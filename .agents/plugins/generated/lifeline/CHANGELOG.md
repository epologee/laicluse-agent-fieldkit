# lifeline changelog

The post-update broadcast (see `bin/check-broadcast`) shows the topmost
section once per machine whenever the installed `version` in
`.claude-plugin/plugin.json` changes. Entry headers record the version at
which the entry was written; a pre-commit hook auto-bumps `plugin.json` on
every commit, so the header may lag the shipped version. Header numbers are
informational, the broadcast is positional. Use the `--force` flag on the
helper to re-read at any time.

Categories:

- **Breaking**: user must adapt
- **Added**: new commands, new optional behavior
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

Patch-level fixes that change nothing the user can observe are intentionally
omitted; the broadcast budget is for things the user benefits from knowing.

## [v2.0.2]

### Added

- **`rethink` returns a drifting project to first principles before another local fix is attempted.** It reconstructs intent and actual behavior from design documents, code, Git history, runtime evidence, transcripts, and operator experience; writes a governing manifesto; and stress-tests its abstraction level through independent review and a one-question-at-a-time operator interview. The workflow keeps refinement and implementation outside the coordinating artifact unless they are separately requested.

## [v1.0.0]

### Added

- **`inspire` and `ground` now ship together from the `lifeline` plugin.**
  Both skills move here from their standalone plugins under the previous
  marketplace. `/inspire` researches what others did before you commit to a
  path; `/ground` verifies your own recent output against external sources
  when a claim is doubted. The slash commands and trigger phrases are
  unchanged; only the plugin that carries them changed. Install via
  `lifeline@laicluse-agent-fieldkit` and uninstall the old `inspire` and
  `ground` plugins.
