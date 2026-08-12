#!/bin/bash
# PreToolUse:Bash guard. A local marketplace registration persists after a linked worktree is removed, so it must use the canonical checkout.

guard_no_worktree_marketplace() {
  local input="$1"
  local cmd cwd source_pattern source cd_pattern
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  cwd=$(jq -r '.cwd // .tool_input.cwd // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0

  source_pattern="(^|[;&|[:space:]])(codex[[:space:]]+plugin|claude[[:space:]]+plugins?)[[:space:]]+marketplace[[:space:]]+add[[:space:]]+(\"[^\"]+\"|'[^']+'|[^;&|[:space:]]+)"
  [[ "$cmd" =~ $source_pattern ]] || return 0
  source="${BASH_REMATCH[3]}"
  source="$(sed -E "s/^[\"']//; s/[\"']$//" <<< "$source")"

  [ -n "$cwd" ] || cwd="$PWD"
  cd_pattern="^[[:space:]]*cd[[:space:]]+(\"[^\"]+\"|'[^']+'|[^[:space:]&]+)[[:space:]]*&&"
  if [[ "$cmd" =~ $cd_pattern ]]; then
    cwd="${BASH_REMATCH[1]}"
    cwd="$(sed -E "s/^[\"']//; s/[\"']$//" <<< "$cwd")"
  fi
  cwd="${cwd/#\~/$HOME}"
  source="${source/#\~/$HOME}"
  case "$source" in
    /*) ;;
    *) source="$cwd/$source" ;;
  esac
  [ -d "$source" ] || return 0

  local gd cgd
  gd=$(git -C "$source" rev-parse --absolute-git-dir 2>/dev/null) || return 0
  cgd=$(git -C "$source" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 0

  if [ "$gd" != "$cgd" ]; then
    dd_emit_deny no-worktree-marketplace "marketplace registration blocked: the local source is a linked git worktree. Persistent marketplace sources may only use the canonical checkout ($(dirname "$cgd")); a remote marketplace source is also safe."
  fi
}
