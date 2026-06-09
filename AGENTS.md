# laicluse-agent-tools marketplace

Publieke l'Aicluse Agent Tools marketplace. Deze repo bevat de publieke,
deelbare plugins, skills, hooks en agent-adapters.

## Schrijfstijl

Taal: Nederlands voor user-facing projectdocumentatie waar die stijl al past.
Code, manifests en commit messages blijven Engels. Vaktermen, package-namen en
framework-namen blijven onvertaald binnen Nederlandse zinnen.

## Lokale storage

Alle eigen runtime-state van l'Aicluse Agent Tools projecten gebruikt
`${LAICLUSE_AGENT_HOME:-$HOME/.laicluse-agent}` als root. Maak subdirectories
op componentnaam, bijvoorbeeld `~/.laicluse-agent/circus/`, niet op
marketplace/repo-privacy (`toolbox`, `private`, `laicluse-agent-tools-private`)
en niet onder nieuwe `~/.laicluse-*` of `~/.leclause-*` roots.

Deze regel geldt voor code en docs in zowel `laicluse-agent-tools` als
`laicluse-agent-tools-private`. Agent-harness caches die Claude of Codex zelf
beheert (`~/.claude/plugins/cache`, `~/.codex/plugins/cache`, install indexes)
blijven waar de harness ze verwacht; schrijf daar geen first-party state tenzij
de harness API dat afdwingt. Bij legacy-state: lees/migreer uit oude paden,
schrijf daarna alleen naar `~/.laicluse-agent`.

## Migratiestatus

Deze repo is voorlopig local-only. Maak geen remote, push niet, en publiceer
niets totdat externe migratie-instructies actionable zijn.

Tijdens de overgang mogen `how-plugins-work` en git-discipline tijdelijk op
meerdere plekken bestaan: oud publiek (`leclause-skills`), nieuw publiek
(`laicluse-agent-tools`) en waar nodig de private werkbank
(`laicluse-agent-tools-private`). Dat is bewuste migratieduplicatie, geen
DRY-findingslijst. Verwijder geen oude kopie zonder werkende migratie-stub
voor bestaande gebruikers. De uiteindelijke publieke canonical plek wordt deze
repo; private tooling blijft alleen in `laicluse-agent-tools-private` als het
operator-specifiek is.
