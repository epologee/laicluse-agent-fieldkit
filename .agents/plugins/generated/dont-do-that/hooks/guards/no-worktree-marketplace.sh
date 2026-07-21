#!/bin/bash
# PreToolUse:Bash guard. A local marketplace registration persists after a linked worktree is removed, so it must use the canonical checkout.

guard_no_worktree_marketplace() {
  local input="$1"
  local cmd cwd
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  cwd=$(jq -r '.cwd // .tool_input.cwd // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0

  grep -Eq '(^|[;&|[:space:]])(codex[[:space:]]+plugin|claude[[:space:]]+plugin)[[:space:]]+marketplace[[:space:]]+add([[:space:]]|$)' <<< "$cmd" || return 0

  [ -n "$cwd" ] || cwd="$PWD"
  local gd cgd
  gd=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null) || return 0
  cgd=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null) || return 0

  case "$gd" in
    /*) ;;
    *) gd="$(cd "$cwd" && cd "$gd" && pwd)" ;;
  esac
  case "$cgd" in
    /*) ;;
    *) cgd="$(cd "$cwd" && cd "$cgd" && pwd)" ;;
  esac

  if [ "$gd" != "$cgd" ]; then
    dd_emit_deny no-worktree-marketplace "marketplace registration blocked: this is a linked git worktree. A local marketplace source persists beyond this worktree and will break every agent after cleanup. Register the canonical checkout ($(dirname "$cgd")) or use the remote marketplace source."
  fi
}
