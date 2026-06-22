# intervision

Peer consultation for coding agents. Intervision is the practice of equals
reviewing each other's work, the opposite of supervision from above. This
plugin brings another coding agent in as that peer: Claude hands work to Codex,
Codex hands work to Claude, and the two reads are compared before anything
lands. The signal is the gap between two independent agents, the spots where
you and the peer disagree.

## Commands

### `/intervision:second-opinion`

Hands the recent work to the other agent and talks it through. Claude uses
`codex exec` on the cheap coding model advertised by `codex debug models`
first, preferring Codex Spark and then mini, and escalates to the configured
Codex default only when the cheap pass is uncertain, misses a concrete concern,
or the work is high-risk. Codex uses `claude -p`. Three shapes, picked by what
just happened:

- **Work just done (a diff):** the peer reviews the actual change set.
- **A design just discussed (no code yet):** the peer reflects on the plan
  without touching the tree.
- **Back and forth:** continue the exchange to push a point, defend yours, or
  ask the peer to reconsider.

The exact agent-specific invocations live in the suffixed skill sources.

The peer's findings come home through three honest fates: fix, skip on cost versus
value, or reject as hollow. The exchange and any remaining disagreement are
surfaced to you.

## Requirements

The peer CLI must be installed and logged in: Claude needs `codex`; Codex needs
`claude`. Reviews run against your own account and quota, so a large diff is a
real billed call. The skill preflights for the CLI and stops with a plain
message when no peer is available.

Claude-side Codex model selection lives in `bin/codex-fast-coding-model`.
`INTERVISION_CODEX_MODEL` can override the catalog choice for one run.

## Installation

```bash
claude plugins install intervision@laicluse-agent-fieldkit
codex plugin add intervision@laicluse-agent-fieldkit
```
