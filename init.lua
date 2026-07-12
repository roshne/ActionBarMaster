local _, ns = ...

LibNAddOn{
  name    = "ActionBarMaster",
  addOn   = ns,
}

-- Surface a "Changelog" button in the Action Bar Master settings category,
-- opening the release history (ns.changelog, from changelog.lua) in the shared
-- CopyWindow. No parent → a top-level category, since the addon has no other
-- settings of its own.
ns:RegisterChangelog()

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
  -- SetPropagateKeyboardInput is protected during combat lockdown, and frame
  -- creation can happen mid-combat (/bars in combat builds the window): set
  -- propagation whenever it is safe — at setup and on every show, which also
  -- resets the no-propagate state an Escape capture leaves behind.
  local function propagate()
    if not InCombatLockdown() then w:SetPropagateKeyboardInput(true) end
  end
  propagate()
  w:HookScript("OnShow", propagate)
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
    -- LEGACY (unread since #124): the bar display order used to be user-reorderable
    -- and stored here; the primary view is now driven by real on-screen topography,
    -- so nothing reads db.barOrder any more. The seed is kept (not removed) so a
    -- rollback to an earlier revision in this patch cycle finds its data intact —
    -- per the non-destructive DB rule. A future /bars cleanup could drop it.
    db.barOrder = { 1, 6, 5, 3, 4, 13, 14, 15, 2, 7, 8, 9, 10, 12, 11 }
    db.version  = 2
  end
end
