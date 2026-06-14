# autonomous changelog

The post-update broadcast (see `bin/check-broadcast`) shows the topmost
section once per machine whenever the installed `version` in
`.claude-plugin/plugin.json` changes. Entry headers record the version at
which the entry was written; a pre-commit hook auto-bumps `plugin.json` on
every commit, so the header may lag the shipped version. Header numbers are
informational, the broadcast is positional. Use the `--force` flag on the
helper to re-read at any time.

## [v2.0.1]

### Breaking

- **`autonomous` is no longer advertised to Codex.** The keepalive, cron, and
  wake skills depend on Claude Code cron/session behavior. The generated Codex
  marketplace now omits the plugin instead of serving commands without a
  compatible runtime path.

## [v2.0.0]

### Breaking

- This plugin is now the keep-it-running layer only: the `keepalive` probe plus
  the `cron` and `wake` machinery. The decision framework (rover, decide, pride,
  trim, verify, prepare, stop) moved to `rover@laicluse-agent-fieldkit`. The old `autonomous:rover`,
  `autonomous:pride`, and the other decision skills are now `/rover:...`.
  Existing `.autonomous/` loop files stay compatible: the format is unchanged
  and the successor rover wakes them as-is.

### Added

- `keepalive` decides whether a mission needs a heartbeat by probing
  `CronCreate` availability instead of reading a caller flag. Available means an
  interactive session (schedule the cron); absent means a persistent process (drive
  to completion).
