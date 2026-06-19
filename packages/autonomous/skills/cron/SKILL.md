---
name: cron
description: >-
  Maintain rover heartbeat cron state: create/delete cadence, back off quiet missions, and restore after restart.
user-invocable: false
effort: low
---

# Autonomy Cron

The cron machine behind an autonomous loop. Its job: keep the loop firing at an appropriate cadence, slow down when nothing is happening, and restart itself cleanly after a session restart.

## No cron, no-op

This skill acts only when there is a real cron to act on. It is a no-op, returning the existing marker without touching any Cron tool, whenever either holds:

- `CronCreate` is not available in this process (the persistent-process case: a detached run or conveyor line that drives to completion in one pass and needs no heartbeat).
- `cron_job_id` is a non-id marker rather than a live job id: `none (persistent process)`, `paused`, `stopped`, or `failed`.

This is the single place that owns the no-op, so callers invoke this skill unconditionally and never branch on the mode themselves; a persistent-mode mission hits every cron call site and each one quietly does nothing.

## Why a separate skill

Cron logic is mechanical and repetitive. Inlining it in the rover's code blurs the core flow. Separating it means:

- `rover:rover` reads like an intent document, not a scheduler
- `wake` reuses the exact same restore logic
- Backoff and auto-stop policy lives in one place

## Setup (new loop)

`keepalive` calls this skill when its startup probe finds an interactive session; the rover reaches cron only through `keepalive`, never directly. This is the rover's setup step 1, before any file writes. The loop file does not exist yet; the cron is going live first so every subsequent setup step (git operations, .gitignore write, loop-file template write) lands under an active safety net. During `wake` restore the file does exist. Your job:

1. Compute cron expression. Active phase = `* * * * *`. STANDBY with `watch_checks >= 1` uses backoff.
2. `CronCreate` with the project's standard prompt (see below)
3. Return the job id to the caller. If the loop file already exists (the `wake` path), edit its `cron_job_id` field in place. If it does not (the `keepalive` new-loop path), the caller holds the id and writes it into the file when creating it.

### Standard cron prompt

```
First run /model sonnet to downgrade this cron-spawned session away
from the operator's account default. Cron ticks are bookkeeping plus
phase action; Opus thinking-budget is wasted on them. STANDBY backoff
ticks should run /model haiku instead.

Then read the file `.autonomous/<FILENAME>.md` in this project. If
the file does not exist yet, the main session is still finishing
setup; do nothing this tick and let the next one retry. Otherwise
check the Phase, follow the Instructions section for the current
phase, and add a timestamped entry to the Log when you take action
(run `date +%H:%M` first, never guess). In STANDBY, an idle tick
with nothing new IS an action: bump `watch_checks`, invoke
`autonomous:cron` so the interval backs off per the table, and log the
tick with the new
`watch_checks` value and the current interval. A silent pass hides
whether the cron is still alive and keeps backoff stuck at one
minute.
```

Replace `<FILENAME>` with the actual file.

## Backoff table

| watch_checks | Interval | Cron expression |
|--------------|----------|-----------------|
| 0 | 1 min | `* * * * *` |
| 1 | 2 min | via `relative-cron 2` |
| 2 | 5 min | via `relative-cron 5` |
| 3 | 10 min | via `relative-cron 10` |
| 4 | 20 min | via `relative-cron 20` |
| 5 | 30 min | via `relative-cron 30` |
| 6+ | 60 min | via `relative-cron 60` |

`relative-cron` is shipped in `bin/` of this plugin. It handles a quirk of cron expressions: `*/N` is not "fire every N minutes from now" but "fire on every minute divisible by N". So `*/20` fires at `:00`, `:20`, `:40`, regardless of when you set it up. If you write `*/20` at `:19`, the next fire is in 1 minute, not 20. For idle backoff where the goal is "wait N minutes before the next check," short intervals (≤ 10) are fine with `*/N` but longer intervals need an explicit target minute: `<current + N> * * * *`. `relative-cron` returns the right form for each case.

**Locating the binary.** Resolve via `installed_plugins.json`, which is the authoritative source for the active install path (the same lookup `clipboard` and `rename-suggestion` use):

```bash
IP=$(jq -r '.plugins["autonomous@laicluse-agent-fieldkit"][0].installPath // empty' ~/.claude/plugins/installed_plugins.json 2>/dev/null)
if [ -z "$IP" ]; then
  echo "cron: autonomous@laicluse-agent-fieldkit not installed or installed_plugins.json missing. Run: claude plugins install autonomous@laicluse-agent-fieldkit" >&2
  CRON="*/${minutes} * * * *"
elif [ ! -x "$IP/bin/relative-cron" ]; then
  echo "cron: $IP/bin/relative-cron not found. Run: claude plugins update autonomous@laicluse-agent-fieldkit" >&2
  CRON="*/${minutes} * * * *"
else
  CRON=$("$IP/bin/relative-cron" "$minutes")
fi
```

The `jq` lookup returns the version Claude Code is currently loading, which matches the skill invoking this helper. No mtime-ordering, no pattern-sort heuristics. Both failure paths name the exact remedy so the operator does not have to diagnose.

## When to change the cron

**Nothing for the cron to do this tick:**

1. **Can the cron act?** The cron's only job is to drive the loop forward when nothing else does. If the next move requires a signal the cron cannot synthesize (an operator message, a bg task's completion, a scheduled trigger from another source) AND that signal has its own arrival channel that re-enters the loop on its own (the conversation re-entry on the operator's next message, a harness task-notification when a `run_in_background` command exits, `/rover:rover .autonomous/<file>`), the cron adds no safety the arrival channel does not already provide. Pause it: invoke `autonomous:cron` to `CronDelete` the current id, set `cron_job_id: paused` in the loop file, log `[HH:MM] cron paused: <wait source>; <reschedule channel> resumes`. The arrival event reschedules the cron via the standard interjection path (CronCreate at `* * * * *`, `watch_checks: 0`).
2. **Cron can act but the loop is STANDBY-idle.** No arrival channel exists for the next move; the cron polling for new state IS the only detection mechanism. Bump `watch_checks` per the backoff table, log the tick with the new value and interval. Backoff exists for this case.
3. **Cron can act and the loop is in an active phase.** Continue per the `rover:rover` phase instructions; do not pause or back off.

This consolidates the previous "operator-present no-op" and "DRIVE-blocked OTP wait" rules into one principle. An active operator who is going to send the next signal is the case where the cron should pause (case 1), not where it should ceremonially log a no-op. A truly unattended loop with no external arrival channel falls under case 2 and backs off normally.

**New input or phase becomes active:**
1. Reset `watch_checks: 0`
2. `CronDelete` old job, `CronCreate` with `* * * * *`, update `cron_job_id`
3. Log the reset with reason

**Auto-stop (hard cap):**
When `watch_checks` reaches 10, the loop is effectively idle. Total idle time to reach this uses the backoff schedule at each step:

| watch_checks | Interval waited at this step |
|--------------|------------------------------|
| 0 to 1 | 1 min |
| 1 to 2 | 2 min |
| 2 to 3 | 5 min |
| 3 to 4 | 10 min |
| 4 to 5 | 20 min |
| 5 to 6 | 30 min |
| 6 to 7 | 60 min |
| 7 to 8 | 60 min |
| 8 to 9 | 60 min |
| 9 to 10 | 60 min |

Sum: 1 + 2 + 5 + 10 + 20 + 30 + 60 × 4 = 308 minutes, about 5 hours.

1. `CronDelete` the current `cron_job_id`
2. Set `cron_job_id: stopped` in the loop file (durable terminal marker)
3. Log "stopped after 10 idle polls"
4. If `notify_on_done` is set and `has_skill` returns true for it, invoke it with a brief end-of-loop summary; otherwise log the summary only

## Restore after session restart

Cron jobs are documented as session-scoped, but in practice some survive a SessionStart:resume. A loop that the operator thought was dead can keep firing on its old cadence while the restored cron fires on its new cadence; the operator sees double cron prompts and the backoff table never takes hold for the orphan. Before creating a new cron, reap any orphan that points at the same loop file.

1. Read the loop file, note `watch_checks`.
2. **Reap orphan crons.** Invoke `CronList` via Skill or ToolSearch. For every entry whose prompt contains the loop file's filename (the `<FILENAME>.md` token after `.autonomous/`), call `CronDelete` on its job id. Log one line per kill: `[HH:MM] reaped orphan cron <id> (matched loop file <FILENAME>)`. Skip and proceed silently when CronList is empty.
3. Compute cron expression from the backoff table.
4. `CronCreate` with that interval and the standard prompt.
5. Update `cron_job_id` in the loop file.
6. Now continue with whatever the phase requires.

If the loop's phase is STANDBY and `watch_checks >= 10`, the loop was already auto-stopped. Do not restore. Still run step 2 to reap any orphan that survived restart on its own; a terminated loop should not have any cron firing for it. Log a note that the loop was found in terminal state.

## Stopping on demand

Called by `rover:stop` or when an DRIVE, INSPECT, or STOW phase finishes cleanly with no STANDBY channels to watch:

1. `CronDelete` with the current `cron_job_id`
2. Set `cron_job_id: stopped` in the loop file
3. Log the stop

The loop file itself is never deleted. It is history.

## Edge cases

**Cron fires during active session.** The REPL is busy with user interaction. The cron waits for idle, which is fine. No action needed from this skill.

**CronCreate fails.** Session might be in a weird state. Retry once. If still failing:

1. Log a loud error line to the loop file: `[HH:MM] CronCreate failed after retry. Loop has no cron. User must drive manually or run /rover:rover .autonomous/<file>.`
2. If `notify_on_done` is configured and its skill is installed, invoke it with the failure.
3. Leave `cron_job_id: failed` in the loop file as a durable marker.

Do not silently proceed.

**Concurrency: threshold-cross race.** Two cron iterations can fire closely if a late tick and a threshold-cross tick overlap. Both read the same `watch_checks`, both decide to reset, both issue CronDelete/CronCreate. Guard with a file-based lock when doing the read-modify-write on `watch_checks`:

```bash
LOOP="$1"
LOCK="${LOOP}.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
  echo "cron: another iteration holds the lock, skipping" >&2
  exit 0
fi
# read watch_checks, compute new interval, edit file, CronDelete, CronCreate
```

On systems without `flock` (macOS by default), fall back to `mkdir` lock or atomic `ln -s` as a sentinel. The lock file name tracks the loop file, so multiple loops do not block each other.

**Multiple loops active.** Each loop file has its own `cron_job_id`. They do not conflict. Do not try to share a cron across loops.

**Session ended → cron is dead regardless of age (in theory).** Do not rely on file `stat` to infer cron liveness. Use `CronList` via the Skill or ToolSearch path and check for the id. A 30-minute-old loop file from a closed session has a dead cron just as surely as a 3-day-old one.

**Cron survives a SessionStart:resume (in practice).** The session-only contract documented for `CronCreate` does not always hold across a SessionStart:resume. Empirically, a cron created in the previous session can keep firing in the resumed session under its old job id, in addition to whatever the restore flow creates. The result: two crons fire for the same loop file, the orphan ignores the loop file's backoff state, and the operator sees double 10-min ticks while the loop file's `cron_job_id` advances on its own backoff schedule. Always run the orphan-reap step at restore (see "Restore after session restart"). Always invoke `CronList` instead of trusting the `cron_job_id` field alone.

## Reference: relative-cron

Source: `packages/autonomous/bin/relative-cron` (ships as `$installPath/bin/relative-cron` in the install cache). Usage:

```bash
relative-cron 20     # -> "47 * * * *" (when now is :27)
relative-cron 5      # -> "*/5 * * * *"
relative-cron 60     # -> exact fire minute one hour from now
```

Rules: short intervals (`<= 10`) use `*/N`, longer intervals compute exact minute to avoid the `*/N` alignment trap.
