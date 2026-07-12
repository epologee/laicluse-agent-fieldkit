---
name: merge-to-default
description: >-
  Merge the current branch to the repo's default branch with git-discipline checks and a no-ff merge commit.
allowed-tools: Bash(git symbolic-ref:*), Bash(git config:*), Bash(git rev-parse:*), Bash(git status:*), Bash(git checkout:*), Bash(git merge:*), Bash(git commit:*), Bash(git rebase:*), Bash(git log:*), Bash(git diff:*), Bash(git ls-remote:*), Bash(git remote:*), Bash(git branch:*), Bash(git worktree:*), Skill(git-discipline:commit-all-the-things), Skill(git-discipline:rebase-latest-default)
---

# /git-discipline:merge-to-default

Land the current branch on the project's default branch with a real `--no-ff` merge commit, the same shape GitHub's merge button produces. Pending working-tree changes ride along via `git-discipline:commit-all-the-things`. Before the merge, the source branch is rebased onto the latest default whenever the default is ahead, so the merge is a clean commit on top of an up-to-date default and a branch falling behind no longer opens a conflict-marker window in the default-branch checkout. The rebase is a precondition, not a recovery: a reactive rebase fallback remains only for the narrow race where the default advances between the rebase and the merge.

## When

- The current feature branch is done and needs to be merged into the Git default branch
- The user types `/git-discipline:merge-to-default` or says "merge naar default", "merge to default", "merge to main", or "merge this into main"
- Local workflow without a PR step: the project does trunk-based development or accepts direct merges on the default branch

Not for remote merges: this skill never pushes the default branch, and landing the merge on the remote is a separate, explicit user action. (The one push this flow can trigger is the rebase precondition's own: `git-discipline:rebase-latest-default` force-pushes the rebased *feature* branch when it is already published.)

## Step 0: Detect default branch and current branch

### 0a: Default branch name

Determine the name of the default branch (`$DEFAULT`):

```bash
DEFAULT=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
if [ -z "$DEFAULT" ]; then
  CONFIGURED_DEFAULT=$(git config --get init.defaultBranch 2>/dev/null || true)
  if [ -n "$CONFIGURED_DEFAULT" ] && git rev-parse --verify "refs/heads/$CONFIGURED_DEFAULT" >/dev/null 2>&1; then
    DEFAULT=$CONFIGURED_DEFAULT
  fi
fi
```

This preserves repository metadata as the first authority while still supporting a local-only repository: `init.defaultBranch` is Git configuration, not a hard-coded `main` or `master` guess, and it is accepted only when the corresponding local branch exists.

If `$DEFAULT` is empty, stop with the message: `Cannot determine the default branch from origin/HEAD or init.defaultBranch. Configure Git's default branch or merge an explicit branch manually.`

### 0b: Current branch

```bash
CURRENT=$(git symbolic-ref --short HEAD)
```

If `git symbolic-ref --short HEAD` fails (detached HEAD), stop with the message: `HEAD is detached. Switch to a branch before invoking /git-discipline:merge-to-default.`

## Step 1: No-op safeguard when already on default

If `$CURRENT` equals `$DEFAULT`, do nothing. Show a clear TUI warning and stop:

```
⚠  /git-discipline:merge-to-default is a no-op on the default branch itself.
    Current branch: <DEFAULT>
    There is nothing to merge into <DEFAULT> from <DEFAULT>.

    Switch to the feature branch you want to merge first, then re-run
    /git-discipline:merge-to-default. Run `git branch` to list local branches,
    or `git reflog` to find the branch you were on before HEAD landed
    here.
```

No commit, no merge, no rebase. Exit cleanly.

## Step 2: Commit pending work via commit-all-the-things

Run `git status --porcelain`. Not empty means there is uncommitted work on the feature branch that should ride along on the merge.

Invoke `git-discipline:commit-all-the-things` via the Skill tool. That sub-skill groups all uncommitted changes into logical commits according to the project- and user-CLAUDE.md conventions and commits them on the current branch (`$CURRENT`). Wait until that skill is done before continuing.

After the invocation: `git status --porcelain` is empty, otherwise stop with the message `commit-all-the-things left uncommitted changes; investigate before merging.`

**Important to know up front:** the skill commits EVERYTHING that is there, including half-finished work the user did not want to lock in yet. Anyone who has staged or working-tree changes that do not belong with the merge should set those aside first (`git stash push -m "wip"`, or a separate snipe commit on another branch) before invoking `/git-discipline:merge-to-default`. The skill has no opt-out for step 2; that is deliberate, because a half-merge with unspoken pending changes muddies the history.

## Step 3: Rebase precondition

A `--no-ff` merge of a branch that is behind the default can conflict, and that conflict materialises in the working tree of the default-branch checkout (Step 4 checks out `$DEFAULT` before merging) before any recovery runs. To guarantee the merge is always a clean commit on an up-to-date default, the source branch is rebased onto the latest default **first**, unconditionally whenever the default is ahead. The rebase is a precondition here, not a recovery: with the branch already up to date, Step 4 cannot produce a conflict from the branch being behind, so the stale-branch conflict-marker window this skill used to risk is closed.

Detect whether `$CURRENT` is behind the latest default. The branch is behind when it lacks any commit that exists on either the local `$DEFAULT` or `origin/$DEFAULT` ref. This is a coarse gate, not a call into `git-discipline:rebase-latest-default`: invoking the sub-skill unconditionally would run its `git ls-remote` staleness check on an already-current branch and could block the merge for a fetch it does not need. The gate never picks the rebase target (the sub-skill still owns that), so a conservative match only triggers a sub-skill call that exits cleanly:

```bash
BEHIND=
for ref in refs/heads/$DEFAULT refs/remotes/origin/$DEFAULT; do
  git rev-parse --verify "$ref" >/dev/null 2>&1 || continue
  [ -n "$(git rev-list "$CURRENT..$ref")" ] && BEHIND=1
done
```

- **`$BEHIND` is empty:** the branch already contains the tip of the latest default. Skip the rebase and report `Branch is up to date with <DEFAULT>; no rebase needed.`, then continue to Step 4. No rebase noise for an already-current branch.
- **`$BEHIND` is set:** the default is ahead. Report `Branch is behind <DEFAULT>; rebasing onto the latest default before merging.` so the rebase output that follows is expected, then invoke `git-discipline:rebase-latest-default` via the Skill tool. That sub-skill rebases `$CURRENT` on the freshest `$DEFAULT` (local or `origin/$DEFAULT`, whichever is ahead) and resolves trivial conflicts (whitespace, identical edits, lockfile regenerations) automatically. The skill is the single rebase tool; this step does not run its own `git rebase`. The worktree is still on `$CURRENT` here and Step 2 already committed pending work, so the tree is clean, which is what rebase-latest-default's pre-rebase guard requires.

After rebase-latest-default returns:

- **Rebase completed:** continue to Step 4. `$CURRENT` now sits on top of the latest default, so the `--no-ff` merge is a clean commit.
- **rebase-latest-default reports already up to date:** the conservative detection flagged the branch as behind a ref it already contains (e.g. `$CURRENT` is based on `origin/$DEFAULT` while a lagging local `$DEFAULT` looked ahead). The sub-skill did nothing; continue to Step 4 and report the rebase as skipped, not performed.
- **rebase-latest-default stops needing a fetch:** when the target is `origin/$DEFAULT` and the tracking ref is stale, rebase-latest-default stops without rebasing and asks for a fetch. `merge-to-default` stops too, before any merge, with `$DEFAULT` untouched. Run `git fetch origin`, then invoke `/git-discipline:merge-to-default` again.
- **Rebase stopped on genuine ambiguity:** rebase-latest-default only auto-resolves trivial conflicts; for genuine ambiguity (both sides made intentional, incompatible changes to the same logic) it stops mid-rebase and points at the conflicting files. `merge-to-default` then also stops, **before any merge**: the worktree sits mid-rebase on `$CURRENT`, `$DEFAULT` is untouched, and no merge commit and no conflict markers ever reach the default-branch checkout. The user has two cleanup options:
  - `git rebase --abort`: returns `$CURRENT` to its pre-rebase tip; nothing merged, `$CURRENT` still unmerged. The user then either tackles the conflict differently or, once it is settled, re-invokes `/git-discipline:merge-to-default`.
  - Manually resolve the conflict, `git rebase --continue` per step, and then invoke `/git-discipline:merge-to-default` again to run the merge.

  `merge-to-default` itself does not make either of these choices for the user; mid-rebase with genuine ambiguity is exactly the place where manual resolution is the right way.

## Step 4: First-pass merge

The branch arrives here up to date with the default, so this merge is expected to be a clean commit. First save the tip of the source branch, then checkout and merge:

```bash
PRE_MERGE_TIP=$(git rev-parse "$CURRENT")
git checkout "$DEFAULT"
git merge --no-ff --no-commit "$CURRENT"
git commit -m "$(cat <<EOF
Merge branch '$CURRENT'

Local merge of the rebased $CURRENT branch into $DEFAULT.

Slice: merge
PII-Doublecheck: yes
EOF
)"
```

`PRE_MERGE_TIP` is used later in Step 6 to confirm that the merge actually integrated the source tip, independent of what some other process (e.g. another shell) does to the `$CURRENT` ref in the meantime.

`--no-ff` forces a merge commit (two parents), even when the default branch sits exactly behind the feature branch. This gives the history the same shape that GitHub's "Create a merge commit" button produces; the iteration on the feature branch stays visible in `git log --graph`. A fast-forward or squash merge would flatten that same iteration, which is why `--no-ff` is non-negotiable here. Anyone who prefers a fast-forward or a rebase merge can use `git merge --ff-only` or `git rebase` directly from the command line; this skill is specifically for the github-merge-button shape.

`--no-commit` preserves the same merge tree while letting the skill write a
commit body that satisfies git-discipline and public-repo PII hooks. The
subject stays the local Git merge shape (`Merge branch '<CURRENT>'`), not the
PR-merge subject (`Merge pull request #N from ...`), because this skill does
not create a PR and does not know a PR number.

- **Succeeds cleanly:** continue to Step 6.
- **Conflicts (rare, residual):** continue to Step 5. With Step 3 in place a stale-branch conflict cannot reach here; a conflict at this point means the default advanced again in the narrow window between the precondition rebase and this merge (a same-line clash between the branch and that newer default commit is one shape this race takes).

## Step 5: Conflict fallback via rebase (rare)

Step 3 removes the stale-branch conflict that used to land here, so this fallback is reached only in the race noted in Step 4: the default advanced again between the precondition rebase and the merge. The handling is the same `rebase first, then clean merge` the precondition uses, never manual conflict resolution inside a merge commit, so the result is still a clean merge commit on top of an up-to-date default.

```bash
git merge --abort
git checkout "$CURRENT"
```

Invoke `git-discipline:rebase-latest-default` via the Skill tool (the same single rebase tool Step 3 uses). After a successful rebase, capture the new source tip before the retry checkout, then repeat the checkout and merge from Step 4:

```bash
PRE_MERGE_TIP=$(git rev-parse "$CURRENT")
git checkout "$DEFAULT"
git merge --no-ff --no-commit "$CURRENT"
git commit -m "$(cat <<EOF
Merge branch '$CURRENT'

Local merge of the rebased $CURRENT branch into $DEFAULT.

Slice: merge
PII-Doublecheck: yes
EOF
)"
```

The merge should run cleanly now. This is a single retry: if it still conflicts (a second race in the same invocation), do not loop back for another rebase. Instead run `git merge --abort` so `$DEFAULT` is never left with conflict markers in its checkout, then surface the conflict and stop; the user re-invokes `/git-discipline:merge-to-default` once the default branch has settled.

If rebase-latest-default itself stops on a non-trivial conflict, the worktree sits mid-rebase on `$CURRENT` and `$DEFAULT` is unchanged (the `git merge --abort` above already undid the merge attempt). Handle it exactly as the genuine-ambiguity case in Step 3: the same two cleanup options apply, and `merge-to-default` makes neither of those choices for the user.

## Step 6: Clean up local source branch

After a confirmed merge, the skill cleans up the local `$CURRENT` branch. Confirmed means: HEAD sits on `$DEFAULT`, HEAD has two parents, and the second parent matches `PRE_MERGE_TIP` (from Step 4) or, in the Step 5 fallback path, the tip `$CURRENT` had right before the retry merge. The skill checks that with:

```bash
SECOND_PARENT=$(git rev-parse HEAD^2 2>/dev/null || true)
[ "$SECOND_PARENT" = "$PRE_MERGE_TIP" ] || stop_with "merge confirmation failed; HEAD^2 ($SECOND_PARENT) does not match captured pre-merge source tip ($PRE_MERGE_TIP)"
```

In the Step 5 fallback path, that step repeats the `PRE_MERGE_TIP=$(git rev-parse "$CURRENT")` capture after the rebase and before the retry checkout, so the confirmation check compares against the post-rebase tip. By recording `PRE_MERGE_TIP` before the checkout, the skill closes a race window: a concurrent commit on `$CURRENT` after the checkout can shift the live `git rev-parse "$CURRENT"`, but `PRE_MERGE_TIP` stays at the value the merge actually integrated.

When that holds: try to delete the branch with `git branch -d "$CURRENT"`. Before that command, the skill checks two things:

1. **Worktree safety.** `git worktree list --porcelain` shows one block per worktree with `worktree <path>` and `branch refs/heads/<name>`. The current worktree root comes from `git rev-parse --show-toplevel` (NOT `--git-dir`, which gives the `.git` directory and never matches the `worktree` field). When some other block has `branch refs/heads/$CURRENT`, skip the delete and surface a TUI line: `⚠  Source branch '<CURRENT>' is checked out in worktree <path>; skipping local branch delete.` The merge commit on `$DEFAULT` stays intact, only the local ref of `$CURRENT` remains.

2. **No `-D` force.** The skill uses `-d` (lowercase), not `-D`. `-d` fails on un-merged branches; in this flow `$CURRENT` is by definition merged into `$DEFAULT` via the merge commit, so `-d` succeeds. If `-d` does fail (race condition with user input between step 4/5 and step 6), surface the error and stop without forcing.

This skill does not touch remote branches. The assumption is that GitHub workflows (branch protection rules with "delete head branch on merge") or a separate cleanup job clean up the remote `origin/<CURRENT>` when the PR merge lands upstream. If your repo does not do that, clean up the remote branch yourself with `git push origin --delete <CURRENT>` after the push (which is not part of this skill).

## Step 7: Reporting

Show a brief summary of what happened:

```
✓ Merged <CURRENT> into <DEFAULT>
  Merge commit: <abbrev SHA>
  Files changed: <N>, +<INS> -<DEL>
  Rebase preceded merge: yes (precondition) | yes (fallback) | no (already up to date)
  Local source branch: deleted | kept (worktree at <path>)
```

`<abbrev SHA>` comes from `git rev-parse --short HEAD`. `Files changed`, insertions, and deletions come from `git diff --shortstat $DEFAULT^1 $DEFAULT`: HEAD is the `--no-ff` merge commit, so `$DEFAULT^1` is the old default tip and this two-dot diff is what the merge brought in. The `Rebase preceded merge` line distinguishes the Step 3 precondition rebase from the rare Step 5 fallback and from the up-to-date skip. The `Local source branch` line reflects what Step 6 did: `deleted` if `git branch -d` succeeded, `kept (worktree at <path>)` if the safety check skipped the delete, or `kept (delete failed: <reason>)` if `-d` failed for another reason.

This skill never pushes the default branch; landing the merge on the remote is a separate user-go (the user-CLAUDE.md push regime documents this). The user pushes themselves once they have validated the merge is correct.
