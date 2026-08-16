#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

pre_bash_payload() {
  jq -cn --arg cwd "$1" --arg cmd "$2" --arg user "$3" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, last_user_message:$user, tool_input:{command:$cmd}}'
}

@test "plugin mutation guard asks the operator through the Claude permission prompt" {
  payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "claude plugins update dibs@example" "Finish the source change")"

  run bash -c 'printf "%s" "$1" | DD_AGENT=claude DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$output")" = "ask" ]
  [ "$(jq -r '.hookSpecificOutput.hookEventName' <<< "$output")" = "PreToolUse" ]
  [[ "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<< "$output")" == *"machine-wide plugin mutation"* ]]
}

@test "plugin mutation guard asks regardless of how the operator phrased the turn" {
  phrasings=(
    "werk de plugins in de Claude runtime bij"
    "update the plugins now"
    "raak de plugins niet aan"
    ""
  )

  for phrasing in "${phrasings[@]}"; do
    payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "claude plugins update dibs@example" "$phrasing")"
    run bash -c 'printf "%s" "$1" | DD_AGENT=claude DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"
    [ "$status" -eq 0 ]
    [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$output")" = "ask" ]
  done
}

@test "plugin mutation guard denies on an agent without an ask channel" {
  payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "codex plugin add dibs@example" "Run codex plugin add for dibs now")"

  run bash -c 'printf "%s" "$1" | DD_AGENT=codex DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 2 ]
  [[ "$output" == *"machine-wide plugin mutation"* ]]
}

@test "plugin mutation guard denies when no agent signalled an ask channel" {
  payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "claude plugins update dibs@example" "Update the plugins now")"

  run bash -c 'printf "%s" "$1" | env -u DD_AGENT DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 2 ]
  [[ "$output" == *"machine-wide plugin mutation"* ]]
}

@test "plugin mutation guard covers marketplace, removal, and wrapped mutations" {
  commands=(
    "codex plugin marketplace upgrade example"
    "codex plugin remove dibs@example"
    "command codex plugin disable dibs@example"
    "claude plugin marketplace add /tmp/example"
    "claude plugins uninstall dibs@example"
    "env LANG=en_US.UTF-8 claude plugins enable dibs@example"
  )

  for command in "${commands[@]}"; do
    payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "$command" "Inspect the plugin state")"
    run bash -c 'printf "%s" "$1" | DD_AGENT=claude DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"
    [ "$status" -eq 0 ]
    [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$output")" = "ask" ]
  done
}

@test "plugin mutation guard does not block read-only plugin inspection" {
  payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "codex plugin list --json" "Inspect the plugin state")"

  run bash -c 'printf "%s" "$1" | DD_AGENT=codex DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
