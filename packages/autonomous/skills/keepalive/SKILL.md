---
name: keepalive
description: Startup probe for the autonomy layer. Answers one question for a dispatched mission, what keeps me alive across turns, by probing which scheduling hooks the runtime exposes. Sets up a cron heartbeat (interactive session), a self-check wake-up heartbeat (persistent process that can self-pace), or nothing (pure batch run), and reports back which. Loaded by rover at dispatch.
user-invocable: false
effort: low
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the autonomous plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("autonomous was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. In agents that do not set
`CLAUDE_PLUGIN_ROOT` the broadcast is intentionally skipped; that is the
guard's purpose, not an oversight.
</post-update-broadcast>

# Autonomy Keepalive

The front door to the autonomy layer. A mission calls this skill once, at startup, and asks a single question:

> What keeps me alive across turns: a cron, a self-paced wake-up, or nothing because I run straight through?

Keepalive answers that question by itself, from the runtime, and acts on the answer. The caller does not have to know anything about cron or wake-up internals; it does not pass a flag, an env var, or a "skip the heartbeat" instruction. It invokes keepalive and uses what comes back.

## Why this skill exists

The caller used to have to know whether its session needed a heartbeat and tell the mission "skip the cron", leaking the autonomy layer's internals into whatever dispatches it. Keepalive moves that decision where it belongs: the autonomy layer probes its own runtime and decides. (The `autonomous` README carries the full runtime-mode rationale.)

## The probe

The signal is **tool availability**, not an environment flag and not a caller contract. Probe two hooks, in order, and take the first branch that matches.

1. **Is `CronCreate` reachable in this process?** Inspect the available tool inventory: `CronCreate` is either a directly available tool or appears in the deferred-tool list loadable via `ToolSearch` (`select:CronCreate`). If it is present or loadable, treat CronCreate as **available**; if it is genuinely absent (not in the tool list and ToolSearch returns nothing for it), treat it as **unavailable**.
2. **If CronCreate is unavailable, is a self-pacing wake-up hook reachable?** The Claude harness exposes `ScheduleWakeup` for this; probe it the same way (`select:ScheduleWakeup` via `ToolSearch`, or a directly available tool). A future runtime may expose a differently-named hook of the same shape; the question is whether the process can schedule its own delayed re-entry.

CronCreate is probed first because the two heartbeat mechanisms are mutually exclusive by host design: an interactive host exposes the cron tools, a self-pacing persistent host withholds them and leaves the wake-up hook. If a host exposed both, the cron branch would win, which is the right call for an interactive session; a host that withholds cron is the signal to look for the wake-up hook. So the ordering is not arbitrary, it encodes which mode each tool combination means.

Branch on the result:

   **CronCreate available, so an interactive session.** The harness exposes the cron machinery because this session needs it: it goes idle between turns and would not survive without a heartbeat. Set it up. Invoke `autonomous:cron` via the Skill tool to `CronCreate` at `* * * * *` with the loop-file path the caller passed, exactly as the cron setup step describes. Return the job id to the caller so it writes `cron_job_id: <id>` into the loop file.

   **CronCreate unavailable but a wake-up hook is available, so a persistent process that can self-pace.** Nothing pauses this process the way a REPL pauses, but it can still end a turn quietly and go silent, and a host that watches for stalls will kill a silent run. So it needs a heartbeat too, just a self-paced one rather than a cron. Set it up. Invoke `autonomous:selfcheck` via the Skill tool to schedule the first self-check wake-up at its interval with the loop-file path. Return the sentinel `none (self-check heartbeat)` so the caller writes `cron_job_id: none (self-check heartbeat)` into the loop file. The selfcheck skill owns the interval, the re-entry contract, and the teardown.

   **Neither hook available, so a pure batch process.** Nothing exposes a heartbeat and nothing here can schedule one; this process genuinely drives the phase machine to completion in one run and exits. Do not schedule anything. Return the sentinel `none (persistent process)` so the caller writes `cron_job_id: none (persistent process)` into the loop file and proceeds straight into the first phase. The loop-file discipline is still kept (an interactive session can `wake` the file later if this run dies), but no heartbeat is scheduled.

## The return contract

Keepalive hands the caller exactly one value for the loop file's `cron_job_id` field:

- A cron job id — a cron heartbeat is scheduled; the caller is interactive.
- `none (self-check heartbeat)` — a self-paced wake-up heartbeat is scheduled; the caller is a persistent process that can re-enter itself.
- `none (persistent process)` — no heartbeat; the caller is a pure batch run and drives straight to completion.

The caller (see `rover` setup) writes that value into the loop file and continues. With a cron, the loop's cron-dependent behaviour (STANDBY backoff, interjection reschedule, `wake` restore) is live. With a self-check heartbeat, the wake-up re-enters on its interval, beats the host stall timer, and ends by not rescheduling; the cron-specific machinery no-ops (no cron exists) while `selfcheck` carries the heartbeat. With neither, the phase machine runs once, end to end, and the mission ends through `stop`.

## The load-bearing assumption

This is a deliberate design choice, not a natural law: the autonomy layer **reads the runtime's scheduling hooks as the signal for which heartbeat (if any) it needs**. The probe is only correct when **need and availability coincide**: a host whose sessions go idle between turns must expose `CronCreate`; a host that runs a persistent process which can still fall silent must expose a self-pacing wake-up hook; and only a host running a true single-pass batch should expose neither. Capability and need are braided into one on purpose, because the probe then needs no coordination between the caller and the host: an explicit flag would require both sides to agree on a name and a value, and that agreement is itself state this design eliminates. The trade is that a host changing its tool configuration is also changing heartbeat semantics; that coupling is the price of the zero-coordination contract.

A host that wants a self-paced persistent mode (the conveyor case) withholds the cron tools (`CronCreate`, `CronDelete`, `CronList`) but leaves the wake-up hook reachable. A host that wants a pure batch run with no heartbeat at all withholds both.

**Degradation when the assumption is not yet met.** If a persistent host still exposes `CronCreate`, the probe reports interactive and schedules a cron. On the normal path that cron is dead weight: a process that runs to completion never goes idle, so the heartbeat never fires and is torn down with the session. The mission still drives to completion through its phase machine; the cost is one wasted `CronCreate` call, not a broken run. On an abnormal exit (the process is killed or preempted mid-phase) the scheduled cron can outlive the session the way any orphan cron can (see `cron`'s note on crons surviving a `SessionStart:resume`); the `wake` restore path reaps such an orphan on the next manual relight. The newer hazard the self-check branch removes is the opposite one: a host that withheld cron but left the wake-up hook reachable used to fall through to "no heartbeat" and let a quietly-stalled run die silently; now it gets the self-check heartbeat instead. Either way the fix for a mismatched host belongs on the host side (configure the tool inventory to match the mode it wants), not here; this skill does not invent an env-var fallback to second-guess the tool probe.

## What it does not do

Keepalive does not write the loop file: the caller owns that and keepalive only returns the value for `cron_job_id`. It is a one-shot setup probe, not a phase, and it never touches the loop-file format. It does not own the cron or wake-up mechanics either: it routes to `autonomous:cron` or `autonomous:selfcheck` and lets each own its own interval, re-entry, and teardown.
