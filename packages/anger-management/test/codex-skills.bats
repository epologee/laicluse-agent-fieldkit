#!/usr/bin/env bats
# Codex adapter contract for anger-management skill instructions.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  CODEX_ROOT="$REPO/.agents/plugins/generated/anger-management"
  BULLSHIT="$CODEX_ROOT/skills/bullshit/SKILL.md"
  REPAIR="$CODEX_ROOT/skills/repair/SKILL.md"
}

@test "Codex /bullshit resolves the plugin root without a Claude-only command" {
  [ -f "$BULLSHIT" ]

  run grep -F 'codex plugin list' "$BULLSHIT"
  [ "$status" -eq 0 ]
  run grep -F 'anger-management@laicluse-agent-fieldkit' "$BULLSHIT"
  [ "$status" -eq 0 ]
  run grep -F 'node "$PLUGIN_ROOT/bin/anger-log" bullshit' "$BULLSHIT"
  [ "$status" -eq 0 ]
  run grep -F 'node "${CLAUDE_PLUGIN_ROOT}/bin/anger-log" bullshit' "$BULLSHIT"
  [ "$status" -ne 0 ]
}

@test "Codex repair resolves the plugin root before anger-resolve" {
  [ -f "$REPAIR" ]

  run grep -F 'codex plugin list' "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F 'anger-management@laicluse-agent-fieldkit' "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F 'node "$PLUGIN_ROOT/bin/anger-resolve"' "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F 'node "${CLAUDE_PLUGIN_ROOT}/bin/anger-resolve"' "$REPAIR"
  [ "$status" -ne 0 ]
}
