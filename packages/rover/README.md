# rover

Dispatch a rover at a task. You stay back, the rover works in the field. The
distance means it decides locally rather than round-tripping every question, so
the plugin carries a `decide` framework, a contrarian `pride` check, a
subtraction-biased `trim` pass, and an evidence-discipline `verify` pass. The
rover only reports done when the mission is solid.

This is the decision framework half of the old `autonomous` plugin. The
keep-it-running half (cron heartbeat, wake/restore) now lives in the
`autonomous` plugin, and the rover asks it one question at startup through
`autonomous:keepalive`: am I in a persistent process, or an interactive session
that needs a heartbeat to stay alive? The caller no longer has to know or say.

## Dependencies

- **`autonomous@laicluse-agent-tools`** (same marketplace): the keep-alive
  layer. The rover invokes `autonomous:keepalive` at dispatch.
- **`gurus@leclause`**: the rover invokes `gurus:gurus` once per mission at
  INSPECT for opinionated panel review; the orchestrator routes to
  `gurus:software`, `gurus:council`, or any future panel.

Install together:

```bash
claude plugins install rover@laicluse-agent-tools autonomous@laicluse-agent-tools
claude plugins install gurus@leclause
```

**Host contract for persistent runs.** The keep-alive probe treats `CronCreate`
availability as the interactive-vs-persistent signal. A host that runs missions
as a persistent process (an Agent SDK run, a conveyor line) must withhold the
cron tools, by adding `CronCreate`, `CronDelete`, and `CronList` to its
disallowed-tools list; otherwise the probe reads the run as interactive and arms
an unused heartbeat. See `autonomous`'s `keepalive` skill for the full contract.

No other hard dependencies. Optional integrations (notifier, reviewbot,
commit-splitter) are user-named at invocation and only used when installed.

## User-invocable skills

### `/rover:rover [loop-file-path | free-form text]`

Entry point. Accepts a loop file path to resume (delegates to `autonomous:wake`)
or free-form mission text (a description, a pasted issue body, a GitHub URL).
Writes `.autonomous/<NAME>.md` (the loop file), asks the autonomy layer whether a
heartbeat is needed, and runs the first SURVEY iteration. The rover does not
fetch remote content on its own; paste an issue body or PR diff into the
invocation if it is part of the mission.

### `/rover:stop [loop-file-path]`

Cleanly stop a running mission. Cuts the cron (when one was armed), writes a
final log entry, and transmits a mission-report communiqué.

### `/rover:pride [git-range | uncommitted]`

Spawns a contrarian agent that reviews a rover artefact for what the user would
notice but the rover missed. Hard gate inside the rover on every artefact
(code, docs, prose, research briefs, media, communiqués), not just pushes. Also
invocable directly.

### `/rover:trim [git-range | uncommitted]`

The subtraction pass: what got added that does not earn its weight? Hard gate in
INSPECT, the inverse of pride.

### `/rover:verify [--propose <loop-file> | <loop-file> | free text]`

Evidence discipline. With `--propose`, writes Done criteria at the end of
SURVEY. Default mode ticks each criterion with evidence at the end of INSPECT.

### `/rover:decide [free text]`

Choice framework for a fork in the field, or for any moment an operator is stuck
between options.

### `/rover:prepare [target repo + mission brief]`

Lay a rover loop file in another repo's `.autonomous/` now, so the operator can
pick it up later from inside that repo.

### `/rover:rover-help`

The rover briefing.

## Phase machine

```
SURVEY -> DRIVE -> INSPECT -> STOW -> STANDBY
```

The loop is autonomous. It does not ask questions mid-phase. When it hits a
choice it invokes `decide`. Before any artefact leaves the rover (push, PR,
handoff communiqué, research brief, generated doc, media, or any other
deliverable) it invokes `pride`. Pushes themselves are never autonomous: the
user must say "push" or equivalent.

## Loop file

Lives in `.autonomous/<NAME>.md` at the git root. Holds context, plan, Done
criteria, decision audit trail, and a timestamped log. Tail it to watch
progress. The format is unchanged from the old `autonomous` plugin, so existing
loop files still wake.
