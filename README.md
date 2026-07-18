# Action Bar Master

Save your entire action setup — bars, keybinds, macros, pet bar, and equipment-set placements — as a named profile, then restore it on any character or share it as a single block of text.

Great for alts that play the same spec, for rebuilding your bars after a wipe of your settings, or for handing a friend a ready-made layout.

> 🐛 **Found a bug or have a request?** Please report it on **[GitHub Issues](https://github.com/roshne/ActionBarMaster/issues)** — I don't reliably see CurseForge comments, so that's the surest way to reach me and get it fixed.

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
- **Bar selector** across the top of the right panel is a strip of chips — one per action bar, plus **Pet**. Every chip starts included; click one to exclude that bar, controlling what a Save captures or a Load restores, or use **Check All / Uncheck All**.
- **Layout preview** below the chips shows your bars in their real on-screen arrangement — a read-only map for telling which bar is which. Hover a chip to highlight the bar it controls.
- **Dupes** scans the selected profile for the same action placed in more than one slot, with a per-finding Ignore.

While the window is open, each of your on-screen action bars is tagged with its **"Bar 3" / "Class 2"** name — the same name the selector and preview use — so you can tell at a glance which chip maps to which physical bar. The tags disappear when you close the window.

> **Loading replaces, it doesn't merge.** A full profile clears action slots and keybindings that aren't part of it, so the result matches the profile exactly. Untick bars before loading to leave them alone.

## Minimap button

A round Action Bar Master button sits on the minimap edge:

- **Left-click** — open or close the window.
- **Right-click** — menu (Open / Hide minimap button).
- **Drag** — move it around the minimap ring.

Hide or show it any time with `/bars minimap`. Even with the button hidden, Action Bar Master is always reachable from the addon-compartment menu at the top of the minimap.

## Changelog

To see what changed in each release without leaving the game, open the game's **Settings → AddOns → Action Bar Master** panel and click **Changelog → View**. The release history opens in a scrollable, copyable window.

## Slash commands

| Command | Action |
|---|---|
| `/bars`, `/wbars` | Open or close the window |
| `/bars minimap` | Show or hide the minimap button |
| `/bars sn` | Autosave the current bars now |
| `/bars dupes` | Open the duplicate-slot scanner |
| `/bars resetpos` | Recenter the window if it ends up off-screen |

## Dependencies

- **LibNAddOn**
- **LibNUI**

## Saved data

Everything is stored account-wide in `ActionBarMasterDB`: your profiles, the window position, and the minimap-button state. Profiles are visible to every character on the account (filtered in the list by class).
