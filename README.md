# Action Bar Master

Save your entire action setup — bars, keybinds, macros, pet bar, and equipment-set placements — as a named profile, then restore it on any character or share it as a single block of text.

Great for alts that play the same spec, for rebuilding your bars after a wipe of your settings, or for handing a friend a ready-made layout.

## What gets captured

A profile stores everything it takes to rebuild your bars:

- **Action bars** — every slot across all bars: spells, items, macros, mounts, pets, flyouts, professions, racials, and equipment sets.
- **Keybindings** — your full key map (full profiles only).
- **Macros** — the macros referenced by your bars, with their names, icons, and bodies.
- **Pet bar** — pet spells and tokens.

Profiles are encoded into a compact text string so they can be copied, pasted, and shared.

## Getting started

1. Open the window with `/bars` (or click the minimap button).
2. Your current bars are saved automatically on login and whenever you change spec, so there's usually an **autosave** entry waiting for you.
3. To keep a named copy, click **Save**, give it a name, and confirm.
4. To apply a profile, select it in the list and click **Load**. Restoring is blocked in combat.

### Sharing a layout

- **Export** turns the selected profile into text — copy it and send it to anyone.
- **Import** takes a pasted string and restores it after you confirm.
- To share with **any class**, untick the bars you don't want before saving. The result is a *partial* profile that ignores class/spec and only touches the bars it contains — handy for sharing just a utility bar or a single rotation row.

## The window

- **Profile list** on the left, filtered by class/spec (defaults to your current class). Autosaves are tagged; all-class shared profiles show an `[s]`.
- **Bar preview grid** on the right shows each bar's icons. Tick or untick bars to control what a Save captures or a Load restores, or use **Check All / Uncheck All**.
- **Drag the grip** on any bar row to reorder how bars are displayed.
- **Dupes** scans the selected profile for the same action placed in more than one slot, with a per-finding Ignore.

> **Loading replaces, it doesn't merge.** A full profile clears action slots and keybindings that aren't part of it, so the result matches the profile exactly. Untick bars before loading to leave them alone.

## Minimap button

A round Action Bar Master button sits on the minimap edge:

- **Right-click** — open or close the window.
- **Shift-right-click** — menu (Open / Hide minimap button).
- **Drag** — move it around the minimap ring.

Hide or show it any time with `/bars minimap`.

## Slash commands

| Command | Action |
|---|---|
| `/bars`, `/wbars` | Open or close the window |
| `/bars minimap` | Show or hide the minimap button |
| `/bars sn` | Autosave the current bars now |
| `/bars dupes` | Open the duplicate-slot scanner |
| `/bars resetpos` | Recenter the window if it ends up off-screen |

## Dependencies

Requires **LibNAddOn** and **LibNUI**.

## Saved data

Everything is stored account-wide in `ActionBarMasterDB`: your profiles, the window position, the bar display order, and the minimap-button state. Profiles are visible to every character on the account (filtered in the list by class).
