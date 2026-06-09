# Migratie naar l'Aicluse Agent Tools

Status: lokaal, niet publiek, geen remote.

## Besluit

De oude publieke marketplace `epologee/leclause-skills` wordt niet in een keer
gerenamed. Deze repo wordt de nieuwe publieke canonical plek onder de
marketplace-alias `laicluse-agent-tools`, maar pas wanneer externe
migratie-instructies uitvoerbaar zijn.

Tot die tijd:

- `leclause-skills` blijft de bestaande publieke bron voor gebruikers.
- `laicluse-agent-tools` is de lokale nieuwe publieke werkmap.
- `laicluse-agent-tools-private` is een lokale private werkbank en krijgt geen
  remote.
- `how-plugins-work` en git-discipline mogen tijdelijk op meerdere plekken
  bestaan. Dat is migratieduplicatie, geen DRY-probleem.

## Voor bestaande gebruikers

Nu geen actie. Niet deinstalleren, niet herinstalleren, niet handmatig renamen.
Marketplace aliases zijn installatie-identiteiten; `@leclause` wordt niet vanzelf
`@laicluse-agent-tools`.

Wanneer een plugin verhuist, blijft in de oude marketplace minstens een
migratie-stub achter die uitlegt welke oude install weg kan en welke nieuwe
install ervoor terugkomt. Pas daarna mag de echte oude plugin verdwijnen.

## Voor agents

Geen remote aanmaken, geen `git remote add`, geen `gh repo create`, geen push.
De eerste publicatie van deze repo is een expliciete operator-gate.

Werk plugin voor plugin. Houd Claude metadata als bron en genereer Codex
adapters met `bin/plugin-adapters`. Houd runtime-state onder
`${LAICLUSE_AGENT_HOME:-$HOME/.laicluse-agent}`.
