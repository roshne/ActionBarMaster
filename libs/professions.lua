local _, ns = ...

-- Profession spells live in the Player spellbook (no separate Profession bank exists).
-- GetProfessionInfo returns spelloffset which is the base index into the Player bank.
local BANK = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player

local PickupSpellBookItem = C_SpellBook and C_SpellBook.PickupSpellBookItem
                         or _G.PickupSpellBookItem

local function SpellIDAt(offset)
  if BANK and C_SpellBook then
    local _, _, spellID = C_SpellBook.GetSpellBookItemType(offset, BANK)
    return spellID
  end
end

-- Returns { [spellID] = ordinal*1000+pos }, { [ordinal] = name }
-- ordinal 1/2 = first/second primary profession; pos = 1-based position within its spells.
function ns.GetProfessionSpellSet()
  local set   = {}
  local names = {}
  if not (GetProfessions and C_SpellBook and BANK) then return set, names end
  local prof1, prof2 = GetProfessions()
  for ordinal, profIdx in ipairs({ prof1, prof2 }) do
    if profIdx then
      local profName, _, _, _, numAbilities, spelloffset = GetProfessionInfo(profIdx)
      names[ordinal] = profName
      for i = 1, (numAbilities or 0) do
        local spellID = SpellIDAt(spelloffset + i)
        if spellID then
          set[spellID] = ordinal * 1000 + i
        end
      end
    end
  end
  return set, names
end

-- Picks up the profession spell at encoded position onto the cursor.
-- encoded = ordinal*1000+pos. No-ops if the character lacks that profession or the slot.
function ns.PickupProfessionSpell(encoded)
  if not (GetProfessions and PickupSpellBookItem) then return end
  local ordinal = math.floor(encoded / 1000)
  local pos     = encoded % 1000
  local prof1, prof2 = GetProfessions()
  local profIdx = (ordinal == 1 and prof1) or (ordinal == 2 and prof2)
  if not profIdx then return end
  local _, _, _, _, numAbilities, spelloffset = GetProfessionInfo(profIdx)
  if not numAbilities or pos > numAbilities then return end
  PickupSpellBookItem(spelloffset + pos, BANK or "spell")
end
