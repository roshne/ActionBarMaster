-- 212: unused arguments; 21/_.*: unused locals deliberately named with a _ prefix
ignore = {"212", "21/_.*"}
max_line_length = 160
max_comment_line_length = 500

-- CI installs the Lua toolchain into the workspace (leafo/gh-actions-lua and
-- -luarocks); keep `luacheck .` off those trees.
exclude_files = {".lua", ".luarocks", ".install"}

-- Specs run under busted and load the addon files via loadfile, stubbing a
-- couple of WoW globals.
files["spec/**/*.lua"] = {
  std = "+busted",
  read_globals = {"loadfile", "assert", "require", "select", "math", "ipairs", "table", "string"},
  globals = {"bit", "IsWindowsClient", "_G.bit", "_G.IsWindowsClient"},
}

std = {
  globals = {
    "_G",
    "SlashCmdList",
    "StaticPopupDialogs",
  },
  read_globals = {
    -- Lua / WoW base
    "bit", "date", "floor", "format", "gsub", "ipairs", "math", "next", "pairs",
    "pcall", "print", "select", "setmetatable", "string", "strsub", "strtrim",
    "strupper", "table", "tonumber", "tostring", "type", "unpack", "wipe",
    "Mixin", "CopyTable", "IsWindowsClient",

    -- addon namespace globals (this addon + LibNAddOn library)
    "LibNAddOn",

    -- UI strings / fonts / colors
    "ACCEPT", "CANCEL", "DELETE", "YES", "NO",
    "GameFontHighlightSmall", "ITEM_QUALITY_COLORS",

    -- frames / widgets / helpers
    "CreateFrame", "CreateAtlasMarkup", "GameTooltip", "UIParent", "UISpecialFrames",
    "StaticPopup_Show", "GetAtlasInfo", "hooksecurefunc", "ClearCursor", "GetCursorInfo",
    "GetCursorPosition", "Minimap", "MenuUtil", "IsShiftKeyDown",

    -- C_* namespaces
    "C_ActionBar", "C_AssistedCombat", "C_ClassColor", "C_EquipmentSet", "C_Item", "C_MountJournal",
    "C_PetJournal", "C_Spell", "C_SpellBook", "C_ToyBox", "C_TransmogOutfitInfo",
    "Enum",

    -- action bars / spells / items / macros / bindings
    "GetActionInfo", "GetFlyoutInfo", "GetFlyoutSlotInfo", "GetItemIcon", "GetItemInfo",
    "GetMacroInfo", "GetPetActionInfo", "GetSpellInfo", "GetSpellLink", "GetSpellTexture",
    "CreateMacro", "GetNumMacros",
    "PickupAction", "PickupMacro", "PickupItem", "PickupPetAction", "PickupPetSpell",
    "PickupSpell", "PickupSpellBookItem", "PlaceAction", "PlayerHasToy",
    "C_KeyBindings", "GetBinding", "GetCurrentBindingSet", "GetNumBindings",
    "SaveBindings", "SetBinding",

    -- character / professions / spec
    "GetProfessions", "GetProfessionInfo", "GetSpecialization", "GetSpecializationInfo",
    "InCombatLockdown", "IsPetActive", "IsSpellKnown",
    "UnitClass", "UnitName", "UnitRace", "UnitSex",

    -- macros constants
    "MAX_ACCOUNT_MACROS", "MAX_CHARACTER_MACROS", "NUM_PET_ACTION_SLOTS",
  },
}
