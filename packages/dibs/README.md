# dibs

A single-occupancy lock for a working directory. Two coding agents, often
cross-vendor (a Claude and a Codex), can start working in the same directory at
the same time and overwrite each other. dibs lets one agent take exclusive
occupancy of a directory and makes the next one step aside. Any tool or agent
can take the lock and any other can observe it, regardless of vendor or
platform.

It is deliberately not a git tool: it locks any working directory or resource,
not only git worktrees. `bonsai` creates worktrees and consumes dibs to claim
the directory it hands out; the lock logic lives in exactly one place.

## CLI

```
dibs claim   <dir> [--pid <n>] [--agent <name>] [--session <id>] [--max-age-hours <n>] [--json]
dibs release <dir> [--pid <n>] [--nonce <hex>] [--json]
dibs check   <dir> [--max-age-hours <n>] [--json]
```

All three verbs require the directory to exist; the lock is keyed by its
realpath, so a missing path is a clear error rather than a silently divergent
key.

- **claim** takes exclusive occupancy of a directory keyed by its realpath.
  Exits 0 on a fresh claim, on an idempotent re-claim by the same holder
  (`held-by-self`), or on taking over a stale lock whose holder pid is dead
  (`took-over-stale`). Exits non-zero and reports the holder when a live holder
  exists.
- **release** deletes the lock only if you are the holder. Releasing a lock held
  by another is refused; releasing an unheld directory is a no-op.
- **check** reports `free`, or the holder with its liveness and staleness.

`--pid` is the holder pid whose liveness defines the lock; default is the
calling process's parent pid. Record the long-lived agent or session process,
not the ephemeral `dibs` invocation.

## How it works

A lock is a file written with an atomic exclusive create (`open(O_CREAT|O_EXCL)`,
the node `wx` flag) at
`${LAICLUSE_HOME:-$HOME/.laicluse}/locks/<sha256-of-realpath>.lock`. The record
is JSON: realpath, holder pid, agent, session, hostname, nonce, acquired-at.

To acquire, dibs tries the atomic create. On collision it reads the record and
checks liveness with `process.kill(pid, 0)` on the same host. A dead holder
(or a foreign-host lock past the optional age cap) is broken and taken over; a
live holder is respected and reported. Release deletes the file only for the
holder.

This is the portable, dependency-free primitive. `flock(1)` is not shipped on
macOS, the `flock(2)` syscall needs a native binding and a session-lived holder
process, and both are host-only. Atomic exclusive create is present everywhere
node runs (macOS, Linux, Windows), gives the same mutual exclusion with zero
dependencies, and self-heals through pid-liveness.

## Scope and non-goals

- **Single machine.** Atomic-create semantics and pid-liveness are host-local.
  Directories shared over NFS or another network filesystem are out of scope
  for v1; cross-machine arbitration is a lease-broker problem, not this lock's.
- **pid recycling.** A recycled pid can read as a live holder. The acquired-at
  timestamp and `--max-age-hours` cap bound the residual risk; v1 accepts it
  rather than probing process start-time natively. When set, `--max-age-hours`
  deliberately overrides liveness: a lock older than the cap is broken even if
  its pid still reads alive, which is the recycling mitigation. Left unset (the
  default), pid-liveness is authoritative and a live holder is never broken. The
  recorded `nonce` identifies a specific claim for logs and observability and is
  not consulted for liveness; `release --nonce <hex>` optionally binds a release
  to one specific claim so a recycled pid cannot release a lock it did not take.
- **Same-user liveness.** `process.kill(pid, 0)` reports a process owned by
  another user or living in another namespace as alive (`EPERM`), so dibs never
  breaks a lock it cannot positively prove dead; such a lock clears only through
  the `--max-age-hours` cap. Within one user on one machine, the agent case,
  liveness is exact.
- **Occupancy, not git.** dibs prevents concurrent occupancy. It is not a git
  lock and does not replace git's own `index.lock`.

## Library

`bin/dibs-lib.mjs` exports `claim`, `release`, `check`, `isAlive`, `locksDir`,
`lockPathFor`, and `canonicalDir` as pure node ES modules with no third-party
imports. Consumers in the same marketplace import it directly so there is a
single lock implementation and no parallel path:

```js
import { claim } from '../../dibs/bin/dibs-lib.mjs';

const result = claim({ dir, pid: process.ppid, agent: 'my-tool' });
if (!result.ok) console.warn(`held by ${result.holder.agent}`);
```

An embedder that hands out a directory on behalf of a long-lived caller (as
`bonsai` does) records that caller's pid, not its own short-lived process.
`bonsai` reads `DIBS_HOLDER_PID`, `DIBS_AGENT`, and `DIBS_SESSION` to label the
holder, and `DIBS_LIB` to point at an alternate lib path. The CLI honours
`DIBS_BIN` for a fixed binary path.
