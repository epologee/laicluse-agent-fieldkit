---
name: circus
description: >-
  Sync multi-agent doctrine, AGENTS/CIRCUS files, and plugin metadata across Claude, Codex, and future agents.
---

# circus

The Circus (le Carre's nickname for MI6) is a central source that briefs each
coding agent. It has three levels and three command groups.

## Explicit Invocation

When the operator says `circus`, `$circus`, "met circus", "via circus", or asks
for multi-agent `AGENTS.md` / `CLAUDE.md` / system-prompt setup, use this skill
as the active workflow. Do not hand-roll separate `AGENTS.md` and `CLAUDE.md`
files and call that done.

First identify the intended level:

- **User level**: global agent doctrine under `~/.laicluse/circus/`; edit the
  source there and run `circus build`.
- **Project level**: instructions inside the current repo or directory; create
  or edit `CIRCUS.md` as the source of truth and run `circus sync <path>`.
- **Plugin level**: marketplace/plugin metadata or skill adapters; edit the
  plugin source and run the relevant `circus plugins build|check|diff`.

If the target level is ambiguous, ask one concrete clarification before editing:
"Do you mean one umbrella `CIRCUS.md` here, or per child repo?" A parent
directory that contains multiple repos is ambiguous unless the operator names a
specific child repo.

After any manual change to project-level agent instructions, run
`circus sync <path>` before reporting done. Verify that `CLAUDE.md` and
`AGENTS.md` carry the `SYNCED` banner and match `CIRCUS.md` after stripping the
banner.

## User Level: `circus build`

Source lives in `~/.laicluse/circus/`:

- `shared/*.md` is shared doctrine, agent-agnostic and
  concatenated in order.
- `specific/<agent>.md` is per-agent guidance such as tool names, hooks, and
  escape hatches.
- `targets` is the `name=output_path` mapping. A target line may add
  `supported=false` to keep an agent configured but inactive, or
  `supported=auto detect=<command>` to skip it unless that command exists.

`circus build` combines `shared/*` with the relevant specifics and writes every
active agent instruction file listed in `targets`, for example
`~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. Each generated file carries a
`<!-- GENERATED ... -->` banner. A handwritten target is never silently
overwritten; it is staged as `<target>.generated` for review, then activated
with `circus build --force <name>`.

When anything under `~/.laicluse/circus/` changes, run `circus build`. This is
operational recovery: idempotent, local, and not an approval gate. New writes go only to `~/.laicluse/circus/`.

## Project Level: `circus sync`

Keeps a repo's `CIRCUS.md`, `CLAUDE.md`, and `AGENTS.md` identical.
`CIRCUS.md` is the visible committed ground truth. `CLAUDE.md` and `AGENTS.md`
carry a `<!-- SYNCED ... -->` banner and are derived targets.

`circus sync [path]` (default cwd) uses the last committed `CIRCUS.md`
(`git show HEAD:CIRCUS.md`) as the ancestor and decides content-based which
file was edited:

- nothing edited -> already in sync
- `CIRCUS.md` edited -> it wins and is folded to all three files
- only `CLAUDE.md` or only `AGENTS.md` edited -> that file wins and is folded
  to the other two
- both `CLAUDE.md` and `AGENTS.md` edited differently -> conflict

Commit the synced state so the ancestor moves with it.

## Plugin Level: `circus plugins`

`circus plugins build [repo]` reads a marketplace repo with
`.claude-plugin/marketplace.json` and
`packages/<plugin>/.claude-plugin/plugin.json`. Claude metadata is source.
Suffixless `skills/<skill>/SKILL.md` files stay in place when they are
multi-agent compatible. `SKILL.claude.md` and `SKILL.codex.md` are
agent-specific sources: they may exist as a pair for parity-by-variant, or
singly when a multi-agent plugin intentionally has partial skill coverage.
Circus generates adapters:

- `.agents/plugins/marketplace.json`
- `packages/<plugin>/.codex-plugin/plugin.json`
- `.agents/plugins/generated/<plugin>/...` when Codex needs a generated
  package, for example because a Claude-only frontmatter field must be
  sanitized or because Codex needs an explicit `hooks/hooks.codex.json`
  materialized as runtime `hooks/hooks.json`
- `packages/<plugin>/skills/<skill>/SKILL.md` when `SKILL.claude.md` is the
  Claude runtime source

Codex hook manifests are stricter than Claude hook manifests. A direct Codex
source may expose `hooks/hooks.json` only when that JSON object has exactly one
top-level key, `hooks`. Claude-only metadata such as top-level `description`
belongs in Claude's `hooks/hooks.json`; Codex-specific hook payloads live in
`hooks/hooks.codex.json` and are materialized into the generated package.

The commands follow the same build/check/diff pattern as the system-prompt
targets:

```
circus plugins build [repo]   write Codex adapters
circus plugins check [repo]   exit 1 when adapters drift
circus plugins diff [repo]    show the generated diff without writing
circus plugins versions {--check|--write|--bootstrap|--staged} [repo]  check or update versions without a repo-local copy
```

This layer may assume the public `how-plugins-work` model exists: shared
`SKILL.md` is source when behavior is agent-agnostic, suffixed skill sources
are deliberate agent-specific coverage, manifests are agent adapters, and
runtime caches are output. The dependency runs only one way. Personal doctrine
and host-specific paths stay in user-level data, never in distributed plugin
docs or generated packages.

## Merge a Sync Conflict

Circus never merges a conflict itself. On conflict it exits 3 and the running
agent merges with its own judgment:

1. Read the three versions: ancestor `git show HEAD:CIRCUS.md`, `CLAUDE.md`
   (ours), and `AGENTS.md` (theirs).
2. Merge them into a document that preserves both intents; discard nothing
   silently.
3. Write the result to `CIRCUS.md`.
4. Run `circus sync` again; `CIRCUS.md` now wins and is rolled out to
   `CLAUDE.md` and `AGENTS.md`.

## Commands

```
circus build [--force] [name]  user level: generate supported targets from shared + specifics
circus sync [path]             project level: keep CIRCUS.md/CLAUDE.md/AGENTS.md equal
circus check                   report drift between source and user targets
circus diff                    show what a build would change
circus plugins <command>       build/check adapters or check/update plugin versions
circus list                    show root, doctrine, specifics, mapping, and skipped targets
circus edit                    open the source data in $EDITOR
```

## Where Things Live

- **Tool**: this plugin ships the `circus` generator at `bin/circus`; the host may expose it on PATH through its own resolver.
- **Personal data**: `~/.laicluse/circus/{shared,specific,targets}` (override
  with `CIRCUS_ROOT`). This is the user's doctrine and support matrix and
  does not belong in a plugin package.
- **Project ground truth**: `CIRCUS.md` in each synced repo.
- **Plugin source**: `.claude-plugin/marketplace.json`,
  `.claude-plugin/plugin.json`, and `skills/` in the marketplace repo.
- **Plugin adapters**: `.agents/plugins/marketplace.json`,
  `.codex-plugin/plugin.json`, and optional
  `.agents/plugins/generated/<plugin>/` materializations generated by
  `circus plugins build`.
