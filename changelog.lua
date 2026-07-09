---@class ActionBarMaster
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by addon-ci's release.yml
-- from the same conventional-commit grouping used for the GitHub / CurseForge
-- release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r4", notes = [==[
### Features
- on-screen bar-name labels while the window is open (#115)
- in-game changelog viewer via LibNAddOn (#116)

### Maintenance
- license copyright holder to Roshne (#117)

]==] },
  { version = "12.0.7-r3", notes = [==[
### CI
- add Discord merged-PR notifications + document the release flow (#113)
]==] },
  { version = "12.0.7-r2", notes = [==[
### Bug Fixes
- wipe pending item-info deferrals at restore entry (#109)

### Refactoring
- split restore.lua and dupes.lua under the file-size cap (#111)

### Maintenance
- low-severity code-review nits (barsicons identity, dupes special, filter arrow) (#110)

### Documentation
- fix inverted DST comment on release cron (#112)
]==] },
  { version = "12.0.7-r1", notes = [==[
Initial CurseForge release.

### Highlights
- Capture & restore action bars, keybindings, macros, pet bar, and equipment-set placements as named profiles
- Share profiles as encoded text (Export / Import), including partial all-class "shared bars" profiles
- Visual bars preview grid with per-bar checkboxes, drag-to-reorder, and a duplicate-action scanner
- Autosave on login and spec change; minimap button + addon-compartment entry
]==] },
}
