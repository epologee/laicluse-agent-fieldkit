# rover changelog

The post-update broadcast (see `bin/check-broadcast`) shows the topmost section
once per machine whenever the installed `version` in
`.claude-plugin/plugin.json` changes. Header version numbers are informational;
the broadcast is positional.

## [v2.0.0]

### Breaking

- Slash commands moved from `/autonomous:...` to `/rover:...`
  (`/rover:rover`, `/rover:stop`, `/rover:pride`, `/rover:trim`,
  `/rover:verify`, `/rover:decide`, `/rover:prepare`, `/rover:rover-help`).
  Waking a mission is now `/rover:rover .autonomous/<NAME>.md`. Install
  `rover@laicluse-agent-tools` alongside `autonomous@laicluse-agent-tools`;
  `autonomous@leclause` is a tombstone pointing here. Existing `.autonomous/`
  loop files stay compatible: the format is unchanged and waking them with the
  new command continues a mission exactly where it stopped.

### Added

- Ported from `autonomous@leclause` and split: `rover` carries the decision
  framework (rover, rover-help, decide, prepare, pride, trim, verify, stop).
  The keep-alive machinery (cron heartbeat, wake/restore) moved to the
  `autonomous` plugin.
- At dispatch the rover asks `autonomous:keepalive` whether it is in a
  persistent process. The caller no longer instructs it to "skip the cron";
  the probe makes that call.
