# Action Bar Master — Code Context

Captures and restores action bars, keybindings, macros, pet bar, and equipment set names as shareable encoded text profiles. Depends on LibNAddOn and LibNUI.

---

## Runtime Environment

WoW runs **Lua 5.1**. All code must be Lua 5.1 compatible — no `goto`/`::label::`, no `//` integer division, no bitwise operators, no `table.unpack` (use `unpack()`).

---

## File Map

| File | Purpose |
|---|---|
| `init.lua` | Addon bootstrap; `ns.CaptureEscape(frame)`; `MigrateDB` (v1: `profiles = {}`, v2: seeds `barOrder`) |
| `capture.lua` | `ns.Capture() → profile` — builds profile from current character state |
| `restore.lua` | `ns.Restore(profile, barFilter?)` — applies profile; no-op in combat. Flyout pre-pass + per-slot restore |
| `restore_pass.lua` | Helper passes: `ns.RestoreMacrosAndSlots`, `ns.RestoreBindings`, `ns.RestorePetBar`, `ns.ClearUnusedSlots` |
| `serialize.lua` | `ns.Encode(profile) → string`, `ns.Decode(text) → profile, err`; format v2 |
| `autosave.lua` | Auto-saves on `PLAYER_ENTERING_WORLD`, `ACTIVE_TALENT_GROUP_CHANGED`; `ns.AutoSave()` |
| `profilelist.lua` | `ns.BuildProfileList(parent, onSelect) → scroll, Refresh, GetSelected, SetSelected, SetClassFilter`; pooled rows |
| `classfilter.lua` | `ns.BuildClassFilter(parent, position, onSelect)` — class dropdown filter widget |
| `barsicons.lua` | Icon + tooltip resolvers per slot type (`ns._bar_getIcon` / `_getPetIcon` / `_addTooltip` / `_addPetTooltip`) |
| `barsview_defs.lua` | `BAR_DEFS` (abm ↔ display label) + `ns.GetActiveBarOrder()` from `db.barOrder` + `ns.GetBarLabel(abm)` |
| `barsview_drag.lua` | `ns.BuildRowDrag(opts)` — phantom row / drop line / catcher drag-to-reorder machinery |
| `barsview.lua` | `ns.BuildBarsGrid(parent) → { Update(profile?), GetChecked() }` — pooled icon grid preview |
| `window.lua` | Main UI window — wires list, filter, grid, buttons, and static popups together |
| `window_dialogs.lua` | `ns.BuildSaveDialog`, `ns.BuildExportDialog`, `ns.BuildImportDialog` modal builders |
| `debug.lua` | `/bars debug <sub>` commands; scrollable copyable output window |
| `libs/base64.lua` | `ns.base64.enc(bytes)`, `ns.base64.dec(str)` |
| `libs/crc32.lua` | `ns.crc32.enc(bytes) → uint32` |
| `libs/racials.lua` | `ns.GetRacialSpells(race, class)`, `ns.GetRacialSpellSet(race, class)` |
| `libs/professions.lua` | `ns.GetProfessionNameMap()`, `ns.GetProfessionSpellID(ordinal, slot)`, `ns.PickupProfessionSpell(ordinal, slot, name)` |

---

## NS API Surface

```lua
ns.CaptureEscape(frame)               -- close frame on Escape w/o CloseSpecialWindows (frame must not be `special`)
ns.Capture()                          -- → profile table (no args)
ns.Restore(profile, barFilter?)       -- applies profile; no-op in combat. barFilter: { [barNum|"pet"] = bool }, false = skip
ns.Encode(profile)                    -- → copyable text string
ns.Decode(text)                       -- → profile, err (nil, msg on failure)
ns.AutoSave()                         -- capture + upsert autosave entry in db.profiles
ns.RestoreMacrosAndSlots(macros, slots) -- ensure macros exist, place macro slots
ns.RestoreBindings(binds)             -- apply + persist key bindings
ns.RestorePetBar(petslots)            -- apply pet bar (no-op without active pet)
ns.ClearUnusedSlots(slots, barFilter?) -- blank action slots absent from profile
ns.BuildProfileList(parent, onSelect) -- → scroll, Refresh(), GetSelected(), SetSelected(i), SetClassFilter(key, specOnly)
ns.BuildClassFilter(parent, pos, onSelect)  -- class dropdown; calls onSelect(classKey|nil, specOnly)
ns.BuildBarsGrid(parent)              -- → { Update(profile?), GetChecked() } pooled icon grid
ns.BuildRowDrag(opts)                 -- → { Start(orderIdx, label), Finish(mouseButton) } drag-to-reorder
ns.GetActiveBarOrder()                -- → ordered { abm, label } defs from db.barOrder
ns.GetBarLabel(abm)                   -- → UI display label for an abm bar number (5 -> "Bar 3")
ns.BuildSaveDialog(parent, onSaved)   -- → dialog (._nameBox); Save Profile modal
ns.BuildExportDialog(parent)          -- → dialog (._box); read-only encoded text
ns.BuildImportDialog(parent, onImport) -- → dialog (._box); decodes paste, calls onImport(profile)
ns.GetRacialSpells(race, class)       -- → ordered array of spell IDs
ns.GetRacialSpellSet(race, class)     -- → { [spellID] = ordinal }
ns.GetProfessionNameMap()             -- → { [spellName] = { ordinal=N, slot=M } } (old-profile fallback)
ns.GetProfessionSpellMap()            -- → { [spellID] = { ordinal=N, slot=M } } (capture-time match)
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
  version   = 2,
  windowPos = { x = number, y = number },  -- saved window position (TOPLEFT anchor)
  barOrder  = { int, ... },   -- abm bar numbers in display order (drag-to-reorder)
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

`MigrateDB`: v1 initialises `profiles = {}`; v2 seeds `barOrder` with the hardcoded default display order (kept in sync with `BAR_DEFS` in `barsview_defs.lua`, but deliberately frozen in `init.lua`).

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

## Restore Order (`restore.lua` + `restore_pass.lua`)

`ns.Restore(profile, barFilter?)` runs the passes in this fixed order:

1. **`RestoreFlyouts`** — flyout slots FIRST, before any other pickup/place call. `PickupSpellBookItem` for flyout-type spellbook items silently fails if called after other protected pickup operations in the same hardware event. Do not reorder.
2. **`RestoreMacrosAndSlots`** — find-or-create each profile macro (matched by name + trimmed body), then place macro slots via the old→new index map.
3. **`RestoreSlots`** — everything else per slot type (each slot wrapped in `pcall`; missing content warns and blanks the slot).
4. **`ClearUnusedSlots`** — blank action slots not present in the profile (respects `barFilter`).
5. **`RestoreBindings`** — `SetBinding` + `SaveBindings`. Merge-only: keys absent from the profile are not unbound.
6. **`RestorePetBar`** — token/spell pet slots; no-op without an active pet, never clears unused pet slots.

`barFilter` (`{ [barNum|"pet"] = bool }`, from the grid checkboxes via `GetChecked()`): entries set to `false` are skipped by slot restore and unused-slot clearing.

---

## Racials (`libs/racials.lua`)

`byRace` table maps `UnitRace select(2)` keys to ordered spell arrays. Class-variant entries are `{ CLASS = spellID, ..., default = spellID }` tables resolved at runtime. Ordinals are stable — a missing ordinal on restore blanks that slot rather than erroring.

---

## Professions (`libs/professions.lua`)

One spellbook pass (`GetProfessions()` → `GetProfessionInfo()` → spellbook entries) builds two lookups: `GetProfessionSpellMap` (`{ [spellID] = { ordinal, slot } }`, used at **capture** time — ID matching avoids misclassifying unrelated spells that share a name with a profession spell, e.g. an item-granted "Survey" vs Archaeology's "Survey") and `GetProfessionNameMap` (`{ [spellName] = ... }`, used only to resolve old profiles' name-only entries, e.g. in `barsicons.lua`). `PickupProfessionSpell` tries slot-based lookup first (portable), then name-match fallback (for old profiles without `profSlot`), then slot 1 as a last resort.

---

## Class Filter (`classfilter.lua`)

`BuildClassFilter` builds a custom dropdown (not Blizzard's UIDropDownMenu) using a `BgFrame` menu + a full-screen transparent `catcher` frame at `(menu.level − 1)` to close the menu on outside clicks. Menu items sit at `(menu.level + 1)`. Both menu and catcher use `DIALOG` strata so level ordering applies. The catcher is hidden via a hook on the menu's `OnHide` — every hide path (item click, outside click, Escape, parent window hiding) funnels through `menu:Hide()`. The menu — like every nested dialog in the addon (Save/Export/Import/Debug) — is deliberately **not** `special`: `CloseSpecialWindows` hides every visible special frame at once, so Escape would close the main window along with it. All of them use `ns.CaptureEscape(frame)` (init.lua) instead, which captures Escape via `OnKeyDown` + `SetPropagateKeyboardInput` while the frame is shown (propagation only, no capture, during combat lockdown). Only the main window itself is `special`.

The player's own class is expanded into two rows: `"<Class> - <Spec>"` (current spec only, `specOnly = true`) and `"<Class> - all specs"`. The spec name in the row label is re-resolved each time the menu opens. `onSelect(classKey, specOnly)` feeds `SetClassFilter(key, specOnly)` in `profilelist.lua`, which narrows to `p.spec == playerSpec` only when the flag is set.

---

## Bars Grid (`barsview.lua` + `barsview_defs.lua` + `barsview_drag.lua`)

`BuildBarsGrid` renders a scrollable grid of icon cells: 15 bars × 12 slots plus an optional Pet row, ordered by `ns.GetActiveBarOrder()` (from `db.barOrder`). Column headers are pinned above the scroll area. `Update(profile)` re-fills rows from profile data; `Update(nil)` clears the grid. Tooltips use `GameTooltip:SetOwner` with `ANCHOR_TOPRIGHT`. Icons resolved per slot type via `barsicons.lua` resolvers.

Rows and cells are **pooled** (`acquireBarRow` / `acquirePetRow`): created once, re-filled and repositioned on every `Update`, hidden when unused — WoW frames are never garbage-collected, so widgets must not be recreated per refresh. Cell buttons always exist; empty cells hide the icon texture and nil out the tooltip scripts. Handle/checkbox closures read the row's `orderIdx` / `barLabel` / `barKey` fields, which fill updates in place. The profile list in `profilelist.lua` uses the same pattern (`acquireRow`), since its `Refresh` runs on every list click.

Each bar row has a per-bar **checkbox** feeding the `GetChecked()` table (used as `barFilter` on Load) and a **drag handle** with a hamburger grip over the label area. Dragging is delegated to `ns.BuildRowDrag` (`barsview_drag.lua`): a phantom row follows the cursor, a drop line marks the target gap, and a full-screen catcher ends the drag from anywhere; `onDrop(from, insertPos)` fires only when the order actually changes, mutates `db.barOrder`, and re-Updates. The pet row is not reorderable.

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
| `/bars debug flyouts` | Dump flyout spellbook and bar-slot state |
| `/bars debug flyoutrestore` | Test `PickupSpellBookItem` for each flyout, show cursor state |
| `/bars debug capture` | Show flyout entries from a live `Capture()` |
| `/bars debug flyoutplace` | Test pickup + `PlaceAction` for Summon Demon on slot 180 (Warlock) |

---

## Static Popups

| Key | Purpose |
|---|---|
| `ABM_CONFIRM_DELETE` | Confirm profile deletion |
| `ABM_CONFIRM_IMPORT` | Confirm restore from Import or Load |
