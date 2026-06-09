---
name: repair
description: Invoked as /anger-management:repair. Reads the accumulated curse-capture log, judges whether there is one concrete recurring thing worth fixing, and if so routes it to self-improvement. Runs only when the operator types it.
---

# Repair

The constructive other half of the curse commands. The operator captured some friction
("curse now, repair later"); this is the later: a cooled-down look at the whole pile.
The steps below are the job; how you phrase any of it is for the local context to decide.

## The log (global, it accumulates)

One pile for every session and every repo:
`${LAICLUSE_AGENT_HOME:-~/.laicluse-agent}/anger-management/friction.jsonl` (each line: ts, word, cwd,
git, note). Repair history: `repairs.jsonl` (past fixes, each with a `covered_through`
watermark). A background diagnosis the cooled-down agent may have written:
`findings.md`.

**Open captures** = entries with `ts` newer than the newest `covered_through` in
`repairs.jsonl` (if there is no history, all are open). Always work the WHOLE open
pile, not one entry. This is why deferring helps: every extra capture across every
session sharpens the picture.

## What to do

1. **Use the background diagnosis only if it is fresh.** If `findings.md` exists, read
   its first line (`as-of: <ts>`). If no capture in the pile is newer than that as-of,
   it is current: use it. If captures are newer, or there is no as-of line, treat it as
   stale and investigate yourself now: read the open captures, `repairs.jsonl`, and the
   agent's recent session transcripts (Claude Code: `~/.claude/projects/`; Codex:
   `~/.codex/sessions/`) for what actually happened around those timestamps. You have
   the time; look properly.

2. **Cluster the open pile.** Same project (cwd/git) or same theme across projects.
   The recurring thing is the signal; a lone one-off is noise.

3. **Open with a go/no-go verdict. This is the whole point: no busywork.** State one
   of three, before anything else:
   - **nothing**: no actionable pattern. Change NOTHING, say why in a line, done.
     This is a good, honest outcome, not a failure. Do not touch CLAUDE.md or any
     config on a vague hunch.
   - **not-enough-signal**: a hint, but too thin to act on. Leave the captures open to
     accumulate; say what you would want to see more of. (Do not advance the
     watermark; do not call anger-resolve.)
   - **fix**: one concrete recurring thing, named, with a specific change.

4. **If fix: scrutinise prior self-improvements first.** The operator mostly curses
   when something RECURS despite earlier fixes. So before proposing a new rule, check
   `repairs.jsonl`: did a past repair already target this? If captures kept coming, the
   past fix probably overcorrected or missed. Prefer **reverting or loosening** that
   rule over piling another on. The right change is often subtraction.

5. **Route it, do not apply it yourself.** Hand the concrete change to
   `/self-improvement` (which owns CLAUDE.md / skill edits). When the operator agrees
   to route it, record it so its captures close (plugin root: `${CLAUDE_PLUGIN_ROOT}`
   in Claude Code; in another agent, resolve it from where this skill file was loaded):

   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/bin/anger-resolve" --through "<as-of you worked from>" "<the change you routed>"
   ```

   Pass `--through` = the as-of of the diagnosis you acted on (the `findings.md` as-of,
   or the newest capture you actually reviewed), so captures that arrived DURING this
   repair are not silently closed. Only on a real routed fix; never for nothing or
   not-enough-signal. The watermark closes by time, so if several distinct clusters are
   open and you fix one, the others are marked covered too and will reopen on their next
   recurrence.

6. **Keep it short, in the operator's language.** The verdict (and, when fixing, the
   routed change) is the whole output.

## Arguments

- No argument: work the whole open pile.
- `<text>`: treat as a filter (a word, a project, a theme) and work only that slice.
