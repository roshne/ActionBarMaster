local _, ns = ...

-- Auto-saves always capture everything regardless of the user's include settings.
local FULL_INCLUDE = { bars = true, bindings = true, macros = true, petbar = true, outfits = true }

local function DoAutoSave()
  -- Spec data may not be ready yet on login/reload; retry rather than saving "Unknown"
  local spec     = GetSpecialization and GetSpecialization()
  local specName = spec and spec > 0 and select(2, GetSpecializationInfo(spec))
  if not specName or specName == "" then
    ns:delay(2000, DoAutoSave)
    return
  end

  local profile = ns.Capture(FULL_INCLUDE, true, true)

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

ns:registerEvent("PLAYER_ENTERING_WORLD", function(self, isLogin, isReload)
  if isLogin or isReload then ns:delay(2000, DoAutoSave) end
end)

ns:registerEvent("PLAYER_LOGOUT", function(self, ...)
  DoAutoSave()
end)

-- Delay slightly on spec change to let the new spec fully settle
ns:registerEvent("ACTIVE_TALENT_GROUP_CHANGED", function(self, ...)
  ns:delay(500, DoAutoSave)
end)
