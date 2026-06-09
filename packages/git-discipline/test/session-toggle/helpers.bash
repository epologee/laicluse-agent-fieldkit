#!/usr/bin/env bash
# Shared setup for the session-toggle BATS suite.
#
# Strategy: override $HOME via env so sentinels land in BATS_TEST_TMPDIR
# and never touch the real ${LAICLUSE_HOME:-~/.laicluse}/git-discipline/. The dispatch.sh script reads
# $HOME directly for sentinel paths, so this is the correct intercept point.
#
# The git shim here is minimal: we only need dispatch.sh to reach the
# session-id check, not to validate commit bodies. The shim makes the
# non-trivial-commit case pass trivially so that guard exits that reach
# further guards do not confuse the tests.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH="$SCRIPT_DIR/../../hooks/dispatch.sh"

export GIT_DISCIPLINE_SHADOW_LOG="$BATS_TEST_TMPDIR/shadow.log"

# Defaults that let all guards pass so the early-exit check is the only
# variable we are testing.
export GIT_SHIM_ORIGIN_URL="https://github.com/someorg/somerepo.git"
export GIT_SHIM_SHORTSTAT=" 1 file changed, 1 insertion(+)"
export GIT_SHIM_DIFF_NAMES="docs/notes.md"
export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="Slice: docs-only"
export GIT_SHIM_LS_TREE_OUTPUT=""
export GIT_SHIM_LOG_HASHES=""
export GIT_SHIM_LOG_BODY=""
export GIT_SHIM_HEAD_ABBREV="feature/session-toggle"
export GIT_SHIM_HEAD_SHORT="deadbeef"

setup() {
  # Redirect $HOME so sentinel files land in the temp directory.
  export HOME="$BATS_TEST_TMPDIR"

  local shim_bin="$BATS_TEST_TMPDIR/bin"
  install -d "$shim_bin" 2>/dev/null || true

  cat > "$shim_bin/git" <<'SHIM'
#!/usr/bin/env bash
args=("$@")

if [[ "${args[0]}" = "config" && "${args[*]}" =~ "remote.origin.url" ]]; then
  printf '%s\n' "$GIT_SHIM_ORIGIN_URL"; exit 0
fi
if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--shortstat" ]]; then
  printf '%s\n' "$GIT_SHIM_SHORTSTAT"; exit 0
fi
if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--name-only" ]]; then
  printf '%s\n' "$GIT_SHIM_DIFF_NAMES"; exit 0
fi
if [[ "${args[0]}" = "interpret-trailers" && "${args[1]}" = "--parse" ]]; then
  printf '%s' "$GIT_SHIM_INTERPRET_TRAILERS_OUTPUT"; exit 0
fi
if [[ "${args[0]}" = "ls-tree" ]]; then
  printf '%s' "$GIT_SHIM_LS_TREE_OUTPUT"; exit 0
fi
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%H" ]]; then
  [[ -n "$GIT_SHIM_LOG_HASHES" ]] && printf '%s\n' "$GIT_SHIM_LOG_HASHES"
  exit 0
fi
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%B" ]]; then
  printf '%s\n' "$GIT_SHIM_LOG_BODY"; exit 0
fi
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--abbrev-ref" ]]; then
  printf '%s\n' "$GIT_SHIM_HEAD_ABBREV"; exit 0
fi
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--short" ]]; then
  printf '%s\n' "$GIT_SHIM_HEAD_SHORT"; exit 0
fi
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "HEAD" ]]; then
  printf 'deadbeef00000000\n'; exit 0
fi
# git rev-parse --show-toplevel: sandbox to BATS_TEST_TMPDIR.
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--show-toplevel" ]]; then
  printf '%s\n' "${BATS_TEST_TMPDIR:-/}"; exit 0
fi

REAL_GIT=$(PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin" command -v git 2>/dev/null || true)
if [[ -n "$REAL_GIT" ]]; then exec "$REAL_GIT" "$@"; fi

printf 'git shim: unhandled: %s\n' "$*" >&2
exit 1
SHIM
  chmod +x "$shim_bin/git"

  export PATH="$shim_bin:$PATH"

  # Pre-seed commit-subject rotation state so ack-rule4 passes immediately.
  local _state_file="$BATS_TEST_TMPDIR/commit-rule-state"
  printf '%s\n%s\n%s\n' '-1' '3' '0' > "$_state_file"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$_state_file"
}

teardown() {
  : # BATS_TEST_TMPDIR cleaned up by bats-core.
}

# ---------------------------------------------------------------------------
# Input builder helpers
# ---------------------------------------------------------------------------

# pretool_bash_json_with_session <bash-command> <session_id>
pretool_bash_json_with_session() {
  local cmd="$1"
  local sid="$2"
  jq -cn --arg c "$cmd" --arg s "$sid" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:$s,tool_input:{command:$c}}'
}

# pretool_bash_json_no_session <bash-command>
pretool_bash_json_no_session() {
  local cmd="$1"
  jq -cn --arg c "$cmd" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'
}

# run_dispatch_with_session <bash-command> <session_id>
run_dispatch_with_session() {
  local cmd="$1"
  local sid="$2"
  local json
  json=$(pretool_bash_json_with_session "$cmd" "$sid")
  run bash "$DISPATCH" <<< "$json"
}

# run_dispatch_no_session <bash-command>
run_dispatch_no_session() {
  local cmd="$1"
  local json
  json=$(pretool_bash_json_no_session "$cmd")
  run bash "$DISPATCH" <<< "$json"
}

# write_session_sentinel <session_id>
write_session_sentinel() {
  local sid="$1"
  mkdir -p "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline"
  touch "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-$sid"
}

# write_global_sentinel
write_global_sentinel() {
  mkdir -p "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline"
  touch "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-global"
}
