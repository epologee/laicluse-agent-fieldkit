#!/usr/bin/env bats
# Contract tests for bin/bonsai teardown: the hard safety gate.
# A non-integrated worktree is never removed without --force; orphaned commits warn.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  BONSAI="$REPO_ROOT/packages/bonsai/bin/bonsai"
  NODE_BIN="$(command -v node)"
  FIX="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$FIX"
  git -C "$FIX" init -q -b main
  git -C "$FIX" config user.email t@t.t
  git -C "$FIX" config user.name t
  git -C "$FIX" commit -q --allow-empty -m init
}

bonsai() { "$NODE_BIN" "$BONSAI" "$@"; }

@test "teardown removes a clean worktree with nothing ahead of default" {
  bonsai create clean-wt --repo "$FIX" --json
  run bonsai teardown clean-wt --repo "$FIX" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"removed": true'
  [ ! -d "$FIX/worktrees/clean-wt" ]
  ! git -C "$FIX" show-ref --verify --quiet refs/heads/clean-wt
}

@test "teardown keeps a non-integrated worktree that has commits, no force" {
  bonsai create work-wt --repo "$FIX" --json
  git -C "$FIX/worktrees/work-wt" commit -q --allow-empty -m work
  run bonsai teardown work-wt --repo "$FIX" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"removed": false'
  echo "$output" | grep -qiE 'unmerged|not integrated|commits'
  [ -d "$FIX/worktrees/work-wt" ]
}

@test "teardown warns about orphaned unpushed commits" {
  bonsai create orphan-wt --repo "$FIX" --json
  git -C "$FIX/worktrees/orphan-wt" commit -q --allow-empty -m work
  run bonsai teardown orphan-wt --repo "$FIX" --json
  echo "$output" | grep -qiE 'orphan|unpushed'
}

@test "teardown --force removes a non-integrated worktree" {
  bonsai create force-wt --repo "$FIX" --json
  git -C "$FIX/worktrees/force-wt" commit -q --allow-empty -m work
  run bonsai teardown force-wt --repo "$FIX" --force --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"removed": true'
  [ ! -d "$FIX/worktrees/force-wt" ]
}

@test "teardown matches a worktree by its full path" {
  bonsai create path-wt --repo "$FIX" --json
  run bonsai teardown "$FIX/worktrees/path-wt" --repo "$FIX" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"removed": true'
  [ ! -d "$FIX/worktrees/path-wt" ]
}

@test "teardown --dry-run never removes, reports classification" {
  bonsai create dry-wt --repo "$FIX" --json
  git -C "$FIX/worktrees/dry-wt" commit -q --allow-empty -m work
  run bonsai teardown dry-wt --repo "$FIX" --dry-run --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"removed": false'
  [ -d "$FIX/worktrees/dry-wt" ]
}

@test "teardown judges integration against origin default when local default is stale" {
  # Incident reproduction: the branch is already merged into origin/main, but the
  # local main ref trails origin AND carries a stray local-only commit, so it is
  # 1-ahead of origin/main. resolveBase would still return the stale local ref;
  # only judging against origin/main sees the branch as the removable ancestor it is.
  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  git init -q --bare -b main "$ORIGIN"
  git -C "$FIX" remote add origin "$ORIGIN"
  git -C "$FIX" push -q origin main
  base_sha="$(git -C "$FIX" rev-parse main)"

  # Feature worktree + branch off main, one commit, fast-forwarded into main.
  bonsai create merged-wt --repo "$FIX" --json
  git -C "$FIX/worktrees/merged-wt" commit -q --allow-empty -m "feature work"
  git -C "$FIX" merge -q --ff-only merged-wt

  # Origin advances past the merge point and we publish it.
  git -C "$FIX" commit -q --allow-empty -m "later main work"
  git -C "$FIX" push -q origin main

  # Local main goes stale: reset behind the merge, add a stray local-only commit.
  git -C "$FIX" reset -q --hard "$base_sha"
  git -C "$FIX" commit -q --allow-empty -m "Safety baseline"
  git -C "$FIX" fetch -q origin

  # Local main is 1-ahead (stray) and 2-behind origin/main: defeats resolveBase.
  [ "$(git -C "$FIX" rev-list --left-right --count main...origin/main)" = "$(printf '1\t2')" ]

  run bonsai teardown merged-wt --repo "$FIX" --dry-run --json
  [ "$status" -eq 0 ]
  # Against origin/main the branch is a clean ancestor, so it is removable; against the
  # stale+stray local main (the old behaviour) it would be refused. removable:true is the
  # discriminator that integration was judged against the remote ref.
  echo "$output" | grep -q '"removable": true'
  ! echo "$output" | grep -qiE 'orphan|unpushed'
  # An already-integrated, removable worktree gets no "rebase before wrap" advice.
  ! echo "$output" | grep -qiE 'advanced|rebase'
}

@test "teardown removes a branch merged into local default when origin trails" {
  # Inverse skew: the branch is merged into LOCAL main (fast-forward) but origin/main
  # has not advanced, so origin lacks the work. Judging against origin alone would
  # refuse this removable, locally-merged worktree; judging against either default removes it.
  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  git init -q --bare -b main "$ORIGIN"
  git -C "$FIX" remote add origin "$ORIGIN"
  git -C "$FIX" push -q origin main

  bonsai create local-wt --repo "$FIX" --json
  git -C "$FIX/worktrees/local-wt" commit -q --allow-empty -m "feature work"
  git -C "$FIX" merge -q --ff-only local-wt
  git -C "$FIX" fetch -q origin

  # Local main contains the branch and is ahead of the trailing origin/main.
  [ "$(git -C "$FIX" rev-list --count origin/main..main)" -gt 0 ]

  run bonsai teardown local-wt --repo "$FIX" --dry-run --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"removable": true'
  ! echo "$output" | grep -qiE 'orphan|unpushed'
}
