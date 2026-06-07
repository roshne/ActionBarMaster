local _, ns = ...

local PickupSpell  = C_Spell and C_Spell.PickupSpell or _G.PickupSpell
local GetSpellName = C_Spell and C_Spell.GetSpellName
                  or function(id) return (GetSpellInfo(id)) end

---Returns { [professionName] = ordinal } for current character primary professions.
---Used at capture time to match action bar spell names against profession names.
function ns.GetProfessionNameMap()
  local map = {}
  if not GetProfessions then return map end
  local prof1, prof2 = GetProfessions()
  for ordinal, profIdx in ipairs({ prof1, prof2 }) do
    if profIdx then
      local profName = GetProfessionInfo(profIdx)
      if profName then map[profName] = ordinal end
    end
  end
  return map
end

---Returns the spell ID for the opener spell of the current character Nth primary profession.
---Uses GetProfessionInfo spellOffset with the Player spellbook bank, which is how
---Blizzard own ProfessionsBook picks up profession spells for drag-to-actionbar.
---@param ordinal number  1 or 2
---@return number|nil
function ns.GetProfessionSpellID(ordinal)
  if not GetProfessions then return nil end
  local prof1, prof2 = GetProfessions()
  local profIdx = (ordinal == 1 and prof1) or (ordinal == 2 and prof2)
  if not profIdx then return nil end
  local _, _, _, _, _, spellOffset = GetProfessionInfo(profIdx)
  if not spellOffset or not C_SpellBook then return nil end
  local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
  if not bank then return nil end
  local _, _, spellID = C_SpellBook.GetSpellBookItemType(spellOffset + 1, bank)
  return spellID
end

---Picks up the current character Nth primary profession opener spell onto the cursor.
---@param ordinal number  1 or 2
function ns.PickupProfessionSpell(ordinal)
  local spellID = ns.GetProfessionSpellID(ordinal)
  if spellID then PickupSpell(spellID) end
end
