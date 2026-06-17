# dibs changelog

The post-update broadcast shows the topmost section once per machine whenever
the installed `version` in `.claude-plugin/plugin.json` changes. Keep entries
short; categories are Breaking, Added, Changed, Fixed.

## [v1.0.0]

### Added

- **Single-occupancy lock**: `dibs claim`, `dibs release`, and `dibs check`
  arbitrate exclusive occupancy of a working directory across vendors and
  platforms, with `--json` facts output.
- **Atomic, dependency-free**: locks are atomic exclusive-create files keyed by
  the directory's realpath under `${LAICLUSE_HOME:-$HOME/.laicluse}/locks/`. No
  `flock`, no native binding.
- **Self-healing**: a lock left by a dead holder pid is taken over by the next
  claimer; a live holder is respected and reported with who holds it and since
  when. An optional `--max-age-hours` cap bounds foreign-host locks.
- **Consumed, not duplicated**: `bonsai` claims the lock for the directory it
  hands out by importing the one dibs implementation. No second lock path.
