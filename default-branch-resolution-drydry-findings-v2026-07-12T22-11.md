# Default branch resolution duplication findings

## Detection method chosen

Checklist `v2026-07-12T22-11` was formulated from the canonical sources in `laicluse-agent-fieldkit` and `laicluse-agent-workbench`. The sweep used `rg -n --hidden -S 'refs/remotes/.*/HEAD|init\.defaultBranch|defaultBranchName|function defaultBranch|DEFAULT=.*symbolic-ref|refs/heads/(main|master)' packages bin` with generated adapters, tests, and docs classified separately. An independent contrarian pass re-read both repositories and confirmed six actionable resolver paths; it also rejected `saysay`, the WIP gate, and push-policy as false convergence targets because their current fallback or conservative-unknown behavior is intentional.

## Findings

### Operational skills stopped without a remote

`packages/git-discipline/skills/merge-to-default/SKILL.md`, `packages/git-discipline/skills/rebase-latest-default/SKILL.md`, both canonical Intervision variants, and `packages/rover/skills/pride/SKILL.md` read only `origin/HEAD`. Drift hypothesis: local-only repositories cannot merge, rebase, or review a branch even though Git names an existing configured default. Triage: cheap and safe; use `origin/HEAD`, then verified `init.defaultBranch`, otherwise stop.

### Rover constructed a remote-only range

`packages/rover/skills/pride/SKILL.md` always built `origin/${DEFAULT}..HEAD`. Drift hypothesis: merely adding local name resolution would still produce a nonexistent remote ref. Triage: cheap and safe; carry a resolved ref, not only a branch name.

### Bonsai treated the current feature as default

`packages/bonsai/bin/bonsai-lib.mjs` fell back from `origin/HEAD` to current `HEAD` for creation and teardown. Drift hypothesis: a local-only repo opened on a feature branch can branch new work from that feature and can classify deletion against the wrong integration base. Triage: cheap and safety-critical; use a verified configured local default and reject ambiguity.

### Fieldkit Pages could publish feature-branch links

`bin/build-pages` fell back from `origin/HEAD` to current `HEAD`, then literal `main`. Drift hypothesis: a local Pages build from a feature branch can emit source links to an unpublished or temporary branch. Triage: cheap and safe; prefer a verified configured local default before presentation-only fallbacks.

### Workbench Conveyor guessed main or master

`packages/conveyor/lib/runtime.mjs` carried a separate `main`/`master` fallback. Drift hypothesis: worktree cleanup and merged-state detection disagree with Fieldkit for a local-only repository configured with a custom default such as `trunk`. Triage: cheap and safe; use the same resolver contract and keep unknown conservatively unmerged.

### Generated adapters mirrored stale behavior

Every changed plugin has a generated Codex mirror under `.agents/plugins/generated`. Drift hypothesis: fixing only canonical source leaves Codex running the old resolver. Triage: mechanical; rebuild and check adapters in both marketplaces, then refresh installed plugins.

## Rejected convergence targets

- `packages/saysay/bin/saysay` uses current `HEAD` only to choose a spoken context label; it does not make integration or deletion decisions.
- `packages/git-discipline/hooks/lib/wip-gate.sh` deliberately falls back to tracked-upstream or local-only commit scanning when remote default metadata is absent.
- `packages/git-discipline/skills/push-policy/git-repo-policy` deliberately classifies an unresolved remote default as `unknown`, the safe policy direction.

## Checklist gaps

No additional resolver implementations were found outside the six actionable paths. Prose mentioning “default branch” without resolving a ref was excluded.
