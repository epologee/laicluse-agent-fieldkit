#!/bin/bash
# allow-comment: Stop guard. Blocks coined approval-gate "-go" compounds (push-go, ship-go, raw user-go) in operator-facing text; pass by backticking the term, prefixing the WIP marker, or phrasing it plainly. See test/smoke-test.sh "jargon:" cases.

guard_jargon() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 2000 "jargon")
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0

  local filtered
  filtered=$(echo "$text" | awk '/^```/ { in_fence = !in_fence; next } !in_fence')
  filtered=$(echo "$filtered" | sed -E 's/`[^`]*`//g; s/\[dont-do-that\/jargon\]//g')

  if grep -qiE "\b(push|ship|merge|deploy|commit|release|publish|send|post|launch|user|yolo|approval)-go\b" <<< "$filtered"; then
    dd_emit_block jargon "Coined approval-gate jargon ('-go' compound) in operator-facing text. The '-go' suffix is internal instruction-vocabulary; do not glue it onto a verb. Say it plainly: 'waiting for your go to push' / 'ik push zodra je het zegt', not the glued form. To name the term itself, wrap it in backticks."
  fi
  return 0
}
