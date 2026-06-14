#!/usr/bin/env bats
# repo-detect.bats
# Verifies that the shadow log receives an entry for violations regardless of
# the repo origin URL (block-mode is universal). The repo-gate from slice 3
# is gone; this file now tests the shadow-log writing side effect.

load helpers

@test "laicluse-agent-fieldkit repo URL: violation still writes to shadow log" {
  export GIT_SHIM_ORIGIN_URL="git@github.com:epologee/laicluse-agent-fieldkit.git"
  export GIT_SHIM_SHORTSTAT=" 5 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb\nc.rb\nd.rb\ne.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  local before
  before=$(shadow_log_line_count)

  # run with || true: dispatch exits 2 (deny), bats run captures status.
  run_dispatch 'git commit -m "Expose session endpoint" # ack-rule4:essentie'

  # Block-mode: denied.
  [ "$status" -eq 2 ]

  # Shadow log must have grown.
  local after
  after=$(shadow_log_line_count)
  [ "$after" -eq $((before + 1)) ]
}

@test "laicluse-agent-fieldkit HTTPS URL: violation writes to shadow log" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/epologee/laicluse-agent-fieldkit.git"
  export GIT_SHIM_SHORTSTAT=" 3 files changed, 15 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'x.rb\ny.rb\nz.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  local before
  before=$(shadow_log_line_count)

  run_dispatch 'git commit -m "Expose unused import path" # ack-rule4:essentie'

  [ "$status" -eq 2 ]

  local after
  after=$(shadow_log_line_count)
  [ "$after" -eq $((before + 1)) ]
}

@test "other-repo URL: violation also writes to shadow log (universal)" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/someorg/otherrepo.git"
  export GIT_SHIM_SHORTSTAT=" 5 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb\nc.rb\nd.rb\ne.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  local before
  before=$(shadow_log_line_count)

  run_dispatch 'git commit -m "Expose session endpoint" # ack-rule4:essentie'

  # Block-mode denies all repos.
  [ "$status" -eq 2 ]

  # Shadow log grows even for non-laicluse-agent-fieldkit repos.
  local after
  after=$(shadow_log_line_count)
  [ "$after" -eq $((before + 1)) ]
}

@test "valid commit: no shadow log entry regardless of repo" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/someorg/otherrepo.git"
  export GIT_SHIM_SHORTSTAT=" 5 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb\nc.rb\nd.rb\ne.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$VALID_TRAILERS"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"

  local before
  before=$(shadow_log_line_count)

  local cmd
  cmd=$(commit_cmd_heredoc \
    "Expose session boundary on transaction events" \
    "$(printf 'When StartTransaction or StopTransaction messages arrive with a\nmeter reading that fails domain validation, we previously rejected\nthe entire event, which masked session starts and stops in analytics.\n\nTests: spec/services/session_spec.rb\nSlice: handler + service + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')")
  cmd="$cmd # ack-rule4:essentie"

  run_dispatch "$cmd"

  [ "$status" -eq 0 ]

  local after
  after=$(shadow_log_line_count)
  [ "$after" -eq "$before" ]
}
