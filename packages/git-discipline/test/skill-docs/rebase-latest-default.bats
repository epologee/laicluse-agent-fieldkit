#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
  SKILL="$REPO_ROOT/packages/git-discipline/skills/rebase-latest-default/SKILL.md"
}

@test "stale remote target asks before fetching and continues in the same invocation" {
  grep -q 'Bash(git fetch:\*)' "$SKILL"
  grep -q 'Ask the operator exactly once' "$SKILL"
  grep -q 'Fetch origin and continue?' "$SKILL"
  grep -q '^git fetch origin$' "$SKILL"
  grep -q 'return to Step 0b in the same invocation' "$SKILL"
}
