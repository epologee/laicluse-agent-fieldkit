---
name: whats-new
description: >-
  Explicit /whats-new: print latest marketplace or plugin CHANGELOG news without touching broadcast sentinels.
---

# Whats New

Show the latest CHANGELOG section for an installed
`laicluse-agent-fieldkit` plugin without touching any post-update broadcast
sentinel.

The normal user-facing invocation in Codex is `$whats-new`. Use the `/skills`
picker if the command surface needs disambiguation.

## What to do

Resolve installed plugin paths through `codex plugin list --json`. That is the
authoritative Codex install index; do not guess cache paths or inspect
`~/.codex/plugins/cache` as source.

When the operator provides a plugin name:

```bash
PLUGIN="<arg>"
INSTALL=$(codex plugin list --json | jq -er --arg id "${PLUGIN}@laicluse-agent-fieldkit" '
  .installed[]?
  | select(.pluginId == $id and (.enabled // true))
  | .source.path
' 2>/dev/null) || {
  echo "Plugin ${PLUGIN}@laicluse-agent-fieldkit is not installed or enabled in Codex."
  exit 0
}
if [ ! -x "$INSTALL/bin/check-broadcast" ]; then
  echo "Plugin ${PLUGIN}@laicluse-agent-fieldkit has no check-broadcast helper; CHANGELOG support not adopted yet."
  exit 0
fi
if [ ! -f "$INSTALL/CHANGELOG.md" ]; then
  echo "Plugin ${PLUGIN}@laicluse-agent-fieldkit has no CHANGELOG.md."
  exit 0
fi

awk '
  /^## \[/ { count++; if (count == 2) exit }
  count == 1 { print }
' "$INSTALL/CHANGELOG.md"
```

Place the output verbatim in a markdown block in your response. No summary, no
interpretation; the CHANGELOG is canonical.

When there is NO argument, the operator wants the marketplace-wide news, not the
per-plugin list. Print the latest section of the marketplace changelog, then a
one-line index of the installed plugins that ship their own per-plugin
CHANGELOG so the operator can drill in.

```bash
TOOLS=$(codex plugin list --json | jq -er '
  .installed[]?
  | select(.pluginId == "laicluse-agent-fieldkit@laicluse-agent-fieldkit" and (.enabled // true))
  | .source.path
' 2>/dev/null) || {
  echo "laicluse-agent-fieldkit@laicluse-agent-fieldkit is not installed or enabled in Codex."
  exit 0
}
if [ ! -f "$TOOLS/MARKETPLACE-CHANGELOG.md" ]; then
  echo "laicluse-agent-fieldkit@laicluse-agent-fieldkit is missing MARKETPLACE-CHANGELOG.md."
  exit 0
fi

awk '
  /^## \[/ { count++; if (count == 2) exit }
  count == 1 { print }
' "$TOOLS/MARKETPLACE-CHANGELOG.md"

echo
echo "---"
echo "Per-plugin CHANGELOGs available for:"
codex plugin list --json | jq -r '
  .installed[]?
  | select((.pluginId // "") | endswith("@laicluse-agent-fieldkit"))
  | [.pluginId, .source.path]
  | @tsv
' | while IFS="$(printf '\t')" read -r entry install; do
  plugin="${entry%@laicluse-agent-fieldkit}"
  if [ -x "$install/bin/check-broadcast" ] && [ -f "$install/CHANGELOG.md" ]; then
    echo "- $plugin"
  fi
done
echo
echo 'Pass a plugin name to drill in: $whats-new <plugin>'
```

Place the awk output verbatim in a markdown block. Then the index list. No
interpretation; the marketplace changelog is canonical.

## Why Codex reads CHANGELOG directly

The `bin/check-broadcast` helper remains the adoption signal for per-plugin
CHANGELOG support. Codex does not call the helper here because generated Codex
plugin roots carry `.codex-plugin/plugin.json`, while older helper versions look
for Claude's `.claude-plugin/plugin.json`. Directly reading the latest
CHANGELOG section preserves `/whats-new` behavior without touching broadcast
sentinels.

## What NOT to do

- No edits to any CHANGELOG from within this skill. Authors maintain their
  CHANGELOG.md outside the agent.
- No modifications to sentinels under `${LAICLUSE_HOME:-~/.laicluse}/<plugin>/broadcasts/`.
- No assumptions about which plugins have adopted the broadcast pattern; the
  presence of `bin/check-broadcast` is the source of truth.
