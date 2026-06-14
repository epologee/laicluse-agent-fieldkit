---
name: setup
user-invocable: true
description: >-
  Prime an existing git worktree: copy the .bonsai-listed files from the
  canonical checkout and install dependencies per directory by the package
  manager each lockfile names. Use when a worktree already exists (made by
  hand or by another tool) and still needs its gitignored files and packages.
---

# setup

Prime a worktree that already exists. Separate from creation so you can run it
on a worktree you made yourself.

## Resolve the bin (cross-agent)

```bash
resolve_bonsai_root() {
  if [ -n "${BONSAI_BIN:-}" ]; then dirname "$(dirname "$BONSAI_BIN")"; return 0; fi
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then printf '%s\n' "$CLAUDE_PLUGIN_ROOT"; return 0; fi
  if command -v codex >/dev/null 2>&1; then
    codex plugin list | awk '$1 == "bonsai@laicluse-agent-fieldkit" { print $NF; found=1; exit } END { exit found ? 0 : 1 }'
    return $?
  fi
  return 1
}
ROOT="$(resolve_bonsai_root)" || { echo "bonsai plugin root not found" >&2; exit 1; }
BONSAI="${BONSAI_BIN:-$ROOT/bin/bonsai}"
```

## Run it

```bash
node "$BONSAI" setup "<worktree path>" --repo "<canonical checkout root>" --json
```

`--repo` is required and must point at the canonical checkout, because the
`.bonsai` file and the files it lists live there, not in the new worktree.
Install is best-effort: a failed install is reported as a warning, not a hard
error, so the worktree is still usable. Pass `--no-install` to copy files and
report the detected install targets without running them.
