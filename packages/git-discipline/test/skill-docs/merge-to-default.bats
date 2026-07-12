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

@test "merge and rebase resolve a configured local default without a remote" {
  local rebase_skill="$REPO_ROOT/packages/git-discipline/skills/rebase-latest-default/SKILL.md"

  for skill in "$SKILL" "$rebase_skill"; do
    grep -q 'Bash(git config:\*)' "$skill"
    grep -q 'git config --get init.defaultBranch' "$skill"
    grep -q 'git rev-parse --verify "refs/heads/\$CONFIGURED_DEFAULT"' "$skill"
  done
}

@test "review skills use the same configured local default contract" {
  local intervision_codex="$REPO_ROOT/packages/intervision/skills/second-opinion/SKILL.codex.md"
  local intervision_claude="$REPO_ROOT/packages/intervision/skills/second-opinion/SKILL.claude.md"
  local rover_pride="$REPO_ROOT/packages/rover/skills/pride/SKILL.md"

  for skill in "$intervision_codex" "$intervision_claude" "$rover_pride"; do
    grep -q 'git config --get init.defaultBranch' "$skill"
    grep -q 'git rev-parse --verify "refs/heads/\$CONFIGURED_DEFAULT"' "$skill"
  done
  grep -q 'DEFAULT_REF=\$CONFIGURED_DEFAULT' "$rover_pride"
  grep -q 'RANGE="${DEFAULT_REF}..HEAD"' "$rover_pride"
}
