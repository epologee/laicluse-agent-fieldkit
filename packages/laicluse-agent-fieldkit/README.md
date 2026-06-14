# laicluse-agent-fieldkit

Marketplace-wide utilities for the laicluse-agent-fieldkit marketplace. This
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

Use `/laicluse-agent-fieldkit:whats-new` only when a namespaced form is needed.

## Installation

```bash
claude plugins install laicluse-agent-fieldkit@laicluse-agent-fieldkit
```

This command covers plugins installed from `@laicluse-agent-fieldkit`.
Existing installs under the previous marketplace identity need to be removed
and reinstalled from Fieldkit.
