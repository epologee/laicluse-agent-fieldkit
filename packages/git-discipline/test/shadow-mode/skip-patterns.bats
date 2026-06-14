#!/usr/bin/env bats
# skip-patterns.bats
# Auto-generated commit subjects (Merge / Revert / fixup! / squash! / amend!)
# must bypass body validation entirely even in block-mode.

load helpers

setup() {
  # Delegate to the shared setup from helpers.bash, then override to a
  # non-trivial diff so the trivial shortcut cannot mask a skip-pattern failure.
  # Note: helpers.bash defines its own setup(); we inline the shared logic here
  # because BATS does not support calling the parent setup() by name.
  local shim_bin="$BATS_TEST_TMPDIR/bin"
  install -d "$shim_bin" 2>/dev/null || true

  cat > "$shim_bin/git" <<'SHIM'
#!/usr/bin/env bash
args=("$@")
if [[ "${args[0]}" = "config" && "${args[*]}" =~ "remote.origin.url" ]]; then printf '%s\n' "$GIT_SHIM_ORIGIN_URL"; exit 0; fi
if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--shortstat" ]]; then printf '%s\n' "$GIT_SHIM_SHORTSTAT"; exit 0; fi
if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--name-only" ]]; then printf '%s\n' "$GIT_SHIM_DIFF_NAMES"; exit 0; fi
if [[ "${args[0]}" = "interpret-trailers" ]]; then printf '%s' "$GIT_SHIM_INTERPRET_TRAILERS_OUTPUT"; exit 0; fi
if [[ "${args[0]}" = "ls-tree" ]]; then printf '%s' "$GIT_SHIM_LS_TREE_OUTPUT"; exit 0; fi
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%H" ]]; then [[ -n "$GIT_SHIM_LOG_HASHES" ]] && printf '%s\n' "$GIT_SHIM_LOG_HASHES"; exit 0; fi
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%B" ]]; then printf '%s\n' "$GIT_SHIM_LOG_BODY"; exit 0; fi
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--abbrev-ref" ]]; then printf '%s\n' "$GIT_SHIM_HEAD_ABBREV"; exit 0; fi
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--short" ]]; then printf '%s\n' "$GIT_SHIM_HEAD_SHORT"; exit 0; fi
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "HEAD" ]]; then printf 'abc1234def5678\n'; exit 0; fi
REAL=$(PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin" command -v git 2>/dev/null || true)
[[ -n "$REAL" ]] && exec "$REAL" "$@"
printf 'git shim: unhandled: %s\n' "$*" >&2; exit 1
SHIM
  chmod +x "$shim_bin/git"
  export PATH="$shim_bin:$PATH"

  # Pre-seed rotation state (pv=-1, pr=3, rp=0) so ack-rule4 passes.
  local _state_file="$BATS_TEST_TMPDIR/commit-rule-state"
  printf '%s\n%s\n%s\n' '-1' '3' '0' > "$_state_file"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$_state_file"

  # Non-trivial diff so the trivial shortcut cannot mask a skip-pattern failure.
  export GIT_SHIM_ORIGIN_URL="https://github.com/epologee/laicluse-agent-fieldkit.git"
  export GIT_SHIM_SHORTSTAT=" 10 files changed, 100 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb\nc.rb\nd.rb\ne.rb\nf.rb\ng.rb\nh.rb\ni.rb\nj.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  export GIT_SHIM_LOG_HASHES=""
  export GIT_SHIM_LOG_BODY=""
  export GIT_SHIM_HEAD_ABBREV="main"
  export GIT_SHIM_HEAD_SHORT="abc1234"
}

@test "Merge subject skips silently: no warn, no log entry" {
  local before
  before=$(shadow_log_line_count)

  run_dispatch "git commit -m \"Merge branch 'feature/x' into main\" # ack-rule4:essentie"

  [ "$status" -eq 0 ]
  [[ "$output" != *'commit-body'* ]]
  local after
  after=$(shadow_log_line_count)
  [ "$after" -eq "$before" ]
}

@test "Revert subject skips silently: no warn, no log entry" {
  local before
  before=$(shadow_log_line_count)

  run_dispatch 'git commit -m "Revert \"Expose session endpoint\"" # ack-rule4:essentie'

  [ "$status" -eq 0 ]
  [[ "$output" != *'commit-body'* ]]
  local after
  after=$(shadow_log_line_count)
  [ "$after" -eq "$before" ]
}

@test "fixup! subject skips silently: no warn, no log entry" {
  local before
  before=$(shadow_log_line_count)

  run_dispatch 'git commit -m "fixup! Expose session endpoint" # ack-rule4:essentie'

  [ "$status" -eq 0 ]
  [[ "$output" != *'commit-body'* ]]
  local after
  after=$(shadow_log_line_count)
  [ "$after" -eq "$before" ]
}

@test "squash! subject skips silently: no warn, no log entry" {
  local before
  before=$(shadow_log_line_count)

  run_dispatch 'git commit -m "squash! Expose session endpoint" # ack-rule4:essentie'

  [ "$status" -eq 0 ]
  [[ "$output" != *'commit-body'* ]]
  local after
  after=$(shadow_log_line_count)
  [ "$after" -eq "$before" ]
}

@test "amend! subject skips silently: no warn, no log entry" {
  local before
  before=$(shadow_log_line_count)

  run_dispatch 'git commit -m "amend! Expose session endpoint" # ack-rule4:essentie'

  [ "$status" -eq 0 ]
  [[ "$output" != *'commit-body'* ]]
  local after
  after=$(shadow_log_line_count)
  [ "$after" -eq "$before" ]
}
