---
name: test-before-push
description: >-
  Test multi-agent plugin marketplace changes locally in Claude Code and Codex before pushing.
---

# Test before push

One way, always. No choices, no options, no "option 1 or option 2". When you
want to test a marketplace plugin in a fresh agent session before pushing, run
the procedure below exactly.

## When to use

- You are in a marketplace repo with `.claude-plugin/marketplace.json` in the root.
- The repo has generated Codex adapters under `.agents/plugins/`.
- You want the current committed plugin version loadable in another Claude Code
  or Codex session.
- Pushing is not on the table yet.

Do not use for user-level skills in `~/.claude/skills/` or `~/.codex/skills`;
those load through the user-level skill path, not a marketplace install.

## Preconditions

Run from the repo root:

```bash
alias=$(jq -r '.name' .claude-plugin/marketplace.json)
printf 'alias=%s\n' "$alias"
git status --short
[ ! -x bin/plugin-versions ] || bin/plugin-versions --check
[ ! -x bin/plugin-adapters ] || bin/plugin-adapters check .
```

All checks must pass. If `git status --short` prints unrelated work, stop and
commit or isolate it first; the install snapshots the working tree.

## Claude Code install

Run:

```bash
alias=$(jq -r '.name' .claude-plugin/marketplace.json)
plugin=<plugin>
claude plugins marketplace add ./
if claude plugins list | grep -Fq "$plugin@$alias"; then
  claude plugins update "$plugin@$alias"
else
  claude plugins install "$plugin@$alias"
fi
jq -r --arg key "$plugin@$alias" '.plugins[$key][0].version' ~/.claude/plugins/installed_plugins.json
```

The printed version must match `packages/<plugin>/.claude-plugin/plugin.json`.

## Codex install

Run:

```bash
alias=$(jq -r '.name' .agents/plugins/marketplace.json)
plugin=<plugin>
codex plugin marketplace add ./
codex plugin add "$plugin@$alias"
```

Codex reads `.agents/plugins/marketplace.json`, follows
`plugins[].source.path`, then reads the package `.codex-plugin/plugin.json`.
If the add cannot find the plugin, run `bin/plugin-adapters check .` before
looking at any cache path. When the check passes and the plugin is absent from
the Codex marketplace, treat that as intentional single-agent coverage rather
than stale generated metadata.

## Fresh session check

Open a fresh session in any directory and invoke the plugin's slash command.
For Claude Code, the current session can pick up the new cache with
`/reload-plugins` after `claude plugins update`; reload alone never snapshots
working-tree edits. For Codex, start a fresh session after `codex plugin add`.

## Revert

For local-only marketplaces, there is no remote revert. Leave the local
marketplace configured until the operator explicitly changes the install source.

When a repo later has a real remote and the tested commit has been pushed,
re-point the alias to the remote source without removing the marketplace:

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
