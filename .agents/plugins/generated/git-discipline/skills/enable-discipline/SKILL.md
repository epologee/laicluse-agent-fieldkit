---
name: enable-discipline
description: >
  Re-enable the git-discipline PreToolUse:Bash guards for the current Claude session
  by removing the sentinel file written by /git-discipline:disable-discipline.
---

# /git-discipline:enable-discipline

Re-enable the git-discipline PreToolUse:Bash guards for the current session.
Removes the sentinel that `/git-discipline:disable-discipline` created. Has no
effect if the guards are already active.

## When to use

Only when the operator explicitly types this command. After running this
command, the guards apply again in full to all subsequent git commands in
the current session.

## Check status

Use `/git-discipline:discipline-status` to see which sentinels are active and
what the current guard state is.

## Implementation

Perform the following steps:

1. Determine the current session_id via the same logic as `/git-discipline:disable-discipline`:
   first `$CLAUDE_SESSION_ID`, then the most recent JSONL file under
   `~/.claude/projects/`, then fall back to global.

2. Remove the session-specific sentinel if it exists:

   ```bash
   SENTINEL="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-$SESSION_ID"
   if [[ -f "$SENTINEL" ]]; then
     rm "$SENTINEL"
     echo "git-discipline guards re-enabled for session $SESSION_ID"
   else
     echo "git-discipline guards were already active for session $SESSION_ID"
   fi
   ```

3. Also check the global sentinel and remove it if the operator means
   that (i.e. when there was no session-specific sentinel but there was
   a global one):

   ```bash
   GLOBAL="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-global"
   if [[ -f "$GLOBAL" ]]; then
     rm "$GLOBAL"
     echo "global git-discipline sentinel removed"
   fi
   ```

4. Confirm to the operator which sentinel(s) were removed and at which path.

Do not write further explanation or caveats afterwards. The operator
typed this command deliberately.
