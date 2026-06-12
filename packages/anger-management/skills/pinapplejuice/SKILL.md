---
name: pinapplejuice
user-invocable: true
description: >-
  Invoked as /pinapplejuice. A fix-now safeword: the operator still has enough mental
  capacity to pause the current work and steer one visible friction point before
  it becomes a delayed anger-management capture. Runs only when explicitly typed.
disable-model-invocation: true
---

# /pinapplejuice

The operator just used "pinapplejuice" as a fix-now safeword. This is not praise, not a
timeout, not a reward loop, and not a delayed anger-management capture. It means:
stop the current work, park the previous task for a moment, and fix the visible
friction now.

The issue may be a one-off. Do not force pattern analysis and do not write to the
anger-management friction log. If the operator is already irritated, or is playing
up irritation for effect, they can use the escalated curse commands instead. This
one is the lighter signal: "I see something going wrong and can still help steer."

## What to do

1. **Interrupt the current task.** Treat the safeword issue as the active blocker.
   Preserve the previous task state, but do not keep executing that plan until this
   friction is handled.
2. **Name the concrete failure.** Identify what is going wrong now. If it is unclear,
   ask one short clarifying question. If it is clear, do not ask for permission to
   investigate.
3. **Get evidence before editing.** Reproduce the failure, inspect the relevant
   source, or cite the exact contradictory instruction/output. For code or config,
   prefer a focused RED check before GREEN when feasible.
4. **Fix at the owner source.** Use the strongest fitting target: hook or
   deterministic check, skill/plugin source, project code, then instruction file as
   last resort. Do not patch runtime caches or generated targets as source; rebuild
   generated adapters when the repo provides a command.
5. **Verify.** Run the focused check that proves the fix. If the safeword concern
   only needed a course correction in the current response, show the corrected
   behavior and continue from there.
6. **Keep the response short.** Say what you changed or how you corrected course,
   include the verification, and then resume the prior work only when it still makes
   sense.

## Hard Rules

- Do not log this through `anger-log`.
- Do not arm the delayed repair worker.
- Do not start `/anger-management:repair`.
- Do not apologize, praise, or narrate emotional support.
- Do not convert a one-off course correction into a durable rule unless the evidence
  shows a durable source problem.
