#!/bin/bash

source "$DIR/guards/dash.sh"

guard_dash_bash() {
  local input="$1" content violation
  content=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$content" ] && return 0

  violation=$(dd_literal_dash_violation "$content")
  [ -z "$violation" ] && return 0
  dd_emit_deny dash-bash "Em/en-dash in bash command:${violation}. Rewrite the command before it runs using a comma, colon, period, or parentheses."
}
