# how-plugins-work

Living document explaining how Claude Code and Codex plugin naming, skill
resolution, cross-agent skill sync, and the `plugin:skill` invocation pattern
actually behave in practice. Based on empirical testing, updated when behavior
shifts.

## Commands

### `/how-plugins-work`

Loads the current understanding: how slash-command names map to plugins, how sub-skills resolve, when the `plugin:skill` form is required, how shared skills can be packaged for multiple agents, and the gotchas around plugin caching.

## Auto-trigger

Activates when diagnosing:

- "Unknown command" errors after a fresh install
- Slash-command autocomplete misses
- Confusion between plugin name, skill name, and command name
- Sub-skills that work in isolation but not when invoked from another skill
- Cross-agent marketplace or manifest drift between shared skills and agent-specific adapters

## Why a living document

Plugin behavior is undocumented in places and shifts between agent releases.
Rather than guess from memory, the skill records what the latest tests show and
updates when something changes.

## Installation

Local-only during the l'Aicluse migration:

```bash
claude plugins install how-plugins-work@laicluse-agent-tools
codex plugin add how-plugins-work@laicluse-agent-tools
```
