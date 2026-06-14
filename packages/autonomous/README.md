# autonomous

The layer that keeps an autonomous mission running across turns. It owns the
persistence workarounds an interactive session needs to stay alive (a cron
heartbeat with exponential backoff, auto-stop after sustained idleness, and
wake/restore after a session restart) and decides by itself whether any of that
machinery is needed.

The decision is a capability probe, not a caller flag. The `rover` plugin's
decision framework calls this layer once at dispatch and asks a single
question: what keeps me alive across turns, a cron, a self-paced wake-up, or
nothing? The probe answers from the runtime.

## Why this is its own plugin

A cron heartbeat is a workaround for one fact: an interactive TUI session is
not a persistent process. It runs a turn, then waits for the operator, and an
autonomous loop in that session stops between turns unless something re-enters
the conversation. A persistent process (a conveyor line, a detached run) keeps
executing rather than waiting on the operator, but that does not make it
immortal: it can still end a turn quietly and go silent, and a host that watches
for stalls will kill a silent run. When such a process can schedule its own
wake-up (the conveyor `claude --bg` case exposes one even with the cron tools
withheld), it gets a self-paced heartbeat instead of a cron. Only a true
single-pass batch run, which exposes no scheduling hook at all, needs no
heartbeat.

Splitting the keep-alive machinery out of the decision framework means the
caller no longer has to know any of this. It invokes `rover`, the rover invokes
`autonomous:keepalive`, and the autonomy layer probes its own runtime and acts.

## Skills

All skills here are internal: the `rover` plugin loads them, the operator does
not invoke them directly.

- **`keepalive`**: the startup probe and front door. Checks which scheduling
  hooks the process exposes. `CronCreate` available means an interactive session,
  so it schedules a cron heartbeat through `cron` and returns the job id. No cron
  but a self-pacing wake-up hook means a persistent process that can still fall
  silent, so it schedules a self-check heartbeat through `selfcheck`. Neither
  hook means a pure batch run, so it schedules nothing and reports back that the
  mission should just drive to completion.
- **`cron`**: the cadence machine. CronCreate, CronDelete, exponential backoff
  when the field goes quiet, auto-stop after sustained idleness, and cron
  restoration after a session restart.
- **`selfcheck`**: the self-paced heartbeat for a persistent process with a
  wake-up hook but no cron. Re-enters on an interval below the host's stall
  window, re-engages a quietly-ended turn, writes a progress beat that resets the
  stall timer, and reaches a terminal verdict when the work is truly done or
  blocked. Ends by not rescheduling.
- **`wake`**: bring a stalled mission back online. Reads the loop file, relights
  the cron, summarises where the traverse left off, and fires the next
  iteration. Reached via `rover:rover` with a loop-file path.

Coming from `autonomous@leclause`? The decision skills you used to reach as
`/autonomous:rover`, `/autonomous:pride`, and so on now live in the `rover`
plugin: install `rover@laicluse-agent-tools` and use `/rover:rover`,
`/rover:pride`, and the rest.

## The probe and its one assumption

The probe is correct only when need and availability coincide: a host whose
sessions go idle between turns must expose `CronCreate`; a host that runs a
persistent process which can still fall silent (the conveyor case) must withhold
the cron tools but leave a self-pacing wake-up hook reachable; and only a true
single-pass batch run should expose neither. When a persistent host still
exposes the cron tools the probe over-detects interactive and schedules a cron
heartbeat. On the normal path that is dead weight: a process that runs to
completion never goes idle, so the cron never fires and is torn down with the
session. Only an abnormal exit can leave it as an orphan, which the `wake`
restore path reaps on the next relight. See `skills/keepalive/SKILL.md` for the
full contract.

## Companion plugin

The decision framework lives in `rover` (invoked as `/rover:...`). Install both
together; `rover` additionally depends on `gurus` for its INSPECT panel review:

```bash
claude plugins install autonomous@laicluse-agent-tools rover@laicluse-agent-tools gurus@laicluse-agent-tools
codex plugin add autonomous@laicluse-agent-tools
codex plugin add rover@laicluse-agent-tools
codex plugin add gurus@laicluse-agent-tools
```
