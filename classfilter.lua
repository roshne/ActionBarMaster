local _, ns = ...
local ui = ns.ui

local ROW_H = 22

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

  local menu = ui.BgFrame:new{
    name     = "ActionBarMasterClassFilter",
    parent   = parent,
    level    = 650,
    strata   = "DIALOG",  -- must match catcher strata so level ordering applies
    special  = true,
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

  -- The menu is special (UISpecialFrames), so Escape can hide it without going
  -- through any click path — mirror every hide onto the catcher here, otherwise
  -- the invisible catcher stays up and swallows the next click.
  menu._widget:HookScript("OnHide", function() catcher:Hide() end)

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
        triggerLabel:Text(EntryText(e) .. " v")
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
end
