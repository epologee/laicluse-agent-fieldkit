#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

pre_bash_payload() {
  jq -cn --arg cwd "$1" --arg cmd "$2" --arg user "$3" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, last_user_message:$user, tool_input:{command:$cmd}}'
}

@test "plugin mutation guard blocks machine-wide Codex activation without current approval" {
  payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "codex plugin add dibs@example" "Merge the plugin worktree")"

  run bash -c 'printf "%s" "$1" | DD_AGENT=codex DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 2 ]
  [[ "$output" == *"machine-wide plugin mutation blocked"* ]]
}

@test "plugin mutation guard allows an explicitly approved Codex activation" {
  payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "codex plugin add dibs@example" "Run codex plugin add for dibs now")"

  run bash -c 'printf "%s" "$1" | DD_AGENT=codex DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "plugin mutation guard reads current approval from a Codex transcript" {
  transcript="$BATS_TEST_TMPDIR/codex.jsonl"
  jq -cn '{type:"response_item", payload:{type:"message", role:"user", content:[{type:"input_text", text:"Update the Claude plugins now"}]}}' > "$transcript"
  payload="$(jq -cn --arg cwd "$BATS_TEST_TMPDIR" --arg transcript "$transcript" '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, transcript_path:$transcript, tool_input:{command:"claude plugins update dibs@example"}}')"

  run bash -c 'printf "%s" "$1" | DD_AGENT=codex DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "plugin mutation guard blocks Claude plugin updates without current approval" {
  payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "claude plugins update dibs@example" "Finish the source change")"

  run bash -c 'printf "%s" "$1" | DD_AGENT=claude DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 2 ]
  [[ "$output" == *"machine-wide plugin mutation blocked"* ]]
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
    run bash -c 'printf "%s" "$1" | DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"
    [ "$status" -eq 2 ]
    [[ "$output" == *"machine-wide plugin mutation blocked"* ]]
  done
}

@test "plugin mutation guard rejects a negated plugin instruction as approval" {
  payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "codex plugin add dibs@example" "Do not update or reinstall the plugin; merge the worktree")"

  run bash -c 'printf "%s" "$1" | DD_AGENT=codex DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 2 ]
  [[ "$output" == *"machine-wide plugin mutation blocked"* ]]
}

@test "plugin mutation guard does not block read-only plugin inspection" {
  payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "codex plugin list --json" "Inspect the plugin state")"

  run bash -c 'printf "%s" "$1" | DD_AGENT=codex DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
