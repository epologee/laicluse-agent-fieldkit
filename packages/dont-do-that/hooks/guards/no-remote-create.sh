#!/bin/bash
# PreToolUse:Bash guard that blocks remote-create patterns (gh repo create, gh repo fork, git remote add, git remote set-url). allow-comment: hook-header documenting the matchers and the operator escape, same pattern as sibling no-remote.sh and no-worktree-deploy.sh in this directory. Remote creation is operator territory: spinning up an account-bound repository or rewiring the local repo carries permission, billing, visibility and team implications the model cannot reason about.

dd_nrc_last_user_text() {
  local input="$1" direct tr
  direct=$(jq -r '.last_user_message // .user_message // empty' <<< "$input" 2>/dev/null)
  if [ -n "$direct" ]; then
    printf '%s\n' "$direct" | tail -c 1000
    return 0
  fi

  tr=$(dd_transcript "$input") || return 1
  [ -f "$tr" ] || return 1
  tail -200 "$tr" \
    | jq -s -r '
def textify:
if . == null then ""
elif type == "string" then .
elif type == "array" then
map(
if type == "string" then .
elif type == "object" then (.text? // (.content? | textify) // "")
else "" end
) | join("\n")
elif type == "object" then (.text? // (.content? | textify) // "")
else "" end;
[
.[]
| select(.type == "user" or .role == "user" or .message.role == "user")
| select(((.message.content? // .content?) | type) != "array"
    or (((.message.content? // .content?) | map(.type? // "")) | index("tool_result") | not))
| (.message.content? // .content? // .text? // empty | textify)
| select(length > 0)
] | .[-3:] | join("\n")
' 2>/dev/null \
    | tail -c 1000
}

dd_nrc_operator_approved() {
  local input="$1" kind="$2" user
  user=$(dd_nrc_last_user_text "$input") || return 1
  [ -n "$user" ] || return 1

  if grep -qiE '\b(niet|geen|never|not|don'\''t|do not)\b.{0,80}\b(gh[[:space:]]+repo|repo|fork|remote)\b' <<< "$user"; then
    return 1
  fi

  grep -qiE '\b(yes|yep|go ahead|do it|run it|execute|approved|approve|allow|please|can you|could you|make|create|fork|add|set|ja|doe maar|voer.{0,30}uit|uitvoeren|maak|aanmaken|voeg.{0,30}toe|zet|mag|toestemming|akkoord|goedgekeurd|graag|kan je|kun je|wil.{0,30}graag|overrul)\b' <<< "$user" || return 1

  case "$kind" in
    forge)
      grep -qiE '\b(remotes?|repos?|repository|repositories|fork(s|en)?|github)\b' <<< "$user"
      ;;
    remote)
      grep -qiE '\b(remotes?|repos?|repository|repositories|github)\b' <<< "$user"
      ;;
    *)
      return 1
      ;;
  esac
}

guard_no_remote_create() {
  local input="$1"
  local cmd
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0

  if grep -Eq '(^|&&|;|\|\||[[:space:]])[[:space:]]*gh[[:space:]]+repo[[:space:]]+(create|fork)([[:space:]]|$)' <<< "$cmd"; then
    dd_nrc_operator_approved "$input" forge && return 0
    dd_emit_deny no-remote-create "remote creation blocked: 'gh repo create' / 'gh repo fork' creates account-bound forge state. Deleting it later is not true reversibility once the name, visibility, audit events, or notifications may have existed on the internet. Ask the operator for explicit approval in the current turn, or have them create the repo in the browser and tell you the URL."
  fi

  if grep -Eq '(^|&&|;|\|\||[[:space:]])[[:space:]]*git[[:space:]]+remote[[:space:]]+(add|set-url)([[:space:]]|$)' <<< "$cmd"; then
    dd_nrc_operator_approved "$input" remote && return 0
    dd_emit_deny no-remote-create "remote attach blocked: 'git remote add' / 'git remote set-url' connects local history to an external destination the operator may not have authorized. Remote wiring is the step that turns a local repo into internet-adjacent state, so it needs explicit operator approval in the current turn."
  fi
}
