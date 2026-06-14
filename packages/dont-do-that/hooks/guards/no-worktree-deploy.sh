#!/bin/bash
# PreToolUse:Bash guard. Blocks ansible-playbook from a git worktree (allow-comment: non-obvious detection via git-dir vs git-common-dir; future readers need the rationale to recognise the canonical worktree marker).

guard_no_worktree_deploy() {
  local input="$1"
  local cmd cwd
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  cwd=$(jq -r '.cwd // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0
  [ -z "$cwd" ] && cwd="$PWD"

  grep -Eq '^[[:space:]]*git([[:space:]]|$)' <<< "$cmd" && return 0

  grep -Eq '(^|[[:space:]]|;|&&|\|\|)ansible-playbook([[:space:]]|$)' <<< "$cmd" || return 0

  grep -Eq '(^|[[:space:]])(--check|--syntax-check|--version|--help|--list-tasks|--list-hosts|--list-tags|-h)([[:space:]=]|$)' <<< "$cmd" && return 0

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
    local main_root
    main_root=$(dirname "$cgd")
    dd_emit_deny no-worktree-deploy "ansible-playbook blocked: working dir is a git worktree, not the production checkout. Deploys land from the canonical checkout ($main_root) after the branch has merged. Use --check / --syntax-check from a worktree for previews only."
  fi
}
