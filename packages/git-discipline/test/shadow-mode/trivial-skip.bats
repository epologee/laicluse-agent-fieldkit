#!/usr/bin/env bats
# trivial-skip.bats
# Commits that touch <= 1 file AND <= 5 insertions are trivial and skip
# body validation silently (no denial, no log entry).
# Commits that exceed either threshold are denied in block-mode.

load helpers

@test "1-file 3-insertion commit without body skips silently" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/epologee/laicluse-agent-fieldkit.git"
  export GIT_SHIM_SHORTSTAT=" 1 file changed, 3 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="README.md"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  local before
  before=$(shadow_log_line_count)

  run_dispatch 'git commit -m "Readme typo on the install snippet" # ack-rule4:essentie'

  # Trivial: must pass.
  [ "$status" -eq 0 ]
  # No log entry.
  local after
  after=$(shadow_log_line_count)
  [ "$after" -eq "$before" ]
}

@test "1-file 5-insertion commit (boundary) also skips silently" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/epologee/laicluse-agent-fieldkit.git"
  export GIT_SHIM_SHORTSTAT=" 1 file changed, 5 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="lib/helper.rb"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  local before
  before=$(shadow_log_line_count)

  run_dispatch 'git commit -m "Guard against nil on session close" # ack-rule4:essentie'

  [ "$status" -eq 0 ]
  local after
  after=$(shadow_log_line_count)
  [ "$after" -eq "$before" ]
}

@test "2-file 3-insertion commit (too many files) is denied in block-mode" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/epologee/laicluse-agent-fieldkit.git"
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 3 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Expose session endpoint" # ack-rule4:essentie'

  [ "$status" -eq 2 ]
}

@test "1-file 6-insertion commit (too many insertions) is denied in block-mode" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/epologee/laicluse-agent-fieldkit.git"
  export GIT_SHIM_SHORTSTAT=" 1 file changed, 6 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="lib/big.rb"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Expose session endpoint" # ack-rule4:essentie'

  [ "$status" -eq 2 ]
}
