# ActionBarMaster — Full Code Review (2026-06-11)

Scope: every file at HEAD (`470c512`, post PR #40). Follow-up to the 2026-06-09 review;
items already fixed there (escape handling, pooling, file splits, docs) are not repeated.
Carry-over open items are listed at the end. WoW API claims verified against
`R:\repos\wow-ui-source` where possible.

---

## Bugs — confirmed

### B1. Mount restore depends on the journal's filter state and uses the wrong loop bound — **open; first fix reverted**
`restore.lua:173-181`. The loop runs `i = 1, C_MountJournal.GetNumMounts()` but indexes
`GetDisplayedMountInfo(i)` — the **displayed** (filtered/searched) list, whose bound is
`GetNumDisplayedMounts()` (see Blizzard_MountCollection.lua:662). Consequences:

- If the user has journal filters or a search active, the saved mount may not be in the
  displayed list at all → no match.
- On no match the fallback `C_MountJournal.Pickup(0)` silently places a *different* mount
  (displayed index 0 / random favorite) instead of warning and blanking, unlike every other
  slot type.

Fix: resolve via `C_MountJournal.GetMountInfoByID(s.index)` → `PickupSpell(spellID)` (works
regardless of filters), or at minimum loop `GetNumDisplayedMounts()` and warn+blank on miss.

**2026-06-11 fix attempt reverted** — switching to `GetNumDisplayedMounts()` +
`Pickup(displayedIndex)` with a `PickupSpell(mount spell)` fallback stopped mounts restoring
entirely in-game, while the original code works in practice. Open questions before retrying:
whether `C_MountJournal.Pickup` expects a 0-based index (the working `Pickup(0)` fallback
hints it might, making a 1-based displayed loop off by one), and whether `PickupSpell`
accepts mount summon spell IDs at all. Needs in-game `/dump` investigation of
`Pickup`/`GetDisplayedMountInfo` index alignment before a second attempt.

### B2. Toy "not in Toy Box" check reads itemQuality, not ownership — **fixed, verified in-game**
`restore.lua:145`. `select(6, C_ToyBox.GetToyInfo(id))` is **itemQuality**
(`itemID, toyName, icon, isFavorite, hasFanfare, itemQuality` — AlertFrameSystems.lua:1253).
`owned == false` is never true, so the suffix is dead code. Use `PlayerHasToy(s.index)`.

### B3. Capture's temp-macro resolution can clobber bars if the cursor is occupied
`capture.lua:71-78`. For temp macros it does `PickupAction(i)` → `GetCursorInfo()` →
`PlaceAction(i)`. Capture runs from **timers** (autosave: 2 s after PLAYER_ENTERING_WORLD,
500 ms after spec change), so the user can be mid-drag with something on the cursor:
`PickupAction(i)` then *swaps* the held action into slot `i`. In combat, `PickupAction` is
blocked → the wrong (temp) index is captured silently.
Fix: skip resolution (or bail out of the swap) when `GetCursorInfo()` is non-nil, and
skip/defer autosave while `InCombatLockdown()`.

### B4. Pet-bar token restore uses a stale slot map across swaps
`restore_pass.lua:75-92`. `tokens[name] = slot` is snapshotted once; each
`PickupPetAction(src); PickupPetAction(dst)` swap moves the displaced token to `src`
without updating the map, so restoring multiple moved tokens places later ones from wrong
slots. Also the `ClearCursor()` after each swap discards whatever was displaced.
Fix: re-scan the token map after each swap (or process as a permutation).

### B5. `/bars debug flyoutplace` destroys the previous slot-180 action despite claiming to restore it
`debug.lua:227-247`. `PlaceAction(TEST_SLOT)` over an occupied slot swaps the old action
onto the cursor — and the very next `ClearCursor()` discards it permanently. The "restore"
block afterwards (`PickupAction` + `PlaceAction` on the same slot) just cycles the *flyout*
out and back; the original action is already gone.
Fix: after PlaceAction, the cursor holds the previous action — hold it and re-place it at
the end instead of clearing; or refuse to run when the slot is occupied.

### B6. Profession map stops at the first nil profession slot — **fixed, verified in-game**
`libs/professions.lua:12-13`. `for ordinal, profIdx in ipairs({ GetProfessions() })` —
GetProfessions returns `(prof1, prof2, archaeology, fishing, cooking)` with nil holes.
Archaeology is nil for nearly everyone, so **fishing and cooking never enter the name map**;
their bar spells get captured as plain `type="spell"` and restore through the unreliable
`PickupSpell` path the profession machinery exists to avoid. A character with no primaries
maps nothing at all.
Fix: `for ordinal = 1, 5 do local profIdx = select(ordinal, GetProfessions()) ... end`
(capture/restore stay consistent because both sides use the same ordinal).

## Bugs — likely / hazard

### B7. Stale profile indices around confirm popups can delete the wrong profile
`window.lua:146-148, 186-200`. `_pendingDelete` and the list selection are absolute indices
into `db.profiles`, but **autosave inserts at index 1** (login timer, spec change). If an
autosave lands while the Delete confirm is open (e.g. spec change mid-dialog), OnAccept
removes a *different profile* — data loss. The list selection has the same staleness
(selection silently shifts identity after any autosave insert; the list isn't refreshed on
autosave events).
Fix: stash the profile *table reference* and locate it by identity at accept time; treat
selection the same way.

### B8. `GetOverrideSpell` nil-result would abort Capture/Restore map builds — **fixed**
`capture.lua:19-20`, `restore.lua:57-58`. If `C_Spell.GetOverrideSpell` ever returns nil
for an odd spellbook entry, `map[nil] = ...` throws "table index is nil" — Capture errors
(and autosave re-errors every retry). One-line hardening: `if ovr and ovr ~= spellId`.

### B9. Verify `PickupPetSpell` still exists in retail
`restore_pass.lua:87`. The only Blizzard usage is Classic (Mists) code; globals aren't in
the generated API docs so this is unverifiable offline. RestorePetBar has no pcall — if the
global is gone, pet restore throws and the final "Bars restored." never prints. Verify
in-game (`/dump PickupPetSpell`); if absent, pick the spell up via
`C_SpellBook.PickupSpellBookItem(..., Enum.SpellBookSpellBank.Pet)`.

## Design gaps — new

### D1. Export ignores the selected profile
`window.lua:151-157`. Export always encodes a fresh `Capture()` of the *current* bars.
There is no way to export a saved profile without loading it onto your character first —
the natural "share this saved profile" flow doesn't exist. Suggest: Export uses the
selected profile when one is selected (its `encoded` string is already in the DB), else
falls back to current bars.

### D2. Late item-data warning never retries the placement
`restore.lua:32-42, 148-150`. When item data isn't cached, the slot is blanked and
GET_ITEM_INFO_RECEIVED merely *warns* once data arrives — at which point the pickup would
likely succeed. Track the slot id alongside the tag and retry the pickup+place on receipt.

### D3. Assisted-combat slots are restored as the resolved spell
`capture.lua:52-53`. Capturing `subType == "assistedcombat"` stores
`C_AssistedCombat.GetActionSpell()` — restore places that concrete spell, losing the
adaptive assisted-combat button. May be intentional; document or restore the real thing.

## Minor / maintenance

- **M1** `serialize.lua` `str8`/`str16` write `#s % 256` (`% 65536`) as the length but emit
  *all* bytes — an over-long string silently corrupts the whole stream. All current fields
  are short; one `assert(#s <= 255)` converts a future silent corruption into an error.
- **M2** `serialize.lua:210` Decode strips `[@][^\n]*` lines — no encoder ever emits `@`
  lines; dead rule (or document what it's for).
- **M3** `restore.lua:113` "already correct" check never matches for `racial`,
  `profession`, `equipmentset`, `outfit` (curType/curIndex semantics differ) — harmless
  wasted re-placement, but worth a comment so nobody "fixes" it wrong.
- **M4** `classfilter.lua:131` the trigger label freezes the spec name at click time; after
  a spec change it shows the old spec while the actual filter (live `playerSpec` in
  profilelist) uses the new one. Cosmetic mismatch.
- **M5** `window.lua:41` `titlebar:SetScript("OnMouseUp", ...)` may clobber LibNUI
  TitleFrame's own handler — prefer HookScript or confirm the contract.
- **M6** `barsview_drag.lua` phantom/drop-line are parented to UIParent and not clipped by
  the scroll frame — they can draw outside the grid when scrolled. Cosmetic.
- **M7** `window_dialogs.lua:51` Save accepts an all-whitespace name (`strtrim` it).
- **M8** No tests, no luacheck, no CI in this repo. `serialize`, `base64`, `crc32`,
  `racials` are pure Lua — the wow suite's busted/luacheck infra applies directly, and a
  serialize round-trip spec would have caught M1-class bugs.

## Carry-over open items (from 2026-06-09 review)

- #5 RestoreBindings is merge-only (never unbinds; restored command can also keep extra
  pre-existing keys).
- #6 Equipment sets / outfits stored by list position, not identity.
- #7 Pet bar is merge-only (never clears).
- #8 Manual save appends to end vs autosave inserts at 1; duplicate names silently allowed.
- Minor: base64 `pairs`→`ipairs`; `ns.delay` single-timer hazard comment in autosave;
  int24 spell-ID ceiling (~16.7 M; Harronir racial is already 1,237,885); `" v"` literal
  dropdown arrow; debug.lua ships four debug commands incl. the Warlock-specific test.
