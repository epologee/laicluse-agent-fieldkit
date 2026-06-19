# l'Aicluse Agent Fieldkit

Agent tooling for Claude Code and Codex.

The GitHub Pages source for a public overview of the repository and changelog
lives in [docs/index.html](docs/index.html). Publish GitHub Pages from the
`main` branch's `/docs` folder to serve it as a project page.

The marketplace currently ships:

- `how-plugins-work`: reference material for plugin names, skill names,
  marketplace aliases, manifests, adapters, and runtime caches.
- `self-improvement`: routes feedback about agent behavior to hooks, skills,
  project code, or instruction files.
- `git-discipline`: git workflow skills plus commit and push hooks for agent
  sessions and direct CLI commits.
- `bonsai`: git worktree lifecycle as a cross-platform CLI with setup and
  guarded teardown.
- `dibs`: single-occupancy locks so one coding agent owns a working directory
  at a time.
- `dont-do-that`: guardrail hooks for Claude Code plus `/duh` and
  `/just-a-question` correction skills for Claude Code and Codex.
- `intervision`: bring another coding agent in as a peer to review work just
  done or just discussed. Claude hands work to Codex; Codex hands work to
  Claude.
- `anger-management`: curse at your coding agent now, fix the real problem
  later. Capture commands log friction to a global pile; a delayed background
  investigation diagnoses the pattern and `repair` routes the fix.
- `drydry`: duplication-audit methodology for code, prose, design systems, and
  technical docs. Quick mode answers scoped "is this duplicate?" questions;
  audit mode produces a findings artefact with verifier commands.
- `laicluse-agent-fieldkit`: marketplace-wide utilities.
  `/whats-new [plugin]`
  re-reads the latest CHANGELOG section of any installed plugin, or the
  marketplace-wide news without arguments. Use
  `/laicluse-agent-fieldkit:whats-new` only when a namespaced form is needed.
- `autonomous` (Claude Code): keep an autonomous mission running across turns. A startup
  capability probe decides whether keep-alive machinery (cron heartbeat,
  backoff, wake) is needed; persistent processes run without it.
- `clipboard`: copy the core content of the last answer to the macOS
  clipboard. Plain text by default, `/clipboard slack` for rich text.
- `gurus`: opinionated review panels for code, decisions, and prose. The
  orchestrator routes to the software, council, or writers panel.
- `rover`: dispatch a rover at a task and stay back while it decides in the
  field: a phase machine with decide, pride/trim quality gates, verify
  evidence discipline, and a stop communique.
- `house-rules`: programming, testing, and naming doctrine, including
  `naming-is-hard`.
- `whywhy`: drills a configurable why-chain into a question or goal, then
  reads the chain for assumptions, forks, and better framing.

## Installation

Claude Code:

```bash
claude plugins marketplace add epologee/laicluse-agent-fieldkit
claude plugins install how-plugins-work@laicluse-agent-fieldkit
claude plugins install bonsai@laicluse-agent-fieldkit
claude plugins install dibs@laicluse-agent-fieldkit
claude plugins install self-improvement@laicluse-agent-fieldkit
claude plugins install git-discipline@laicluse-agent-fieldkit
claude plugins install dont-do-that@laicluse-agent-fieldkit
claude plugins install intervision@laicluse-agent-fieldkit
claude plugins install anger-management@laicluse-agent-fieldkit
claude plugins install drydry@laicluse-agent-fieldkit
claude plugins install laicluse-agent-fieldkit@laicluse-agent-fieldkit
claude plugins install autonomous@laicluse-agent-fieldkit
claude plugins install clipboard@laicluse-agent-fieldkit
claude plugins install gurus@laicluse-agent-fieldkit
claude plugins install rover@laicluse-agent-fieldkit
claude plugins install house-rules@laicluse-agent-fieldkit
claude plugins install whywhy@laicluse-agent-fieldkit
```

Codex:

```bash
codex plugin marketplace add epologee/laicluse-agent-fieldkit
codex plugin add how-plugins-work@laicluse-agent-fieldkit
codex plugin add bonsai@laicluse-agent-fieldkit
codex plugin add dibs@laicluse-agent-fieldkit
codex plugin add self-improvement@laicluse-agent-fieldkit
codex plugin add git-discipline@laicluse-agent-fieldkit
codex plugin add dont-do-that@laicluse-agent-fieldkit
codex plugin add intervision@laicluse-agent-fieldkit
codex plugin add anger-management@laicluse-agent-fieldkit
codex plugin add drydry@laicluse-agent-fieldkit
codex plugin add laicluse-agent-fieldkit@laicluse-agent-fieldkit
codex plugin add clipboard@laicluse-agent-fieldkit
codex plugin add gurus@laicluse-agent-fieldkit
codex plugin add rover@laicluse-agent-fieldkit
codex plugin add house-rules@laicluse-agent-fieldkit
codex plugin add whywhy@laicluse-agent-fieldkit
```

Codex receives the generated subset that has Codex-compatible runtime
behavior. Claude-only plugins and skills are intentionally omitted from the
Codex marketplace instead of being served as inert commands.

Existing installs under the previous marketplace identity do not rename
themselves. See [docs/migration.md](docs/migration.md) for the hard-cutover
commands.

## Development

For local development, point the marketplace at this working copy:

```bash
claude plugins marketplace add ./
codex plugin marketplace add ./
```

Claude metadata is the source. Codex metadata is generated:

```bash
bin/plugin-adapters build .
bin/plugin-adapters check .
bin/plugin-adapters diff .
```

The GitHub Pages catalog data is generated from the same source manifests and
package changelogs:

```bash
bin/build-pages .
```

Plugin versions follow `2.0.<commit-count>` per package:

```bash
bin/plugin-versions --check
bin/plugin-versions --write
```

Enable the local git hooks in this clone:

```bash
git config core.hooksPath hooks
```

The pre-commit hook bumps versions, builds Codex adapters, and stages the
generated targets. The commit-msg hook requires `PII-Doublecheck: yes`.

## Local Storage

All first-party runtime state for l'Aicluse Agent Fieldkit uses:

```bash
${LAICLUSE_HOME:-$HOME/.laicluse}
```

Agent-harness caches stay where the harness expects them, for example
`~/.claude/plugins/cache` and `~/.codex/plugins/cache`.
