# laicluse-agent-fieldkit marketplace

Public l'Aicluse Agent Fieldkit marketplace. This repository contains the public,
shareable plugins, skills, hooks, and agent adapters.

## Multi-agent marketplace

This is neither a Claude-only nor a Codex-only repository.
`packages/<plugin>/` is the canonical source for each plugin; Claude and Codex
receive their own runtime form through generated adapters. New tooling should
therefore be designed as multi-agent by default, or be marked explicitly as
agent-specific with the suffix convention below. Account for future agents
beyond Claude and Codex.

## Writing Style

Language: English for all repository documentation and public skill text.
Code, manifests, and commit messages also stay English. Keep package names,
framework names, and literal trigger phrases unchanged when they are part of a
skill's matching behavior.

## Package README Structure

Package READMEs under `packages/<plugin>/README.md` are public website detail
pages as well as repository documentation and machine-readable context for
future agents. Write them for all three audiences.

Start with the user-facing purpose in plain language: what the plugin is, who
it supports, and what practical problem it solves. Follow with a complete,
scan-friendly capability inventory before implementation internals. For plugins
with hooks, commands, skills, or generated adapter behavior, include stable
names in headings, tables, or bullets so humans, search index crawlers, and
agents can all find the same facts. Put install and configuration near the
capability description. Put architecture, contributor workflow, generated-file
notes, and tests after the product-level explanation.

Do not open a package README with registry mechanics, adapter internals, or
historical migration notes unless that is the plugin's primary user-visible
purpose. Internal architecture is still documented, but it follows the readable
overview and complete capability catalog.

## Local Storage

All first-party runtime state for l'Aicluse Agent Fieldkit projects uses
`${LAICLUSE_HOME:-$HOME/.laicluse}` as its root. Create
subdirectories by component name, for example `~/.laicluse/drydry/`, not
by marketplace status (`public`, `private`) or repository name, and not under
new `~/.laicluse-*` roots.

Agent-harness caches managed by Claude or Codex themselves
(`~/.claude/plugins/cache`, `~/.codex/plugins/cache`, install indexes) stay
where the harness expects them. Do not write first-party state there unless the
harness API requires it. For legacy state: read or migrate from old paths, then
write only to `~/.laicluse`.

## Migration Status

This repository is the public canonical home for l'Aicluse Agent Fieldkit.
Publish only changes that external users can follow with a working install or
migration route.

The previous public marketplace identity has been retired through a hard
cutover. Do not reintroduce old marketplace aliases, old storage roots, or
parallel migration stubs in this repository; current docs and install commands
point at `laicluse-agent-fieldkit`.

## Plugin Conventions

- Skills live under `packages/<plugin>/skills/<skill>/`.
- Use `SKILL.md` only when the skill is truly multi-agent-compatible.
- Use `SKILL.claude.md` and/or `SKILL.codex.md` when the workflow differs per
  agent or only one agent can support it; `bin/plugin-adapters build .`
  materializes the runtime `SKILL.md` targets that exist for each agent.
- Prefer host-owned capability contracts over hard runtime dependency routes in
  shared skill text. Describe the outcome the active host must arrange
  (continue the loop, provide an independent reviewer, drive a browser, send a
  notification) and let Claude, Codex, or future agents satisfy it with their
  available tools. Hard-code another skill, plugin, MCP server, or helper only
  when that dependency is itself the public API the workflow is about.
- Claude metadata remains the source; Codex manifests and `.agents/plugins/`
  are generated adapters.
- No symlinks; the same layout must work on macOS, Linux, and Windows.
