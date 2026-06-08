local _, ns = ...
local ui = ns.ui

local MAX_BARS = 180
local DLG_W, DLG_H = 500, 400
local PAD, BTN_H = 8, 22

local debugDlg

local function GetDebugWindow()
  if debugDlg then return debugDlg end

  debugDlg = ui.TitleFrame:new{
    name    = "ActionBarMasterDebugDlg",
    title   = "ABM Debug",
    special = true,
    level   = 700,
    position = { Center = {}, Width = DLG_W, Height = DLG_H, Hide = true },
  }

  local scroll = ui.ScrollFrame:new{
    parent   = debugDlg,
    position = {
      TopLeft     = { debugDlg.titlebar, ui.edge.BottomLeft, PAD, -PAD },
      BottomRight = { debugDlg, ui.edge.BottomRight, -PAD, PAD + BTN_H + PAD },
    },
  }

  local box = ui.EditBox:new{
    parent   = scroll,
    multiline = true,
    template  = "",
    fontObj   = GameFontHighlightSmall,
    position  = { Width = DLG_W - PAD * 2 - 20 },
    OnEscapePressed = function() debugDlg:Hide() end,
    OnMouseUp       = function(self) self._widget:HighlightText(0, -1) end,
  }
  scroll:Child(box)
  debugDlg._box = box

  local closeBtn = ui.Button:new{
    parent   = debugDlg,
    template = "UIPanelButtonTemplate",
    glow     = false,
    onClick  = function() debugDlg:Hide() end,
    position = { Left = { debugDlg, ui.edge.Center, -40, 0 }, Bottom = { debugDlg, ui.edge.Bottom, 0, PAD }, Width = 80, Height = BTN_H },
  }
  closeBtn:Text("Close")
  closeBtn:TextAlign("CENTER")

  return debugDlg
end

local function ShowDebugOutput(text)
  local dlg = GetDebugWindow()
  dlg._box:Text(text)
  dlg._box._widget:HighlightText(0, -1)
  dlg:Show()
end

-- ── Debug commands ────────────────────────────────────────────────────────────

local function DebugFlyouts()
  local lines = { "=== Flyout Debug ===" }

  -- Section 1: spellbook flyouts (deduplicated by flyout ID)
  lines[#lines+1] = "-- Spellbook flyouts --"
  local bookFlyouts = {}   -- id -> name
  local flyoutBarSlots = {} -- id -> {barSlot, ...}
  local seen = {}
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
    for lineIdx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local info = C_SpellBook.GetSpellBookSkillLineInfo(lineIdx)
      for i = 1, info.numSpellBookItems do
        local si = info.itemIndexOffset + i
        local typ, id = C_SpellBook.GetSpellBookItemType(si, Enum.SpellBookSpellBank.Player)
        if typ == Enum.SpellBookItemType.Flyout and not seen[id] then
          seen[id] = true
          local name, _, numSlots, isKnown = GetFlyoutInfo(id)
          bookFlyouts[id] = name or "?"
          local barSlots = C_ActionBar and C_ActionBar.FindFlyoutActionButtons
                       and C_ActionBar.FindFlyoutActionButtons(id) or {}
          flyoutBarSlots[id] = barSlots
          local slotStr = #barSlots > 0 and table.concat(barSlots, ",") or "none"
          lines[#lines+1] = string.format("  id=%d  name=%s  slots=%d  known=%s  onBars={%s}",
            id, name or "?", numSlots or 0, tostring(isKnown), slotStr)
        end
      end
    end
  else
    lines[#lines+1] = "  C_SpellBook unavailable"
  end

  -- Section 2: bar slots reporting as flyout via GetActionInfo
  lines[#lines+1] = "-- Bar slots with type=flyout (GetActionInfo) --"
  local actionFlyoutSlots = {}
  local found = false
  for i = 1, MAX_BARS do
    local t, id = GetActionInfo(i)
    if t == "flyout" then
      actionFlyoutSlots[i] = id
      lines[#lines+1] = string.format("  barSlot=%d  flyoutID=%s  name=%s",
        i, tostring(id), bookFlyouts[id] or "?")
      found = true
    end
  end
  if not found then lines[#lines+1] = "  (none)" end

  -- Section 3: mismatch — slots FindFlyoutActionButtons says have a flyout
  -- but GetActionInfo disagrees
  lines[#lines+1] = "-- Mismatch: FindFlyoutActionButtons vs GetActionInfo --"
  local anyMismatch = false
  for id, barSlots in pairs(flyoutBarSlots) do
    for _, slot in ipairs(barSlots) do
      if actionFlyoutSlots[slot] ~= id then
        local t, aid = GetActionInfo(slot)
        lines[#lines+1] = string.format(
          "  slot=%d  expected flyoutID=%d (%s)  GetActionInfo=(%s,%s)",
          slot, id, bookFlyouts[id] or "?", tostring(t), tostring(aid))
        anyMismatch = true
      end
    end
  end
  if not anyMismatch then lines[#lines+1] = "  (none)" end

  lines[#lines+1] = "=== End ==="
  ShowDebugOutput(table.concat(lines, "\n"))
end

ns:registerCommand("debug", "flyouts", function() DebugFlyouts() end,
  "Dump flyout spellbook and bar-slot state for debugging")
