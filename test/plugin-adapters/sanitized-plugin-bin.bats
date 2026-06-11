#!/usr/bin/env bats
# test/plugin-adapters/sanitized-plugin-bin.bats
#
# A plugin whose skills need sanitization installs for Codex from the
# generated dir under .agents/plugins/generated/<name>/. Skills that invoke
# helpers from the plugin's bin/ ("resolve the plugin root from where this
# skill file was loaded") then need bin/ to exist in that generated dir,
# otherwise the Codex install ships prompts that point at missing binaries
# (observed with clipboard-copy and anger-log).

SCRIPT="$BATS_TEST_DIRNAME/../../bin/plugin-adapters"

setup() {
  export REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.claude-plugin" "$REPO/packages/demo/.claude-plugin" \
           "$REPO/packages/demo/skills/demo" "$REPO/packages/demo/bin"
  cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "demo-marketplace",
  "plugins": [ { "name": "demo", "description": "demo plugin", "source": "./packages/demo" } ]
}
JSON
  cat > "$REPO/packages/demo/.claude-plugin/plugin.json" <<'JSON'
{ "name": "demo", "description": "demo plugin", "version": "1.0.0" }
JSON
  # user-invocable forces the sanitized/generated-dir path for Codex.
  cat > "$REPO/packages/demo/skills/demo/SKILL.md" <<'MD'
---
name: demo
user-invocable: true
description: demo skill
---

# Demo
MD
  printf '#!/bin/sh\necho helper\n' > "$REPO/packages/demo/bin/demo-helper"
  chmod +x "$REPO/packages/demo/bin/demo-helper"
}

@test "build copies bin/ into the generated codex dir for sanitized plugins" {
  bash "$SCRIPT" build "$REPO" > /dev/null

  [ -f "$REPO/.agents/plugins/generated/demo/bin/demo-helper" ]
  [ -x "$REPO/.agents/plugins/generated/demo/bin/demo-helper" ]
}

@test "check passes after build with a bin directory present" {
  bash "$SCRIPT" build "$REPO" > /dev/null

  run bash "$SCRIPT" check "$REPO"
  [ "$status" -eq 0 ]
}

@test "a stale generated bin file that no longer exists in the source is drift" {
  bash "$SCRIPT" build "$REPO" > /dev/null
  printf '#!/bin/sh\necho stale\n' > "$REPO/.agents/plugins/generated/demo/bin/stale-helper"

  run bash "$SCRIPT" check "$REPO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"stale-helper"* ]]
}
