# vaultsync changelog

The post-update broadcast shows the topmost section once per machine whenever the installed `version` in `.claude-plugin/plugin.json` changes. Keep entries short; categories are Breaking, Added, Changed, Fixed.

## [v2.0.8]

### Fixed

- **Generated HTML viewers no longer block managed vault syncs.** Commit-message normalization records a changed HTML artifact as `Visual:` evidence when the configured LLM did not supply its own visual trailer, keeping Tilt viewer updates compatible with git-discipline.

## [v2.0.4]

### Added

- **Managed-checkout status is now a CLI contract.** `vaultsync managed [path] --json` reports whether a path belongs to a vaultsync-managed checkout, so other tools can integrate without depending on vaultsync's storage layout.
