#!/usr/bin/env bats
# allow-comment: git-native parity for the body gate. The installed pre-push must
# allow-comment: block a push range carrying a malformed body (Codex/CLI parity
# allow-comment: with Claude's push-body-gate), and post-rewrite must surface and
# allow-comment: log a rewritten malformed body without blocking (git ignores its
# allow-comment: exit status).

load helpers

BAD_BODY=$'Add a clear capability\n\nThe system gains a real behaviour here, described in two sentences so the\nWHY block is satisfied and the gate is happy.\n\nSlice: docs-only\n\nVerified: n/a (no behaviour change)'

seed_repo() {
  pushd "$TEST_REPO" >/dev/null
  printf 'base\n' > base.txt
  git add base.txt
  git -c commit.gpgsign=false commit -q -m "Establish base" --no-verify
  BASE_SHA=$(git rev-parse HEAD)
  printf '%s' "$BAD_BODY" > .m
  printf 'a\nb\nc\nd\ne\nf\n' >> base.txt
  git add base.txt
  git -c commit.gpgsign=false commit -q -F .m --no-verify
  rm -f .m
  HEAD_SHA=$(git rev-parse HEAD)
  popd >/dev/null
}

@test "installed pre-push blocks a push range with a malformed body" {
  run_install "$TEST_REPO"
  [ "$status" -eq 0 ]
  seed_repo

  pushd "$TEST_REPO" >/dev/null
  run bash -c "printf 'refs/heads/feature %s refs/heads/feature %s\n' '$HEAD_SHA' '$BASE_SHA' | .git/hooks/pre-push origin file:///tmp/none"
  popd >/dev/null

  [ "$status" -eq 1 ]
  [[ "$output" == *"[git-discipline/pre-push]"* ]]
  [[ "$output" == *"Body schema misses"* ]]
}

@test "installed post-rewrite warns and logs but does not block" {
  run_install "$TEST_REPO"
  [ "$status" -eq 0 ]
  seed_repo

  pushd "$TEST_REPO" >/dev/null
  run bash -c "printf '%s %s\n' '$BASE_SHA' '$HEAD_SHA' | .git/hooks/post-rewrite amend"
  popd >/dev/null

  [ "$status" -eq 0 ]
  [[ "$output" == *"[git-discipline/post-rewrite]"* ]]
  [ -f "$HOME/.laicluse/git-discipline/git-discipline-post-rewrite.log" ]
}
