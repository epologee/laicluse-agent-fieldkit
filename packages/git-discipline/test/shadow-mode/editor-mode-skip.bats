#!/usr/bin/env bats
# editor-mode-skip.bats
# "git commit" without a -m flag (editor-mode) must be ignored by the
# commit-body guard. commit-format.sh handles editor-mode separately.

load helpers

@test "git commit without -m skips silently in laicluse-agent-fieldkit repo" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/epologee/laicluse-agent-fieldkit.git"
  export GIT_SHIM_SHORTSTAT=" 5 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb\nc.rb\nd.rb\ne.rb')"

  local before
  before=$(shadow_log_line_count)

  # Plain "git commit" with no message flag.
  # commit-subject guard will deny this with "Pass inline" but we want to
  # confirm commit-body does not add its own context before that happens.
  # We check no commit-body context appears in the output.
  run bash "$DISPATCH" <<< \
    '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit"}}'

  # commit-subject guard blocks editor-mode (exit 2); that is expected.
  # What we assert: commit-body does NOT appear in either stdout or stderr.
  [[ "$output" != *'commit-body'* ]]

  # No shadow log entry from commit-body.
  local after
  after=$(shadow_log_line_count)
  [ "$after" -eq "$before" ]
}

@test "git commit --amend without -m also skips body guard silently" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/epologee/laicluse-agent-fieldkit.git"

  local before
  before=$(shadow_log_line_count)

  run bash "$DISPATCH" <<< \
    '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit --amend"}}'

  [[ "$output" != *'commit-body'* ]]
  local after
  after=$(shadow_log_line_count)
  [ "$after" -eq "$before" ]
}
