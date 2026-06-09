#!/usr/bin/env bats
# Per-toplevel state-file namespacing. The state file path is hashed by
# `git rev-parse --show-toplevel` so two repos open in different
# worktrees do not share rotation state. The legacy global state file
# (one location for the whole user) migrates to the per-toplevel path
# on first read for the current repo.

load helpers

@test "two different toplevels resolve to two different state files" {
  # Use a fake HOME so the test does not touch the operator's real
  # ${LAICLUSE_HOME:-~/.laicluse}/git-discipline.
  local fake_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$fake_home/.laicluse/git-discipline"
  local saved_home="$HOME"
  export HOME="$fake_home"
  unset GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE

  # First repo.
  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/repo-a"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  run_dispatch "git commit -m 'Drop bad reading on transaction events'"
  [ "$status" -eq 2 ]
  local files_after_a
  files_after_a=$(ls "$fake_home/.laicluse/git-discipline/" | sort)

  # Second repo. The state file from the first must persist; the second
  # repo creates its own.
  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/repo-b"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  run_dispatch "git commit -m 'Drop bad reading on transaction events'"
  [ "$status" -eq 2 ]
  local files_after_b
  files_after_b=$(ls "$fake_home/.laicluse/git-discipline/" | sort)

  # Two distinct state files now exist, both prefixed with the repo
  # base name; counts of files differ between the two snapshots.
  local count_a count_b
  count_a=$(printf '%s\n' "$files_after_a" | grep -c "^git-discipline-commit-rule-state-" || true)
  count_b=$(printf '%s\n' "$files_after_b" | grep -c "^git-discipline-commit-rule-state-" || true)
  [ "$count_a" = "1" ]
  [ "$count_b" = "2" ]

  unset GIT_SHIM_TOPLEVEL
  export HOME="$saved_home"
}

@test "global migration archives source so a second new repo starts fresh" {
  local fake_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$fake_home/.laicluse/git-discipline"
  local saved_home="$HOME"
  export HOME="$fake_home"
  unset GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE

  # Seed the global file with rotation_pos=7 (pretend the operator has
  # been committing under the old single-file scheme).
  printf 'pv=-1\npr=-1\nrp=7\nack_pending_sha=\n' \
    > "$fake_home/.laicluse/git-discipline/git-discipline-commit-rule-state"

  # First new repo: migrates and inherits rp=7.
  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/repo-first"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  run_dispatch "git commit -m 'Drop bad reading on transaction events'"
  local first_file
  first_file=$(ls "$fake_home/.laicluse/git-discipline/git-discipline-commit-rule-state-"* 2>/dev/null | head -1)
  [ -n "$first_file" ]

  # Source is renamed to .migrated; original global path is gone.
  [ -f "$fake_home/.laicluse/git-discipline/git-discipline-commit-rule-state.migrated" ]
  [ ! -f "$fake_home/.laicluse/git-discipline/git-discipline-commit-rule-state" ]

  # Second new repo: no global file to migrate from anymore. The new
  # per-toplevel file starts fresh (rp=0 default after the dispatcher
  # advances by one for the deny path, so rp lands on slot 0 plus 1 or
  # similar small value, NOT inheriting rp=7 from the first repo).
  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/repo-second"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  run_dispatch "git commit -m 'Drop bad reading on transaction events'"
  local second_file
  second_file=$(ls "$fake_home/.laicluse/git-discipline/git-discipline-commit-rule-state-"* 2>/dev/null \
    | grep -v "$(basename "$first_file")" | head -1)
  [ -n "$second_file" ]
  local second_rp
  second_rp=$(read_state_field "$second_file" rp)
  # Second repo did not inherit rp=7; the no-migration path leaves
  # rp at the loader's default 0 (and the deny that just fired
  # writes the same rp back). Assert exactly 0 rather than just
  # `!= 7`, so partial state leakage to other slots also fails the
  # test.
  [ "$second_rp" = "0" ]

  unset GIT_SHIM_TOPLEVEL
  export HOME="$saved_home"
}

@test "legacy positional global migrates to per-toplevel and converges to key=value" {
  # Combined exercise of points 2 and 8: the global file in the OLD
  # three-line positional format must migrate into the new per-toplevel
  # path and, on the next write, end up in the canonical key=value
  # format.
  local fake_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$fake_home/.laicluse/git-discipline"
  local saved_home="$HOME"
  export HOME="$fake_home"
  unset GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE

  # Legacy three-line positional global file.
  printf '%s\n%s\n%s\n' '-1' '10' '7' \
    > "$fake_home/.laicluse/git-discipline/git-discipline-commit-rule-state"

  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/some-repo"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  run_dispatch "git commit -m 'Capture HEAD sha when ack matches' # ack-rule11:loep"
  [ "$status" -eq 0 ] || {
    printf 'expected dispatch to pass after combined migration, got status %s, output: %s\n' \
      "$status" "$output" >&2
    return 1
  }

  # Per-toplevel file exists, fields read correctly out of the migrated
  # legacy state, AND the file is now in key=value form.
  local per_top_file
  per_top_file=$(ls "$fake_home/.laicluse/git-discipline/git-discipline-commit-rule-state-"* 2>/dev/null | head -1)
  [ -n "$per_top_file" ]
  [ "$(read_state_field "$per_top_file" rp)" = "7" ]
  [ "$(read_state_field "$per_top_file" ack_pending_sha)" = "deadbeef00000000" ]
  grep -qE '^pv=' "$per_top_file"
  grep -qE '^pr=' "$per_top_file"
  grep -qE '^rp=' "$per_top_file"

  unset GIT_SHIM_TOPLEVEL
  export HOME="$saved_home"
}

@test "global state file migrates to per-toplevel path on first read" {
  local fake_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$fake_home/.laicluse/git-discipline"
  local saved_home="$HOME"
  export HOME="$fake_home"
  unset GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE

  # Seed a legacy global state file with a recognizable rotation_pos.
  printf 'pv=-1\npr=10\nrp=7\nack_pending_sha=\n' \
    > "$fake_home/.laicluse/git-discipline/git-discipline-commit-rule-state"

  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/some-repo"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  run_dispatch "git commit -m 'Capture HEAD sha when ack matches' # ack-rule11:loep"
  [ "$status" -eq 0 ] || {
    printf 'expected dispatch to pass after migration, got status %s, output: %s\n' \
      "$status" "$output" >&2
    return 1
  }

  # Per-toplevel file now exists with rp preserved at 7 and the shim
  # HEAD as pending sha (proves the seed migrated and the ack matched).
  local per_top_file
  per_top_file=$(ls "$fake_home/.laicluse/git-discipline/git-discipline-commit-rule-state-"* 2>/dev/null | head -1)
  [ -n "$per_top_file" ]
  [ "$(read_state_field "$per_top_file" rp)" = "7" ]
  [ "$(read_state_field "$per_top_file" ack_pending_sha)" = "deadbeef00000000" ]

  unset GIT_SHIM_TOPLEVEL
  export HOME="$saved_home"
}
