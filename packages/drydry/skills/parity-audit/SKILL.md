---
name: parity-audit
user-invocable: true
description: >-
  The long invocation. A multi-agent, whole-codebase sweep over every entry point that promises one outcome, to find where their consequences diverge, converge the difference into the shared path, and re-run the audit to prove it moved. Runs as a named background process over minutes, not seconds. For a quick "have I seen this code before?" check, use drydry:drydry instead.
allowed-tools:
  - Skill
  - Agent
  - Workflow
  - Bash(git status *)
  - Bash(git log *)
  - Bash(git diff *)
  - Bash(date *)
  - Bash(ls *)
  - Bash(find *)
  - Bash(grep *)
  - Bash(rg *)
  - Bash(wc *)
  - Bash(python3 *)
  - Read
  - Write
  - Edit
  - Glob
  - Grep
effort: high
---

# Parity audit

Drydry's dual. The rest of the plugin hunts **duplication**: the same work written twice. This skill hunts **divergence**: several entry points that promise the user one and the same outcome, reach one and the same shared step, and then quietly do different things afterwards.

That asymmetry is worse than duplication, because duplication is visible in a diff and divergence is not. Every door produces the identical primary result, so every manual test passes. Only the secondary effects differ, and they surface hours later as the absence of something: a reminder that never fired, a listener never woken, a teardown never run. The absence of a future event is the hardest failure mode there is to observe.

## When to use

Reach for this when a system has more than one way to trigger the same outcome. That is nearly always: a button, a keyboard shortcut, a CLI flag, an API route, a scheduled job, a webhook, a voice intent, an undo, an import path, a chapter-skip in a player. Language and stack are irrelevant; the discipline only needs "several callers, one shared step".

Trigger phrases: "does every path do the same thing?", "why did it work from the button but not from the automation?", "we added X but only some flows got it", or an incident where the primary result was right and a follow-up was missing.

Do not use it to find copy-paste. That is `drydry:drydry`.

## The discriminator

One mechanical rule carries the whole audit, and it needs no domain knowledge:

> At N entry points that share a core call, count the statements **after** the core call in each entry point. If they differ, you have divergence.

That is what makes this fannable: a reviewer who has never seen the domain can apply it, in any language, and the answers are comparable across reviewers.

Injected closures are the usual mechanism. A closure is right as dependency inversion and wrong as composition: the moment each caller assembles its own subset of callbacks, you can half-implement the set and nothing complains.

## The seven phases

Five of these carry an established name from the aspect-oriented migration literature; the naming is not decoration, it is how you know the step has been thought about before. Two do not: the comparison rule is an inversion of the standard technique, and the closing re-mine is borrowed from a different field entirely because the refactoring literature stops one step short.

| # | Phase | Established name | What happens |
|---|-------|------------------|--------------|
| 1 | **Mine** | aspect mining | Enumerate every entry point with a side effect, grouped by *surface*, not by folder. |
| 2 | **Explore** | exploration | Read the shared core by hand, in parallel with the fan-out, until you can tell a real finding from a plausible one. |
| 3 | **Compare** | none, this inverts fan-in analysis | Record what runs after the shared call, in one schema, and diff the tails. |
| 4 | **Document** | documentation | Write the artefact. It is not a write-up, it is the baseline phase 7 diffs against. |
| 5 | **Converge** | aspect refactoring | Move the shared consequence to the deepest common point, not the shallowest. |
| 6 | **Guard** | behaviour conservation | Leave an exit-parity test behind: two doors, one spy, same observed effects. |
| 7 | **Re-mine** | closed-loop remediation | Run phases 1 to 4 again, with the same instrument, and read the delta. |

### 1. Mine

Fan out. One reviewer per **entry surface**, never per directory. Divergence lives *between* surfaces; a folder-based split buries the comparison inside one reviewer's context where nobody can see it.

Typical surfaces: direct user controls, scheduled/background work, external triggers (webhooks, intents, deep links, notifications), lifecycle hooks (launch, resume, teardown), administrative or debug paths, and anything embedded that mutates state outside your own code (an embedded browser, a third-party SDK, a vendor console).

Announce the run as a long-running background process with a name that says what is being measured, and poll it between logical steps rather than blocking on it.

### 2. Explore

Do not wait for the fan-out to finish before you understand the thing yourself. While the reviewers run, read the shared core, its callers, and the wiring that injects its dependencies.

This is the step that decides whether the audit is trustworthy. A reviewer that has read one subsystem produces confident, plausible, and occasionally wrong claims; without your own reading you cannot separate those from the real ones, and a confident wrong finding costs more than a missed one. Expect to correct the report, including your own earlier conclusions.

The published strategy places exploration between mining and refactoring for the same reason: mined seeds are candidates, not findings.

### 3. Compare

Every reviewer fills the **same structured schema**. This is not bureaucracy; it is the entire reason eight independent reads become comparable. Free-text reports cannot be diffed against each other or against a later run.

Minimum fields per action: name, entry surface, location, the trigger, the primary effect, the shared call it ends in, the depth at which it enters the shared path, and the load-bearing one, **everything that runs after that shared call**.

Classic aspect mining looks for **high fan-in**: one method called from many places. This phase inverts it. Many places calling one method is the starting condition, not the finding; the finding is that they then disagree about what happens next.

Give the reviewers the failure story that motivated the audit, so they know which axis to scan. On a re-run, tell them explicitly that the story may no longer describe the code and that they must report what the source says today; otherwise they confirm the narrative instead of reading the source.

### 4. Document

Produce one reviewable artefact, and treat it as an instrument rather than a report. It has two jobs: to be read now, and to be diffed against later. An artefact that cannot be re-generated the same way next quarter fails the second job, so the schema and the surface list are part of the deliverable, not scaffolding you throw away.

Drydry states this as detection method as a first-class artefact. The migration literature makes documentation its own phase for the same reason.

### 5. Converge

Put the shared consequence **inside** the shared path. A helper that each door must remember to call is still N call sites, and forgetting to call it is exactly the failure you are removing.

Prefer one capability that names the whole consequence set over several optional hooks, precisely because you cannot half-implement it. Then check what you have actually achieved: moving the trap from "forget the call at N call sites" to "forget the injection at one construction site" is progress, but if the un-injected default is silent and total, you have hidden the trap rather than closed it. Make the empty case something a caller has to name out loud.

Not every difference should be converged, but the bar is high and the burden of proof sits with the difference, never with the convergence.

**Justification is per element, never per door.** A voice trigger may owe the user a spoken confirmation because nobody is looking at the screen. That justifies *the confirmation*. It does not justify that same door also taking a different persistence path, a different teardown, or a different end reason. The moment you accept one justified element as cover for the whole tail, you have stopped auditing.

So: for every statement in the tail that a sibling door does not have, name the constraint that forces it. A constraint is something the door cannot escape, such as running with the app process dead, having no screen, or holding no session. "It grew here" and "this surface has always done it" are not constraints, they are history.

Two paths that are ninety percent parallel and differ on ten percent are the dangerous case, not the safe one. If only that ten percent is genuinely forced, the other ninety is not justified difference, it is a design that was never pulled together, and the audit must report it as divergence even though a plausible-sounding reason exists for the part next to it. Report the justified element and the unjustified remainder as separate lines. A finding that reads "explained by design" without naming the constraint per element is a finding you waved through.

Converge incrementally, one consequence at a time, so the system is never half-migrated in a way that cannot be shipped. That is the literature's incremental integration, and in practice it means one commit per converged consequence, each independently green.

### 6. Guard

The refactoring literature calls the obligation **behaviour conservation**: the change must preserve observable behaviour. A divergence audit sharpens it, because the behaviour you must conserve is *per door*, and the doors did not agree before you started. Decide explicitly which door was right, then conserve that.

Parity tests that compare what goes **into** the shared call catch half the problem. The other half is a test that puts the observed effects of two doors against the same spy. Guardrails belong at the exit, not only at the entrance. Every convergence should leave exactly one such test behind.

### 7. Re-mine

Run the audit again, with the same instrument, after the change. This is not ceremony:

- It catches what the convergence pass itself left behind, one layer out.
- It tells you whether divergence was removed or merely **moved**. That distinction is the real finding, and it is invisible without a second measurement.
- It re-baselines the artefact so the next run has something to diff against.

Report counts honestly. A second pass usually enumerates more finely than the first; more rows is more resolution, not more surface. Say so explicitly or the delta lies.

## Discipline

These cut across every phase; the phase-specific rules live with their phase.

- **Findings are hypotheses until a test reproduces them.** Every behaviour change gets a test that is red first for the stated reason, then green. A divergence you cannot make fail on demand is a divergence you have not understood.
- **A finding that only the audit can see is not finished.** Either a test now fails, or the report names why no test can reach it. Otherwise the next run rediscovers it and you learn nothing.
- **Ship the convergence in slices that each stand alone.** One consequence per commit, each green, so an interrupted audit leaves a working system rather than a half-migration.
- **Say what you did not look at.** Surfaces you skipped, a subsystem the fan-out could not reach, an artefact you could not capture. An audit that reports only what it found reads as complete when it is not.

## Output

A single reviewable artefact with: what changed since the last run, the remaining findings ranked by consequence (not by effort), a convergence map of which commands promise the same thing and where their shared step now sits, and the full inventory grouped by surface.

Rank by what it costs the user when the follow-up is missing. In domains where a missing consequence is expensive and a redundant one is cheap, say so, and let that asymmetry drive the ranking.

Every near-parallel pair gets a line, including the ones you are about to excuse. For each difference the report names the constraint that forces it, or it names no constraint and the difference stands as a finding. "Mostly the same, and the rest is by design" is not a reportable state: split it into the forced element and the remainder, and let the remainder be counted. The report should make a ninety-percent-parallel pair look more alarming than two paths that share nothing, because it is.

## Prior art

The parts are named; the loop is not. Grounded 2026-07-21:

- **Crosscutting concern / code scattering / code tangling** name the phenomenon: one concern spread across regions of the program, versus several concerns overlapping in one region. <https://www.sciencedirect.com/topics/computer-science/crosscutting-concern>
- **Shotgun surgery** (Fowler, *Refactoring*, 1999) names the maintenance symptom: one change forces many small edits across many modules. <https://sourcemaking.com/refactoring/smells/shotgun-surgery>
- **Join point, pointcut, advice** name the mechanics. What this audit finds is *after advice* hand-inlined at every call site instead of applied once at a join point. <https://en.wikipedia.org/wiki/Pointcut>
- **Aspect mining** names phase 1: reverse engineering to find crosscutting concerns in a system that was not written with them factored out. Its classic technique, **fan-in analysis**, looks for one method called from many places. This skill inverts it: it looks for many places that call one method and then *disagree about what happens next*. <https://arxiv.org/pdf/cs/0609147>
- **Integrated crosscutting concern migration strategy** (Marin et al.) is the closest published whole, and supplies phases 1, 2, 4 and 5: mining, exploration, documentation, refactoring. It has no re-mine step. <https://arxiv.org/abs/0707.2291>
- **Behaviour conservation** and **incremental integration** name what phase 6 owes: a migration must preserve observable behaviour and must be able to go in stage by stage alongside the original. In a divergence audit the first obligation needs a decision first, because the doors disagreed before you started. <https://arxiv.org/abs/cs/0503015>
- **Closed-loop remediation** names phase 7, borrowed from compliance and security because the refactoring literature has no equivalent: a finding is not done when it is fixed, it is done when re-verification confirms it is gone. <https://nhimg.org/glossary/closed-loop-remediation/>

Composite name for the practice: **tail parity audit**. "Tail" is the statements after the shared call, which is where the divergence lives and what the discriminator counts. If you prefer to stay entirely inside published vocabulary, call it closed-loop aspect mining.
