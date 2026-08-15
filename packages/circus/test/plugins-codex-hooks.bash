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
    ],
	"PreToolUse": [
	  {
	    "matcher": "Bash",
	    "hooks": [
	      { "type": "command", "command": "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/hooks/dispatch.sh" }
	    ]
	  }
    ]
  }
}
JSON
printf '#!/bin/sh\n[ -z "${PROBE_UMASK_OUTPUT:-}" ] || umask > "$PROBE_UMASK_OUTPUT"\necho dispatch\n' > "$repo/packages/probe/hooks/dispatch.sh"
printf '#!/bin/sh\necho guard\n' > "$repo/packages/probe/hooks/guards/probe.sh"
chmod +x "$repo/packages/probe/hooks/dispatch.sh"
chmod +x "$repo/packages/probe/hooks/guards/probe.sh"

"$circus_bin" plugins build "$repo" >/dev/null

gen="$repo/.agents/plugins/generated/probe"
test -f "$gen/hooks/hooks.json"
test -f "$gen/hooks/dispatch.sh"
test -f "$gen/hooks/guards/probe.sh"
test ! -f "$gen/hooks/hooks.codex.json"
test "$(jq -r '.version' "$gen/.codex-plugin/plugin.json")" = "1.0.0+codex.hooks.1"
grep -q 'PLUGIN_ROOT' "$gen/hooks/hooks.json"
grep -q 'PLUGIN_DATA' "$gen/hooks/hooks.json"
grep -q '"path": "./.agents/plugins/generated/probe"' "$repo/.agents/plugins/marketplace.json"

loaded_command="$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$gen/hooks/hooks.json")"
cache_root="$tmp/codex-home/plugins/cache/probe-marketplace/probe"
old_root="$cache_root/1.0.0"
plugin_data="$tmp/codex-home/plugins/data/probe-probe-marketplace"
mkdir -p "$cache_root" "$plugin_data"
cp -R "$gen" "$old_root"

umask_output="$tmp/first-hook-umask"
expected_umask="$(umask)"
first_output="$(PLUGIN_ROOT="$old_root" PLUGIN_DATA="$plugin_data" PROBE_UMASK_OUTPUT="$umask_output" sh -c "$loaded_command")"
test "$first_output" = "dispatch"
test "$(cat "$umask_output")" = "$expected_umask"

rm -rf "$old_root"
new_root="$cache_root/1.0.1"
cp -R "$gen" "$new_root"
printf '#!/bin/sh\necho new-dispatch\n' > "$new_root/hooks/dispatch.sh"
chmod +x "$new_root/hooks/dispatch.sh"

retained_output="$(PLUGIN_ROOT="$old_root" PLUGIN_DATA="$plugin_data" sh -c "$loaded_command")"
test "$retained_output" = "dispatch"

retained_link="$plugin_data/.runtime/hooks/by-version/1.0.0"
retained_target="$plugin_data/.runtime/hooks/by-version/$(readlink "$retained_link")"
rm -rf "$retained_target"
test -L "$retained_link"
test ! -e "$retained_link"
dangling_recovery_output="$(PLUGIN_ROOT="$old_root" PLUGIN_DATA="$plugin_data" sh -c "$loaded_command")"
test "$dangling_recovery_output" = "new-dispatch"
test -x "$retained_link/hooks/dispatch.sh"

fresh_plugin_data="$tmp/fresh-codex-home/plugins/data/probe-probe-marketplace"
mkdir -p "$fresh_plugin_data"
fallback_output="$(PLUGIN_ROOT="$old_root" PLUGIN_DATA="$fresh_plugin_data" sh -c "$loaded_command")"
test "$fallback_output" = "new-dispatch"

pretool_command="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$gen/hooks/hooks.json")"
missing_root="$tmp/missing-codex-home/plugins/cache/probe-marketplace/probe/1.0.0"
missing_data="$tmp/missing-codex-home/plugins/data/probe-probe-marketplace"
mkdir -p "$missing_data"
set +e
missing_output="$(PLUGIN_ROOT="$missing_root" PLUGIN_DATA="$missing_data" sh -c "$pretool_command" 2>&1)"
missing_status=$?
set -e
test "$missing_status" -eq 2
case "$missing_output" in *'restart this Codex session'*) ;; *) exit 1 ;; esac

"$circus_bin" plugins check "$repo" >/dev/null
