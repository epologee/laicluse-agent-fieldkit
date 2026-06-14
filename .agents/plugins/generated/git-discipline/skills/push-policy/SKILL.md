---
name: push-policy
description: >
  Reference skill for the per-repo git push-policy: how to decide
  whether and when a push is appropriate for the repository you are
  in. Read this on any push decision, or when a teammate asks why a
  push was or was not made automatically. Resolves repo facts
  (collaboration, visibility, default-branch protection, push access)
  into one of five modes (local-only, solo-trunk, team-trunk, pr-flow,
  external) and tells you how each mode behaves.
---

# /git-discipline:push-policy

git-discipline's push hooks gate push CONTENT: no wip commits, a schema-valid body.
This skill governs push CONTEXT: whether and when a push fits the repository
you are working in. The two are orthogonal. A push can be content-valid and
still be the operator's call; a freely-pushable repo still owes a valid body.

The destination is a sound push decision for THIS repo, not a fixed ceremony.
Resolve the repo's mode, then act in the way that mode allows. Do not invent a
ceremony where the repo does not need one, and do not push where another person
is affected without the operator's go.

## The resolver

```bash
resolve_git_discipline_root() {
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT"
    return 0
  fi
  if command -v codex >/dev/null 2>&1; then
    codex plugin list --json \
      | jq -er '.installed[] | select(.pluginId == "git-discipline@laicluse-agent-tools") | .source.path'
    return $?
  fi
  return 1
}

GD_ROOT="$(resolve_git_discipline_root)" || { echo "git-discipline plugin root not found" >&2; exit 1; }
"$GD_ROOT/skills/push-policy/git-repo-policy" [repo-path]
```

Run it on a push decision (defaults to the current repo). It prints, one per
line: `remote`, `has_remote`, `collaboration`, `visibility`, `default_policy`,
`push_access`, `confidence`, `mode`, `hygiene`. The pure derivation functions
are covered by `test/push-policy/derive-mode.bats`.

## Three facts, plus access

- **collaboration**: `individual`, `closed`, or `open`. Derived from distinct
  author NAMES (not emails) in recent history, so one person committing under
  several git emails still reads as `individual`. Multiple authors on a private
  repo read as `closed`; on a public repo as `open`.
- **visibility**: `private` or `public` (via `gh`). Public raises `hygiene` to
  `high`.
- **defaultBranchPolicy**: `pushable` or `protected`. `protected` means
  MEANINGFUL protection on the default branch: required pull-request reviews,
  required status-check contexts, or push restrictions. An empty 200 protection
  object is NOT protected.
- **push_access**: `write` or `external` (via `gh` viewer permission, with an
  owner-heuristic fallback against the `codingAgent.git.owners` global).

## Five modes

- **local-only**: no remote. Never mention pushing at all.
- **solo-trunk**: your own repo, pushable default. Push freely, including the
  default branch. Auto-push completions. Do not ask.
- **team-trunk**: a shared repo you can write to, pushable default. Feature
  branches push freely. Pushing the shared default is suggested once with
  reasons, not done silently.
- **pr-flow**: a protected default. Never push the default directly. Branch,
  then PR, then merge is the gated step that needs the operator's go.
- **external**: no write access. Fork plus PR.

**Forced continuation**: after a rebase of a branch that already has an
upstream, a `--force-with-lease` push of your own branch is the completion of
that rebase, not a new decision. Do not ask for it, unless the branch is a
protected default.

## Safe defaults when gh is absent

- no remote becomes `local-only`
- no write becomes `external`
- unknown protection becomes `pushable` when you have write, else `protected`
- unknown visibility becomes `public` (strictest hygiene)

## Config and overrides

Per-repo overrides live in git-local config under the `codingAgent.git.*`
namespace and win over detection:

- `codingAgent.git.collaboration` (`individual` / `closed` / `open`)
- `codingAgent.git.visibility` (`private` / `public`)
- `codingAgent.git.defaultBranchPolicy` (`pushable` / `protected`)
- `codingAgent.git.pushAccess` (`write` / `external`)

A global `codingAgent.git.owners` list (set with `git config --global`) names
the repo owners you have write access to. It feeds the `push_access` fallback
when `gh` cannot answer.

Set one with, for example:

```
git config codingAgent.git.collaboration individual
```

## Self-discovery rule

Resolve the mode on any push decision. If the resolver reports
`confidence=low`, or the detected collaboration feels wrong for the work in
front of you, propose the single-line `codingAgent.git.*` override ONCE, then
proceed on your best reading. Never re-ask the same question on later pushes in
the same repo: the override is the durable answer, and a repeated nag costs
more than it protects.
