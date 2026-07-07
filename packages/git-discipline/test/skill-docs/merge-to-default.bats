#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
  SKILL="$REPO_ROOT/packages/git-discipline/skills/merge-to-default/SKILL.md"
}

@test "merge-to-default writes a hook-compliant merge commit explicitly" {
  grep -q 'Bash(git commit:\*)' "$SKILL"
  grep -q 'git merge --no-ff --no-commit "$CURRENT"' "$SKILL"
  grep -q 'git commit -m "$(cat <<EOF' "$SKILL"
  grep -q 'Slice: merge' "$SKILL"
  grep -q 'PII-Doublecheck: yes' "$SKILL"
  ! grep -q 'git merge --no-ff --no-edit' "$SKILL"
}
