#!/bin/bash
# PreToolUse:Bash guard for gh pr create / gh pr edit. allow-comment: hook-header documenting the matchers and the operator escape, same pattern as sibling no-remote-create.sh. Blocks when the title uses a placement-verb dodge (git-discipline Rule 1 vocabulary) or the body carries fixed-section/AI-attribution template signatures (## Summary / ## Test plan headers, Generated with Claude Code footer, Co-Authored-By trailer with an @anthropic.com email). PR-time enforcement closes the gap left by the git-discipline commit-subject and commit-trailers guards, which fire on git commit but never on gh pr create.

guard_pr_discipline() {
  local input="$1"
  local cmd
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0

  local cmd_after_cd
  cmd_after_cd=$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*cd[[:space:]]+[^&]+&&[[:space:]]*//')
  [[ "$cmd_after_cd" =~ ^[[:space:]]*gh[[:space:]]+pr[[:space:]]+(create|edit)([[:space:]]|$) ]] || return 0

  local title
  title=$(grep -oE -- "--title[[:space:]]+(\"[^\"]*\"|'[^']*'|[^[:space:]]+)" <<< "$cmd" \
    | head -1 \
    | sed -E "s/^--title[[:space:]]+//; s/^[\"']//; s/[\"']$//")

  if [ -n "$title" ]; then
    local activity_re='^(Fix|Improve|Update|Change|Refactor|Add|Extract|Move|Remove|Rename|Drop|Create|Clear|Land|Make|Work|Do|Get|Tweak|Surface|Address|Apply|Plant|Place|Pin|Lay|Anchor|Set|Stand|Mount|Install|Ship|Bring|Wire|Hook|Sow|Ground)[[:space:]]'
    shopt -s nocasematch
    if [[ "$title " =~ $activity_re ]]; then
      shopt -u nocasematch
      dd_emit_deny pr-discipline "PR title '${title}' starts with a placement or git-action verb (git-discipline Rule 1 vocabulary). PR titles describe the user-visible capability that exists now, not the placement action that landed it. Rewrite so the title answers 'what can the system do now that it could not before?'."
    fi
    shopt -u nocasematch
  fi

  if grep -qE '##[[:space:]]+(Summary|Test plan)[[:space:]]*$' <<< "$cmd"; then
    dd_emit_deny pr-discipline "PR body contains '## Summary' or '## Test plan' header. The body should be one or two paragraphs about why the change matters, not a fixed-section template."
  fi

  if grep -qE '(Generated with \[?Claude Code|🤖[[:space:]]+Generated with)' <<< "$cmd"; then
    dd_emit_deny pr-discipline "PR body contains the 'Generated with Claude Code' footer. That signals AI authorship to the reviewer in a way the operator does not want; remove it."
  fi

  if grep -qE 'Co-Authored-By:[[:space:]]+[^<]*<[^>]*@anthropic\.com>' <<< "$cmd"; then
    dd_emit_deny pr-discipline "PR body contains a Co-Authored-By trailer with an @anthropic.com email. Remove the trailer; the change is the operator's, not a co-authored work."
  fi
}
