---
name: merge-to-default
user-invocable: true
description: >-
  Verify and atomically merge a worktree candidate into the current default branch without checking that branch out.
optional: true
scope: global
---

# Merge To Default

Merge the current worktree candidate as a real two-parent commit without checking out or mutating a default-branch worktree. The shared `git-discipline` executable creates the commit, validates candidate evidence, and updates the local or remote ref with compare-and-swap semantics. Do not reproduce that implementation with direct Git commands.

## Resolve policy and the shared command

```bash
resolve_git_discipline_root() {
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT"
    return 0
  fi
  if command -v codex >/dev/null 2>&1; then
    codex plugin list --json | jq -er '.installed[] | select(.pluginId == "git-discipline@laicluse-agent-fieldkit") | .source.path'
    return $?
  fi
  return 1
}

GD_ROOT="$(resolve_git_discipline_root)" || { echo "git-discipline plugin root not found" >&2; exit 1; }
"$GD_ROOT/bin/git-discipline" default
POLICY="$("$GD_ROOT/skills/push-policy/git-repo-policy")"
MODE="$(printf '%s\n' "$POLICY" | sed -n 's/^mode=//p')"
```

Repository policy determines the only valid merge target:

| Mode | Action |
|------|--------|
| `local-only` | Use `--local`; atomically update the local default ref. |
| `solo-trunk` | Use `--remote`; the non-force push is normal completion. |
| `team-trunk` | Use `--remote` only when the operator explicitly ordered this default merge; that order is the go for the shared ref update. |
| `pr-flow` | Do not update the default ref directly. Follow the repository's PR flow; the remote merge remains an explicit operator gate. |
| `external` | Do not update the default ref; there is no write access. |

```bash
case "$MODE" in
  local-only) TARGET=--local ;;
  solo-trunk|team-trunk) TARGET=--remote ;;
  pr-flow) echo "Default is protected; use the repository PR flow." >&2; exit 1 ;;
  external) echo "Repository is external; default cannot be updated from this checkout." >&2; exit 1 ;;
  *) echo "Unknown git-discipline mode: $MODE" >&2; exit 1 ;;
esac
```

## Prepare and verify the candidate

If the worktree is dirty, commit only the completed logical slice with `git-discipline:commit-snipe` or `git-discipline:commit-all-the-things` as appropriate. Then use the shared rebase operation; the worktree owner resolves any conflict here.

```bash
"$GD_ROOT/bin/git-discipline" rebase "$TARGET"
"$GD_ROOT/bin/git-discipline" verify "$TARGET" -- <test-command> [args...]
```

The verification command must cover the relevant behavior at the exact candidate SHA. A candidate is mergeable only when it is a descendant of the current default tip and its passing proof names that same candidate and base.

## Atomic two-parent merge

```bash
"$GD_ROOT/bin/git-discipline" merge "$TARGET"
```

The executable creates a merge commit whose first parent is the verified default tip, whose second parent is the candidate, and whose tree equals the candidate tree. `--local` uses `git update-ref <ref> <new> <expected>`; `--remote` uses a normal non-force push. If another merge wins first, the compare-and-swap fails without changing the default ref. Rebase on the new tip, rerun the relevant verification, and retry until the candidate wins or a genuine gate is reached. Do not add a long-lived merge lock.

Keep the source worktree and branch until merge and any required deployment are proven complete; cleanup belongs to `bonsai:prune`. Deployment is repository-specific and must use the exact merged SHA from a clean deploy checkout, never this authoring worktree.

Report the candidate SHA, verified base SHA, merge SHA, target, race retries, and deployment state when deployment was part of the order.
