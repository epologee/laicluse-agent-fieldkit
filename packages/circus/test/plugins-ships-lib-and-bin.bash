#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
mkdir -p "$repo/.claude-plugin"
mkdir -p "$repo/packages/probe/.claude-plugin"
mkdir -p "$repo/packages/probe/skills/board/bin"
mkdir -p "$repo/packages/probe/lib/commands"
mkdir -p "$repo/packages/probe/bin"
mkdir -p "$repo/packages/probe/templates"

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

cat > "$repo/packages/probe/package.json" <<'JSON'
{ "name": "probe", "private": true, "type": "module" }
JSON

cat > "$repo/packages/probe/skills/board/SKILL.md" <<'MD'
---
name: board
description: Board skill.
user-invocable: true
---

# board
MD

cat > "$repo/packages/probe/skills/board/bin/board.mjs" <<'JS'
import { hello } from '../../../lib/commands/hello.mjs';
console.log(hello());
JS

cat > "$repo/packages/probe/lib/commands/hello.mjs" <<'JS'
export function hello() { return 'from-lib'; }
JS

cat > "$repo/packages/probe/bin/probe" <<'JS'
#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { hello } from '../lib/commands/hello.mjs';
const here = dirname(fileURLToPath(import.meta.url));
const template = readFileSync(join(here, '../templates/message.txt'), 'utf8').trim();
console.log(`${hello()}:${template}`);
JS
chmod +x "$repo/packages/probe/bin/probe"

printf 'from-template\n' > "$repo/packages/probe/templates/message.txt"

"$circus_bin" plugins build "$repo" >/dev/null

gen="$repo/.agents/plugins/generated/probe"
test -f "$gen/lib/commands/hello.mjs"
test -f "$gen/bin/probe"
test -f "$gen/templates/message.txt"
test -f "$gen/package.json"
grep -q '"type": "module"' "$gen/package.json"

out="$(node "$gen/skills/board/bin/board.mjs")"
test "$out" = "from-lib"

out_bin="$(node "$gen/bin/probe")"
test "$out_bin" = "from-lib:from-template"

"$circus_bin" plugins check "$repo" >/dev/null
