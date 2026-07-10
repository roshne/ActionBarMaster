local _, ns = ...
local ui = ns.ui

local PAD        = 8
local DWIN_W     = 450
local DLABEL_W   = 80
local CELL_W     = 27
local CELL_GAP   = 2
local DBAR_GAP   = 4
local SUBTITLE_H = 16
local ICON_INSET = 2
local UNRESOLVED = "Interface\\AddOns\\ActionBarMaster\\textures\\unresolved.png"

local detail = nil  -- lazily created; one shared instance

local function ensureWindow()
  if detail then return end
  detail = {}
  detail.rows = {}

  -- Not `special`: like every nested frame in the addon (dupes list, Save/Export/Import/
  -- Debug, the class filter), Escape is handled by ns.CaptureEscape below — a `special`
  -- frame routes Escape through CloseSpecialWindows and takes the main window down with it.
  detail.f = ui.TitleFrame:new{
    name     = "ABMDupesDetailWindow",
    title    = "Duplicate Detail",
    level    = 610,
    position = { Center = {}, Width = DWIN_W, Height = 180 },
  }
  ns.CaptureEscape(detail.f)
  detail.f:SetScript("OnHide", function()
    if detail.currentFinding and detail.currentFinding.charName == UnitName("player") then
      ns.AutoSave()
    end
    detail.currentFinding = nil
  end)

  detail.subtitle = ui.Label:new{
    parent  = detail.f,
    fontObj = "GameFontHighlightSmall",
    position = {
      TopLeft  = { detail.f.titlebar, ui.edge.BottomLeft,  PAD, -PAD },
      TopRight = { detail.f.titlebar, ui.edge.BottomRight, -PAD, -PAD },
      Height   = SUBTITLE_H,
    },
  }

  detail.content = ui.Frame:new{
    parent   = detail.f,
    position = {
      TopLeft     = { detail.f.titlebar, ui.edge.BottomLeft,
                      PAD, -(PAD + SUBTITLE_H + PAD) },
      BottomRight = { detail.f, ui.edge.BottomRight, -PAD, PAD },
    },
  }
end

local function acquireBarRow(n)
  ensureWindow()
  if detail.rows[n] then return detail.rows[n] end

  local r = {}
  r.frame = ui.Frame:new{
    parent   = detail.content,
    position = { TopLeft = {0, 0}, Width = DWIN_W - PAD * 2, Height = CELL_W },
  }
  r.lbl = ui.Label:new{
    parent  = r.frame,
    fontObj = "GameFontHighlightSmall",
    position = {
      TopLeft = { r.frame, ui.edge.TopLeft, 0, 0 },
      Width   = DLABEL_W, Height = CELL_W,
    },
  }
  r.cells = {}
  for col = 1, 12 do
    local cell = ui.Frame:new{
      parent     = r.frame,
      position   = {
        TopLeft = { r.frame, ui.edge.TopLeft,
                    DLABEL_W + (col - 1) * (CELL_W + CELL_GAP), 0 },
        Width   = CELL_W, Height = CELL_W,
      },
      background = { 0.15, 0.15, 0.15, 0.8 },
    }
    cell.icon = ui.Texture:new{
      parent = cell,
      position = {
        TopLeft     = { cell, ui.edge.TopLeft,     ICON_INSET, -ICON_INSET },
        BottomRight = { cell, ui.edge.BottomRight, -ICON_INSET, ICON_INSET },
      },
    }
    cell.icon:Hide()
    r.cells[col] = cell
  end
  detail.rows[n] = r
  return r
end

function ns.ShowDupeDetail(finding)
  ensureWindow()
  detail.subtitle:Text("|cffaaaaaa" .. finding.profileName .. "|r   " .. finding.actionName)

  local profile = ns.Decode(finding.profile.encoded)
  if not profile then detail.f:Show(); return end

  -- Build slotMap: barIndex -> colIndex -> slot entry
  local slotMap = {}
  for _, slot in ipairs(profile.slots or {}) do
    local bar = math.ceil(slot.id / 12)
    local c   = (slot.id - 1) % 12 + 1
    if not slotMap[bar] then slotMap[bar] = {} end
    slotMap[bar][c] = slot
  end

  local macros = profile.macros or {}
  local n = #finding.slotIDs
  for i, slotID in ipairs(finding.slotIDs) do
    local row     = acquireBarRow(i)
    local barIdx  = math.ceil(slotID / 12)
    local dupeCol = (slotID - 1) % 12 + 1
    row.frame:TopLeft(detail.content, ui.edge.TopLeft, 0, -(i - 1) * (CELL_W + DBAR_GAP))
    row.lbl:Text(ns.GetBarLabel(barIdx))
    local barSlots = slotMap[barIdx] or {}
    for c = 1, 12 do
      local cell  = row.cells[c]
      local entry = barSlots[c]
      if c == dupeCol then
        cell.background:Color(1, 0.75, 0, 1)
      else
        cell.background:Color(0.15, 0.15, 0.15, 0.8)
      end
      if entry then
        cell.icon:Texture(ns._bar_getIcon(entry, macros) or UNRESOLVED)
        cell.icon:Show()
      else
        cell.icon:Hide()
      end
    end
    row.frame:Show()
  end
  for j = n + 1, #detail.rows do detail.rows[j].frame:Hide() end

  local contentH = n * CELL_W + (n - 1) * DBAR_GAP
  detail.f:Height(30 + PAD + SUBTITLE_H + PAD + contentH + PAD)
  detail.currentFinding = finding
  detail.f:Show()
end
