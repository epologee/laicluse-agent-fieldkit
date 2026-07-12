# Default branch resolution duplication checklist

Version: `v2026-07-12T22-11`

- `remote-only-hard-stop`: Find operational skills that read `origin/HEAD` and stop even when `init.defaultBranch` identifies an existing local branch. Signatures: `refs/remotes/origin/HEAD`, `cannot determine default branch`.
- `hard-coded-name-fallback`: Find resolvers that fall back to literal `main` or `master`. Signatures: `refs/heads/main`, `refs/heads/master`, `['main', 'master']`.
- `current-head-as-default`: Find state-changing or integration logic that treats the currently checked-out feature branch as the default. Signatures: `allowHeadFallback`, `symbolic-ref --quiet --short HEAD`.
- `remote-ref-assumption`: Find code that resolves a local default name but still constructs `origin/<name>` unconditionally. Signatures: `origin/${DEFAULT}`, `origin/$DEFAULT`.
- `configured-ref-not-verified`: Find `init.defaultBranch` fallbacks that do not verify `refs/heads/<configured>` before accepting the name. Signatures: `init.defaultBranch`, `rev-parse --verify`.
- `context-fallback-confusion`: Separate presentation-only current-branch fallbacks from merge, review, deletion, or integration decisions. Signatures: `default_branch`, `context`, `label`.
- `conservative-unknown-regression`: Preserve consumers whose safe behavior deliberately treats missing remote metadata as unknown. Signatures: `default_policy="unknown"`, `wip_gate_resolve_default_ref`.
- `generated-mirror-drift`: Confirm every changed canonical skill or package source is reflected in generated Codex adapters. Signatures: `.agents/plugins/generated`, `plugin-adapters check`, `circus plugins check`.
