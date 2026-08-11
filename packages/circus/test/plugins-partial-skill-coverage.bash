#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
mkdir -p "$repo/.claude-plugin"
mkdir -p "$repo/packages/probe/.claude-plugin"
mkdir -p "$repo/packages/probe/skills/shared"
mkdir -p "$repo/packages/probe/skills/claude-only/bin"
mkdir -p "$repo/packages/probe/skills/codex-only/bin"
mkdir -p "$repo/packages/probe/skills/variant"

cat > "$repo/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "probe-marketplace",
  "owner": {
    "name": "Probe Marketplace"
  },
  "plugins": [
    {
      "name": "probe",
      "description": "Probe plugin.",
      "source": "./packages/probe"
    }
  ]
}
JSON

cat > "$repo/packages/probe/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "probe",
  "version": "1.0.0",
  "description": "Probe plugin."
}
JSON

cat > "$repo/packages/probe/skills/shared/SKILL.md" <<'MD'
---
name: shared
description: Shared skill.
user-invocable: true
---

# shared
MD

cat > "$repo/packages/probe/skills/claude-only/SKILL.claude.md" <<'MD'
---
name: claude-only
description: Claude-only skill.
user-invocable: true
---

# claude-only
MD

cat > "$repo/packages/probe/skills/claude-only/bin/helper.mjs" <<'JS'
export const owner = 'shared-by-assets';
JS

cat > "$repo/packages/probe/skills/codex-only/SKILL.codex.md" <<'MD'
---
name: codex-only
description: Codex-only skill.
---

# codex-only
MD

cat > "$repo/packages/probe/skills/codex-only/bin/helper.mjs" <<'JS'
export const owner = 'codex-only';
JS

cat > "$repo/packages/probe/skills/variant/SKILL.claude.md" <<'MD'
---
name: variant
description: Claude variant.
---

# variant claude
MD

cat > "$repo/packages/probe/skills/variant/SKILL.codex.md" <<'MD'
---
name: variant
description: Codex variant.
---

# variant codex
MD

"$circus_bin" plugins build "$repo" >/dev/null

test -f "$repo/packages/probe/skills/claude-only/SKILL.md"
grep -q '# claude-only' "$repo/packages/probe/skills/claude-only/SKILL.md"

test -f "$repo/.agents/plugins/generated/probe/skills/shared/SKILL.md"
test ! -f "$repo/.agents/plugins/generated/probe/skills/claude-only/SKILL.md"
test -f "$repo/.agents/plugins/generated/probe/skills/claude-only/bin/helper.mjs"
test -f "$repo/.agents/plugins/generated/probe/skills/codex-only/SKILL.md"
test -f "$repo/.agents/plugins/generated/probe/skills/variant/SKILL.md"
grep -q '# variant codex' "$repo/.agents/plugins/generated/probe/skills/variant/SKILL.md"

"$circus_bin" plugins check "$repo" >/dev/null
