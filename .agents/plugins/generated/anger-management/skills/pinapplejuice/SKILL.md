---
name: pinapplejuice
description: >-
  Explicit fix-now safeword /pinapplejuice; route one caught problem into immediate durable repair.
---

# /pinapplejuice

The operator just used "pinapplejuice" as a fix-now safeword: stop the current work and
fix the problem they just caught, at its source, in this turn. Not praise, not a
timeout, not a reward loop, and not a delayed capture.

This is the now mode of `/anger-management:repair`: a single problem instead of
the cooled-down pile. Repair owns the fixing steps; this command only frames the
moment (now, not later) and what it works from (this one problem, not the log).

## What to do

1. **Interrupt the current task.** Treat what triggered the safeword as the active
   blocker; preserve the prior task state but stop executing that plan until it is
   handled.
2. **Name the concrete failure.** Identify what is going wrong now. One short
   clarifying question only if it is unclear; otherwise do not ask permission to
   investigate.
3. **Run `/anger-management:repair` in now mode on this one problem.** Walk
   repair's fixing steps: get evidence, choose the strongest source by its
   enforcement and scope ladders, make the smallest durable change (pruning in the
   same pass), rebuild generated adapters, and verify. Do not write to the friction
   log, advance the watermark, call `anger-resolve`, or start the delayed repair
   worker; now mode touches no log.
4. **Report and resume.** Say what changed and where, then resume the prior work
   only when it still makes sense.

## Hard rules

- A bare acknowledgement is never the outcome: end in a real source-level change,
  or the corrected behavior shown now with evidence it was a true one-off.
- Default to a structural fix; conclude "one-off" only on evidence.
- Do not log this, advance the watermark, or run the pile-mode recording.
- Do not apologize, praise, or perform emotional support.
