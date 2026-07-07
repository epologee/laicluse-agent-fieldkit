# saysay changelog

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

## [v2.0.7]

### Fixed

- **Default-branch speech context follows Git metadata.** Without an explicit
  `--context`, saysay no longer announces a non-`main` default branch as the
  session topic.

## [v2.0.1]

### Added

- **saysay now ships from the public laicluse-agent-fieldkit marketplace.**
  `/saysay` turns on speech mode: every response is spoken aloud through the
  macOS `say` command, translating screen content into spoken language rather
  than reading it out verbatim, and `/saysay off` exits. A per-user phonetic
  dictionary (`say-phonetic`) under `${LAICLUSE_HOME:-$HOME/.laicluse}` fixes
  mispronounced names and acronyms, and serialized, ducked playback lets
  parallel sessions speak one after another. macOS only.
