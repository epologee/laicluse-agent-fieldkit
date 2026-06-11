#!/usr/bin/env bats
# packages/git-discipline/test/sentinel-protect/sentinel-protect.bats
#
# The enable/disable sentinel files are operator territory. An agent-driven
# Bash call that creates or removes a git-discipline-disabled-* sentinel is
# denied, in both directions (disabling the guards AND re-enabling them).
# Read-only inspection of the sentinel paths (discipline-status) stays open.
# The guard runs with the safety locks, BEFORE the early sentinel exit, so a
# session whose discipline is already off cannot quietly flip it back on.

load ../session-toggle/helpers

@test "touch of the session sentinel is denied" {
  run_dispatch_with_session \
    'touch "$HOME/.laicluse/git-discipline/git-discipline-disabled-test-session-abc"' \
    "test-session-abc"

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/sentinel-protect]"* ]]
}

@test "touch of the global sentinel is denied" {
  run_dispatch_no_session \
    'mkdir -p "$HOME/.laicluse/git-discipline" && touch "$HOME/.laicluse/git-discipline/git-discipline-disabled-global"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/sentinel-protect]"* ]]
}

@test "rm of an existing sentinel is denied even though discipline is off" {
  local sid="test-session-flip"
  write_session_sentinel "$sid"

  run_dispatch_with_session \
    "rm \"\$HOME/.laicluse/git-discipline/git-discipline-disabled-$sid\"" \
    "$sid"

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/sentinel-protect]"* ]]
}

@test "rm of the global sentinel is denied" {
  write_global_sentinel

  run_dispatch_no_session \
    'rm -f "$HOME/.laicluse/git-discipline/git-discipline-disabled-global"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/sentinel-protect]"* ]]
}

@test "shell redirection into a sentinel path is denied" {
  run_dispatch_no_session \
    ': > "$HOME/.laicluse/git-discipline/git-discipline-disabled-global"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/sentinel-protect]"* ]]
}

@test "mv onto a sentinel path is denied" {
  run_dispatch_no_session \
    'mv /tmp/scratch "$HOME/.laicluse/git-discipline/git-discipline-disabled-global"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/sentinel-protect]"* ]]
}

@test "writing the per-repo git lock sentinel is denied" {
  run_dispatch_no_session \
    'printf "%s\n" "hands off" > .git/git-discipline-deny'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/sentinel-protect]"* ]]
}

@test "rm of the per-repo git lock sentinel is denied" {
  run_dispatch_no_session 'rm .git/git-discipline-deny'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/sentinel-protect]"* ]]
}

@test "read-only check of the per-repo git lock sentinel is allowed" {
  run_dispatch_no_session \
    '[ -f .git/git-discipline-deny ] && cat .git/git-discipline-deny || echo unlocked'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/sentinel-protect]"* ]]
}

@test "read-only inspection of sentinel paths is allowed" {
  run_dispatch_no_session \
    'ls "$HOME/.laicluse/git-discipline/" 2>/dev/null; [ -f "$HOME/.laicluse/git-discipline/git-discipline-disabled-global" ] && echo DISABLED || echo ACTIVE'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/sentinel-protect]"* ]]
}

@test "an unrelated rm does not trip the guard" {
  run_dispatch_no_session 'rm -f /tmp/some-scratch-file'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/sentinel-protect]"* ]]
}
