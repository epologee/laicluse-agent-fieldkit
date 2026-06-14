#!/bin/bash
# PreToolUse:Bash guard. Blocks `git push` when the current repo has no
# remote configured (or the targeted remote is missing). Push to a repo
# without a remote is always unintended; the operator either wants to add
# a remote first, or stay local. The recurrent friction pattern that
# justified hardening this from a CLAUDE.md rule into a hook: prose
# discipline kept failing for this specific reflex.

guard_no_remote() {
  local input="$1"
  local cmd
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0

  # Match `git push` at the start of the command or after a chain
  # operator (`&&`, `;`, `||`, newline). Skip when nothing pushes.
  grep -Eq '(^|&&|;|\|\||[[:space:]])[[:space:]]*git[[:space:]]+push([[:space:]]|$)' <<< "$cmd" || return 0

  # allow-comment: honor leading `cd <path> &&` so the remote check runs in the target repo, mirroring git-discipline's cd-target handling.
  local target=""
  if [[ "$cmd" =~ ^[[:space:]]*cd[[:space:]]+(\"[^\"]+\"|\'[^\']+\'|[^[:space:]\&]+)[[:space:]]*\&\& ]]; then
    target="${BASH_REMATCH[1]}"
    target="${target#\"}"; target="${target%\"}"
    target="${target#\'}"; target="${target%\'}"
    target="${target/#\~/$HOME}"
  fi
  if [ -n "$target" ] && [ -d "$target" ]; then
    cd "$target" 2>/dev/null || true
  fi

  # Find any configured remote. `git remote` prints one name per line; an
  # empty list means no remote at all.
  local remotes
  remotes=$(git remote 2>/dev/null)
  if [ -z "$remotes" ]; then
    dd_emit_deny no-remote "git push blocked: this repo has no remote configured. Run 'git remote add origin <url>' first, or keep the work local."
  fi

  # If the push command names a specific remote, verify that one exists.
  # Pattern: `git push <remote>` (with optional flags before <remote>).
  local target
  target=$(sed -nE 's/.*git[[:space:]]+push([[:space:]]+-[^[:space:]]+)*[[:space:]]+([^[:space:]-][^[:space:]]*).*/\2/p' <<< "$cmd" | head -1)
  if [ -n "$target" ]; then
    if ! grep -qx "$target" <<< "$remotes"; then
      dd_emit_deny no-remote "git push blocked: remote '$target' is not configured. Available: $(echo "$remotes" | tr '\n' ' ')"
    fi
  fi
}
