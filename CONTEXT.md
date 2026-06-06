# Warbandeer Bars RGS — Code Context

Captures and restores action bars, keybindings, macros, pet bar, and equipment set names as shareable encoded text profiles. Depends on LibNAddOn and LibNUI.

---

## File Map

| File | Purpose |
|---|---|
| `init.lua` | Addon bootstrap, `DefaultSettings`, `MigrateDB`, `onLoad` (initialises `ns.settings`) |
| `capture.lua` | `ns.Capture(include, accountMacros, charMacros) → profile` |
| `restore.lua` | `ns.Restore(profile, include)` — applies profile to current character |
| `serialize.lua` | `ns.Encode(profile) → string`, `ns.Decode(text) → profile, err` |
| `autosave.lua` | Auto-saves on `PLAYER_LOGIN`, `PLAYER_LOGOUT`, `ACTIVE_TALENT_GROUP_CHANGED` |
| `profilelist.lua` | `ns.BuildProfileList(parent, onSelect) → scroll, Refresh(), GetSelected()` |
| `window.lua` | Main UI window — Export/Import/Save/Load/Delete, checkbox row, static popups |
| `libs/base64.lua` | `ns.base64.enc(bytes)`, `ns.base64.dec(str)` |
| `libs/crc32.lua` | `ns.crc32.enc(bytes) → uint32` |

---

## NS API Surface

```lua
ns.Capture(include, accountMacros, charMacros)  -- → profile table
ns.Restore(profile, include)                    -- applies profile; no-op in combat
ns.Encode(profile)                              -- → copyable text string
ns.Decode(text)                                 -- → profile, err (nil, msg on failure)
ns.BuildProfileList(parent, onSelect)           -- → scroll, Refresh(), GetSelected()
ns.Print(msg)                                   -- addon-prefixed chat print (from LibNAddOn)
ns.delay(ms, fn)                               -- one-shot timer (overwrites any pending)
ns:Open()                                       -- show the main window
ns.settings                                     -- live ref to WarbandeerBarsRGSSettings
ns.db                                           -- live ref to WarbandeerBarsRGSDB
```

---

## DB Schema (`WarbandeerBarsRGSDB`)

Managed by LibNAddOn via `X-NUI-DB` / `X-NUI-DB-VERSION`.

```lua
WarbandeerBarsRGSDB = {
  version  = 1,
  profiles = {               -- array; index 1 = most recent
    {
      name     = string,     -- display name (user-entered or auto "Char - Spec")
      char     = string,     -- UnitName("player") at capture time
      class    = string,     -- e.g. "WARRIOR"
      spec     = string,     -- spec display name
      encoded  = string,     -- ns.Encode() output
      autosave = bool|nil,   -- true for auto-saved entries
    },
    ...
  },
}
```

`MigrateDB` (version 1): initialises `profiles = {}` if absent.

---

## Settings Schema (`WarbandeerBarsRGSSettings`, per-character)

Managed manually in `onLoad` (not via LibNAddOn DB system).

```lua
WarbandeerBarsRGSSettings = {
  include = {
    bars     = bool,   -- default true
    bindings = bool,   -- default true
    macros   = bool,   -- default true
    petbar   = bool,   -- default false
    outfits  = bool,   -- default true
  },
  accountMacros = bool,  -- default true
  charMacros    = bool,  -- default true
}
```

---

## Profile Table Structure

Produced by `ns.Capture`, consumed by `ns.Restore` and `ns.Encode`.

```lua
profile = {
  version  = 1,
  char     = string,
  class    = string,
  spec     = string,
  slots    = { { id=int, type=string, index=int|nil, strindex=string|nil }, ... },
  binds    = { { command=string, key1=string|nil, key2=string|nil }, ... },
  macros   = { { id=int, name=string, icon=string, body=string }, ... },
  petslots = { { id=int, type=string, index=int|nil, strindex=string|nil }, ... },
  outfits  = { string, ... },   -- equipment set names
}
```

Slot `type` values: `"spell"`, `"macro"`, `"item"`, `"flyout"`, `"summonpet"`, `"summonmount"`, `"equipmentset"`, `"companion"`, `"petaction"`, `"futurespell"`.

---

## Serialization Format

`ns.Encode` packs the profile into a binary buffer, prepends a 5-byte header `[version(1)][crc32(4)]`, base64-encodes it, and wraps it in `# …` comment lines (60-char line width). `ns.Decode` strips comments, base64-decodes, verifies CRC, then unpacks.

---

## Slash Commands

| Command | Action |
|---|---|
| `/bars`, `/wbars` | Open the main window |

---

## Static Popups

| Key | Purpose |
|---|---|
| `WBARSRGS_CONFIRM_IMPORT` | Confirm restore from Import or Load |
| `WBARSRGS_SAVE_NAME` | Enter a name when saving a profile |
