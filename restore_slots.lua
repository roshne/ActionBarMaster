local _, ns = ...

-- Per-slot restore: the spell/item/racial/... pickup ladder plus the flyout pre-pass
-- and spellbook maps. Split out of restore.lua (file-size cap); ns.Restore orchestrates
-- these and owns the miss/async-item summary (ns.RestoreMiss / ns.DeferItemWarn).
local PickupSpell   = C_Spell and C_Spell.PickupSpell   or _G.PickupSpell
local PickupItem    = C_Item  and C_Item.PickupItem      or _G.PickupItem
local GetSpellLink  = C_Spell and C_Spell.GetSpellLink  or _G.GetSpellLink
local PickupSpellBookItem = C_SpellBook and C_SpellBook.PickupSpellBookItem or _G.PickupSpellBookItem
local GetSpellName  = C_Spell and C_Spell.GetSpellName
                   or function(id) return (GetSpellInfo(id)) end

local function Warn(msg)
  ns.Print("|cffff9900[Bars]|r " .. msg)
end

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


local function slotLabel(id)
  local bar = math.floor((id - 1) / 12) + 1
  local col = ((id - 1) % 12) + 1
  -- UI display label ("Bar 3", "Bonus", "Class 1", ...), not the internal bar
  -- number — internal bars 2-6 carry different display names in the grid
  return ns.GetBarLabel(bar) .. " slot " .. col .. ": "
end

-- Build override map (bidirectional base <-> override) and flyout map
-- (flyoutId -> {spellIndex, bank}) in a single spellbook pass.
-- Override map lets PickupSpell find a working ID for old profiles that stored
-- override IDs (e.g. Bear Swipe 213771 captured in shapeshift form).
function ns.BuildSpellbookMaps()
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

-- Flyout slots must be restored first, before any other PickupSpell/PlaceAction calls
-- consume the hardware event context. PickupSpellBookItem for flyout-type spellbook items
-- silently fails if called after other protected pickup operations in the same event.
function ns.RestoreFlyouts(slots, flyouts)
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

function ns.RestoreSlots(slots, overrides, flyouts, race, class)
  for _, s in ipairs(slots) do
    local slot = slotLabel(s.id)
    local ok, err = pcall(function()
      -- Neither type carries anything we can re-place (capture stores the type only),
      -- so the profile's wanted state for the slot is EMPTY — blank it, as documented.
      -- Handled before the "already matches" early-out below, which would otherwise
      -- leave a pre-existing petaction sitting in the slot, and with an explicit return
      -- so the place/blank tail can't PlaceAction the picked-up action straight back
      -- into the same slot — the round-trip this used to do (#131).
      if s.type == "petaction" or s.type == "futurespell" then
        PickupAction(s.id)
        ClearCursor()
        ns.RestoreMiss(slot .. (s.type == "petaction" and "Pet action" or "Unlearned spell")
          .. " can't be restored")
        return
      end

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
            ns.RestoreMiss(slot .. "Missing item " .. link .. suffix)
          else
            -- defer: warn (and retry placement) once the item's data loads
            ns.DeferItemWarn(s.index, s.id, slot)
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
          ns.RestoreMiss(slot .. "Missing racial #" .. s.index .. " for " .. (race or "?"))
        end
      elseif s.type == "profession" then
        ns.PickupProfessionSpell(s.index, s.profSlot, s.strindex)
        if not GetCursorInfo() then
          local what = s.strindex and ("[" .. s.strindex .. "]") or ("profession spell #" .. s.index)
          local why  = (GetProfessions and not select(s.index, GetProfessions()))
            and "profession not learned" or "spell not found"
          ns.RestoreMiss(slot .. "skipped " .. what .. " — " .. why)
        end
      elseif s.type == "macro" then
        -- handled in RestoreMacros pass; skip here
        return
      elseif s.type == "summonpet" then
        C_PetJournal.PickupPet(s.strindex, false)
        if not GetCursorInfo() then C_PetJournal.PickupPet(s.strindex, true) end
        if not GetCursorInfo() then ns.RestoreMiss(slot .. "Missing pet [" .. tostring(s.strindex) .. "]") end
      elseif s.type == "summonmount" then
        -- GetDisplayedMountInfo indexes the DISPLAYED (filtered) list, bounded by
        -- GetNumDisplayedMounts() — not GetNumMounts() (the full catalog). Pickup's
        -- arg is a 1-based luaIndex into that same displayed list. The old code looped
        -- to GetNumMounts() and fell back to Pickup(0) (Blizzard's "pick up nothing"
        -- index), which silently placed a wrong/no mount when a journal filter hid the
        -- target. Loop the displayed bound, and warn+blank on a miss like other slots.
        local mi
        if C_MountJournal then
          for i = 1, C_MountJournal.GetNumDisplayedMounts() do
            local _, _, _, _, _, _, _, _, _, _, isCollected, mid = C_MountJournal.GetDisplayedMountInfo(i)
            if isCollected and mid == s.index then mi = i; break end
          end
        end
        if mi then
          C_MountJournal.Pickup(mi)
        else
          ns.RestoreMiss(slot .. "Missing mount #" .. tostring(s.index)
            .. " (uncollected, or hidden by an active mount-journal filter)")
        end
      elseif s.type == "companion" then
        -- legacy pre-journal mount/mini-pet action; index is the summon spell ID
        PickupSpell(s.index)
        if not GetCursorInfo() then
          ns.RestoreMiss(slot .. "Missing companion " .. (GetSpellLink(s.index) or ("spell " .. s.index)))
        end
      elseif s.type == "equipmentset" then
        if C_EquipmentSet then
          local setIDs = C_EquipmentSet.GetEquipmentSetIDs() or {}
          -- resolve by name first (identity), fall back to stored list position
          local setID
          if s.strindex then
            for _, id in ipairs(setIDs) do
              if C_EquipmentSet.GetEquipmentSetInfo(id) == s.strindex then setID = id; break end
            end
          end
          setID = setID or (s.index and setIDs[s.index])
          if setID then C_EquipmentSet.PickupEquipmentSet(setID) end
          if not GetCursorInfo() then
            ns.RestoreMiss(slot .. "Missing equipment set "
              .. (s.strindex and ('[' .. s.strindex .. ']') or ('#' .. tostring(s.index))))
          end
        end
      elseif s.type == "outfit" then
        if C_TransmogOutfitInfo then
          local outfits = C_TransmogOutfitInfo.GetOutfitsInfo() or {}
          -- resolve by name first (identity), fall back to stored list position
          local outfitID
          if s.strindex then
            for _, info in ipairs(outfits) do
              if info.name == s.strindex then outfitID = info.outfitID; break end
            end
          end
          if not outfitID and s.index then
            local info = outfits[s.index]
            outfitID = info and info.outfitID
          end
          if outfitID then C_TransmogOutfitInfo.PickupOutfit(outfitID) end
          if not GetCursorInfo() then
            ns.RestoreMiss(slot .. "Missing outfit "
              .. (s.strindex and ('[' .. s.strindex .. ']') or ('#' .. tostring(s.index))))
          end
        end
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
