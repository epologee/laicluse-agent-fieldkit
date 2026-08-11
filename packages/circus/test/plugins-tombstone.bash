#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
mkdir -p "$repo/.claude-plugin" "$repo/packages/retired/.claude-plugin"

cat > "$repo/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "probe-marketplace",
  "plugins": [
    { "name": "retired", "description": "DEPRECATED: moved elsewhere.", "source": "./packages/retired" }
  ]
}
JSON

cat > "$repo/packages/retired/.claude-plugin/plugin.json" <<'JSON'
{ "name": "retired", "version": "1.0.2", "description": "DEPRECATED: moved elsewhere." }
JSON

"$circus_bin" plugins build "$repo" >/dev/null
! jq -e '.plugins[] | select(.name == "retired")' "$repo/.agents/plugins/marketplace.json" >/dev/null
"$circus_bin" plugins check "$repo" >/dev/null

echo "ok: plugins-tombstone"
