#!/bin/bash
# PreToolUse:Bash guard. Denies gh api POSTs whose body contains deferral
# phrases ("follow-up", "wordt opgepakt", "buiten scope", ...) unless the
# body starts with "Bewust uitgesteld:" (deliberate deferral escape token).
# Passed: guard_followup "$INPUT_JSON"

guard_followup() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [[ "$command" =~ (^|[^A-Za-z0-9_/.-])gh[[:space:]]+api([[:space:]]|$) ]] || return 0
  [[ "$command" =~ (--field|--raw-field|-f|-F)[[:space:]]+body= || \
     "$command" =~ --input[[:space:]] ]] || return 0

  local body_lower
  body_lower=$(echo "$command" | tr '[:upper:]' '[:lower:]')
  local patterns=(
    "follow-up" "follow up" "wordt opgepakt" "opgepakt als"
    "buiten scope" "niet in scope" "in een volgende pr" "latere pr"
    "toekomstige pr" "aparte pr" "los issue"
  )
  local p
  for p in "${patterns[@]}"; do
    case "$body_lower" in
      *"$p"*)
        case "$command" in
          *"Bewust uitgesteld:"*) return 0 ;;
        esac
        dd_emit_deny followup "Deferral language ('$p') without approval. Prefix 'Bewust uitgesteld:' or fix it now."
        ;;
    esac
  done
  return 0
}
