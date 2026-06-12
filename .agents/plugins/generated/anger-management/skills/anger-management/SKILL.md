---
name: anger-management
description: Invoked as /anger-management. A quick read-back of the cuss-capture log and its recurring clusters; for the actual fix pass use /anger-management:repair. Runs only when the operator types it.
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the anger-management plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("anger-management was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. Codex currently has no equivalent
post-update broadcast path in this plugin; skip this block silently there.
</post-update-broadcast>

# Anger Management

The cuss commands (`/fuck`, `/fucking`, `/fucked`, `/shit`, `/crap`, `/wtf`,
`/bullshit`) capture one cheap friction line and let the operator get back to work.
This skill is the quick glance at that pile. The safeword commands (`/safeword`,
`/pineapple`, `/pineapplejuice`, `/pinapplejuice`, `/flugelhorn`, `/banana`) are
different: they interrupt current work and fix one visible friction point now, so
they do not fill this log. For the real cooled-down fix pass over the delayed pile,
use **`/anger-management:repair`**; this one just shows what is in the log.

## The log

One global pile across every session, repo, and agent:

```
${LAICLUSE_HOME:-~/.laicluse}/anger-management/friction.jsonl
```

Each line: `{ "ts", "word", "cwd", "git", "note" }`. Cheap on the capture side; the
value is in the aggregate. Captures that older versions wrote under
`~/.claude/var/leclause/` migrate to this path automatically on the next capture or
repair.

## What to do

A read-back, proportional to what is there. No fixing here, that is `repair`'s job.

1. Read the log. No file or an empty one means nothing is captured yet: say so, point
   at the cuss commands as what fills it, and mention that safewords do not go into
   this pile.
2. Surface the signal: cluster what recurs (same project via cwd/git, or the same theme
   across projects). Count, do not transcribe. A lone capture is a bad moment, not a
   pattern.
3. Show the top recurring frictions, worst first: what it is, how often, where it bites.
4. Point at the next step: `/anger-management:repair` is what actually judges whether
   there is something concrete to fix and routes it. Do not route anything yourself
   here.

## Notes

Match the operator's language. The log is the operator's: if they want it cleared, point
at the path, do not truncate it unprompted.

## Arguments

- No argument: full read-back of the recurring clusters.
- `<text>`: filter to a word, project, or theme and report only that slice.
