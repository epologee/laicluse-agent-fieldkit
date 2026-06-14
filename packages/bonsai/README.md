# bonsai

Worktree lifecycle as a small, cross-platform CLI. Bonsai owns one thing well:
creating, priming, and tearing down git worktrees, git-natively, with a safety
gate so work is never thrown away by accident.

It is deliberately distinct from raw `git worktree`: bonsai resolves the
freshest default branch, follows the `<root>/worktrees/<dir>` convention with a
self-ignoring `.gitignore`, primes a tree from a `.bonsai` file list, and
guards teardown. It emits facts (`--json`), never a start command or clipboard
payload; whatever launches an agent in the worktree composes its own briefing.

## CLI

```
bonsai create <branch> --repo <root> [--base <ref>] [--json]
bonsai setup  <worktree> --repo <root> [--no-install] [--json]
bonsai teardown <worktree|branch> --repo <root> [--force] [--dry-run] [--json]
```

- **create** — resolve the freshest default, make the worktree + branch (slashes
  in the branch flatten to dashes in the dir), refuse an existing branch, and
  print `{ worktree, branch, base, baseSha, port }`. The port is a deterministic
  dev-server hint in 3100-3999.
- **setup** — copy the `.bonsai`-listed files from the canonical checkout
  (`--repo`) and install dependencies per directory by the manager each lockfile
  names. Install is best-effort; failures warn rather than block.
- **teardown** — remove a worktree only when it is integrated, or clean with
  nothing ahead of the default. Otherwise it is kept with a reason. Warns on
  orphaned unpushed commits and on a diverged default. `--dry-run` classifies
  without removing; `--force` overrides the gate.

## Skills

- `bonsai` — make a ready worktree (create + setup).
- `setup` — prime an existing worktree.
- `prune` — tear down behind the safety gate.

## Files

- `bin/bonsai` — CLI dispatcher.
- `bin/bonsai-lib.mjs` — pure functions (base resolution, port, copy, install
  detection, teardown classification).
- `test/*.bats` — CLI contract tests.
