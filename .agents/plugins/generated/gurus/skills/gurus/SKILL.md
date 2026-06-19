---
name: gurus
description: >-
  Route /gurus to the software, council, or writers panel when the right panel is not yet known.
allowed-tools:
  - Skill
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git status *)
  - Bash(git branch *)
---

# Gurus Orchestrator

Three panels live under this plugin:

- **`gurus:software`** does opinionated code review with eight engineering personas (Beck, Fowler, Uncle Bob, DHH, Metz, Evans, Hickey, Ousterhout). Consensus across 6+/8 yields an action plan.
- **`gurus:council`** critiques a decision or idea with five adversarial lenses (pre-mortem, first-principles, opportunity-finder, stranger, action), anonymous peer review, and chairman synthesis.
- **`gurus:writers`** reviews a piece of prose with six writers (Didion, Saunders, Rovelli, Watts, Gladwell, Urban). Consensus across 4+/6 yields an action plan of edits, cuts, and rewrites.

This orchestrator decides which panel fits the question.

## Routing

### Implicit signal from context

Read the context before asking the user anything. Beyond the conversation you may call `git status`, `git log`, and `git diff` to check recent code activity; the frontmatter allows this.

- **Software** is the right panel when:
  - The conversation discusses a diff, code change, or codebase review
  - The user names a file or directory to review
  - Recent commits exist and the question feels like "is dit goed?"
  - The user uses words like "review", "refactor", "smell", "structure"
  - The user asks a technical correctness question ("does this regex do X?", "is this query right?"); this is not a decision but a code question and falls under software
  - The user pastes a code snippet. Pass that snippet as an explicit scope via `args` so the software skill does not accidentally scan the whole codebase

- **Council** is the right panel when:
  - The question is a trade-off or decision ("moet ik X of Y?"), not a question about code correctness
  - The topic is strategic, product-oriented, or interpersonal
  - The user wonders whether the active agent was just being agreeable ("was ik te hard voor je?" is a signal)
  - The question contains no concrete technical correctness question

- **Writers** is the right panel when:
  - The artefact under review is prose, not code: an essay, a script, a manuscript chapter, narrative HTML editorial, voiceover, long-form copy
  - The user names a `.md`, `.txt`, or HTML file with body prose, or pastes a paragraph for review
  - The user uses words like "voice", "tone", "narrative", "pacing", "opening", "ending", "cadence", "schrijfstuk", "manuscript", "essay", "copy"
  - Recent commits or `git diff` show changes in markdown or prose blocks rather than source code

**Tiebreaker when both signals fire.** A "should I use a service object here?" mixes a decision form ("should I") with code context. In that case: default to **software**, because the code is the ground truth; mention in the proposal line that council also fits and offer the override explicitly. When code and prose are both in scope (a feature with both implementation and changelog/docs), default to the artefact under direct discussion: the file the user named, the paragraph they pasted, or the kind of file dominating the recent diff.

Example tiebreaker proposal:

> You are asking whether to use a service object, and you have code in context. Two panels fit. Routing to **software** (code as ground truth). Type `council` to get a design-decision review instead.

### Default and override

Determine a default based on the signals and present it to the user. Example:

> I see a recent diff on `packages/foo/`. Routing to **`gurus:software`**. Type `council` to switch to the adversarial panel.

Or:

> Your question reads as a strategic choice without code context. Routing to **`gurus:council`**. Type `software` to get a code review.

When there is direct explicit intent (the user said "council", "software", or "writers" in their message) skip this check and dispatch immediately.

### No signal

When context is empty or multiple panels are equally plausible, ask one short question:

> Three panels available: `software` for code review, `council` for a decision or idea, `writers` for a piece of prose. Which fits?

Ask this question **once**. The user's answer is binding; do not confirm again.

### Skill-invoked (autonomous callers)

When this orchestrator is invoked by another skill rather than typed by the
operator (an autonomous caller that passes mission context through `args`), the
operator is not in the loop and cannot answer a routing question. Routing must
complete from `args` alone.

Detection: `args` carries explicit mission context (a Dispatch block, a branch name, a diff summary, a stated decision, a research brief). Treat any non-empty caller-supplied context as the autonomous path.

Rules in this mode:

- **Never ask the user.** The "ask once" fallback in the No-signal section does not apply. If the implicit signals are weak, pick a default and dispatch.
- **Default when multiple panels fit:** `software` if `args` contains code, a diff, file paths to source files, or a branch name; `writers` if `args` references prose files (`.md`, `.txt`, body-prose `.html`) or pastes a paragraph for review; `council` if `args` is purely about a decision, plan, or strategy without code or prose attached.
- **Caller-named panel wins.** If `args` contains the literal token `panel: software`, `panel: council`, or `panel: writers`, dispatch that panel without further routing logic.
- **No proposal line, no override prompt.** The caller is autonomous; produce the review directly.
- **Multi-axis dispatch is allowed.** When `args` describes a mission that mixes a code deliverable and a strategic call, dispatch both panels in sequence (software first, then council). Combine the verdicts in the return value.

The contract: a skill-invoked call always produces a verdict and never bounces back a question.

## Dispatch

After routing: run the chosen sibling skill. If this Codex session exposes a
skill-dispatch tool, invoke `gurus:software`, `gurus:council`, or
`gurus:writers` with the concrete question, scope, or piece of prose as `args`.
If it does not expose such a tool, read and follow the chosen sibling skill's
instructions from this plugin directly. Do not ask the operator to retype the
same request with a different slash command.

**When the user typed `/gurus:gurus` without accompanying text**, there is no literal question to pass on. Synthesize a one-sentence summary of the current topic from the conversation (optionally enriched with the output of `git status` or `git log -1`) and pass that as `args`. Keep the summary neutral; no framing that steers the panel toward a particular verdict.

**When the user pasted a code snippet**, pass that snippet as explicit scope in `args` so `gurus:software` does not scan the full codebase but only the snippet (and optionally the surrounding file the user mentioned).

**When the user pasted a paragraph or short excerpt of prose**, pass it as explicit scope in `args` so `gurus:writers` reviews the excerpt (and the surrounding file when named) rather than asking for a file path.

The sub-skills take over. This orchestrator does not do any review itself.

## Rules

- **Routing is fast.** At most one question to the user before dispatching. Every second question is a failure mode.
- **Explicit intent wins.** When the user already named `software`, `council`, or `writers` in the invocation, skip the routing step and dispatch directly.
- **Do not review yourself.** This skill only presents the choice and delegates. Substantive review happens in the sub-skill.
- **Stay neutral between panels.** Present both as legitimate; the context determines which fits, not which panel is "better".
