# house-rules changelog

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

## [v2.0.6]

### Changed

- **Testing doctrine now says default branch.** The examples point at Git's
  default-branch metadata so the prose no longer trains agents to treat `main`
  as universal.

## [v2.0.1]

### Breaking

- **naming-is-hard has moved into house-rules.** The standalone
  `naming-is-hard` plugin is retired. The `/naming-is-hard` skill is
  unchanged, but it now ships from `house-rules` rather than its own plugin.
  If you installed `naming-is-hard@laicluse-agent-fieldkit`, switch:

  ```bash
  claude plugins install house-rules@laicluse-agent-fieldkit
  claude plugins uninstall naming-is-hard@laicluse-agent-fieldkit
  ```

### Added

- **house-rules debuts as an opinionated craft-doctrine baseline.** It bundles
  three skills in the tradition of Beck, Martin, and Fowler:
  `programming-philosophy`, `testing-philosophy`, and the relocated
  `naming-is-hard`. `programming-philosophy` and `testing-philosophy` were not
  previously part of this marketplace; they ship here for the first time.
