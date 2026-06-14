---
name: whats-new
user-invocable: true
description: With a plugin-name argument (e.g. `git-discipline`), reprints the latest CHANGELOG section for that installed laicluse-agent-tools plugin without touching its broadcast sentinel. Without argument, prints the latest section of the marketplace-wide MARKETPLACE-CHANGELOG and lists which plugins have a per-plugin CHANGELOG.
disable-model-invocation: true
argument-hint: "[plugin-name]"
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the laicluse-agent-tools plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("laicluse-agent-tools was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. In agents that do not set
`CLAUDE_PLUGIN_ROOT` the broadcast is intentionally skipped; that is the
guard's purpose, not an oversight.
</post-update-broadcast>

# /whats-new

Show the CHANGELOG section of an installed laicluse-agent-tools plugin
without touching the post-update broadcast sentinel.

The normal user-facing command is `/whats-new`. The fully namespaced fallback
is `/laicluse-agent-tools:whats-new` if another installed plugin ever makes the
bare form ambiguous.

## What to do

Resolve the install path of the requested plugin via
`~/.claude/plugins/installed_plugins.json` (canonical source). When the
operator provides a plugin name:

```bash
PLUGIN="<arg>"
INSTALL=$(jq -r --arg name "${PLUGIN}@laicluse-agent-tools" \
  '.plugins[$name][0].installPath // empty' \
  ~/.claude/plugins/installed_plugins.json)
if [ -z "$INSTALL" ]; then
  echo "Plugin ${PLUGIN}@laicluse-agent-tools is not installed."
  exit 0
fi
if [ ! -x "$INSTALL/bin/check-broadcast" ]; then
  echo "Plugin ${PLUGIN}@laicluse-agent-tools has no check-broadcast helper; CHANGELOG support not adopted yet."
  exit 0
fi
node "$INSTALL/bin/check-broadcast" --force
```

Place the output verbatim in a markdown block in your response. No
summary, no interpretation; the CHANGELOG is canonical.

When there is NO argument, the operator wants the marketplace-wide
news, not the per-plugin list. Print the latest section of the
marketplace CHANGELOG, then a one-line index of the plugins that
ship their own per-plugin CHANGELOG so the operator can drill in.

```bash
TOOLS=$(jq -r '.plugins["laicluse-agent-tools@laicluse-agent-tools"][0].installPath // empty' \
  ~/.claude/plugins/installed_plugins.json)
if [ -z "$TOOLS" ] || [ ! -f "$TOOLS/MARKETPLACE-CHANGELOG.md" ]; then
  echo "laicluse-agent-tools@laicluse-agent-tools is not installed or missing MARKETPLACE-CHANGELOG.md."
  exit 0
fi

awk '
  /^## \[/ { count++; if (count == 2) exit }
  count == 1 { print }
' "$TOOLS/MARKETPLACE-CHANGELOG.md"

echo
echo "---"
echo "Per-plugin CHANGELOGs available for:"
jq -r '.plugins | to_entries[] | select(.key | endswith("@laicluse-agent-tools")) | .key' \
  ~/.claude/plugins/installed_plugins.json | while read -r entry; do
  plugin="${entry%@laicluse-agent-tools}"
  install=$(jq -r --arg k "$entry" '.plugins[$k][0].installPath // empty' \
    ~/.claude/plugins/installed_plugins.json)
  if [ -x "$install/bin/check-broadcast" ]; then
    echo "- $plugin"
  fi
done
echo
echo "Pass a plugin name to drill in: /whats-new <plugin>"
```

Place the awk output verbatim in a markdown block. Then the index
list. No interpretation; the marketplace CHANGELOG is canonical.

## What NOT to do

- No edits to any CHANGELOG from within this skill. Authors maintain their
  CHANGELOG.md outside the agent.
- No modifications to sentinels under `${LAICLUSE_HOME:-~/.laicluse}/<plugin>/broadcasts/`.
  `--force` does not touch them; only the non-force broadcast blocks in a
  plugin's host skills write them.
- No assumptions about which plugins have adopted the broadcast pattern;
  the presence of `bin/check-broadcast` is the source of truth.
