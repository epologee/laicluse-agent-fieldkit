# intervision changelog

The post-update broadcast (see `bin/check-broadcast`) shows the topmost
section once per machine whenever the installed `version` in
`.claude-plugin/plugin.json` changes. Entry headers record the version at
which the entry was written; a pre-commit hook auto-bumps `plugin.json` on
every commit, so the header may lag the shipped version. Header numbers are
informational, the broadcast is positional. Use the `--force` flag on the
helper to re-read at any time.

Categories:

- **Breaking**: user must adapt
- **Added**: new commands, new optional behavior
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

Patch-level fixes that change nothing the user can observe are intentionally
omitted; the broadcast budget is for things the user benefits from knowing.
The helper writes the sentinel only when stdout is non-empty, so a CHANGELOG
without a `## [vX.Y.Z]` section stays silent on every update.

## [v2.0.1]

### Changed

- **intervision now ships from the public laicluse-agent-fieldkit marketplace.**
  Install the Fieldkit copy for the current Claude-to-Codex and Codex-to-Claude
  peer review workflow.
- **`second-opinion` is multi-agent.** Claude asks Codex via `codex exec`,
  while Codex asks Claude via `claude -p`. Runtime state lives under
  `${LAICLUSE_HOME:-~/.laicluse}/intervision`.

## [v1.0.7]

### Added

- New plugin. `/intervision:second-opinion` brings Codex in as a peer to review
  work just done or just discussed via `codex exec`, surfaces its independent
  read, and goes back and forth. Needs the `codex` CLI installed and logged in.
