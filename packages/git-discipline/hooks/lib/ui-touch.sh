#!/bin/bash
# packages/git-discipline/hooks/lib/ui-touch.sh
#
# Single-purpose lib: classify the staged diff as UI-touched or not.
# Sourced by validate-body.sh (Visual trailer rule), example-synth.sh
# (synthesised template Visual line), and the git-native prepare-commit-msg
# hook (template Visual line).
#
# Public functions:
#
#   _vb_ui_touched_files
#     Echoes a newline-separated list of staged paths that match the
#     UI-touch heuristic, or empty when no UI is touched. Reads `git diff
#     --cached --name-only` once per call. Callers that need a single-line
#     display join with their own separator (the validator uses ", ").
#
#   _vb_is_ui_touch
#     Convenience wrapper: returns 0 when at least one path is UI-touched,
#     1 otherwise. Equivalent to `[[ -n "$(_vb_ui_touched_files)" ]]`.
#
# Heuristic detail. UI extensions (definitely UI):
#   .tsx .jsx .vue .svelte .html .htm
#   .css .scss .sass .less
#   .erb .haml .slim
#   .storyboard .xib
#   plus any path under a *.xcassets/ directory.
#
# Swift content-grep (.swift only): the staged blob (`git show :<path>`) is
# inspected for SwiftUI / UIKit / AppKit symbols. The boundary patterns
# (`: View([^A-Za-z0-9_]|$)` etc.) match `: View {`, `: View,`, and the
# dominant `: View<EOL>{` form while excluding longer identifiers like
# `ViewModifier`. When `git show :<path>` returns nothing (file not staged
# as a blob, e.g. partial amend), the Swift file is conservatively NOT
# treated as UI; operators opt in via `Visual: n/a (rationale)` if needed.

# Note: no `set -euo pipefail` here. This file is sourced as a library by
# multiple callers (the validator, example-synth, prepare-commit-msg, BATS
# harnesses). Each caller controls its own errexit/pipefail. The functions
# below handle non-zero returns explicitly via conditionals.

_VB_UI_LIB_DIR_CTX="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if ! declare -F _vb_delta_files >/dev/null 2>&1; then
  . "$_VB_UI_LIB_DIR_CTX/vb-context.sh"
fi

# allow-comment: load-bearing WHY. Build-output marked git-discipline-generated in .gitattributes is exempt from the Visual/UI gate so regenerating it does not demand a fresh screenshot; hand-authored UI still counts. Opt-in per repo, backward-compatible when the attribute is absent.
_vb_is_generated() {
  local f="$1" attr
  attr=$(git check-attr git-discipline-generated -- "$f" 2>/dev/null) || return 1
  case "$attr" in
    *": git-discipline-generated: true"|*": git-discipline-generated: set") return 0 ;;
  esac
  return 1
}

_vb_ui_touched_files() {
  local staged
  staged=$(_vb_delta_files)
  [[ -z "$staged" ]] && return 0

  # Newline-separated output keeps filenames with embedded commas or spaces
  # intact; consumers join with their own separator for display.
  local f
  local matches=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    _vb_is_generated "$f" && continue  # allow-comment: generated output exempt from UI gate
    case "$f" in
      *.tsx|*.jsx|*.vue|*.svelte|*.html|*.htm) matches+="${matches:+$'\n'}$f" ;;
      *.css|*.scss|*.sass|*.less)              matches+="${matches:+$'\n'}$f" ;;
      *.erb|*.haml|*.slim)                     matches+="${matches:+$'\n'}$f" ;;
      *.storyboard|*.xib)                      matches+="${matches:+$'\n'}$f" ;;
      *.xcassets/*)                            matches+="${matches:+$'\n'}$f" ;;
      *.swift)
        # Two passes. First the staged blob; this is what the commit will
        # actually carry. Second the working-tree file as a backstop so
        # `git add -p` (partial-stage of a non-UI hunk in a UI file) does
        # not silently classify a SwiftUI view as backend. False positives
        # from the working-tree pass (e.g., staged content has UI removed
        # but the working tree still shows it) are absorbed by Visual: n/a
        # (rationale); false negatives from the staged-only pass were
        # silent and harder to recover from.
        local content_staged=""
        content_staged=$(_vb_show_blob "$f")
        local _matched=0
        if printf '%s' "$content_staged" \
            | grep -qE '(import SwiftUI|import UIKit|import AppKit|: View([^A-Za-z0-9_]|$)|: UIView([^A-Za-z0-9_]|$)|: NSView([^A-Za-z0-9_]|$)|UIViewController|NSViewController)'; then
          _matched=1
        elif [[ -f "$f" ]] && grep -qE \
            '(import SwiftUI|import UIKit|import AppKit|: View([^A-Za-z0-9_]|$)|: UIView([^A-Za-z0-9_]|$)|: NSView([^A-Za-z0-9_]|$)|UIViewController|NSViewController)' \
            "$f" 2>/dev/null; then
          _matched=1
        fi
        if [[ "$_matched" -eq 1 ]]; then
          matches+="${matches:+$'\n'}$f"
        fi
        ;;
    esac
  done <<< "$staged"

  printf '%s' "$matches"
}

_vb_is_ui_touch() {
  [[ -n "$(_vb_ui_touched_files)" ]]
}
