#!/bin/bash
# Stop guard. Blocks pre-existing / already-broken / known-issue rationalisations.
# Always runs, even when an earlier guard in the same fire blocked
# (it keeps its own per-session line-tracking state).

guard_false_claims() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 2000 "false-claims")
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0

  local filtered
  filtered=$(echo "$text" \
    | sed -E 's/false[_-]claims[_-]guard//gi' \
    | sed -E 's/pre-existing[_-]trap[_-]guard//gi' \
    | sed -E 's/pre-existing-trap//gi' \
    | sed -E 's/`pre-existing`//gi' \
    | sed -E 's/`(known issue|bekende bug|already fail[a-z]*)`//gi')

  echo "$filtered" \
    | grep -qiE "pre-existing (failure|test|error|bug|issue|problem)|bestond(en)? al|reeds bestaand|al bestaand|niet gerelateerd aan (deze|mijn|onze) wijziging|known (issue|bug|flak)|bekende (bug|fout|issue)|was al (stuk|kapot|broken)|already fail" \
    || return 0

  dd_emit_block pre-existing "Boy Scout rule: fix it. Exception: parallel work in the same directory (formulate it that way)."
}
