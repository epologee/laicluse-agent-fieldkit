---
name: verify
description: Evidence discipline for the rover. Writes Done criteria so the mission has an actual endpoint, then gathers evidence against each criterion (run the code, screenshot the UI, curl the endpoint, query the state) and reports what is proven, unverified, or failed.
user-invocable: true
argument-hint: "[--propose <loop-file> | <loop-file> | free text]"
effort: high
---

# Autonomous Verify

Evidence discipline for autonomous work. The operator is not watching, so every claim of progress or completion has to rest on something the operator could check without being present.

Two disciplines, one skill:

1. **Write Done criteria up front.** Before the rover starts building, it commits to what "done" looks like in concrete terms.
2. **Gather evidence against those criteria.** Actively verify each criterion by running, observing, or measuring. Report what is proven, what is unverified, what failed.

## Why this matters for an autonomous rover

Without Done criteria, the rover has no endpoint. It stops when it is tired, when tests happen to be green, or when the phase machine nudges it along. None of that is "finished." The operator reading the loop file later has no way to audit whether the work actually matches the original goal.

Without active evidence, the rover coasts on proxies: "CI green," "the code compiles," "the test file exists." None of these prove the feature does what the user asked for. Proxies are the autonomous-work equivalent of driving at night without headlights.

## Mode 1: propose Done criteria (`--propose`)

Invocation: `/rover:verify --propose <loop-file>` or called by rover at end of SURVEY.

1. Read the loop file's `## Dispatch`, `## Context`, and `## Plan` sections. Dispatch is the source of truth; Context is interpretation; Plan is the proposed deliverable.
2. **Plan-vs-Dispatch check (mandatory).** Compare the action verbs in Dispatch against the deliverables described in Plan. If Dispatch contains action verbs (build, ship, fix, port, install, deliver, enable, make work, implement) and the Plan only describes producing research, documentation, or analysis without naming the actual implementation as the deliverable, refuse to generate Done criteria. Log the mismatch, send the rover back to SURVEY to rewrite the Plan so it includes the actual implementation, and only then return to Done-criteria generation. The rover does not ask the operator to confirm research-only scope; the Dispatch's verbs are the answer. Always compare against Dispatch, never against Context alone; Context can itself have shrunk the dispatch.
3. Derive 3 to 10 criteria. Each criterion is:
   - **Concrete:** names a specific file, command, endpoint, UI element, or observable state
   - **Observable:** you can run, see, or measure it, not just "know" it
   - **Binary:** either met or not met, not a spectrum
   - **Aligned with the Dispatch's action verbs:** if Dispatch says "make X work on Windows," at least one criterion must directly assert that X works on Windows. Doc-quality criteria alone (file exists, word count is high enough, formatting passes a lint) do not satisfy an action-verb dispatch.
4. Write the criteria into the loop file under `## Done criteria` (create the section if missing).

### Good vs bad criteria

| Bad | Good |
|-----|------|
| "The settings page works" | "`GET /settings` returns HTTP 200 when logged in as a user" |
| "Form validation is correct" | "Submitting the form with an empty name shows an inline error next to the name field, no DB write happens" |
| "Fast enough" | "`/settings` first-paint under 200ms at p95 on the staging box" |
| "Tests pass" | "`bin/rspec spec/settings_spec.rb` exits 0 with 12 examples, 0 failures" |
| "Looks good" | "Screenshot at 1440x900 shows form below header, no horizontal scroll, no overlap with nav" |

Vague criteria are how missions drift. The rover catches this up front by insisting on sharp ones.

## Mode 2: gather evidence (default)

Invocation: `/rover:verify <loop-file>`, or bare `/rover:verify` in a session where a loop file is obvious, or called by rover at end of INSPECT.

1. Read the `## Done criteria` section.
2. For each criterion, determine the verification tactic:

| Criterion type | Tactic | Evidence |
|----------------|--------|----------|
| Code runs | Execute it (unit test, script, CLI) | Command output, exit code |
| HTTP endpoint | `curl -sSv` with expected inputs | Status code, response body |
| UI element | Navigate and screenshot | PNG path + described observation |
| UI state change | Before and after screenshots | Two PNGs, described diff |
| DB mutation | Query the DB after the action | Row count, specific field values |
| File on disk | `ls` / `stat` / `cat` | Path + relevant content |
| Third-party integration | Trigger it, inspect the other side | Log entry, API response, webhook payload |
| Logged behavior | Run, grep the log | Matched log line with timestamp |

3. For each criterion, attach the evidence under its row in the loop file. Format:

```markdown
## Done criteria

- [x] `GET /settings` returns 200 when logged in
      Evidence: `curl -s -o /dev/null -w "%{http_code}" http://app.test/settings` → 200 at 10:14
- [x] Submitting empty name shows inline error
      Evidence: screenshot `/tmp/settings-empty-name.png`, error visible next to name field
- [ ] p95 first-paint under 200ms
      Unverified: no staging box available in dev. Ran locally only: 180ms average over 5 runs.
- [ ] Tests pass
      Failed: `bin/rspec` → 12 examples, 1 failure. See log.
```

4. Report a summary:
   - Criteria met with evidence
   - Criteria unverified (why, what would be needed to verify)
   - Criteria failed (what the evidence showed, next DRIVE target)

## Mode 3: standalone use

Outside a rover session, `/rover:verify "free text describing the work"` lets a user ask "did I really finish what I claimed?" for any recent work. The skill:

1. Asks for or infers a short Done-criteria list from the free text and the recent diff
2. Gathers evidence
3. Reports

This is useful after any non-trivial task, not just autonomous loops.

## Proxies are not verification

The rover is tempted by proxies because they are cheaper than real evidence. Reject them:

| Proxy | Why it fails | Real verification |
|-------|--------------|-------------------|
| "CI is green" | Tests a file I cannot run | Run the relevant scenario locally |
| "The code compiles" | Syntax check, not behavior | Execute the code path |
| "The test file exists" | File existence, not passage | Run the test, see it pass |
| "Curl returns 200" | Status code, not content | Assert on response body |
| "The feature should work" | Unchecked hypothesis | Run the feature end-to-end |
| "I followed the pattern" | Pattern imitation, not correctness | Prove this instance behaves |
| "No errors in the console" | Absence is not presence | Confirm the positive outcome happened |
| "The pipeline works on one example, so the matrix criterion is met" | Single-instance evidence does not satisfy a quantitative criterion | Run the full matrix, produce every output the criterion names, list each one |
| "The simulator boot loop would burn context, so I tick the criterion now" | Cost is a fate-2 candidate for findings; Done criteria have no fate-2 path | Either produce the full evidence, or mark `unverified: <route the operator needs to take>` and stay in DRIVE |

When a proxy is the only thing available, label it: `unverified, only proxy evidence: <X>`. Honesty beats a false green.

## When verification is genuinely impossible

Sometimes a criterion cannot be verified with available tools:

- Production-only behavior (auth, third-party services, real user load)
- Visual checks in a headless environment without a browser
- Timing-sensitive measurements without a stable baseline
- Behaviors that only manifest under rare conditions

Mark these `unverified: <specific reason>` in the Done criteria. Do not claim them met. The rover does not decide on its own that an unverified criterion is "acceptable" and push on. The rover also does not route unverified criteria to the operator; there is no operator-accept path inside an autonomous mission. The rover's job is to make every criterion verifiable and produce the evidence.

Done criteria are not findings. The three-fates rubric from `rover` applies to findings raised by pride, gurus, end-user, and technical passes; it does not apply here. Done criteria are the mission's destination, not weights along the way. There is no fate-2 cost-value-skip path for a Done criterion: every criterion is either met with evidence, or unverified (which blocks STOW until the rover produces a verification route). Fate 3 (reject-as-non-issue) does not apply either: a Done criterion was committed to during SURVEY and proves the mission delivered what the Dispatch asked for, so it cannot retroactively be a non-issue.

### Unverified blocks STOW, not INSPECT activity

When INSPECT runs, any criterion still marked `unverified` blocks the transition from INSPECT to STOW. It does not freeze the rover. Other criteria keep verifying, other pride findings keep getting fixed, other parallel work continues; the blocker is only on closing out the mission. The rover's legitimate move on the unverified item is:

1. **Return to DRIVE and provide the evidence.** If the direct evidence is out of reach with the current setup, change the setup. Stand up a local harness, seed a test database, mock the third-party with a fixture that exercises the real code path, run a headless browser under Playwright to screenshot a UI that was previously "headless-only", instrument the code to emit a log line the criterion can assert against. Log each attempt explicitly. "I could not run the staging test" is not acceptable until "I tried A, B, and C, and here is why each failed, so I built D, which produced the evidence" has been logged. Unverified is not a final state for the rover; it is an assignment back to DRIVE.

The rover **never** upgrades `unverified` to a tick on its own, never silently drops a criterion from the list, never reasons "in de praktijk zal dit wel werken" / "in practice this should be fine" to close it out, and never asks the operator to accept an unverified criterion. Those moves are the exact corner-cutting this discipline exists to prevent. If you catch yourself typing "accepting unverified" or "acceptable given context" into the loop file, revert and go back to DRIVE to produce the evidence.

## Anti-patterns

| Thought | What it actually is |
|---------|---------------------|
| "I'll verify at the end" | No you will not, you will run out of steam. Verify per change. |
| "This is too obvious to verify" | Obvious things fail too. 30 seconds of evidence beats 5 minutes of debugging later. |
| "Verification would take forever" | If verifying the mission takes longer than doing it, the mission is probably too big. Split. |
| "The tests cover it" | Tests are a form of verification, but rarely the full criterion. What did the user see? |
| "I already checked" | Show the evidence. If you cannot cite it, you did not check. |

## Quantitative criteria need quantitative evidence

A Done criterion that names a count or a matrix (`bin/capture-shots produces 40 PNGs`, `all 10 scenes render`, `both locales receive a preview`, `every endpoint returns 200`) is met only when every named instance is produced and listed. Proving the mechanism on one instance proves the mechanism; it does not prove the criterion. The two are not the same.

The temptation is structural: when the matrix is wide (40 outputs, hours of simulator boots, a long sweep) and the mechanism is verified on one example, the rover wants to upgrade "mechanism proven" to "criterion met" because the marginal cost of the remaining N-1 runs feels disproportionate to the marginal information. That trade is wrong twice. First, the criterion was committed to during SURVEY precisely because the matrix matters; the rover does not get to redefine the criterion at INSPECT to be the part it already finished. Second, the rover routinely discovers that the mechanism works on the first instance but fails on the second or third (a scene flag the schema does not expose, a locale-specific font fallback, a device-class path the mechanism hardcoded). The matrix runs are the discovery surface, not the formality.

If the matrix is genuinely too expensive to run in this session, the move is `unverified: requires <concrete-route>` with a route the operator could take, not a tick. Unverified blocks STOW, so the mission stays open and the operator sees the gap in the next read of the loop file. A ticked criterion that was not actually verified is worse than an unverified one: the operator stops looking, the gap rots, and the next reader of the communiqué believes a lie.

Red flag: when typing a verify-pass log entry, watch for the construction "running N more iterations would exceed prudent context; the one-scene verification proves the pipeline works." That sentence shape is the proxy this section exists to prevent. The correct continuation is `unverified: needs full matrix run via bin/X`. Then stay in DRIVE until the matrix evidence exists, or transition out only because the operator's environment legitimately blocks the run and the unverified state is documented for them to pick up.

## Interaction with other skills

- **`decide`** picks which path to take; `verify` proves the chosen path worked. Complementary.
- **`pride`** asks "would the user hate this?" (contrarian, smell-finding); `verify` asks "did this do the thing?" (evidence-gathering). Different questions, no overlap. The rover runs both before declaring done.
- **`rover`** invokes `verify --propose` at end of SURVEY and `verify` (default) at end of INSPECT. A rover mission without Done criteria is not started; a rover mission without ticked criteria is not finished.
