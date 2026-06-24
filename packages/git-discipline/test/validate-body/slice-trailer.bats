#!/usr/bin/env bats
# Slice trailer presence / absence and opt-out enum acceptance.

load helpers

# ---------------------------------------------------------------------------
# Slice trailer present / absent / empty (4 cases)
# ---------------------------------------------------------------------------

@test "commit without Slice trailer fails with missing-slice" {
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Red-then-green: n/a (test fixture, no spec applies)"$'\n'"Verified: operator-confirmed"
  local body
  body="$(cat <<'MSG'
Expose session boundary on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation, we previously rejected
the entire event.

Tests: spec/services/session_spec.rb
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
)"
  local file
  file=$(write_fixture "no-slice.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-slice"* ]]
}

@test "missing Slice explains visible but unparsed trailer lines" {
  use_trailers "Verified: red-then-green"
  local body
  body="$(cat <<'MSG'
Add voice retry command

Allow hands-free dictation to discard a polluted pending turn before it
reaches the agent surface. This makes the spoken retry phrase a
first-class voice command instead of a literal text fragment.

Tests: vocalist-swift/Tests/VocalistTests/TurnComposerTests.swift

Slice: command processing + docs + specs

Red-then-green: vocalist-swift/Tests/VocalistTests/TurnComposerTests.swift:81 # testRetryCommandDiscardsPendingTurnWithoutTouchingSurface

Verified: red-then-green
MSG
)"
  local file
  file=$(write_fixture "split-trailers.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-slice"* ]]
  [[ "$output" == *"Slice line exists in the message text"* ]]
  [[ "$output" == *"multiple -m flags"* ]]
  [[ "$output" == *"Keep Tests, Slice, Red-then-green, Verified, and Visual lines contiguous"* ]]
}

@test "commit with empty Slice value fails with missing-slice" {
  # Shim returns Slice: with empty value (trailing space stripped by grep).
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Red-then-green: n/a (test fixture, no spec applies)"$'\n'"Verified: operator-confirmed"
  local body
  body="$(cat <<'MSG'
Expose session boundary on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation.

Tests: spec/services/session_spec.rb
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
)"
  local file
  file=$(write_fixture "empty-slice.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-slice"* ]]
}

@test "commit with valid free-text Slice passes" {
  use_trailers "$VALID_TRAILERS"
  local file
  file=$(write_fixture "valid-slice.txt" "$VALID_BODY_TEMPLATE")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "commit with Slice opt-out token docs-only skips Tests and RTG checks" {
  use_trailers "Slice: docs-only"
  local body
  body="$(cat <<'MSG'
Update CONTRIBUTING guide with commit schema

The new body schema requires three trailers; this commit documents
the format, the opt-out tokens, and the escape hatch.

Slice: docs-only
MSG
)"
  local file
  file=$(write_fixture "docs-only.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Opt-out enum tokens (4 cases covering all 7 tokens)
# ---------------------------------------------------------------------------

@test "Slice: config-only is accepted without Tests or RTG" {
  use_trailers "Slice: config-only"
  local body
  body="$(cat <<'MSG'
Tighten rubocop line-length to 100

The default 120-char limit lets wide lines slip through code review.
Narrowing to 100 aligns with the existing editor ruler setting.

Slice: config-only
MSG
)"
  local file
  file=$(write_fixture "config-only.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Slice: migration-only is accepted without Tests and RTG" {
  # Fix 2: migration-only is now also RTG-exempt.
  use_trailers "Slice: migration-only"
  local body
  body="$(cat <<'MSG'
Add null constraint to sessions.user_id

The column was added without a NOT NULL in the original migration.
Backfilling confirmed no null rows exist in production.

Slice: migration-only
MSG
)"
  local file
  file=$(write_fixture "migration-only.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Slice: spec-only is accepted without Tests and RTG" {
  # Fix 2: spec-only is a new opt-out token; both Tests and RTG are exempt.
  use_trailers "Slice: spec-only"
  local body
  body="$(cat <<'MSG'
Add failing specs for enrollment race-condition fix

Tests written first to drive the implementation. The handler does not
exist yet; these specs are the red phase of the TDD cycle.

Slice: spec-only
MSG
)"
  local file
  file=$(write_fixture "spec-only.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Slice: chore-deps is accepted without Tests and RTG" {
  use_trailers "Slice: chore-deps"
  local body
  body="$(cat <<'MSG'
Bump bundler to 2.5.18

Security advisory CVE-2025-9999 affects bundler < 2.5.18.
Upgrading resolves the advisory without behaviour change.

Slice: chore-deps
MSG
)"
  local file
  file=$(write_fixture "chore-deps.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Slice: wip is accepted without Tests but still requires RTG" {
  # wip is in opt-out (no Tests) but NOT in RTG-exempt (RTG still required).
  use_trailers "Slice: wip"$'\n'"Red-then-green: n/a (work in progress, tests come next)"
  local body
  body="$(cat <<'MSG'
Wire session boundary to analytics pipeline (WIP)

First pass connecting the event bus to the analytics ingestion layer.
This commit intentionally skips the adapter layer; next commit adds it.

Slice: wip
Red-then-green: n/a (work in progress, tests come next)
MSG
)"
  local file
  file=$(write_fixture "wip.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Fix 3: free-text Slice minimum length (>= 10 chars)
# ---------------------------------------------------------------------------

@test "free-text Slice shorter than 10 chars fails with slice-too-short" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: api"$'\n'"Red-then-green: n/a (test fixture, no spec applies)"$'\n'"Verified: operator-confirmed"
  local body
  body="$(cat <<'MSG'
Expose session boundary on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation, we previously rejected
the entire event.

Tests: spec/services/session_spec.rb
Slice: api
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
)"
  local file
  file=$(write_fixture "short-slice.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"slice-too-short"* ]]
}

@test "free-text Slice exactly 10 chars passes" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: api + spec"$'\n'"Red-then-green: n/a (test fixture, no spec applies)"$'\n'"Verified: operator-confirmed"
  local body
  body="$(cat <<'MSG'
Expose session boundary on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation, we previously rejected
the entire event.

Tests: spec/services/session_spec.rb
Slice: api + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
)"
  local file
  file=$(write_fixture "exact10-slice.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "opt-out token shorter than 10 chars is still accepted (not subject to length rule)" {
  use_trailers "Slice: wip"$'\n'"Red-then-green: n/a (wip, continuing next commit)"
  local body
  body="$(cat <<'MSG'
Wire session boundary to analytics pipeline (WIP)

First pass connecting the event bus to the analytics ingestion layer.
This commit intentionally skips the adapter layer; next commit adds it.

Slice: wip
Red-then-green: n/a (wip, continuing next commit)
MSG
)"
  local file
  file=$(write_fixture "wip-short-ok.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}
