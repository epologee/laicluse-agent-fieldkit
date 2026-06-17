#!/bin/bash
# Single entry point for all dont-do-that hooks. Registered against
# PreToolUse (Bash|file-edit tools), PostToolUse (Bash|file-edit tools), and
# Stop in hooks.json.
# Routes to the right guard set based on hook_event_name in the stdin JSON.

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/common.sh"

INPUT=$(cat)
EVENT=$(dd_event "$INPUT")

run_pre_bash() {
  if dd_guard_enabled no-remote PreToolUse; then
    source "$DIR/guards/no-remote.sh"
    guard_no_remote "$INPUT"
  fi
  if dd_guard_enabled no-remote-create PreToolUse; then
    source "$DIR/guards/no-remote-create.sh"
    guard_no_remote_create "$INPUT"
  fi
  if dd_guard_enabled no-worktree-deploy PreToolUse; then
    source "$DIR/guards/no-worktree-deploy.sh"
    guard_no_worktree_deploy "$INPUT"
  fi
  if dd_guard_enabled pr-discipline PreToolUse; then
    source "$DIR/guards/pr-discipline.sh"
    guard_pr_discipline "$INPUT"
  fi
  if dd_guard_enabled followup PreToolUse; then
    source "$DIR/guards/followup.sh"
    guard_followup "$INPUT"
  fi
}

run_pre_edit() {
  if dd_guard_enabled no-code-comments PreToolUse; then
    source "$DIR/guards/no-code-comments.sh"
    guard_no_code_comments "$INPUT"
  fi
}

run_post_tool() {
  local dash_output="" land_output=""
  if dd_guard_enabled dash PostToolUse; then
    source "$DIR/guards/dash.sh"
    dash_output=$( guard_dash "$INPUT" )
  fi
  if dd_guard_enabled land PostToolUse; then
    source "$DIR/guards/land.sh"
    land_output=$( guard_land "$INPUT" )
  fi
  if [ -n "$dash_output" ]; then
    echo "$dash_output"
    exit 0
  fi
  if [ -n "$land_output" ]; then
    echo "$land_output"
    exit 0
  fi
}

run_stop_tracked_guards() {
  local false_claims_output="" tool_error_output=""
  if dd_guard_enabled false-claims Stop; then
    source "$DIR/guards/false-claims.sh"
    false_claims_output=$( guard_false_claims "$INPUT" )
  fi
  if dd_guard_enabled tool-error Stop; then
    source "$DIR/guards/tool-error.sh"
    tool_error_output=$( guard_tool_error "$INPUT" )
  fi

  if [ -n "$false_claims_output" ]; then
    echo "$false_claims_output"
    exit 0
  fi
  if [ -n "$tool_error_output" ]; then
    echo "$tool_error_output"
    exit 0
  fi
}

run_stop_mutex_guards() {
  if dd_guard_enabled cache Stop; then
    source "$DIR/guards/cache.sh"
    guard_cache "$INPUT"
  fi
  if dd_guard_enabled estimate Stop; then
    source "$DIR/guards/estimate.sh"
    guard_estimate "$INPUT"
  fi
  if dd_guard_enabled prefer Stop; then
    source "$DIR/guards/prefer.sh"
    guard_prefer "$INPUT"
  fi
  if dd_guard_enabled premature Stop; then
    source "$DIR/guards/premature.sh"
    guard_premature "$INPUT"
  fi
  if dd_guard_enabled verify Stop; then
    source "$DIR/guards/verify.sh"
    guard_verify "$INPUT"
  fi
  if dd_guard_enabled duh Stop; then
    source "$DIR/guards/duh.sh"
    guard_duh "$INPUT"
  fi
  if dd_guard_enabled compliance Stop; then
    source "$DIR/guards/compliance.sh"
    guard_compliance "$INPUT"
  fi
  if dd_guard_enabled jargon Stop; then
    source "$DIR/guards/jargon.sh"
    guard_jargon "$INPUT"
  fi
}

case "$EVENT" in
  PreToolUse)
    TOOL=$(dd_tool_name "$INPUT")
    case "$TOOL" in
      Bash)
	run_pre_bash
        ;;
      Edit|Write|MultiEdit|apply_patch)
	run_pre_edit
        ;;
    esac
    ;;

  PostToolUse)
    TOOL=$(dd_tool_name "$INPUT")
    case "$TOOL" in
      Edit|Write|MultiEdit|Bash|apply_patch)
	run_post_tool
        ;;
    esac
    ;;

  Stop)
    # allow-comment: headless `claude -p` returns its last turn as the result, so any Stop-block forces a nudge-turn that overwrites it; DD_HEADLESS opts the whole Stop set out while PreToolUse safety stays on.
    [ -n "$DD_HEADLESS" ] && exit 0
    # false-claims and tool-error run in subshells so that an emit + exit in
    # one of them does not prevent the other from updating its own
    # per-session state on the same fire. Pre-refactor they
    # were separate processes with independent lifecycles; preserve that by
    # subshelling here. First non-empty output wins, in hooks.json order
    # (false-claims before tool-error).
    run_stop_tracked_guards

    # Mutex-respecting guards. If a prior Stop fire already blocked, skip
    # these to avoid re-blocking on the same text across consecutive fires.
    if ! dd_stop_active "$INPUT"; then
      run_stop_mutex_guards
    fi
    ;;
esac

exit 0
