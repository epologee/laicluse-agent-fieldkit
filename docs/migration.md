# Migration to l'Aicluse Agent Fieldkit

Status: active hard cutover.

## What Changed

The public marketplace identity is now `laicluse-agent-fieldkit`. It carries
the same field-ready agent plugins, skills, hooks, helpers, and reference docs
under a stronger name that pairs with the private `laicluse-agent-workbench`.

The package names for the individual plugins stay stable:

- `how-plugins-work`
- `self-improvement`
- `git-discipline`
- `dont-do-that`
- `intervision`
- `anger-management`
- `drydry`
- `autonomous`
- `gurus`
- `rover`
- `clipboard`
- `laicluse-agent-fieldkit`

## Existing Installs

Marketplace aliases are installation identities. Existing installs under the
previous marketplace identity do not automatically become Fieldkit installs.
Remove the old marketplace installs, then add this marketplace and install the
plugins you use.

Claude Code:

```bash
claude plugins marketplace add epologee/laicluse-agent-fieldkit
claude plugins install how-plugins-work@laicluse-agent-fieldkit
claude plugins install self-improvement@laicluse-agent-fieldkit
claude plugins install git-discipline@laicluse-agent-fieldkit
claude plugins install dont-do-that@laicluse-agent-fieldkit
claude plugins install intervision@laicluse-agent-fieldkit
claude plugins install anger-management@laicluse-agent-fieldkit
claude plugins install drydry@laicluse-agent-fieldkit
claude plugins install autonomous@laicluse-agent-fieldkit
claude plugins install gurus@laicluse-agent-fieldkit
claude plugins install rover@laicluse-agent-fieldkit
claude plugins install clipboard@laicluse-agent-fieldkit
claude plugins install laicluse-agent-fieldkit@laicluse-agent-fieldkit
```

Codex:

```bash
codex plugin marketplace add epologee/laicluse-agent-fieldkit
codex plugin add how-plugins-work@laicluse-agent-fieldkit
codex plugin add self-improvement@laicluse-agent-fieldkit
codex plugin add git-discipline@laicluse-agent-fieldkit
codex plugin add dont-do-that@laicluse-agent-fieldkit
codex plugin add intervision@laicluse-agent-fieldkit
codex plugin add anger-management@laicluse-agent-fieldkit
codex plugin add drydry@laicluse-agent-fieldkit
codex plugin add gurus@laicluse-agent-fieldkit
codex plugin add rover@laicluse-agent-fieldkit
codex plugin add clipboard@laicluse-agent-fieldkit
```

Claude Code needs `/reload-plugins` plus `/reload-skills`, or a session
restart, after install changes. Codex picks up the new plugin set in a new
session.

## Maintainers

Keep Claude metadata as source, then regenerate Codex adapters:

```bash
bin/plugin-adapters build .
bin/plugin-adapters check .
```

Runtime state stays under `${LAICLUSE_HOME:-$HOME/.laicluse}` by component
name, not by marketplace name.
