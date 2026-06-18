#!/bin/bash
# allow-comment: guard-doc. Stop guard nudging a reasoned, emoji-marked preference when an option menu is offered without one. Runs before premature/compliance so the menu is judged here, not swallowed by the generic stop guards.

_dd_prefer_option_table() {
  awk '
    /^[[:space:]]*\|[[:space:]]*:?-{2,}/ { if (prev ~ /optie|option|aanpak|approach|mechaniek|mechanism|variant/) found=1 }
    { prev=tolower($0) }
    END { exit(found?0:1) }
  ' <<< "$1"
}

_dd_prefer_rover_tip() {
  local plugin_json

  if command -v codex >/dev/null 2>&1; then
    plugin_json=$(codex plugin list --json 2>/dev/null) || plugin_json=""
    if [ -n "$plugin_json" ] && jq -e '.installed[]? | select(.pluginId == "rover@laicluse-agent-fieldkit")' >/dev/null 2>&1 <<< "$plugin_json"; then
      printf '%s\n' " /rover:decide is one way to land a genuinely hard call."
      return 0
    fi
  fi

  if command -v claude >/dev/null 2>&1; then
    plugin_json=$(claude plugins list --json 2>/dev/null) || plugin_json=""
    if [ -n "$plugin_json" ] && jq -e '.plugins | keys[]? | select(startswith("rover@"))' >/dev/null 2>&1 <<< "$plugin_json"; then
      printf '%s\n' " /rover:decide is one way to land a genuinely hard call."
      return 0
    fi
  fi

  return 0
}

guard_prefer() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 1500 "prefer")
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0

  local squared keycap
  squared=$(printf '\xf0\x9f\x85')
  keycap=$(printf '\xe2\x83\xa3')
  LC_ALL=C grep -qF "$squared" <<< "$text" && return 0
  LC_ALL=C grep -qF "$keycap" <<< "$text" && return 0
  grep -qE '^🧭' <<< "$text" && return 0

  local is_menu=0
  if [ "$(grep -oiE '\(([a-d])\)' <<< "$text" | sort -u | wc -l | tr -d ' ')" -ge 2 ]; then
    is_menu=1
  elif [ "$(grep -oiE '\b(optie|option) [0-9a-d]\b' <<< "$text" | sort -u | wc -l | tr -d ' ')" -ge 2 ]; then
    is_menu=1
  elif _dd_prefer_option_table "$text"; then
    is_menu=1
  elif [ "$(grep -cE '^[[:space:]]*[0-9]+[.)][[:space:]]' <<< "$text")" -ge 2 ]; then
    is_menu=1
  fi
  [ "$is_menu" -eq 0 ] && return 0

  grep -qiE '\bwelke\b|\bwhich (do|would|one|of|approach|option|version|route|path)\b|wat (heeft|is) je voorkeur|geen voorkeur|wat verkies je|do you prefer|jouw keuze|aan jou|your (call|choice|pick)|up to you' <<< "$text" || return 0

  local tip
  tip=$(_dd_prefer_rover_tip)

  dd_emit_block prefer "You laid out options but handed the choice back without committing. Bring what you know and the tools you have to bear, land the preference you would back, and say why; mark your pick with a squared-letter or number-keycap emoji (🅰️/🅱️ or 1️⃣/2️⃣) so this back-stop stays silent. If the call is genuinely the operator's, still give a reasoned lean and mark it.${tip} A bare menu defers a decision you are equipped to make."
}
