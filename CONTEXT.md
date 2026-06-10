# Action Bar Master — Code Context

Captures and restores action bars, keybindings, macros, pet bar, and equipment set names as shareable encoded text profiles. Depends on LibNAddOn and LibNUI.

---

## Runtime Environment

WoW runs **Lua 5.1**. All code must be Lua 5.1 compatible — no `goto`/`::label::`, no `//` integer division, no bitwise operators, no `table.unpack` (use `unpack()`).

---

## File Map

| File | Purpose |
|---|---|
| `init.lua` | Addon bootstrap; `MigrateDB` initialises `db.profiles = {}` at version 1 |
| `capture.lua` | `ns.Capture() → profile` — builds profile from current character state |
| `restore.lua` | `ns.Restore(profile)` — applies profile; no-op in combat |
| `serialize.lua` | `ns.Encode(profile) → string`, `ns.Decode(text) → profile, err`; format v2 |
| `autosave.lua` | Auto-saves on `PLAYER_ENTERING_WORLD`, `ACTIVE_TALENT_GROUP_CHANGED`; `ns.AutoSave()` |
| `profilelist.lua` | `ns.BuildProfileList(parent, onSelect) → scroll, Refresh, GetSelected, SetSelected, SetClassFilter` |
| `classfilter.lua` | `ns.BuildClassFilter(parent, position, onSelect)` — class dropdown filter widget |
| `barsview.lua` | `ns.BuildBarsGrid(parent) → { Update(profile?) }` — scrollable icon grid preview |
| `window.lua` | Main UI window — profile list, bars grid, Save/Load/Delete/Export/Import buttons |
| `libs/base64.lua` | `ns.base64.enc(bytes)`, `ns.base64.dec(str)` |
| `libs/crc32.lua` | `ns.crc32.enc(bytes) → uint32` |
| `libs/racials.lua` | `ns.GetRacialSpells(race, class)`, `ns.GetRacialSpellSet(race, class)` |
| `libs/professions.lua` | `ns.GetProfessionNameMap()`, `ns.GetProfessionSpellID(ordinal, slot)`, `ns.PickupProfessionSpell(ordinal, slot, name)` |

---

## NS API Surface

```lua
ns.Capture()                          -- → profile table (no args)
ns.Restore(profile)                   -- applies profile; no-op in combat
ns.Encode(profile)                    -- → copyable text string
ns.Decode(text)                       -- → profile, err (nil, msg on failure)
ns.AutoSave()                         -- capture + upsert autosave entry in db.profiles
ns.BuildProfileList(parent, onSelect) -- → scroll, Refresh(), GetSelected(), SetSelected(i), SetClassFilter(key)
ns.BuildClassFilter(parent, pos, onSelect)  -- class dropdown; calls onSelect(classKey|nil, specOnly)
ns.BuildBarsGrid(parent)              -- → { Update(profile?) } icon grid
ns.GetRacialSpells(race, class)       -- → ordered array of spell IDs
ns.GetRacialSpellSet(race, class)     -- → { [spellID] = ordinal }
ns.GetProfessionNameMap()             -- → { [spellName] = { ordinal=N, slot=M } }
ns.GetProfessionSpellID(ordinal, slot)-- → spellID or nil
ns.PickupProfessionSpell(ordinal, slot, name) -- puts spell on cursor
ns.Print(msg)                         -- addon-prefixed chat print (from LibNAddOn)
ns.delay(ms, fn)                      -- one-shot timer (overwrites any pending)
ns:Open()                             -- show the main window
ns.db                                 -- live ref to ActionBarMasterDB
```

---

## DB Schema (`ActionBarMasterDB`)

Managed by LibNAddOn via `X-NUI-DB` / `X-NUI-DB-VERSION`.

```lua
ActionBarMasterDB = {
  version   = 1,
  windowPos = { x = number, y = number },  -- saved window position (TOPLEFT anchor)
  profiles  = {               -- array; index 1 = most recent
    {
      name     = string,      -- display name (user-entered or "Char - Spec")
      char     = string,      -- UnitName("player") at capture time
      class    = string,      -- e.g. "WARRIOR"
      spec     = string,      -- spec display name
      encoded  = string,      -- ns.Encode() output
      autosave = bool|nil,    -- true for auto-saved entries
      savedAt  = string|nil,  -- "%Y-%m-%d %H:%M" timestamp, autosave only
    },
    ...
  },
}
```

`MigrateDB` (version 1): initialises `profiles = {}` if absent.

---

## Profile Table Structure

Produced by `ns.Capture`, consumed by `ns.Restore` and `ns.Encode`.

```lua
profile = {
  version  = 1,
  char     = string,
  class    = string,
  spec     = string,
  slots    = {
    {
      id       = int,         -- action bar slot 1–180
      type     = string,      -- see slot types below
      index    = int|nil,     -- spell ID / item ID / macro index / ordinal
      strindex = string|nil,  -- summonpet GUID, or spell name for profession fallback
      profSlot = int|nil,     -- profession spellbook slot (type="profession" only)
    }, ...
  },
  binds    = { { command=string, key1=string|nil, key2=string|nil }, ... },
  macros   = { { id=int, name=string, icon=string, body=string }, ... },
  petslots = { { id=int, type="token"|"spell", index=int|nil, strindex=string|nil }, ... },
  outfits  = { string, ... },  -- outfit names (unused at restore time; reserved)
}
```

**Slot `type` values:**

| Type | `index` | `strindex` |
|---|---|---|
| `"spell"` | base spell ID | — |
| `"racial"` | ordinal in racial spell list | — |
| `"profession"` | profession ordinal (1 or 2) | spell name fallback |
| `"macro"` | macro index | — |
| `"item"` | item ID | — |
| `"flyout"` | flyout ID | — |
| `"summonpet"` | — | pet GUID |
| `"summonmount"` | mount ID | — |
| `"equipmentset"` | position in set ID array | — |
| `"outfit"` | position in outfit list | — |
| `"companion"` | companion ID | — |
| `"petaction"` / `"futurespell"` | — | — (cleared on restore) |

---

## Serialization Format

`ns.Encode` packs the profile via `Pack` into a binary byte array, prepends a 5-byte header `[version(1)][crc32(4)]`, base64-encodes the whole frame, and wraps it in `# …` comment lines (60-char width). `ns.Decode` strips comments, base64-decodes, verifies CRC, then unpacks.

**Current format version: 2.** Version 2 adds a `profSlot` byte after `strindex` for each slot. Version 1 profiles are still readable (the `profSlot` byte is absent and defaults to 0).

---

## Racials (`libs/racials.lua`)

`byRace` table maps `UnitRace select(2)` keys to ordered spell arrays. Class-variant entries are `{ CLASS = spellID, ..., default = spellID }` tables resolved at runtime. Ordinals are stable — a missing ordinal on restore blanks that slot rather than erroring.

---

## Professions (`libs/professions.lua`)

`GetProfessionNameMap` iterates `GetProfessions()` → `GetProfessionInfo()` → spellbook entries to build a `{ [spellName] = { ordinal, slot } }` lookup used at capture time. `PickupProfessionSpell` tries slot-based lookup first (portable), then name-match fallback (for old profiles without `profSlot`), then slot 1 as a last resort.

---

## Class Filter (`classfilter.lua`)

`BuildClassFilter` builds a custom dropdown (not Blizzard's UIDropDownMenu) using a `BgFrame` menu + a full-screen transparent `catcher` frame at `(menu.level − 1)` to close the menu on outside clicks. Menu items sit at `(menu.level + 1)`. Both menu and catcher use `DIALOG` strata so level ordering applies. The catcher is hidden via a hook on the menu's `OnHide` — every hide path (item click, outside click, Escape via UISpecialFrames) funnels through `menu:Hide()`.

The player's own class is expanded into two rows: `"<Class> - <Spec>"` (current spec only, `specOnly = true`) and `"<Class> - all specs"`. The spec name in the row label is re-resolved each time the menu opens. `onSelect(classKey, specOnly)` feeds `SetClassFilter(key, specOnly)` in `profilelist.lua`, which narrows to `p.spec == playerSpec` only when the flag is set.

---

## Bars Grid (`barsview.lua`)

`BuildBarsGrid` renders a scrollable grid of 46×46 icon cells: 15 bars × 12 slots plus an optional Pet row. Column headers are pinned above the scroll area. `Update(profile)` rebuilds rows from profile data; `Update(nil)` clears the grid. Tooltips use `GameTooltip:SetOwner` with `ANCHOR_TOPRIGHT`. Icons resolved per slot type via `getIcon` / `getPetIcon`.

---

## Autosave (`autosave.lua`)

- Triggers: `PLAYER_ENTERING_WORLD` (login or reload) with a 2-second delay; `ACTIVE_TALENT_GROUP_CHANGED` with 500ms delay.
- Retries every 2 seconds if spec is not yet resolved (specName == "" or profile.spec == "Unknown").
- One autosave entry per `char + spec` — updates in place rather than appending.
- New entries are inserted at index 1 (most recent first).
- Exposes `ns.AutoSave()` so the window's "Autosave Now" button and `/bars sn` can call it directly.

---

## Slash Commands

| Command | Action |
|---|---|
| `/bars`, `/wbars` | Open the main window |
| `/bars sn` | Autosave now |

---

## Static Popups

| Key | Purpose |
|---|---|
| `ABM_CONFIRM_DELETE` | Confirm profile deletion |
| `ABM_CONFIRM_IMPORT` | Confirm restore from Import or Load |
