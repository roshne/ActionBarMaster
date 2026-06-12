local _, ns = ...

local PickupSpell   = C_Spell and C_Spell.PickupSpell   or _G.PickupSpell
local PickupItem    = C_Item  and C_Item.PickupItem      or _G.PickupItem
local GetSpellLink  = C_Spell and C_Spell.GetSpellLink  or _G.GetSpellLink
local PickupSpellBookItem = C_SpellBook and C_SpellBook.PickupSpellBookItem or _G.PickupSpellBookItem
local GetSpellName  = C_Spell and C_Spell.GetSpellName
                   or function(id) return (GetSpellInfo(id)) end

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

-- Last-resort pickup by spell NAME: class-variant racials (Orc Blood Fury) are
-- separate spells per class sharing one name — if the variant table ever
-- drifts, the known variant is still findable by name.
local function PickupSpellFromBookByName(name)
  if not name or not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return end
  for idx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(idx)
    for i = 1, info.numSpellBookItems do
      local si = info.itemIndexOffset + i
      local _, _, sid = C_SpellBook.GetSpellBookItemType(si, Enum.SpellBookSpellBank.Player)
      if sid and GetSpellName(sid) == name then
        PickupSpellBookItem(si, Enum.SpellBookSpellBank.Player)
        return true
      end
    end
  end
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

-- Build override map (bidirectional base <-> override) and flyout map
-- (flyoutId -> {spellIndex, bank}) in a single spellbook pass.
-- Override map lets PickupSpell find a working ID for old profiles that stored
-- override IDs (e.g. Bear Swipe 213771 captured in shapeshift form).
local function BuildSpellbookMaps()
  local overrides, flyouts = {}, {}
  if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return overrides, flyouts end
  for idx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(idx)
    for i = 1, info.numSpellBookItems do
      local si = info.itemIndexOffset + i
      local spellType, id, spellId = C_SpellBook.GetSpellBookItemType(si, Enum.SpellBookSpellBank.Player)
      if spellId then
        local ovr = C_Spell.GetOverrideSpell(spellId)
        if ovr and ovr ~= spellId then overrides[spellId] = ovr; overrides[ovr] = spellId end
      elseif spellType == Enum.SpellBookItemType.Flyout then
        local _, _, numSlots, isKnown = GetFlyoutInfo(id)
        if isKnown and numSlots > 0 then
          for k = 1, numSlots do
            local sid, ovr = GetFlyoutSlotInfo(id, k)
            if sid and ovr and ovr ~= sid then overrides[sid] = ovr; overrides[ovr] = sid end
          end
        end
        if not flyouts[id] then flyouts[id] = { si, Enum.SpellBookSpellBank.Player } end
      end
    end
  end
  return overrides, flyouts
end


local function slotLabel(id)
  local bar = math.floor((id - 1) / 12) + 1
  local col = ((id - 1) % 12) + 1
  -- UI display label ("Bar 3", "Bonus", "Class 1", ...), not the internal bar
  -- number — internal bars 2-6 carry different display names in the grid
  return ns.GetBarLabel(bar) .. " slot " .. col .. ": "
end

-- Flyout slots must be restored first, before any other PickupSpell/PlaceAction calls
-- consume the hardware event context. PickupSpellBookItem for flyout-type spellbook items
-- silently fails if called after other protected pickup operations in the same event.
local function RestoreFlyouts(slots, flyouts)
  for _, s in ipairs(slots) do
    if s.type == "flyout" then
      local curType, curIndex = GetActionInfo(s.id)
      if not (curType == "flyout" and curIndex == s.index) then
        local slot = slotLabel(s.id)
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
      end
    end
  end
end

local function RestoreSlots(slots, overrides, flyouts, race, class)
  for _, s in ipairs(slots) do
    local slot = slotLabel(s.id)
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
            local isToy  = C_ToyBox and C_ToyBox.GetToyInfo(s.index)
            local suffix = (isToy and not PlayerHasToy(s.index)) and " (not in Toy Box)" or ""
            Warn(slot .. "Missing item " .. link .. suffix)
          else
            pendingItemWarns[s.index] = slot
            C_Item.RequestLoadItemDataByID(s.index)
          end
        end
      elseif s.type == "racial" then
        -- same fallback ladder as the spell branch: racials with class
        -- variants (e.g. Orc Blood Fury) live in the spellbook as the base
        -- spell with an override active, and PickupSpell can fail for the
        -- base ID — retry the override ID, then pick up by spellbook index
        local spells  = ns.GetRacialSpells(race, class)
        local spellID = spells[s.index]
        if spellID then
          PickupSpell(spellID)
          if not GetCursorInfo() and overrides[spellID] then
            PickupSpell(overrides[spellID])
          end
          if not GetCursorInfo() then
            PickupSpellFromBook(spellID)
          end
          if not GetCursorInfo() and overrides[spellID] then
            PickupSpellFromBook(overrides[spellID])
          end
          if not GetCursorInfo() then
            PickupSpellFromBookByName(GetSpellName(spellID))
          end
        end
        if not GetCursorInfo() then
          Warn(slot .. "Missing racial #" .. s.index .. " for " .. (race or "?"))
        end
      elseif s.type == "profession" then
        ns.PickupProfessionSpell(s.index, s.profSlot, s.strindex)
        if not GetCursorInfo() then
          local what = s.strindex and ("[" .. s.strindex .. "]") or ("profession spell #" .. s.index)
          local why  = (GetProfessions and not select(s.index, GetProfessions()))
            and "profession not learned" or "spell not found"
          Warn(slot .. "skipped " .. what .. " — " .. why)
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
      elseif s.type == "companion" then
        -- legacy pre-journal mount/mini-pet action; index is the summon spell ID
        PickupSpell(s.index)
        if not GetCursorInfo() then
          Warn(slot .. "Missing companion " .. (GetSpellLink(s.index) or ("spell " .. s.index)))
        end
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


---Apply a profile to the current character.
---@param profile table
---@param barFilter table? optional map of bar numbers (and "pet") to bool; nil/true = restore, false = skip
function ns.Restore(profile, barFilter)
  if InCombatLockdown() then
    ns.Print("Cannot restore during combat.")
    return
  end
  local overrides, flyouts = BuildSpellbookMaps()
  local _, race   = UnitRace("player")
  local _, class  = UnitClass("player")

  local slots    = profile.slots    or {}
  local petslots = profile.petslots or {}

  -- Partial profiles only touch their captured bars: restrict slot restore AND
  -- unused-slot clearing to the intersection of the captured set and the
  -- caller's barFilter. Bars outside the captured set are left untouched.
  if profile.bars then
    local captured = {}
    for _, b in ipairs(profile.bars) do captured[b] = true end
    local merged = {}
    for b = 1, MAX_BARS / 12 do
      merged[b] = (captured[b] and (not barFilter or barFilter[b] ~= false)) or false
    end
    merged.pet = ((#petslots > 0) and (not barFilter or barFilter.pet ~= false)) or false
    barFilter = merged
  end

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
  ns.RestoreMacrosAndSlots(profile.macros or {}, slots)
  RestoreSlots(slots, overrides, flyouts, race, class)
  ns.ClearUnusedSlots(slots, barFilter)
  if #(profile.binds or {}) > 0 then
    ns.RestoreBindings(profile.binds)
  end
  ns.RestorePetBar(petslots)
  ns.Print("Bars restored.")
end
