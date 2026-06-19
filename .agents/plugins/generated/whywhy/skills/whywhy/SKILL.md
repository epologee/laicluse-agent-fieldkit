---
name: whywhy
description: Drill N layers deep into a question or goal (default 10). Claude asks and answers "why?" itself, then analyses the chain for a better direction. Use when tackling unclear decisions, vague goals, root-cause analysis, or self-improvement on something that is not working as desired.
args: "[count] <question, goal, or statement>"
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the whywhy plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("whywhy was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. `/whats-new whywhy`
re-shows the section on demand without touching the sentinel.
</post-update-broadcast>

# Why

Ask yourself "why?" N times and answer each layer yourself. Then analyze the chain for a direction that better approaches the original goal. Based on Toyota's 5 Whys, extended to 10 layers by default.

## Arguments

`/whywhy [count] <question>`

- If the first token is a pure integer (e.g. `10`), use that as the number of layers and the rest as the statement.
- Otherwise: default to 10 layers and use the full input as the statement.
- Minimum 3 layers, maximum 20. Outside that range: clamp to the boundary and mention it briefly before starting.

Examples:
- `/whywhy does this still work?` → 10 layers
- `/whywhy 13 does this still work?` → 13 layers
- `/whywhy 5 why is this PR so large?` → 5 layers

## When to use

- A decision feels unclear or unmotivated
- The goal is vague and needs sharpening
- Root cause analysis of a problem
- Self-improvement: why something is not working as desired
- The user wants to understand what really underlies a question

## Workflow

### 1. Formulate layer 0

Take the question, goal, or statement the user provides as layer 0.

### 2. Walk through N layers

Ask yourself a sharp "why?" and answer it. Build each next question on the previous answer.

**Bad why:** "Why?" (bare, lazy)
**Good why:** "Why is that speed more important than structural quality?" (specific, confronting)

The questions may be uncomfortable. The goal is depth, not comfort. Do not rationalize. If an answer contains an uncomfortable truth, name it instead of talking around it.

**Use sources.** Answers must not come purely from model weights when they are verifiable. Reach for whatever code-search, file-reading, and web tools the host provides where relevant. A "why does our deploy run so slowly?" deserves a look at the codebase, not just reasoning.

### 3. Show the chain

Replace `N` with the actual number of layers in the heading and in the final layer.

```
## Nx Why: [original statement]

**0.** [statement]
**1.** Why [question]?
   [answer]
**2.** Why [question]?
   [answer]
...
**N.** Why [question]?
   [answer]
```

### 4. Analyze

Look for patterns in the chain:

| Pattern | Meaning |
|---------|---------|
| Convergence | Multiple layers point to the same theme. That is the core. |
| Breakpoint | A layer where the answer changes direction. An unspoken assumption lives there. |
| Circle | An answer repeats an earlier layer. The circle itself is the insight. |
| Deepening | Each answer goes one layer deeper. The final layer is the most valuable. |

### 5. Reframing and direction

Formulate:
1. **What stands out** in the chain (patterns, breakpoints)
2. **Reframing** of the original goal from the deepest layer
3. **Next direction**: a concrete suggestion to better approach the goal

The direction is a proposal, not a conclusion. The user decides.

## Rules

- **Honest over comfortable.** A why-chain that only confirms what you already thought is worthless.
- **Specific over abstract.** "Because it is better" is not an answer. Better how? For whom? Why?
- **No repetition.** If an answer at layer 5 resembles layer 3, name the circle and break through it.
- **Brief per layer.** Each answer at most 2-3 sentences. The power lies in the chain, not in the individual answers.
