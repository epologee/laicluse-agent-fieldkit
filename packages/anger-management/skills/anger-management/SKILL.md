---
name: anger-management
user-invocable: true
description: Invoked as /anger-management. A read-only window onto the cuss-capture pile, a tally with no analysis; /anger-management:repair is the single place that analyses the pile and fixes recurring issues. Runs only when the operator types it.
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
`/bullshit`) capture one cheap note and let the operator get back to work.
This skill is the quick glance at that pile. The safeword commands (`/safeword`,
`/pineapple`, `/pineapplejuice`, `/pinapplejuice`, `/flugelhorn`, `/banana`) are
different: they interrupt current work and fix one visible friction point now, so
they do not fill this log. For the deeper delayed repair pass, use
**`/anger-management:repair`**; this one just shows what is in the log.

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

Read back the captures; do not judge them. Analysis and fixing both live in
`/anger-management:repair`; this is only the window onto the pile.

1. Read the log. No file or an empty one means nothing is captured yet: say so,
   point at the cuss commands as what fills it, and mention that safewords do not
   go into this pile.
2. Tally, do not judge: counts by word, by project (cwd/git), and recency. Show
   the raw shape of the pile, not a verdict on it. Deciding what is a pattern, and
   what to do about it, is repair's call, not this view's.
3. Point at the next step: `/anger-management:repair` analyses the pile and fixes
   the recurring issue; a safeword fixes one issue immediately. Do not analyse or
   route anything here.

## Notes

Match the operator's language. The log is the operator's: if they want it cleared, point
at the path, do not truncate it unprompted.

## Arguments

- No argument: full tally of the pile.
- `<text>`: filter to a word, project, or theme and tally only that slice.
