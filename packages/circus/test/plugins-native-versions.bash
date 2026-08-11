#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
mkdir -p "$repo/.claude-plugin" "$repo/packages/probe/.claude-plugin"

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
{ "name": "probe", "version": "3.0.1", "description": "Probe plugin." }
JSON

git -C "$repo" init -q
git -C "$repo" config user.name "Circus Test"
git -C "$repo" config user.email "circus@example.invalid"
git -C "$repo" add .
git -C "$repo" -c core.hooksPath=/dev/null commit -qm "Add probe plugin"

"$circus_bin" plugins versions --check "$repo"

python3 - "$repo/packages/probe/.claude-plugin/plugin.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
manifest = json.loads(path.read_text())
manifest["description"] = "Updated probe plugin."
path.write_text(json.dumps(manifest, indent=2) + "\n")
PY

"$circus_bin" plugins versions --write "$repo" >/dev/null
jq -e '.plugins[0].description == "Updated probe plugin."' \
  "$repo/.claude-plugin/marketplace.json" >/dev/null

echo "ok: plugins-native-versions"
