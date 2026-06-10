local _, ns = ...

LibNAddOn{
  name    = "ActionBarMaster",
  addOn   = ns,
}

---Close `frame` on Escape without letting CloseSpecialWindows see the press —
---it hides every visible special frame at once, which would take the main
---window down along with the dialog. Frames using this must NOT be `special`.
---Other keys propagate normally. During combat lockdown (where
---SetPropagateKeyboardInput is protected) keys propagate untouched, so Escape
---falls back to closing everything.
---@param frame table  LibNUI frame to close on Escape while shown
function ns.CaptureEscape(frame)
  local w = frame._widget
  w:EnableKeyboard(true)
  w:SetPropagateKeyboardInput(true)
  w:SetScript("OnKeyDown", function(widget, key)
    local isEsc = key == "ESCAPE"
    if not InCombatLockdown() then
      widget:SetPropagateKeyboardInput(not isEsc)
    end
    if isEsc then frame:Hide() end
  end)
end

function ns:MigrateDB()
  local db = self.db
  if not db.version then
    db.profiles = {}
    db.version  = 1
  end
  if db.version < 2 then
    -- Seed bar display order from the hardcoded default (abm bar numbers in display order)
    db.barOrder = { 1, 6, 5, 3, 4, 13, 14, 15, 2, 7, 8, 9, 10, 12, 11 }
    db.version  = 2
  end
end
