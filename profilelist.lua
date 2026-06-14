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
  -- [a] autosave; [s] shared (partial, class/spec agnostic — p.class is nil)
  local prefix = p.autosave and "|cff888888[a] |r"
              or not p.class and "|cff888888[s] |r"
              or ""
  -- shared profiles belong to no class: heirloom blue, like account-wide items
  local color = p.class and ClassColor(p.class)
             or ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[7] and ITEM_QUALITY_COLORS[7].hex
             or "|cff00ccff"
  return prefix .. color .. (p.name or "?") .. "|r"
end

---Build a scrollable profile list inside `parent`.
---Returns: scroll frame, Refresh(), GetSelected() -> profile entry, SetSelected(entry)
---`onSelect` receives the selected profile entry (or nil when cleared).
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

  local rowPool     = {}     -- pooled row widgets, re-filled on every Refresh
  local selected    = nil
  local classFilter = nil    -- nil = show all
  local specFilter  = false  -- true = also narrow to the player's current spec
  local Refresh              -- forward-declared; row onClick closures call it

  -- Rows are pooled because WoW frames are never garbage-collected and
  -- Refresh runs on every list click — recreating rows leaks frames.
  local function acquireRow(n)
    if rowPool[n] then return rowPool[n] end
    local row = {}
    row.btn = ui.Button:new{
      parent   = content,
      position = {
        TopLeft = { content, ui.edge.TopLeft, 0, 0 },
        Width   = LIST_W - PAD * 2,
        Height  = ROW_H,
      },
      onClick = function()
        selected = row.profile
        onSelect(row.profile)
        Refresh()
      end,
    }
    row.name = ui.Label:new{
      parent   = row.btn,
      position = { Left = { row.btn, ui.edge.Left, 4, 0 }, Top = {} },
    }
    row.time = ui.Label:new{
      parent   = row.btn,
      position = { Left = { row.btn, ui.edge.Left, 4, 0 }, Top = { row.btn, ui.edge.Top, 0, -ROW_H } },
    }
    ui.Texture:new{
      parent   = row.btn,
      color    = rgba(255, 255, 255, 0.08),
      position = {
        BottomLeft  = { row.btn, ui.edge.BottomLeft,  0, 0 },
        BottomRight = { row.btn, ui.edge.BottomRight, 0, 0 },
        Height      = 1,
      },
    }
    rowPool[n] = row
    return row
  end

  Refresh = function()
    local spec       = GetSpecialization and GetSpecialization()
    local playerSpec = spec and spec > 0 and select(2, GetSpecializationInfo(spec))
    local n, y = 0, 0
    for _, p in ipairs(ns.db.profiles) do
      -- shared profiles (p.class nil) ignore the class/spec filter entirely
      local classMatch = not classFilter or not p.class or p.class == classFilter
      local specMatch  = not specFilter  or not p.class or p.spec == playerSpec
      if classMatch and specMatch then
        n = n + 1
        local row = acquireRow(n)
        local h = (p.autosave and p.savedAt) and ROW_H * 2 or ROW_H
        -- selection is keyed by the profile entry itself (identity), not its
        -- list index — an autosave inserting at index 1 mid-session must not
        -- shift which profile is selected (issue #65)
        row.profile = p
        row.btn:TopLeft(content, ui.edge.TopLeft, 0, -y)
        row.btn:Height(h)
        row.name:Text((selected == p and "|cffffd100> |r" or "  ") .. ProfileLabel(p))
        if p.autosave and p.savedAt then
          row.time:Text("|cff888888  " .. p.savedAt .. "|r")
          row.time:Show()
        else
          row.time:Hide()
        end
        row.btn:Show()
        y = y + h
      end
    end
    for j = n + 1, #rowPool do rowPool[j].btn:Hide() end
    content:Height(math.max(y, 1))
  end

  local function SetSelected(v) selected = v end
  local function SetClassFilter(key, specOnly)
    classFilter = key
    specFilter  = specOnly or false
    Refresh()
  end
  return scroll, Refresh, function() return selected end, SetSelected, SetClassFilter
end
