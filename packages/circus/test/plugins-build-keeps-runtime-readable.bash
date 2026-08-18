#!/usr/bin/env bash
# A build must never make the generated runtime disappear, not even briefly.
# Git hooks and Codex sessions execute straight out of
# .agents/plugins/generated/<name>/, so a build that clears that directory
# before refilling it breaks whatever runs in the window: a concurrent
# `git push` reports a missing plugin binary and fails.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
mkdir -p "$repo/.claude-plugin" \
         "$repo/packages/probe/.claude-plugin" \
         "$repo/packages/probe/skills/board" \
         "$repo/packages/probe/bin"

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

cat > "$repo/packages/probe/skills/board/SKILL.md" <<'MD'
---
name: board
description: Board skill.
user-invocable: true
---

# board
MD

cat > "$repo/packages/probe/bin/probe" <<'SH'
#!/usr/bin/env bash
printf 'probe\n'
SH
chmod +x "$repo/packages/probe/bin/probe"

"$circus_bin" plugins build "$repo" >/dev/null

runtime="$repo/.agents/plugins/generated/probe/bin/probe"
test -x "$runtime"

misses="$tmp/misses"
stop="$tmp/stop"
: > "$misses"

(
  while [ ! -f "$stop" ]; do
    [ -x "$runtime" ] || printf 'x' >> "$misses"
  done
) &
sampler=$!

"$circus_bin" plugins build "$repo" >/dev/null

: > "$stop"
wait "$sampler"

if [ -s "$misses" ]; then
  printf 'FAIL: generated runtime was unreadable during %s samples of a build\n' \
    "$(wc -c < "$misses" | tr -d ' ')" >&2
  exit 1
fi

test -x "$runtime"
"$circus_bin" plugins check "$repo" >/dev/null
printf 'ok\n'
