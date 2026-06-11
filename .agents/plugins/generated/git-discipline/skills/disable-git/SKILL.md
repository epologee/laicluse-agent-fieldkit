---
name: disable-git
description: >
  Lock git for the current repo so Claude only allows read-only inspection
  (status, log, diff, show, blame, rev-parse, etc.) and blocks every
  command that touches the working directory, index, refs, or remote.
  Writes a sentinel file at .git/git-discipline-deny.
---

# /git-discipline:disable-git

Set a per-repo lock that tells Claude to keep its hands off git for a
while. Read-only inspection commands keep working (status, log, diff,
show, blame, rev-parse, branch list, tag list, etc.). Anything that
mutates working directory, index, refs, or remote (commit, checkout,
switch, restore, reset, merge, rebase, cherry-pick, revert, push,
pull, fetch, add, rm, mv, stash, clean, branch -d, tag v0.1, ...) is
blocked.

The lock is a sentinel file at `.git/git-discipline-deny` inside the repo (or
the main worktree's `.git/` when invoked from a linked worktree). It
is per-repo, never committed, and not visible in `git status`.

## Implementation

Perform the following steps:

1. Resolve the git common dir:

   ```bash
   common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
   ```

   Bail with a clear error when not inside a git repo.

2. Do NOT write the sentinel yourself; the `sentinel-protect` guard denies
   agent-driven writes to it, with no escape. Print the ready-to-paste
   command for the operator instead (the `! ` prefix runs it directly in
   the session). The optional argument becomes the first line of the file
   (used as the reason in the deny message):

   ```
   ! printf '%s\n' "<reason>" > <common_dir>/git-discipline-deny
   ```

   or without a reason:

   ```
   ! touch <common_dir>/git-discipline-deny
   ```

   Substitute `<common_dir>` and `<reason>` with the literal values so the
   operator can paste the line as-is.

3. After the operator has run it, confirm via a read-only check
   (`[ -f ... ]`, not blocked): print the absolute sentinel path, the
   reason if any, and a one-line reminder that `/git-discipline:enable-git`
   lifts the lock.

## Scope of the lock

- Allowed (read-only inspection): `status`, `log`, `diff`, `show`,
  `blame`, `rev-parse`, `rev-list`, `name-rev`, `describe`, `reflog`,
  `shortlog`, `cat-file`, `ls-files`, `ls-tree`, `ls-remote`,
  `for-each-ref`, `grep`, `whatchanged`, `merge-base`,
  `symbolic-ref`, `var`, `version`, `help`, `remote -v`,
  `config --get`, `branch` / `tag` in list form,
  `bisect view` / `bisect log`, `worktree list`,
  `submodule status` / `summary`, `stash list` / `show`,
  `notes list` / `show`.
- Blocked: everything else.

## CLI-time coverage

When `/git-discipline:install-hooks` is active in the repo, the `commit-msg`
and `pre-push` git-native hooks honour the same sentinel, so direct
shell `git commit` and `git push` (outside Claude) are blocked too.
Other CLI write commands (`git reset`, `git checkout`, ...) are not
covered CLI-time because git-discipline does not install hooks for them; they
remain free for the operator to use deliberately. Claude is fully
locked at PreToolUse time regardless.

## Recovery

`/git-discipline:enable-git` removes the sentinel.

Do not write further explanation or caveats afterwards. The operator
typed this command deliberately.
