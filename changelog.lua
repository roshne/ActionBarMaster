---@class ActionBarMaster
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by addon-ci's release.yml
-- from the same conventional-commit grouping used for the GitHub / CurseForge
-- release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.1.0-r1", notes = [==[
### Maintenance
- target WoW 12.1.0 (Interface 120100) (#137)

]==] },
  { version = "12.0.7-r11", notes = [==[
### CI
- stop announcing docs-only pushes (#136)

]==] },
  { version = "12.0.7-r10", notes = [==[
### Bug Fixes
- unify the skyriding bar on "Sky" (#135)

### Other Changes
- docs+fix: dead tooltip helpers, README drift from #126, and two window.lua nits (#134)

]==] },
  { version = "12.0.7-r9", notes = [==[
### Bug Fixes
- clear petaction/futurespell slots instead of round-tripping them (#133)

]==] },
  { version = "12.0.7-r8", notes = [==[
### CI
- add push-notify caller (one post per push, as Github-Repo-Updates) (roshne/Tooling#111)

]==] },
  { version = "12.0.7-r7", notes = [==[
### Features
- replace fixed 15x12 grid with topographic view as primary editor (#126)
- docked real-layout bar preview via ui.BarsPreview (#125)

### Refactoring
- use shared ns.wow.collectActionButtons/actionSlotOf (#123)

]==] },
  { version = "12.0.7-r5", notes = [==[
### Bug Fixes
- drop special=true from the detail window (multi-close in combat) (#122)

]==] },
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
