local _, ns = ...

local PickupSpell   = C_Spell and C_Spell.PickupSpell   or _G.PickupSpell
local PickupItem    = C_Item  and C_Item.PickupItem      or _G.PickupItem
local GetSpellLink  = C_Spell and C_Spell.GetSpellLink  or _G.GetSpellLink
local PickupSpellBookItem = C_SpellBook and C_SpellBook.PickupSpellBookItem or _G.PickupSpellBookItem

local MAX_BARS = 180

-- PickupSpell fails for some valid spells (e.g. form-specific druid abilities).
-- Fall back to picking up by spellbook index, which works regardless of current form.
local function PickupSpellFromBook(targetSid)
  if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return end
  for idx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(idx)
    for i = 1, info.numSpellBookItems do
      local si = info.itemIndexOffset + i
      local _, _, sid = C_SpellBook.GetSpellBookItemType(si, Enum.SpellBookSpellBank.Player)
      if sid == targetSid then
        PickupSpellBookItem(si, Enum.SpellBookSpellBank.Player)
        return true
      end
    end
  end
  return false
end

local function Warn(msg)
  ns.Print("|cffff9900[Bars]|r " .. msg)
end

local pendingItemWarns = {}

ns:registerEvent("GET_ITEM_INFO_RECEIVED", function(self, itemID, success)
  if pendingItemWarns[itemID] then
    local tag = pendingItemWarns[itemID]
    pendingItemWarns[itemID] = nil
    local link = success and select(2, GetItemInfo(itemID))
               or ("|Hitem:" .. itemID .. "|h[item:" .. itemID .. "]|h")
    Warn(tag .. "Missing item " .. link)
  end
end)

-- Override map: bidirectional (base <-> override).
-- New profiles store base IDs, but old profiles captured in shapeshift form may store
-- override IDs (e.g. Bear Swipe 213771). Both directions let PickupSpell find a working ID.
local function BuildOverrideMap()
  local map = {}
  if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return map end
  for idx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(idx)
    for i = 1, info.numSpellBookItems do
      local spellIndex = info.itemIndexOffset + i
      local spellType, id, spellId = C_SpellBook.GetSpellBookItemType(spellIndex, Enum.SpellBookSpellBank.Player)
      if spellId then
        local ovr = C_Spell.GetOverrideSpell(spellId)
        if ovr ~= spellId then map[spellId] = ovr; map[ovr] = spellId end
      elseif spellType == Enum.SpellBookItemType.Flyout then
        local _, _, numSlots, isKnown = GetFlyoutInfo(id)
        if isKnown and numSlots > 0 then
          for k = 1, numSlots do
            local sid, ovr = GetFlyoutSlotInfo(id, k)
            if ovr ~= sid then map[sid] = ovr; map[ovr] = sid end
          end
        end
      end
    end
  end
  return map
end

-- Flyout map: flyoutId -> {spellIndex, bank}
local function BuildFlyoutMap()
  local map = {}
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
    for idx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local info = C_SpellBook.GetSpellBookSkillLineInfo(idx)
      for i = 1, info.numSpellBookItems do
        local si = info.itemIndexOffset + i
        local typ, id = C_SpellBook.GetSpellBookItemType(si, Enum.SpellBookSpellBank.Player)
        if typ == Enum.SpellBookItemType.Flyout then
          map[id] = { si, Enum.SpellBookSpellBank.Player }
        end
      end
    end
  end
  return map
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
  local perchar = isChar and canC or (canG and false or canC)
  if not canG and not canC then
    Warn("No macro space for: " .. m.name)
    return nil
  end
  local icon = m.icon
  if strsub(m.body, 1, 12) == "#showtooltip" then icon = "INV_Misc_QuestionMark" end
  return CreateMacro(m.name, icon, m.body, perchar)
end

-- Flyout slots must be restored first, before any other PickupSpell/PlaceAction calls
-- consume the hardware event context. PickupSpellBookItem for flyout-type spellbook items
-- silently fails if called after other protected pickup operations in the same event.
local function RestoreFlyouts(slots, flyouts)
  for _, s in ipairs(slots) do
    if s.type == "flyout" then
      local curType, curIndex = GetActionInfo(s.id)
      if curType == "flyout" and curIndex == s.index then goto continue end
      local bar = math.floor((s.id - 1) / 12) + 1
      local col = ((s.id - 1) % 12) + 1
      local slot = "bar " .. bar .. " slot " .. col .. ": "
      local f = flyouts[s.index]
      if f then
        ClearCursor()
        PickupSpellBookItem(f[1], f[2])
      end
      if GetCursorInfo() then
        PlaceAction(s.id)
        ClearCursor()
      elseif f then
        local name = GetFlyoutInfo and GetFlyoutInfo(s.index)
        Warn(slot .. "drag " .. (name and "[" .. name .. "]" or "flyout " .. s.index)
          .. " from your spellbook to restore it")
      end
      ::continue::
    end
  end
end

local function RestoreSlots(slots, overrides, flyouts, race, class)
  for _, s in ipairs(slots) do
    local bar  = math.floor((s.id - 1) / 12) + 1
    local col  = ((s.id - 1) % 12) + 1
    local slot = "bar " .. bar .. " slot " .. col .. ": "
    local ok, err = pcall(function()
      local curType, curIndex = GetActionInfo(s.id)
      if curType == s.type and curIndex == (s.index or s.strindex) then return end

      if s.type == "spell" then
        PickupSpell(s.index)
        if not GetCursorInfo() and overrides[s.index] then
          PickupSpell(overrides[s.index])
        end
        local foundInBook = false
        if not GetCursorInfo() then
          foundInBook = PickupSpellFromBook(s.index)
        end
        -- only warn if the spell exists in this character's spellbook but still failed;
        -- if it's not in the book it's unavailable content (profession, expansion, etc.)
        if not GetCursorInfo() and foundInBook then
          Warn(slot .. "Unknown spell [" .. s.index .. "] " .. (GetSpellLink(s.index) or ""))
        end
      elseif s.type == "flyout" then
        -- handled in RestoreFlyouts pre-pass; skip here
        return
      elseif s.type == "item" then
        PickupItem(s.index)
        if not GetCursorInfo() and C_ToyBox then
          C_ToyBox.PickupToyBoxItem(s.index)
        end
        -- try by link string (some items only respond to this form)
        if not GetCursorInfo() then
          local link = select(2, GetItemInfo(s.index))
          if link then PickupItem(link) end
        end
        if not GetCursorInfo() then
          local link = select(2, GetItemInfo(s.index))
          if link then
            local owned = C_ToyBox and select(6, C_ToyBox.GetToyInfo(s.index))
            local suffix = (owned == false) and " (not in Toy Box)" or ""
            Warn(slot .. "Missing item " .. link .. suffix)
          else
            pendingItemWarns[s.index] = slot
            C_Item.RequestLoadItemDataByID(s.index)
          end
        end
      elseif s.type == "racial" then
        local spells  = ns.GetRacialSpells(race, class)
        local spellID = spells[s.index]
        if spellID then PickupSpell(spellID) end
        if not GetCursorInfo() then
          Warn(slot .. "Missing racial #" .. s.index .. " for " .. (race or "?"))
        end
      elseif s.type == "profession" then
        ns.PickupProfessionSpell(s.index, s.profSlot, s.strindex)
        if not GetCursorInfo() then
          Warn(slot .. "No profession in slot #" .. s.index
            .. (s.strindex and " [" .. s.strindex .. "]" or ""))
        end
      elseif s.type == "macro" then
        -- handled in RestoreMacros pass; skip here
        return
      elseif s.type == "summonpet" then
        C_PetJournal.PickupPet(s.strindex, false)
        if not GetCursorInfo() then C_PetJournal.PickupPet(s.strindex, true) end
        if not GetCursorInfo() then Warn(slot .. "Missing pet [" .. tostring(s.strindex) .. "]") end
      elseif s.type == "summonmount" then
        local mi
        if C_MountJournal then
          for i = 1, C_MountJournal.GetNumMounts() do
            local _, _, _, _, _, _, _, _, _, _, mountCol, mid = C_MountJournal.GetDisplayedMountInfo(i)
            if mountCol and mid == s.index then mi = i; break end
          end
        end
        if mi then C_MountJournal.Pickup(mi) else C_MountJournal.Pickup(0) end
      elseif s.type == "equipmentset" then
        if C_EquipmentSet then
          local setIDs = C_EquipmentSet.GetEquipmentSetIDs()
          local setID  = setIDs and setIDs[s.index]
          if setID then C_EquipmentSet.PickupEquipmentSet(setID) end
          if not GetCursorInfo() then Warn(slot .. "Missing equipment set #" .. tostring(s.index)) end
        end
      elseif s.type == "outfit" then
        if C_TransmogOutfitInfo then
          local outfits = C_TransmogOutfitInfo.GetOutfitsInfo()
          local info    = outfits and outfits[s.index]
          if info then C_TransmogOutfitInfo.PickupOutfit(info.outfitID) end
          if not GetCursorInfo() then Warn(slot .. "Missing outfit #" .. tostring(s.index)) end
        end
      elseif s.type == "petaction" or s.type == "futurespell" then
        PickupAction(s.id) -- clear
      end

      if GetCursorInfo() then
        PlaceAction(s.id)
      else
        PickupAction(s.id)  -- item not found; blank the slot
      end
      ClearCursor()
    end)
    if not ok then Warn(slot .. "Slot error: " .. tostring(err)) end
  end
end

local function RestoreMacrosAndSlots(macros, slots)
  -- build id->newId map
  local idMap = {}
  for _, m in ipairs(macros) do
    local newId = FindOrCreateMacro(m)
    if newId then idMap[m.id] = newId end
  end
  -- place macro slots
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

local function RestoreBindings(binds)
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

local function RestorePetBar(petslots)
  if not IsPetActive() then return end
  local tokens = {}
  for i = 1, NUM_PET_ACTION_SLOTS do
    local name, _, isToken = GetPetActionInfo(i)
    if isToken then tokens[name] = i end
  end
  for _, p in ipairs(petslots) do
    if p.type == "token" and tokens[p.strindex] then
      PickupPetAction(tokens[p.strindex])
      PickupPetAction(p.id)
    elseif p.type == "spell" then
      PickupPetSpell(p.index)
      PickupPetAction(p.id)
    end
    ClearCursor()
  end
end

local function ClearUnusedSlots(slots, barFilter)
  local used = {}
  for _, s in ipairs(slots) do used[s.id] = true end
  for i = 1, MAX_BARS do
    if not used[i] and GetActionInfo(i) then
      local bar = math.floor((i - 1) / 12) + 1
      if not barFilter or barFilter[bar] ~= false then
        PickupAction(i)
        ClearCursor()
      end
    end
  end
end

---Apply a profile to the current character.
---@param profile table
---@param barFilter table? optional map of bar numbers (and "pet") to bool; nil/true = restore, false = skip
function ns.Restore(profile, barFilter)
  if InCombatLockdown() then
    ns.Print("Cannot restore during combat.")
    return
  end
  local overrides = BuildOverrideMap()
  local flyouts   = BuildFlyoutMap()
  local _, race   = UnitRace("player")
  local _, class  = UnitClass("player")

  local slots    = profile.slots    or {}
  local petslots = profile.petslots or {}

  if barFilter then
    local filtered = {}
    for _, s in ipairs(slots) do
      local bar = math.floor((s.id - 1) / 12) + 1
      if barFilter[bar] ~= false then
        filtered[#filtered + 1] = s
      end
    end
    slots = filtered
    if barFilter.pet == false then petslots = {} end
  end

  RestoreFlyouts(slots, flyouts)
  RestoreMacrosAndSlots(profile.macros or {}, slots)
  RestoreSlots(slots, overrides, flyouts, race, class)
  ClearUnusedSlots(slots, barFilter)
  RestoreBindings(profile.binds or {})
  RestorePetBar(petslots)
  ns.Print("Bars restored.")
end
