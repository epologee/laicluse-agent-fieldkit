#!/bin/bash
# PostToolUse guard. Surfaces additionalContext when em-dash (U+2014) or
# en-dash (U+2013) appears in persisted content or a Bash command. Chat-only
# text is not checked.

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
    Bash)
      content=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
      source="bash command"
      ;;
    apply_patch)
      content=$(dd_dash_patch_additions "$(dd_tool_patch "$input")")
      source="apply_patch additions"
      ;;
    *) return 0 ;;
  esac
  [ -z "$content" ] && return 0

  local dash_class
  dash_class=$(printf '[\xe2\x80\x94\xe2\x80\x93]')
  local violation
  violation=$(awk -v pat="$dash_class" '
    /^```/ { in_code = !in_code; next }
    in_code { next }
    $0 ~ pat { print NR": "$0; exit }
  ' <<< "$content")

  [ -z "$violation" ] && return 0
  dd_emit_context dash "Em/en-dash in ${source}:${violation}. Em-dashes read as machine-authored; in legal, formal, or customer-facing copy (terms, contracts, client messages) that is a tell to remove entirely. Rewrite using a comma, colon, period, or parentheses."
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
