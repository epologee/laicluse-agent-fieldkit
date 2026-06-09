# Migration to l'Aicluse Agent Tools

Status: active.

## Decision

The legacy marketplace `epologee/leclause-skills` will not be renamed in
place. New multi-agent-compatible plugins ship under the
`laicluse-agent-tools` marketplace alias.

During the transition:

- `leclause-skills` remains the existing source for users.
- `laicluse-agent-tools` is the home for multi-agent-compatible plugins.
- `how-plugins-work`, `self-improvement`, and git-discipline may temporarily
  exist in multiple places. That is migration duplication, not a DRY problem.
- The new canonical plugin name for git-discipline is
  `git-discipline@laicluse-agent-tools`; the legacy name
  `gitgit@leclause` stays in place until the old marketplace can carry a
  plugin-specific migration stub.
- The new canonical plugin name for self-improvement is
  `self-improvement@laicluse-agent-tools`.
- Migration status belongs here and in package-specific changelogs or stubs,
  not in `how-plugins-work`. That skill documents plugin mechanics only:
  naming, aliases, cache behavior, and adapter sync.

## For Existing Users

Install the new marketplace alongside the old one:

```bash
claude plugins marketplace add epologee/laicluse-agent-tools
```

Marketplace aliases are installation identities; `@leclause` does not become
`@laicluse-agent-tools` automatically.

When a plugin moves, the old marketplace keeps at least one migration stub that
explains which legacy install can be removed and which new install replaces it.
Only then may the real legacy plugin disappear.

## For Maintainers

Work plugin by plugin. Keep Claude metadata as the source and generate Codex
adapters with `bin/plugin-adapters`. Keep runtime state under
`${LAICLUSE_AGENT_HOME:-$HOME/.laicluse-agent}`.
