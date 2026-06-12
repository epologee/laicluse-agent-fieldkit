#!/usr/bin/env bats
# Contract tests for the generated safeword-command aliases.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  SYNC="$REPO/bin/sync-safeword-skills"
  SOURCE_ROOT="$REPO/packages/anger-management"
  CODEX_ROOT="$REPO/.agents/plugins/generated/anger-management"
}

@test "current copy names the safeword cuss repair ladder" {
  run grep -F "safeword lane" "$SOURCE_ROOT/README.md"
  [ "$status" -eq 0 ]
  run grep -F "cuss lane" "$SOURCE_ROOT/README.md"
  [ "$status" -eq 0 ]
  run grep -F "repair lane" "$SOURCE_ROOT/README.md"
  [ "$status" -eq 0 ]
  run grep -F "swear/cuss words" "$SOURCE_ROOT/README.md"
  [ "$status" -eq 0 ]
  run grep -F "cuss commands" "$SOURCE_ROOT/capture-skill.template.md"
  [ "$status" -eq 0 ]
  run grep -F "cuss-capture log" "$SOURCE_ROOT/skills/repair/SKILL.md"
  [ "$status" -eq 0 ]

  run grep -F "curse commands" \
    "$SOURCE_ROOT/README.md" \
    "$SOURCE_ROOT/capture-skill.template.md" \
    "$SOURCE_ROOT/safeword-skill.template.md" \
    "$SOURCE_ROOT/skills/anger-management/SKILL.md" \
    "$SOURCE_ROOT/skills/repair/SKILL.md" \
    "$SOURCE_ROOT/.claude-plugin/plugin.json"
  [ "$status" -ne 0 ]
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
    run grep -F 'node "$PLUGIN_ROOT/bin/anger-schedule"' "$SOURCE_ROOT/skills/$word/SKILL.md"
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
    run grep -F 'node "$PLUGIN_ROOT/bin/anger-schedule"' "$CODEX_ROOT/skills/$word/SKILL.md"
    [ "$status" -ne 0 ]
  done
}
