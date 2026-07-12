# Action Bar Master — Code Context

Captures and restores action bars, keybindings, macros, pet bar, and equipment set names as shareable encoded text profiles. Depends on LibNAddOn and LibNUI.

---

## Runtime Environment

WoW runs **Lua 5.1**. All code must be Lua 5.1 compatible — no `goto`/`::label::`, no `//` integer division, no bitwise operators, no `table.unpack` (use `unpack()`).

---

## File Map

| File | Purpose |
|---|---|
| `init.lua` | Addon bootstrap; `ns.CaptureEscape(frame)`; `MigrateDB` (v1: `profiles = {}`, v2: seeds `barOrder`, now legacy/unread — see #124); `ns:RegisterChangelog()` (LibNAddOn changelog viewer — no parent → auto top-level settings category, since the addon has no other settings) |
| `changelog.lua` | `ns.changelog` release-history list for the in-game changelog viewer; auto-prepended at release by addon-ci's `release.yml`, excluded from release-change detection |
| `capture.lua` | `ns.Capture(barFilter?) → profile` — builds profile from current character state; partial shared profiles. Also captures `profile.barLayout = ns.wow.ReadActionBars()` (real on-screen orientation/enabled + pet + `mainPage`) for the layout preview — stored on the DB entry, **not** serialized (see below) |
| `restore.lua` | `ns.Restore(profile, barFilter?)` — orchestrates the restore passes; no-op in combat. Owns the miss/async-item summary state + hooks (`ns.RestoreMiss`, `ns.DeferItemWarn`, the `GET_ITEM_INFO_RECEIVED` retry) |
| `restore_slots.lua` | `ns.RestoreSlots` (per-slot pickup ladder), `ns.RestoreFlyouts` (flyout pre-pass), `ns.BuildSpellbookMaps` (override + flyout maps) — split from `restore.lua` for the file-size cap; consumes `restore.lua`'s miss/defer hooks |
| `restore_pass.lua` | Helper passes: `ns.RestoreMacrosAndSlots`, `ns.RestoreBindings`, `ns.RestorePetBar`, `ns.ClearUnusedSlots` |
| `serialize.lua` | `ns.Encode(profile) → string`, `ns.Decode(text) → profile, err`; format v2 (full) / v3 (partial) |
| `autosave.lua` | Auto-saves on `PLAYER_ENTERING_WORLD`, `ACTIVE_TALENT_GROUP_CHANGED`; `ns.AutoSave()` |
| `profilelist.lua` | `ns.BuildProfileList(parent, onSelect) → scroll, Refresh, GetSelected, SetSelected, SetClassFilter`; pooled rows |
| `classfilter.lua` | `ns.BuildClassFilter(parent, position, onSelect)` — class dropdown filter widget |
| `barsicons.lua` | Icon/name + tooltip resolvers per slot type (`ns._bar_getIcon` / `_getName` / `_getPetIcon` / `_addTooltip` / `_addPetTooltip`); `_getName` (name-first, mirrors `addTooltip`) feeds the preview's hover text |
| `barlabels.lua` | `BAR_DEFS` (abm ↔ display label) + `ns.GetBarLabel(abm)` — names an abm bar the way the UI/overlay do (used by restore warnings, the overlay, the dupe scanner). Bar order is now driven by real topography, so there is no user-configurable order (was `barsview_defs.lua`; `GetActiveBarOrder` dropped) |
| `barselect.lua` | `ns.BuildBarSelect(parent) → { GetChecked, SetAllChecked, SetHighlighter, Height }` — the per-bar **include selector**: a compact chip grid (`1‑8` / `C1‑C5` / `Bonus` / `Sky` / `Pet`) feeding the Save/Load `barFilter`. Chips default included; hovering one highlights its real bar in the preview. Modeled on Warbandeer's `BarsApply` (#124) |
| `baroverlay.lua` | `ns.barOverlay` (`Show`/`Hide`/`Refresh`) — on-screen "Bar 3"/"Class 2" tags beside each live action bar while the window is open |
| `barspreview.lua` | `ns.BuildBarsPreview(parent) → { Update, Highlight }` — the **primary bar view** (#124): a read-only condensed-topographic layout of the selected (or live) profile via LibNUI's shared `ui.BarsPreview`, **scaled to 115% of native** (`fit-to-native × ZOOM`, `ZOOM` = 1.15) with ABM's slot resolvers (`ns._bar_getIcon`/`_getName`/`_getPetIcon`; resolvers close over the profile's macro array, ignoring the widget's macro map). `Update(profile)` renders the captured `barLayout` (hides on nil); `Highlight(abm, on)` lights a bar (driven by selector-chip hover) |
| `window.lua` | Main UI window — wires list, filter, the bar selector (`f._barSelect`), the primary layout preview (`f._barsPreview`), buttons, and static popups together. `OnSelect` reattaches `profile.barLayout = entry.barLayout` after decode (it isn't serialized) and updates the preview |
| `window_dialogs.lua` | `ns.BuildSaveDialog`, `ns.BuildExportDialog`, `ns.BuildImportDialog` modal builders |
| `minimap.lua` | Minimap button via `ui.MinimapButton` (`textures\minimap.png`, `iconFillsButton`): left-click opens, right-click menu, drag to move; `ns.SetMinimapShown`, `/bars minimap`. Also `ns:CompartmentClick` (toggle window) for the toc `AddonCompartmentFunc`/`X-NUI-COMPARTMENT` entry, with `## IconTexture` set to the same PNG |
| `debug.lua` | `/bars debug <sub>` commands; scrollable copyable output window |
| `libs/base64.lua` | `ns.base64.enc(bytes)`, `ns.base64.dec(str)` |
| `libs/crc32.lua` | `ns.crc32.enc(bytes) → uint32` |
| `libs/racials.lua` | `ns.GetRacialSpells(race, class)`, `ns.GetRacialSpellSet(race, class)` |
| `libs/professions.lua` | `ns.GetProfessionNameMap()`, `ns.GetProfessionSpellID(ordinal, slot)`, `ns.PickupProfessionSpell(ordinal, slot, name)` |

---

## NS API Surface

```lua
ns.CaptureEscape(frame)               -- close frame on Escape w/o CloseSpecialWindows (frame must not be `special`)
ns.Capture(barFilter?)                -- → profile table; barFilter excluding any bar → PARTIAL shared
                                      --   profile (profile.bars, class/spec "", no binds, macros trimmed)
ns.Restore(profile, barFilter?)       -- applies profile; no-op in combat. barFilter: { [barNum|"pet"] = bool }, false = skip
ns.Encode(profile)                    -- → copyable text string
ns.Decode(text)                       -- → profile, err (nil, msg on failure)
ns.AutoSave()                         -- capture + upsert autosave entry in db.profiles
ns.RestoreMacrosAndSlots(macros, slots) -- ensure macros exist, place macro slots
ns.RestoreBindings(binds)             -- apply + persist key bindings
ns.RestorePetBar(petslots)            -- apply pet bar (no-op without active pet); rescans token slots
                                      --   per placement (B4). Merge-only: does NOT clear unused slots
ns.ClearUnusedSlots(slots, barFilter?) -- blank action slots absent from profile
ns.BuildProfileList(parent, onSelect) -- → scroll, Refresh(), GetSelected(), SetSelected(entry), SetClassFilter(key, specOnly)
                                      -- selection is identity-based: GetSelected/onSelect yield the profile ENTRY (not an index)
ns.BuildClassFilter(parent, pos, onSelect)  -- class dropdown; calls onSelect(classKey|nil, specOnly)
ns.BuildBarSelect(parent)             -- → { GetChecked(), SetAllChecked(v), SetHighlighter(fn), Height() }
                                      --   per-bar include chip strip; GetChecked() → { [abm|"pet"] = bool }
ns.BuildBarsPreview(parent)           -- → { Update(profile?), Highlight(abm, on) } primary topographic preview
ns.GetBarLabel(abm)                   -- → UI display label for an abm bar number (5 -> "Bar 3")
ns.BuildSaveDialog(parent, onSaved)   -- → dialog (._nameBox); Save Profile modal
ns.BuildExportDialog(parent)          -- → dialog (._box); read-only encoded text. Export button shows the SELECTED profile's stored .encoded (shareable as-is), or a live ns.Encode(ns.Capture()) when nothing is selected
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
ns:ToggleMainWindow()                 -- bare-command toggle: hide if open, else Open()
ns:HideMainWindow()                   -- hide the main window if it exists
ns.SetMinimapShown(show)              -- show/hide minimap button + persist (db.minimap.hide); the button is built eagerly at PLAYER_LOGIN (no-op before that)
ns:CompartmentClick()                 -- addon-compartment entry handler (toc AddonCompartmentFunc) → ToggleMainWindow
ns.db                                 -- live ref to ActionBarMasterDB
```

---

## DB Schema (`ActionBarMasterDB`)

Managed by LibNAddOn via `X-NUI-DB` / `X-NUI-DB-VERSION`.

```lua
ActionBarMasterDB = {
  version   = 2,
  windowPos = { x = number, y = number },  -- saved window position (TOPLEFT anchor)
  barOrder   = { int, ... },   -- LEGACY (unread since #124): was the user's bar
                               -- display order; kept for rollback safety, never read
  ackedDupes = { [string] = true, ... },  -- lazy-init; key = "profileName|actionKey"; ignored duplicates
  minimap    = { angle = number, hide = bool },  -- lazy-init (minimap.lua, PLAYER_LOGIN); ring angle in degrees
  profiles  = {               -- array; index 1 = most recent
    {
      name     = string,      -- display name (user-entered or "Char - Spec")
      char     = string,      -- UnitName("player") at capture time
      class    = string,      -- e.g. "WARRIOR"
      spec     = string,      -- spec display name
      encoded  = string,      -- ns.Encode() output
      autosave = bool|nil,    -- true for auto-saved entries
      savedAt  = string|nil,  -- "%Y-%m-%d %H:%M" timestamp, autosave only
      barLayout = table|nil,  -- ns.wow.ReadActionBars() snapshot (real orientation) for
                              -- the preview; NOT in `encoded`, so imported/older entries
                              -- lack it and the preview falls back to a flat layout.
                              -- Additive field — no DB version bump / migration needed.
    },
    ...
  },
}
```

`MigrateDB`: v1 initialises `profiles = {}`; v2 seeds `barOrder` — now **legacy/unread since #124** (the primary view is driven by real topography). The seed is retained (never removed) so a rollback within the patch cycle finds its data intact, per the non-destructive DB rule.

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
      strindex = string|nil,  -- summonpet GUID; profession spell-name fallback;
                              -- equipment-set / outfit NAME (identity, see table)
      profSlot = int|nil,     -- profession spellbook slot (type="profession" only)
    }, ...
  },
  binds    = { { command=string, key1=string|nil, key2=string|nil }, ... },
  macros   = { { id=int, name=string, icon=string, body=string }, ... },
  petslots = { { id=int, type="token"|"spell", index=int|nil, strindex=string|nil }, ... },
  outfits  = { string, ... },  -- outfit names (unused at restore time; reserved)
  bars     = { int, ... }|nil, -- PARTIAL profiles only: captured internal bar numbers (1-15).
                               -- Restore touches ONLY these bars (place + clear strays);
                               -- all other bars, bindings, and pet bar are left alone.
  barLayout = table|nil,       -- ns.wow.ReadActionBars() at capture time: { [bar] =
                               -- { orientation, numIcons, numRows, enabled }, pet, mainPage }.
                               -- Preview-only; dropped by Encode (persisted on the DB entry).
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
| `"equipmentset"` | position in set ID array (fallback) | set name (identity) |
| `"outfit"` | position in outfit list (fallback) | outfit name (identity) |
| `"companion"` | summon spell ID (legacy pre-journal mount/pet action) | — |
| `"petaction"` / `"futurespell"` | — | — (cleared on restore) |

---

## Serialization Format

`ns.Encode` packs the profile via `Pack` into a binary byte array, prepends a 5-byte header `[version(1)][crc32(4)]`, base64-encodes the whole frame, and wraps it in `# …` comment lines (60-char width). `ns.Decode` strips comments, base64-decodes, verifies CRC, then unpacks.

**Current max format version: 3.** Version 2 adds a `profSlot` byte after `strindex` for each slot; version 3 appends the captured-bars list (count byte + bar bytes) after outfits. **Full profiles still encode as v2** so earlier addon revisions can read them; v3 is emitted only for partial profiles (`profile.bars` set). Versions 1-2 remain readable.

---

## Restore Order (`restore.lua` + `restore_pass.lua`)

`ns.Restore(profile, barFilter?)` runs the passes in this fixed order:

1. **`RestoreFlyouts`** — flyout slots FIRST, before any other pickup/place call. `PickupSpellBookItem` for flyout-type spellbook items silently fails if called after other protected pickup operations in the same hardware event. Do not reorder.
2. **`RestoreMacrosAndSlots`** — find-or-create each profile macro (matched by name + trimmed body), then place macro slots via the old→new index map.
3. **`RestoreSlots`** — everything else per slot type (each slot wrapped in `pcall`; content that isn't available on this character blanks the slot). Equipment sets and outfits resolve by **name** first (`strindex` identity), falling back to the stored list position for pre-identity profiles. Unresolvable slots are collected as "misses" (not printed individually) and flushed as a **single summary line** at the end of `ns.Restore` — async item-info lookups (`GET_ITEM_INFO_RECEIVED`) defer the flush until the last one resolves (`pendingItems` counter — the pending set is wiped at each `ns.Restore` entry so a prior restore's delayed event can't decrement this one's counter below zero), and **retry placement** when the data loads (`PickupItem(link)` resolves items that only respond to the link form) before warning — combat-guarded, and only into a still-empty slot. True per-slot errors and the flyout "drag from spellbook" instruction still print immediately via `Warn`. **assistedcombat** slots are captured as the action's own spell id (not the volatile `C_AssistedCombat.GetActionSpell()` suggestion), so they restore as the assist action rather than a frozen rotation spell.
4. **`ClearUnusedSlots`** — blank action slots not present in the profile (respects `barFilter`).
5. **`RestoreBindings`** — clear-then-apply: clears the character's current key bindings, then applies the profile's + `SaveBindings` — a restore rather than a merge (consistent with `ClearUnusedSlots` for action slots). Scope caveat: capture and clear both cover only `GetBinding`'s key1/key2, so a 3rd+ key bound to a command is neither captured nor cleared. Only runs for full profiles — partial/shared profiles carry no binds.
6. **`RestorePetBar`** — token/spell pet slots; no-op without an active pet. Re-scans token slots per placement (placing a token swaps slots, staling a once-built map — B4). **Merge-only — does NOT clear unused pet slots** (gap #7 deliberately skipped: most pet-bar buttons are the pet's intrinsic tokens, so blanking "unused" slots risks stripping a different pet's built-in actions).

`barFilter` (`{ [barNum|"pet"] = bool }`, from the bar selector's chips via `GetChecked()`): entries set to `false` are skipped by slot restore and unused-slot clearing.

**Partial (shared) profiles** (`profile.bars` present): the effective filter is the intersection of the captured-bar set and the caller's barFilter — bars outside the captured set are never touched; bindings are absent by construction (`RestoreBindings` is skipped when the profile has none); the pet bar restores only if captured. Saved from the window with any bar-selector chip excluded; stored with `class`/`spec = nil` in the DB so the list shows them to every character (`[s]` tag, ignores class/spec filters). The window previews the current character's live bars when no profile is selected.

---

## Racials (`libs/racials.lua`)

`byRace` table maps `UnitRace select(2)` keys to ordered spell arrays. Class-variant entries are `{ CLASS = spellID, ..., default = spellID }` tables resolved at runtime. Ordinals are stable — a missing ordinal on restore blanks that slot rather than erroring.

---

## Professions (`libs/professions.lua`)

One spellbook pass (`GetProfessions()` → `GetProfessionInfo()` → spellbook entries) builds two lookups: `GetProfessionSpellMap` (`{ [spellID] = { ordinal, slot } }`, used at **capture** time — ID matching avoids misclassifying unrelated spells that share a name with a profession spell, e.g. an item-granted "Survey" vs Archaeology's "Survey") and `GetProfessionNameMap` (`{ [spellName] = ... }`, used only to resolve old profiles' name-only entries, e.g. in `barsicons.lua`). `PickupProfessionSpell` tries slot-based lookup first (portable), then name-match fallback (for old profiles without `profSlot`), then slot 1 as a last resort.

---

## Class Filter (`classfilter.lua`)

`BuildClassFilter` builds a custom dropdown (not Blizzard's UIDropDownMenu) using a `BgFrame` menu + a full-screen transparent `catcher` frame at `(menu.level − 1)` to close the menu on outside clicks. Menu items sit at `(menu.level + 1)`. Both menu and catcher use `DIALOG` strata so level ordering applies. The catcher is hidden via a hook on the menu's `OnHide` — every hide path (item click, outside click, Escape, parent window hiding) funnels through `menu:Hide()`. The menu — like every nested dialog in the addon (Save/Export/Import/Debug) — is deliberately **not** `special`: `CloseSpecialWindows` hides every visible special frame at once, so Escape would close the main window along with it. All of them use `ns.CaptureEscape(frame)` (init.lua) instead, which captures Escape via `OnKeyDown` + `SetPropagateKeyboardInput` while the frame is shown (propagation only, no capture, during combat lockdown). Only the main window itself is `special`.

The player's own class is expanded into two rows: `"<Class> - <Spec>"` (current spec only, `specOnly = true`) and `"<Class> - all specs"`. The spec name in the row label is re-resolved each time the menu opens. `onSelect(classKey, specOnly)` feeds `SetClassFilter(key, specOnly)` in `profilelist.lua`, which narrows to `p.spec == playerSpec` only when the flag is set. The filter **defaults to the player's current class + spec** at build time (falling back to All Classes if the class has no entry); manual selections persist for the session.

---

## Bar Selector + Layout Preview (`barselect.lua` + `barspreview.lua`)

The window's right panel is the **primary bar view** (#124, replacing the old fixed 15×12 grid): a per-bar **include selector** across the top over a read-only **topographic layout preview** filling the rest.

**`ns.BuildBarSelect(parent)`** builds a compact grid of toggle **chips** — one per action bar (`1‑8`, `C1‑C5`, `Bonus`, `Sky`) plus `Pet` — laid out in two rows. Each chip maps a short label to an abm bar number (`barlabels.lua` `BAR_DEFS`; the pet chip maps to the `"pet"` filter key). Chips **default to included** (gold wash + gold accent); clicking excludes (empty + red accent). `GetChecked()` returns `{ [abm | "pet"] = bool }` (explicit `true`/`false`; `false` = exclude) — consumed as the `barFilter` by Save (partial profiles) and Load; because all-`true` still counts 15 bars, `ns.Capture` treats "everything included" as a **full** profile. `SetAllChecked(v)` drives the window's **Check All / Uncheck All** button (header row, between the Profiles label and the class filter). `SetHighlighter(fn)` wires chip hover to the preview's `Highlight(abm, on)`, so hovering a chip lights up the bar it controls. Modeled on Warbandeer's `BarsApply` strip; the abm bar-number space is identical to LibNUI's `ui.BarsPreview` row keys (both `floor((slot-1)/12)+1`), so a chip's abm number *is* the preview bar it highlights.

**`ns.BuildBarsPreview(parent)`** hosts LibNUI's shared `ui.BarsPreview`, **scaled to fit** the panel so the whole topography (including the right-docked vertical bars, which can push it wider than the panel) is always visible without clipping. The scale is `min(1, fitW, fitH) × ZOOM` (`ZOOM` = 1.15, the tuned in-game size) applied to an ABM-owned wrapper frame — the shared widget is left untouched — so it renders at 115% of native when native fits, shrinking proportionally only if native itself can't fit a smaller window. The window (`window.lua` `WIN_W`) is sized so a full setup fits at this zoom. A stage clip guards the frame or two before the first fit; the fit re-runs on the panel's `OnSizeChanged` (the first Open updates before the window is shown, so the stage has no size yet then). `Update(profile)` renders the captured `barLayout`; `Update(nil)` hides it. `Highlight(abm, on)` forwards to the widget's `HighlightBar`. This view is **read-only** — a spatial reference; all include/exclude interaction lives in the selector strip.

The pooled row/cell discipline of the old grid now lives inside the shared `ui.BarsPreview` widget (LibNUI). The profile list in `profilelist.lua` still uses its own `acquireRow` pool, since its `Refresh` runs on every list click.

---

## Bar Overlay (`baroverlay.lua`)

`ns.barOverlay.Show()` / `Hide()` tag each on-screen action bar with the same label the selector/preview show, so the UI's bars map to physical ones. Lifetime is tied to the window frame's visibility via `OnShow`/`OnHide` hooks in `window.lua` (plus an explicit `Show()` in `ns:Open` — `TitleFrame` is created shown, so the first open misses the hook). Purely decorative: reads button state, never writes it, so no taint and no combat guard.

- **Button discovery** is addon-agnostic and now uses LibNAddOn's shared primitives — `ns.wow.collectActionButtons()` (`LibActionButton-1.0:GetAllButtons()` for Bartender/Dominos/ElvUI + a Blizzard default-bar name scan) and `ns.wow.actionSlotOf(btn)` (`_state_type`/`_state_action` → Blizzard `.action`). These are the same helpers behind `ns.wow.ReadActionBars()`, so the suite has one implementation (nazumods/wow#466); this overlay keeps its own `place()` because it anchors to the actual button frames, which `ReadActionBars` abstracts away.
- **Grouping**: visible action buttons bucket by abm bar with the same `floor((slot − 1) / 12) + 1` rule as capture; label text is `ns.GetBarLabel(abm)`.
- **Placement** anchors to the bar's bounding box. **Horizontal** bars anchor the label to the left of the leftmost button, flipping to the right of the rightmost when the bar hugs the **left screen edge** too tightly to fit. **Vertical** bars get a **stacked** label (`stackText`: one char per line, bar number kept whole after a blank line, e.g. `Bar 3` → `B/a/r//3`) placed **above** the top button and centred on the column, flipping **below** the bottom button when there's no room at the top of the screen.
- **Z-order**: labels parent a `FULLSCREEN_DIALOG`-strata container (frame level 1000) so they sit above the bars and the ABM window, below real tooltips.
- **Refresh**: while shown, a driver frame re-anchors on `ACTIONBAR_PAGE_CHANGED` / `UPDATE_BONUS_ACTIONBAR` / `UPDATE_OVERRIDE_ACTIONBAR` / `UPDATE_VEHICLE_ACTIONBAR` (paging/stance/skyriding/vehicle swaps). The event refresh is **coalesced onto the next frame** via LibNAddOn `ns:coalesce("baroverlay", 0, Refresh)` (fires 0ms/next-frame after the first event, dropping the rest of the burst) — LibActionButton re-pages its buttons within the same event, so a synchronous read would catch the pre-swap slots (a mount into skyriding would lag one event behind). Labels and their container are pooled — hidden, never recreated.

## Autosave (`autosave.lua`)

- Triggers: `PLAYER_ENTERING_WORLD` (login or reload) with a 2-second delay; `ACTIVE_TALENT_GROUP_CHANGED` with 500ms delay.
- Retries every 2 seconds if spec is not yet resolved (specName == "" or profile.spec == "Unknown").
- One autosave entry per `char + spec` — updates in place rather than appending.
- New entries are inserted at index 1 (most recent first).

## Manual save (`window_dialogs.lua` `BuildSaveDialog`)

- New profiles are **front-inserted at index 1** (same ordering as autosave; "index 1 = most recent").
- Saving into an existing **non-autosave** name prompts `ABM_CONFIRM_OVERWRITE` and overwrites that entry **in place** (keeps its position and table identity, so a live list selection stays valid — cf. #65) instead of silently duplicating. Autosave entries (keyed by char+spec) are not matched here.
- Exposes `ns.AutoSave()` so the window's "Autosave Now" button and `/bars sn` can call it directly.

---

## Slash Commands

| Command | Action |
|---|---|
| `/bars`, `/wbars` | Toggle the main window (closes it if already open) |
| `/bars resetpos` | Recenter the window to its default position (recovery if a resolution/scale change orphaned it off-screen) |
| `/bars minimap` | Toggle the minimap button on/off (persisted in `db.minimap.hide`) |
| `/bars sn` | Autosave now |
| `/bars dupes` | Toggle the duplicate-scan window (closes it if already open); Ignore button per finding |
| `/bars debug flyouts` | Dump flyout spellbook and bar-slot state |
| `/bars debug flyoutrestore` | Test `PickupSpellBookItem` for each flyout, show cursor state |
| `/bars debug capture` | Show flyout entries from a live `Capture()` |

---

## Static Popups

| Key | Purpose |
|---|---|
| `ABM_CONFIRM_DELETE` | Confirm profile deletion |
| `ABM_CONFIRM_IMPORT` | Confirm restore from Import or Load |
| `ABM_CONFIRM_OVERWRITE` | Confirm overwriting an existing (non-autosave) profile name on Save |

---

## Tests & CI

WoW-API-free modules have [busted](https://lunarmodules.github.io/busted/) specs in `spec/`; everything touching `C_*`/frames stays in-game-tested (`/reload`).

- **Covered:** `libs/base64.lua`, `libs/crc32.lua`, `serialize.lua` (Encode/Decode round-trip, partial-profile v3, CRC tamper detection).
- **Loader:** `spec/abm.lua` `load()` loads those files into a fresh `ns` with the `(addonName, ns)` vararg, stubbing a pure-Lua **variadic** `bit` library (matches WoW's 4-arg `bor` that `Decode` relies on) and `IsWindowsClient`. No `luabitop` rock needed.
- **Run:** `busted` from the repo root (config in `.busted`, `ROOT = {"spec"}`). Spec files are never listed in the `.toc`, so WoW never loads them; save them **without a UTF-8 BOM** (Lua 5.1 `loadfile` rejects it).
- **Lint:** `luacheck . --codes` (config in `.luacheckrc`; WoW globals as `read_globals`, `spec/**` gets `+busted` std). Repo lints clean — keep it that way.
- **CI:** `.github/workflows/ci.yml` runs busted + luacheck on Lua 5.1.5 for every push to `main` and every PR.
