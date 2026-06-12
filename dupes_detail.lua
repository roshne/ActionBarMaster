local _, ns = ...
local ui = ns.ui

-- Constants (must match dupes.lua layout decisions)
local PAD        = 8
local DWIN_W     = 450
local DLABEL_W   = 80
local CELL_W     = 27
local CELL_GAP   = 2
local DBAR_H     = 28
local DBAR_GAP   = 6
local SUBTITLE_H = 16

local detail = nil  -- lazily created; one shared instance

local function ensureWindow()
  if detail then return end
  detail = {}
  detail.rows = {}

  detail.f = ui.TitleFrame:new{
    name     = "ABMDupesDetailWindow",
    title    = "Duplicate Detail",
    special  = true,
    level    = 610,
    position = { Center = {}, Width = DWIN_W, Height = 180 },
  }
  ns.CaptureEscape(detail.f)

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
    position = { TopLeft = {0, 0}, Width = DWIN_W - PAD*2, Height = DBAR_H },
  }
  r.lbl = ui.Label:new{
    parent  = r.frame,
    fontObj = "GameFontHighlightSmall",
    position = {
      TopLeft = { r.frame, ui.edge.TopLeft, 0, 0 },
      Width   = DLABEL_W, Height = DBAR_H,
    },
  }
  r.cells = {}
  local cellTop = -math.floor((DBAR_H - CELL_W) / 2)
  for col = 1, 12 do
    r.cells[col] = ui.Frame:new{
      parent     = r.frame,
      position   = {
        TopLeft = { r.frame, ui.edge.TopLeft,
                    DLABEL_W + (col - 1) * (CELL_W + CELL_GAP), cellTop },
        Width   = CELL_W, Height = CELL_W,
      },
      background = { 0.15, 0.15, 0.15, 0.8 },
    }
  end
  detail.rows[n] = r
  return r
end

function ns.ShowDupeDetail(finding)
  ensureWindow()

  detail.subtitle:Text("|cffaaaaaa" .. finding.profileName .. "|r   " .. finding.actionName)

  local n = #finding.slotIDs
  for i, slotID in ipairs(finding.slotIDs) do
    local row    = acquireBarRow(i)
    local barIdx = math.ceil(slotID / 12)
    local col    = (slotID - 1) % 12 + 1
    row.frame:TopLeft(detail.content, ui.edge.TopLeft, 0, -(i - 1) * (DBAR_H + DBAR_GAP))
    row.lbl:Text(ns.GetBarLabel(barIdx))
    for c = 1, 12 do
      if c == col then
        row.cells[c].background:Color(1, 0.75, 0, 1)
      else
        row.cells[c].background:Color(0.15, 0.15, 0.15, 0.8)
      end
    end
    row.frame:Show()
  end
  for j = n + 1, #detail.rows do detail.rows[j].frame:Hide() end

  -- Resize height to fit the content snugly
  local contentH = n * DBAR_H + (n - 1) * DBAR_GAP
  detail.f:Height(30 + PAD + SUBTITLE_H + PAD + contentH + PAD)

  detail.f:Show()
end
