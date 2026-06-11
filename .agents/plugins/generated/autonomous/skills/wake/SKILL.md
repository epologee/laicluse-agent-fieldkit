---
name: wake
description: Bring a stalled rover back online. Reads the loop file, relights the cron via autonomous:cron, summarises where the traverse left off, and fires the next iteration. Reached via rover:rover with a loop-file path.
---

# Autonomy Wake

Revive a loop that was paused, auto-stopped, or lost its cron because the Claude session ended.

## When to use

- Session restarted and an old loop file in `.autonomous/` should continue
- Loop auto-stopped after ten idle polls but new activity is expected (a review just came in, a test just ran)
- Context was compacted and the loop file shows work mid-flight

## What it does

1. Read the loop file at the argument path. Wake is invoked only via `rover:rover` (the rover entry point), which always passes a path; if a run lands here without one, treat that as a caller bug and surface the missing argument to the operator rather than guessing which loop to revive.
2. Check liveness of the recorded `cron_job_id`. Use `CronList` if available via the Skill/Tool interface. A `cron_job_id` of `stopped` or `failed` is a durable terminal marker and means the loop needs a fresh cron regardless of file age.
3. If the loop file records a branch (under `## Context` or similar), verify the current branch matches or offer to switch. If no branch was recorded, continue on the current branch.
4. Invoke `autonomous:cron` via the Skill tool to restore: `CronCreate` at the interval matching `watch_checks`, write the new `cron_job_id` into the file.
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
