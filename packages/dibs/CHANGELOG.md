# dibs changelog

The post-update broadcast shows the topmost section once per machine whenever
the installed `version` in `.claude-plugin/plugin.json` changes. Keep entries
short; categories are Breaking, Added, Changed, Fixed.

## [v2.0.11]

### Fixed

- **Occupancy now refuses a codex nested under a Claude session.** A codex
  started inside a Claude session (intervision, `codex exec`) runs below the
  Claude process, and the holder-pid walk climbed to the topmost agent
  ancestor, landing on the Claude pid that already held the directory, so dibs
  read held-by-self and allowed the edit. The walk now stops at the nearest
  agent ancestor, and the agent label keys on `PLUGIN_ROOT` (which codex sets
  alongside `CLAUDE_PLUGIN_ROOT`) so a nested codex no longer mislabels itself
  as claude.

## [v2.0.9]

### Added

- **Universal occupancy enforcement hooks.** dibs now ships
  `hooks/occupancy.sh` (with `hooks/hooks.json` for Claude and
  `hooks/hooks.codex.json` for Codex), so single-occupancy is enforced for every
  agent session, not only the worktrees `bonsai` hands out. SessionStart claims
  the working directory and steers a latecomer aside, a PreToolUse file-edit gate
  hard-denies a write when a different live agent session holds the directory,
  and Claude SessionEnd releases while Codex relies on pid-liveness self-heal.
  Self-recognition keys on the lock's session id so a drifted worker pid never
  blocks the agent against its own lock, and the gate fails open on anything that
  is not a positive cross-session refusal. The hooks shell out to this plugin's
  own CLI; no lock logic is duplicated. Opt out per session with
  `DIBS_OCCUPANCY=off`.

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
