# drydry changelog

Each entry corresponds to the `version` in `.claude-plugin/plugin.json`. The
post-update broadcast (see `bin/check-broadcast`) shows the section for the
currently-installed version exactly once per machine. Use
`/whats-new drydry` to re-read at any time.

Categories:

- **Breaking**: user must adapt
- **Added**: new commands, new optional behavior
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

Patch-level fixes that change nothing the user can observe are intentionally
omitted; the broadcast budget is for things the user benefits from knowing.
The helper writes the sentinel only when stdout is non-empty, so a CHANGELOG
without a `## [vX.Y.Z]` section stays silent on every update.

## [v2.0.0]

### Breaking

- **Marketplace identity moved to Fieldkit.** Install as
  `drydry@laicluse-agent-fieldkit` in Claude Code or Codex; previous
  marketplace installs do not rename themselves.

### Changed

- **Codex receives generated adapter metadata.** The skill text now uses
  host-owned reviewer and research capability contracts instead of hard-coding
  one agent runtime for the drydry audit passes.
- **Runtime state moved under `${LAICLUSE_HOME:-$HOME/.laicluse}`.** Broadcast
  sentinels are stored under `drydry/broadcasts/`.

## [v1.0.20]

### Added

- Audit mode catches parallel-orchestration drift: two or more entry points to the same domain action that each orchestrate a preflight stack above a shared leaf-call, a duplication shape the eight previous formulation prompts did not name.

## [v1.0.12]

### Breaking

- Audit mode no longer hands you a canned checklist. The calling session formulates the duplication checklist itself against eight formulation prompts in `drydry:drydry` step 2.
- `drydry:checklist` is now opt-in via `seed-from <domain>`. No-keyword audits never dispatch it.

### Added

- New mandatory step 2.5: a contrarian Sonnet subagent reads the formulated checklist against the scope and surfaces what it is failing to name. Audits the omission of findings the way Chapter 7 audits the rejection of findings.

## [v1.0.9]

### Added

- `/drydry:drydry`: one user-invocable command, two modes. Quick mode answers "is this duplicate?" inline with a verifier-grep. Audit mode produces a `<scope>-drydry-findings-<timestamp>.md` artefact.
- `/drydry:drydry learn <topic>`: writes research proposals to `<project_root>/.drydry/learnings/`. The next audit folds in `robust`-confidence proposals automatically.
