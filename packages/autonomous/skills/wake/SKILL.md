---
name: wake
description: Bring a stalled rover back online. Reads the loop file, relights the cron via autonomous:cron, summarises where the traverse left off, and fires the next iteration. Reached via rover:rover with a loop-file path.
user-invocable: false
effort: low
---

# Autonomy Wake

Revive a loop that was paused, auto-stopped, or lost its cron because the Claude session ended.

## When to use

- Session restarted and an old loop file in `.autonomous/` should continue
- Loop auto-stopped after ten idle polls but new activity is expected (a review just came in, a test just ran)
- Context was compacted and the loop file shows work mid-flight

## What it does

1. Read the loop file at the argument path. Wake is invoked only via `rover:rover` (the rover entry point), which always passes a path; if a run lands here without one, treat that as a caller bug and surface the missing argument to the operator rather than guessing which loop to revive.
2. Check liveness of the recorded `cron_job_id`. Use `CronList` if available via the Skill/Tool interface. A `cron_job_id` of `stopped` or `failed` is a durable terminal marker and means the loop needs a fresh cron regardless of file age. A `cron_job_id` of `none (persistent process)` means the original run never had a heartbeat; whether this wake gets one depends on the wake session, not the recorded value (step 4 re-decides).
3. If the loop file records a branch (under `## Context` or similar), verify the current branch matches or offer to switch. If no branch was recorded, continue on the current branch.
4. Re-decide keep-alive for this wake session through `autonomous:keepalive` (the wake session is a fresh process and may be interactive or persistent regardless of how the original run started). When the probe finds an interactive session it restores the heartbeat via `autonomous:cron` and writes the new `cron_job_id`; a freshly woken mission is active, so `autonomous:cron` schedules at the active cadence rather than resuming a stale backoff interval. When the probe finds a persistent process it writes `none (persistent process)` and the loop simply drives the next iteration without a heartbeat. Either way `autonomous:cron` no-ops when there is nothing to schedule, so a persistent-mode file never triggers a stray `CronCreate`.
5. Summarize the loop's current state to the conversation:
   - Phase
   - Last log entries (tail 10 lines)
   - Any uncommitted changes in the working tree
   - Any open PR associated with the branch
   - Anything in the `## Input` section waiting to be read
6. Acquire the lock (see `cron` concurrency section) before running one iteration of the current phase. This prevents the fresh cron from firing the same iteration in parallel. Release the lock when done.

## Detecting a compacted session

After a context compaction, the conversation summary usually contains phase words (SURVEY, DRIVE, INSPECT, STANDBY). If you see those and a loop file, prefer `wake` over manual takeover.

## What it does not do

- Does not modify the loop's Plan or Context. Those are the loop's memory.
- Does not push anything. Wake is local.
- Does not take over work the cron was going to do. Hand it back to the loop.

## After wake

The cron is live and will drive from here. If the operator is present, they can add notes to the `## Input` section or let the cron tick by itself.
