#!/usr/bin/env bats
# allow-comment: Pure-function unit tests for the push-policy resolver: derive_mode (mode from five facts), _protection_meaningful (branch-protection JSON triage), _classify_collaboration (author-count to individual/shared).

load helpers

@test "no remote is local-only" {
  run derive_mode no write pushable individual private
  [ "$status" -eq 0 ]
  [ "$output" = "local-only" ]
}

@test "no remote wins over everything" {
  run derive_mode no external protected shared public
  [ "$output" = "local-only" ]
}

@test "no write access forks" {
  run derive_mode yes external pushable individual private
  [ "$output" = "external" ]
}

@test "unknown access is conservative" {
  run derive_mode yes unknown pushable individual private
  [ "$output" = "external" ]
}

@test "protected default is pr-flow" {
  run derive_mode yes write protected shared private
  [ "$output" = "pr-flow" ]
}

@test "unknown default is conservative" {
  run derive_mode yes write unknown individual private
  [ "$output" = "pr-flow" ]
}

@test "private individual pushable default is auto-trunk" {
  run derive_mode yes write pushable individual private
  [ "$output" = "auto-trunk" ]
}

@test "private shared pushable default is gated-trunk" {
  run derive_mode yes write pushable shared private
  [ "$output" = "gated-trunk" ]
}

@test "public shared pushable default is gated-trunk" {
  run derive_mode yes write pushable shared public
  [ "$output" = "gated-trunk" ]
}

@test "public individual pushable default is gated-trunk" {
  run derive_mode yes write pushable individual public
  [ "$output" = "gated-trunk" ]
}

@test "unknown collaboration is not automatic" {
  run derive_mode yes write pushable unknown private
  [ "$output" = "gated-trunk" ]
}

@test "unknown visibility is not automatic" {
  run derive_mode yes write pushable individual unknown
  [ "$output" = "gated-trunk" ]
}

@test "empty protection object is not meaningful" {
  result="$(printf '%s' '{"required_signatures":{"enabled":false},"enforce_admins":{"enabled":false},"allow_force_pushes":{"enabled":false}}' | _protection_meaningful)"
  [ "$result" = "false" ]
}

@test "required status checks make it meaningful" {
  result="$(printf '%s' '{"required_status_checks":{"contexts":["rspec","cucumber"]}}' | _protection_meaningful)"
  [ "$result" = "true" ]
}

@test "restrictions make it meaningful" {
  result="$(printf '%s' '{"restrictions":{"teams":[{"slug":"development"}]}}' | _protection_meaningful)"
  [ "$result" = "true" ]
}

@test "required PR reviews make it meaningful" {
  result="$(printf '%s' '{"required_pull_request_reviews":{"required_approving_review_count":0}}' | _protection_meaningful)"
  [ "$result" = "true" ]
}

@test "404 not-protected body is not meaningful" {
  result="$(printf '%s' '{"message":"Branch not protected","documentation_url":"https://docs.github.com"}' | _protection_meaningful)"
  [ "$result" = "false" ]
}

@test "missing origin HEAD keeps default policy unknown instead of guessing pushable" {
  local repo="$BATS_TEST_TMPDIR/no-default-metadata"
  local fakebin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$repo" "$fakebin"
  git -C "$repo" init -b trunk >/dev/null
  git -C "$repo" config core.hooksPath /dev/null
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name Test
  git -C "$repo" config codingAgent.git.pushAccess write
  git -C "$repo" config codingAgent.git.visibility private
  git -C "$repo" config codingAgent.git.collaboration individual
  git -C "$repo" remote add origin git@github.com:org/repo.git
  echo root > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -m init >/dev/null
  cat > "$fakebin/gh" <<'SH'
#!/usr/bin/env bash
exit 1
SH
  chmod +x "$fakebin/gh"

  run env PATH="$fakebin:$PATH" "$HELPER_DIR/../../skills/push-policy/git-repo-policy" "$repo"

  [ "$status" -eq 0 ]
  [[ "$output" == *"default_policy=unknown"* ]]
  [[ "$output" == *"mode=pr-flow"* ]]
}

@test "one author name is individual" {
  run _classify_collaboration 1
  [ "$output" = "individual" ]
}

@test "multiple author names are shared" {
  run _classify_collaboration 3
  [ "$output" = "shared" ]
}

@test "legacy closed override normalizes to shared" {
  run _normalize_collaboration closed
  [ "$output" = "shared" ]
}

@test "legacy open override normalizes to shared" {
  run _normalize_collaboration open
  [ "$output" = "shared" ]
}
