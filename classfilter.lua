local _, ns = ...
local ui = ns.ui

local ROW_H = 22

-- Down-caret suffix on the trigger label. FRIZQT has no ▼ glyph (renders as
-- tofu), so use Blizzard's dropdown arrow atlas inline. The "-up" suffix is
-- the toggle button's released state, not the arrow direction — it points
-- down. Single point of change if a different atlas is wanted.
local ARROW = " " .. CreateAtlasMarkup("auctionhouse-ui-dropdown-arrow-up")

local CLASSES = {
  { key = nil,           label = "All Classes"  },
  { key = "DEATHKNIGHT", label = "Death Knight" },
  { key = "DEMONHUNTER", label = "Demon Hunter" },
  { key = "DRUID",       label = "Druid"        },
  { key = "EVOKER",      label = "Evoker"       },
  { key = "HUNTER",      label = "Hunter"       },
  { key = "MAGE",        label = "Mage"         },
  { key = "MONK",        label = "Monk"         },
  { key = "PALADIN",     label = "Paladin"      },
  { key = "PRIEST",      label = "Priest"       },
  { key = "ROGUE",       label = "Rogue"        },
  { key = "SHAMAN",      label = "Shaman"       },
  { key = "WARLOCK",     label = "Warlock"      },
  { key = "WARRIOR",     label = "Warrior"      },
}

local function ClassLabel(key, label)
  if not key then return label end
  local c = C_ClassColor.GetClassColor(key)
  return c and (c:GenerateHexColorMarkup() .. label .. "|r") or label
end

local function CurrentSpecName()
  local spec = GetSpecialization and GetSpecialization()
  local name = spec and spec > 0 and select(2, GetSpecializationInfo(spec))
  if name and name ~= "" then return name end
end

---Build a class filter dropdown inside `parent` at `position`.
---Calls onSelect(classKey or nil, specOnly) when the selection changes.
---The player's own class gets two rows: current spec only, and all specs.
---@param parent table     LibNUI frame to parent the dropdown to
---@param position table   LibNUI position table for the trigger button
---@param onSelect fun(key: string|nil, specOnly: boolean|nil)
function ns.BuildClassFilter(parent, position, onSelect)
  local playerClass = select(2, UnitClass("player"))

  local entries = {}
  for _, cls in ipairs(CLASSES) do
    if cls.key == playerClass then
      entries[#entries+1] = { key = cls.key, label = cls.label, specOnly = true }
      entries[#entries+1] = { key = cls.key, label = cls.label .. " - all specs" }
    else
      entries[#entries+1] = { key = cls.key, label = cls.label }
    end
  end

  -- Spec-only row text resolves the live spec name, which can change while
  -- the window is open (ACTIVE_TALENT_GROUP_CHANGED)
  local function EntryText(e)
    local label = e.label
    if e.specOnly then label = label .. " - " .. (CurrentSpecName() or "current spec") end
    return ClassLabel(e.key, label)
  end

  local triggerLabel  -- assigned after button creation

  -- placeholder onClick so Button registers the WoW OnClick script
  local triggerBtn = ui.Button:new{
    parent   = parent,
    position = position,
    onClick  = function() end,
  }
  triggerLabel = ui.Label:new{
    parent   = triggerBtn,
    text     = "All Classes v",
    position = { Left = { triggerBtn, ui.edge.Left, 4, 0 }, Top = {}, Bottom = {} },
  }

  -- Not `special`: Escape is handled by ns.CaptureEscape below instead.
  local menu = ui.BgFrame:new{
    name     = "ActionBarMasterClassFilter",
    parent   = parent,
    level    = 650,
    strata   = "DIALOG",  -- must match catcher strata so level ordering applies
    position = {
      TopLeft  = { triggerBtn, ui.edge.BottomLeft,  0, 0 },
      TopRight = { triggerBtn, ui.edge.BottomRight, 0, 0 },
      Height   = #entries * ROW_H,
      Hide     = true,
    },
  }

  -- Transparent full-screen catcher; closes the menu on any click outside it.
  -- Must use the same strata as the menu so that frame-level ordering determines priority:
  -- catcher sits at (menu.level - 1), menu items sit at (menu.level + 1), so items win.
  local catcher = CreateFrame("Frame", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("DIALOG")
  catcher:SetFrameLevel(menu._widget:GetFrameLevel() - 1)
  catcher:EnableMouse(true)
  catcher:Hide()
  catcher:SetScript("OnMouseDown", function()
    menu:Hide()
  end)

  -- Every dismissal path (item click, outside click, Escape, parent window
  -- hiding) funnels through the menu hiding — mirror it onto the catcher here,
  -- otherwise the invisible catcher stays up and swallows the next click.
  menu._widget:HookScript("OnHide", function() catcher:Hide() end)

  -- Escape closes only the menu, not the (special) main window
  ns.CaptureEscape(menu)

  local rowLabels = {}

  -- Replace placeholder; showing an already-visible menu is harmless (AnyDown+AnyUp both fire)
  triggerBtn.onClick = function()
    for i, e in ipairs(entries) do
      if e.specOnly then rowLabels[i]:Text(EntryText(e)) end
    end
    menu:Show()
    catcher:Show()
  end

  for i, e in ipairs(entries) do
    local btn = ui.Button:new{
      parent   = menu,
      position = {
        TopLeft  = { menu, ui.edge.TopLeft,  0, -(i - 1) * ROW_H },
        TopRight = { menu, ui.edge.TopRight, 0, -(i - 1) * ROW_H },
        Height   = ROW_H,
      },
      onClick = function()
        triggerLabel:Text(EntryText(e) .. ARROW)
        menu:Hide()
        onSelect(e.key, e.specOnly)
      end,
    }
    rowLabels[i] = ui.Label:new{
      parent   = btn,
      text     = EntryText(e),
      position = { Left = { btn, ui.edge.Left, 4, 0 }, Top = {}, Bottom = {} },
    }
  end

  -- Default to the player's current class + spec rather than All Classes;
  -- manual selections persist for the rest of the session. Falls back to
  -- All Classes if the player's class has no entry (future class not in CLASSES).
  for _, e in ipairs(entries) do
    if e.specOnly then
      triggerLabel:Text(EntryText(e) .. ARROW)
      onSelect(e.key, true)
      break
    end
  end
end
