# clipboard

Copy the core content of the last assistant answer to the macOS clipboard. Plain text by default, Slack-flavored rich text on request.

## Commands

### `/clipboard`

Copies the relevant content of the last answer to the clipboard as plain text via the `clipboard-copy` helper (which wraps `pbcopy`). The skill picks the core content (code block, summary, answer body) rather than the full response wrapper.

### `/clipboard slack`

Copies as Slack rich text via `clipboard-copy --html` (which wraps `pbcopy-html`), preserving bold, italic, code spans, and code blocks when pasted into Slack.

## Requirements

macOS, with Node.js on `$PATH` (the `clipboard-copy` helper and the update-broadcast check are Node scripts). Plain text mode uses the built-in `pbcopy` and works out of the box; the skill calls the `clipboard-copy` helper that ships inside `bin/` of the plugin, resolved via `${CLAUDE_PLUGIN_ROOT}` (or, in another agent, relative to the loaded skill file), so no PATH-level install step is needed.

Rich text mode (`/clipboard slack`) drives `pbcopy-html`, a Swift script shipped with the plugin. Copy it onto your `$PATH` if you want to invoke `pbcopy-html` directly from a shell; `clipboard-copy --html` already resolves it relative to its own location. The `jq` lookup below is a shell convenience for finding the active install from your terminal (where `${CLAUDE_PLUGIN_ROOT}` is not set); the skill itself never uses it, and the copy is repeated after each plugin update per the note below. The marketplace is symlink-free to keep Windows consumers working, so install with `cp -f`:

```bash
SRC=$(jq -r '.plugins["clipboard@laicluse-agent-tools"][0].installPath // empty' ~/.claude/plugins/installed_plugins.json)
[ -n "$SRC" ] || { echo "clipboard@laicluse-agent-tools is not installed"; exit 1; }
cp -f "$SRC/skills/clipboard/pbcopy-html.swift" /usr/local/bin/pbcopy-html
```

The script runs via its `#!/usr/bin/env swift` shebang; no compile step is needed.

Re-run after each `claude plugins update clipboard@laicluse-agent-tools` so the installed copy matches the updated plugin.

## Consuming from another plugin

A skill in a different plugin cannot use `${CLAUDE_PLUGIN_ROOT}` to find this
plugin's helper (that variable points at its own root). The canonical
resolution idiom for cross-plugin consumers is one lookup against the
harness's install index, with a graceful skip when clipboard is absent:

```bash
IP=$(jq -r '.plugins["clipboard@laicluse-agent-tools"][0].installPath // empty' ~/.claude/plugins/installed_plugins.json 2>/dev/null)
if [ -n "$IP" ] && [ -x "$IP/bin/clipboard-copy" ]; then
  printf 'content' | "$IP/bin/clipboard-copy"
fi
```

Copy this idiom rather than inventing a variant; it is the one place the
install key lives outside this plugin.

## Installation

```bash
claude plugins install clipboard@laicluse-agent-tools
```

Migrating from `clipboard@leclause`: the skill name and behaviour are unchanged (`/clipboard`, `/clipboard slack`). Install this plugin, then run `claude plugins uninstall clipboard@leclause`.
