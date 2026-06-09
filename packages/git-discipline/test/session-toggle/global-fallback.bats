#!/usr/bin/env bats
# packages/git-discipline/test/session-toggle/global-fallback.bats
#
# When the JSON input has no session_id (e.g. older Claude Code version or
# a context where session_id is not injected), dispatch.sh checks the global
# sentinel at ${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-disabled-global. If that file exists, all
# guards are suppressed for every session until it is removed.

load helpers

@test "global sentinel present, no session_id: dispatch exits 0 silently" {
  write_global_sentinel

  run_dispatch_no_session \
    'git commit -m "bad commit no body" # ack-rule4:essentie'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/"* ]]
}

@test "global sentinel absent, no session_id: guards run normally" {
  export GIT_SHIM_SHORTSTAT=" 3 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/foo.rb\napp/models/bar.rb\nspec/models/foo_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch_no_session \
    'git commit -m "bare subject no body" # ack-rule4:essentie'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/commit-body]"* ]]
}

@test "global sentinel present even when session_id is present: dispatch exits 0" {
  write_global_sentinel

  # Provide a session_id too, but no session-specific sentinel.
  run_dispatch_with_session \
    'git commit -m "bad commit no body" # ack-rule4:essentie' \
    "some-session-xyz"

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/"* ]]
}
