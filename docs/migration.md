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
- `house-rules`
- `laicluse-agent-fieldkit`

## house-rules absorbs naming-is-hard

`house-rules` is the opinionated craft-doctrine plugin: it ships the
`programming-philosophy`, `testing-philosophy`, and `naming-is-hard` skills
together. The `naming-is-hard` skill is unchanged; it now ships from
`house-rules` instead of its own plugin. The standalone `naming-is-hard` plugin
has been retired.

If you installed the standalone plugin, switch to `house-rules`:

```bash
claude plugins install house-rules@laicluse-agent-fieldkit
claude plugins uninstall naming-is-hard@laicluse-agent-fieldkit
```

```bash
codex plugin add house-rules@laicluse-agent-fieldkit
```

`/naming-is-hard` keeps working exactly as before once `house-rules` is
installed.

## lifeline absorbs inspire and ground

`lifeline` is the consult-outside-yourself plugin: it ships the `inspire` and
`ground` skills together. `/inspire` researches what others did before you
commit to a path; `/ground` verifies your own recent output against external
sources when a claim is doubted. Both skills are unchanged; they now ship from
`lifeline` instead of their own standalone plugins. The slash commands and
trigger phrases are identical.

If you installed the standalone plugins, switch to `lifeline`:

```bash
claude plugins install lifeline@laicluse-agent-fieldkit
claude plugins uninstall inspire@leclause
claude plugins uninstall ground@leclause
```

```bash
codex plugin add lifeline@laicluse-agent-fieldkit
```

`/inspire` and `/ground` keep working exactly as before once `lifeline` is
installed.

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
claude plugins install house-rules@laicluse-agent-fieldkit
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
codex plugin add house-rules@laicluse-agent-fieldkit
```

Claude Code needs `/reload-plugins` plus `/reload-skills`, or a session
restart, after install changes. Codex picks up the new plugin set in a new
session.

## Maintainers

Claude metadata stays the source; the Codex adapters under `.agents/plugins/`
are generated and committed alongside it.

Runtime state stays under `${LAICLUSE_HOME:-$HOME/.laicluse}` by component
name, not by marketplace name.
