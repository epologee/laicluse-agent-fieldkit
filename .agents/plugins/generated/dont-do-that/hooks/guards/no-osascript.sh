#!/bin/bash

guard_no_osascript() {
  local input="$1"
  local cmd
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0

  local prefix='(^|[;&|({]|[$][(])[[:space:]]*'
  local assignments='([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*'
  local wrappers='((command|exec|nohup|sudo|doas|arch)([[:space:]]+-[^[:space:]]+)*[[:space:]]+|env([[:space:]]+-[^[:space:]]+|[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+)*[[:space:]]+)*'
  local target='([[:alnum:]_.\/-]+\/)?osascript([[:space:]]|$)'

  if grep -Eq "${prefix}${assignments}${wrappers}${target}" <<< "$cmd"; then
    dd_emit_deny no-osascript "osascript blocked: AppleScript execution can drive local apps and user-facing system state invisibly. Use an explicit host-owned UI/browser capability or a project-native command path instead."
  fi
}
