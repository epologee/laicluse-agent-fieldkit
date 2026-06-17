#!/usr/bin/env bats

SOURCE="$BATS_TEST_DIRNAME/../hooks/hooks.codex.json"
GENERATED="$BATS_TEST_DIRNAME/../../../.agents/plugins/generated/dont-do-that/hooks/hooks.json"
DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

stop_payload() {
  jq -cn --arg t "$1" '{hook_event_name:"Stop", last_assistant_message:$t, stop_hook_active:false}'
}

@test "Codex hook manifest keeps Stop but skips premature only" {
  jq -e '.hooks.Stop | length > 0' "$SOURCE" > /dev/null
  jq -e '.hooks.Stop | length > 0' "$GENERATED" > /dev/null
  jq -e '.hooks.Stop[].hooks[].command | contains("DD_SKIP_STOP_GUARDS=premature")' "$SOURCE" > /dev/null
  jq -e '.hooks.Stop[].hooks[].command | contains("DD_SKIP_STOP_GUARDS=premature")' "$GENERATED" > /dev/null
}

@test "Codex hook manifest keeps tool guards" {
  jq -e '.hooks.PreToolUse | length > 0' "$SOURCE" > /dev/null
  jq -e '.hooks.PostToolUse | length > 0' "$SOURCE" > /dev/null
  jq -e '.hooks.PreToolUse | length > 0' "$GENERATED" > /dev/null
  jq -e '.hooks.PostToolUse | length > 0' "$GENERATED" > /dev/null
}

@test "Codex Stop skip suppresses premature" {
  payload="$(stop_payload "Klaar.")"

  run bash -c 'printf "%s" "$1" | DD_SKIP_STOP_GUARDS=premature bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 0 ]
  [[ "$output" != *"[dont-do-that/premature]"* ]]
  [[ "$output" != *'"decision":"block"'* ]]
}

@test "Codex Stop skip still lets other Stop guards fire" {
  payload="$(stop_payload "De wijziging staat in het bestand. Check of het werkt. 🏁")"

  run bash -c 'printf "%s" "$1" | DD_SKIP_STOP_GUARDS=premature bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"[dont-do-that/verify]"* ]]
}
