#!/usr/bin/env bats
# Per-session rotation namespacing. When the PreToolUse JSON payload
# carries a Claude session_id, the rotation state file gains a session
# suffix so two concurrent Claude sessions in the same repo do not race
# each other's rotation slot. Inherit-on-first-use copies the per-toplevel
# rp/pr into the new per-session file; the per-toplevel file is not
# archived because other sessions in the same repo also inherit from it.
# Opportunistic mtime prune removes per-session siblings older than 7 days.

load helpers

pretool_bash_json_with_session() {
  local cmd="$1"
  local sid="$2"
  jq -cn --arg c "$cmd" --arg s "$sid" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:$s,tool_input:{command:$c}}'
}

run_dispatch_with_session() {
  local cmd="$1"
  local sid="$2"
  local json
  json=$(pretool_bash_json_with_session "$cmd" "$sid")
  run bash "$DISPATCH" <<< "$json"
}

setup_session_test_env() {
  local fake_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$fake_home/.laicluse/git-discipline"
  export HOME="$fake_home"
  unset GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE
}

toplevel_hash_for() {
  local toplevel="$1"
  local h
  h=$(printf '%s' "$toplevel" | shasum 2>/dev/null | cut -c1-8)
  [[ -z "$h" ]] && h=$(printf '%s' "$toplevel" | md5sum 2>/dev/null | cut -c1-8)
  [[ -z "$h" ]] && h=$(printf '%s' "$toplevel" | md5 -q 2>/dev/null | cut -c1-8)
  printf '%s' "$h"
}

session_key_for() {
  local session_id="$1"
  local k
  k=$(printf '%s' "$session_id" | shasum 2>/dev/null | cut -c1-8)
  [[ -z "$k" ]] && k=$(printf '%s' "$session_id" | md5sum 2>/dev/null | cut -c1-8)
  [[ -z "$k" ]] && k=$(printf '%s' "$session_id" | md5 -q 2>/dev/null | cut -c1-8)
  printf '%s' "$k"
}

@test "two different session ids resolve to two different state files in the same repo" {
  setup_session_test_env
  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/repo-twosid"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  local h
  h=$(toplevel_hash_for "$GIT_SHIM_TOPLEVEL")

  run_dispatch_with_session "git commit -m 'Drop bad reading on transaction events'" "alpha-sid-1"
  [ "$status" -eq 2 ]
  run_dispatch_with_session "git commit -m 'Drop bad reading on transaction events'" "beta-sid-22"
  [ "$status" -eq 2 ]

  local count
  count=$(ls "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state-${h}-"* 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" = "2" ]
  [ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state-${h}-$(session_key_for "alpha-sid-1")" ]
  [ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state-${h}-$(session_key_for "beta-sid-22")" ]

  unset GIT_SHIM_TOPLEVEL
}

@test "same session id is idempotent: two dispatches reuse one per-session file" {
  setup_session_test_env
  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/repo-idem"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  local h
  h=$(toplevel_hash_for "$GIT_SHIM_TOPLEVEL")

  run_dispatch_with_session "git commit -m 'Drop bad reading on transaction events'" "stable-sid-001"
  [ "$status" -eq 2 ]
  run_dispatch_with_session "git commit -m 'Drop bad reading on transaction events'" "stable-sid-001"
  [ "$status" -eq 2 ]

  local count
  count=$(ls "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state-${h}-"* 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" = "1" ]
  [ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state-${h}-$(session_key_for "stable-sid-001")" ]

  unset GIT_SHIM_TOPLEVEL
}

@test "dispatch without session_id falls back to the per-toplevel state file" {
  setup_session_test_env
  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/repo-no-sid"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  local h per_toplevel
  h=$(toplevel_hash_for "$GIT_SHIM_TOPLEVEL")
  per_toplevel="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state-${h}"

  run_dispatch "git commit -m 'Drop bad reading on transaction events'"
  [ "$status" -eq 2 ]

  [ -f "$per_toplevel" ]
  local sibling_count
  sibling_count=$(ls "${per_toplevel}-"* 2>/dev/null | wc -l | tr -d ' ')
  [ "$sibling_count" = "0" ]

  unset GIT_SHIM_TOPLEVEL
}

@test "first session use inherits rp from per-toplevel into the new per-session file" {
  setup_session_test_env
  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/repo-inherit"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  local h per_toplevel per_session
  h=$(toplevel_hash_for "$GIT_SHIM_TOPLEVEL")
  per_toplevel="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state-${h}"
  per_session="${per_toplevel}-$(session_key_for "alpha-inherit")"
  printf 'pv=-1\npr=-1\nrp=7\nack_pending_sha=\n' > "$per_toplevel"

  run_dispatch_with_session "git commit -m 'Capture HEAD sha when ack matches'" "alpha-inherit"
  [ "$status" -eq 2 ]

  [ -f "$per_session" ]
  [ "$(read_state_field "$per_session" rp)" = "7" ]
  [[ "$output" == *"Rule 11/15"* ]] || {
    printf 'expected the deny to fire rule 11 (rotation_slots[7]=10 → rule 11), got: %s\n' "$output" >&2
    return 1
  }
  [ -f "$per_toplevel" ]
  [ ! -f "${per_toplevel}.migrated" ]

  unset GIT_SHIM_TOPLEVEL
}

@test "concurrent mutation of per-toplevel does not change the slot the current session is asked to ack" {
  setup_session_test_env
  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/repo-race"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  local h per_toplevel per_alpha
  h=$(toplevel_hash_for "$GIT_SHIM_TOPLEVEL")
  per_toplevel="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state-${h}"
  per_alpha="${per_toplevel}-$(session_key_for "alpha-race-x")"
  printf 'pv=-1\npr=-1\nrp=6\nack_pending_sha=\n' > "$per_toplevel"

  run_dispatch_with_session "git commit -m 'Capture HEAD sha when ack matches'" "alpha-race-x"
  [ "$status" -eq 2 ]
  [ "$(read_state_field "$per_alpha" pr)" = "9" ]
  [ "$(read_state_field "$per_alpha" rp)" = "6" ]

  printf 'pv=-1\npr=-1\nrp=10\nack_pending_sha=\n' > "$per_toplevel"

  run_dispatch_with_session "git commit -m 'Capture HEAD sha when ack matches' # ack-rule10:incognito" "alpha-race-x"
  [ "$status" -eq 0 ] || {
    printf 'expected alpha ack to pass after parallel mutation, got status %s, output: %s\n' "$status" "$output" >&2
    return 1
  }

  unset GIT_SHIM_TOPLEVEL
}

@test "stale per-session siblings older than 7 days are pruned on session-first-read" {
  setup_session_test_env
  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/repo-prune"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  local h per_toplevel stale_sibling fresh_sibling new_session
  h=$(toplevel_hash_for "$GIT_SHIM_TOPLEVEL")
  per_toplevel="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state-${h}"
  stale_sibling="${per_toplevel}-deadold0"
  fresh_sibling="${per_toplevel}-recently"
  new_session="${per_toplevel}-$(session_key_for "fresh-prune-test")"
  printf 'pv=-1\npr=-1\nrp=0\nack_pending_sha=\n' > "$per_toplevel"
  printf 'pv=-1\npr=-1\nrp=0\nack_pending_sha=\n' > "$stale_sibling"
  printf 'pv=-1\npr=-1\nrp=0\nack_pending_sha=\n' > "$fresh_sibling"
  touch -t 202001010000 "$stale_sibling"

  run_dispatch_with_session "git commit -m 'Drop bad reading on transaction events'" "fresh-prune-test"
  [ "$status" -eq 2 ]

  [ ! -f "$stale_sibling" ]
  [ -f "$per_toplevel" ]
  [ -f "$fresh_sibling" ]
  [ -f "$new_session" ]

  unset GIT_SHIM_TOPLEVEL
}

@test "session inherit copies only rp; pv and ack_pending_sha reset to fresh state" {
  setup_session_test_env
  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/repo-inherit-reset"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  local h per_toplevel per_session
  h=$(toplevel_hash_for "$GIT_SHIM_TOPLEVEL")
  per_toplevel="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state-${h}"
  per_session="${per_toplevel}-$(session_key_for "fresh-isolation")"
  printf 'pv=2\npr=4\nrp=5\nack_pending_sha=feedfacefeedface\n' > "$per_toplevel"

  run_dispatch_with_session "git commit -m 'Drop bad reading on transaction events'" "fresh-isolation"
  [ "$status" -eq 2 ]

  [ -f "$per_session" ]
  [ "$(read_state_field "$per_session" rp)" = "5" ]
  [ "$(read_state_field "$per_toplevel" pv)" = "2" ]
  [ "$(read_state_field "$per_toplevel" ack_pending_sha)" = "feedfacefeedface" ]

  unset GIT_SHIM_TOPLEVEL
}

@test "per-toplevel file is not archived after session inherit" {
  setup_session_test_env
  export GIT_SHIM_TOPLEVEL="$BATS_TEST_TMPDIR/repo-noarchive"
  mkdir -p "$GIT_SHIM_TOPLEVEL"
  local h per_toplevel
  h=$(toplevel_hash_for "$GIT_SHIM_TOPLEVEL")
  per_toplevel="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state-${h}"
  printf 'pv=-1\npr=-1\nrp=4\nack_pending_sha=\n' > "$per_toplevel"

  run_dispatch_with_session "git commit -m 'Drop bad reading on transaction events'" "first-sess"
  [ "$status" -eq 2 ]
  [ -f "$per_toplevel" ]
  [ ! -f "${per_toplevel}.migrated" ]

  run_dispatch_with_session "git commit -m 'Drop bad reading on transaction events'" "second-sess"
  [ "$status" -eq 2 ]
  [ -f "$per_toplevel" ]
  [ ! -f "${per_toplevel}.migrated" ]
  [ "$(read_state_field "$per_toplevel" rp)" = "4" ]

  unset GIT_SHIM_TOPLEVEL
}
