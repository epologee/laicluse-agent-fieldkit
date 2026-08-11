#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
mkdir -p "$repo/.claude-plugin"
mkdir -p "$repo/packages/probe/.claude-plugin"
mkdir -p "$repo/packages/probe/skills/only/bin"

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

cat > "$repo/packages/probe/skills/only/SKILL.claude.md" <<'MD'
---
name: only
description: Claude-only skill.
user-invocable: true
---

# only
MD

cat > "$repo/packages/probe/skills/only/bin/only" <<'SH'
#!/bin/sh
echo only
SH
chmod +x "$repo/packages/probe/skills/only/bin/only"

"$circus_bin" plugins build "$repo" >/dev/null

test -f "$repo/packages/probe/skills/only/SKILL.md"
test ! -e "$repo/.agents/plugins/generated/probe"
test ! -e "$repo/packages/probe/.codex-plugin"

if jq -e '.plugins[] | select(.name == "probe")' "$repo/.agents/plugins/marketplace.json" >/dev/null 2>&1; then
  echo "FAIL: Claude-only plugin leaked into the Codex marketplace" >&2
  exit 1
fi

"$circus_bin" plugins check "$repo" >/dev/null

echo "ok: plugins-claude-only-excluded-from-codex"
