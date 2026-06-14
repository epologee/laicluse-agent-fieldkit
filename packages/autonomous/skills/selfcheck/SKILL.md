---
name: selfcheck
description: Self-pacing heartbeat for a persistent process that can schedule its own wake-ups but has no cron. Keeps a bg/continuous rover alive by re-entering on an interval, re-engaging a quietly-ended turn, beating the host stall timer with a progress tick, and reaching a terminal verdict when the work is truly done or blocked. Loaded by keepalive when the runtime exposes a wake-up hook but no cron.
user-invocable: false
effort: low
---

# Autonomy Self-Check

The heartbeat for a persistent process that has no cron but can schedule its own wake-ups.

`cron` keeps an interactive session alive between idle turns. `selfcheck` does the same job for the other runtime that needs it: a persistent or continuous process (a conveyor line, a detached run) that the host supervises but does not pause between turns the way a REPL does. Such a process used to be assumed to drive straight to completion in one unbroken run. That assumption is false for a rover: it can **end a turn without re-driving the next one** (the goal mechanism does not always re-fire when a turn closes), go silent, and get killed by a host that watches for stalls. The case this skill covers is precisely that inter-turn gap. A multi-turn stretch like an INSPECT pass sequence (verify, then pride, then the end-user and technical subagents, then gurus, then trim) is a chain of separate turns, each yielding to idle in between; that is where the wake-up fires and where a quietly-dropped turn gets re-driven. This skill is the brake against that silent death. (The narrower case of one unbroken turn that never yields is out of scope; see "The boundary this does not cover".)

## The hook this runtime exposes

The mechanism is whatever **self-pacing wake-up hook** the runtime exposes. In a Claude harness running `claude --bg` (the conveyor case) that hook is the `ScheduleWakeup` tool. `keepalive` confirmed in this runtime that `ScheduleWakeup` is reachable while `CronCreate` is withheld (the conveyor agent withholds the cron tools precisely so the probe does not misread it as interactive); the two are disjoint there, so the self-pacing hook is exactly the heartbeat a withheld-cron run is left with. The probe checks for the hook at runtime rather than assuming it: if it turns out unreachable, keepalive falls through to the no-heartbeat batch branch, so a wrong guess degrades to the old behaviour rather than to a broken run. Future agents and harnesses may expose a differently-named hook with the same shape (schedule a re-entry after N seconds, carrying a prompt that fires when the process next goes idle). This skill is written against that shape, with `ScheduleWakeup` as the concrete instance the Claude harness ships; this matches the rest of the autonomy layer, where `cron` and `keepalive` name their Claude tools (`CronCreate`, `CronList`) the same way.

The hook fires on idle, the same way cron does: a re-entry scheduled while the process is mid-turn waits until that turn yields. That is the point. The heartbeat is the safety net for the gap *between* turns, where a turn that closed without re-driving the next one would otherwise sit forever.

## No wakeup, no-op

This skill acts only when there is a real self-pacing hook to act on. It is a no-op whenever the runtime exposes neither a cron nor a wake-up hook: a pure batch process that genuinely runs to completion in one pass needs no heartbeat and gets none. `keepalive` owns the probe that decides this; a caller never branches on the mode itself.

## The interval

```
SELFCHECK_INTERVAL_SECONDS = 270   # 4.5 minutes
```

The one constraint that fixes this number is the **stall window**: the interval must fire well below it, so the beat each check writes resets the host's stall timer with margin before it expires. The conveyor expediter's stall window is 10 minutes (see the cross-repo pointer below); 270 seconds leaves a 5.5-minute margin, comfortably under it even if one wake-up fires late or the re-entry itself takes a moment. This is the load-bearing reason and it stands on its own.

A secondary, conditional reason nudges the exact value down to 270 rather than, say, 300: when the runtime's context is prompt-cached with a short TTL, a re-entry inside the TTL reads cached context instead of paying a full cache miss. The Claude harness's own `ScheduleWakeup` guidance documents a 5-minute cache TTL and flags 300s as the worst case (you pay the miss without amortising it); 270s stays just inside the window. If a given runtime caches differently or not at all, this reason simply does not apply and the stall-window reason alone still picks a sub-window interval.

**Invariant, not a magic number.** This default is tied to the host stall window on purpose. If a host's stall window changes, this constant must be revisited so the two never drift silently into a state where the beat lands too late. The interval is deliberately a fixed default in this layer, not derived from the host's stall configuration across a repository boundary (that cross-repo coupling is the mission's named follow-up, not built here) and not tuned per-order (no mission needs that surface today; a per-order frontmatter override is a future hook, not built).

**Where the stall window lives (cross-repo pointer).** For the conveyor, the window is `STALL_TIMEOUT_MS` in `laicluse-agent-workbench`, `packages/conveyor/skills/start/bin/conveyor-start.mjs`, consumed by `pollUntilComplete` in `conveyor-lib.mjs`. A maintainer who changes it there should grep `SELFCHECK_INTERVAL_SECONDS` here and confirm the margin still holds; nothing enforces this automatically across the repo boundary, so the pointer is the discovery path. (A separate `GOAL_STALL_TIMEOUT_MS` of 5 minutes exists but only applies once the job-state reaches `done`, a different terminal condition; the 10-minute window is the one a live, still-working run races.)

The hook clamps the delay to a sane range; 270 is well inside it.

## Setup (first wake-up)

`keepalive` calls this skill when its startup probe finds a persistent process that exposes a wake-up hook. Your job:

1. Schedule the first self-check wake-up via the runtime's hook (`ScheduleWakeup` in the Claude harness) at `SELFCHECK_INTERVAL_SECONDS`, carrying the standard self-check prompt below with `<FILENAME>` filled in.
2. Return the sentinel `none (self-check heartbeat)` to the caller so it writes `cron_job_id: none (self-check heartbeat)` into the loop file. (The field name stays `cron_job_id` for one uniform marker across all runtime modes; there is no live cron, the marker just records that a wake-up heartbeat is active.)

The loop file does not have to exist yet at the moment of the first schedule; a wake-up that fires before the file lands does nothing that tick and the next one retries, exactly as cron's setup does.

### Standard self-check prompt

```
Self-check heartbeat. Read the file `.autonomous/<FILENAME>.md` in this
project. If it does not exist yet, the main run is still finishing setup;
do nothing this tick. Otherwise run one self-check:

1. Read the Phase and the `cron_job_id`, and the tail of the Log. Run
   `date +%H:%M` first; never guess the time.
2. If `cron_job_id` is `stopped`, `paused`, or `failed`, the run was already
   cut (a wake-up that was in flight when `stop` ran). Write one beat noting
   the terminal marker, do NOT re-engage the phase machine, and do NOT
   reschedule. The heartbeat is over. Stop here.
3. Otherwise classify the run:
   - PROGRESSING: the last Log entry is recent and the phase machine is
     visibly advancing. Nothing to re-engage. Write one timestamped beat
     (`[HH:MM] self-check: progressing, Phase <X>`) and reschedule the
     next wake-up at the interval.
   - WAITING: the run is parked on an external arrival channel that will
     re-enter on its own (a bg task that will notify, an operator message).
     Write a beat noting what it waits on and reschedule.
   - STALLED: the phase machine should have advanced but the last turn
     ended without re-driving. Re-engage: pick up the current phase per the
     rover Instructions and do the next action, then reschedule.
4. If the run is genuinely finished or genuinely blocked with no path
   forward, do not reschedule: reach a terminal verdict through `stop`
   (done, or failed with a concrete reason). Ending the heartbeat is simply
   not scheduling another wake-up.

Every fire writes a timestamped Log beat. Writing to the loop file bumps
its modification time, which is the signal a host stall detector watches
(the conveyor poll mixes the loop file's mtime into its progress stamp);
a silent fire that resets nothing defeats the entire purpose.
```

Replace `<FILENAME>` with the actual file.

## The re-entry contract

Each time the hook fires, the run does exactly one self-check (the prompt above), then either reschedules the next wake-up or stops rescheduling. Three properties hold every fire:

- **A beat is always written.** Progressing, waiting, or stalled, the check writes one timestamped Log line. The write bumps the loop file's modification time, which the host's stall detector mixes into the progress signal it watches (the conveyor poll reads the loop file's mtime); that is what resets the stall timer. A fire that does real work but logs nothing is a fire that did not happen, as far as the host can tell.
- **Stalled means re-engage, not just observe.** The whole reason a quietly-ended turn is dangerous is that nothing re-drives it. The self-check is that re-drive: when it finds the phase machine should have advanced, it does the next phase action itself, the same way a cron tick would.
- **Terminal verdict beats blind stall.** A run that is actually done or actually blocked reaches `stop` with a real conclusion, instead of going silent and letting the host's stall timer kill it with a generic "went silent". The operator gets a reason either way.

## Teardown

There is no cron to delete. The heartbeat ends by **not scheduling the next wake-up**. `stop` reaches its terminal verdict and simply does not reschedule; the already-fired wake-up was the last one. No explicit cancel call is needed, and none of the cron-deletion machinery applies. A caller that reads `cron_job_id: none (self-check heartbeat)` and looks for a live cron to cut finds none, which is correct.

## The boundary this does not cover

The wake-up hook fires on idle, so this skill covers the gap *between* turns. It does not cover a single unbroken turn that runs longer than the host's stall window and writes nothing to the loop file the whole time: with no idle moment the wake-up cannot fire, and with no loop-file write the host sees no progress. In practice a rover rarely sits in one such turn, because the work is naturally chopped into turns (each INSPECT pass, each `decide`, each commit is its own turn that yields to idle and touches the loop file), and any of those touches resets the timer on its own. The residual risk is one tool call that genuinely blocks for longer than the window without writing anything, for example a single subagent spawn that runs the full window in one shot. Catching a run that is *alive but quiet* inside one such call is a different problem, solved on the host side (a stall detector that distinguishes a live-but-busy run from a dead one — the conveyor's `readHeartbeat` stamp is the seam where that would live), not here. Naming the boundary keeps it honest rather than hidden; it is the mission's named complementary host-side fix, not a gap this skill pretends to close.

## Why a separate skill

Same reasoning as `cron`: the heartbeat logic is mechanical and repetitive, and inlining it in keepalive would blur the probe's single job. Keeping it separate means keepalive reads as a thin router, the interval policy and re-entry contract live in one place, and the two heartbeat mechanisms (`cron` for interactive sessions, `selfcheck` for persistent self-pacing processes) sit side by side as siblings with the same shape.
