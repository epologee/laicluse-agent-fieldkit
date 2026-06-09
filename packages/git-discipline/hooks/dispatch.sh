#!/bin/bash
# allow-comment: Single entry point for git-discipline hooks. PreToolUse:Bash carries safety locks (dash-c, config-override, repo-deny), the push-time gates (wip + body), the rotation-reminder layer (commit-subject), and the commit-message nudge layer (commit-format, commit-body, commit-trailers). The nudge layer emits additionalContext via dd_emit_pre_context instead of denying so the commit lands and Claude amends silently.

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/common.sh"
source "$DIR/lib/version-skew.sh"

INPUT=$(cat)
EVENT=$(dd_event "$INPUT")

case "$EVENT" in
  PreToolUse)
    TOOL=$(dd_tool_name "$INPUT")
    [ "$TOOL" = "Bash" ] || exit 0

    dd_git_discipline_version_skew "$INPUT"

    dd_cd_to_bash_target "$INPUT"

    source "$DIR/guards/git-dash-c.sh"
    source "$DIR/guards/git-config-override.sh"
    source "$DIR/guards/repo-deny.sh"
    guard_git_dash_c "$INPUT"
    guard_git_config_override "$INPUT"
    guard_repo_deny "$INPUT"

    SESSION_ID=$(dd_session_id "$INPUT")
    if [[ -n "$SESSION_ID" ]] && [[ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-$SESSION_ID" ]]; then
      exit 0
    fi
    if [[ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-global" ]]; then
      exit 0
    fi

    source "$DIR/lib/validate-body.sh"
    source "$DIR/lib/example-synth.sh"
    source "$DIR/guards/git-first-contact.sh"
    guard_git_first_contact "$INPUT"

    source "$DIR/guards/push-wip-gate.sh"
    source "$DIR/guards/push-body-gate.sh"
    guard_push_wip_gate "$INPUT"
    guard_push_body_gate "$INPUT"

    source "$DIR/guards/commit-subject.sh"
    source "$DIR/guards/commit-format.sh"
    source "$DIR/guards/commit-body.sh"
    source "$DIR/guards/commit-trailers.sh"
    # allow-comment: run the commit-message guards via _dd_run_collect so a
    # allow-comment: deny from one guard does not short-circuit the others;
    # allow-comment: all four pass against the same commit message and the
    # allow-comment: operator sees subject + format + body issues in one
    # allow-comment: aggregated deny block (eliminates per-violation amend
    # allow-comment: cycles that the old short-circuit imposed).
    DD_DENY_MESSAGES=()
    _dd_run_collect guard_commit_subject "$INPUT"
    _dd_run_collect guard_commit_format "$INPUT"
    _dd_run_collect guard_commit_body "$INPUT"
    _dd_run_collect guard_commit_trailers "$INPUT"
    if [ "${#DD_DENY_MESSAGES[@]}" -gt 0 ]; then
      for _dd_deny_msg in "${DD_DENY_MESSAGES[@]}"; do
        printf '%s\n' "$_dd_deny_msg" >&2
      done
      exit 2
    fi
    ;;

  PostToolUse)
    TOOL=$(dd_tool_name "$INPUT")
    [ "$TOOL" = "Bash" ] || exit 0

    SESSION_ID=$(dd_session_id "$INPUT")
    if [[ -n "$SESSION_ID" ]] && [[ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-$SESSION_ID" ]]; then
      exit 0
    fi
    if [[ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-global" ]]; then
      exit 0
    fi

    source "$DIR/guards/commit-subject.sh"
    guard_commit_subject_posttool "$INPUT"
    ;;
esac

exit 0
