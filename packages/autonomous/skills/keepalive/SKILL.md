---
name: keepalive
description: Startup probe for the autonomy layer. Answers one question for a dispatched mission, am I in a persistent process or an interactive session that needs a heartbeat to survive across turns, by probing CronCreate availability. Sets up the cron heartbeat when one is needed and reports back when it is not. Loaded by rover at dispatch.
user-invocable: false
effort: low
---

# Autonomy Keepalive

The front door to the autonomy layer. A mission calls this skill once, at startup, and asks a single question:

> Am I in a persistent process, or in an interactive session that stops between turns and needs a heartbeat to keep itself alive?

Keepalive answers that question by itself, from the runtime, and acts on the answer. The caller does not have to know anything about cron internals; it does not pass a flag, an env var, or a "skip cron" instruction. It invokes keepalive and uses what comes back.

## Why this skill exists

The cron heartbeat (`cron`) and the restore path (`wake`) are workarounds for one fact: an interactive TUI session is not a persistent process. It runs a turn, then goes idle waiting for the operator. Without a heartbeat re-entering the conversation, an autonomous loop in that session simply stops between turns. The cron exists to fire on idle and drive the next phase.

A detached process (an Agent SDK run, a conveyor line, any continuous headless invocation) has the opposite shape: it keeps executing until the mission completes, then exits. A cron there is dead weight; there is no idle REPL for it to re-enter, and the process does not need anything to stay alive because it never pauses.

Historically the *caller* had to know this difference and tell the mission "skip the cron." That leaks the autonomy layer's internals into whatever dispatches it. Keepalive moves the decision where it belongs: the autonomy layer probes its own runtime and decides.

## The probe

The signal is **tool availability**, not an environment flag and not a caller contract.

1. Determine whether `CronCreate` is reachable in this process. Inspect the available tool inventory: `CronCreate` is either a directly available tool or appears in the deferred-tool list loadable via `ToolSearch` (`select:CronCreate`). If it is present or loadable, treat CronCreate as **available**. If it is genuinely absent (not in the tool list and ToolSearch returns nothing for it), treat it as **unavailable**.
2. Branch on the result:

   **CronCreate available, so an interactive session.** The harness exposes the heartbeat machinery because this session needs it: it goes idle between turns. Set the heartbeat up. Invoke `cron` via the Skill tool to `CronCreate` at `* * * * *` with the loop-file path the caller passed, exactly as the cron setup step describes. Return the job id to the caller so it writes `cron_job_id: <id>` into the loop file.

   **CronCreate unavailable, so a persistent process.** Nothing exposes a heartbeat because nothing here pauses; the process drives the phase machine to completion in one run and exits. Do not create a cron. Return the sentinel `none (persistent process)` so the caller writes `cron_job_id: none (persistent process)` into the loop file and proceeds straight into the first phase. The loop-file discipline is still kept (an interactive session can `wake` the file later if this run dies), but no heartbeat is armed.

## The return contract

Keepalive hands the caller exactly one value:

- A cron job id (a heartbeat is armed; the caller is interactive), or
- `none (persistent process)` (no heartbeat; the caller drives to completion).

The caller (see `rover` setup) writes that value into the loop file's `cron_job_id` field and continues. In interactive mode the rest of the loop's cron-dependent behaviour (STANDBY backoff, interjection re-arm, `wake` restore) is live. In persistent mode those steps are moot: the phase machine runs once, end to end, and the mission ends through `stop`.

## The load-bearing assumption

The probe is only correct when **need and availability coincide**: a host that runs a mission as a persistent process must not expose `CronCreate`, and a host whose sessions go idle must expose it. That is the contract the autonomy layer relies on instead of a caller flag.

A host that wants persistent/continuous mode withholds the cron tools (for example by adding `CronCreate`, `CronDelete`, and `CronList` to its disallowed-tools list). When it does, this probe reports persistent and arms nothing, which is exactly right.

**Degradation when the assumption is not yet met.** If a persistent host still exposes `CronCreate`, the probe reports interactive and arms a cron. That cron is harmless: a one-shot process that runs to completion and exits never goes idle, so the heartbeat never fires and dies with the process. The cost is one wasted `CronCreate` call, not a broken mission. The mission still drives to completion through its phase machine. The fix is on the host side (withhold the cron tools), not here; this skill does not invent an env-var fallback to second-guess the tool probe.

## What it does not do

- Does not write the loop file. The caller owns that; keepalive only returns the value for `cron_job_id`.
- Does not run any phase. It is a setup probe, invoked once, before the first SURVEY iteration.
- Does not read or change the loop-file format. `wake` reads the same template whether the heartbeat was armed or not.
