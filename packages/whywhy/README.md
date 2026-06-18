# whywhy

Drill N layers deep into a question or goal (default 10). Claude autonomously asks and answers "why?" itself, building a chain of reasoning, then analyzes the chain for a better direction toward the goal.

The classic five-whys exercise, but autonomous and slightly deeper. Useful when the surface-level answer feels too convenient.

## Commands

### `/whywhy [n] <question, goal, or statement>`

Generates an `n`-deep "why?" chain (default 10), then analyzes the chain for:

- assumptions that broke down
- layers where the reasoning forked
- a better-framed goal at one of the deeper layers

Argument can be a question, a stated goal, or a claim to interrogate.

## Auto-trigger

Activates when the user types `/whywhy` with content, and is model-invocable: it
activates whenever a task is about drilling into the root cause of a decision,
goal, or problem. Does not auto-fire on free conversation.

## Requirements

Node.js on `$PATH` for the post-update broadcast check (`bin/check-broadcast`).
The skill itself is plain Markdown and needs nothing beyond a reader.

## Installation

```bash
claude plugins install whywhy@laicluse-agent-fieldkit
codex plugin add whywhy@laicluse-agent-fieldkit
```
