---
name: enable-git
user-invocable: true
description: >-
  Explicit /git-discipline:enable-git: remove the repo read-only git lock for Claude.
disable-model-invocation: true
argument-hint: ""
---

# /git-discipline:enable-git

Remove the per-repo lock that `/git-discipline:disable-git` set. After this command
Claude is free to run mutating git commands again. Has no effect when no
sentinel is present.

## Implementation

Perform the following steps:

1. Resolve the git common dir:

   ```bash
   common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
   ```

   Bail with a clear error when not inside a git repo.

2. Check (read-only, not blocked) whether the sentinel exists:

   ```bash
   [ -f "$common_dir/git-discipline-deny" ]
   ```

   If it does not, report that no git lock was active and stop.

3. Do NOT remove the sentinel yourself; the `sentinel-protect` guard
   denies agent-driven removal, with no escape. Unlocking a repo the
   operator locked is the operator's call. Print the ready-to-paste
   command instead (the `! ` prefix runs it directly in the session):

   ```
   ! rm <common_dir>/git-discipline-deny
   ```

   Substitute `<common_dir>` with the literal path so the operator can
   paste the line as-is.

4. After the operator has run it, confirm via a read-only check and
   report that the lock is lifted.

Do not write further explanation or caveats afterwards. The operator
typed this command deliberately.
