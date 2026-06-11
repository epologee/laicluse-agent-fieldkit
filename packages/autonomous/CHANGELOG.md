# autonomous changelog

## [v2.0.0]

### Breaking

- Reshaped from `autonomous@leclause`. This plugin is now the keep-it-running
  layer only: the `keepalive` probe plus the `cron` and `wake` machinery. The
  decision framework (rover, decide, pride, trim, verify, prepare, stop) moved
  to `rover@laicluse-agent-tools`. The old `autonomous:rover`,
  `autonomous:pride`, and the other decision skills are now `/rover:...`.

### Added

- `keepalive` decides whether a mission needs a heartbeat by probing
  `CronCreate` availability instead of reading a caller flag. Available means an
  interactive session (arm the cron); absent means a persistent process (drive
  to completion).
