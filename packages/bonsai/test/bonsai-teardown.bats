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
