# naming-is-hard changelog

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

- **naming-is-hard now ships from the public laicluse-agent-fieldkit
  marketplace.** The `/naming-is-hard` skill loads the canonical l'Aicluse
  naming and wording doctrine for code symbols, domain language, branches,
  worktrees, commits, pull requests, docs, UI copy, and Dutch/English mixed
  wording. The full doctrine lives in
  `skills/naming-is-hard/references/naming-doctrine.md`.
