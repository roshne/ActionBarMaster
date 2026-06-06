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

---Build a class filter dropdown inside `parent` at `position`.
---Calls onSelect(classKey or nil) when the selection changes.
---@param parent table     LibNUI frame to parent the dropdown to
---@param position table   LibNUI position table for the trigger button
---@param onSelect fun(key: string|nil)
function ns.BuildClassFilter(parent, position, onSelect)
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
    name     = "WarbandeerBarsRGSClassFilter",
    parent   = parent,
    level    = 650,
    special  = true,
    position = {
      TopLeft  = { triggerBtn, ui.edge.BottomLeft,  0, 0 },
      TopRight = { triggerBtn, ui.edge.BottomRight, 0, 0 },
      Height   = #CLASSES * ROW_H,
      Hide     = true,
    },
  }

  -- Replace placeholder; showing an already-visible menu is harmless (AnyDown+AnyUp both fire)
  triggerBtn.onClick = function() menu:Show() end

  for i, cls in ipairs(CLASSES) do
    local btn = ui.Button:new{
      parent   = menu,
      position = {
        TopLeft  = { menu, ui.edge.TopLeft,  0, -(i - 1) * ROW_H },
        TopRight = { menu, ui.edge.TopRight, 0, -(i - 1) * ROW_H },
        Height   = ROW_H,
      },
      onClick = function()
        triggerLabel:Text(ClassLabel(cls.key, cls.label) .. " v")
        menu:Hide()
        onSelect(cls.key)
      end,
    }
    ui.Label:new{
      parent   = btn,
      text     = ClassLabel(cls.key, cls.label),
      position = { Left = { btn, ui.edge.Left, 4, 0 }, Top = {}, Bottom = {} },
    }
  end
end
