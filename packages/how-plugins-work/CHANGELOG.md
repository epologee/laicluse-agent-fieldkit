# how-plugins-work changelog

Each entry corresponds to the `version` in `.claude-plugin/plugin.json`. The
post-update broadcast (see `bin/check-broadcast`) shows the section for the
currently-installed version exactly once per machine. Use
the marketplace-wide whats-new skill to re-read at any time while that helper is
installed.

Categories:

- **Breaking**: user must adapt
- **Added**: new commands, new optional behavior
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

Patch-level fixes that change nothing the user can observe are intentionally
omitted; the broadcast budget is for things the user benefits from knowing.
The helper writes the sentinel only when stdout is non-empty, so a CHANGELOG
without a `## [vX.Y.Z]` section stays silent on every update.

## [v2.0.5]

### Changed

- **First public l'Aicluse release.** `how-plugins-work` now ships from
  `how-plugins-work@laicluse-agent-tools` with major version 2.

## [v1.0.4]

### Added

- **Agent-specific skill source convention.** `SKILL.md` is now reserved for
  truly agent-agnostic skill sources; paired `SKILL.claude.md` and
  `SKILL.codex.md` sources are generated into runtime `SKILL.md` targets when
  behavior needs to differ per agent.

## [v1.0.3]

### Changed

- **Project status moved out of the mechanics reference.** `how-plugins-work`
  now stays focused on plugin naming, marketplace aliases, adapter sync, caches,
  and local install mechanics; repo transition state belongs in repo-level docs.

## [v1.0.1]

### Changed

- **Multi-agent local marketplace baseline.** The skill now covers both Claude
  Code and Codex local marketplace installs, and stores broadcast state under
  `${LAICLUSE_HOME:-~/.laicluse}`.

## [v1.0.31]

### Added

- **Cross-agent sync vocabulary.** The skill now explains how to keep shared `SKILL.md` sources, Claude manifests, Codex manifests, marketplace indexes, and runtime caches in separate source/adapter/cache roles.

## [v1.0.27]

### Changed

- **Haiku no longer suggested as a subagent target.** Token-savings example lists Sonnet only (Sonnet has its own usage allocation; Haiku does not); the factual reference about supported `model` values still includes `haiku`.
