local _, ns = ...

local PickupSpell  = C_Spell and C_Spell.PickupSpell or _G.PickupSpell
local GetSpellName = C_Spell and C_Spell.GetSpellName
                  or function(id) return (GetSpellInfo(id)) end

---Returns { [spellName] = { ordinal=N, slot=M } } for all spells in current character's
---primary professions. Used at capture time to match action bar spells to professions.
function ns.GetProfessionNameMap()
  local map = {}
  if not GetProfessions then return map end
  local profs = { GetProfessions() }
  for ordinal, profIdx in ipairs(profs) do
    if profIdx then
      local profName, _, _, _, numItems, spellOffset = GetProfessionInfo(profIdx)
      if profName then
        if not map[profName] then map[profName] = { ordinal = ordinal, slot = 1 } end
        if numItems and spellOffset and C_SpellBook then
          local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
          if bank then
            for i = 1, numItems do
              local _, _, spellID = C_SpellBook.GetSpellBookItemType(spellOffset + i, bank)
              if spellID then
                local name = GetSpellName(spellID)
                if name then map[name] = { ordinal = ordinal, slot = i } end
              end
            end
          end
        end
      end
    end
  end
  return map
end

---Returns the spell ID for a spell at `slot` within the current character's Nth primary profession.
---@param ordinal number  1 or 2
---@param slot number  position within profession spellbook (default 1)
---@return number|nil
function ns.GetProfessionSpellID(ordinal, slot)
  if not GetProfessions then return nil end
  local profIdx = select(ordinal, GetProfessions())
  if not profIdx then return nil end
  local _, _, _, _, _, spellOffset = GetProfessionInfo(profIdx)
  if not spellOffset or not C_SpellBook then return nil end
  local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
  if not bank then return nil end
  local _, _, spellID = C_SpellBook.GetSpellBookItemType(spellOffset + (slot or 1), bank)
  return spellID
end

---Picks up a profession spell onto the cursor.
---Tries slot-based lookup first (portable across professions), then name match, then slot 1.
---@param ordinal number  1 or 2
---@param slot number|nil  position within profession spellbook
---@param spellName string|nil  name fallback for older profiles without slot
function ns.PickupProfessionSpell(ordinal, slot, spellName)
  if not GetProfessions then return end
  local profIdx = select(ordinal, GetProfessions())
  if not profIdx then return end
  local _, _, _, _, numItems, spellOffset = GetProfessionInfo(profIdx)
  if not spellOffset or not C_SpellBook then return end
  local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
  if not bank then return end

  -- Slot-based: position is consistent across professions (slot 2 = journal for any profession)
  if slot and slot <= (numItems or 1) then
    local _, _, spellID = C_SpellBook.GetSpellBookItemType(spellOffset + slot, bank)
    if spellID then PickupSpell(spellID); return end
  end

  -- Name-based fallback for profiles captured before slot tracking was added
  if spellName and numItems then
    for i = 1, numItems do
      local _, _, spellID = C_SpellBook.GetSpellBookItemType(spellOffset + i, bank)
      if spellID and GetSpellName(spellID) == spellName then
        PickupSpell(spellID); return
      end
    end
  end

  -- Last resort: first spell in profession
  local _, _, spellID = C_SpellBook.GetSpellBookItemType(spellOffset + 1, bank)
  if spellID then PickupSpell(spellID) end
end
