#!/usr/bin/env bats
# Contract tests for the generated safeword-command aliases.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  SYNC="$REPO/bin/sync-safeword-skills"
  SOURCE_ROOT="$REPO/packages/anger-management"
  CODEX_ROOT="$REPO/.agents/plugins/generated/anger-management"
}

@test "safeword aliases are generated from the fix-now template" {
  for word in safeword pineapple pineapplejuice pinapplejuice flugelhorn banana; do
    run grep -F "'$word'" "$SYNC"
    [ "$status" -eq 0 ]
    [ -f "$SOURCE_ROOT/skills/$word/SKILL.md" ]
    run grep -F "fix-now safeword" "$SOURCE_ROOT/skills/$word/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -F "name: $word" "$SOURCE_ROOT/skills/$word/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -F 'node "$PLUGIN_ROOT/bin/anger-log"' "$SOURCE_ROOT/skills/$word/SKILL.md"
    [ "$status" -ne 0 ]
    run grep -F 'node "$PLUGIN_ROOT/bin/anger-arm"' "$SOURCE_ROOT/skills/$word/SKILL.md"
    [ "$status" -ne 0 ]
  done
}

@test "Codex adapter includes safeword aliases" {
  for word in safeword pineapple pineapplejuice pinapplejuice flugelhorn banana; do
    [ -f "$CODEX_ROOT/skills/$word/SKILL.md" ]
    run grep -F "fix-now safeword" "$CODEX_ROOT/skills/$word/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -F "name: $word" "$CODEX_ROOT/skills/$word/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -F 'node "$PLUGIN_ROOT/bin/anger-log"' "$CODEX_ROOT/skills/$word/SKILL.md"
    [ "$status" -ne 0 ]
    run grep -F 'node "$PLUGIN_ROOT/bin/anger-arm"' "$CODEX_ROOT/skills/$word/SKILL.md"
    [ "$status" -ne 0 ]
  done
}
