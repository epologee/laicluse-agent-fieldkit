# laicluse-agent-tools changelog

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

## [v2.0.2]

### Fixed

- **`/whats-new` is Claude-only for now.** The command reads Claude plugin
  install metadata and marketplace changelog state, so the generated Codex
  marketplace no longer advertises it until a Codex runtime path exists.

## [v2.0.1]

### Added

- **`/whats-new` is the marketplace-wide changelog reader.** With a
  plugin name it reprints that plugin's latest CHANGELOG section without
  touching the broadcast sentinel; without arguments it shows the
  marketplace-wide news plus an index of plugins that ship a CHANGELOG.
  The namespaced form is `/laicluse-agent-tools:whats-new`; this was ported
  from `/leclause:whats-new`, which keeps working for plugins that remain on
  the legacy marketplace.

### Fixed

- **The marketplace utility plugin is named `laicluse-agent-tools`.** The
  earlier package name `laicluse` was a naming mistake and is not kept as a
  separate alias. Use the bare `/whats-new` command for daily use.
