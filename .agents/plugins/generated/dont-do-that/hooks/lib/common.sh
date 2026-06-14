#!/bin/bash
# Shared library for the dont-do-that dispatcher and its guard functions.
# Sourced by dispatch.sh and guards/*.sh; never executed directly.
#
# Public helpers:
#   dd_event          - hook event from input JSON
#   dd_tool_name      - tool name from input JSON
#   dd_tool_patch     - patch/diff payload from input JSON
#   dd_stop_active    - 0/1 based on stop_hook_active
#   dd_session_id     - session id from input JSON
#   dd_transcript     - transcript path, resolving session fallback
#   dd_state_file     - per-session guard state under LAICLUSE_HOME
#   dd_assistant_text - last-turn assistant text, optional line-tracking
#   dd_is_wip         - 0 if the assistant text contains 🚧
#   dd_emit_block     - Stop-style block JSON with mnemonic prefix
#   dd_emit_deny      - PreToolUse stderr + exit 2, mnemonic prefix
#   dd_emit_context   - PostToolUse additionalContext JSON, mnemonic prefix
#
# Every emit helper prefixes the message with "[dont-do-that/<mnemonic>] ".
# That prefix is the stable code the operator and agent can recognise at a
# glance without reading the whole reason.

dd_event() {
  jq -r '.hook_event_name // empty' <<< "$1" 2>/dev/null
}

dd_tool_name() {
  jq -r '.tool_name // empty' <<< "$1" 2>/dev/null
}

dd_tool_patch() {
  jq -r '
    if (.tool_input | type) == "string" then
      .tool_input
    else
      .tool_input.patch
      // .tool_input.diff
      // .tool_input.input
      // .tool_input.command
      // .tool_input.content
      // .tool_input.cmd
      // empty
    end
  ' <<< "$1" 2>/dev/null
}

dd_stop_active() {
  local v
  v=$(jq -r '.stop_hook_active // false' <<< "$1" 2>/dev/null)
  [ "$v" = "true" ]
}

dd_session_id() {
  jq -r '.session_id // .sessionId // empty' <<< "$1" 2>/dev/null
}

dd_transcript() {
  local input="$1"
  local t
  t=$(jq -r '.transcript_path // empty' <<< "$input" 2>/dev/null)
  if [ -n "$t" ] && [ -f "$t" ]; then
    echo "$t"
    return 0
  fi
  local sid
  sid=$(dd_session_id "$input")
  [ -z "$sid" ] && return 1
  local base found
  for base in "$HOME/.claude/projects" "$HOME/.codex/sessions"; do
    [ -d "$base" ] || continue
    found=$(find "$base" -name "${sid}.jsonl" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
      echo "$found"
      return 0
    fi
  done
  return 1
}

dd_state_file() {
  local name="$1" sid="$2"
  [ -n "$name" ] || return 1
  [ -n "$sid" ] || return 1

  local root safe
  root="${LAICLUSE_HOME:-$HOME/.laicluse}/dont-do-that/state"
  mkdir -p "$root" 2>/dev/null || return 1
  safe=$(printf '%s' "$sid" | tr -c 'A-Za-z0-9._-' '_')
  printf '%s/%s-%s\n' "$root" "$name" "$safe"
}

dd_is_wip() {
  grep -q '🚧' <<< "$1"
}

# dd_assistant_text <input-json> <char-budget> [guard-name]
# Returns the tail of the current turn's assistant text.
# When guard-name is set, tracks last-seen transcript line count under
# ${LAICLUSE_HOME:-~/.laicluse}/dont-do-that/state/, scanning only new lines. This matches
# the pre-refactor behavior of the individual scripts.
dd_assistant_text() {
  local input="$1"
  local chars="${2:-1000}"
  local guard="${3:-}"

  local msg
  msg=$(jq -r '.last_assistant_message // empty' <<< "$input" 2>/dev/null)
  if [ -n "$msg" ]; then
    echo "$msg" | tail -c "$chars"
    return 0
  fi

  local sid
  sid=$(dd_session_id "$input")
  [ -z "$sid" ] && return 1

  local tr
  tr=$(dd_transcript "$input")
  [ -z "$tr" ] || [ ! -f "$tr" ] && return 1

  local tail_lines=50
  if [ -n "$guard" ]; then
    local line_file
    line_file=$(dd_state_file "$guard" "$sid") || return 1
    local total last
    total=$(wc -l < "$tr" | tr -d ' ')
    if [ -f "$line_file" ]; then
      last=$(cat "$line_file")
    else
      last=$((total > 30 ? total - 30 : 0))
    fi
    echo "$total" > "$line_file"
    tail_lines=$((total - last))
    [ "$tail_lines" -le 0 ] && return 1
  fi

  tail -"$tail_lines" "$tr" \
    | jq -s -r '
        . as $all
        | ([$all | to_entries[] | select(.value.type == "user") | .key] | last // -1) as $lu
        | $all[$lu + 1:]
        | map(select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text)
        | join("\n")
      ' 2>/dev/null \
    | tail -c "$chars"
}

# dd_emit_block <mnemonic> <message>
# Stop hook: print one-line JSON and exit 0. The reason carries the mnemonic
# prefix so the transcript shows e.g. [dont-do-that/cache] Cache is ...
dd_emit_block() {
  local mnemonic="$1"
  local msg="$2"
  jq -cn --arg r "[dont-do-that/${mnemonic}] ${msg}" '{decision:"block", reason:$r}'
  exit 0
}

# dd_emit_deny <mnemonic> <message>
# PreToolUse hook: print one-line stderr and exit 2 (blocks the tool).
dd_emit_deny() {
  local mnemonic="$1"
  local msg="$2"
  printf '[dont-do-that/%s] %s\n' "$mnemonic" "$msg" >&2
  exit 2
}

# dd_emit_context <mnemonic> <message>
# PostToolUse hook: print additionalContext JSON (does not block, surfaces text).
dd_emit_context() {
  local mnemonic="$1"
  local msg="$2"
  jq -cn --arg c "[dont-do-that/${mnemonic}] ${msg}" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
}

# dd_emit_pre_context <mnemonic> <message>
# PreToolUse hook: print additionalContext JSON (does not block, surfaces text
# to the agent in the next turn so it can adjust subsequent calls).
dd_emit_pre_context() {
  local mnemonic="$1"
  local msg="$2"
  jq -cn --arg c "[dont-do-that/${mnemonic}] ${msg}" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
}
