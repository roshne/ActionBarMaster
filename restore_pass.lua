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
---Faithful mirror, consistent with how action slots restore (ClearUnusedSlots blanks
---slots absent from the profile): clear the character's current key bindings first, then
---apply the profile's, so the key map ends up exactly as captured rather than merged.
---Capture stores the FULL binding set, and ns.Restore only calls this for full profiles
---(partial/shared profiles carry no binds), so nothing the source had is lost.
---@param binds table
function ns.RestoreBindings(binds)
  -- Collect every currently-bound key first, then clear, so we never mutate bindings
  -- while iterating the bindable-command list.
  local toClear = {}
  for i = 1, GetNumBindings() do
    local _, _, key1, key2 = GetBinding(i)
    if key1 then toClear[#toClear + 1] = key1 end
    if key2 then toClear[#toClear + 1] = key2 end
  end
  for _, key in ipairs(toClear) do
    SetBinding(key)   -- one-arg form clears the binding for this key
  end

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
---Pet-bar restore is merge-only by design: it places the profile's pet slots but does
---NOT clear slots absent from the profile. Most pet-bar buttons are the pet's intrinsic
---tokens (attack/follow/stances + the pet's own abilities), so blanking "unused" slots
---risks stripping a different pet's built-in actions (gap #7 deliberately skipped).
---@param petslots table
function ns.RestorePetBar(petslots)
  if not IsPetActive() then return end

  -- Re-scan the token slots for each placement: placing a token swaps the two
  -- slots' contents, so a name->slot map built once goes stale across
  -- placements and would move the wrong token (B4).
  local function tokenSlot(name)
    for i = 1, NUM_PET_ACTION_SLOTS do
      local n, _, isToken = GetPetActionInfo(i)
      if isToken and n == name then return i end
    end
  end

  for _, p in ipairs(petslots) do
    if p.type == "token" then
      local from = tokenSlot(p.strindex)
      if from then
        PickupPetAction(from)
        PickupPetAction(p.id)
      end
    elseif p.type == "spell" and PickupPetSpell then
      -- PickupPetSpell is not present on every client; guard it so pet-bar restore
      -- never errors when it's absent (the spell slot is simply skipped). Both calls
      -- are gated together so PickupPetAction can't pick up the existing slot action
      -- with an empty cursor (issue #68 / B9).
      PickupPetSpell(p.index)
      PickupPetAction(p.id)
    end
    ClearCursor()
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
