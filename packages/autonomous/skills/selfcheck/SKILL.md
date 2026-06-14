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

`keepalive` routes here only after its probe confirms the runtime exposes a **self-pacing wake-up hook** but no cron (see `keepalive` for the probe and why the two tool sets are disjoint by host design). The mechanism is whatever such hook the runtime exposes. In a Claude harness running `claude --bg` (the conveyor case) it is the `ScheduleWakeup` tool. Future agents and harnesses may expose a differently-named hook of the same shape — schedule a re-entry after N seconds, carrying a prompt that fires when the process next goes idle — and this skill is written against that shape, with `ScheduleWakeup` as the concrete instance the Claude harness ships; this matches the rest of the autonomy layer, where `cron` and `keepalive` name their Claude tools (`CronCreate`, `CronList`) the same way.

The hook fires on idle, the same way cron does: a re-entry scheduled while the process is mid-turn waits until that turn yields. That is the point. The heartbeat is the safety net for the gap *between* turns, where a turn that closed without re-driving the next one would otherwise sit forever.

## No wakeup, no-op

This skill acts only when there is a real self-pacing hook to act on. It is a no-op whenever the runtime exposes neither a cron nor a wake-up hook: a pure batch process that genuinely runs to completion in one pass needs no heartbeat and gets none. `keepalive` owns the probe that decides this; a caller never branches on the mode itself.

## The interval

```
SELFCHECK_INTERVAL_SECONDS = 270   # 4.5 minutes
```

The constraint that fixes this number is one inequality: `interval < stall_window − longest_expected_turn`. Because the wake-up fires on idle, the real gap between two beats is the interval plus however long the turn in flight when it fires runs before yielding; that sum must stay under the host's stall window. With the conveyor's 10-minute window, 270s leaves the interval itself 5.5 minutes of headroom and still clears the window after a four-minute turn (≈8.5 minutes total). A turn that by itself approaches `window − interval` is the regime the boundary section calls out, not a margin this constant can widen.

The value lands on 270 rather than 300 for a secondary reason that only some runtimes have: a prompt cache with a short TTL. A re-entry inside the TTL reads cached context instead of paying a full miss; the Claude harness's `ScheduleWakeup` guidance documents a 5-minute TTL and flags 300s as the worst case, so 270s stays just inside it. Where a runtime caches differently or not at all, this drops away and the inequality alone still picks a sub-window interval.

**Invariant, not a magic number.** The default is tied to the host stall window on purpose; if that window changes, this constant must be revisited so the beat never lands too late. It is deliberately a fixed default in this layer, not derived from the host's config across a repo boundary (that cross-repo coupling is the mission's named follow-up) and not tuned per-order (a per-order override is a future hook, not built).

*See also — where the stall window lives:* for the conveyor it is `STALL_TIMEOUT_MS` in `laicluse-agent-workbench`, `packages/conveyor/skills/start/bin/conveyor-start.mjs`, consumed by `pollUntilComplete` in `conveyor-lib.mjs`. A maintainer changing it there should grep `SELFCHECK_INTERVAL_SECONDS` here; nothing enforces the link automatically, so this pointer is the discovery path. (A separate `GOAL_STALL_TIMEOUT_MS` of 5 minutes applies only once the job-state reaches `done`; the 10-minute window is the one a live, still-working run races.) The hook clamps the delay to a sane range; 270 is well inside it.

## Setup (first wake-up)

`keepalive` calls this skill when its startup probe finds a persistent process that exposes a wake-up hook. Your job:

The loop-file path arrives as the skill argument from `keepalive`, the same way `cron` receives its caller's path. Your job:

1. Schedule the first self-check wake-up via the runtime's hook (`ScheduleWakeup` in the Claude harness) at `SELFCHECK_INTERVAL_SECONDS`, carrying the standard self-check prompt below with `<FILENAME>` filled in.
2. Return the sentinel `none (self-check heartbeat)` to the caller so it writes that value into the loop file's `cron_job_id`. The value is one of the canonical markers defined in `autonomous:keepalive` ("The return contract"); that section is the single owner of the marker vocabulary. The field name stays `cron_job_id` across all runtime modes for one uniform marker; here there is no live cron, the marker just records that a wake-up heartbeat is active.

The loop file does not have to exist yet at the moment of the first schedule; a wake-up that fires before the file lands does nothing that tick and the next one retries, exactly as cron's setup does.

### Standard self-check prompt

```
Self-check heartbeat. Read the file `.autonomous/<FILENAME>.md` in this
project. If it does not exist yet, the main run is still finishing setup;
do nothing this tick. Otherwise run one self-check. Acquire the loop-file
lock first (the same lock `cron` and `wake` use, see autonomous:cron's
concurrency section) so two fires cannot act at once; release it at the end.

1. Run `date +%H:%M` first; never guess the time. Read the Phase, the
   `cron_job_id`, and the tail of the Log.

2. STAND DOWN unless this is still the active self-check heartbeat. If
   `cron_job_id` is anything other than `none (self-check heartbeat)` — a
   live cron id (a `wake` re-decided this run as interactive), or `stopped`,
   `paused`, `failed` (the run was cut) — this wake-up is a leftover, not the
   live heartbeat. Write one beat noting the marker, do NOT re-engage, do NOT
   reschedule. Stop here.

3. FIRST FIRE: if the Log holds no earlier `self-check:` beat, this is the
   first fire. Write one beat (`[HH:MM] self-check: first beat, Phase <X>`)
   and reschedule. Do not classify or re-engage on the first fire; you have
   no prior beat to measure progress against yet.

4. Otherwise classify, measuring against the PREVIOUS `self-check:` beat.
   Your own beats are never progress: a `self-check:` Log line does not
   count. Real progress is a Phase change or any non-beat Log entry dated
   after the previous beat.
   - PROGRESSING: there is real progress since the previous beat. The run is
     driving itself. Write a beat
     (`[HH:MM] self-check: progressing, Phase <X>`) and reschedule.
   - WAITING: no real progress, AND the latest non-beat Log entry names an
     external arrival channel that will re-enter THIS run on its own — a bg
     task that will notify, or an operator message. (A cron is not such a
     channel: this run has no cron, so "waiting on a cron tick" is a STALL,
     not a WAIT.) Write a beat naming what it waits on and reschedule. Do NOT
     re-engage; double-driving a parked mission is wrong.
   - STALLED: anything else — no real progress and no qualifying wait. When
     in doubt between WAITING and STALLED, choose STALLED: a redundant
     re-drive is cheap, a missed one is the silent death this exists to stop.
     Re-engage: follow the `## Instructions` section of THIS loop file for
     the current Phase and do its next action, write a beat
     (`[HH:MM] self-check: re-engaged <Phase>, <what you did>`), then
     reschedule.

5. If the run is genuinely finished or genuinely blocked with no path
   forward, do not reschedule: reach a terminal verdict by invoking
   `rover:stop` with this loop file's path as the argument
   (`.autonomous/<FILENAME>.md`) — passing the path matters, with no argument
   `stop` asks an operator which file to stop and none is present. If `stop`
   instead bounces the run back to DRIVE (it found unresolved work), the run
   was not finished after all: treat that as a re-engage and reschedule
   rather than calling `stop` again. Ending the heartbeat is simply not
   scheduling another wake-up.

To reschedule (steps 3 and 4): schedule the next wake-up at the heartbeat
interval, carrying THIS SAME prompt with `<FILENAME>` already substituted,
so the next fire is identical to this one.

Every fire writes one timestamped Log beat. That loop-file write is how the
host detects the run is still alive (it resets the host's stall timer); a
fire that resets nothing defeats the entire purpose.
```

Replace `<FILENAME>` (the bare loop-file stem, e.g. `BUILD-AUTH-PAGE`, not
the path or the `.md`) everywhere it appears — the read path, the step-5
`stop` argument — before scheduling the first wake-up; every later
reschedule carries that already-substituted prompt forward unchanged. The
prompt is frozen at first schedule: a later edit to this skill does not
reach an in-flight run, which carries the version that started it.

## Why the prompt is shaped this way

The prompt above is the normative contract; this section is only the reasoning behind its three load-bearing moves. A *beat* throughout is one timestamped Log line written by a fire; the *heartbeat* is the recurring wake-up mechanism. The two are not the same word for the same thing.

- **A beat is always written, even on a quiet pass.** The whole value of a fire is the loop-file write it produces: that write is how the host tells a live run from a dead one (see "The interval" for the concrete conveyor signal). A fire that decides "nothing to do" and writes nothing is, to the host, indistinguishable from a process that died.
- **Stalled means re-engage, not just observe.** A quietly-ended turn is dangerous precisely because nothing re-drives it. The self-check is that re-drive: it does the next phase action itself, the same way a cron tick would. A heartbeat that only noted the stall without acting would still let the run die, slower.
- **A terminal verdict beats a blind stall.** A run that is actually finished or actually blocked reaches `stop` with a real conclusion, so the operator reads a reason instead of a generic "went silent" from the host's stall timer.

## Teardown

There is no cron to delete. The heartbeat ends by **not scheduling the next wake-up**. `stop` reaches its terminal verdict and simply does not reschedule; the already-fired wake-up was the last one. No explicit cancel call is needed, and none of the cron-deletion machinery applies. A caller that reads `cron_job_id: none (self-check heartbeat)` and looks for a live cron to cut finds none, which is correct.

## The boundary this does not cover

The wake-up fires on idle, so this skill covers the gap *between* turns, not a single unbroken turn that runs past the stall window while writing nothing: with no idle moment the wake-up cannot fire, and with no write the host sees no progress. In practice the work is chopped into turns — each INSPECT pass, each `decide`, each commit yields to idle and touches the loop file — so any of those resets the timer on its own; the residual risk is one tool call (a subagent spawn, say) that blocks the full window in one shot. Catching a run that is *alive but quiet* inside such a call is a host-side problem (a stall detector that tells live-but-busy from dead), not this skill's; the same idle-fire limit applies to `cron`, which an interactive operator is present to notice. Naming the boundary keeps it honest; it is the mission's named complementary host-side fix, not a gap this skill pretends to close.

## Why a separate skill

Same reasoning as `cron`: the heartbeat logic is mechanical and repetitive, and inlining it in keepalive would blur the probe's single job. Keeping it separate means keepalive reads as a thin router, the interval policy and re-entry contract live in one place, and the two heartbeat mechanisms (`cron` for interactive sessions, `selfcheck` for persistent self-pacing processes) sit side by side as siblings with the same shape.
