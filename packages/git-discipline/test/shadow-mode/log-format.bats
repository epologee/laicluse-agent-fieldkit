#!/usr/bin/env bats
# log-format.bats
# Verify that shadow log entries conform to the expected pipe-delimited format
# and that the log directory is created automatically when it does not exist.
# In block-mode violations also exit 2 (deny), but the shadow log is still
# written as a parallel audit record.

load helpers

@test "log line format matches <ISO-timestamp>|<sha>|<branch>|<code>|<subject>" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/epologee/laicluse-agent-fieldkit.git"
  export GIT_SHIM_SHORTSTAT=" 5 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb\nc.rb\nd.rb\ne.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""
  export GIT_SHIM_HEAD_SHORT="cafe123"
  export GIT_SHIM_HEAD_ABBREV="feature/log-test"

  # Block-mode exits 2 on violation; run captures it without failing the test.
  run_dispatch 'git commit -m "Expose session endpoint" # ack-rule4:essentie'

  # Block-mode: denied.
  [ "$status" -eq 2 ]

  # The shadow log must exist and have at least one entry.
  [ -f "$GIT_DISCIPLINE_SHADOW_LOG" ]
  local line_count
  line_count=$(wc -l < "$GIT_DISCIPLINE_SHADOW_LOG" | tr -d ' ')
  [ "$line_count" -ge 1 ]

  local last_line
  last_line=$(tail -1 "$GIT_DISCIPLINE_SHADOW_LOG")

  # Field 1: ISO timestamp (rough check: starts with 20 and contains T and Z).
  local ts
  ts=$(printf '%s' "$last_line" | cut -d'|' -f1)
  [[ "$ts" =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]

  # Field 2: sha from shim ("cafe123").
  local sha
  sha=$(printf '%s' "$last_line" | cut -d'|' -f2)
  [ "$sha" = "cafe123" ]

  # Field 3: branch from shim.
  local branch
  branch=$(printf '%s' "$last_line" | cut -d'|' -f3)
  [ "$branch" = "feature/log-test" ]

  # Field 4: violation code (non-empty string, no spaces).
  local code
  code=$(printf '%s' "$last_line" | cut -d'|' -f4)
  [[ -n "$code" ]]
  [[ "$code" != *" "* ]]

  # Field 5: subject (truncated to 50 chars from "Expose session endpoint").
  local subj
  subj=$(printf '%s' "$last_line" | cut -d'|' -f5)
  [[ "$subj" = "Expose session endpoint" ]]
}

@test "log directory is created automatically when missing" {
  # Point the shadow log to a nonexistent subdirectory path.
  local deep_log="$BATS_TEST_TMPDIR/deep/nested/dir/shadow.log"
  export GIT_DISCIPLINE_SHADOW_LOG="$deep_log"

  export GIT_SHIM_ORIGIN_URL="https://github.com/epologee/laicluse-agent-fieldkit.git"
  export GIT_SHIM_SHORTSTAT=" 5 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb\nc.rb\nd.rb\ne.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit -m "Expose session endpoint" # ack-rule4:essentie'

  # Block-mode: denied; but directory and log file must now exist.
  [ "$status" -eq 2 ]
  [ -d "$(dirname "$deep_log")" ]
  [ -f "$deep_log" ]
}

@test "staging sha is used when HEAD does not exist yet" {
  export GIT_SHIM_ORIGIN_URL="https://github.com/epologee/laicluse-agent-fieldkit.git"
  export GIT_SHIM_SHORTSTAT=" 5 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'a.rb\nb.rb\nc.rb\nd.rb\ne.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  # Override the git shim so rev-parse --short exits non-zero (simulates
  # initial commit where HEAD does not exist). We replace the shim inline.
  local shim_bin="$BATS_TEST_TMPDIR/bin"
  cat > "$shim_bin/git" <<'SHIM2'
#!/usr/bin/env bash
args=("$@")
if [[ "${args[0]}" = "config" && "${args[*]}" =~ "remote.origin.url" ]]; then
  printf '%s\n' "$GIT_SHIM_ORIGIN_URL"; exit 0
fi
if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--shortstat" ]]; then
  printf '%s\n' "$GIT_SHIM_SHORTSTAT"; exit 0
fi
if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--name-only" ]]; then
  printf '%s\n' "$GIT_SHIM_DIFF_NAMES"; exit 0
fi
if [[ "${args[0]}" = "interpret-trailers" ]]; then
  printf '%s' "$GIT_SHIM_INTERPRET_TRAILERS_OUTPUT"; exit 0
fi
if [[ "${args[0]}" = "ls-tree" ]]; then
  printf '%s' "$GIT_SHIM_LS_TREE_OUTPUT"; exit 0
fi
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%H" ]]; then exit 0; fi
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%B" ]]; then exit 0; fi
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--abbrev-ref" ]]; then
  printf 'main\n'; exit 0
fi
# Simulate HEAD not existing.
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--short" ]]; then
  exit 1
fi
REAL=$(PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin" command -v git 2>/dev/null || true)
[[ -n "$REAL" ]] && exec "$REAL" "$@"
exit 1
SHIM2
  chmod +x "$shim_bin/git"

  run_dispatch 'git commit -m "Expose session endpoint" # ack-rule4:essentie'

  # Block-mode: denied.
  [ "$status" -eq 2 ]
  [ -f "$GIT_DISCIPLINE_SHADOW_LOG" ]
  local sha_field
  sha_field=$(tail -1 "$GIT_DISCIPLINE_SHADOW_LOG" | cut -d'|' -f2)
  # When rev-parse --short fails, commit-body.sh falls back to "staging".
  [ "$sha_field" = "staging" ]
}
