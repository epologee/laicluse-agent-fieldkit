# gurus changelog

The post-update broadcast (see `bin/check-broadcast`) shows the topmost section
once per machine whenever the installed `version` in
`.claude-plugin/plugin.json` changes. Header version numbers are informational;
the broadcast is positional.

Categories:

- **Breaking**: user must adapt
- **Added**: new commands, new optional behavior
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

Patch-level fixes that change nothing the user can observe are intentionally
omitted; the broadcast budget is for things the user benefits from knowing.

## [v2.0.0]

### Added

- **gurus now ships from the public laicluse-agent-tools marketplace.** It
  replaces `gurus@leclause`; install `gurus@laicluse-agent-tools` alongside
  `rover@laicluse-agent-tools` so the rover's INSPECT panel review no longer
  depends on the legacy marketplace.
- **The plugin is multi-agent.** Claude keeps the original `gurus:sonnet-max`
  plugin-shipped subagent flow. Codex gets Codex-specific skill bodies that use
  native subagents when available and fall back to a clearly marked
  single-session panel review when they are not.

### Changed

- **Codex guru panels prefer cheaper native reviewer subagents.** Claude's
  `gurus:sonnet-max` agent remains Claude-only; the generated Codex package no
  longer ships that subagent definition.

## Legacy leclause history

## [v1.0.35]

### Changed

- **`/gurus:software` panel composition shifts: Ousterhout in, Thoughtbot out.** John Ousterhout brings the scope-cutting lens from *A Philosophy of Software Design* (deep modules, defining errors out of existence). Panel size and 6+/8 threshold unchanged.

## [v1.0.34]

### Changed

- **Sibling-skill references use suggestion-with-fallback.** `gurus:software` and `gurus:writers` recommend `/auto-loop` for autonomous handoff with a fallback for sessions that lack it; stop-mechanism examples cover both `/auto-loop` and `/autonomous:stop`.

## [v1.0.29]

### Changed

- Eric Evans replaces Tobi Lutke on the `/gurus:software` panel; size and 6+/8 threshold unchanged. Evans brings the domain-modeling lens (ubiquitous language, bounded contexts, aggregates, anti-corruption layers) the panel was missing.
