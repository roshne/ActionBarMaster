# Action Bar Master

Capture and restore your action bars, keybindings, macros, pet bar, and equipment-set placements as shareable, encoded text profiles. Swap full setups between specs and characters, or share just a few bars with anyone.

## Features

- **Profiles** — save the current action bars, keybinds, macros, and pet bar as a named profile, and restore them on any character.
- **Autosave** — your bars are saved automatically on login and whenever you change spec, one entry per character + spec.
- **Per-bar sharing** — uncheck bars before saving to create a partial profile that any class can import.
- **Import / export** — copy a profile to a text string to share, and paste one back to restore.
- **Duplicate scan** — find the same action placed on multiple slots.

## Minimap button

A round Action Bar Master button sits on the minimap edge:

- **Right-click** — open (or close) the main window.
- **Shift-right-click** — small menu (Open / Hide minimap button).
- **Drag** — move the button around the minimap ring.

Left-click is unused for now. Toggle the button on or off any time with `/bars minimap`.

## Slash commands

| Command | Action |
|---|---|
| `/bars`, `/wbars` | Open or close the main window |
| `/bars minimap` | Show or hide the minimap button |
| `/bars resetpos` | Recenter the window (recovery if it ends up off-screen) |
| `/bars sn` | Autosave now |
| `/bars dupes` | Open the duplicate-slot scanner |

## Dependencies

Requires **LibNAddOn** and **LibNUI**.

## Saved data

Stored per account in `ActionBarMasterDB` (profiles, window position, bar display order, and minimap-button state).
