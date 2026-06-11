local _, ns = ...

local MAX_BARS   = 180
local MAX_MACROS = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS

-- Spell overrides: override spellId -> base spellId
-- GetActionInfo may return an override ID (e.g. Bear Swipe 213771 when captured in form).
-- Map override -> base so CaptureSlots always stores the base spell ID.
local function BuildSpellOverrides()
  local map = {}
  if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return map end

  for idx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(idx)
    for i = 1, info.numSpellBookItems do
      local spellIndex = info.itemIndexOffset + i
      local spellType, id, spellId = C_SpellBook.GetSpellBookItemType(spellIndex, Enum.SpellBookSpellBank.Player)
      if spellId then
        local ovr = C_Spell.GetOverrideSpell(spellId)
        if ovr and ovr ~= spellId then map[ovr] = spellId end  -- override -> base
      elseif spellType == Enum.SpellBookItemType.Flyout then
        local _, _, numSlots, isKnown = GetFlyoutInfo(id)
        if isKnown and numSlots > 0 then
          for k = 1, numSlots do
            local sid, ovr = GetFlyoutSlotInfo(id, k)
            if sid and ovr and ovr ~= sid then map[ovr] = sid end
          end
        end
      end
    end
  end
  return map
end

local GetSpellNameFn = C_Spell and C_Spell.GetSpellName
                    or function(id) return (GetSpellInfo(id)) end

-- Capture all non-empty action bar slots.
-- includeOutfits:  when false, slots of type "outfit" are skipped.
-- racialSet:       { [spellID] = ordinal }            racial spells stored as type="racial"
-- profSpellMap:    { [spellID] = {ordinal, slot} }    profession spells matched by spell ID
-- barFilter:       { [barNum] = bool }?               false = skip that bar's slots
local function CaptureSlots(overrides, includeOutfits, racialSet, profSpellMap, barFilter)
  local slots = {}
  for i = 1, MAX_BARS do
    local slotType, index, subType = GetActionInfo(i)
    local bar = math.floor((i - 1) / 12) + 1
    if barFilter and barFilter[bar] == false then
      slotType = nil  -- bar excluded from this capture
    end
    if slotType and slotType ~= "" then
      if slotType == "outfit" and not includeOutfits then
        -- skip
      else
        local entry = { id = i, type = slotType }
        if slotType == "spell" then
          if subType == "assistedcombat" then
            entry.index = C_AssistedCombat.GetActionSpell()
          else
            local spellID   = overrides[index] or index
            local racialN   = racialSet[spellID]
            local profInfo  = not racialN and profSpellMap[spellID]
            if racialN then
              entry.type  = "racial"
              entry.index = racialN
            elseif profInfo then
              entry.type     = "profession"
              entry.index    = profInfo.ordinal
              entry.profSlot = profInfo.slot
              entry.strindex = GetSpellNameFn(spellID)
            else
              entry.index = spellID
            end
          end
        elseif slotType == "macro" then
          -- subType means it's a temp macro; resolve real index via cursor.
          -- PickupAction is protected in combat (ADDON_ACTION_BLOCKED), and
          -- with something already held it would SWAP the cursor contents
          -- into the slot — keep the raw index in either case (B3)
          if subType and not InCombatLockdown() and not GetCursorInfo() then
            PickupAction(i)
            _, index = GetCursorInfo()
            PlaceAction(i)
          end
          entry.index = index
        elseif slotType == "item" or slotType == "flyout"
            or slotType == "companion" or slotType == "summonmount" then
          entry.index = index
        elseif slotType == "summonpet" then
          entry.strindex = index  -- GUID string
        elseif slotType == "equipmentset" then
          local setIDs = C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs()
          for pos, setID in ipairs(setIDs or {}) do
            if C_EquipmentSet.GetEquipmentSetInfo(setID) == index then
              entry.index = pos
              break
            end
          end
        elseif slotType == "outfit" then
          local outfits = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitsInfo()
          for pos, info in ipairs(outfits or {}) do
            if info.outfitID == index then
              entry.index = pos
              break
            end
          end
        end
        slots[#slots+1] = entry
      end
    end
  end
  return slots
end

-- Capture key bindings (skip unbound)
local function CaptureBindings()
  local binds = {}
  for i = 1, GetNumBindings() do
    local command, _, key1, key2 = GetBinding(i)
    if command and (key1 or key2) then
      binds[#binds+1] = { command = command, key1 = key1, key2 = key2 }
    end
  end
  return binds
end

-- Capture macros
local function CaptureMacros()
  local macros = {}
  for i = 1, MAX_MACROS do
    local name, icon, body = GetMacroInfo(i)
    if name then
      icon = gsub(strupper(icon or "INV_Misc_QuestionMark"), "INTERFACE\\ICONS\\", "")
      macros[#macros+1] = { id = i, name = name, icon = icon, body = body }
    end
  end
  return macros
end

-- Capture pet action bar
local function CapturePetBar()
  local slots = {}
  if not IsPetActive() then return slots end
  for i = 1, NUM_PET_ACTION_SLOTS do
    local name, _, isToken, _, _, _, spellID = GetPetActionInfo(i)
    if isToken then
      slots[#slots+1] = { id = i, type = "token", strindex = name }
    elseif spellID then
      slots[#slots+1] = { id = i, type = "spell", index = spellID }
    end
  end
  return slots
end

-- Build profile metadata from current character
local function ProfileMeta()
  local spec = GetSpecialization and GetSpecialization()
  local specName = spec and select(2, GetSpecializationInfo(spec)) or "Unknown"
  local _, class = UnitClass("player")
  return {
    char  = UnitName("player"),
    class = class,
    spec  = specName,
  }
end

-- Narrow a macro list to the macros actually referenced by the given slots
local function TrimMacros(macros, slots)
  local used = {}
  for _, s in ipairs(slots) do
    if s.type == "macro" and s.index then used[s.index] = true end
  end
  local r = {}
  for _, m in ipairs(macros) do
    if used[m.id] then r[#r+1] = m end
  end
  return r
end

---Capture the current character's setup into a profile table.
---With a barFilter excluding any bar, the result is a PARTIAL profile: it
---records the captured-bar set (profile.bars), becomes class/spec agnostic
---(shared across characters), drops keybinds (global, not per-bar), and trims
---macros to those the captured slots reference. Restore only touches the
---captured bars of such a profile.
---@param barFilter table? { [barNum|"pet"] = bool }; false = exclude
---@return table profile
function ns.Capture(barFilter)
  local overrides          = BuildSpellOverrides()
  local _, race            = UnitRace("player")
  local _, class           = UnitClass("player")
  local racialSet          = ns.GetRacialSpellSet(race, class)
  local profSpellMap       = ns.GetProfessionSpellMap()
  local profile = ProfileMeta()
  profile.version  = 1
  profile.slots    = CaptureSlots(overrides, true, racialSet, profSpellMap, barFilter)
  profile.binds    = CaptureBindings()
  profile.macros   = CaptureMacros()
  profile.petslots = (not barFilter or barFilter.pet ~= false) and CapturePetBar() or {}

  if barFilter then
    local bars = {}
    for b = 1, MAX_BARS / 12 do
      if barFilter[b] ~= false then bars[#bars+1] = b end
    end
    if #bars < MAX_BARS / 12 then
      profile.bars   = bars
      profile.class  = ""
      profile.spec   = ""
      profile.binds  = {}
      profile.macros = TrimMacros(profile.macros, profile.slots)
    end
  end
  return profile
end
