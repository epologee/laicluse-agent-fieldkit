#!/usr/bin/env bash
# Shared setup, teardown, and fixture helpers for the shadow-mode BATS suite.
#
# Mock strategy: the git shim is the same approach as validate-body/helpers.bash.
# Additional shim variables cover the calls commit-body.sh makes:
#   GIT_SHIM_ORIGIN_URL   - what "git config --get remote.origin.url" returns
#   GIT_SHIM_SHORTSTAT    - what "git diff --cached --shortstat" returns
#   GIT_SHIM_DIFF_NAMES   - what "git diff --cached --name-only" returns
#   GIT_SHIM_HEAD_ABBREV  - what "git rev-parse --abbrev-ref HEAD" returns
#   GIT_SHIM_HEAD_SHORT   - what "git rev-parse --short HEAD" returns
#   (validate-body shim vars are also available for inner validate calls)
#
# The guard is tested by invoking dispatch.sh with synthetic PreToolUse JSON,
# because dispatch.sh sources commit-body.sh and validate-body.sh in the
# right order.  We inspect stdout (additionalContext JSON) and the shadow log
# to verify warn/skip behaviour without ever blocking.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH="$SCRIPT_DIR/../../hooks/dispatch.sh"
VALIDATOR="$SCRIPT_DIR/../../hooks/lib/validate-body.sh"

# Override the shadow log path so tests never write to the real log.
export GIT_DISCIPLINE_SHADOW_LOG="$BATS_TEST_TMPDIR/shadow.log"

# Shim defaults (can be overridden per test).
export GIT_SHIM_ORIGIN_URL="https://github.com/epologee/laicluse-agent-fieldkit.git"
export GIT_SHIM_SHORTSTAT=" 5 files changed, 20 insertions(+), 3 deletions(-)"
export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb\nc.rb\nd.rb\ne.rb')"
export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""
export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
export GIT_SHIM_DIFF_CACHED_OUTPUT=""
export GIT_SHIM_LOG_HASHES=""
export GIT_SHIM_LOG_BODY=""
export GIT_SHIM_HEAD_ABBREV="main"
export GIT_SHIM_HEAD_SHORT="abc1234"

setup() {
  local shim_bin="$BATS_TEST_TMPDIR/bin"
  install -d "$shim_bin" 2>/dev/null || true

  cat > "$shim_bin/git" <<'SHIM'
#!/usr/bin/env bash
# Git shim for shadow-mode BATS tests.
args=("$@")

# git config --get remote.origin.url
if [[ "${args[0]}" = "config" && "${args[*]}" =~ "remote.origin.url" ]]; then
  printf '%s\n' "$GIT_SHIM_ORIGIN_URL"
  exit 0
fi

# git diff --cached --shortstat
if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--shortstat" ]]; then
  printf '%s\n' "$GIT_SHIM_SHORTSTAT"
  exit 0
fi

# git diff --cached --name-only
if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--name-only" ]]; then
  printf '%s\n' "$GIT_SHIM_DIFF_NAMES"
  exit 0
fi

# git interpret-trailers --parse
if [[ "${args[0]}" = "interpret-trailers" && "${args[1]}" = "--parse" ]]; then
  printf '%s' "$GIT_SHIM_INTERPRET_TRAILERS_OUTPUT"
  exit 0
fi

# git ls-tree -r HEAD --name-only
if [[ "${args[0]}" = "ls-tree" ]]; then
  printf '%s' "$GIT_SHIM_LS_TREE_OUTPUT"
  exit 0
fi

# git log -5 --pretty=format:'%H' HEAD
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%H" ]]; then
  [[ -n "$GIT_SHIM_LOG_HASHES" ]] && printf '%s\n' "$GIT_SHIM_LOG_HASHES"
  exit 0
fi

# git log -1 --pretty=format:'%B' <hash>
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%B" ]]; then
  printf '%s\n' "$GIT_SHIM_LOG_BODY"
  exit 0
fi

# git rev-parse --abbrev-ref HEAD
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--abbrev-ref" ]]; then
  printf '%s\n' "$GIT_SHIM_HEAD_ABBREV"
  exit 0
fi

# git rev-parse --short HEAD
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--short" ]]; then
  printf '%s\n' "$GIT_SHIM_HEAD_SHORT"
  exit 0
fi

# git rev-parse HEAD
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "HEAD" ]]; then
  printf 'abc1234def5678\n'
  exit 0
fi

# git rev-parse --show-toplevel
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--show-toplevel" ]]; then
  printf '%s\n' "${BATS_TEST_TMPDIR:-/}"
  exit 0
fi

REAL_GIT=$(PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin" command -v git 2>/dev/null || true)
if [[ -n "$REAL_GIT" ]]; then
  exec "$REAL_GIT" "$@"
fi

printf 'git shim: unhandled: %s\n' "$*" >&2
exit 1
SHIM
  chmod +x "$shim_bin/git"

  export PATH="$shim_bin:$PATH"

  # Pre-seed the commit-subject rotation state so a single call with
  # "# ack-rule4:essentie" passes without a first-call denial.
  # State format: pv / pr / rp (three lines).
  #   pv=-1 : no pending violation
  #   pr=3  : rotation for rule 4 (slot index 3, 0-based rule index) pending
  #   rp=0  : rotation position 0
  # With this state a clean subject + "# ack-rule4:essentie" passes immediately.
  local _state_file="$BATS_TEST_TMPDIR/commit-rule-state"
  printf '%s\n%s\n%s\n' '-1' '3' '0' > "$_state_file"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$_state_file"
}

teardown() {
  : # BATS_TEST_TMPDIR is cleaned up automatically by bats-core.
}

# ---------------------------------------------------------------------------
# Input builder helpers
# ---------------------------------------------------------------------------

# pretool_bash_json <bash-command-string>
# Emit the JSON that dispatch.sh expects on stdin for a PreToolUse:Bash event.
pretool_bash_json() {
  local cmd="$1"
  jq -cn --arg c "$cmd" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'
}

# run_dispatch <bash-command-string>
# Pass a PreToolUse:Bash event through dispatch.sh.
# Sets $status, $output, $dispatch_stdout.
run_dispatch() {
  local cmd="$1"
  local json
  json=$(pretool_bash_json "$cmd")
  run bash "$DISPATCH" <<< "$json"
}

# commit_cmd_simple <subject>
# Build a simple -m commit command string.
commit_cmd_simple() {
  printf 'git commit -m "%s"' "$1"
}

# commit_cmd_heredoc <subject> <body>
# Build a heredoc-style commit command string (the pattern Claude Code uses).
commit_cmd_heredoc() {
  local subject="$1"
  local body="$2"
  printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\n%s\n\n%s\nEOF\n)"' "$subject" "$body"
}

# shadow_log_line_count
# Return the number of lines currently in the shadow log.
shadow_log_line_count() {
  if [[ ! -f "$GIT_DISCIPLINE_SHADOW_LOG" ]]; then
    printf '0'
    return
  fi
  wc -l < "$GIT_DISCIPLINE_SHADOW_LOG" | tr -d ' '
}

# ---------------------------------------------------------------------------
# Standard valid-body trailer set (shimmed via GIT_SHIM_INTERPRET_TRAILERS_OUTPUT)
# ---------------------------------------------------------------------------

VALID_TRAILERS="$(printf 'Tests: spec/services/session_spec.rb\nSlice: handler + service + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')"

VALID_BODY="$(cat <<'BODY'
Expose session boundary on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation, we previously rejected
the entire event, which masked session starts and stops in analytics.

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
BODY
)"
