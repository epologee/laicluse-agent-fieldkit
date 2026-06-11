---
name: enable-discipline
user-invocable: true
description: >
  Re-enable the git-discipline PreToolUse:Bash guards for the current Claude session
  by removing the sentinel file written by /git-discipline:disable-discipline.
disable-model-invocation: true
argument-hint: ""
---

# /git-discipline:enable-discipline

Re-enable the git-discipline PreToolUse:Bash guards for the current session.
Removes the sentinel that `/git-discipline:disable-discipline` created. Has no
effect if the guards are already active.

## Operator-actuated, by design

The sentinel file is operator territory in BOTH directions. The
`sentinel-protect` guard denies any agent-driven Bash call that creates or
removes a `git-discipline-disabled-*` file, with no escape. Re-enabling
discipline that the operator deliberately switched off is just as much a
unilateral flip as disabling it. The agent prepares the exact command; the
operator runs it via the `! ` prefix in the prompt (or their own terminal).

## When to use

Only when the operator explicitly types this command. After the operator
runs the removal, the guards apply again in full to all subsequent git
commands in the current session.

## Check status

Use `/git-discipline:discipline-status` to see which sentinels are active and
what the current guard state is.

## Implementation

Perform the following steps:

1. Determine the current session_id via the same logic as
   `/git-discipline:disable-discipline`: first `$CLAUDE_SESSION_ID`, then the
   most recent JSONL file under `~/.claude/projects/`, then fall back to
   global.

2. Check (read-only, not blocked) which sentinels exist:

   ```bash
   ls "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/" 2>/dev/null | grep git-discipline-disabled
   ```

   If none exist, report that the guards are already active and stop.

3. Do NOT remove the sentinel yourself; the `sentinel-protect` guard denies
   it. Print the ready-to-paste command for the operator instead, naming
   the sentinel(s) found in step 2:

   ```
   ! rm ~/.laicluse/git-discipline/git-discipline-disabled-<SESSION_ID>
   ```

   and/or, when the global sentinel exists and the operator means that one:

   ```
   ! rm ~/.laicluse/git-discipline/git-discipline-disabled-global
   ```

   When `LAICLUSE_HOME` is set to a non-default location, substitute that
   root for `~/.laicluse`.

4. Tell the operator, in one line, to paste the command (the `! ` prefix
   runs it directly in the session). After they have run it, confirm via a
   read-only check and report that the guards are active again.

Do not write further explanation or caveats. The operator typed this
command deliberately.
