#!/bin/bash
# PreToolUse:Bash guard for machine-wide plugin mutations. Install, update, removal, enablement, and marketplace commands can invalidate hook paths or change runtime behavior in every live coding session, so the operator decides each one. allow-comment: load-bearing contract. The guard classifies the COMMAND and hands the decision to the host's permission prompt; it never reads the operator's wording to infer consent. Detecting approval from natural language was tried and failed: a keyword-and-verb match refuses real approvals phrased outside its vocabulary, accepts sentences that merely mention plugins, and turns every new phrasing into another regex. The host already owns the question and shows the operator the exact command, which no word list can match.

guard_plugin_mutation() {
  local input="$1" cmd prefix assignments wrappers codex_mutation claude_mutation
  cmd=$(jq -r '.tool_input.command // .tool_input.cmd // empty' <<< "$input" 2>/dev/null)
  [ -n "$cmd" ] || return 0

  prefix='(^|[;&|({]|[$][(])[[:space:]]*'
  assignments='([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*'
  wrappers='((command|exec|nohup|sudo|doas|arch)([[:space:]]+-[^[:space:]]+)*[[:space:]]+|env([[:space:]]+-[^[:space:]]+|[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+)*[[:space:]]+)*'
  codex_mutation='([[:alnum:]_.\/-]+\/)?codex[[:space:]]+plugin[[:space:]]+((add|remove|enable|disable)([[:space:]]|$)|marketplace[[:space:]]+(add|remove|upgrade)([[:space:]]|$))'
  claude_mutation='([[:alnum:]_.\/-]+\/)?claude[[:space:]]+plugins?[[:space:]]+((install|uninstall|update|enable|disable)([[:space:]]|$)|marketplace[[:space:]]+(add|remove|update)([[:space:]]|$))'

  if grep -Eq "${prefix}${assignments}${wrappers}(${codex_mutation}|${claude_mutation})" <<< "$cmd"; then
    dd_emit_ask plugin-mutation "machine-wide plugin mutation: this replaces hook paths and runtime code for every live coding session on this machine. For a local marketplace that already points at the primary checkout, testing the candidate and merging it beats reinstalling it."
  fi
}
