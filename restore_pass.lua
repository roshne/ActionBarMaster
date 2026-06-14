local _, ns = ...

local function Warn(msg)
  ns.Print("|cffff9900[Bars]|r " .. msg)
end

-- Find or create a macro by name+body; returns macro index or nil
local function FindOrCreateMacro(m)
  local target = strtrim(m.body):gsub("\r", "")
  for i = 1, MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS do
    local name, _, body = GetMacroInfo(i)
    if name and name == m.name and strtrim(body):gsub("\r","") == target then
      return i
    end
  end
  -- create it
  local numG, numC = GetNumMacros()
  local isChar = m.id > MAX_ACCOUNT_MACROS
  local canG, canC = numG < MAX_ACCOUNT_MACROS, numC < MAX_CHARACTER_MACROS
  local perchar
  if isChar then
    perchar = canC
  else
    perchar = not canG and canC
  end
  if not canG and not canC then
    Warn("No macro space for: " .. m.name)
    return nil
  end
  local icon = m.icon
  if strsub(m.body, 1, 12) == "#showtooltip" then icon = "INV_Misc_QuestionMark" end
  return CreateMacro(m.name, icon, m.body, perchar)
end

---Ensure all profile macros exist on this character, then place them on their slots.
---@param macros table
---@param slots  table
function ns.RestoreMacrosAndSlots(macros, slots)
  local idMap = {}
  for _, m in ipairs(macros) do
    local newId = FindOrCreateMacro(m)
    if newId then idMap[m.id] = newId end
  end
  for _, s in ipairs(slots) do
    if s.type == "macro" and s.index then
      local newId = idMap[s.index]
      if newId then
        PickupMacro(newId)
        if GetCursorInfo() then PlaceAction(s.id) end
        ClearCursor()
      end
    end
  end
end

---Apply saved key bindings and persist them.
---@param binds table
function ns.RestoreBindings(binds)
  for _, b in ipairs(binds) do
    for _, key in ipairs({ b.key1, b.key2 }) do
      if key then
        local ctx = 1
        if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
          ctx = C_KeyBindings.GetBindingContextForAction(b.command)
        end
        SetBinding(key, b.command, ctx)
      end
    end
  end
  SaveBindings(GetCurrentBindingSet())
end

---Restore pet bar slots from a profile's petslots array.
---@param petslots table
function ns.RestorePetBar(petslots)
  if not IsPetActive() then return end

  -- Find a token's CURRENT slot by name. Token positions shift as we swap them into
  -- place, so re-scan per token rather than trusting a one-time snapshot — a stale
  -- snapshot moved later tokens from the wrong slots (B4).
  local function tokenSlot(name)
    for i = 1, NUM_PET_ACTION_SLOTS do
      local n, _, isToken = GetPetActionInfo(i)
      if isToken and n == name then return i end
    end
  end

  local used = {}
  for _, p in ipairs(petslots) do used[p.id] = true end

  for _, p in ipairs(petslots) do
    if p.type == "token" then
      local src = tokenSlot(p.strindex)
      if src then
        PickupPetAction(src)
        PickupPetAction(p.id)
      end
    elseif p.type == "spell" and PickupPetSpell then
      -- PickupPetSpell is not present on every client; guard it so pet-bar restore
      -- never errors when it's absent (the spell slot is simply left as-is). Both
      -- calls are gated together so PickupPetAction can't pick up the existing slot
      -- action with an empty cursor.
      PickupPetSpell(p.index)
      PickupPetAction(p.id)
    end
    ClearCursor()
  end

  -- Clear pet slots not present in the profile, mirroring ClearUnusedSlots for the
  -- main bars (gap #7) — but only when the profile actually carries pet data. An empty
  -- petslots means "no pet captured" (or the pet bar was filtered out, in which case
  -- restore.lua passes {}), not "blank the pet bar", so leave it untouched then.
  if #petslots > 0 then
    for i = 1, NUM_PET_ACTION_SLOTS do
      if not used[i] and GetPetActionInfo(i) then
        PickupPetAction(i)
        ClearCursor()
      end
    end
  end
end

---Clear action bar slots that are not in the restored profile.
---@param slots     table
---@param barFilter table?  map of bar numbers to bool; nil/true = clear, false = skip
function ns.ClearUnusedSlots(slots, barFilter)
  local used = {}
  for _, s in ipairs(slots) do used[s.id] = true end
  for i = 1, 180 do
    if not used[i] and GetActionInfo(i) then
      local bar = math.floor((i - 1) / 12) + 1
      if not barFilter or barFilter[bar] ~= false then
        PickupAction(i)
        ClearCursor()
      end
    end
  end
end
