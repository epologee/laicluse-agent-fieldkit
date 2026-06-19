# Naming Doctrine

## Purpose

Names are part of the interface. They shape how future agents, colleagues, and
users understand the system. Treat every naming decision as vocabulary design:
one concept should have one name across code, docs, UI, commits, PRs, scripts,
automation, and human communication unless the domain deliberately uses
different words for different audiences.

This reference gathers the naming categories that tend to drift when agents
follow generic training-corpus defaults.

## Mental Models

- **Names are interfaces.** A name is not decoration around the implementation;
  it is the handle future readers use to reason about the system.
- **Vocabulary is architecture.** When two names describe one concept, the
  system now has an accidental split. When one name describes two concepts, the
  system now hides a distinction.
- **Search is a first-class reader.** A good name is the term a future agent or
  teammate will search for when they need the concept.
- **Local language beats global averages.** Generic corpus defaults are
  fallback material. The repo, domain, protocol, product, and team vocabulary
  are the authority.
- **Audience can justify aliases, not drift.** Code, UI, support copy, and PRs
  may use different words only when their audiences need them. Keep the
  mapping deliberate.

## Naming Principles

1. Prefer the local lexicon over generic best practice. Search the repo before
   coining a synonym.
2. Preserve domain language. Use the words the business, protocol, hardware,
   product, or user already uses.
3. Name the result, not the move. `Allow users to disconnect their car from the
   app` is better than `Add disconnect button`; `Plan charging sessions and
   generate energy profiles` is better than `Add ExampleSolverBuilder`.
4. Avoid generic wrapper nouns unless the framework or domain makes them
   specific: `Manager`, `Handler`, `Helper`, `Service`, `Util`, `Data`, `Info`,
   `Thing`, `Item`, `Processor`, and `Controller` are usually placeholders for
   a missing domain name.
5. Avoid cleverness. Names must survive being read in isolation, searched with
   `rg`, spoken in a review, and reused by another agent months later.
6. Keep the vocabulary stable across artifacts. A feature name, branch name,
   commit subject, PR title, UI label, and docs heading should feel like facets
   of the same concept, not separate naming attempts.
7. Do not leak process scaffolding. Generated-by-agent details, internal
   prompt vocabulary, tool names, temporary scripts, and local operator setup
   do not belong in shareable names or prose.
8. When a name and a comment compete, make the name carry more meaning. A
   comment that explains a vague name is a rename request.
9. Respect lint and language naming conventions by changing code shape before
   disabling rules. If a predicate cannot take the idiomatic predicate suffix
   in one shape, rewrite the method before proposing a lint exception.
10. If two names seem possible, ask what future search term should find this.
    Searchability beats private cleverness.

## Naming Patterns

- **Capability subject:** name a commit, PR title, feature, or changelog entry
  after the capability now present, not the files changed to create it.
- **Domain noun plus specific verb:** combine the domain object with the action
  it owns, such as `recipeSaver`, `tariffWindow`, or `sessionPlanner`.
- **Audience split with explicit mapping:** keep precise domain terms in code
  and user-natural labels in UI only when the relationship is clear.
- **Protocol term preservation:** keep protocol-defined names such as
  `setpoint`, `meter reading`, or `endpoint` unless the local codebase has an
  established translation.
- **Searchable branch phrase:** use a lower-case hyphenated phrase that a later
  searcher would also use in an issue, PR, or commit subject.
- **Negative example pair:** when replacing a bad name, record the before/after
  as a compact contrast so future agents learn the boundary.

## Categories To Check

- Code symbols: variables, constants, functions, methods, classes, interfaces,
  modules, namespaces, components, hooks, jobs, migrations, policies, commands,
  and exceptions.
- Domain-specific language: business concepts, protocol terms, product terms,
  hardware terms, finance/legal/regulatory terms, roles, states, transitions,
  and units.
- Data contracts: API endpoints, route names, event names, queue names,
  database tables, columns, JSON keys, GraphQL fields, cache keys, metrics,
  analytics events, feature flags, env vars, config keys, and error codes.
- Project and product identity: project names, repo names, package names,
  marketplace names, product names, feature names, initiative names, and
  internal codenames.
- Filesystem names: files, directories, package names, plugin names, skill
  names, scripts, assets, generated targets, fixtures, templates, and docs.
- Test language: spec filenames, describe/context labels, fixture names,
  snapshot names, fake builders, scenario names, and example prompts.
- Source-control language: branch names, worktree names, commit subjects,
  commit bodies, trailers, tags, release names, changelog bullets, PR titles,
  PR bodies, issue titles, and issue references.
- Product and UX language: feature names, UI labels, button text, empty states,
  onboarding steps, notifications, help text, navigation labels, and support
  macros.
- Human communication: chat messages, customer/partner emails, recaps,
  summaries, handoff notes, review comments, and status updates.
- Mixed-language use: Dutch/English code-switching, jargon translation,
  metaphor verbs, decimal and thousands notation, issue/PR URL style, and
  product names that should not be translated.
- Operational language: daemon names, launchd labels, cron names, queue names,
  workbench orders, automation reports, and local-only helper names.
- Brand and voice: brand nouns, product names, claims, proof points, tone,
  bilingual copy, and words that sound like marketing hype.
- Privacy boundaries: private personal names, client/employer details,
  credentials, local tool names, and generated-process vocabulary.

## Language Rules

Code and code-adjacent names are English even inside Dutch conversation:
feature names, command names, CLI names, class names, module names, method
names, config keys, file names, branch names, worktree names, commit subjects,
and PR titles when the project uses English PR titles.

Dutch communication can and should code-switch. Keep established technical
terms in English: framework names, library names, protocol names, gem/package
names, product names, and domain jargon. Do not translate `soft-delete`,
`bounds`, `switching penalty`, `smart charging`, or similar terms just because
the surrounding sentence is Dutch. Use the established term from the codebase
or domain docs.

Metaphor verbs need natural Dutch, not literal translation. `Spin up a server`
becomes `start` or `zet op`; `tackle a problem` becomes `pak aan`; `navigate
the codebase` becomes `loop door de codebase` or `kijk rond in de codebase`;
`ship` may stay `shippen` or become `uitleveren`, depending on the local style.

In Dutch output, do not use a dot as a thousands separator. Write whole numbers
without separators, and use a comma for decimals when the prose is Dutch. This
is wording, not code formatting.

## Code Naming

Use names that reveal responsibility at the call site. If the caller sees
`thing.process(data)`, the names have failed. If the caller sees
`tariffWindow.includes?(timestamp)` or `recipeSaver.save(page_payload)`, the
domain is visible without a comment.

Prefer specific domain roles over architectural roles. A generic suffix is
acceptable only when the surrounding framework makes it meaningful, such as a
Rails controller or a SwiftUI view. Even then, the prefix should carry the
domain.

Boolean names should read as predicates in the local language convention:
`active?`, `can_charge?`, `isEnabled`, `hasAccess`. Do not silence predicate
lint because a first draft chose a shape that fights the language.

Spec and test names should name behavior or endpoints, not implementation
containers. For request specs, name after the endpoint rather than the
controller when the endpoint is the thing under test.

## Domain Language

Build a glossary from local sources before naming new concepts. Good sources:
existing code, migrations, public APIs, product copy, protocol specs, issue
titles, customer-facing docs, and recent commits that touched the same area.

Do not smooth over domain terms into generic words. If a protocol says
`setpoint`, do not invent `targetPower` unless the project already uses that
translation. If a business concept is called `mandje`, `charge point`, or
`grid congestion`, keep that concept stable across layers.

When a domain has multiple audiences, choose the term for the artifact's
audience. UI labels can be user-natural while code keeps the precise domain
term, but document the relationship if both terms must coexist.

## Branches And Worktrees

Branch and worktree names describe the feature or domain slice. Do not include
agent names, vendor names, or tooling signatures. Prefer lower-case hyphenated
phrases unless a repo has a stricter local convention.

Good branch-name shapes:

- `naming-is-hard`
- `recipe-saving-endpoints`
- `worktree-default-reporter`
- `charging-session-planning`

Poor branch-name shapes:

- `codex/naming-plugin`
- `claude-fix`
- `agent-generated-cleanup`
- `update-stuff`

When a tool derives worktree directories from branch names, keep both readable.
If slashes flatten to dashes in the worktree directory, choose a branch name
that remains understandable after flattening.

## Commits

Commit subjects are English, imperative, and result-oriented. Aim for about 50
characters and never exceed 72 unless the project explicitly permits it.

The subject answers one of these questions:

- What can the system do now that it could not do before?
- What works differently now?
- What invariant is now protected?
- Which user-visible or maintainer-visible risk is reduced?

Avoid starting with these generic verbs unless the local project explicitly
requires them: `Add`, `Fix`, `Improve`, `Update`, `Change`, `Refactor`,
`Extract`, `Move`, `Remove`, `Rename`. These usually describe the git operation
or coding activity instead of the resulting behavior.

Avoid file inventories, class inventories, and meta triggers:

- Poor: `Update user.rb and add migration`
- Poor: `Add FooBuilder with bar and baz`
- Poor: `Address PR feedback`
- Better: `Prevent duplicate charging sessions for same vehicle`
- Better: `Use device from gum filter instead of stale variable`

Commit bodies explain WHY when the subject cannot carry enough context. Do not
add agent footers or `Co-Authored-By` trailers unless the project explicitly
requires them.

## Pull Requests And Issues

Treat a PR as a proposal to humans. Start with context and intent, not a
template header. The diff already shows files and tests; the PR body should
explain why this change is the right shape and what reviewers should know.

Do not use default agent PR templates, generated footers, or AI-scaffolding
language. For visual changes, include the actual visual evidence in the
project's expected form. For non-visual changes, do not embed a rendered code
diff in prose.

Use full issue and PR URLs in intentional communication. Bare `#123` is
ambiguous across repos.

Follow the repo's language split. Common patterns in local projects: commit
subjects and PR titles in English, PR descriptions and review comments in
Dutch, issue titles/bodies in Dutch for Dutch-working-language teams.

## Docs, Changelogs, And Release Notes

Docs should name the user-visible concept first. Implementation details belong
where they help the reader act, not as the heading or headline by default.

Changelog and broadcast bullets are for action-relevant change. Keep bullets
short, state the user-visible change first, and avoid back-story about the
previous implementation. If readers need engineering history, they can read the
commit log.

README names should be stable entry points: plugin names, commands, skills,
directories, and examples should match actual package and CLI names exactly.
A README reference to a nonexistent name is a blocker: build it, rename it, or
remove the reference.

## Human Communication

Keep messages short, scanable, and concrete. In chat-like channels, use a
generic greeting rather than a personal name. Do not leak private names,
internal agent setup, local tools, or credentials-adjacent details into
messages sent on the operator's behalf.

When referring to a team, `we` can be correct. When referring to product or
platform behavior, prefer the product/system name if that is more precise:
`the platform recognizes the card` is different from `we found what happened`.
Apply the same distinction to projects and brands.

Prefer plainspoken, technical, concrete copy over marketing language. Concrete
numbers beat adjectives. Avoid puns and idioms when copy must work in both
Dutch and English.

## Naming Review Checklist

- Does the name use the vocabulary already present in this repo or domain?
- Would `rg` find this later with the obvious search term?
- Does the name describe meaning, capability, or behavior rather than a file
  operation, refactor, framework move, or agent action?
- Is jargon preserved instead of awkwardly translated?
- Does mixed Dutch/English prose read naturally?
- Does the name avoid private names, toolchain details, and local setup?
- Does the same concept keep the same name across code, docs, branch, commit,
  PR, UI, and communication?
- Could a domain expert say this name out loud without it sounding like
  generated marketing or framework filler?
