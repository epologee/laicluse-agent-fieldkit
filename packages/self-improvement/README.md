# self-improvement

Routes feedback about agent behavior to the strongest durable target: hooks,
skills, project code, or instruction files.

## Command

### `/self-improvement`

Reads recent feedback from the conversation, classifies the issue by
enforcement strength and scope, then applies the change in the right source.
It may add, edit, shorten, merge, or remove instructions.

## Auto-trigger

Activates when the user:

- gives feedback on agent behavior ("don't do that", "do this instead")
- says "remember this" or "onthou dit"
- asks to create or improve skills, hooks, plugins, or instruction files
- asks to consolidate or trim instructions

## Install

```bash
claude plugins install self-improvement@laicluse-agent-tools
codex plugin add self-improvement@laicluse-agent-tools
```
