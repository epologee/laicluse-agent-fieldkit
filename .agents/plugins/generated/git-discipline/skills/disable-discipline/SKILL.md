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

## When to use

Only when the operator explicitly types this command. Never use this
automatically to get past a blocked commit. The guards exist for a
reason; bypassing them is the operator's choice, not Claude's.

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
   fall back to the global sentinel (see below).

2. If session_id is available:

   ```bash
   mkdir -p "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline"
   touch "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-$SESSION_ID"
   echo "git-discipline guards disabled for session $SESSION_ID"
   echo "Re-enable with /git-discipline:enable-discipline"
   ```

3. If session_id is NOT available (fallback to the global sentinel):

   ```bash
   mkdir -p "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline"
   touch "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-global"
   echo "git-discipline guards disabled globally (session_id not available)"
   echo "WARNING: this sentinel disables guards for ALL sessions until removed."
   echo "Re-enable with /git-discipline:enable-discipline"
   ```

4. Confirm to the operator which sentinel was created and at which path.

Do not write further explanation or caveats afterwards. The operator
typed this command deliberately.
