#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
mkdir -p "$repo/.claude-plugin"
mkdir -p "$repo/packages/probe/.claude-plugin"
mkdir -p "$repo/packages/probe/skills/board"

cat > "$repo/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "probe-marketplace",
  "owner": { "name": "Probe Marketplace" },
  "plugins": [
    { "name": "probe", "description": "Probe plugin.", "source": "./packages/probe" }
  ]
}
JSON

cat > "$repo/packages/probe/.claude-plugin/plugin.json" <<'JSON'
{ "name": "probe", "version": "1.0.0", "description": "Probe plugin." }
JSON

cat > "$repo/packages/probe/skills/board/SKILL.codex.md" <<'MD'
---
name: board
description: Board skill.
---

# board
MD

cat > "$repo/packages/probe/skills/board/SKILL.claude.md" <<'MD'
---
name: board
description: Board skill.
---

# board
MD

cat > "$repo/packages/probe/CHANGELOG.md" <<'MD'
# probe changelog

## [v1.0.0]

### Added

- Probe shipped.
MD

"$circus_bin" plugins build "$repo" >/dev/null

gen="$repo/.agents/plugins/generated/probe"
test -f "$gen/CHANGELOG.md"
grep -q "Probe shipped." "$gen/CHANGELOG.md"

"$circus_bin" plugins check "$repo" >/dev/null

echo "ok: plugins-ships-changelog"
