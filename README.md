# l'Aicluse Agent Tools

Agent tooling for Claude Code and Codex.

The marketplace currently ships:

- `how-plugins-work`: reference material for plugin names, skill names,
  marketplace aliases, manifests, adapters, and runtime caches.
- `self-improvement`: routes feedback about agent behavior to hooks, skills,
  project code, or instruction files.
- `git-discipline`: git workflow skills plus commit and push hooks for agent
  sessions and direct CLI commits.
- `intervision`: bring another coding agent in as a peer to review work just
  done or just discussed. Claude hands work to Codex; Codex hands work to
  Claude.
- `anger-management`: curse at your coding agent now, fix the real problem
  later. Capture commands log friction to a global pile; a delayed background
  investigation diagnoses the pattern and `repair` routes the fix.
- `autonomous`: keep an autonomous mission running across turns. A startup
  capability probe decides whether keep-alive machinery (cron heartbeat,
  backoff, wake) is needed; persistent processes run without it.
- `rover`: dispatch a rover at a task and stay back while it decides in the
  field: a phase machine with decide, pride/trim quality gates, verify
  evidence discipline, and a stop communique.
- `clipboard`: copy the core content of the last answer to the macOS
  clipboard. Plain text by default, `/clipboard slack` for rich text.

## Installation

Claude Code:

```bash
claude plugins marketplace add epologee/laicluse-agent-tools
claude plugins install how-plugins-work@laicluse-agent-tools
claude plugins install self-improvement@laicluse-agent-tools
claude plugins install git-discipline@laicluse-agent-tools
claude plugins install intervision@laicluse-agent-tools
claude plugins install anger-management@laicluse-agent-tools
claude plugins install autonomous@laicluse-agent-tools
claude plugins install rover@laicluse-agent-tools
claude plugins install clipboard@laicluse-agent-tools
```

Codex:

```bash
codex plugin marketplace add epologee/laicluse-agent-tools
codex plugin add how-plugins-work@laicluse-agent-tools
codex plugin add self-improvement@laicluse-agent-tools
codex plugin add git-discipline@laicluse-agent-tools
codex plugin add intervision@laicluse-agent-tools
codex plugin add anger-management@laicluse-agent-tools
codex plugin add autonomous@laicluse-agent-tools
codex plugin add rover@laicluse-agent-tools
codex plugin add clipboard@laicluse-agent-tools
```

If you still use older `@leclause` plugins, keep that marketplace installed
until the replacement you need is listed here. See [docs/migration.md](docs/migration.md).

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

All first-party runtime state for l'Aicluse Agent Tools uses:

```bash
${LAICLUSE_HOME:-$HOME/.laicluse}
```

Agent-harness caches stay where the harness expects them, for example
`~/.claude/plugins/cache` and `~/.codex/plugins/cache`.
