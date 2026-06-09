#!/usr/bin/env bats
# packages/git-discipline/test/session-toggle/sentinel-filename.bats
#
# Verifies that the sentinel filename embeds the session_id and is therefore
# unique per session: two different session_ids produce two independent
# sentinels that do not interfere with each other.

load helpers

@test "sentinel filename includes the session_id verbatim" {
  local sid="unique-session-deadbeef"
  write_session_sentinel "$sid"

  [[ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-$sid" ]]
}

@test "two session sentinels coexist independently" {
  local sid_a="session-alpha"
  local sid_b="session-beta"
  write_session_sentinel "$sid_a"
  write_session_sentinel "$sid_b"

  [[ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-$sid_a" ]]
  [[ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-$sid_b" ]]
}

@test "sentinel for session A suppresses guards for A but not for B" {
  local sid_a="session-suppress"
  local sid_b="session-active"
  write_session_sentinel "$sid_a"

  # Session A: should exit 0 silently.
  run_dispatch_with_session \
    'git commit -m "bad commit no body" # ack-rule4:essentie' \
    "$sid_a"
  [ "$status" -eq 0 ]

  # Session B (no sentinel): non-trivial commit should be blocked.
  export GIT_SHIM_SHORTSTAT=" 3 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/foo.rb\napp/models/bar.rb\nspec/models/foo_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch_with_session \
    'git commit -m "bare subject no body" # ack-rule4:essentie' \
    "$sid_b"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/commit-body]"* ]]
}

@test "removing session sentinel re-enables guards for that session" {
  local sid="session-toggle-test"
  write_session_sentinel "$sid"

  # Confirm guards are suppressed.
  run_dispatch_with_session \
    'git commit -m "bad commit no body" # ack-rule4:essentie' \
    "$sid"
  [ "$status" -eq 0 ]

  # Remove sentinel (simulates /git-discipline:enable-discipline).
  rm "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-$sid"

  # Now guards should run for a non-trivial commit.
  export GIT_SHIM_SHORTSTAT=" 3 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/foo.rb\napp/models/bar.rb\nspec/models/foo_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch_with_session \
    'git commit -m "bare subject no body" # ack-rule4:essentie' \
    "$sid"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/commit-body]"* ]]
}
