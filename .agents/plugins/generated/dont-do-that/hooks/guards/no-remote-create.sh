#!/bin/bash
# PreToolUse:Bash guard that blocks remote-create patterns (gh repo create, gh repo fork, git remote add, git remote set-url). allow-comment: hook-header documenting the matchers and the operator escape, same pattern as sibling no-remote.sh and no-worktree-deploy.sh in this directory. Remote creation is operator territory: spinning up an account-bound repository or rewiring the local repo carries permission, billing, visibility and team implications the model cannot reason about. Operator escape is the REPL `!` prefix.

guard_no_remote_create() {
  local input="$1"
  local cmd
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0

  if grep -Eq '(^|&&|;|\|\||[[:space:]])[[:space:]]*gh[[:space:]]+repo[[:space:]]+(create|fork)([[:space:]]|$)' <<< "$cmd"; then
    dd_emit_deny no-remote-create "remote creation blocked: 'gh repo create' / 'gh repo fork' spins up an account-bound repository on the forge; that is an operator decision. Ask the operator to run it themselves with the '!' prefix, or to create the repo in the browser and tell you the URL."
  fi

  if grep -Eq '(^|&&|;|\|\||[[:space:]])[[:space:]]*git[[:space:]]+remote[[:space:]]+(add|set-url)([[:space:]]|$)' <<< "$cmd"; then
    dd_emit_deny no-remote-create "remote attach blocked: 'git remote add' / 'git remote set-url' rewires the local repo to a remote the operator may not have authorized. Ask the operator to run it themselves with the '!' prefix."
  fi
}
