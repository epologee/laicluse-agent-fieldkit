# eye-of-the-beholder changelog

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
The helper writes the sentinel only when stdout is non-empty, so a CHANGELOG
without a `## [vX.Y.Z]` section stays silent on every update.

## [v2.0.1]

### Breaking

- **eye-of-the-beholder now ships from the public laicluse-agent-fieldkit marketplace.** Install the Fieldkit copy for `eye-of-the-beholder`, `art-director`, and `visual-inspection`, then uninstall the old `eye-of-the-beholder@leclause` package. The skill names and trigger phrases are unchanged; only the marketplace identity changed.

### Changed

- **Codex receives generated adapter metadata for all three visual skills.** The skill sources remain shared, while Codex gets strict manifest and frontmatter views through the Fieldkit adapter build.

## [v1.0.35]

### Changed

- **External `impeccable` plugin no longer referenced.** Visual skills and `art-director` templates swap `impeccable` cross-references for canonical specs (WCAG 2.1, OKLCH) or "the build-time discipline in your session".
