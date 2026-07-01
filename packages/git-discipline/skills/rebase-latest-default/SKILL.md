---
name: rebase-latest-default
user-invocable: true
description: >-
  Rebase the current branch onto the freshest local or remote default branch.
allowed-tools: Bash(git rev-parse:*), Bash(git ls-remote:*), Bash(git rebase:*), Bash(git rev-list:*), Bash(git add:*), Bash(git diff:*), Bash(git status:*), Bash(git symbolic-ref:*), Bash(git remote:*), Bash(git log:*), Bash(git push:*), Bash(git config:*)
optional: true
scope: global
---

# /git-discipline:rebase-latest-default Skill

Rebase the current branch on the latest version of the default branch. The target can be a local branch (e.g. `main`) or a remote tracking branch (e.g. `origin/main`), whichever is further ahead. This supports worktree setups where the main worktree has unpushed commits, and repos without a remote.

## Step 0: Detect Default Branch and Rebase Target

### 0a: Find the default branch name

Determine the default branch name (`$DEFAULT`):

1. Try `git symbolic-ref refs/remotes/origin/HEAD` and extract the branch name (e.g. `main`).
2. If that fails (no remote, or ref not set), check which of `main` or `master` exists locally via `git rev-parse --verify refs/heads/main` and `git rev-parse --verify refs/heads/master`. Prefer `main` if both exist.
3. If neither exists, stop and ask the user.

### 0b: Determine the rebase target

Check which references to `$DEFAULT` exist:

```bash
git rev-parse --verify refs/heads/$DEFAULT 2>/dev/null
```
```bash
git rev-parse --verify refs/remotes/origin/$DEFAULT 2>/dev/null
```

Based on availability, determine `$TARGET`:

- **Both exist:** Compare which is ahead:
  ```bash
  git rev-list --left-right --count refs/heads/$DEFAULT...refs/remotes/origin/$DEFAULT
  ```
  Left count = commits in local not in origin (local ahead). Right count = commits in origin not in local (origin ahead). If origin is strictly ahead (right > 0, left = 0), use `origin/$DEFAULT`. If both have diverged (left > 0 AND right > 0), warn: `Local $DEFAULT and origin/$DEFAULT have diverged (<left> and <right> commits respectively). Rebasing on local. Consider fetching and fast-forwarding local $DEFAULT first.` Then use `$DEFAULT` (local). If local is ahead or equal, use `$DEFAULT` (local). Report which target was chosen and why.
- **Only local exists:** Use `$DEFAULT`. No staleness check needed.
- **Only remote exists:** Use `origin/$DEFAULT`. Proceed to Step 1 (staleness check).
- **Neither exists:** Stop and ask the user.

## Step 1: Staleness Check (remote targets only)

Skip this step entirely when `$TARGET` is a local branch.

When `$TARGET` is `origin/$DEFAULT`, check if the tracking ref matches the remote without fetching. Run these as **separate Bash calls**:

```bash
git rev-parse refs/remotes/origin/$DEFAULT
```
```bash
git ls-remote origin refs/heads/$DEFAULT
```

Compare the SHAs:

- **If they match:** proceed to Step 2.
- **If they differ:** show a warning and **stop**:
  ```
  origin/$DEFAULT is stale (local: <short-sha>, remote: <short-sha>).
  Run `git fetch origin` first, then invoke /git-discipline:rebase-latest-default again.
  ```
  Do NOT proceed with the rebase. Do NOT fetch. The user must fetch explicitly because fetching updates all remote tracking refs, which affects `--force-with-lease` behavior on other branches.

## Step 2: Pre-rebase Guards

First, check if the current branch IS the default branch:

```bash
git rev-parse --abbrev-ref HEAD
```

If the current branch equals `$DEFAULT`, report `You are on $DEFAULT, nothing to rebase.` and stop.

Then, check for uncommitted changes:

```bash
git status --porcelain
```

If the output is non-empty, report `Working tree is dirty. Stash or commit your changes first.` and stop.

## Step 3: Pre-rebase State

Record the current state so the user can assess the rebase afterward:

```bash
git rev-list --left-right --count $TARGET...HEAD
```

Report: `Branch is <ahead> commits ahead, <behind> commits behind $TARGET.`

If the branch is 0 commits behind, report `Already up to date with $TARGET.` and stop.

## Step 4: Rebase

```bash
git rebase $TARGET
```

- **If the rebase succeeds cleanly:** proceed to Step 5.
- **If the rebase hits conflicts:** proceed to Step 4a.

## Step 4a: Resolve Conflicts

When a rebase stops on conflicts:

1. Read each conflicting file to understand both sides.
2. Resolve the conflicts. Use your understanding of the codebase and the intent of both sides to produce the correct merge. Prefer the branch's intent when it deliberately diverges from the default branch (that's the point of the branch). Prefer the default branch's version for incidental changes (renames, formatting, new imports).
3. Stage the resolved files and continue:
   ```bash
   git add <resolved-files>
   ```
   ```bash
   git rebase --continue
   ```
4. Repeat if the rebase stops on further commits.
5. If a conflict is genuinely ambiguous (both sides made intentional, incompatible changes to the same logic), stop and describe the conflict to the user instead of guessing.

### Generated files: regenerate, don't hand-merge

A conflict in a generated file (a schema dump like Rails' `db/schema.rb`, a lockfile, codegen output) is not resolved by editing the markers; hand-stitching produces something the generator would never emit. Clear the markers only to unblock (take either side), then rerun whatever produces the file and stage that output. Pick the right tool per file: you already know which command regenerates each kind.

If the generator needs the fully merged inputs (which only exist once the rebase finishes), unblock the conflicting commit with a placeholder, let the rebase complete, regenerate once against the final tree, and fold the result into the commit it belongs to.

## Step 5: After Rebase

Report the result: how many commits ahead of `$TARGET`, and whether conflicts were resolved (and if so, which files). Then proceed to Step 6 for the push decision.

## Step 5a: Mark carry-along commits that predate the discipline

A rebase replays commits that may have been authored before the commit-body
discipline existed; on the push the body-gate flags those subject-only commits.
They are not new work to re-justify, and reworking their bodies is busywork over
changes that already shipped under their pre-rebase SHA. Mark them as carried,
do not rewrite them.

For each rebased commit whose body does not meet the schema (a subject-only
commit, or one the gate would flag), amend the trailer `Discipline: skip due to
rebase` onto it so the body-gate treats it as already-shipped. The route is the
local session's call: stamp during the rebase, or push first and let the gate
name the stragglers, then amend the trailer onto exactly those. Commits you
authored under the discipline keep their real body; the marker is only for the
carry-along, not a blanket bypass. The trailer and its semantics are documented
in `/git-discipline:commit-discipline` under Escape hatches.

## Step 6: Forced-continuation push (resolver-gated)

A rebase rewrites the branch's commits, so the published branch now points at pre-rebase commits and its open PR keeps running CI against the OLD tip. **The whole point of this skill is that CI re-runs on the rebased version**, so pushing the rebased tip is the COMPLETION of this rebase, not a new decision: it does not need a fresh go. The current branch is a feature branch here (Step 2 already stopped if you were on the default), so this never force-pushes the default. Deferring the push to the operator leaves CI stuck on the pre-rebase commits and defeats the skill.

Consult the resolver, reading `push_access` from its output:

```bash
resolve_git_discipline_root() {
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT"
    return 0
  fi
  if command -v codex >/dev/null 2>&1; then
    codex plugin list --json \
      | jq -er '.installed[] | select(.pluginId == "git-discipline@laicluse-agent-fieldkit") | .source.path'
    return $?
  fi
  return 1
}

GD_ROOT="$(resolve_git_discipline_root)" || { echo "git-discipline plugin root not found" >&2; exit 1; }
"$GD_ROOT/skills/push-policy/git-repo-policy"
```

**The gate is whether the branch is PUBLISHED, not whether an upstream is configured.** A branch can have a live remote counterpart (and an open PR) while its local tracking is unset; `@{u}` then fails even though the branch is fully published. Detect publication by the remote branch, and read the current branch name first:

```bash
git rev-parse --abbrev-ref HEAD
```
```bash
git rev-parse --verify refs/remotes/origin/$BRANCH 2>/dev/null
```

Decide:

- **Remote branch exists AND `push_access` is not `external`:** force-with-lease push the rebased tip so CI re-runs. `--force-with-lease` is safe by construction here: it compares against the remote-tracking ref and refuses if the remote moved beyond what you last fetched, so it cannot clobber a teammate's push.
  - Upstream configured (`@{u}` resolves): `git push --force-with-lease`
  - Upstream NOT configured: push explicitly against the published branch and repair tracking, do NOT defer:
    ```bash
    git push --force-with-lease=$BRANCH:$(git rev-parse refs/remotes/origin/$BRANCH) origin HEAD:$BRANCH
    ```
    ```bash
    git branch --set-upstream-to=origin/$BRANCH
    ```
- **No remote branch at all (branch is local-only, never pushed):** this would be a FIRST publication, a genuine operator gate. Leave it to the operator and report the branch is rebased and ready.
- **`push_access` is `external`:** no write rights. Leave the push to the operator.

The push hooks still gate the CONTENT of that push (no wip commits, valid bodies); the force flag does not bypass them. See `/git-discipline:push-policy` for the mode behavior.
