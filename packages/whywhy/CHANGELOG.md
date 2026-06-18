# whywhy changelog

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

## [v2.0.1]

### Added

- **whywhy now ships from the public laicluse-agent-fieldkit marketplace.**
  The `/whywhy [count] <question>` skill drills a configurable "why?" chain
  (default 10 layers, based on Toyota's 5 Whys) and then analyzes the chain
  for convergence, breakpoints, circles, and a better-framed goal at a deeper
  layer. Available to both Claude Code and Codex.
