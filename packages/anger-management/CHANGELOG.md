# anger-management changelog

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

## [v2.0.9]

### Changed

- **The escalation vocabulary is now safeword, cuss, repair.** The public copy
  uses the safeword lane for immediate course correction, the cuss lane for
  delayed capture via swear/cuss words, and the repair lane for cooled-down
  high-confidence fixes.

## [v2.0.8]

### Added

- **Safeword commands interrupt and fix now.** `/safeword`,
  `/pineapple`, `/pineapplejuice`, `/pinapplejuice`, `/flugelhorn`, and
  `/banana` pause the current task to correct one visible friction point
  immediately instead of logging it for later repair.

## [v2.0.7]

### Changed

- **Repair now owns the owner-source fix path.** A high-confidence diagnosis now
  chooses target scope, source ownership, authoring strategy, pruning, and the
  fallback when the source cannot be found, so `/self-improvement` is no longer
  the default execution handoff.

## [v2.0.6]

### Changed

- **Repair now has a confidence gate.** The cooled-down diagnosis reads the
  full capture history, emits a confidence score plus mitigation level, and
  only proposes a fix at `0.80` confidence or higher. Lower-confidence findings
  leave the captures open so future passes keep the breadcrumb trail.

## [v2.0.3]

### Breaking

- **`/damn` is removed.** It read as too harsh for what it captured; use any of
  the remaining curse commands instead. Existing `/damn` captures in the pile
  stay valid and are still weighed by repair.

### Added

- **`/fucking` and `/fucked`** join `/fuck` as capture commands, so the curse
  lands in whatever grammatical shape it leaves your fingers.

## [v2.0.1]

### Changed

- **anger-management now ships from the public laicluse-agent-tools
  marketplace.** It replaces `anger-management@leclause`; uninstall that copy
  if you still have it.
- **The friction pile moved to `${LAICLUSE_HOME:-~/.laicluse}/anger-management/`.**
  Captures written under the old `~/.claude/var/leclause/` path migrate
  automatically on the next capture or repair.
- **The plugin is multi-agent.** Codex sessions capture to the same pile, and
  the background investigation falls back to `codex exec` when no `claude` CLI
  is available.

## [v1.0.2]

### Added

- New plugin. Curse at the agent with `/fuck`, `/shit`, `/crap`, `/wtf`, `/bullshit`, or `/damn` to capture one cheap friction line to a global log and move on, no fix demanded in the moment.
- `/anger-management:repair` is the cooled-down fix pass: a go/no-go verdict (nothing / not-enough-signal / fix) that routes a real recurring problem to `/self-improvement`, or changes nothing when the pattern is unclear. `/anger-management` stays a quick read-back of the pile.
