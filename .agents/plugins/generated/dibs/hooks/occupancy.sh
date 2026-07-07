#!/bin/bash
# allow-comment: load-bearing contract. dibs occupancy enforcement: claim the working directory only at the first mutating file edit (PreToolUse), hard-deny that edit when a different live agent session already holds it, and release at SessionEnd (Claude only; Codex has no session-end event and relies on dibs pid-liveness self-heal). Read-only sessions never take occupancy and never get steered aside. No lock logic lives here; every verb shells out to this plugin's own dibs CLI. The decision is driven off `dibs claim --json` state, and the gate fails open on anything that is not a positive cross-session refusal, so a broken or missing lock never blocks an agent. Opt out per session with DIBS_OCCUPANCY=off.

OCC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# allow-comment: load-bearing. Share one holder-pid walk with the undibs skill so claim and release agree on the recorded pid.
. "$OCC_DIR/bin/holder-pid.sh"

occ_event()   { jq -r '.hook_event_name // empty' <<< "$1" 2>/dev/null; }
occ_tool()    { jq -r '.tool_name // empty' <<< "$1" 2>/dev/null; }
occ_session() { jq -r '.session_id // .sessionId // empty' <<< "$1" 2>/dev/null; }

occ_cwd() {
  local c
  c=$(jq -r '.cwd // empty' <<< "$1" 2>/dev/null)
  [ -n "$c" ] && [ -d "$c" ] && printf '%s\n' "$c"
}

occ_abs_path() {
  local input="$1" path="$2" cwd
  [ -n "$path" ] || return 1
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *)
      cwd="$(occ_cwd "$input")"
      [ -n "$cwd" ] || return 1
      printf '%s/%s\n' "$cwd" "$path"
      ;;
  esac
}

occ_existing_dir_for_path() {
  local path="$1" dir
  [ -n "$path" ] || return 1
  if [ -d "$path" ]; then
    dir="$path"
  else
    dir="$(dirname "$path")"
  fi
  while [ -n "$dir" ] && [ ! -d "$dir" ] && [ "$dir" != "/" ]; do
    dir="$(dirname "$dir")"
  done
  [ -d "$dir" ] && printf '%s\n' "$dir"
}

occ_git_root_for_dir() {
  local dir="$1" root
  root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || root=""
  if [ -n "$root" ] && [ -d "$root" ]; then
    (cd "$root" && pwd -P)
  else
    (cd "$dir" && pwd -P)
  fi
}

occ_target_dir_for_path() {
  local input="$1" path="$2" abs dir root
  abs="$(occ_abs_path "$input" "$path")" || return 1
  dir="$(occ_existing_dir_for_path "$abs")" || return 1
  root="$(occ_git_root_for_dir "$dir")" || return 1
  # allow-comment: load-bearing. The filesystem root is never a working tree. Outside a git repo, bogus path tokens scraped from heredoc/inline command content (e.g. "/w:p" from "</w:p>") walk up to "/" and would otherwise be claimed, colliding with any session that legitimately holds "/". Keep occupancy at real directory level.
  [ "$root" = "/" ] && return 1
  printf '%s\n' "$root"
}

occ_json_tool_paths() {
  jq -r '
    [
      .tool_input.file_path?,
      .tool_input.filePath?,
      .tool_input.path?,
      .tool_input.files[]?.path?
    ]
    | .[]
    | select(type == "string" and length > 0)
  ' <<< "$1" 2>/dev/null
}

occ_patch_paths() {
  local patch
  patch="$(jq -r '
    (
      if (.tool_input? | type) == "string" then .tool_input
      else (.tool_input.patch? // .tool_input.input? // .tool_input.content? // empty)
      end
    )
    | select(type == "string")
  ' <<< "$1" 2>/dev/null)"
  [ -n "$patch" ] || return 0
  printf '%s\n' "$patch" | awk '
    /^\*\*\* (Add|Update|Delete) File: / {
      sub(/^\*\*\* (Add|Update|Delete) File: /, "")
      print
      next
    }
    /^\*\*\* Move to: / {
      sub(/^\*\*\* Move to: /, "")
      print
      next
    }
  '
}

occ_bash_command() {
	jq -r '.tool_input.command // empty' <<< "$1" 2>/dev/null
}

occ_command_without_strings() {
	printf '%s' "$1" | sed -E "s/'[^']*'//g; s/\"([^\"\\\\]|\\\\.)*\"//g"
}

occ_bash_mutates() {
	local command="$1" stripped
	[ -n "$command" ] || return 1
	stripped="$(occ_command_without_strings "$command")"
	# allow-comment: load-bearing. A redirect to the /dev device tree (the ubiquitous 2>/dev/null, or >/dev/null) writes to no working tree, so it must not classify a read-only command as mutating. Strip those redirects before the write-detection below, otherwise every grep/find/cat with suppressed stderr claims occupancy on its path arguments.
	stripped="$(printf '%s' "$stripped" | sed -E 's#[0-9]*>>?[[:space:]]*/dev/[^[:space:];&|)]*##g')"
	[[ "$stripped" =~ (^|[[:space:]\;\&\|\(])(cp|mv|rm|mkdir|rmdir|touch|tee|ln|unlink|truncate|install)([[:space:]\;\&\|\)]|$) ]] && return 0
	[[ "$stripped" =~ (^|[[:space:]\;\&\|\(])git[[:space:]]+([^;\&\|]*[[:space:]])?(add|stage|commit|checkout|switch|merge|rebase|reset|restore|clean|mv|rm|am|cherry-pick|revert)([[:space:]\;\&\|\)]|$) ]] && return 0
	[[ "$stripped" =~ (^|[[:space:]\;\&\|\(])git[[:space:]]+([^;\&\|]*[[:space:]])?stash[[:space:]]+(push|pop|apply|drop|clear|save)([[:space:]\;\&\|\)]|$) ]] && return 0
	[[ "$stripped" =~ (^|[[:space:]\;\&\|\(])git[[:space:]]+([^;\&\|]*[[:space:]])?worktree[[:space:]]+(add|remove|move|prune|repair)([[:space:]\;\&\|\)]|$) ]] && return 0
	[[ "$stripped" =~ (^|[[:space:]\;\&\|\(])git[[:space:]]+([^;\&\|]*[[:space:]])?branch[[:space:]]+(-d|-D|-m|-M|-c|-C|--delete|--move|--copy)([[:space:]\;\&\|\)]|$) ]] && return 0
	[[ "$stripped" =~ (^|[[:space:]\;\&\|\(])git[[:space:]]+([^;\&\|]*[[:space:]])?tag[[:space:]]+(-a|-s|-u|-d|--annotate|--sign|--delete)([[:space:]\;\&\|\)]|$) ]] && return 0
	[[ "$stripped" =~ (^|[[:space:]\;\&\|\(])(npm|pnpm|yarn|bun)[[:space:]]+(install|add|remove|update|link|unlink)([[:space:]\;\&\|\)]|$) ]] && return 0
	[[ "$stripped" =~ (^|[[:space:]\;\&\|\(])bundle[[:space:]]+(install|add|remove|update)([[:space:]\;\&\|\)]|$) ]] && return 0
	[[ "$stripped" =~ (^|[[:space:]\;\&\|])[0-9]*\>\>?[[:space:]]*[^[:space:]\&] ]] && return 0
	return 1
}

occ_bash_path_candidates() {
	printf '%s\n' "$1" | awk '
		{
			while (match($0, /(^|[[:space:];&|<>()])((\/|\.{1,2}\/)[^[:space:];&|<>()"]+)/)) {
				token = substr($0, RSTART, RLENGTH)
				sub(/^[[:space:];&|<>()]+/, "", token)
				print token
				$0 = substr($0, RSTART + RLENGTH)
			}
		}
	'
}

occ_bash_dirs() {
	local input="$1" command path emitted=0
	command="$(occ_bash_command "$input")"
	occ_bash_mutates "$command" || return 0
	while IFS= read -r path; do
		[ -n "$path" ] || continue
		occ_target_dir_for_path "$input" "$path" && emitted=1
	done < <(occ_bash_path_candidates "$command")
	[ "$emitted" -eq 1 ] || occ_cwd "$input"
}

occ_gate_dirs() {
  local input="$1" path
  {
    case "$(occ_tool "$input")" in
      Bash) occ_bash_dirs "$input" ;;
      *)
        occ_json_tool_paths "$input"
        [ "$(occ_tool "$input")" = "apply_patch" ] && occ_patch_paths "$input"
        ;;
    esac
  } | while IFS= read -r path; do
    occ_target_dir_for_path "$input" "$path" || true
  done | awk 'NF && !seen[$0]++ { print }'
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

# allow-comment: load-bearing. Codex sets PLUGIN_ROOT (and CLAUDE_PLUGIN_ROOT too, for Claude-format hook compat); Claude sets only CLAUDE_PLUGIN_ROOT. So PLUGIN_ROOT presence is the codex signal and must be checked first, otherwise a codex launched under a Claude session mislabels itself claude. DIBS_AGENT overrides for any host.
occ_agent_label() {
  if [ -n "${DIBS_AGENT:-}" ]; then printf '%s\n' "$DIBS_AGENT"; return 0; fi
  if [ -n "${PLUGIN_ROOT:-}" ]; then printf 'codex\n'; return 0; fi
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then printf 'claude\n'; return 0; fi
  printf 'agent\n'
}

occ_owner() {
  local input="$1" agent sid
  if [ -n "${DIBS_OWNER:-}" ]; then printf '%s\n' "$DIBS_OWNER"; return 0; fi
  agent="$(occ_agent_label)"
  sid="$(occ_session "$input")"
  if [ "$agent" = "codex" ]; then
    if [ -n "${CMUX_TAB_ID:-}" ]; then printf '%s\n' "$CMUX_TAB_ID"; return 0; fi
    if [ -n "${CMUX_WORKSPACE_ID:-}" ]; then printf '%s\n' "$CMUX_WORKSPACE_ID"; return 0; fi
    if [ -n "${CODEX_THREAD_ID:-}" ]; then printf '%s\n' "$CODEX_THREAD_ID"; return 0; fi
  fi
  [ -n "$sid" ] && printf '%s\n' "$sid"
}

occ_description() {
  local dir="$1" branch default_branch
  if [ -n "${DIBS_DESCRIPTION:-}" ]; then printf '%s\n' "$DIBS_DESCRIPTION"; return 0; fi
  branch="$(git -C "$dir" branch --show-current 2>/dev/null || true)"
  [ -n "$branch" ] || return 1
  default_branch="$(git -C "$dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
  if [ -z "$default_branch" ]; then
    default_branch="$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  fi
  [ "$branch" = "$default_branch" ] && return 1
  printf '%s\n' "$branch"
}

occ_legacy_codex_reclaim() {
  local input="$1"
  [ "$(occ_agent_label)" = "codex" ] || return 1
  [ -n "$(occ_owner "$input")" ] || return 1
  [ "$(occ_event "$input")" = "PreToolUse" ] || return 1
}

# allow-comment: load-bearing WHY. Record the long-lived agent process, never the ephemeral hook shell. The walk lives in bin/holder-pid.sh (shared with the undibs skill); occ_holder_pid keeps the hook-local name and contract. Nearest, not topmost: a codex nested in a Claude session must resolve to the codex, not climb past it to the Claude pid that already holds the lock.
occ_holder_pid() { dibs_holder_pid "$@"; }

occ_holder_line() {
  jq -r 'if .holder then "held by \(.holder.agent) (pid \(.holder.pid)) on \(.holder.hostname) since \(.holder.acquiredAt)" + (if .holder.description then "; work: \(.holder.description)" else "" end) else "another live agent holds this directory" end' 2>/dev/null
}

occ_refusal_suggestion() {
  jq -r '.suggestion // "Create a separate git worktree on a new branch (for example with bonsai:bonsai, or plain git worktree if you do not have it), then claim that worktree path."' 2>/dev/null
}

occ_abs_existing_dir() {
	local path="$1" base
	[ -n "$path" ] || return 1
	case "$path" in
		/*) ;;
		*) path="$(pwd -P)/$path" ;;
	esac
	[ -d "$path" ] && { (cd "$path" && pwd -P); return 0; }
	base="$(dirname "$path")"
	[ -d "$base" ] && (cd "$base" && pwd -P)
}

occ_is_linked_worktree_root() {
	local root="$1" git_dir common_dir git_abs common_abs
	git_dir="$(git -C "$root" rev-parse --git-dir 2>/dev/null)" || return 1
	common_dir="$(git -C "$root" rev-parse --git-common-dir 2>/dev/null)" || return 1
	case "$git_dir" in /*) ;; *) git_dir="$root/$git_dir" ;; esac
	case "$common_dir" in /*) ;; *) common_dir="$root/$common_dir" ;; esac
	git_abs="$(occ_abs_existing_dir "$git_dir")" || return 1
	common_abs="$(occ_abs_existing_dir "$common_dir")" || return 1
	[ "$git_abs" != "$common_abs" ]
}

occ_requires_linked_worktree() {
	local dir="$1" required
	required="$(git -C "$dir" config --bool --get laicluse.requireWorktree 2>/dev/null || true)"
	[ "$required" = "true" ] || return 1
	occ_is_linked_worktree_root "$dir" && return 1
	return 0
}

occ_enforce_worktree_requirement() {
	local dir="$1"
	occ_requires_linked_worktree "$dir" || return 0
	printf '[dibs/worktree-required] %s has laicluse.requireWorktree=true; mutating the primary checkout is blocked. Create or use a linked git worktree, for example with bonsai:bonsai, and retry there.\n' "$dir" >&2
	exit 2
}

occ_claim_output() {
  local input="$1" dir="${2:-}" dibs pid agent sid owner description
  dibs="$(occ_dibs_bin)" || return 2
  command -v node >/dev/null 2>&1 || return 2
  [ -n "$dir" ] || dir="$(occ_cwd "$input")"
  [ -n "$dir" ] || return 3
  pid="$(occ_holder_pid "${OCC_PPID:-$PPID}")"
  agent="$(occ_agent_label)"
  sid="$(occ_session "$input")"
  owner="$(occ_owner "$input")"
  description="$(occ_description "$dir")"
  set -- claim "$dir" --pid "$pid" --agent "$agent"
  [ -n "$sid" ] && set -- "$@" --session "$sid"
  [ -n "$owner" ] && set -- "$@" --owner "$owner"
  [ -n "$description" ] && set -- "$@" --description "$description"
  occ_legacy_codex_reclaim "$input" && set -- "$@" --legacy-codex-resume
  node "$dibs" "$@" --json 2>/dev/null
}

# allow-comment: load-bearing. Return 0 only when a DIFFERENT live session holds the directory. dibs matches self on exact pid; keying self-recognition on the session id makes a drifted worker pid harmless. An unidentifiable self (no session id) fails open.
occ_refused_by_other() {
  local input="$1" out="$2" state my_sid holder_sid my_owner holder_owner
  state="$(printf '%s' "$out" | jq -r '.state // empty' 2>/dev/null)"
  [ "$state" = "refused" ] || return 1
  my_owner="$(occ_owner "$input")"
  holder_owner="$(printf '%s' "$out" | jq -r '.holder.owner // empty' 2>/dev/null)"
  [ -n "$my_owner" ] && [ "$my_owner" = "$holder_owner" ] && return 1
  my_sid="$(occ_session "$input")"
  [ -n "$my_sid" ] || return 1
  holder_sid="$(printf '%s' "$out" | jq -r '.holder.session // empty' 2>/dev/null)"
  [ "$my_sid" = "$holder_sid" ] && return 1
  return 0
}

occ_gate() {
  local input="$1" out rc dir dirs
  dirs="$(occ_gate_dirs "$input")"
  if [ -z "$dirs" ] && [ "$(occ_tool "$input")" != "Bash" ]; then
    dirs="$(occ_cwd "$input")"
  fi
  [ -n "$dirs" ] || return 0
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    occ_enforce_worktree_requirement "$dir"
    out="$(occ_claim_output "$input" "$dir")"
    rc=$?
    case "$rc" in 0 | 2 | 3) continue ;; esac
    occ_refused_by_other "$input" "$out" || continue
    printf '[dibs/occupancy] %s; another live agent occupies this directory. %s If that holder is stale, inspect it with '\''dibs check %s'\'' and clear it with '\''dibs release %s'\''.\n' "$(printf '%s' "$out" | occ_holder_line)" "$(printf '%s' "$out" | occ_refusal_suggestion)" "$dir" "$dir" >&2
    exit 2
  done <<< "$dirs"
}

# allow-comment: load-bearing. A session can claim more than one directory (occ_gate_dirs keys per git root of each edited file), so a single-dir release at SessionEnd would leak every non-cwd lock until pid-liveness self-heal. Sweep all of this session's locks by holder pid, plus owner/session when known.
occ_release() {
  local input="$1" dibs pid owner sid
  dibs="$(occ_dibs_bin)" || return 0
  command -v node >/dev/null 2>&1 || return 0
  pid="$(occ_holder_pid "${OCC_PPID:-$PPID}")"
  owner="$(occ_owner "$input")"
  sid="$(occ_session "$input")"
  set -- release-all --pid "$pid"
  [ -n "$sid" ] && set -- "$@" --session "$sid"
  [ -n "$owner" ] && set -- "$@" --owner "$owner" --agent "$(occ_agent_label)"
  node "$dibs" "$@" >/dev/null 2>&1 || true
}

occ_dispatch() {
  local input="$1"
  case "$(occ_event "$input")" in
    SessionEnd)   occ_release "$input" ;;
    PreToolUse)
      case "$(occ_tool "$input")" in
        Bash|Edit|Write|MultiEdit|apply_patch) occ_gate "$input" ;;
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
