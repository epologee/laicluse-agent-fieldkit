#!/bin/bash
# PreToolUse:Bash guard for machine-wide plugin mutations. Install, update, removal, enablement, and marketplace commands can invalidate hook paths or change runtime behavior in every live coding session, so the operator must approve that exact action in the current turn.

dd_plugin_mutation_approved() {
  local input="$1" user
  user=$(dd_last_user_text "$input") || return 1
  [ -n "$user" ] || return 1

  if grep -qiE '\b(niet|geen|nooit|never|not|don'\''t|do not|zonder overleg|hoeft niet|doe niet)\b.{0,100}\b(plugin|plugins|marketplace)\b' <<< "$user"; then
    return 1
  fi

  grep -qiE '\b(plugin|plugins|marketplace)\b' <<< "$user" || return 1
  grep -qiE '\b(add|install|update|upgrade|remove|uninstall|enable|disable|activate|refresh|run|execute|approve|allow|voeg|installeer|verwijder|deinstalleer|activeer|deactiveer|ververs|draai|voer|doe|mag|akkoord|goedgekeurd|bijwerken|bijgewerkt)\b' <<< "$user" && return 0
  # allow-comment: load-bearing. Dutch splits its update verb ("werk de plugins bij"), and the word boundary on werk keeps the negated "bij te werken" out.
  grep -qiE '\bwerk\b.{0,80}\bbij\b' <<< "$user"
}

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
    dd_plugin_mutation_approved "$input" && return 0
    dd_emit_deny plugin-mutation "machine-wide plugin mutation blocked: this can replace hook paths or runtime code used by every live coding session. For a local Codex marketplace that already points at the primary checkout, test the candidate and merge it; do not reinstall it. Otherwise ask the operator to approve the exact install, update, removal, enablement, or marketplace change in the current turn."
  fi
}
