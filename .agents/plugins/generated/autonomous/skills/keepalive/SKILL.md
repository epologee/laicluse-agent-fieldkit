---
name: keepalive
description: Startup probe for the autonomy layer. Answers one question for a dispatched mission, am I in a persistent process or an interactive session that needs a heartbeat to survive across turns, by probing CronCreate availability. Sets up the cron heartbeat when one is needed and reports back when it is not. Loaded by rover at dispatch.
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

> Am I in a persistent process, or in an interactive session that stops between turns and needs a heartbeat to keep itself alive?

Keepalive answers that question by itself, from the runtime, and acts on the answer. The caller does not have to know anything about cron internals; it does not pass a flag, an env var, or a "skip cron" instruction. It invokes keepalive and uses what comes back.

## Why this skill exists

The caller used to have to know whether its session needed a heartbeat and tell the mission "skip the cron", leaking the autonomy layer's internals into whatever dispatches it. Keepalive moves that decision where it belongs: the autonomy layer probes its own runtime and decides. (The `autonomous` README carries the full interactive-vs-persistent rationale.)

## The probe

The signal is **tool availability**, not an environment flag and not a caller contract.

1. Determine whether `CronCreate` is reachable in this process. Inspect the available tool inventory: `CronCreate` is either a directly available tool or appears in the deferred-tool list loadable via `ToolSearch` (`select:CronCreate`). If it is present or loadable, treat CronCreate as **available**. If it is genuinely absent (not in the tool list and ToolSearch returns nothing for it), treat it as **unavailable**.
2. Branch on the result:

   **CronCreate available, so an interactive session.** The harness exposes the heartbeat machinery because this session needs it: it goes idle between turns. Set the heartbeat up. Invoke `autonomous:cron` via the Skill tool to `CronCreate` at `* * * * *` with the loop-file path the caller passed, exactly as the cron setup step describes. Return the job id to the caller so it writes `cron_job_id: <id>` into the loop file.

   **CronCreate unavailable, so a persistent process.** Nothing exposes a heartbeat because nothing here pauses; the process drives the phase machine to completion in one run and exits. Do not create a cron. Return the sentinel `none (persistent process)` so the caller writes `cron_job_id: none (persistent process)` into the loop file and proceeds straight into the first phase. The loop-file discipline is still kept (an interactive session can `wake` the file later if this run dies), but no heartbeat is armed.

## The return contract

Keepalive hands the caller exactly one value:

- A cron job id (a heartbeat is armed; the caller is interactive), or
- `none (persistent process)` (no heartbeat; the caller drives to completion).

The caller (see `rover` setup) writes that value into the loop file's `cron_job_id` field and continues. In interactive mode the rest of the loop's cron-dependent behaviour (STANDBY backoff, interjection re-arm, `wake` restore) is live. In persistent mode those steps are moot: the phase machine runs once, end to end, and the mission ends through `stop`.

## The load-bearing assumption

This is a deliberate design choice, not a natural law: the autonomy layer **treats `CronCreate` availability as the interactive-vs-persistent signal**. The probe is only correct when **need and availability coincide**: a host that runs a mission as a persistent process must not expose `CronCreate`, and a host whose sessions go idle must expose it. Capability and need are two facts braided into one on purpose, because the probe needs no coordination between the caller and the host: an explicit flag would require both sides to agree on a name and a value, and that agreement is itself state this design eliminates. The trade is that a host changing its tool configuration is also changing session-mode semantics; that coupling is the price of the zero-coordination contract.

A host that wants persistent/continuous mode withholds the cron tools, for example by adding `CronCreate`, `CronDelete`, and `CronList` to its disallowed-tools list.

**Degradation when the assumption is not yet met.** If a persistent host still exposes `CronCreate`, the probe reports interactive and arms a cron. On the normal path that cron is dead weight: a process that runs to completion never goes idle, so the heartbeat never fires and is torn down with the session. The mission still drives to completion through its phase machine; the cost is one wasted `CronCreate` call, not a broken run. On an abnormal exit (the process is killed or preempted mid-phase) the armed cron can outlive the session the way any orphan cron can (see `cron`'s note on crons surviving a `SessionStart:resume`); the `wake` restore path reaps such an orphan on the next manual relight. Either way the fix belongs on the host side (withhold the cron tools so the probe reports persistent), not here; this skill does not invent an env-var fallback to second-guess the tool probe.

## What it does not do

Keepalive does not write the loop file: the caller owns that and keepalive only returns the value for `cron_job_id`. It is a one-shot setup probe, not a phase, and it never touches the loop-file format.
