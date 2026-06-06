local _, ns = ...
local ui   = ns.ui
local rgba = ns.Colors.rgba

local LIST_W = 240
local PAD    = 8
local ROW_H  = 22

local function ClassColor(class)
  local c = class and C_ClassColor.GetClassColor(class)
  return c and c:GenerateHexColorMarkup() or ""
end

local function ProfileLabel(p)
  local prefix = p.autosave and "|cff888888[a] |r" or ""
  return prefix .. ClassColor(p.class) .. (p.name or "?") .. "|r"
end

---Build a scrollable profile list inside `parent`.
---Returns: scroll frame, Refresh(), GetSelected() -> index, SetSelected(index)
function ns.BuildProfileList(parent, onSelect)
  local scroll = ui.ScrollFrame:new{
    parent   = parent,
    position = {
      TopLeft     = { parent, ui.edge.TopLeft,     PAD,  -PAD },
      BottomRight = { parent, ui.edge.BottomRight, -PAD,  PAD },
    },
  }

  local content = ui.Frame:new{
    parent   = scroll,
    position = {
      TopLeft = { scroll, ui.edge.TopLeft, 0, 0 },
      Width   = LIST_W - PAD * 2,
    },
  }
  scroll:Child(content)

  local rows        = {}
  local selected    = nil
  local classFilter = nil  -- nil = show all

  local function Refresh()
    for _, r in ipairs(rows) do r:Hide() end
    rows = {}
    local profiles = ns.db.profiles
    local playerClass = select(2, UnitClass("player"))
    local spec        = GetSpecialization and GetSpecialization()
    local playerSpec  = spec and spec > 0 and select(2, GetSpecializationInfo(spec))
    local y = 0
    for i, p in ipairs(profiles) do
      local classMatch = not classFilter or p.class == classFilter
      local specMatch  = classFilter ~= playerClass or p.spec == playerSpec
      if classMatch and specMatch then
      local h = (p.autosave and p.savedAt) and ROW_H * 2 or ROW_H
      local btn = ui.Button:new{
        parent   = content,
        position = {
          TopLeft = { content, ui.edge.TopLeft, 0, -y },
          Width   = LIST_W - PAD * 2,
          Height  = h,
        },
        onClick = function()
          selected = i
          onSelect(i)
          Refresh()
        end,
      }
      ui.Label:new{
        parent   = btn,
        text     = (selected == i and "|cffffd100> |r" or "  ") .. ProfileLabel(p),
        position = { Left = { btn, ui.edge.Left, 4, 0 }, Top = {} },
      }
      if p.autosave and p.savedAt then
        ui.Label:new{
          parent   = btn,
          text     = "|cff888888  " .. p.savedAt .. "|r",
          position = { Left = { btn, ui.edge.Left, 4, 0 }, Top = { btn, ui.edge.Top, 0, -ROW_H } },
        }
      end
      ui.Texture:new{
        parent   = btn,
        color    = rgba(255, 255, 255, 0.08),
        position = {
          BottomLeft  = { btn, ui.edge.BottomLeft,  0, 0 },
          BottomRight = { btn, ui.edge.BottomRight, 0, 0 },
          Height      = 1,
        },
      }
      rows[#rows+1] = btn
      y = y + h
      end
    end
    content:Height(math.max(y, 1))
  end

  local function SetSelected(v) selected = v end
  local function SetClassFilter(key) classFilter = key; Refresh() end
  return scroll, Refresh, function() return selected end, SetSelected, SetClassFilter
end
