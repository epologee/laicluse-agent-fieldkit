#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
mkdir -p "$repo/.claude-plugin"
mkdir -p "$repo/packages/probe/.claude-plugin"
mkdir -p "$repo/packages/probe/skills/probe"
mkdir -p "$repo/packages/probe/hooks/guards"

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

cat > "$repo/packages/probe/skills/probe/SKILL.md" <<'MD'
---
name: probe
description: Probe skill.
---

# probe
MD

cat > "$repo/packages/probe/hooks/hooks.json" <<'JSON'
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

if "$circus_bin" plugins build "$repo" >"$tmp/build.out" 2>"$tmp/build.err"; then
  echo "expected direct Codex source with a Claude-style hook manifest to fail" >&2
  exit 1
fi
grep -q "top-level hooks key" "$tmp/build.err"

cat > "$repo/packages/probe/hooks/hooks.codex.json" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          { "type": "command", "command": "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/hooks/dispatch.sh" }
        ]
      }
    ]
  }
}
JSON
printf '#!/bin/sh\necho dispatch\n' > "$repo/packages/probe/hooks/dispatch.sh"
printf '#!/bin/sh\necho guard\n' > "$repo/packages/probe/hooks/guards/probe.sh"

"$circus_bin" plugins build "$repo" >/dev/null

gen="$repo/.agents/plugins/generated/probe"
test -f "$gen/hooks/hooks.json"
test -f "$gen/hooks/dispatch.sh"
test -f "$gen/hooks/guards/probe.sh"
test ! -f "$gen/hooks/hooks.codex.json"
grep -q 'PLUGIN_ROOT' "$gen/hooks/hooks.json"
grep -q '"path": "./.agents/plugins/generated/probe"' "$repo/.agents/plugins/marketplace.json"

"$circus_bin" plugins check "$repo" >/dev/null
