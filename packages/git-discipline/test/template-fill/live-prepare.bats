#!/usr/bin/env bats
# live-prepare.bats
# Behavioral integration tests for prepare-commit-msg.
#
# Strategy: install hooks via lib/install.sh into a real fixture repo using
# the development checkout as the plugin path. Stage files, then run
# git commit in a way that exercises prepare-commit-msg and captures the
# resulting COMMIT_EDITMSG content before git commits (we use --dry-run is
# not available for prepare-commit-msg, so instead we abort the commit by
# having the editor exit non-zero via GIT_EDITOR=false, then inspect
# .git/COMMIT_EDITMSG which git writes even when the editor aborts).

load helpers

setup() {
  setup_fixture_repo
}

teardown() {
  : # BATS_TEST_TMPDIR cleaned by bats-core.
}

# ---------------------------------------------------------------------------
# Helper: install hooks and stage files in TEST_REPO.
# ---------------------------------------------------------------------------

_install_and_stage() {
  run_install "$TEST_REPO"
  [ "$status" -eq 0 ]

  pushd "$TEST_REPO" >/dev/null

  install -d app/services spec/services
  printf 'class SessionService; end\n' > app/services/session_service.rb
  printf '# spec\n' > spec/services/session_service_spec.rb
  git add app/services/session_service.rb spec/services/session_service_spec.rb

  popd >/dev/null
}

# ---------------------------------------------------------------------------
# Helper: run git commit with GIT_EDITOR=false so git writes COMMIT_EDITMSG
# (prepare-commit-msg fires) but the commit is aborted by the editor.
# git exits non-zero (editor abort), but we only care about COMMIT_EDITMSG.
# ---------------------------------------------------------------------------

_run_editor_abort_commit() {
  pushd "$TEST_REPO" >/dev/null

  # GIT_EDITOR=false: git opens the editor and /usr/bin/false immediately
  # exits 1, causing git to abort the commit with "Aborting commit due to
  # empty commit message" -- but prepare-commit-msg ran before the editor.
  GIT_EDITOR=false git -c commit.gpgsign=false commit --no-verify 2>/dev/null || true

  popd >/dev/null
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@test "live: prepare-commit-msg writes WHY placeholder into COMMIT_EDITMSG" {
  _install_and_stage
  _run_editor_abort_commit

  editmsg="$TEST_REPO/.git/COMMIT_EDITMSG"
  [ -f "$editmsg" ]
  grep -q "WHY:" "$editmsg"
}

@test "live: prepare-commit-msg writes real Slice trailer into COMMIT_EDITMSG" {
  # Fix 9: Slice must be a real line (no # prefix) so the validator sees it.
  _install_and_stage
  _run_editor_abort_commit

  editmsg="$TEST_REPO/.git/COMMIT_EDITMSG"
  [ -f "$editmsg" ]
  # Real Slice line (not a comment).
  grep -qE '^Slice:' "$editmsg"
}

@test "live: prepare-commit-msg auto-detects staged spec path" {
  _install_and_stage
  _run_editor_abort_commit

  editmsg="$TEST_REPO/.git/COMMIT_EDITMSG"
  [ -f "$editmsg" ]
  grep -q "session_service_spec.rb" "$editmsg"
}

@test "live: prepare-commit-msg does not fire on merge commit" {
  _install_and_stage

  # Create a side branch to merge from so we get a real merge commit scenario.
  pushd "$TEST_REPO" >/dev/null

  # Initial commit uses --no-verify: we are testing prepare-commit-msg on the
  # merge, not the initial setup commit. The hook suite is installed by
  # _install_and_stage but we bypass it here to keep the fixture simple.
  printf 'init\n' > init.txt
  git add init.txt
  git -c commit.gpgsign=false commit --no-verify -m "Init" >/dev/null

  git checkout -q -b side
  printf 'side\n' > side.txt
  git add side.txt
  git -c commit.gpgsign=false commit --no-verify -m "Side commit" >/dev/null
  git checkout -q main

  # Merge with --no-ff and -m so the editor does not open.
  # prepare-commit-msg receives source="merge" and must do nothing.
  git -c commit.gpgsign=false merge --no-ff side -m "Merge branch side" >/dev/null || true

  # The merge commit message must not contain our WHY template.
  local log_body
  log_body=$(git log -1 --pretty=format:'%B' 2>/dev/null || true)
  [[ "$log_body" != *"WHY:"* ]]

  popd >/dev/null
}
