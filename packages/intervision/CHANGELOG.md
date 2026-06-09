# intervision changelog

Each entry corresponds to the `version` in `.claude-plugin/plugin.json`. The
post-update broadcast (see `bin/check-broadcast`) shows the section for the
currently-installed version exactly once per machine.

Categories:

- **Breaking**: user must adapt
- **Added**: new commands, new optional behavior
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

Patch-level fixes that change nothing the user can observe are intentionally
omitted; the broadcast budget is for things the user benefits from knowing.
The helper writes the sentinel only when stdout is non-empty, so a CHANGELOG
without a `## [vX.Y.Z]` section stays silent on every update.

## [v1.0.1]

### Changed

- **Private multi-agent baseline.** `second-opinion` now has agent-specific
  sources: Claude asks Codex via `codex exec`, while Codex asks Claude via
  `claude -p`. Runtime state moved under
  `${LAICLUSE_AGENT_HOME:-~/.laicluse-agent}/intervision`.

## [v1.0.7]

### Added

- New plugin. `/intervision:second-opinion` brings Codex in as a peer to review
  work just done or just discussed via `codex exec`, surfaces its independent
  read, and goes back and forth. Needs the `codex` CLI installed and logged in.
