---
name: fucking
description: Invoked as /fucking. Captures a one-line friction note for a later repair pass; runs only when the operator explicitly types this command, never auto-activated.
---

# /fucking

The operator just cussed "fucking" at the session. This is one of the cuss commands:
a capture, not a request to fix anything now. Log it cheap and get back to work. The
constructive pass happens later via `/anger-management:repair`.

The commands below live in this plugin's `bin/` directory. Resolve the loaded
plugin root first; Claude Code exposes `${CLAUDE_PLUGIN_ROOT}`, and Codex exposes
the install path through `codex plugin list`.

1. Distil what actually set them off into a plain one-line pointer of at most a dozen
   words. Point at what happened (the thing the agent or workflow did), not at the
   feeling. Then append it through a quoted heredoc (the quoted delimiter stops the
   shell touching the text, even if it echoes something hostile):

   ```bash
   resolve_anger_plugin_root() {
     if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
       printf '%s\n' "$CLAUDE_PLUGIN_ROOT"
       return 0
     fi
     if command -v codex >/dev/null 2>&1; then
       codex plugin list | awk '$1 == "anger-management@laicluse-agent-tools" { print $NF; found=1; exit } END { exit found ? 0 : 1 }'
       return $?
     fi
     return 1
   }

   PLUGIN_ROOT="$(resolve_anger_plugin_root)" || { echo "anger-management plugin root not found" >&2; exit 1; }
   node "$PLUGIN_ROOT/bin/anger-log" fucking <<'CAPTURE_NOTE'
   <pointer>
   CAPTURE_NOTE
   ```

   No clear cause? Log the word alone, do not invent one:
   use the same command with `</dev/null` instead of the heredoc.

2. Schedule the cooled-down repair so the operator never has to remember it:

   ```bash
   resolve_anger_plugin_root() {
     if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
       printf '%s\n' "$CLAUDE_PLUGIN_ROOT"
       return 0
     fi
     if command -v codex >/dev/null 2>&1; then
       codex plugin list | awk '$1 == "anger-management@laicluse-agent-tools" { print $NF; found=1; exit } END { exit found ? 0 : 1 }'
       return $?
     fi
     return 1
   }

   PLUGIN_ROOT="$(resolve_anger_plugin_root)" || { echo "anger-management plugin root not found" >&2; exit 1; }
   node "$PLUGIN_ROOT/bin/anger-schedule"
   ```

   Single-flight: it starts a background investigation only if none is pending and
   there are open captures. Safe to run on every capture.

3. If your harness has a scheduler (Claude Code: CronList/CronCreate) and no
   anger-management check-in job exists yet, schedule a recurring poll so the
   diagnosis can surface when it arrives: a modest interval (e.g. `*/5 * * * *`) whose
   prompt is: "Read
   `${LAICLUSE_HOME:-~/.laicluse}/anger-management/findings.md`. If it
   exists, tell the operator a repair diagnosis is ready and offer
   `/anger-management:repair`, then delete this job. If it is absent, do nothing this
   tick." The exact 22m22s timing lives in the background worker; this just polls
   cheaply until the diagnosis file appears, then removes itself. No scheduler in
   your harness? Skip this step; the diagnosis still surfaces at the next
   `/anger-management:repair`.

4. Acknowledge briefly in the operator's language and get back to work. This is a
   capture, not a fix: do not start self-improvement or change scope now, that is what
   the later repair pass is for.
