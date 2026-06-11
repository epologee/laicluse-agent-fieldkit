---
name: rover-help
description: Rover briefing. Explains what the autonomous Rover does and how to dispatch, steer, and stop one. Read this when you are about to send a Rover out for the first time, or when you forgot which command does what.
---

## When this skill is invoked

Print the briefing below to the user **verbatim**, including the ASCII art and all section headings. Do not summarise, paraphrase, translate, or compress, not even in caveman, wenyan, terse, or low-token modes. The briefing is the output; your job is to deliver it intact. Stop immediately after printing. Do not add follow-up questions or offers to help.

---

# Rover Briefing

```
                       ▁▁▁▁
                      ▇███▉
                      ▕██▉▀
                        █▉                   ▂▂▂
                       ▝▇▛▘                  ▐██
                        █▋                   ▐█▀ ▃▅▇▇▆
      ▗▇▇▖       ▃▄▄▄▖  █▛          ▖▗▄▄▄▄▄ ▗▄▅▅▜█████▉▖
       ▜▛▜▅▁     ▀▜██▀▗▟██▏▗▅▕▉   ▂▂▊▂ ▐█▋▁▐████▐██████▍
       ▐▋ ▔▀▆▃    ▁█▍▆▆██▆▆▆▆▆▆▇▊▆▆▆▆▆▆▆▆▆▆▇█████████▛▀
       ▐▋    ▀▇▖▂▃█████████████▙▙██████▉█████████▀▀▘
       ▐▋      ▜█▉▔▔▂▔▜██████▇█████████▉████████▐▎▂▖
     ▐▊▐▋          ▐█▆▇▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▜██████▙▅▅▟▙
     ▐███          ▜▇▘                 ▂▅▛▀▘▔    ▝▇▇▘
    ▄▄██▙▄▖      ▗▅▜▇▆▄          ▃▆▀▀▆▟▀▔       ▄▆▇▇▆▃
    ▝▀▀▀▀▔▘     ▗▛ ██▌ ▙        ▟▘▕▅▅▎▝▋       ▟▘▐██▎▐▌
                ▝▋▔▛▀▌▔▛        ▜▖▔▛▜▔▗▋       ▜▖▝▛▜▔▐▌
                 ▝▀▅▄▞▀          ▀▜▄▄▛▀         ▀▜▄▄▛▘
```

Welcome to Mission Control. This is the short version of what the Rover does and how you drive it. Roughly ten percent astronaut, ninety percent practical.

## How to dispatch

```
/rover:rover "<mission brief>"
/rover:rover .autonomous/<NAME>.md         # wake an existing mission
```

The mission brief is free-form text. A GitHub URL pasted on its own counts as text: the Rover does not fetch remote content autonomously. If the issue body or PR diff is part of the mission, the operator pastes it into the brief.

On dispatch, the Rover first runs a short reversibility check (is there a git repo with commits, is the working tree clean, is the current branch the default one) and asks once if any of those cannot be answered "yes" on its own; that is the only moment in the whole mission where the Rover asks anything. When the check is resolved it creates a mission branch named after the goal, writes `.autonomous/<NAME>.md` (the mission file holding context, plan, Done criteria, decision audit, and a timestamped log), and runs the first SURVEY iteration in the same turn. In an interactive session it also asks the autonomy layer to keep it alive, which sets up a Claude Code cron that fires the loop every minute while the REPL is idle; a persistent process skips the cron and drives straight to completion.

The mission file is your window. Tail it to watch the traverse.

## What the Rover does

You dispatch a Rover at a task. You stay back. The Rover rolls across the codebase on its own, surveying terrain, driving changes, inspecting its own work, stowing the build-time clutter, and standing by for new signals. It does not radio home for every fork in the traverse; it carries a `decide` framework and a `pride` check so it can keep moving without waking you up.

The stance: _festina lente_. Hasten slowly. A Rover in a hurry drives into a crevasse. The operator is not in a hurry either.

## Phase machine

```
SURVEY ──► DRIVE ──► INSPECT ──► STOW ──► STANDBY
    ▲           ▲            │                  │
    │           └────────────┘                  │
    └──────── new signals ────────────────────────┘
```

- **SURVEY.** Read the codebase, form hypotheses, lock down a plan, write Done criteria via `verify --propose`.
- **DRIVE.** Build. Commit per logical step. Verify as you go.
- **INSPECT.** Four passes: `verify` against Done criteria, `pride` contrarian review as the phase gate on the current batch of work, end-user walkthrough, technical plan-vs-diff. Any failure sends the Rover back to DRIVE. `pride` also runs separately on every artefact the Rover hands off later (the `stop` communiqué is its own pride pass, not a second invocation of this INSPECT gate).
- **STOW.** Mechanical cleanup only. Debug prints gone, unused imports gone, half-finished refactors finished. Separate commit.
- **STANDBY.** Watch channels (PR comments, CI, uncommitted work). Back off the cron as idleness grows. Auto-stop after about five hours of quiet.

## How to steer a running Rover

- **Talk to it in the session.** Your turns take priority; the cron waits for idle.
- **Write into `## Input` in the mission file.** The Rover reads that section each STANDBY tick and acts on it.
- **Stop it.** Use the stop flow (currently reached via the Rover entry; writes a final log entry, cuts the cron, and transmits a home communiqué).
- **Resume a stopped Rover.** Re-dispatch with the mission file path.

## Related commands you can call directly

| Command | What it does |
|---------|--------------|
| `/rover:rover` | Dispatch a Rover. Accepts a free-form mission brief or a mission file to wake. |
| `/rover:verify` | Standalone evidence check. Propose Done criteria, or tick them off with evidence. |
| `/rover:pride` | Contrarian review of the current branch diff. Finds what the operator would hate. |
| `/rover:decide` | Choice framework. Use when you are stuck between options, inside a Rover or not. |
| `/rover:rover-help` | This briefing. |

## What the Rover will never do on its own

- Ask the operator anything mid-mission (it uses `decide` for every fork, including scope calls)
- Defer, postpone, plan, or down-scope a finding (fix it, or reject it with evidence via pride's second-pass gate)
- Push to a remote without explicit operator go (pushes are the one external-action gate that stays operator-held)
- Transition out of DRIVE with a dirty working tree
- Hand off any artefact (code, docs, prose, research brief, media, communiqué) without a logged `pride` pass covering it
- Call a mission done without ticked Done criteria and evidence

## Cost awareness

A cron at one-minute cadence drives many Claude turns during active phases. That is the point: the Rover is working for you. During STANDBY the backoff grows to 60-minute intervals and auto-stops after sustained quiet. For small tasks, a normal conversation is cheaper than a full Rover dispatch.

The Rover keeps reasoning on your session model and offloads the mechanical work to Sonnet subagents: STANDBY polling (`git status`, PR comments, CI checks) and the INSPECT technical pass (diff-vs-plan review). Hand work to subagents, keep head work on the session model. Your model choice for the session sets the ceiling on quality; the subagent floor is Sonnet.

Standing by for mission parameters.
