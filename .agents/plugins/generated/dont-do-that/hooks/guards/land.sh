#!/bin/bash
# allow-comment: PostToolUse guard. Soft nudge (never blocks) when the vague "land" metaphor appears in persisted content; mirrors the dash guard's shape and reuses its patch-additions helper.

guard_land() {
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
  violation=$(awk '
    /^```/ { in_code = !in_code; next }
    in_code { next }
    tolower($0) ~ /land/ { print NR": "$0; exit }
  ' <<< "$content")

  [ -z "$violation" ] && return 0
  dd_emit_context land "Possible vague \"land\" metaphor in ${source}:${violation}. If it is literal or domain language, leave it; otherwise it names nothing concrete, so say what actually happens here in whatever word fits."
}
