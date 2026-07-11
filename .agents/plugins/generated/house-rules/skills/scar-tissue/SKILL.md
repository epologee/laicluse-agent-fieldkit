---
name: scar-tissue
description: >-
  Use when wrapping up work before handing it over: cut the residue of iterative fixing so the deliverable shows the destination, not the journey. Triggers on "scar tissue", finishing a branch, an end-of-work cleanup pass, or writing a changelog, commit message, or PR description. Spans code, changelogs, commit history, PR text, and tests.
---

# Scar tissue

Hand over the result, not the log of every failed attempt to build it.

We iterate toward a result, locally, in a branch, in a closed loop. What you hand over is that result, not the result with the R&D log of every dead end stapled to it, "first we tried this, it failed; then that, it failed; then this." Scar tissue is that log leaking into the deliverable: the residue the *fixing* leaves behind, distinct from the bug it fixed. It works, but it is stiffer, it reads like a fight instead of a design, and it compounds, because the next agent inherits the archaeology instead of clean tissue.

A meandering, corrected path generates it. Watch for it in every artifact, not just code:

- **Code**: a compensating layer stacked on an earlier fix; an escape for a problem you caused; a mechanism built *around* one that already existed because you did not read for it first; a WHY-comment defending a struggle rather than carrying load-bearing intent.
- **Changelogs**: an entry that undoes the entry above it; several versions churning one misfeature.
- **Commit history**: the tried-X, reverted, tried-Y trail instead of one clean atomic commit that delivers the capability.
- **PR descriptions**: a narration of the fight instead of the capability delivered.
- **Specs, issues, design docs**: a section that narrates your own deliberation or catalogues the decisions you deliberately left open ("what I did not decide, and why"). It is the cowboy novel whose preface explains it is not about an astronaut who never went to the moon. Leaving a choice open means omitting it; the reader silently fills that space. Enumerated non-decisions read as scope and send the next reader down a track that was never real.
- **Tests**: a spec bent to accommodate churn, or pinning behaviour a past wound left behind.

## Invoked on a suspected scar: look before you cut

Being invoked is usually a pointer, not a blank cheque. The operator saw something go by in the trace, thought "this did not need to happen" (a changelog that undoes itself, an escape for a self-inflicted problem), and wants it gone; or wants a control check, because generating scar tissue is a coding-agent reflex. Do not open with questions, and do not open with assumptions.

- **Look first.** Read the flagged artifact, or for a control check the recent diff. Cutting on sight, and assuming a wide sweep when one thing was pointed at, are both the reflex, not the work.
- **Run the test on each candidate.** Name what it serves in the system today. A clear scar is cut without asking. Something load-bearing but non-obvious is kept, and you say what it serves: a flagged item is occasionally a false alarm, and naming why is pushback with evidence, not deference.
- **Over-cutting is the dangerous direction.** Removing a guard that still protects, or a comment that carries load-bearing intent, is a fresh wound, worse than the scar it replaced. When one candidate is a genuine judgement call, surface that one with its evidence rather than guess; do not turn the invocation into a questionnaire.

## The discipline: a deliberate end-of-work pass

When the work is done, go back before you hand it over and cut the marks of the struggle until only what is really needed remains. The result should read as if it were designed that way the first time. This is not optional polish: a fought-into-existence artifact spreads confusion and drift to everyone downstream. Cutting it saves tokens, compute, time, and money, and keeps quality high.

## The test of a scar

Name what this serves in the system as it is *today*. If the honest answer is "it went wrong here once" or "I built it before I understood the piece that already did this," it is scar tissue, not structure. A justified guard names a failure it still protects against today; a bug reproduction names the bug. Everything else is the receipt, not the bread.

## This is an umbrella; the enforcers already exist

Scar tissue is the shared principle behind rules you already have. Do not restate them here, apply them, and cut toward them:

- **Commit messages** describe the capability, not the git operation or the struggle. See the git-and-github / commit-discipline skills.
- **Shared artifacts** carry the user-visible change, not the toolchain or scaffolding that produced it. See the no-tooling-leak skill.
- **Tests** have their own species, absence-pinning and phrasing-pinning; see the testing-philosophy skill's "Scar tissue".
- **Dead code** is removed entirely when no longer needed; see programming-philosophy's "Cruft zero tolerance".
