# circus

The Circus is one source of truth for the system prompts of multiple coding
agents. Change the source once, then build the configured agent-specific
targets, such as Claude Code, OpenAI Codex, or future agents supported on the
current machine.

`circus` is le Carre's nickname for MI6 in *Tinker Tailor Soldier Spy*: a
central service briefing field agents from one source.

This plugin ships the **generator** (`bin/circus`). **Personal data** lives outside the plugin in `~/.laicluse/circus/` (override with `CIRCUS_ROOT`), so distributed code contains no user-specific doctrine or host paths.

## Installation

```bash
claude plugins install circus@laicluse-agent-fieldkit
codex plugin add circus@laicluse-agent-fieldkit
```

Circus supports Claude Code and Codex from the same package source. Restart an
existing Codex session after installation; Claude Code can reload the installed
plugin with `/reload-plugins` and `/reload-skills`.

## Three Levels

**User level (`circus build`).** Source is `~/.laicluse/circus/`: `shared/*.md`
(shared doctrine), `specific/<agent>.md` (per-agent overlay), and `targets`
(`name=path`). It generates every active target listed there, for example
`~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. Target lines may add
`supported=false` to keep an agent known but inactive, or `supported=auto`
with `detect=<command>` to skip it unless that command exists. This is one-way,
with a `<!-- GENERATED -->` banner. A handwritten target is never overwritten
silently; it is staged as `<target>.generated` for review and can be activated
with `--force`.

The build step exists because Codex does not support file imports: shared text
must be physically present in the target file, and symlinks leave no room for
per-agent content.

**Project level (`circus sync`).** Keeps a repo's `CIRCUS.md` (visible committed
ground truth), `CLAUDE.md`, and `AGENTS.md` identical. It is bidirectional:
edit any of the three, and `circus sync` folds that edit into the other two
using the last committed `CIRCUS.md` as the ancestor. On a real conflict
(`CLAUDE.md` and `AGENTS.md` changed differently), the running agent merges;
circus itself does not.

**Plugin level (`circus plugins`).** Applies the public `how-plugins-work`
sync model to local marketplace repos. `SKILL.md` is shared source when
behavior is agent-agnostic. `SKILL.claude.md` and `SKILL.codex.md` are
agent-specific sources; they may exist as a pair for parity-by-variant, or
singly when a multi-agent plugin has partial skill coverage. Claude manifests
remain source; Codex manifests and `.agents/plugins/marketplace.json` are
generated adapters. When suffix sources are present, circus materializes the
runtime `SKILL.md` only for the agents that have source coverage. If Codex
rejects a Claude-only frontmatter field, circus materializes a sanitized
generated package under `.agents/plugins/generated/<plugin>/`. If Codex needs
hooks, use `hooks/hooks.codex.json`; circus materializes it as runtime
`hooks/hooks.json` in that generated package and keeps Claude-only hook metadata
out of Codex's strict hook schema. Circus owns that executable adapter logic;
generated manifests and runtime packages remain output.

## Usage

```
circus build [--force] [name]   generate user targets from shared + specific
circus sync [path]              sync project CIRCUS.md/CLAUDE.md/AGENTS.md
circus check                    drift report (exit 1 on drift)
circus diff                     show what a build would change
circus plugins build [repo]     generate Codex plugin adapters from Claude metadata
circus plugins check [repo]     drift check for generated plugin adapters
circus plugins diff [repo]      show adapter diff without writing
circus plugins versions {--check|--write|--bootstrap|--staged} [repo]  check or update marketplace plugin versions
circus list                     root, doctrine, specific, mapping
circus edit                     open the source data in $EDITOR
```

## Add an Agent

1. Add `name=~/path` to `~/.laicluse/circus/targets`.
2. Add `~/.laicluse/circus/specific/name.md` with per-agent instructions.
3. `circus build`.

Optional targets can stay in the file without being built:

```
claude=~/.claude/CLAUDE.md
codex=~/.codex/AGENTS.md
opencode=~/.config/opencode/AGENTS.md supported=false
future=~/.future-agent/AGENTS.md supported=auto detect=future-agent
```

`supported=auto` uses the target name as the detector when `detect=` is
omitted. `circus build`, `circus check`, and `circus diff` skip inactive
targets; `circus list` shows why they were skipped.
