---
name: test-before-push
description: >-
  Verify plugin candidates, then activate integrated changes from the primary checkout in Claude Code and Codex.
---

# Test before push

One way, always. No choices, no options, no "option 1 or option 2". Run this procedure after every multi-agent marketplace plugin change before declaring it complete, whether or not a push is planned. A linked worktree may verify a candidate but may never become a persistent marketplace source.

## When to use

- You are in a marketplace repo with `.claude-plugin/marketplace.json` in the root.
- The repo has generated Codex adapters under `.agents/plugins/`.
- You want the current plugin version loadable in another Claude Code or Codex session.
- You are completing the change locally or preparing it for a later push.

Do not use for user-level skills in `~/.claude/skills/` or `~/.codex/skills`;
those load through the user-level skill path, not a marketplace install.

## Preconditions

Run from the repo root:

```bash
alias=$(jq -r '.name' .claude-plugin/marketplace.json)
printf 'alias=%s\n' "$alias"
git status --short
circus_bin="${CIRCUS_BIN:-$(command -v circus || true)}"
[ -x "$circus_bin" ] || {
  echo "circus@laicluse-agent-fieldkit is required for plugin builds" >&2
  exit 1
}
if git diff --cached --quiet; then
  "$circus_bin" plugins versions --check .
else
  PLUGIN_VERSIONS_GIT_CMD="${PLUGIN_VERSIONS_GIT_CMD:-git commit}" \
    "$circus_bin" plugins versions --staged .
fi
"$circus_bin" plugins build .
"$circus_bin" plugins check .
```

All checks must pass. A clean index validates the committed version with `--check`; a staged current-task slice validates and preserves the next commit-count version with the same `--staged` operation the repository hook uses. If `git status --short` prints unrelated work, stop and isolate it first. Stage the current task before this procedure when version calculation needs the final candidate slice.

## Persistent source gate

```bash
git_dir=$(git rev-parse --absolute-git-dir)
common_dir=$(git rev-parse --path-format=absolute --git-common-dir)
primary_checkout=$(dirname "$common_dir")
if [ "$git_dir" != "$common_dir" ]; then
  printf 'Candidate verified in linked worktree; integrate it before persistent runtime activation from %s.\n' "$primary_checkout"
fi
```

Never run either host's `marketplace add` with a linked-worktree path. Finish candidate verification there, integrate it through the repository flow, update the primary checkout to the integrated SHA, and run the install sections below from that primary checkout. This ordering keeps persistent global agent state stable across parallel sessions and worktree cleanup.

## Claude Code install

Run:

```bash
common_dir=$(git rev-parse --path-format=absolute --git-common-dir)
primary_checkout=$(dirname "$common_dir")
test "$(git rev-parse --absolute-git-dir)" = "$common_dir"
alias=$(jq -r '.name' "$primary_checkout/.claude-plugin/marketplace.json")
plugin=<plugin>
claude plugins marketplace add "$primary_checkout"
if claude plugins list | grep -Fq "$plugin@$alias"; then
  claude plugins update "$plugin@$alias"
else
  claude plugins install "$plugin@$alias"
fi
jq -r --arg key "$plugin@$alias" '.plugins[$key][0].version' ~/.claude/plugins/installed_plugins.json
```

The printed version must match `$primary_checkout/packages/<plugin>/.claude-plugin/plugin.json`.

## Codex install

Run:

```bash
common_dir=$(git rev-parse --path-format=absolute --git-common-dir)
primary_checkout=$(dirname "$common_dir")
test "$(git rev-parse --absolute-git-dir)" = "$common_dir"
alias=$(jq -r '.name' "$primary_checkout/.agents/plugins/marketplace.json")
plugin=<plugin>
codex plugin marketplace add "$primary_checkout"
codex plugin add "$plugin@$alias"
```

Codex reads `.agents/plugins/marketplace.json`, follows
`plugins[].source.path`, then reads the package `.codex-plugin/plugin.json`.
If the add cannot find the plugin, run `circus plugins check .` before
looking at any cache path. When the check passes and the plugin is absent from
the Codex marketplace, treat that as intentional single-agent coverage rather
than stale generated metadata.

## Fresh session check

Open a fresh session in any directory and invoke the plugin's slash command.
For Claude Code, the current session can pick up the new cache with
`/reload-plugins` after `claude plugins update`; reload alone never snapshots
working-tree edits. For Codex, start a fresh session after `codex plugin add`.

## Revert

For local-only marketplaces, there is no remote revert. Leave the primary-checkout marketplace configured until the operator explicitly changes the install source.

Only when the local clone is deliberately retired after its tested commit has been pushed, re-point the alias to the remote source without removing the marketplace:

```bash
owner_repo=$(git remote get-url origin | sed -E 's#.*github.com[:/](.+)/(.+)(\.git)?$#\1/\2#; s#\.git$##')
claude plugins marketplace add "$owner_repo"
claude plugins update "<plugin>@<alias>"
codex plugin marketplace add "$owner_repo"
codex plugin add "<plugin>@<alias>"
```

Do not run marketplace remove as a cleanup step. In Claude Code, marketplace
remove cascade-uninstalls plugins under that alias.

## Contract

This skill has no confirmation step. The only valid pause is a failed
precondition or an explicit operator gate such as remote creation, push, or
first public publication.
