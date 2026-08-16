#!/bin/bash
# PreToolUse:Bash guard for the plugin commands that change which code a machine loads. allow-comment: load-bearing contract. Only the set that adds, removes or disables is gated: install, uninstall, disable, and marketplace add or remove. Updating or enabling an already installed plugin is ordinary agent work and passes untouched, because activating merged work is the job, not a hazard. A gated command goes to the host's permission prompt where the operator sees one, and is refused elsewhere with the DD_PLUGIN_MUTATION=asked escape named in the denial, so an agent whose operator did ask is never stuck handing the command back. The guard never reads the operator's wording to infer consent: a keyword-and-verb match refuses real approvals phrased outside its vocabulary, accepts sentences that merely mention plugins, and turns every new phrasing into another regex.

guard_plugin_mutation() {
  local input="$1" cmd prefix assignments wrappers codex_mutation claude_mutation
  cmd=$(jq -r '.tool_input.command // .tool_input.cmd // empty' <<< "$input" 2>/dev/null)
  [ -n "$cmd" ] || return 0

  prefix='(^|[;&|({]|[$][(])[[:space:]]*'
  assignments='([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*'
  wrappers='((command|exec|nohup|sudo|doas|arch)([[:space:]]+-[^[:space:]]+)*[[:space:]]+|env([[:space:]]+-[^[:space:]]+|[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+)*[[:space:]]+)*'
  codex_mutation='([[:alnum:]_.\/-]+\/)?codex[[:space:]]+plugin[[:space:]]+((add|remove|disable)([[:space:]]|$)|marketplace[[:space:]]+(add|remove)([[:space:]]|$))'
  claude_mutation='([[:alnum:]_.\/-]+\/)?claude[[:space:]]+plugins?[[:space:]]+((install|uninstall|disable)([[:space:]]|$)|marketplace[[:space:]]+(add|remove)([[:space:]]|$))'

  grep -Eq "${prefix}${assignments}${wrappers}(${codex_mutation}|${claude_mutation})" <<< "$cmd" || return 0
  grep -Eq '(^|[[:space:]])DD_PLUGIN_MUTATION=asked([[:space:]]|$)' <<< "$cmd" && return 0

  dd_emit_ask plugin-mutation "this adds, removes or disables machine-wide plugin code, so it changes which hooks and runtime every live coding session on this machine loads. Updating or enabling an already installed plugin is not gated; this is the set that changes what exists. Re-run with DD_PLUGIN_MUTATION=asked in front once the operator has asked for this exact change." "$input"
}
