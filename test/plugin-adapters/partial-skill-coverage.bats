#!/usr/bin/env bats
# test/plugin-adapters/partial-skill-coverage.bats
#
# Agent-specific skill sources may exist singly. A Claude-only skill should
# materialize for Claude while being omitted from the generated Codex skill
# catalog; a Codex-only skill should do the inverse.

SCRIPT="$BATS_TEST_DIRNAME/../../bin/plugin-adapters"

setup() {
  export REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.claude-plugin"
  mkdir -p "$REPO/packages/probe/.claude-plugin"
  mkdir -p "$REPO/packages/probe/skills/shared"
  mkdir -p "$REPO/packages/probe/skills/claude-only/bin"
  mkdir -p "$REPO/packages/probe/skills/codex-only/bin"
  mkdir -p "$REPO/packages/probe/skills/variant"
  mkdir -p "$REPO/packages/claude-only-plugin/.claude-plugin"
  mkdir -p "$REPO/packages/claude-only-plugin/skills/internal"

  cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "probe-marketplace",
  "plugins": [
    { "name": "probe", "description": "Probe plugin.", "source": "./packages/probe" },
    { "name": "claude-only-plugin", "description": "Claude-only plugin.", "source": "./packages/claude-only-plugin" }
  ]
}
JSON

  cat > "$REPO/packages/probe/.claude-plugin/plugin.json" <<'JSON'
{ "name": "probe", "version": "1.0.0", "description": "Probe plugin." }
JSON

  cat > "$REPO/packages/claude-only-plugin/.claude-plugin/plugin.json" <<'JSON'
{ "name": "claude-only-plugin", "version": "1.0.0", "description": "Claude-only plugin." }
JSON

  cat > "$REPO/packages/probe/skills/shared/SKILL.md" <<'MD'
---
name: shared
description: Shared skill.
user-invocable: true
---

# shared
MD

  cat > "$REPO/packages/probe/skills/claude-only/SKILL.claude.md" <<'MD'
---
name: claude-only
description: Claude-only skill.
user-invocable: true
---

# claude-only
MD

  cat > "$REPO/packages/probe/skills/claude-only/bin/helper.mjs" <<'JS'
export const owner = 'asset-without-codex-skill';
JS

  cat > "$REPO/packages/probe/skills/codex-only/SKILL.codex.md" <<'MD'
---
name: codex-only
description: Codex-only skill.
---

# codex-only
MD

  cat > "$REPO/packages/probe/skills/codex-only/bin/helper.mjs" <<'JS'
export const owner = 'codex-only';
JS

  cat > "$REPO/packages/probe/skills/variant/SKILL.claude.md" <<'MD'
---
name: variant
description: Claude variant.
---

# variant claude
MD

  cat > "$REPO/packages/probe/skills/variant/SKILL.codex.md" <<'MD'
---
name: variant
description: Codex variant.
---

# variant codex
MD

  cat > "$REPO/packages/claude-only-plugin/skills/internal/SKILL.claude.md" <<'MD'
---
name: internal
description: Claude-only internal skill.
---

# internal claude
MD
}

@test "build materializes only the skill sources that apply to each agent" {
  bash "$SCRIPT" build "$REPO" > /dev/null

  [ -f "$REPO/packages/probe/skills/claude-only/SKILL.md" ]
  grep -q '# claude-only' "$REPO/packages/probe/skills/claude-only/SKILL.md"
  [ ! -f "$REPO/packages/probe/skills/codex-only/SKILL.md" ]

  [ -f "$REPO/.agents/plugins/generated/probe/skills/shared/SKILL.md" ]
  [ ! -f "$REPO/.agents/plugins/generated/probe/skills/claude-only/SKILL.md" ]
  [ -f "$REPO/.agents/plugins/generated/probe/skills/claude-only/bin/helper.mjs" ]
  [ -f "$REPO/.agents/plugins/generated/probe/skills/codex-only/SKILL.md" ]
  [ -f "$REPO/.agents/plugins/generated/probe/skills/variant/SKILL.md" ]
  grep -q '# variant codex' "$REPO/.agents/plugins/generated/probe/skills/variant/SKILL.md"
}

@test "build omits plugins that have no Codex runtime payload" {
  bash "$SCRIPT" build "$REPO" > /dev/null

  ! jq -e '.plugins[] | select(.name == "claude-only-plugin")' "$REPO/.agents/plugins/marketplace.json" > /dev/null
  [ ! -e "$REPO/.agents/plugins/generated/claude-only-plugin" ]
  [ ! -e "$REPO/packages/claude-only-plugin/.codex-plugin" ]
}

@test "check passes after build with partial coverage" {
  bash "$SCRIPT" build "$REPO" > /dev/null

  run bash "$SCRIPT" check "$REPO"
  [ "$status" -eq 0 ]
}
