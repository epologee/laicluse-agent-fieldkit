# l'Aicluse Agent Tools

Publieke, deelbare agent tooling voor Claude Code, Codex en toekomstige
coding-agents.

Deze repo is voorlopig local-only. Maak geen remote, push niet, en publiceer
niets totdat de migratie voor externe gebruikers actionable is.

## Eerste slice

De eerste plugin in deze nieuwe marketplace is `how-plugins-work`. Die legt vast
hoe plugin-namen, skill-namen, marketplace-aliassen, Claude manifests, Codex
manifests en runtime caches zich tot elkaar verhouden.

Tijdens de migratie blijft `epologee/leclause-skills` de bestaande publieke
marketplace. Bestaande gebruikers hoeven nu niets te deinstalleren of te
herinstalleren. Een rename van `@leclause` naar `@laicluse-agent-tools` gebeurt
niet automatisch; beide aliases kunnen naast elkaar bestaan zodra deze repo
later wel extern installeerbaar is. Oude plugins verdwijnen pas nadat er per
verwijderde plugin een werkende migratie-stub is.

## Lokale installatie

Alleen voor lokale ontwikkeling:

```bash
claude plugins marketplace add ./
claude plugins install how-plugins-work@laicluse-agent-tools

codex plugin marketplace add ./
codex plugin add how-plugins-work@laicluse-agent-tools
```

## Plumbing

Claude metadata is voorlopig de hand-edite bron. Codex metadata wordt
gegenereerd:

```bash
bin/plugin-adapters build .
bin/plugin-adapters check .
bin/plugin-adapters diff .
```

Pluginversies volgen `1.0.<commit-count>` per package:

```bash
bin/plugin-versions --check
bin/plugin-versions --write
```

Activeer de lokale git hooks in deze clone:

```bash
git config core.hooksPath hooks
```

De pre-commit hook bumpet versies, bouwt Codex adapters en staged de gegenereerde
targets. De commit-msg hook vraagt expliciet om `PII-Doublecheck: yes`, omdat
deze repo uiteindelijk publiek bedoeld is.

## Lokale storage

Alle first-party runtime-state voor l'Aicluse Agent Tools gebruikt:

```bash
${LAICLUSE_AGENT_HOME:-$HOME/.laicluse-agent}
```

Agent-harness caches blijven waar de harness ze verwacht, bijvoorbeeld
`~/.claude/plugins/cache` en `~/.codex/plugins/cache`.
