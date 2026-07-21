#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
  SKILL="$REPO_ROOT/packages/git-discipline/skills/rebase-latest-default/SKILL.md"
}

@test "rebase delegates default resolution and the rebase operation to the shared command" {
  grep -q 'bin/git-discipline" default' "$SKILL"
  grep -q 'bin/git-discipline" rebase' "$SKILL"
  grep -q -- '--local' "$SKILL"
  grep -q -- '--remote' "$SKILL"
  ! grep -q '^git rebase ' "$SKILL"
  ! grep -q '^git fetch ' "$SKILL"
}
