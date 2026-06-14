#!/usr/bin/env bats
# Contract tests for bin/bonsai setup: copy .bonsai files from the canonical
# checkout and detect the per-directory package manager. --no-install keeps
# the tests offline.

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

@test "setup copies .bonsai-listed files from the canonical checkout" {
  printf 'secret.txt\n' > "$FIX/.bonsai"
  printf 's3cr3t\n' > "$FIX/secret.txt"
  bonsai create cfg-wt --repo "$FIX" --json
  run bonsai setup "$FIX/worktrees/cfg-wt" --repo "$FIX" --no-install --json
  [ "$status" -eq 0 ]
  [ -f "$FIX/worktrees/cfg-wt/secret.txt" ]
  echo "$output" | grep -q 'secret.txt'
}

@test "setup with no .bonsai file does nothing and does not error" {
  bonsai create plain-wt --repo "$FIX" --json
  run bonsai setup "$FIX/worktrees/plain-wt" --repo "$FIX" --no-install --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"copied"'
}

@test "setup detects the package manager from the lockfile" {
  bonsai create dep-wt --repo "$FIX" --json
  mkdir -p "$FIX/worktrees/dep-wt/app"
  printf '{}\n' > "$FIX/worktrees/dep-wt/app/package.json"
  : > "$FIX/worktrees/dep-wt/app/yarn.lock"
  run bonsai setup "$FIX/worktrees/dep-wt" --repo "$FIX" --no-install --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'yarn'
}

@test "setup skips a .bonsai entry that does not exist without erroring" {
  printf 'missing.txt\n' > "$FIX/.bonsai"
  bonsai create miss-wt --repo "$FIX" --json
  run bonsai setup "$FIX/worktrees/miss-wt" --repo "$FIX" --no-install --json
  [ "$status" -eq 0 ]
  [ ! -f "$FIX/worktrees/miss-wt/missing.txt" ]
}
