#!/usr/bin/env bats
# packages/git-discipline/test/repo-deny/disable-discipline-orthogonal.bats
#
# /git-discipline:disable-discipline silences the commit-discipline guards
# session-wide, but the per-repo /git-discipline:disable-git lock is intentionally
# orthogonal: it must keep firing even when discipline is disabled.

load helpers

@test "global disable-discipline does NOT lift the per-repo lock" {
  write_sentinel "safety lock"
  mkdir -p "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline"
  touch "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-global"

  run_dispatch 'git commit -m foo'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/disable-git]"* ]]
}

@test "session disable-discipline does NOT lift the per-repo lock" {
  write_sentinel
  local sid="test-session-orth"
  mkdir -p "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline"
  touch "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-$sid"

  local json
  json=$(jq -cn --arg c 'git checkout main' --arg s "$sid" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:$s,tool_input:{command:$c}}')
  run bash "$DISPATCH" <<< "$json"

  [ "$status" -eq 2 ]
}

@test "global disable-discipline still skips OTHER guards on read-only commands" {
  # No sentinel here. Without the sentinel and with global-disable, dispatch
  # should silently pass through.
  mkdir -p "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline"
  touch "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-global"

  run_dispatch 'git status'
  [ "$status" -eq 0 ]
}
