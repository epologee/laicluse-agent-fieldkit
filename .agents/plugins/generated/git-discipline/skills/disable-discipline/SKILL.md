---
name: disable-discipline
description: >
  Disable the git-discipline PreToolUse:Bash guards for the current Claude session by
  writing a sentinel file to ${LAICLUSE_HOME:-~/.laicluse}/git-discipline/. Other sessions are not affected.
---

# /git-discipline:disable-discipline

Disable the git-discipline PreToolUse:Bash guards for the current session. All
guards (commit-format, commit-subject, commit-body, commit-trailers,
git-dash-c, push-wip-gate) are torn down until the operator runs
`/git-discipline:enable-discipline`. Other sessions are not affected; the sentinel
is session-specific.

## Operator-actuated, by design

The sentinel file is operator territory. The `sentinel-protect` guard denies
any agent-driven Bash call that creates or removes a
`git-discipline-disabled-*` file, with no magic-comment or env-var escape.
That guard fires even when the operator typed this command: the agent's job
here is to prepare the exact command and hand it to the operator, who runs it
via the `! ` prefix in the prompt (or their own terminal). The physical
keystroke that flips the switch is always the operator's.

## When to use

Only when the operator explicitly types this command. Never suggest this
to get past a blocked commit. The guards exist for a reason; bypassing
them is the operator's choice, not Claude's.

Typical use: a session that deliberately works outside the normal commit
schema (e.g. a series of trivial fixup commits, a rebasing session, or an
experimental branch where the discipline does not apply temporarily).

## Recovery

Restore the guards with `/git-discipline:enable-discipline`. Check the status with
`/git-discipline:discipline-status`.

## Implementation

Perform the following steps:

1. Determine the current session_id. Read `$CLAUDE_SESSION_ID` from the
   environment if available. Alternatively: get the session_id from the
   transcript path available in the hook context, or derive it from the
   most recent JSONL file under `~/.claude/projects/`. If neither works,
   use the global sentinel (see below).

2. Do NOT run the sentinel write yourself; the `sentinel-protect` guard
   denies it. Print the ready-to-paste command for the operator instead.

   If session_id is available:

   ```
   ! mkdir -p ~/.laicluse/git-discipline && touch ~/.laicluse/git-discipline/git-discipline-disabled-<SESSION_ID>
   ```

   If session_id is NOT available (global sentinel; warn that this
   disables the guards for ALL sessions until removed):

   ```
   ! mkdir -p ~/.laicluse/git-discipline && touch ~/.laicluse/git-discipline/git-discipline-disabled-global
   ```

   Substitute `<SESSION_ID>` with the literal id so the operator can paste
   the line as-is. When `LAICLUSE_HOME` is set to a non-default location,
   substitute that root for `~/.laicluse`.

3. Tell the operator, in one line, to paste the command (the `! ` prefix
   runs it directly in the session) and that `/git-discipline:enable-discipline`
   restores the guards.

4. After the operator has run it, confirm via
   `[ -f <sentinel-path> ]` (read-only checks are not blocked) and report
   the resulting state.

Do not write further explanation or caveats. The operator typed this
command deliberately.
