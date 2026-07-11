local _, ns = ...

local GetSpellName = C_Spell and C_Spell.GetSpellName
                  or function(id) return (GetSpellInfo(id)) end

local function spellTex(id)
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
  return GetSpellTexture(id)
end

-- Battle-pet name for a stored pet GUID, or nil if it no longer resolves
-- (pet caged/released since capture).
local function petName(petID)
  if not (C_PetJournal and petID) then return end
  local _, customName, _, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(petID)
  return customName or name
end

-- Resolve a captured equipment-set slot to a live set ID by stored NAME (identity)
-- first, falling back to the captured list position for pre-identity profiles — the same
-- name-first resolution restore.lua uses, so the grid preview matches what restore places.
local function resolveSetID(entry)
  local ids = C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs()
  if not ids then return nil end
  if entry.strindex then
    for _, id in ipairs(ids) do
      if C_EquipmentSet.GetEquipmentSetInfo(id) == entry.strindex then return id end
    end
  end
  return ids[entry.index]
end

-- Resolve a captured outfit slot to its live outfit info by stored NAME first, else position.
local function resolveOutfit(entry)
  local outfits = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitsInfo()
  if not outfits then return nil end
  if entry.strindex then
    for _, info in ipairs(outfits) do
      if info.name == entry.strindex then return info end
    end
  end
  return outfits[entry.index]
end

local function profSpellID(entry)
  local id = entry.profSlot and ns.GetProfessionSpellID(entry.index, entry.profSlot)
  if not id and entry.strindex then
    local info = ns.GetProfessionNameMap()[entry.strindex]
    if info then id = ns.GetProfessionSpellID(info.ordinal, info.slot) end
  end
  return id
end

-- Racial entries store the ORDINAL in the racial spell list, not a spell ID.
-- Resolve against the viewing character's race/class — same as restore does —
-- so the grid shows what a Load would actually place on this character.
local function racialSpellID(ordinal)
  local _, race  = UnitRace("player")
  local _, class = UnitClass("player")
  return ns.GetRacialSpells(race, class)[ordinal]
end

local function getIcon(entry, macros)
  local t = entry.type
  if t == "spell" then
    return spellTex(entry.index)
  elseif t == "racial" then
    local sid = racialSpellID(entry.index)
    if sid then return spellTex(sid) end
  elseif t == "profession" then
    local spellID = profSpellID(entry)
    if spellID then return spellTex(spellID) end
  elseif t == "macro" then
    for _, m in ipairs(macros) do
      if m.id == entry.index then
        local ic = m.icon or "INV_Misc_QuestionMark"
        local n  = tonumber(ic)
        if n then return n end
        if not ic:find("\\") and not ic:find("/") then
          return "Interface\\Icons\\" .. ic
        end
        return ic
      end
    end
  elseif t == "flyout" then
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
      for idx = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(idx)
        if info then
          for i = 1, info.numSpellBookItems do
            local si = info.itemIndexOffset + i
            local spellType, id = C_SpellBook.GetSpellBookItemType(si, Enum.SpellBookSpellBank.Player)
            if spellType == Enum.SpellBookItemType.Flyout and id == entry.index then
              return C_SpellBook.GetSpellBookItemTexture(si, Enum.SpellBookSpellBank.Player)
            end
          end
        end
      end
    end
    -- fallback: first known spell inside the flyout (pre-10.0 or flyout not in spellbook)
    local _, _, numSlots = GetFlyoutInfo(entry.index)
    if numSlots and numSlots > 0 then
      for i = 1, numSlots do
        local spellID, _, isKnown = GetFlyoutSlotInfo(entry.index, i)
        if spellID and spellID > 0 and isKnown then return spellTex(spellID) end
      end
    end
  elseif t == "item" then
    return GetItemIcon(entry.index)
  elseif t == "summonmount" then
    local _, _, icon = C_MountJournal.GetMountInfoByID(entry.index)
    return icon
  elseif t == "companion" then
    -- legacy pre-journal mount/mini-pet action; index is the summon spell ID
    return spellTex(entry.index)
  elseif t == "equipmentset" then
    local setID = resolveSetID(entry)
    if setID then
      local _, icon = C_EquipmentSet.GetEquipmentSetInfo(setID)
      return icon
    end
  elseif t == "outfit" then
    local info = resolveOutfit(entry)
    return info and info.icon
  elseif t == "summonpet" then
    if C_PetJournal and entry.strindex then
      return select(9, C_PetJournal.GetPetInfoByPetID(entry.strindex))
    end
  end
end

local function getPetIcon(entry)
  if entry.type == "spell" then return spellTex(entry.index) end
  -- token pet commands store a global-string key in texture, resolved via _G
  local _, texture = GetPetActionInfo(entry.id)
  return texture and _G[texture]
end

-- Display name for a captured slot (the read-only preview's hover tooltip; the
-- interactive grid uses the richer addTooltip instead). Reuses the same name-first
-- resolution as addTooltip so the preview matches what the grid shows.
local function getName(entry, macros)
  local t = entry.type
  if t == "spell" or t == "companion" then
    return GetSpellName(entry.index)
  elseif t == "racial" then
    local sid = racialSpellID(entry.index)
    return sid and GetSpellName(sid)
  elseif t == "profession" then
    local sid = profSpellID(entry)
    return (sid and GetSpellName(sid)) or entry.strindex
  elseif t == "macro" then
    for _, m in ipairs(macros) do
      if m.id == entry.index then return m.name end
    end
  elseif t == "flyout" then
    return (GetFlyoutInfo(entry.index))
  elseif t == "item" then
    return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(entry.index)
  elseif t == "summonmount" then
    return (C_MountJournal.GetMountInfoByID(entry.index))
  elseif t == "summonpet" then
    return petName(entry.strindex) or "Battle Pet"
  elseif t == "equipmentset" then
    local setID = resolveSetID(entry)
    return (setID and C_EquipmentSet.GetEquipmentSetInfo(setID)) or "Equipment Set"
  elseif t == "outfit" then
    local info = resolveOutfit(entry)
    return info and info.name or "Outfit"
  end
end

local function addTooltip(btn, entry, macros)
  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(btn._widget, "ANCHOR_TOPRIGHT", -2, 0)
    local t = entry.type
    if t == "spell" then
      -- guard invalid IDs (a captured spell whose ID churned out of existence):
      -- SetSpellByID on an unknown ID leaves the tooltip blank/erroring
      if GetSpellName(entry.index) then GameTooltip:SetSpellByID(entry.index)
      else GameTooltip:AddLine("Unknown spell #" .. tostring(entry.index), 1, 1, 1) end
    elseif t == "racial" then
      local sid = racialSpellID(entry.index)
      if sid then GameTooltip:SetSpellByID(sid)
      else GameTooltip:AddLine("Racial #" .. tostring(entry.index), 1, 1, 1) end
    elseif t == "profession" then
      local sid = profSpellID(entry)
      if sid then GameTooltip:SetSpellByID(sid)
      else GameTooltip:AddLine(entry.strindex or "?", 1, 1, 1) end
    elseif t == "macro" then
      for _, m in ipairs(macros) do
        if m.id == entry.index then
          GameTooltip:AddLine(m.name or "?", 1, 1, 1); break
        end
      end
    elseif t == "flyout" then
      local name = GetFlyoutInfo(entry.index)
      GameTooltip:AddLine(name or "Flyout", 1, 1, 1)
    elseif t == "item" then
      GameTooltip:SetHyperlink("item:" .. entry.index)
    elseif t == "summonmount" then
      local _, spellID = C_MountJournal.GetMountInfoByID(entry.index)
      if spellID then GameTooltip:SetSpellByID(spellID) end
    elseif t == "companion" then
      if GetSpellName(entry.index) then GameTooltip:SetSpellByID(entry.index)
      else GameTooltip:AddLine("Companion #" .. tostring(entry.index), 1, 1, 1) end
    elseif t == "summonpet" then
      GameTooltip:AddLine(petName(entry.strindex) or "Battle pet (not in collection)", 1, 1, 1)
    elseif t == "equipmentset" then
      local setID = resolveSetID(entry)
      local name  = setID and C_EquipmentSet.GetEquipmentSetInfo(setID) or "Equipment Set"
      GameTooltip:AddLine(name, 1, 1, 1)
    elseif t == "outfit" then
      local info = resolveOutfit(entry)
      GameTooltip:AddLine(info and info.name or "Outfit", 1, 1, 1)
    end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function addPetTooltip(btn, entry)
  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(btn._widget, "ANCHOR_TOPRIGHT", -2, 0)
    if entry.type == "spell" then
      GameTooltip:SetSpellByID(entry.index)
    else
      local _, _, _, _, _, _, spellID = GetPetActionInfo(entry.id)
      if spellID and spellID > 0 then
        GameTooltip:SetSpellByID(spellID)
      elseif entry.strindex then
        GameTooltip:AddLine(entry.strindex, 1, 1, 1)
      end
    end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

ns._bar_getIcon       = getIcon
ns._bar_getName       = getName
ns._bar_getPetIcon    = getPetIcon
ns._bar_addTooltip    = addTooltip
ns._bar_addPetTooltip = addPetTooltip
