local _, ns = ...

local MAX_BARS = 180

-- /abm debug flyouts
-- Dumps three sections:
--   1. Spellbook flyout entries (ID, name, known, bar slots via FindFlyoutActionButtons)
--   2. Bar slots where GetActionInfo returns type="flyout" (id returned by GetActionInfo)
--   3. Cross-check: flyouts found in spellbook vs found on bars
local function DebugFlyouts()
  ns.Print("=== Flyout Debug ===")

  -- ── Section 1: spellbook flyouts ────────────────────────────────────────────
  ns.Print("-- Spellbook flyouts --")
  local bookFlyouts = {}  -- flyoutID -> name
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
    for lineIdx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local info = C_SpellBook.GetSpellBookSkillLineInfo(lineIdx)
      for i = 1, info.numSpellBookItems do
        local si = info.itemIndexOffset + i
        local typ, id = C_SpellBook.GetSpellBookItemType(si, Enum.SpellBookSpellBank.Player)
        if typ == Enum.SpellBookItemType.Flyout then
          local name, _, numSlots, isKnown = GetFlyoutInfo(id)
          bookFlyouts[id] = name or "?"
          local barSlots = C_ActionBar and C_ActionBar.FindFlyoutActionButtons
                       and C_ActionBar.FindFlyoutActionButtons(id) or {}
          local slotStr = #barSlots > 0 and table.concat(barSlots, ",") or "none"
          ns.Print(string.format("  id=%d  name=%s  slots=%d  known=%s  onBars={%s}",
            id, name or "?", numSlots or 0, tostring(isKnown), slotStr))
        end
      end
    end
  else
    ns.Print("  C_SpellBook unavailable")
  end

  -- ── Section 2: bar slots reporting as flyout ─────────────────────────────────
  ns.Print("-- Bar slots with type=flyout --")
  local found = false
  for i = 1, MAX_BARS do
    local t, id = GetActionInfo(i)
    if t == "flyout" then
      local name = bookFlyouts[id] or "?"
      ns.Print(string.format("  bar slot=%d  flyoutID=%s  name=%s",
        i, tostring(id), name))
      found = true
    end
  end
  if not found then ns.Print("  (none)") end

  ns.Print("=== End Flyout Debug ===")
end

ns:registerCommand("debug", "flyouts", function() DebugFlyouts() end,
  "Dump flyout spellbook and bar-slot state for debugging")
