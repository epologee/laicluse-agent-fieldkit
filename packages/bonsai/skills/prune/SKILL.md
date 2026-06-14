---
name: prune
user-invocable: true
description: >-
  Tear down a git worktree behind a safety gate: keep any non-integrated work
  unless explicitly forced, and warn when removal would orphan unpushed commits
  or when the default branch has moved on. Use to clean up a finished or
  abandoned worktree without losing work by accident.
---

# prune

Tear down a worktree, safely. The gate is the point: a worktree that is clean
but not yet integrated still holds work, so it is kept by default.

## Resolve the bin (cross-agent)

```bash
resolve_bonsai_root() {
  if [ -n "${BONSAI_BIN:-}" ]; then dirname "$(dirname "$BONSAI_BIN")"; return 0; fi
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then printf '%s\n' "$CLAUDE_PLUGIN_ROOT"; return 0; fi
  if command -v codex >/dev/null 2>&1; then
    codex plugin list | awk '$1 == "bonsai@laicluse-agent-tools" { print $NF; found=1; exit } END { exit found ? 0 : 1 }'
    return $?
  fi
  return 1
}
ROOT="$(resolve_bonsai_root)" || { echo "bonsai plugin root not found" >&2; exit 1; }
BONSAI="${BONSAI_BIN:-$ROOT/bin/bonsai}"
```

## Check, then tear down

```bash
node "$BONSAI" teardown <worktree|branch> --repo "<root>" --dry-run --json   # classify only
node "$BONSAI" teardown <worktree|branch> --repo "<root>" --json             # remove if safe
```

A worktree is removed only when it is integrated into the default branch, or
when it is clean with nothing ahead of the default. Otherwise teardown keeps it
and returns `removed: false` with a reason. `--dry-run` reports the same
classification and warnings without removing anything. `--force` overrides the
gate and also deletes an unmerged branch; reach for it only on a deliberate
throwaway, and never wire it into an unattended caller.
