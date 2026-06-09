# self-improvement changelog

Each entry corresponds to the `version` in `.claude-plugin/plugin.json`.

Categories:

- **Breaking**: user must adapt
- **Added**: new commands, new optional behavior
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

## [v2.0.0]

### Changed

- **First l'Aicluse release.** The skill is now agent-neutral and routes
  feedback across hooks, skills, project code, and instruction files instead
  of assuming Claude-only `CLAUDE.md` targets.
