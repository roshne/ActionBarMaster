# Contributing

This repo is a standalone WoW addon, checked out (or symlinked) into a WoW installation's
`Interface/AddOns/` directory. There is no build step and no package manager — edits are
live on the next `/reload`.

For a code-level map — file map, namespace API surface, DB/settings schemas, profile table
structure, and the slash command registry — start at [CONTEXT.md](CONTEXT.md). Coding
conventions are in [CLAUDE.md](CLAUDE.md); the highlights are below.

## Code style

- 2-space indent.
- Every file imports the namespace with `local _, ns = ...`.
- Classes are defined with `local Foo = Class(Parent, function(self) ... end, { defaults })`.
- UI widgets are accessed only through `self._widget` — never reach into `_widget` from
  outside a class.
- Everything belongs on a class or the addon namespace — no standalone globals/utilities.
- LuaLS annotations (`---@class`, `---@field`, `---@param`, `---@return`) on public surface.
- WoW runs **Lua 5.1** — no `goto`, no `//`, no bitwise operators, no `table.unpack`.
- Keep files within ~200–300 lines; split by responsibility (data / view / controller)
  beyond that.

## Dependencies

Depends on **LibNAddOn** (addon init, events, DB, settings, slash commands) and **LibNUI**
(OOP UI widgets). Both must be installed alongside this addon.

## Database compatibility

- DB upgrades must be **non-destructive**: `MigrateDB` adds keys, never removes or
  repurposes them, so a user can roll back to an earlier revision without data loss.
- If keys become stale after an upgrade, remove them via an explicit cleanup command —
  never automatically.

## Testing

- **In-game**: `/reload` after changes. `/dump <expr>` and `/run <lua>` inspect live data
  (e.g. `/run print(GetActionInfo(1))`, `/dump ns.db.profiles`).
- **Lint**: `luacheck` (config in `.luacheckrc`). CI is **strict** — any warning fails the
  build, and the repo lints clean. Keep it that way. When you add a WoW global, add it to
  `read_globals`.
- CI runs luacheck on every PR and push to `main` (`.github/workflows/ci.yml`).

## Branching

`main` is protected — always work on a feature branch and open a pull request; never commit
directly to `main`.

## Versioning

`## Version:` in the `.toc` is `MAJOR.MINOR.PATCH-rREVISION`, where `MAJOR.MINOR.PATCH`
mirrors the WoW client version (e.g. `12.0.7-r0`). Bump `MAJOR.MINOR.PATCH` when adding
support for a new client version (alongside the `## Interface:` field); increment
`-rREVISION` for subsequent releases within the same client version. Doc-only (`.md`)
changes don't warrant a revision bump.
