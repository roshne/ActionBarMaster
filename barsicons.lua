local _, ns = ...

local function spellTex(id)
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
  return GetSpellTexture(id)
end

local function profSpellID(entry)
  local id = entry.profSlot and ns.GetProfessionSpellID(entry.index, entry.profSlot)
  if not id and entry.strindex then
    local info = ns.GetProfessionNameMap()[entry.strindex]
    if info then id = ns.GetProfessionSpellID(info.ordinal, info.slot) end
  end
  return id
end

local function getIcon(entry, macros)
  local t = entry.type
  if t == "spell" or t == "racial" then
    return spellTex(entry.index)
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
    local ids   = C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs()
    local setID = ids and ids[entry.index]
    if setID then
      local _, icon = C_EquipmentSet.GetEquipmentSetInfo(setID)
      return icon
    end
  elseif t == "outfit" then
    local outfits = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitsInfo()
    local info    = outfits and outfits[entry.index]
    return info and info.icon
  end
end

local function getPetIcon(entry)
  if entry.type == "spell" then return spellTex(entry.index) end
  -- token pet commands store a global-string key in texture, resolved via _G
  local _, texture = GetPetActionInfo(entry.id)
  return texture and _G[texture]
end

local function addTooltip(btn, entry, macros)
  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(btn._widget, "ANCHOR_TOPRIGHT", -2, 0)
    local t = entry.type
    if t == "spell" or t == "racial" then
      GameTooltip:SetSpellByID(entry.index)
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
      GameTooltip:SetSpellByID(entry.index)
    elseif t == "equipmentset" then
      local ids   = C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs()
      local setID = ids and ids[entry.index]
      local name  = setID and C_EquipmentSet.GetEquipmentSetInfo(setID) or "Equipment Set"
      GameTooltip:AddLine(name, 1, 1, 1)
    elseif t == "outfit" then
      local outfits = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitsInfo()
      local info    = outfits and outfits[entry.index]
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
ns._bar_getPetIcon    = getPetIcon
ns._bar_addTooltip    = addTooltip
ns._bar_addPetTooltip = addPetTooltip
