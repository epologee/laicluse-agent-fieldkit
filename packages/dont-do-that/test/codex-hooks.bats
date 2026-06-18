#!/usr/bin/env bats

SOURCE="$BATS_TEST_DIRNAME/../hooks/hooks.codex.json"
GENERATED="$BATS_TEST_DIRNAME/../../../.agents/plugins/generated/dont-do-that/hooks/hooks.json"
DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"
REGISTRY="$BATS_TEST_DIRNAME/../hooks/guards.json"

stop_payload() {
  jq -cn --arg t "$1" '{hook_event_name:"Stop", last_assistant_message:$t, stop_hook_active:false}'
}

@test "Codex hook manifest signals DD_AGENT=codex on every event" {
  jq -e '.hooks.PreToolUse[].hooks[].command | contains("DD_AGENT=codex")' "$SOURCE" > /dev/null
  jq -e '.hooks.PostToolUse[].hooks[].command | contains("DD_AGENT=codex")' "$SOURCE" > /dev/null
  jq -e '.hooks.Stop[].hooks[].command | contains("DD_AGENT=codex")' "$SOURCE" > /dev/null
  jq -e '.hooks.Stop[].hooks[].command | contains("DD_AGENT=codex")' "$GENERATED" > /dev/null
}

@test "Codex manifest no longer carries the ad hoc DD_SKIP_STOP_GUARDS hack" {
  ! grep -q 'DD_SKIP_STOP_GUARDS' "$SOURCE"
  ! grep -q 'DD_SKIP_STOP_GUARDS' "$GENERATED"
}

@test "Registry is the source of truth: premature is disabled for codex, enabled for claude" {
  [ "$(jq -r '.guards.premature.agents.codex' "$REGISTRY")" = "disabled" ]
  [ "$(jq -r '.guards.premature.agents.claude' "$REGISTRY")" = "enabled" ]
}

@test "Codex hook manifest keeps Stop and the tool guards" {
  jq -e '.hooks.Stop | length > 0' "$SOURCE" > /dev/null
  jq -e '.hooks.PreToolUse | length > 0' "$SOURCE" > /dev/null
  jq -e '.hooks.PostToolUse | length > 0' "$SOURCE" > /dev/null
  jq -e '.hooks.Stop | length > 0' "$GENERATED" > /dev/null
  jq -e '.hooks.PreToolUse | length > 0' "$GENERATED" > /dev/null
  jq -e '.hooks.PostToolUse | length > 0' "$GENERATED" > /dev/null
}

@test "Codex agent suppresses premature" {
  payload="$(stop_payload "Klaar.")"

  run bash -c 'printf "%s" "$1" | DD_AGENT=codex bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 0 ]
  [[ "$output" != *"[dont-do-that/premature]"* ]]
  [[ "$output" != *'"decision":"block"'* ]]
}

@test "Codex agent still lets other Stop guards fire" {
  payload="$(stop_payload "De wijziging staat in het bestand. Check of het werkt. 🏁")"

  run bash -c 'printf "%s" "$1" | DD_AGENT=codex bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"[dont-do-that/verify]"* ]]
}
