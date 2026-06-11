# git-discipline

Git workflow skills plus commit and push hooks for agent sessions and direct
CLI commits.

## What

`git-discipline` has two parts:

1. **Git workflow skills.** Commands for grouped commits, precise commits from
   a dirty tree, rebasing on the latest default branch, merging to default,
   resolving push policy, and installing hooks.
2. **Commit-discipline enforcement.** Two-layer hook architecture
   (PreToolUse guards plus git-native hooks) that validates a structured
   body schema: subject + WHY paragraph + Slice / Tests / Red-then-green
   trailers parsed via `git interpret-trailers`, with eight opt-out enum
   tokens. `Red-then-green` accepts three forms: `n/a (reason >= 10 chars)`,
   `<path>` (a spec file in the staged diff), or `<path>:<line> # <test-name>`
   (line is 1-based, name must match a test declaration in the staged
   blob; the `# ` separator follows the RSpec / Cucumber convention and
   keeps `path:line` clickable in iTerm2 / VSCode / Ghostty). Bare `yes`
   is no longer accepted.

Reference for the schema, examples, escape-hatches, and troubleshooting:
`/git-discipline:commit-discipline`.

## Skills

| Skill | Command | Auto |
|-------|---------|:----:|
| commit-all-the-things | `/git-discipline:commit-all-the-things` | yes |
| commit-snipe | `/git-discipline:commit-snipe` | yes (on the word "snipe") |
| rebase-latest-default | `/git-discipline:rebase-latest-default` | yes |
| merge-to-default | `/git-discipline:merge-to-default` | yes |
| push-policy | `/git-discipline:push-policy` | |
| commit-discipline | `/git-discipline:commit-discipline` | |
| install-hooks | `/git-discipline:install-hooks` | |
| run-spec | `/git-discipline:run-spec` | |
| disable-session | `/git-discipline:disable-discipline` | |
| enable-session | `/git-discipline:enable-discipline` | |
| session-status | `/git-discipline:discipline-status` | |
| disable-git | `/git-discipline:disable-git [reason]` | |
| enable-git | `/git-discipline:enable-git` | |

- **commit-all-the-things** inspects `git status` plus `git diff`, groups
  changes by intent (feature, fix, refactor, docs, config), and creates
  one commit per group. Trigger phrases include "commit everything",
  "clean up the working tree", and "commit what's left".
- **commit-snipe** stages only the files (or hunks) that belong to the
  current conversation's work and leaves the rest untouched. Auto-fires
  on the word "snipe".
- **rebase-latest-default** rebases the current branch on the freshest
  default branch (local or `origin/<default>`), resolves trivial conflicts
  where safe, and stops on non-trivial conflicts.
- **merge-to-default** lands the current branch on the project's default
  with a github-style `--no-ff` merge commit, rebases on conflict, deletes
  the local source branch after the merge is confirmed, and no-ops with a
  TUI warning when invoked on the default branch itself. Push remains an
  explicit user action.
- **push-policy** decides whether and when a push fits the current repo. It
  ships a resolver (`skills/push-policy/git-repo-policy`) that reads per-repo
  facts (collaboration, visibility, default-branch protection, push access)
  and derives one of five modes (`local-only`, `solo-trunk`, `team-trunk`,
  `pr-flow`, `external`), each with its own push behavior. Per-repo overrides
  live under git-local `codingAgent.git.*`. `rebase-latest-default` and
  `merge-to-default` consult it; the push hooks gate content and are
  orthogonal to this context decision.
- **commit-discipline** is the canonical reference for the body schema,
  error-codes, opt-out enum, and escape-hatches.
- **install-hooks** copies the git-native `commit-msg`, `prepare-commit-msg`,
  `post-commit`, and `pre-push` hooks into the current repo so commits
  made outside Claude Code still get validated. `--force` overwrites
  existing hooks (a backup is taken automatically); `--dry-run` previews.
- **run-spec** runs a single test/spec file through the project's
  auto-detected runner (RSpec, Jest, Vitest, Go test, pytest) and prints
  a PASS/FAIL summary. No cache side-effects.
- **disable-session** writes a sentinel file at `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-disabled-<session_id>`
  that tells the dispatcher to skip all guards for the current session. Other
  sessions are not affected. Only fire on explicit user invocation.
- **enable-session** removes the session sentinel (and the global fallback
  sentinel if present), restoring guards for the current session.
- **session-status** reports the current session_id, which sentinels exist,
  whether guards are active or disabled, the active plugin version, and the
  list of guard scripts in the install.
- **disable-git** writes `.git/git-discipline-deny` (per-repo, never committed) and
  locks git for Claude. While the sentinel exists, only read-only inspection
  is allowed (status, log, diff, show, blame, rev-parse, branch / tag in
  list form, remote -v, config --get, `bisect view`, `worktree list`,
  `submodule status`, `stash list/show`, `notes list/show`); every mutation
  (commit, checkout, switch, restore, reset, merge, rebase, cherry-pick,
  revert, push, pull, fetch, add, rm, mv, stash, clean, branch -d, tag
  v0.1, ...) is denied. Optional argument becomes the reason printed in the
  deny message. With `/git-discipline:install-hooks` active, the `commit-msg` and
  `pre-push` git-native hooks honour the same sentinel, so direct shell
  `git commit` and `git push` are also blocked. Other shell mutations
  (`git reset`, `git checkout`, ...) are not covered CLI-time because
  git-discipline installs no hooks for them; Claude is fully locked at PreToolUse
  time regardless.
- **enable-git** removes `.git/git-discipline-deny`, lifting the lock.

## Hooks

PreToolUse:Bash dispatcher chain (`hooks/dispatch.sh`):

| Guard | Triggers on | Blocks |
|-------|-------------|--------|
| `git-dash-c.sh` | any `git -C <dir>` command | `git -C` |
| `repo-deny.sh` | any `git <mutation>` while `.git/git-discipline-deny` exists | every git command outside the read-only allow-list |
| `commit-format.sh` | `git commit` | editor-mode commits without `-m` |
| `commit-subject.sh` | `git commit -m` | subjects past 50/72, lowercase first, trailing period |
| `commit-body.sh` | `git commit -m` | bodies that fail `validate-body.sh` |
| `commit-trailers.sh` | `git commit -m` | `Co-Authored-By:` with `@anthropic.com` email |
| `push-wip-gate.sh` | `git push` | push range containing a `Slice: wip` commit |

Git-native hooks (installed per-repo via `/git-discipline:install-hooks`,
sourced from `skills/commit-discipline/git-hooks/`):

| Hook | Purpose |
|------|---------|
| `commit-msg` | runs `validate-body.sh` on every non-Claude commit |
| `prepare-commit-msg` | pre-fills the editor with a layer-classified template |
| `post-commit` | logs `--no-verify` usage to `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-no-verify.log` |
| `pre-push` | re-runs the wip-gate on the push range |

Both layers source the same `hooks/lib/validate-body.sh`, so behavior never
diverges between Claude-driven and CLI-driven commits.

## Install

```bash
claude plugins install git-discipline@laicluse-agent-tools
codex plugin add git-discipline@laicluse-agent-tools
```

In Claude Code, the PreToolUse:Bash hooks register automatically. In Codex,
the skills are available but Claude-specific plugin hooks do not run. To catch
commits made outside Claude Code, or from Codex, install the git-native hooks
into each repo:

```bash
/git-discipline:install-hooks
```

Use `--dry-run` to preview, `--force` to overwrite existing hooks. Re-run
after each `claude plugins update git-discipline@laicluse-agent-tools` so the installed hooks
point at the current plugin version.

## Example commit message

```
Drop invalid meter reading on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation, we previously rejected
the entire event, which masked session starts and stops in analytics.
This change keeps the transaction event but discards just the bad
reading, restoring the visibility we lost.

Tests: spec/services/session_spec.rb#start_event_with_bad_reading,
       spec/services/session_spec.rb#stop_event_with_bad_reading
Slice: handler + service + spec
Red-then-green: spec/services/session_spec.rb:42 # start_event drops invalid meter reading
Verified: red-then-green
Resolves: https://example.org/backlog/issues/1234
```

The `Slice` value can also be one of eight opt-out tokens: `docs-only`,
`config-only`, `migration-only`, `spec-only`, `chore-deps`, `revert`,
`merge`, `wip`.
Opt-out commits drop the `Tests:` requirement; the documentation /
config / chore-deps tokens additionally drop the `Red-then-green:`
requirement.

## Bypass

Escape-hatches, each logged for later auditing:

- `git commit --no-verify` (git-native layer only, logged to
  `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-no-verify.log` via the `post-commit` hook; see the
  `--no-verify` section of `/git-discipline:commit-discipline` for the layer
  split and the operator-only PreToolUse off-switch)
- `GIT_DISCIPLINE_ALLOW_AI_COAUTHOR=1` to allow a single `@anthropic.com`
  `Co-Authored-By:` trailer
- `GIT_DISCIPLINE_ALLOW_CONJUNCTION=1` or the magic-comment `# allow-conjunction:
  <reason>` in the body to permit a subject that contains ` and `, ` + `,
  or ` & ` when the joined form is genuinely atomic
- `GIT_DISCIPLINE_ALLOW_WIP_PUSH=1` or the magic-comment `# allow-wip-push` to
  push a range that contains `Slice: wip` commits (logged to
  `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-wip-pushes.log`). Note: `# allow-wip-push` only
  works when Claude issues the push (the PreToolUse:Bash guard reads the
  bash command string). For terminal-issued `git push`, only
  `GIT_DISCIPLINE_ALLOW_WIP_PUSH=1` works.
- `GIT_DISCIPLINE_TRIVIAL_OK=1` to skip body-validation for a single trivial commit
  (set automatically by the PreToolUse guard for diffs of <= 1 file and
  <= 5 insertions)

See `/git-discipline:commit-discipline` for the full schema, opt-out matrix, and
troubleshooting guide.

## Test suite

```bash
bash packages/git-discipline/test/run-bats              # 200+ BATS cases
bash packages/git-discipline/test/smoke/smoke-test.sh   # 22-case end-to-end smoke
```

The BATS suite is split per concern:

- `validate-body/` covers the body schema rules.
- `block-mode/`, `shadow-mode/`, `wip-gate/`, `template-fill/` cover the
  guard glue per slice.
- `install-hooks/` covers the per-repo install scenarios (empty repo,
  existing hooks, `core.hooksPath`, worktree).
- `migrated-hooks/`, `migration/` cover compatibility with previous hook
  behavior.

The smoke suite spins up disposable git repos and exercises the full hook
chain end-to-end.

## Audit

Verify that no body-less commits slipped through.
The script ships inside the plugin at `bin/audit-no-body-commits`; resolve
its path from the active install so it survives plugin updates:

```bash
GIT_DISCIPLINE=$(jq -r '.plugins["git-discipline@laicluse-agent-tools"][0].installPath' \
  ~/.claude/plugins/installed_plugins.json)
python3 "$GIT_DISCIPLINE/bin/audit-no-body-commits"
python3 "$GIT_DISCIPLINE/bin/audit-no-body-commits" --branch main --since 2026-04-01
python3 "$GIT_DISCIPLINE/bin/audit-no-body-commits" --exclude-trivial
```

Lists every commit on the branch with a single-line message (or below the
trivial threshold), useful for checking that the push gate held.
