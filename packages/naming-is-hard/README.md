# naming-is-hard

Canonical l'Aicluse naming and wording doctrine. A read-only reference skill for
any "what should this be called?" task: code symbols, files, directories,
modules, packages, plugins, skills, CLI commands, config keys, APIs, events,
database fields, domain language, feature names, project names, branch names,
worktree names, commit messages, pull requests, issues, release notes, docs, UI
copy, human communication, and Dutch/English mixed-language wording.

## Skill

### `/naming-is-hard`

Loads the naming doctrine. The skill body carries a quick workflow and the core
rules; `skills/naming-is-hard/references/naming-doctrine.md` holds the full
doctrine (mental models, principles, patterns, per-category checks, language
rules, and a review checklist) for nontrivial naming choices, renames, and
cross-language wording decisions.

The skill is also model-invocable: it activates whenever a task is about
choosing or revising a name or term, so naming decisions reach for the local
lexicon before falling back to generic corpus defaults.

## Requirements

Node.js on `$PATH` for the post-update broadcast check (`bin/check-broadcast`).
The doctrine itself is plain Markdown and needs nothing beyond a reader.

## Installation

```bash
claude plugins install naming-is-hard@laicluse-agent-fieldkit
codex plugin add naming-is-hard@laicluse-agent-fieldkit
```
