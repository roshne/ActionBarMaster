local _, ns = ...

-- Detection uses spell name matching rather than spellbook offsets.
-- Enum.SpellBookSpellBank.Profession does not exist; spelloffset from GetProfessionInfo
-- does not reliably map to C_SpellBook indices in 12.x. Name matching is simpler and
-- works regardless of spellbook API changes.

---Returns { [professionName] = ordinal } for the current character's primary professions.
---Used at capture time to tag matching spells.
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

---Picks up the current character's Nth primary profession window spell.
---@param ordinal number  1 or 2
function ns.PickupProfessionSpell(ordinal)
  if not GetProfessions then return end
  local prof1, prof2 = GetProfessions()
  local profIdx = (ordinal == 1 and prof1) or (ordinal == 2 and prof2)
  if not profIdx then return end
  local profName = GetProfessionInfo(profIdx)
  if profName then PickupSpell(profName) end
end
