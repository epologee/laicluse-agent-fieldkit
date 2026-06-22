#!/usr/bin/env bats
# test/plugin-adapters/rover-codex-catalog.bats

REPO="$BATS_TEST_DIRNAME/../.."

@test "generated Codex marketplace exposes rover" {
  jq -e '.plugins[] | select(.name == "rover")' \
    "$REPO/.agents/plugins/marketplace.json" > /dev/null
}

@test "rover uses shared skill sources rather than Claude-only sources" {
  run find "$REPO/packages/rover/skills" -name 'SKILL.claude.md' -print
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}
