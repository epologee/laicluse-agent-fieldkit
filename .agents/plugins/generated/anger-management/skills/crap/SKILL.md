---
name: crap
description: Invoked as /crap. Captures a one-line friction note for a later repair pass; runs only when the operator explicitly types this command, never auto-activated.
---

# /crap

The operator just cursed "crap" at the session. This is a capture, not a request
to fix anything now: log it cheap and get back to work. The constructive pass happens
later via `/anger-management:repair`.

The commands below live in this plugin's `bin/` directory. In Claude Code the root is
`${CLAUDE_PLUGIN_ROOT}`; in another agent, resolve the plugin root from where this
skill file was loaded (two directories up) and substitute it.

1. Distil what actually set them off into a plain one-line pointer of at most a dozen
   words. Point at what happened (the thing the agent or workflow did), not at the
   feeling. Then append it through a quoted heredoc (the quoted delimiter stops the
   shell touching the text, even if it echoes something hostile):

   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/bin/anger-log" crap <<'CAPTURE_NOTE'
   <pointer>
   CAPTURE_NOTE
   ```

   No clear cause? Log the word alone, do not invent one:
   `node "${CLAUDE_PLUGIN_ROOT}/bin/anger-log" crap </dev/null`

2. Arm the cooled-down repair so the operator never has to remember it:

   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/bin/anger-arm"
   ```

   Single-flight: it starts a background investigation only if none is pending and
   there are open captures. Safe to run on every capture.

3. If your harness has a scheduler (Claude Code: CronList/CronCreate) and no
   anger-management check-in job exists yet, schedule a recurring poll so the
   diagnosis can surface when it lands: a modest interval (e.g. `*/5 * * * *`) whose
   prompt is: "Read
   `${LAICLUSE_AGENT_HOME:-~/.laicluse-agent}/anger-management/findings.md`. If it
   exists, tell the operator a repair diagnosis is ready and offer
   `/anger-management:repair`, then delete this job. If it is absent, do nothing this
   tick." The exact 22m22s timing lives in the background worker; this just polls
   cheaply until the diagnosis file appears, then removes itself. No scheduler in
   your harness? Skip this step; the diagnosis still surfaces at the next
   `/anger-management:repair`.

4. Acknowledge briefly in the operator's language and get back to work. This is a
   capture, not a fix: do not start self-improvement or change scope now, that is what
   the later repair pass is for.
