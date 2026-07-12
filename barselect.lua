local _, ns = ...
local ui   = ns.ui
local rgba = ns.Colors.rgba

-- Chip metrics
local CHIP_W, CHIP_H, GAP = 40, 24, 4
local ACC_W   = 3
local CAP_H   = 14   -- caption line
local PER_ROW = 8    -- chips per row (both rows are full)
local ROW_W   = PER_ROW * CHIP_W + (PER_ROW - 1) * GAP   -- strip width, for centering

-- Included / excluded palette — mirrors the on-screen bar overlay + Warbandeer's
-- apply strip: a gold wash + gold accent reads as "included", an empty chip with
-- a red accent reads as "excluded".
local INCL_BG   = rgba(212, 175, 55, 0.20)
local HOVER_ON  = rgba(212, 175, 55, 0.34)
local HOVER_OFF = rgba(255, 255, 255, 0.10)
local ACC_ON    = rgba(212, 175, 55, 1)
local ACC_OFF   = rgba(200,  60, 60, 1)

-- Display chip -> abm bar number (mirrors barlabels.lua BAR_DEFS). The abm bar
-- number is the same 1-15 slot-range space LibNUI's ui.BarsPreview keys its rows
-- by, so a chip lights up its real bar in the preview via HighlightBar. Pet maps
-- to the "pet" filter key (petslots), not a slot range. `nl` breaks to a new row.
local CHIPS = {
  { label = "1",     abm = 1  },
  { label = "2",     abm = 6  },
  { label = "3",     abm = 5  },
  { label = "4",     abm = 3  },
  { label = "5",     abm = 4  },
  { label = "6",     abm = 13 },
  { label = "7",     abm = 14 },
  { label = "8",     abm = 15 },
  { label = "C1",    abm = 7, nl = true },
  { label = "C2",    abm = 8  },
  { label = "C3",    abm = 9  },
  { label = "C4",    abm = 10 },
  { label = "C5",    abm = 12 },
  { label = "Bonus", abm = 2  },
  { label = "Sky",   abm = 11 },
  { label = "Pet",   pet = true },
}

---Build the per-bar include selector: a compact grid of toggle chips (one per
---action bar plus Pet) that feeds the barFilter used by Save (partial profiles)
---and Load. Replaces the old interactive grid's per-row checkboxes. Chips default
---to included; hovering a chip highlights the bar it controls in the topographic
---preview (wired via SetHighlighter). Centered horizontally in `parent`. Modeled
---on Warbandeer's BarsApply strip.
---@param parent table  LibNUI frame
---@return { GetChecked: fun(): table, SetAllChecked: fun(v: boolean), SetHighlighter: fun(fn: fun(abm: integer, on: boolean)), Height: fun(): number }
function ns.BuildBarSelect(parent)
  local checked   = {}    -- [abm | "pet"] = bool (explicit; false = exclude)
  local chips     = {}
  local highlight = nil   -- (abm, on) highlighter, set via SetHighlighter

  -- Everything anchors to the parent's TOP edge (its horizontal centre), so the
  -- fixed-width strip stays centered in the panel without measuring it.
  ui.Label:new{
    parent   = parent, fontObj = "GameFontHighlightSmall", color = "muted", wordWrap = false,
    justifyH = "CENTER", text = "Include on Save / Load",
    position = { Top = { parent, ui.edge.Top, 0, 0 }, Width = ROW_W, Height = CAP_H },
  }

  -- Flat wash: gold fill + gold accent when included, empty + red accent when excluded.
  local function paint(chip)
    if chip._on then
      chip.background:Color(INCL_BG)
      chip.accent:Color(ACC_ON)
      chip.label:Color("text")
    else
      chip.background:Color(0, 0, 0, 0)
      chip.accent:Color(ACC_OFF)
      chip.label:Color("muted")
    end
  end

  local startX = -ROW_W / 2
  local x, y = startX, -(CAP_H + GAP)
  for _, def in ipairs(CHIPS) do
    if def.nl then x, y = startX, y - CHIP_H - GAP end
    local key = def.pet and "pet" or def.abm
    checked[key] = true

    local chip = ui.Button:new{
      parent     = parent,
      glow       = false,
      background = INCL_BG,
      position   = { TopLeft = { parent, ui.edge.Top, x, y }, Width = CHIP_W, Height = CHIP_H },
    }
    chip._on  = true
    chip._key = key
    chip._abm = def.abm   -- nil for the pet chip

    chip.accent = ui.Texture:new{
      parent   = chip, layer = ui.layer.Overlay,
      position = { TopLeft = { chip, ui.edge.TopLeft, 0, 0 }, Width = ACC_W, Height = CHIP_H },
    }
    chip.label = ui.Label:new{
      parent = chip, fontObj = "GameFontHighlightSmall", justifyH = "CENTER",
      text = def.label, position = { All = true },
    }

    chip.OnClick = function()
      chip._on = not chip._on
      checked[key] = chip._on
      paint(chip)
    end
    -- Hover: lift the chip and light up the bar it controls in the preview so the
    -- mapping from chip to real bar is visible. The pet chip has no preview bar.
    chip.OnEnter = function()
      chip.background:Color(chip._on and HOVER_ON or HOVER_OFF)
      if highlight and chip._abm then highlight(chip._abm, true) end
    end
    chip.OnLeave = function()
      paint(chip)
      if highlight and chip._abm then highlight(chip._abm, false) end
    end

    paint(chip)
    chips[#chips + 1] = chip
    x = x + CHIP_W + GAP
  end

  local totalH = -y + CHIP_H

  -- Drives the window's Check All / Uncheck All button.
  local function SetAllChecked(v)
    for _, chip in ipairs(chips) do
      chip._on = v
      checked[chip._key] = v
      paint(chip)
    end
  end

  return {
    GetChecked     = function() return checked end,
    SetAllChecked  = SetAllChecked,
    SetHighlighter = function(fn) highlight = fn end,
    Height         = function() return totalH end,
  }
end
