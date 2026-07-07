# bonsai changelog

The post-update broadcast shows the topmost section once per machine whenever
the installed `version` in `.claude-plugin/plugin.json` changes. Keep entries
short; categories are Breaking, Added, Changed, Fixed.

## [v2.0.28]

### Added

- **Worktree locks now carry the branch as a work description.** The dibs lock
  created by `bonsai create` records the branch name as words, so later
  inspection shows what work the lock represented.

## [v2.0.21]

### Fixed

- **No more worktree-in-a-worktree**: `bonsai create` now anchors new worktrees
  at the main working tree even when `--repo` (or the cwd) points at a linked
  worktree, instead of nesting `worktrees/<name>` under that worktree. A caller
  such as conveyor that grounds an order inside a worktree no longer produces a
  `repo/worktrees/a/worktrees/b` layout.

## [v2.0.0]

### Added

- **Worktree CLI**: `bonsai create`, `bonsai setup`, and `bonsai teardown`
  manage the full worktree lifecycle git-natively, with `--json` facts output.
- **Safety gate on teardown**: a clean-but-non-integrated worktree is kept by
  default; removal needs integration or an explicit `--force`. Warns on orphaned
  unpushed commits and on a diverged default branch.
- **Skills**: `bonsai` (create + setup), `setup`, and `prune`, agent-neutral and
  resolving the CLI cross-agent.

### Breaking

- Dropped the clipboard / start-command mechanism and the macOS-only
  requirement. Bonsai now emits facts and launches nothing. Install
  `bonsai@laicluse-agent-fieldkit`.
