---
name: restart-claude-agents
user-invocable: true
description: >-
  Explicit /restart-claude-agents: restart Claude Code background agents so they load updated plugins.
allowed-tools:
  - Bash(*restart-claude-agents*)
effort: low
disable-model-invocation: true
---

# Restart Claude agents

Restart running Claude Code background agents so a fresh process loads the
plugin versions on disk. A running agent holds its plugins in memory from the
moment it started; there is no in-process reload (see the `/reload-plugins`
section of the how-plugins-work reference), so picking up an updated plugin
means starting a new process. `claude --bg --resume` does exactly that: it
stops nothing on its own, but a fresh process replays the agent's conversation
and loads the current plugins, so the agent keeps its context and continues
where it left off.

The helper at `${CLAUDE_PLUGIN_ROOT}/bin/restart-claude-agents` does the work.
It only ever touches `kind: background` agents; interactive sessions (your live
terminals) are never restarted.

## Workflow

1. **List first.** Run the helper's `list` command and show the running
   background agents to the user, so it is clear what is about to be
   restarted:

   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/bin/restart-claude-agents" list
   ```

2. **Restart.** Without arguments, restart restarts every *idle* background
   agent and reports any busy ones it skipped:

   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/bin/restart-claude-agents" restart
   ```

   - Pass one or more agent ids to restart exactly those, busy or not:
     `restart <id> <id>`
   - `--force` includes busy (non-idle) agents in a bulk restart
   - `--cwd <path>` limits to agents whose working directory is under `<path>`
   - `--dry-run` reports what would be restarted without touching anything

3. **Report** the old to new job id mapping the helper prints. Each restarted
   agent gets a new job id and session id (resume forks the session), so the
   ids in `claude agents` change.

## What is preserved

The restart re-applies each agent's **original launch flags**, read from its
own job state at `~/.claude/jobs/<id>/state.json` (which Claude Code writes for
every background agent): permission mode (so a `bypassPermissions` / YOLO agent
comes back YOLO), the disallowed-tools deny list, custom settings, and the
agent's goal (the stored intent is re-passed, re-arming the goal-redrive loop).
Combined with `--resume`, the agent keeps its conversation, its permissions,
its safety net, and its mission across the restart.

The only fallback: if an agent has no readable job state, it gets a plain
context-preserving resume under **default permissions** and the helper flags it
in the output. That is the exception, not the normal path.

## Requirements

Claude Code, with Node.js on `$PATH` (the helper is a Node script). The helper
drives the `claude` CLI it finds on `$PATH`; override with `CLAUDE_BINARY` if
`claude` is not the right name.
