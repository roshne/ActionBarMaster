local _, ns = ...

-- Active racial abilities indexed by UnitRace select(2) key.
-- Each entry is an ordered array of spell IDs (or class-variant tables).
-- Class-variant: { CLASS = spellID, ..., default = spellID }
-- Ordinal position is stable across races; a missing ordinal on restore blanks the slot.
local byRace = {
  -- Alliance Core
  Human    = { 59752 },              -- Will to Survive
  Dwarf    = { 20594 },              -- Stoneform
  NightElf = { 58984 },              -- Shadowmeld
  Gnome    = { 20589 },              -- Escape Artist
  Draenei  = {                       -- Gift of the Naaru (class-specific heal)
    { DEATHKNIGHT=59545, HUNTER=59543, MAGE=59548,   MONK=121093, PALADIN=59542,
      PRIEST=59544,      ROGUE=370626, SHAMAN=59547,  WARLOCK=416250, WARRIOR=28880 },
  },
  Worgen   = { 68992, 87840 },       -- Darkflight, Two Forms

  -- Horde Core
  Orc      = { 20572 },              -- Blood Fury
  Troll    = { 26297 },              -- Berserking
  Scourge  = { 7744,  20577 },       -- Will of the Forsaken, Cannibalize
  Tauren   = { 20549 },              -- War Stomp
  BloodElf = {                       -- Arcane Torrent (class-specific)
    { DEATHKNIGHT=50613, DEMONHUNTER=202719, HUNTER=80483, MAGE=28730,
      MONK=129597,       PALADIN=155145,     PRIEST=232633, ROGUE=25046,
      WARLOCK=28730,     WARRIOR=69179 },
  },
  Goblin   = { 69070, 69041 },       -- Rocket Jump, Rocket Barrage

  -- Neutral Core
  Pandaren = { 107079 },             -- Quaking Palm
  Dracthyr = {                       -- Tail Swipe (Evoker) / Wing Buffet (other)
    { EVOKER=368970, default=357214 },
  },

  -- Alliance Allied Races
  VoidElf            = { 256948 },   -- Spatial Rift
  LightforgedDraenei = { 255647 },   -- Light's Judgment
  DarkIronDwarf      = { 265221 },   -- Fireblood
  KulTiran           = { 287712 },   -- Haymaker
  Mechagnome         = { 312924 },   -- Hyper Organic Light Originator

  -- Horde Allied Races
  Nightborne         = { 260364 },   -- Arcane Pulse
  HighmountainTauren = { 255654 },   -- Bull Rush
  MagharOrc          = { 274738 },   -- Ancestral Call
  ZandalariTroll     = { 291944 },   -- Regeneratin'
  Vulpera            = { 312411, 275371, 296071 }, -- Bag of Tricks, Make Camp, Return to Camp

  -- Neutral Allied Races
  EarthenDwarf = { 436344 },         -- Azerite Surge
  Harronir     = { 1237885 },        -- Thorn Bloom
}

local function ResolveEntry(entry, class)
  if type(entry) == "number" then return entry end
  return entry[class] or entry.default
end

---Returns an ordered array of racial spell IDs for the given race+class.
---@param race  string  UnitRace select(2) value
---@param class string  UnitClass select(2) value
---@return number[]
function ns.GetRacialSpells(race, class)
  local entries = byRace[race]
  if not entries then return {} end
  local spells = {}
  for _, entry in ipairs(entries) do
    local id = ResolveEntry(entry, class)
    if id then spells[#spells+1] = id end
  end
  return spells
end

---Returns a set { [spellID] = ordinal } for capture-time lookup.
---@param race  string
---@param class string
---@return table
function ns.GetRacialSpellSet(race, class)
  local spells = ns.GetRacialSpells(race, class)
  local set = {}
  for i, id in ipairs(spells) do
    set[id] = i
  end
  return set
end
