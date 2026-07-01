#!/usr/bin/env bats
# Registry-driven dispatch and validation. Proves the registry is the source of
# truth for which guard runs on which event for which agent, and that the
# validator rejects impossible placements.

DDROOT="$BATS_TEST_DIRNAME/.."
REGISTRY="$DDROOT/hooks/guards.json"
DISPATCH="$DDROOT/hooks/dispatch.sh"
VALIDATE="$DDROOT/bin/validate-registry"

stop_payload() {
  jq -cn --arg t "$1" '{hook_event_name:"Stop", last_assistant_message:$t, stop_hook_active:false}'
}

posttool_edit() {
  jq -cn --arg f "$1" --arg c "$2" \
    '{hook_event_name:"PostToolUse", tool_name:"Edit", tool_input:{file_path:$f, new_string:$c}}'
}

@test "validator passes on the real registry" {
  run bash "$VALIDATE"
  [ "$status" -eq 0 ]
}

@test "validator rejects a Stop-contract guard placed on a PostToolUse lane" {
  tmp="$(mktemp)"
  jq '.guards.premature.lane = "post"' "$REGISTRY" > "$tmp"
  run bash "$VALIDATE" "$tmp"
  rm -f "$tmp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not provided by event PostToolUse"* ]]
}

@test "validator rejects an unknown agent policy value" {
  tmp="$(mktemp)"
  jq '.guards.dash.agents.codex = "maybe"' "$REGISTRY" > "$tmp"
  run bash "$VALIDATE" "$tmp"
  rm -f "$tmp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"enabled or disabled"* ]]
}

@test "validator rejects two guards sharing a function name" {
  tmp="$(mktemp)"
  jq '.guards.dash.function = "guard_land"' "$REGISTRY" > "$tmp"
  run bash "$VALIDATE" "$tmp"
  rm -f "$tmp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"guard_land"* ]]
}

@test "validator rejects a guard with no backing script" {
  tmp="$(mktemp)"
  jq '.guards.ghost = {lane:"stop-mutex", order:99, function:"guard_ghost", contract:"final-answer", agents:{}}' "$REGISTRY" > "$tmp"
  run bash "$VALIDATE" "$tmp"
  rm -f "$tmp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ghost"* ]]
}

@test "PreToolUse fails closed when the registry is missing" {
  payload="$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:"echo hi"}}')"
  run bash -c 'printf "%s" "$1" | DD_REGISTRY=/nonexistent/guards.json bash "$2"' _ "$payload" "$DISPATCH"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[dont-do-that/registry]"* ]]
}

@test "PreToolUse fails closed when the registry is malformed" {
  tmp="$(mktemp)"
  printf '%s' '{ "guards": {' > "$tmp"
  payload="$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:"echo hi"}}')"
  run bash -c 'printf "%s" "$1" | DD_REGISTRY="$3" bash "$2"' _ "$payload" "$DISPATCH" "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[dont-do-that/registry]"* ]]
}

@test "PreToolUse passes through when the registry is valid" {
  payload="$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:"echo hi"}}')"
  run bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload" "$DISPATCH"
  [ "$status" -eq 0 ]
}

@test "registry order wins within a lane: dash (order 10) beats land (order 20)" {
  emdash="$(printf '\xe2\x80\x94')"
  payload="$(posttool_edit "/tmp/x.md" "We land the change ${emdash} here")"
  run bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload" "$DISPATCH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dont-do-that/dash]"* ]]
  [[ "$output" != *"[dont-do-that/land]"* ]]
}

@test "Stop lanes fail open on a corrupt registry (deliberate asymmetry vs PreToolUse)" {
  tmp="$(mktemp)"
  printf '%s' '{ "guards": {' > "$tmp"
  payload="$(stop_payload "Klaar 🏁")"
  run bash -c 'printf "%s" "$1" | DD_REGISTRY="$3" bash "$2"' _ "$payload" "$DISPATCH" "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "registry guard count matches guards/*.sh files" {
  reg=$(jq -r '.guards | length' "$REGISTRY")
  files=$(find "$DDROOT/hooks/guards" -name '*.sh' | wc -l | tr -d ' ')
  [ "$reg" -eq "$files" ]
}

@test "README documents every registered guard" {
  readme="$DDROOT/README.md"
  while IFS= read -r id; do
    grep -q "\`$id\`" "$readme" || {
      echo "README is missing guard: $id" >&2
      return 1
    }
  done < <(jq -r '.guards | keys[]' "$REGISTRY")
}

@test "Codex premature does not block a short completed answer" {
  run bash -c 'printf "%s" "$1" | DD_AGENT=codex bash "$2"' _ "$(stop_payload "Klaar 🏁")" "$DISPATCH"
  [ "$status" -eq 0 ]
  [[ "$output" != *"[dont-do-that/premature]"* ]]
  [[ "$output" != *'"decision":"block"'* ]]
}

@test "Codex verify still blocks verification delegation on Stop" {
  run bash -c 'printf "%s" "$1" | DD_AGENT=codex bash "$2"' _ \
    "$(stop_payload "De wijziging staat in het bestand. Check of het werkt. 🏁")" "$DISPATCH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dont-do-that/verify]"* ]]
}

@test "Codex estimate stays silent even on duration phrasing" {
  run bash -c 'printf "%s" "$1" | DD_AGENT=codex bash "$2"' _ \
    "$(stop_payload "Dat is een paar uur werk. Ik ga verder met de rest. 🏁")" "$DISPATCH"
  [ "$status" -eq 0 ]
  [[ "$output" != *"[dont-do-that/estimate]"* ]]
}

@test "Codex dash still emits from PostToolUse" {
  emdash="$(printf '\xe2\x80\x94')"
  run bash -c 'printf "%s" "$1" | DD_AGENT=codex bash "$2"' _ \
    "$(posttool_edit "/tmp/x.md" "Some prose with ${emdash} dash here")" "$DISPATCH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dont-do-that/dash]"* ]]
  [[ "$output" == *"additionalContext"* ]]
}

@test "Claude runs premature on a short completed answer" {
  run bash -c 'printf "%s" "$1" | DD_AGENT=claude bash "$2"' _ "$(stop_payload "Klaar 🏁")" "$DISPATCH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dont-do-that/premature]"* ]]
}

@test "default agent (no DD_AGENT) runs the full Claude stack" {
  run bash -c 'printf "%s" "$1" | bash "$2"' _ "$(stop_payload "Klaar 🏁")" "$DISPATCH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dont-do-that/premature]"* ]]
}
