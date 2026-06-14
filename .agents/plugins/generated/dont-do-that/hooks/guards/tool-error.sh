#!/bin/bash
# Stop guard. Blocks Stop when the last significant event was a failed
# tool call. Max 2 nudges per session plus LINE_FILE tracking so we only
# fire on NEW errors. Runs even when stop_hook_active is true (nudge must
# still fire when a prior Stop hook blocked first).

guard_tool_error() {
  local input="$1"
  local sid
  sid=$(dd_session_id "$input")
  [ -z "$sid" ] && return 0

  local tr
  tr=$(dd_transcript "$input")
  [ -z "$tr" ] || [ ! -f "$tr" ] && return 0

  local nudge_file line_file
  nudge_file=$(dd_state_file "nudge-error" "$sid") || return 0
  line_file=$(dd_state_file "nudge-error-line" "$sid") || return 0
  local count=0
  [ -f "$nudge_file" ] && count=$(cat "$nudge_file")
  [ "$count" -ge 2 ] 2>/dev/null && return 0

  local current last
  current=$(wc -l < "$tr" | tr -d ' ')
  last=0
  [ -f "$line_file" ] && last=$(cat "$line_file")
  [ "$current" -le "$last" ] && return 0

  local new=$((current - last))
  local scan=$((new > 30 ? new : 30))
  local tail_status
  tail_status=$(tail -"$scan" "$tr" | awk '
    /"is_error"[[:space:]]*:[[:space:]]*true/    { last = "ERROR" }
    /Exit code [1-9]/                             { last = "ERROR" }
    /"type"[[:space:]]*:[[:space:]]*"tool_use"/   { last = "TOOL_USE" }
    END { print last }
  ')

  if [ "$tail_status" != "ERROR" ]; then
    echo "$current" > "$line_file"
    return 0
  fi

  echo "$((count + 1))" > "$nudge_file"
  echo "$current" > "$line_file"
  dd_emit_block tool-error "Last tool call failed. Diagnose before reacting. A denial (auto-mode classifier, settings rule, user-prompt deny) is information about the harness, not a message from the user; the user may be AFK. Do not narrate user intent from it ('je verifieert zelf', 'je wil dit niet'). That is talking to yourself."
}
