#!/usr/bin/env bats
# test/plugin-adapters/sanitized-plugin-bin.bats
#
# A plugin whose skills need sanitization installs for Codex from the
# generated dir under .agents/plugins/generated/<name>/. Skills that invoke
# helpers from the plugin root ("resolve the plugin root from where this
# skill file was loaded") then need support files to exist in that generated
# dir, otherwise the Codex install ships prompts that point at missing files
# (observed with clipboard-copy, anger-log, and git-discipline's git-native
# hook libraries).

SCRIPT="$BATS_TEST_DIRNAME/../../bin/plugin-adapters"

setup() {
  export REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.claude-plugin" "$REPO/packages/demo/.claude-plugin" \
           "$REPO/packages/demo/skills/demo" "$REPO/packages/demo/bin" \
           "$REPO/packages/demo/hooks/lib"
  cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "demo-marketplace",
  "plugins": [ { "name": "demo", "description": "demo plugin", "source": "./packages/demo" } ]
}
JSON
  cat > "$REPO/packages/demo/.claude-plugin/plugin.json" <<'JSON'
{ "name": "demo", "description": "demo plugin", "version": "1.0.0" }
JSON
  printf '# demo changelog\n' > "$REPO/packages/demo/CHANGELOG.md"
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
  printf 'demo hook lib\n' > "$REPO/packages/demo/hooks/lib/demo-lib.sh"
  printf '{"hooks":{"PreToolUse":[]}}\n' > "$REPO/packages/demo/hooks/hooks.json"
}

@test "build copies bin/ into the generated codex dir for sanitized plugins" {
  bash "$SCRIPT" build "$REPO" > /dev/null

  [ -f "$REPO/.agents/plugins/generated/demo/bin/demo-helper" ]
  [ -x "$REPO/.agents/plugins/generated/demo/bin/demo-helper" ]
}

@test "build copies hooks/lib into the generated codex dir for sanitized plugins" {
  bash "$SCRIPT" build "$REPO" > /dev/null

  [ -f "$REPO/.agents/plugins/generated/demo/hooks/lib/demo-lib.sh" ]
  [ ! -f "$REPO/.agents/plugins/generated/demo/hooks/hooks.json" ]
}

@test "build copies top-level changelog into the generated codex dir" {
  bash "$SCRIPT" build "$REPO" > /dev/null

  [ -f "$REPO/.agents/plugins/generated/demo/CHANGELOG.md" ]
  grep -q 'demo changelog' "$REPO/.agents/plugins/generated/demo/CHANGELOG.md"
}

@test "build materializes explicit Codex hooks into the generated codex dir" {
  mkdir -p "$REPO/packages/demo/hooks/guards"
  printf '#!/bin/sh\necho dispatch\n' > "$REPO/packages/demo/hooks/dispatch.sh"
  chmod +x "$REPO/packages/demo/hooks/dispatch.sh"
  printf '#!/bin/sh\necho guard\n' > "$REPO/packages/demo/hooks/guards/demo.sh"
  chmod +x "$REPO/packages/demo/hooks/guards/demo.sh"
  cat > "$REPO/packages/demo/hooks/hooks.codex.json" <<'JSON'
{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"${PLUGIN_ROOT}/hooks/dispatch.sh"}]}]}}
JSON

  bash "$SCRIPT" build "$REPO" > /dev/null

  [ -f "$REPO/.agents/plugins/generated/demo/hooks/hooks.json" ]
  [ -f "$REPO/.agents/plugins/generated/demo/hooks/dispatch.sh" ]
  [ -f "$REPO/.agents/plugins/generated/demo/hooks/guards/demo.sh" ]
  [ -f "$REPO/.agents/plugins/generated/demo/hooks/lib/demo-lib.sh" ]
  [ ! -f "$REPO/.agents/plugins/generated/demo/hooks/hooks.codex.json" ]
  grep -q 'PLUGIN_ROOT' "$REPO/.agents/plugins/generated/demo/hooks/hooks.json"
}

@test "check passes after build with a bin directory present" {
  bash "$SCRIPT" build "$REPO" > /dev/null

  run bash "$SCRIPT" check "$REPO"
  [ "$status" -eq 0 ]
}

@test "a stale generated hook library that no longer exists in the source is drift" {
  bash "$SCRIPT" build "$REPO" > /dev/null
  printf 'stale\n' > "$REPO/.agents/plugins/generated/demo/hooks/lib/stale-lib.sh"

  run bash "$SCRIPT" check "$REPO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"stale-lib.sh"* ]]
}

@test "a stale generated bin file that no longer exists in the source is drift" {
  bash "$SCRIPT" build "$REPO" > /dev/null
  printf '#!/bin/sh\necho stale\n' > "$REPO/.agents/plugins/generated/demo/bin/stale-helper"

  run bash "$SCRIPT" check "$REPO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"stale-helper"* ]]
}
