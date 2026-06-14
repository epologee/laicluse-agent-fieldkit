# laicluse-agent-tools

Marketplace-wide utilities for the laicluse-agent-tools marketplace. This
plugin is currently Claude Code-only because `/whats-new` reads Claude plugin
install metadata and broadcast sentinel state.

## Commands

### `/whats-new [plugin-name]`

With a plugin name (e.g. `git-discipline`): reprints the latest CHANGELOG
section of that installed plugin without touching its broadcast sentinel,
so the regular post-update broadcast still fires exactly once.

Without arguments: prints the latest marketplace-wide news from
`MARKETPLACE-CHANGELOG.md` plus an index of installed plugins that ship a
per-plugin CHANGELOG.

Use `/laicluse-agent-tools:whats-new` only when a namespaced form is needed.

## Installation

```bash
claude plugins install laicluse-agent-tools@laicluse-agent-tools
```

Coming from `leclause-skills`: `/leclause:whats-new` keeps working for
plugins that remain on the legacy marketplace; this plugin covers the
`@laicluse-agent-tools` installs.
