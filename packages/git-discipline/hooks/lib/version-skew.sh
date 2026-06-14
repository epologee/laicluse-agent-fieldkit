#!/bin/bash
# allow-comment: Surfaces parallel-session version drift. Every Claude session freezes its plugin install path at start, so `claude plugins update` does not propagate to running sessions. Without a signal, the operator cannot tell that two parallel sessions are running different git-discipline versions on the same repo. This guard fires once per session via a sentinel and emits a non-blocking nudge.

dd_git_discipline_version_skew() {
  local input="$1"

  local session_id
  session_id=$(dd_session_id "$input")
  [[ -z "$session_id" ]] && return 0

  local sentinel="/tmp/git-discipline-version-skew-checked-${session_id}"
  [[ -f "$sentinel" ]] && return 0
  touch "$sentinel" 2>/dev/null || true

  local plugin_root
  plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  local loaded_pjson="$plugin_root/.claude-plugin/plugin.json"
  [[ -f "$loaded_pjson" ]] || return 0

  local loaded_version
  loaded_version=$(jq -r '.version // empty' "$loaded_pjson" 2>/dev/null)
  [[ -z "$loaded_version" ]] && return 0

  local installed_json="$HOME/.claude/plugins/installed_plugins.json"
  [[ -f "$installed_json" ]] || return 0

  local installed_version
  installed_version=$(jq -r '.plugins["git-discipline@laicluse-agent-fieldkit"][0].version // empty' "$installed_json" 2>/dev/null)
  [[ -z "$installed_version" ]] && return 0

  [[ "$loaded_version" = "$installed_version" ]] && return 0

  dd_emit_pre_context "version-skew" "git-discipline version skew detected: this session loaded v${loaded_version}, but v${installed_version} is currently installed. Parallel sessions on different versions can deny the same commit differently. Restart this Claude session to pick up v${installed_version}, or accept that the discipline in this session lags the installed version."
}
