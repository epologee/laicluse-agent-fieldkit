#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../bin/plugin-adapters"

setup() {
  export REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.claude-plugin"
  mkdir -p "$REPO/packages/probe/.claude-plugin"
  mkdir -p "$REPO/packages/probe/skills/probe"
  mkdir -p "$REPO/packages/probe/hooks/guards"

  cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "probe-marketplace",
  "plugins": [
    { "name": "probe", "description": "Probe plugin.", "source": "./packages/probe" }
  ]
}
JSON

  cat > "$REPO/packages/probe/.claude-plugin/plugin.json" <<'JSON'
{ "name": "probe", "version": "1.0.0", "description": "Probe plugin." }
JSON

  cat > "$REPO/packages/probe/skills/probe/SKILL.md" <<'MD'
---
name: probe
description: Probe skill.
---

# probe
MD

  cat > "$REPO/packages/probe/hooks/hooks.json" <<'JSON'
{
  "description": "Claude-only hook description.",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/dispatch.sh" }
        ]
      }
    ]
  }
}
JSON
}

@test "direct Codex source rejects Claude-only hook metadata" {
  run bash "$SCRIPT" build "$REPO"

  [ "$status" -eq 1 ]
  [[ "$output" == *"top-level hooks key"* ]]
}

@test "explicit Codex hook manifest materializes a generated plugin" {
  cat > "$REPO/packages/probe/hooks/hooks.codex.json" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          { "type": "command", "command": "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}/hooks/dispatch.sh" }
        ]
      }
    ]
  }
}
JSON
  printf '#!/bin/sh\necho dispatch\n' > "$REPO/packages/probe/hooks/dispatch.sh"
  printf '#!/bin/sh\necho guard\n' > "$REPO/packages/probe/hooks/guards/probe.sh"

  bash "$SCRIPT" build "$REPO" > /dev/null

  [ -f "$REPO/.agents/plugins/generated/probe/hooks/hooks.json" ]
  [ -f "$REPO/.agents/plugins/generated/probe/hooks/dispatch.sh" ]
  [ -f "$REPO/.agents/plugins/generated/probe/hooks/guards/probe.sh" ]
  [ ! -f "$REPO/.agents/plugins/generated/probe/hooks/hooks.codex.json" ]
  grep -q 'PLUGIN_ROOT' "$REPO/.agents/plugins/generated/probe/hooks/hooks.json"
  grep -q '"path": "./.agents/plugins/generated/probe"' "$REPO/.agents/plugins/marketplace.json"

  run bash "$SCRIPT" check "$REPO"
  [ "$status" -eq 0 ]
}
