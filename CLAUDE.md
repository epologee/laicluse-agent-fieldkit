# laicluse-agent-tools marketplace

Public l'Aicluse Agent Tools marketplace. This repository contains the public,
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

## Local Storage

All first-party runtime state for l'Aicluse Agent Tools projects uses
`${LAICLUSE_HOME:-$HOME/.laicluse}` as its root. Create
subdirectories by component name, for example `~/.laicluse/circus/`, not
by marketplace or repository name (`toolbox`, `public`, `private`) and not
under new `~/.laicluse-*` or `~/.leclause-*` roots.

Agent-harness caches managed by Claude or Codex themselves
(`~/.claude/plugins/cache`, `~/.codex/plugins/cache`, install indexes) stay
where the harness expects them. Do not write first-party state there unless the
harness API requires it. For legacy state: read or migrate from old paths, then
write only to `~/.laicluse`.

## Migration Status

This repository is the public successor for selected tools from
`epologee/leclause-skills`. Publish only changes that external users can follow
with a working install or migration route.

During the transition, `how-plugins-work` and git-discipline may temporarily
exist in multiple places: legacy public (`leclause-skills`) and new public
(`laicluse-agent-tools`). That is intentional migration duplication, not a DRY
findings list. Do not remove an old copy without a working migration stub for
existing users. This repository becomes the public canonical home.

## Plugin Conventions

- Skills live under `packages/<plugin>/skills/<skill>/`.
- Use `SKILL.md` only when the skill is truly multi-agent-compatible.
- Use `SKILL.claude.md` and/or `SKILL.codex.md` when the workflow differs per
  agent or only one agent can support it; `bin/plugin-adapters build .`
  materializes the runtime `SKILL.md` targets that exist for each agent.
- Claude metadata remains the source; Codex manifests and `.agents/plugins/`
  are generated adapters.
- No symlinks; the same layout must work on macOS, Linux, and Windows.
