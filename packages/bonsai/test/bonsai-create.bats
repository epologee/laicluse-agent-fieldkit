#!/usr/bin/env bats
# Contract tests for bin/bonsai create: worktree + branch + gitignore + json facts.

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

run_bonsai() { "$NODE_BIN" "$BONSAI" "$@"; }

@test "create makes a worktree, branch, gitignore and prints json facts" {
  run run_bonsai create my-feature --repo "$FIX" --json
  [ "$status" -eq 0 ]
  [ -d "$FIX/worktrees/my-feature" ]
  [ -f "$FIX/worktrees/.gitignore" ]
  echo "$output" | grep -q '"branch": "my-feature"'
  echo "$output" | grep -q '"worktree"'
  echo "$output" | grep -q '"port"'
  git -C "$FIX" show-ref --verify --quiet refs/heads/my-feature
}

@test "create sanitizes a slash branch into a dashed dir and returns both" {
  run run_bonsai create feature/foo --repo "$FIX" --json
  [ "$status" -eq 0 ]
  [ -d "$FIX/worktrees/feature-foo" ]
  echo "$output" | grep -q '"branch": "feature/foo"'
  echo "$output" | grep -q 'feature-foo'
}

@test "create refuses an existing branch with a clear message" {
  run_bonsai create dup --repo "$FIX" --json
  run run_bonsai create dup --repo "$FIX" --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "already exists"
}

@test "create is deterministic about the port for a given dir name" {
  run run_bonsai create stable --repo "$FIX" --json
  port_a="$(echo "$output" | grep '"port"' | grep -oE '[0-9]+')"
  [ "$port_a" -ge 3100 ]
  [ "$port_a" -le 3999 ]
}

@test "create --dir decouples the worktree dir from the branch name" {
  run run_bonsai create my-handle --dir my-handle-r2 --repo "$FIX" --json
  [ "$status" -eq 0 ]
  [ -d "$FIX/worktrees/my-handle-r2" ]
  [ ! -d "$FIX/worktrees/my-handle" ]
  echo "$output" | grep -q '"branch": "my-handle"'
  echo "$output" | grep -q 'my-handle-r2'
  git -C "$FIX" show-ref --verify --quiet refs/heads/my-handle
}

@test "create rejects a .. branch name as invalid" {
  run run_bonsai create .. --repo "$FIX" --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi 'invalid branch'
}

@test "create rejects a branch name with whitespace" {
  run run_bonsai create "my feature" --repo "$FIX" --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi 'invalid branch'
}

@test "create emits a JSON error object under --json on failure" {
  run_bonsai create dup2 --repo "$FIX" --json
  run run_bonsai create dup2 --repo "$FIX" --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -q '"error"'
}
