#!/usr/bin/env bats
# error-format.bats
# The deny error message names the exact missing trailer and includes both
# a synthesized example and the opt-out enum for each violation type.

load helpers

# ---------------------------------------------------------------------------
# Helper: build a commit body with a WHY block but missing specific trailers.
# ---------------------------------------------------------------------------

# valid_why_only_cmd <subject>
# A heredoc commit with a WHY paragraph but NO trailers at all.
valid_why_only_cmd() {
  local subject="$1"
  local cmd
  cmd=$(commit_cmd_heredoc \
    "$subject" \
    "$(printf 'This change addresses a latent race condition in the session\nhandler that manifested under high concurrency in staging.')")
  printf '%s # ack-rule4:essentie' "$cmd"
}

# commit_with_trailers_cmd <subject> <trailer-block>
# A heredoc commit with WHY + given trailers.
commit_with_trailers_cmd() {
  local subject="$1"
  local trailers="$2"
  local cmd
  cmd=$(commit_cmd_heredoc \
    "$subject" \
    "$(printf 'This change addresses a latent race condition in the session\nhandler that manifested under high concurrency in staging.\n\n%s' "$trailers")")
  printf '%s # ack-rule4:essentie' "$cmd"
}

# ---------------------------------------------------------------------------
# missing-tests
# ---------------------------------------------------------------------------

@test "missing-tests violation: error names Tests as the missing key" {
  export GIT_SHIM_SHORTSTAT=" 3 files changed, 25 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/session.rb\napp/services/session_service.rb\nspec/models/session_spec.rb')"
  # Trailers have Slice and Red-then-green but no Tests.
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf 'Slice: handler + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')"

  local cmd
  cmd=$(commit_with_trailers_cmd \
    "Session boundary model for meter events" \
    "$(printf 'Slice: handler + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')")

  run_dispatch "$cmd"

  [ "$status" -eq 2 ]
  [[ "$output" == *"missing-tests"* ]]
}

@test "missing-tests violation: error includes synthesized spec-path in example" {
  export GIT_SHIM_SHORTSTAT=" 3 files changed, 25 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/session.rb\napp/services/session_service.rb\nspec/models/session_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf 'Slice: handler + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')"

  local cmd
  cmd=$(commit_with_trailers_cmd \
    "Session boundary model for meter events" \
    "$(printf 'Slice: handler + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')")

  run_dispatch "$cmd"

  [ "$status" -eq 2 ]
  # The synthesized example should contain the spec path from staged diff.
  [[ "$output" == *"session_spec.rb"* ]]
}

@test "missing-tests violation: error includes opt-out enum" {
  export GIT_SHIM_SHORTSTAT=" 3 files changed, 25 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/session.rb\napp/services/session_service.rb\nspec/models/session_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf 'Slice: handler + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')"

  local cmd
  cmd=$(commit_with_trailers_cmd \
    "Session boundary model for meter events" \
    "$(printf 'Slice: handler + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')")

  run_dispatch "$cmd"

  [ "$status" -eq 2 ]
  [[ "$output" == *"config-only"* ]]
  [[ "$output" == *"migration-only"* ]]
}

# ---------------------------------------------------------------------------
# missing-slice
# ---------------------------------------------------------------------------

@test "missing-slice violation: error names Slice as the missing key" {
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/user.rb\nspec/models/user_spec.rb')"
  # Trailers present but no Slice.
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf 'Tests: spec/models/user_spec.rb\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/models/user_spec.rb"

  local cmd
  cmd=$(commit_with_trailers_cmd \
    "User validation rule for enrollment" \
    "$(printf 'Tests: spec/models/user_spec.rb\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')")

  run_dispatch "$cmd"

  [ "$status" -eq 2 ]
  [[ "$output" == *"missing-slice"* ]]
}

@test "missing-slice violation: error includes opt-out enum" {
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/user.rb\nspec/models/user_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf 'Tests: spec/models/user_spec.rb\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/models/user_spec.rb"

  local cmd
  cmd=$(commit_with_trailers_cmd \
    "User validation rule for enrollment" \
    "$(printf 'Tests: spec/models/user_spec.rb\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')")

  run_dispatch "$cmd"

  [ "$status" -eq 2 ]
  [[ "$output" == *"wip"* ]]
  [[ "$output" == *"chore-deps"* ]]
}

# ---------------------------------------------------------------------------
# missing-red-then-green
# ---------------------------------------------------------------------------

@test "missing-red-then-green violation: error names Red-then-green as missing key" {
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/controllers/orders.rb\nspec/controllers/orders_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf 'Tests: spec/controllers/orders_spec.rb\nSlice: handler + spec')"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/controllers/orders_spec.rb"

  local cmd
  cmd=$(commit_with_trailers_cmd \
    "Order creation handler for checkout flow" \
    "$(printf 'Tests: spec/controllers/orders_spec.rb\nSlice: handler + spec')")

  run_dispatch "$cmd"

  [ "$status" -eq 2 ]
  [[ "$output" == *"missing-red-then-green"* ]]
}

@test "missing-red-then-green violation: error includes opt-out enum" {
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 20 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/controllers/orders.rb\nspec/controllers/orders_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf 'Tests: spec/controllers/orders_spec.rb\nSlice: handler + spec')"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/controllers/orders_spec.rb"

  local cmd
  cmd=$(commit_with_trailers_cmd \
    "Order creation handler for checkout flow" \
    "$(printf 'Tests: spec/controllers/orders_spec.rb\nSlice: handler + spec')")

  run_dispatch "$cmd"

  [ "$status" -eq 2 ]
  [[ "$output" == *"docs-only"* ]]
  [[ "$output" == *"revert"* ]]
}

# ---------------------------------------------------------------------------
# Fix 1: stderr capture - violation code must appear in deny output
# ---------------------------------------------------------------------------

@test "deny output contains the violation code from validate_body stderr" {
  # This test confirms Fix 1: validate_body writes diagnostics to stderr.
  # The old redirect (2>&1 >/dev/null) swallowed stderr; the fix (2>&1)
  # merges it into stdout so the denial message carries the violation code.
  export GIT_SHIM_SHORTSTAT=" 3 files changed, 25 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/models/session.rb\napp/services/session_service.rb\nspec/models/session_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$(printf 'Slice: handler + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')"

  local cmd
  cmd=$(commit_with_trailers_cmd \
    "Session boundary model for meter events" \
    "$(printf 'Slice: handler + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')")

  run_dispatch "$cmd"

  [ "$status" -eq 2 ]
  # The violation code "missing-tests" must be present in the deny message,
  # not just in a synthesized example. This only works if stderr is captured.
  [[ "$output" == *"missing-tests"* ]]
  # The code must appear before the example block (i.e. it comes from the
  # violation_output, not coincidentally from the synthesized example).
  local first_occurrence
  first_occurrence=$(printf '%s' "$output" | grep -n 'missing-tests' | head -1 | cut -d: -f1)
  [[ "$first_occurrence" -le 3 ]]
}

# ---------------------------------------------------------------------------
# The deny text matches actual gate behaviour: --no-verify is not an escape
# at the PreToolUse layer, so a --no-verify commit is still denied and the
# message must not advertise that flag as the way out.
# ---------------------------------------------------------------------------

@test "no-verify commit is still denied and the deny names the sentinel route" {
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 30 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/controllers/foo.rb\nspec/controllers/foo_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""

  run_dispatch 'git commit --no-verify -m "Controller boundary for incoming session events" # ack-rule4:essentie'

  [ "$status" -eq 2 ]
  # Denied by body validation specifically, not by some other guard.
  [[ "$output" == *"missing-body"* ]]
  [[ "$output" != *"Escape: git commit --no-verify"* ]]
  [[ "$output" == *"operator-only"* ]]
  [[ "$output" == *"/git-discipline:disable-discipline"* ]]
}

@test "no-verify commit with a valid body passes (flag has no effect either way)" {
  export GIT_SHIM_SHORTSTAT=" 2 files changed, 30 insertions(+)"
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/controllers/foo.rb\nspec/controllers/foo_spec.rb')"
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$VALID_TRAILERS"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/controllers/foo_spec.rb"

  local cmd
  cmd=$(commit_cmd_heredoc \
    "Controller boundary for incoming session events" \
    "$(printf 'When StartTransaction messages arrive with an invalid meter reading,\nthe previous implementation rejected the entire event and masked\nsession starts in the analytics pipeline.\n\nTests: spec/controllers/foo_spec.rb\nSlice: handler + spec\nRed-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed')")
  cmd="${cmd/git commit/git commit --no-verify} # ack-rule4:essentie"

  run_dispatch "$cmd"

  [ "$status" -eq 0 ]
}
