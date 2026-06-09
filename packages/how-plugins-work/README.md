# how-plugins-work

Reference for Claude Code and Codex plugin naming, skill resolution,
cross-agent skill sync, and the `plugin:skill` invocation pattern.

## Commands

### `/how-plugins-work`

Loads the reference: how slash-command names map to plugins, how sub-skills
resolve, when the `plugin:skill` form is required, how shared skills can be
packaged for multiple agents, and where plugin caches fit.

## Auto-trigger

Activates when diagnosing:

- "Unknown command" errors after a fresh install
- Slash-command autocomplete misses
- Confusion between plugin name, skill name, and command name
- Sub-skills that work in isolation but not when invoked from another skill
- Cross-agent marketplace or manifest drift between shared skills and agent-specific adapters

## Installation

Install:

```bash
claude plugins install how-plugins-work@laicluse-agent-tools
codex plugin add how-plugins-work@laicluse-agent-tools
```
