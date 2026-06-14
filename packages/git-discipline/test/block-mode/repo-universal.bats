#!/usr/bin/env bats
# repo-universal.bats
# In block-mode the guard fires on ALL repos, not just the laicluse-agent-fieldkit
# repo. The shadow log still gets an entry for every violation regardless of
# origin URL.

load helpers

@test "non-laicluse-agent-fieldkit repo URL still triggers block-mode denial" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/someorg/otheproject.git"
  export GIT_SHIM_SHORTSTAT=" 5 files changed, 40 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb\nc.rb\nd.rb\ne.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Session boundary for other project" # ack-rule4:essentie'

  # Block-mode: must deny (exit 2).
  [ "$status" -eq 2 ]
}

@test "laicluse-agent-fieldkit repo URL also triggers block-mode denial" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/epologee/laicluse-agent-fieldkit.git"
  export GIT_SHIM_SHORTSTAT=" 3 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb\nc.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Extend laicluse-agent-fieldkit plugin" # ack-rule4:essentie'

  [ "$status" -eq 2 ]
}

@test "shadow log gets an entry for a non-laicluse-agent-fieldkit violation" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/acme/other-repo.git"
  export GIT_SHIM_SHORTSTAT=" 5 files changed, 40 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb\nc.rb\nd.rb\ne.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  local before
  before=$(shadow_log_line_count)

  run_dispatch 'git commit -m "Session boundary for acme project" # ack-rule4:essentie'

  local after
  after=$(shadow_log_line_count)

  # Shadow log must have grown by exactly one entry.
  [ "$after" -eq $((before + 1)) ]
}

@test "empty remote URL still triggers block-mode denial" {
  export GIT_SHIM_ORIGIN_URL=""
  export GIT_SHIM_SHORTSTAT=" 5 files changed, 40 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb\nc.rb\nd.rb\ne.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Some commit no body" # ack-rule4:essentie'

  [ "$status" -eq 2 ]
}
