#!/usr/bin/env bats
# live-validation.bats
# Behavioural integration test: install hooks in a fixture repo and prove
# that the wired commit-msg actually denies a non-trivial body-less commit
# and accepts a body-compliant one. This proves the install-time path
# substitution and the validator chain end-to-end.

load helpers

@test "installed commit-msg blocks non-trivial body-less commit" {
  run_install "$TEST_REPO"
  [ "$status" -eq 0 ]

  pushd "$TEST_REPO" >/dev/null

  # Stage enough content to exceed the trivial threshold (>1 file or >5 ins).
  for i in 1 2 3; do
    printf 'line-a\nline-b\nline-c\n' > "file$i.txt"
  done
  git add file1.txt file2.txt file3.txt

  run git -c commit.gpgsign=false commit -m "Subject only, no body, non-trivial change"

  [ "$status" -ne 0 ]
  [[ "$output" == *"git-discipline/commit-msg"* ]] || [[ "$output" == *"missing-body"* ]]

  popd >/dev/null
}

@test "installed commit-msg accepts a body-compliant commit" {
  run_install "$TEST_REPO"
  [ "$status" -eq 0 ]

  pushd "$TEST_REPO" >/dev/null

  # Stage a single tiny change so we are trivial; the validator skips
  # the body requirement entirely. This isolates "hook ran and let me
  # through" from the more complex non-trivial flow.
  printf 'one\n' > tiny.txt
  git add tiny.txt

  run git -c commit.gpgsign=false commit -m "Tiny trivial change"

  [ "$status" -eq 0 ]

  popd >/dev/null
}

@test "installed commit-msg accepts non-trivial commit with full body schema" {
  run_install "$TEST_REPO"
  [ "$status" -eq 0 ]

  pushd "$TEST_REPO" >/dev/null

  # Create a fake spec path the Tests trailer can reference.
  install -d spec
  printf 'placeholder spec\n' > spec/foo_spec.rb
  for i in 1 2 3; do
    printf 'line-a\nline-b\nline-c\n' > "src$i.rb"
  done
  git add spec/foo_spec.rb src1.rb src2.rb src3.rb

  local msg
  msg=$(cat <<'BODY'
Add foo controller boundary

When StartTransaction messages arrive with an invalid meter reading,
the previous implementation rejected the entire event and masked
session starts in the analytics pipeline.

Tests: spec/foo_spec.rb
Slice: handler + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
BODY
)

  run git -c commit.gpgsign=false commit -m "$msg"

  [ "$status" -eq 0 ]

  popd >/dev/null
}

@test "post-commit logs a --no-verify bypass" {
  run_install "$TEST_REPO"
  [ "$status" -eq 0 ]

  pushd "$TEST_REPO" >/dev/null

  printf 'one\n' > a.txt
  git add a.txt
  git -c commit.gpgsign=false commit --no-verify -m "Bypass via no-verify" >/dev/null

  popd >/dev/null

  local log="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-no-verify.log"
  [ -f "$log" ]
  # Format is ts|sha|branch (3 fields, no email column since Fix 8).
  # Pattern anchors to exactly 3 pipe-delimited fields so a 4-field regression
  # (e.g. email column reintroduced) would cause this assertion to fail.
  grep -qE "^[^|]+\|[^|]+\|main$" "$log"
}

@test "post-commit does NOT log when commit-msg ran normally" {
  run_install "$TEST_REPO"
  [ "$status" -eq 0 ]

  pushd "$TEST_REPO" >/dev/null

  printf 'one\n' > a.txt
  git add a.txt
  git -c commit.gpgsign=false commit -m "Trivial change" >/dev/null

  popd >/dev/null

  local log="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-no-verify.log"
  # File may exist from earlier tests in other repos, but this commit's SHA
  # must not be in the log.
  if [[ -f "$log" ]]; then
    pushd "$TEST_REPO" >/dev/null
    local sha
    sha=$(git rev-parse --short HEAD)
    popd >/dev/null
    ! grep -q "|$sha|" "$log"
  fi
}
