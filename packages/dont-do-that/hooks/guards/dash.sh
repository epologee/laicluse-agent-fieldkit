#!/bin/bash
# allow-comment: PostToolUse guard for em/en-dashes in persisted content; shell commands are denied before execution by dash-bash.

guard_dash() {
  local input="$1"
  local tool content source
  tool=$(jq -r '.tool_name // empty' <<< "$input" 2>/dev/null)
  case "$tool" in
    Edit)
      content=$(jq -r '.tool_input.new_string // empty' <<< "$input" 2>/dev/null)
      source=$(jq -r '.tool_input.file_path // "unknown file"' <<< "$input" 2>/dev/null)
      ;;
    Write)
      content=$(jq -r '.tool_input.content // empty' <<< "$input" 2>/dev/null)
      source=$(jq -r '.tool_input.file_path // "unknown file"' <<< "$input" 2>/dev/null)
      ;;
    MultiEdit)
      content=$(jq -r '.tool_input.edits[]?.new_string // empty' <<< "$input" 2>/dev/null)
      source=$(jq -r '.tool_input.file_path // "unknown file"' <<< "$input" 2>/dev/null)
      ;;
    apply_patch)
      content=$(dd_dash_patch_additions "$(dd_tool_patch "$input")")
      source="apply_patch additions"
      ;;
    *) return 0 ;;
  esac
  [ -z "$content" ] && return 0

  local violation
  violation=$(dd_dash_violation "$content")

  [ -z "$violation" ] && return 0
  dd_emit_context dash "Em/en-dash in ${source}:${violation}. Em-dashes read as machine-authored; in legal, formal, or customer-facing copy (terms, contracts, client messages) that is a tell to remove entirely. Rewrite using a comma, colon, period, or parentheses."
}

dd_dash_violation() {
  local content="$1" em_dash en_dash dash_entity_pattern
  em_dash=$(printf '\xe2\x80\x94')
  en_dash=$(printf '\xe2\x80\x93')
  dash_entity_pattern='(&mdash;|&ndash;|&#821[12];|&#[xX]201[34];)'
  awk -v em_dash="$em_dash" -v en_dash="$en_dash" -v entity_pat="$dash_entity_pattern" '
    /^```/ { in_code = !in_code; next }
    in_code { next }
    index($0, em_dash) || index($0, en_dash) || $0 ~ entity_pat { print NR": "$0; exit }
  ' <<< "$content"
}

dd_literal_dash_violation() {
  local content="$1" em_dash en_dash
  em_dash=$(printf '\xe2\x80\x94')
  en_dash=$(printf '\xe2\x80\x93')
  awk -v em_dash="$em_dash" -v en_dash="$en_dash" '
    index($0, em_dash) || index($0, en_dash) { print NR": "$0; exit }
  ' <<< "$content"
}

dd_dash_patch_additions() {
  local patch="$1" line out=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "+++ "*) continue ;;
      "+"*) out+="${line#+}"$'\n' ;;
    esac
  done <<< "$patch"
  printf '%s' "$out"
}
