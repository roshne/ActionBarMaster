local _, ns = ...

local function DoAutoSave()
  -- In combat, Capture degrades (temp-macro resolution needs the protected
  -- PickupAction) — defer rather than snapshot wrong data
  -- ns:delay is a single-slot timer: any concurrent ns.delay call elsewhere in
  -- this addon would silently cancel this retry. Safe today (no other callers),
  -- but keep this in mind before adding a new ns.delay call to the addon.
  if InCombatLockdown() then
    ns:delay(2000, DoAutoSave)
    return
  end

  -- Spec data may not be ready yet on login/reload; retry rather than saving "Unknown"
  local spec     = GetSpecialization and GetSpecialization()
  local specName = spec and spec > 0 and select(2, GetSpecializationInfo(spec))
  if not specName or specName == "" then
    ns:delay(2000, DoAutoSave)
    return
  end

  local profile = ns.Capture()

  -- Belt-and-suspenders: Capture has its own spec lookup; guard against it too
  if profile.spec == "Unknown" then
    ns:delay(2000, DoAutoSave)
    return
  end

  local encoded = ns.Encode(profile)
  local entry   = {
    name     = UnitName("player") .. " - " .. profile.spec,
    char     = profile.char,
    class    = profile.class,
    spec     = profile.spec,
    encoded  = encoded,
    autosave = true,
    savedAt  = date("%Y-%m-%d %H:%M"),
    barLayout = profile.barLayout,  -- real layout for the preview (not serialized)
  }

  -- One autosave per character+spec — update in place if one already exists
  local profiles = ns.db.profiles
  for i, p in ipairs(profiles) do
    if p.autosave and p.char == profile.char and p.spec == profile.spec then
      profiles[i] = entry
      return
    end
  end

  table.insert(profiles, 1, entry)
end

ns.AutoSave = DoAutoSave

ns:registerCommand("sn", nil, function(self) DoAutoSave() end, "Autosave now")

ns:registerEvent("PLAYER_ENTERING_WORLD", function(self, isLogin, isReload)
  if isLogin or isReload then ns:delay(2000, DoAutoSave) end
end)

-- Delay slightly on spec change to let the new spec fully settle
ns:registerEvent("ACTIVE_TALENT_GROUP_CHANGED", function(self, ...)
  ns:delay(500, DoAutoSave)
end)
