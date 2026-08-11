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

cat > "$repo/packages/probe/skills/probe/SKILL.md" <<'MD'
---
name: probe
description: Probe skill.
user-invocable: true
---

# probe
MD

"$circus_bin" plugins build "$repo" >/dev/null

mkdir -p "$repo/worktrees/stale"
cp -R "$repo/.agents" "$repo/.claude-plugin" "$repo/packages" "$repo/worktrees/stale/"

output="$("$circus_bin" plugins check "$repo")"
case "$output" in
  *"worktrees/stale"*) echo "FAIL: worktree copy leaked into adapter check" >&2; exit 1 ;;
esac

echo "ok: plugins-check-ignores-worktree-copies"
