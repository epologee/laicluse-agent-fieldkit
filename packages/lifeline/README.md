# lifeline

Two ways to reach outside your own head when your own certainty runs out, the
way a game-show contestant phones a friend. Both skills consult external
reality instead of trusting the model's first answer; they differ only in when.

## Skills

### `/inspire`

Online research that answers "how do others do this?", "what already exists?",
"what can we learn from published experience?" before you commit to a path.
Forward-looking and divergent: it widens the option space and ranks by quality
of the end result, not ease of implementation. Triggers on `/inspire [topic]`,
on unfamiliar territory, and on phrases like "hoe doen anderen dit?".

### `/ground`

Verify your own recent output against external sources when a claim is doubted.
Backward-looking and convergent: generation and verification are separate
processes, so it re-checks a specific claim with code search, file reads, and
the web rather than re-asserting from model weights. Triggers on `/ground`, on
skepticism signals like "dat klopt niet", and on necessity claims that justify
complexity.

## Installation

```bash
claude plugins install lifeline@laicluse-agent-fieldkit
codex plugin add lifeline@laicluse-agent-fieldkit
```
