---
name: dibs
description: >-
  Take exclusive occupancy of a working directory so only one coding agent
  works in it at a time. Use before a tool or agent starts mutating a directory
  that another agent (often a different vendor) might also pick up, or when you
  need to know who currently holds a directory. claim/release/check on a
  vendor-neutral, cross-platform lockfile keyed by the directory's realpath;
  self-heals a lock left by a dead process and respects a live one.
---

# dibs

Calling dibs on a directory: a small, vendor-neutral, cross-platform lock so
only one coding agent occupies a working directory at a time. A Claude and a
Codex contend for the same lock through the same on-disk artifact, so neither
needs to know about the other's hooks.

The lock is a file created with an atomic exclusive create
(`open(O_CREAT|O_EXCL)`, the node `wx` flag) at a deterministic path keyed by
the target directory's realpath: `${LAICLUSE_HOME:-$HOME/.laicluse}/locks/<sha256-of-realpath>.lock`.
The record holds the realpath, holder pid, agent, session id, hostname, a
nonce, and an acquired-at timestamp. Liveness is pid-based
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
node "$DIBS" claim   <dir> [--pid <n>] [--agent <name>] [--session <id>] [--max-age-hours <n>] [--json]
node "$DIBS" release <dir> [--pid <n>] [--json]
node "$DIBS" check   <dir> [--max-age-hours <n>] [--json]
```

- **claim** takes exclusive occupancy. It exits 0 when it claims a free
  directory, re-claims one you already hold (`held-by-self`), or takes over a
  stale lock whose holder is dead (`took-over-stale`). It exits non-zero and
  names the holder (`refused: held by <agent> (pid <pid>) since <acquired-at>`)
  when a live holder exists.
- **release** deletes the lock only if you are the holder; releasing a lock held
  by someone else is refused and exits non-zero, releasing an unheld directory
  is a no-op.
- **check** prints `free` or the holder plus its liveness and staleness.

`--pid` is the pid that must stay alive for the lock to count as live. Record
the long-lived holder (the agent or session process), not the ephemeral process
that runs `dibs`. It defaults to the calling process's parent pid. `--json`
prints the full result record for machine consumers.

## Who calls dibs

The lock only helps if it is acquired before mutation, so the two reliable
acquisition points are:

- **Session start.** A coding agent claims the directory it is about to work in
  as part of its session-start path, and releases on session end. Claude and
  Codex call the same CLI; the on-disk lock is the shared artifact.
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
- **Occupancy, not git.** This prevents two agents occupying a directory; it is
  not a git lock and does not replace git's own `index.lock`.
