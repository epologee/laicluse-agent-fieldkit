#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
  SKILL="$REPO_ROOT/packages/git-discipline/skills/merge-to-default/SKILL.md"
}

@test "merge-to-default delegates verification and merge topology to the shared command" {
  grep -q 'bin/git-discipline" verify' "$SKILL"
  grep -q 'bin/git-discipline" merge' "$SKILL"
  grep -q -- '--local' "$SKILL"
  grep -q -- '--remote' "$SKILL"
  ! grep -q 'git checkout' "$SKILL"
  ! grep -q 'git merge' "$SKILL"
  ! grep -q 'git commit-tree' "$SKILL"
}

@test "merge and rebase use the same executable default-branch resolver" {
  local rebase_skill="$REPO_ROOT/packages/git-discipline/skills/rebase-latest-default/SKILL.md"

  for skill in "$SKILL" "$rebase_skill"; do
    grep -q 'bin/git-discipline" default' "$skill"
    ! grep -q 'git config --get init.defaultBranch' "$skill"
  done
}

@test "merge-to-default maps repository policy before choosing a local or remote CAS" {
  grep -q 'git-repo-policy' "$SKILL"
  grep -q 'local-only' "$SKILL"
  grep -q 'solo-trunk' "$SKILL"
  grep -q 'team-trunk' "$SKILL"
  grep -q 'pr-flow' "$SKILL"
  grep -q 'external' "$SKILL"
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
