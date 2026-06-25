---
name: dibs
user-invocable: true
description: >-
  Claim, check, or release a vendor-neutral directory lock before mutating a repo another agent might touch.
---

# dibs

Calling dibs on a directory: a small, vendor-neutral, cross-platform lock so
only one coding agent mutates a working directory at a time. A Claude and a
Codex contend for the same lock through the same on-disk artifact, so neither
needs to know about the other's hooks.

The lock is a file created with an atomic exclusive create
(`open(O_CREAT|O_EXCL)`, the node `wx` flag) at a deterministic path keyed by
the target directory's realpath: `${LAICLUSE_HOME:-$HOME/.laicluse}/locks/<sha256-of-realpath>.lock`.
The record holds the realpath, holder pid, agent, session id, stable owner id,
hostname, a nonce, and an acquired-at timestamp. Liveness is pid-based
(`process.kill(pid, 0)` on the same host), not a heartbeat: a lock whose holder
process is gone is taken over by the next claimer, while a live holder is
refused. No external binary, no `flock`, no native dependency.

## Resolve the bin (cross-agent)

The CLI lives in this plugin's `bin/`. Resolve the plugin root, then call it:

```bash
resolve_dibs_root() {
  if [ -n "${DIBS_BIN:-}" ]; then dirname "$(dirname "$DIBS_BIN")"; return 0; fi
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then printf '%s\n' "$CLAUDE_PLUGIN_ROOT"; return 0; fi
  if command -v codex >/dev/null 2>&1; then
    codex plugin list | awk '$1 == "dibs@laicluse-agent-fieldkit" { print $NF; found=1; exit } END { exit found ? 0 : 1 }'
    return $?
  fi
  return 1
}
ROOT="$(resolve_dibs_root)" || { echo "dibs plugin root not found" >&2; exit 1; }
DIBS="${DIBS_BIN:-$ROOT/bin/dibs}"
```

## Use the lock

```bash
node "$DIBS" claim   <dir> [--pid <n>] [--agent <name>] [--session <id>] [--owner <id>] [--max-age-hours <n>] [--json]
node "$DIBS" release <dir> [--pid <n>] [--json]
node "$DIBS" check   <dir> [--max-age-hours <n>] [--json]
```

- **claim** takes exclusive occupancy. It exits 0 when it claims a free
  directory, re-claims one you already hold (`held-by-self`), reclaims one with
  the same stable owner (`reclaimed-by-owner`), or takes over a stale lock whose
  holder is dead (`took-over-stale`). It exits non-zero and names the holder
  (`refused: held by <agent> (pid <pid>) since <acquired-at>`) when a live holder
  exists. A refusal suggests creating a separate git worktree on a new branch
  (for example with `bonsai:bonsai`, or plain `git worktree` if you do not have
  it) and claiming that worktree path.
- **release** deletes the lock only if you are the holder; releasing a lock held
  by someone else is refused and exits non-zero, releasing an unheld directory
  is a no-op.
- **check** prints `free` or the holder plus its liveness and staleness.

`release` is an explicit recovery/operator action, not normal end-of-task
cleanup. After a coding agent claims occupancy through the hook, keep the lock
until the host's session end mechanism releases it (Claude) or until
pid-liveness/owner reclaim clears it on the next claim (Codex). Do not manually
release a live agent lock just because the current task is committed, tests are
green, or the final answer is being written.

`--pid` is the pid that must stay alive for the lock to count as live. Record
the long-lived holder (the agent or session process), not the ephemeral process
that runs `dibs`. It defaults to the calling process's parent pid. `--json`
prints the full result record for machine consumers.

`--owner` is a stable identity for resumed sessions. The occupancy hook sets it
from `DIBS_OWNER`, then for Codex from `CMUX_TAB_ID`, `CMUX_WORKSPACE_ID`,
`CODEX_THREAD_ID`, or the hook session id, so a Codex resume can reclaim its own
old lock even when pid, host, or thread id changed.

## Who calls dibs

The lock only helps if it is acquired before mutation, so the reliable
acquisition points are:

- **Pre-mutation hook.** A coding agent claims the directory at its first
  mutating file edit, not when the session starts. Read-only questions in an
  occupied directory stay quiet; the refusal and worktree recovery suggestion
  appear only when another live session already holds the directory and this
  session tries to write. Claude and Codex call the same CLI; the on-disk lock
  is the shared artifact.
- **Directory handout.** `bonsai` claims the lock for a worktree it hands out
  (it consumes this one implementation; there is no second lock anywhere). The
  git-native commit hook in the branch-worktree-discipline order remains the
  backstop for agents without a reliable pre-mutation hook.

## Scope and caveats

- **Single machine.** Atomic-create semantics and pid-liveness are host-local.
  A directory shared over NFS or another network filesystem is out of scope for
  v1; cross-machine arbitration needs a lease broker, not this lock.
- **pid recycling.** A dead holder's pid reused by an unrelated live process can
  read as alive. The acquired-at timestamp and `--max-age-hours` cap bound the
  residual risk; v1 accepts it rather than adding a native process-start probe.
- **Same-user liveness.** A holder owned by another user or namespace reads as
  alive (`EPERM`), so dibs never breaks a lock it cannot prove dead; that lock
  clears only via `--max-age-hours`. Within one user on one machine, the agent
  case, liveness is exact.
- **Occupancy, not git.** This prevents two agents occupying a directory; it is
  not a git lock and does not replace git's own `index.lock`.
