# dibs changelog

The post-update broadcast shows the topmost section once per machine whenever
the installed `version` in `.claude-plugin/plugin.json` changes. Keep entries
short; categories are Breaking, Added, Changed, Fixed.

## [v2.0.20]

### Changed

- **Occupancy starts at the first write, not session start.** Claude and Codex
  no longer claim or steer aside on `SessionStart`; the occupancy hook claims at
  the mutating file-edit gate and only suggests a separate worktree when that
  write would collide with another live agent.
- **Agent-held locks stay held after task completion.** The dibs skill and
  README now spell out that `release` is recovery/operator teardown, not normal
  end-of-task cleanup. Claude releases on `SessionEnd`; Codex relies on
  pid-liveness or owner reclaim.

## [v2.0.15]

### Changed

- **Blocked directories now point at a worktree recovery path.** `dibs claim`,
  JSON refusals, and the occupancy hook suggest creating a separate git worktree
  on a new branch and claiming that worktree path when another live agent holds
  the requested directory.

## [v2.0.14]

### Fixed

- **Codex resumes no longer self-lock on their old dibs claim.** Locks now carry
  a stable `owner` in addition to pid and hook session id. The occupancy hook
  fills it from `DIBS_OWNER`, then Codex surface ids (`CMUX_TAB_ID`,
  `CMUX_WORKSPACE_ID`, `CODEX_THREAD_ID`) before falling back to the hook
  session id. A resumed Codex with the same owner rewrites the lock to its new
  pid/host; a one-time legacy handoff lets resume clear older ownerless Codex
  locks.

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
