#!/bin/bash
# allow-comment: load-bearing contract. dibs occupancy enforcement: claim the working directory at SessionStart, hard-deny a file edit when a different live agent session already holds it (PreToolUse), release at SessionEnd (Claude only; Codex has no session-end event and relies on dibs pid-liveness self-heal). No lock logic lives here; every verb shells out to this plugin's own dibs CLI. The decision is driven off `dibs claim --json` state, and the gate fails open on anything that is not a positive cross-session refusal, so a broken or missing lock never blocks an agent; SessionStart instead surfaces that enforcement is off. Opt out per session with DIBS_OCCUPANCY=off.

OCC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

occ_event()   { jq -r '.hook_event_name // empty' <<< "$1" 2>/dev/null; }
occ_tool()    { jq -r '.tool_name // empty' <<< "$1" 2>/dev/null; }
occ_session() { jq -r '.session_id // .sessionId // empty' <<< "$1" 2>/dev/null; }

occ_cwd() {
  local c
  c=$(jq -r '.cwd // empty' <<< "$1" 2>/dev/null)
  [ -n "$c" ] && [ -d "$c" ] && printf '%s\n' "$c"
}

occ_dibs_bin() {
  if [ -n "${DIBS_BIN:-}" ] && [ -e "$DIBS_BIN" ]; then printf '%s\n' "$DIBS_BIN"; return 0; fi
  if [ -e "$OCC_DIR/bin/dibs" ]; then printf '%s\n' "$OCC_DIR/bin/dibs"; return 0; fi
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -e "$CLAUDE_PLUGIN_ROOT/bin/dibs" ]; then printf '%s\n' "$CLAUDE_PLUGIN_ROOT/bin/dibs"; return 0; fi
  if command -v codex >/dev/null 2>&1; then
    local r
    r=$(codex plugin list 2>/dev/null | awk '$1 == "dibs@laicluse-agent-fieldkit" { print $NF; found=1; exit } END { exit found ? 0 : 1 }')
    [ -n "$r" ] && [ -e "$r/bin/dibs" ] && { printf '%s\n' "$r/bin/dibs"; return 0; }
  fi
  return 1
}

occ_agent_label() {
  if [ -n "${DIBS_AGENT:-}" ]; then printf '%s\n' "$DIBS_AGENT"; return 0; fi
  if [ -n "${PLUGIN_ROOT:-}" ] && [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then printf 'codex\n'; return 0; fi
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then printf 'claude\n'; return 0; fi
  printf 'agent\n'
}

# allow-comment: load-bearing WHY. Record the long-lived agent process, never the ephemeral hook shell. DIBS_HOLDER_PID overrides; else walk to the TOPMOST claude/codex ancestor so the same pid is recorded across SessionStart, every PreToolUse, and SessionEnd; fall back to the start pid.
occ_holder_pid() {
  local start="${1:-$PPID}"
  if [ -n "${DIBS_HOLDER_PID:-}" ] && [ "${DIBS_HOLDER_PID}" -gt 0 ] 2>/dev/null; then
    printf '%s\n' "$DIBS_HOLDER_PID"
    return 0
  fi
  local pid="$start" hops=0 comm parent match=""
  while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null && [ "$hops" -lt 30 ]; do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null)
    case "$comm" in
      *[Cc]laude*|*[Cc]odex*) match="$pid" ;;
    esac
    parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -z "$parent" ] && break
    pid="$parent"
    hops=$((hops + 1))
  done
  if [ -n "$match" ]; then
    printf '%s\n' "$match"
  elif [ "$start" -gt 0 ] 2>/dev/null; then
    printf '%s\n' "$start"
  else
    printf '%s\n' "$PPID"
  fi
}

occ_holder_line() {
  jq -r 'if .holder then "held by \(.holder.agent) (pid \(.holder.pid)) on \(.holder.hostname) since \(.holder.acquiredAt)" else "another live agent holds this directory" end' 2>/dev/null
}

occ_claim_output() {
  local input="$1" dibs dir pid agent sid
  dibs="$(occ_dibs_bin)" || return 2
  command -v node >/dev/null 2>&1 || return 2
  dir="$(occ_cwd "$input")"
  [ -n "$dir" ] || return 3
  pid="$(occ_holder_pid "${OCC_PPID:-$PPID}")"
  agent="$(occ_agent_label)"
  sid="$(occ_session "$input")"
  if [ -n "$sid" ]; then
    node "$dibs" claim "$dir" --pid "$pid" --agent "$agent" --session "$sid" --json 2>/dev/null
  else
    node "$dibs" claim "$dir" --pid "$pid" --agent "$agent" --json 2>/dev/null
  fi
}

# allow-comment: load-bearing. Return 0 only when a DIFFERENT live session holds the directory. dibs matches self on exact pid; keying self-recognition on the session id makes a drifted worker pid harmless. An unidentifiable self (no session id) fails open.
occ_refused_by_other() {
  local input="$1" out="$2" state my_sid holder_sid
  state="$(printf '%s' "$out" | jq -r '.state // empty' 2>/dev/null)"
  [ "$state" = "refused" ] || return 1
  my_sid="$(occ_session "$input")"
  [ -n "$my_sid" ] || return 1
  holder_sid="$(printf '%s' "$out" | jq -r '.holder.session // empty' 2>/dev/null)"
  [ "$my_sid" = "$holder_sid" ] && return 1
  return 0
}

occ_session_context() {
  jq -cn --arg c "[dibs/occupancy] $1" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
}

occ_claim() {
  local input="$1" out rc
  out="$(occ_claim_output "$input")"
  rc=$?
  if [ "$rc" -eq 2 ]; then
    occ_session_context "dibs CLI not found; single-occupancy enforcement is OFF for this session. Set DIBS_BIN to restore it."
    return 0
  fi
  { [ "$rc" -eq 0 ] || [ "$rc" -eq 3 ]; } && return 0
  occ_refused_by_other "$input" "$out" || return 0
  occ_session_context "$(printf '%s' "$out" | occ_holder_line); another agent occupies this directory. Step aside and work elsewhere, or stop."
}

occ_gate() {
  local input="$1" out rc dir
  out="$(occ_claim_output "$input")"
  rc=$?
  case "$rc" in 0 | 2 | 3) return 0 ;; esac
  occ_refused_by_other "$input" "$out" || return 0
  dir="$(occ_cwd "$input")"
  printf '[dibs/occupancy] %s; another live agent occupies this directory. Work elsewhere; if that holder is stale, inspect it with '\''dibs check %s'\'' and clear it with '\''dibs release %s'\''.\n' "$(printf '%s' "$out" | occ_holder_line)" "$dir" "$dir" >&2
  exit 2
}

occ_release() {
  local input="$1" dibs dir pid
  dibs="$(occ_dibs_bin)" || return 0
  command -v node >/dev/null 2>&1 || return 0
  dir="$(occ_cwd "$input")"
  [ -n "$dir" ] || return 0
  pid="$(occ_holder_pid "${OCC_PPID:-$PPID}")"
  node "$dibs" release "$dir" --pid "$pid" >/dev/null 2>&1 || true
}

occ_dispatch() {
  local input="$1"
  case "$(occ_event "$input")" in
    SessionStart) occ_claim "$input" ;;
    SessionEnd)   occ_release "$input" ;;
    PreToolUse)
      case "$(occ_tool "$input")" in
        Edit|Write|MultiEdit|apply_patch) occ_gate "$input" ;;
      esac
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  [ "${DIBS_OCCUPANCY:-on}" = "off" ] && exit 0
  OCC_PPID="$PPID"
  occ_dispatch "$(cat)"
  exit 0
fi
