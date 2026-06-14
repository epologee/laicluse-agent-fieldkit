#!/bin/bash
# Single entry point for all dont-do-that hooks. Registered against
# PreToolUse (Bash|file-edit tools), PostToolUse (Bash|file-edit tools), and
# Stop in hooks.json.
# Routes to the right guard set based on hook_event_name in the stdin JSON.

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/common.sh"

INPUT=$(cat)
EVENT=$(dd_event "$INPUT")

case "$EVENT" in
  PreToolUse)
    TOOL=$(dd_tool_name "$INPUT")
    case "$TOOL" in
      Bash)
        source "$DIR/guards/no-remote.sh"
        guard_no_remote "$INPUT"
        source "$DIR/guards/no-remote-create.sh"
        guard_no_remote_create "$INPUT"
        source "$DIR/guards/no-worktree-deploy.sh"
        guard_no_worktree_deploy "$INPUT"
        source "$DIR/guards/pr-discipline.sh"
        guard_pr_discipline "$INPUT"
        source "$DIR/guards/followup.sh"
        guard_followup "$INPUT"
        ;;
      Edit|Write|MultiEdit|apply_patch)
        source "$DIR/guards/no-code-comments.sh"
        guard_no_code_comments "$INPUT"
        ;;
    esac
    ;;

  PostToolUse)
    TOOL=$(dd_tool_name "$INPUT")
    case "$TOOL" in
      Edit|Write|MultiEdit|Bash|apply_patch)
        source "$DIR/guards/dash.sh"
        guard_dash "$INPUT"
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
    source "$DIR/guards/false-claims.sh"
    source "$DIR/guards/tool-error.sh"

    FC_OUTPUT=$( guard_false_claims "$INPUT" )
    TE_OUTPUT=$( guard_tool_error "$INPUT" )

    if [ -n "$FC_OUTPUT" ]; then
      echo "$FC_OUTPUT"
      exit 0
    fi
    if [ -n "$TE_OUTPUT" ]; then
      echo "$TE_OUTPUT"
      exit 0
    fi

    # Mutex-respecting guards. If a prior Stop fire already blocked, skip
    # these to avoid re-blocking on the same text across consecutive fires.
    if ! dd_stop_active "$INPUT"; then
      source "$DIR/guards/cache.sh"
      source "$DIR/guards/estimate.sh"
      source "$DIR/guards/premature.sh"
      source "$DIR/guards/verify.sh"
      source "$DIR/guards/duh.sh"
      source "$DIR/guards/compliance.sh"
      source "$DIR/guards/prefer.sh"
      source "$DIR/guards/jargon.sh"
      guard_cache "$INPUT"
      guard_estimate "$INPUT"
      guard_prefer "$INPUT"
      guard_premature "$INPUT"
      guard_verify "$INPUT"
      guard_duh "$INPUT"
      guard_compliance "$INPUT"
      guard_jargon "$INPUT"
    fi
    ;;
esac

exit 0
