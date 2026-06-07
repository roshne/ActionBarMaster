local _, ns = ...

-- Prefer new C_SpellBook Profession bank; fall back to old BOOKTYPE_PROFESSION string.
local BANK = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Profession

local function ProfessionSpellID(offset)
  if BANK and C_SpellBook then
    local _, _, id = C_SpellBook.GetSpellBookItemType(offset, BANK)
    return id
  elseif GetSpellBookItemInfo then
    local _, id = GetSpellBookItemInfo(offset, "profession")
    return id
  end
end

-- Builds two tables for capture-time use:
--   set   { [spellID] = ordinal*1000+pos }  -- quick lookup
--   names { [ordinal] = professionName }    -- for warning messages
-- ordinal 1 = first primary profession, 2 = second primary profession.
-- pos = position within that profession's spellbook (1-based).
function ns.GetProfessionSpellSet()
  local set   = {}
  local names = {}
  if not GetProfessions then return set, names end
  local prof1, prof2 = GetProfessions()
  for ordinal, profIdx in ipairs({ prof1, prof2 }) do
    if profIdx then
      local profName, _, _, _, numAbilities, spelloffset = GetProfessionInfo(profIdx)
      names[ordinal] = profName
      for i = 1, (numAbilities or 0) do
        local spellID = ProfessionSpellID(spelloffset + i)
        if spellID then
          set[spellID] = ordinal * 1000 + i
        end
      end
    end
  end
  return set, names
end

-- Returns the spell ID for the given encoded value on the current character.
-- encoded = ordinal*1000+pos; returns nil if the character lacks that profession
-- or the profession has fewer spells than pos.
function ns.GetProfessionSpell(encoded)
  if not GetProfessions then return nil end
  local ordinal = math.floor(encoded / 1000)
  local pos     = encoded % 1000
  local prof1, prof2 = GetProfessions()
  local profIdx = (ordinal == 1 and prof1) or (ordinal == 2 and prof2)
  if not profIdx then return nil end
  local _, _, _, _, numAbilities, spelloffset = GetProfessionInfo(profIdx)
  if not numAbilities or pos > numAbilities then return nil end
  return ProfessionSpellID(spelloffset + pos)
end
