---
name: stop
description: >-
  Stop a rover mission and send home its final report, open gates, and not-done list.
---

# Autonomy Stop

End a loop on purpose, with a recap.

## When to use

- The work is done and the operator is ready to review
- The loop is in a broken state (wrong branch, wrong scope, wrong file) and restarting cleanly is easier than fixing
- The operator wants the loop off

## What it does

1. Locate the loop file. If an argument is given, use it. If not, list `.autonomous/*.md` candidates in the conversation and ask which to stop. The ask is only correct when stop was operator-invoked (see step 4 on attribution); when stop was rover-invoked the args carry the loop-file path already.
2. Read `continuation` and `continuation_handle` from the file. If the active host exposes a way to cancel that continuation, use it. If the host does not expose cancellation, or the loop file only has legacy cron metadata, do not call runtime-specific helpers directly from rover; mark the loop file as stopped and proceed. Legacy loop files may still contain `cron_job_id`; preserve it as history unless the active host owns and can cancel that exact handle through its own continuation mechanism.
3. Set `continuation: stopped` in the loop file. If a legacy `cron_job_id` field exists, set `legacy_cron_job_id: stopped` or `cron_job_id: stopped` consistently with the file's existing field name.
4. Append a final log entry with a timestamp from `date +%H:%M`. Attribute the stop correctly based on caller:
   - When the operator typed `/rover:stop` (the slash command, with or without a file path argument): `[HH:MM] Stopped by operator. Phase at stop: <PHASE>.`
   - When another skill invoked `stop` via the Skill tool from inside the loop (the rover's STANDBY entry-check finding zero listeners, an INSPECT pass concluding mission-complete, or any other autonomous trigger that calls into this skill): `[HH:MM] Stopped autonomously (<trigger>). Phase at stop: <PHASE>.` where `<trigger>` names the autonomous reason concretely ("zero listeners after STANDBY entry-check", "INSPECT-complete handoff", "watch_checks cap" from the host continuation path, and so on).
   - The default attribution is "operator" only when the caller is genuinely the operator. The slash-command invocation is the operator; an autonomous loop calling this skill from inside its own phase machine is the rover. Misattributing a rover-invoked stop as "by user" makes the log read as if the operator pulled the plug when the rover actually closed itself out, which the operator will spot and ask about (this distinction matters; do not collapse it).
5. Produce a communiqué to the conversation. The communiqué is itself a rover artefact, so run `pride` on the drafted text before transmitting it (log the pride findings in the loop file, fix them or reject them with concrete evidence of non-issue via the second-pass gate, then send the final version).

   Not a data dump, not a form with six bullet-headers. A **mission report** written as prose: the operator comes back to the TUI and wants to read a story of the traverse, not grep through section titles. The goal is that after reading, the operator knows where the rover went, what it found, what it changed along the way, and what the next move is, without having to re-read the loop file or ask "are you proud of this?"

   ### Length matches the mission

   Compute mission duration from the Log: first timestamped entry to the stop timestamp. Scale the communiqué by that duration, with the shape of the story preserved in each size:

   | Mission duration | Traverse prose | Conclusion | Next actions |
   |------------------|----------------|------------|--------------|
   | `< 2 hours` | at least 1 paragraph per landmark | 1 paragraph | Bulleted |
   | `2h ≤ duration < 12h` | at least 1 paragraph per landmark, plus a scene-setting opener | 1 to 2 paragraphs | Bulleted |
   | `≥ 12 hours` | at least 1 paragraph per landmark, sub-landmarks for multi-beat ones | 2 to 3 paragraphs | Bulleted |

   The shape rule is "at least one paragraph per landmark" at every duration; the table sets the expected minimum context beyond that. A short mission with a long communiqué is padding; a long mission that genuinely had three landmark beats does not need ten paragraphs of prose invented to fill a range.

   ### Language

   The communiqué is written in the language of the Dispatch block. Whatever language the operator dispatched the rover in, the communiqué matches that. Mixed-language dispatches (prose in one language with technical terms in another) follow the dominant prose language of the Dispatch, not of the Context, Plan, or Log (those may have drifted into another language during execution). The rover does not translate the work; it writes the report in the same language the operator asked the question in, so the operator does not context-switch between briefing and report. Operator override takes precedence: if a later `## Input` entry names a language (e.g. "report in English", or the same instruction in any other operator language), the rover follows that.

   ### Shape of the communiqué

   **Traverse (prose).** The journey in chronological order, told as landmarks and what the rover did at each: the initial read of the terrain during SURVEY, the decision points that the Decision Audit Trail captured, the pivots where an assumption broke and the rover re-planned (mark these explicitly, they are the most interesting parts of the story), the INSPECT passes and what they caught, the STOW cleanup. Decision entries from the audit trail are woven into the prose as supporting detail, not listed separately. Pride findings and their fates belong in-line: "the review surfaced X, which turned out to be Y, and was fixed in commit Z" reads better than a dedicated review-results section. Name the substance of each finding and how it resolved, not pride's internal mechanics. Quoting gate names or counting rejects hides the only question that matters (whether the rover is actually proud of the work) behind bureaucratic compliance. Pull concrete artefacts in where they carry the story: commit SHAs for landmark changes, file paths for the hardest edits, command outputs that changed the rover's mind. Avoid the temptation to summarise; summaries are what the operator is trying to avoid by reading this at all.

   **Qualitative conclusion (prose).** One or more paragraphs, length-scaled, that give the operator a read on how the mission actually went. What is the rover confident about, and what is it less confident about and why? Where was the work easy, where was it hard, and did the final form address the hard parts cleanly or did compromises land? Was the original Dispatch the right framing, in hindsight? This is the section where the operator finds "am I proud of this?" answered in advance; the rover writes an honest self-assessment here so the operator does not have to extract one.

   `pride`'s category 8 (effort-and-scope reflex) applies to the conclusion paragraph verbatim. Any wording that the reflex-pattern detector flags means the rover is not in a state to stop. Transition back to DRIVE, close each item, then re-draft the communiqué.

   **Not done.** Mandatory, even when it is empty. The expectation for any mission that runs to `stop` is that the section is empty: the rover does not defer, postpone, plan, or down-scope, so every finding was fixed or rejected-with-evidence during INSPECT. If the section is genuinely empty, write the literal sentence `Nothing remains. Every Done criterion is ticked, every pride finding resolved.` and only that sentence. If the section is non-empty, the rover is not in a state to stop: every bullet that would have gone here is a finding the rover owes a DRIVE cycle. Transition back to DRIVE, close each item, re-run INSPECT, re-draft the communiqué. The only exception is a pride finding that was rejected with concrete evidence of non-issue via the second-pass gate; record each such reject as a single bullet naming the finding, the evidence, and the second-pass confirmation.

   **Next actions for you.** A bulleted list of concrete operator moves, each a one-liner. These are **only** external-action gates the rover is structurally forbidden from taking: push, merge, deploy, notify a stakeholder outside the rover's channels. Never a decision, never a review question, never a scope check. The rover decided everything it was going to decide inside the mission; there are no pending questions waiting for operator judgement. **Never** "try it out", "verify it works", "test the feature", "check that the UI looks right", "see if it does what you wanted". The rover has already done verification during INSPECT; asking the operator to redo that work duplicates effort and contradicts the Done-criteria evidence.

   **Audit per-leg reachability before bouncing a multi-step setup to the operator.** A surprisingly common failure mode: the rover lists "log in to service X, copy the auth token, set it in the secret store" as a next-action because the auth model "needs a human", without checking whether each individual leg is reachable through tooling the rover already loaded. Email-code login: the code arrives in an inbox the rover can read via Gmail/IMAP MCPs. Browser-only login: drivable with playwright or the Chrome MCP (often already proven reachable during slice 0 discovery). OAuth callback to a localhost port: catchable with a transient HTTP listener. Secret-write: storing a secret via the local secret-manager CLI is a step the rover routinely runs. MFA via TOTP: readable from a known secret store. The pattern to catch is assuming "X needs a human" without auditing each sub-step against loaded MCP tools, skills, and binaries. Before listing a setup flow as a next-action, walk each leg: (1) what tooling would execute this leg? (2) is that tooling actually reachable in this session? (3) are the required inputs (email address, account handle, etc.) retrievable from a store the rover can read? If every leg passes, execute the flow during INSPECT or DRIVE, do not defer it to the communiqué. Only when at least one leg genuinely lands on a human-only channel (physical hardware key tap, a phone notification, a person-in-the-loop approval) does the flow belong in next-actions. Specific red flag: typing "log in to ..., copy ..., set ... in the secret store" as a bullet without having first run a reachability audit across each verb. That bullet shape is the failure mode by sight; revert and execute.

   **Verify each gate is actually applicable before listing it.** A gate that does not apply to this repo is noise, not guidance, and the operator reads the next-actions list as if every line is real. Run the relevant probe before each candidate bullet:

   - **`git push -u origin <branch>`**: only list if `git remote -v` shows at least one remote. No remote, no push line. A repo cloned locally without a publish target is a local-only repo by intent. The probe also rules in or out the implicit "create a remote first": that is a setup decision the operator already made when they did not configure one, so the rover does not propose it.
   - **`ansible-playbook ... -l <host>`**: only list if the role exists in this repo (`ls ansible/playbook-*.yml` matches the relevant playbook) AND the inventory has the targeted host (`grep -l <host> ansible/inventory.yml || ansible-inventory --list 2>/dev/null`). Otherwise the deploy bullet refers to a playbook that is not actually present.
   - **`gh pr create`** or merge: only list if `gh repo view` succeeds AND there is a remote to push the branch to first.
   - **External notifications, deploys, or any other gate** named in the mission: only list when the underlying tooling is reachable (binary on PATH, credentials present in the operator's known stores, target host alive). When the tooling is missing, the next action is operator-side setup, not the gate itself.

   When a gate would have been listed but the probe ruled it out, write a single sentence in the conclusion paragraph naming what is missing ("no `origin` remote configured; the branch lives only locally"). That sentence replaces the bullet; it does not get smuggled back in as a different bullet.

   Close the communiqué with the loop file path and the phase at stop, on its own line, so the operator can find the full log if they want it.
6. If `notify_on_done` is set in the loop file, check installation via the `has_skill` helper. If installed, invoke it with the recap. If missing, log a loud line: `[HH:MM] Stop: notify_on_done=<X> is not installed, skipping notification.`

## What it does not do

- Does not delete the loop file. The file is history.
- Does not push, merge, or clean up commits. Those require explicit instructions.
- Does not restart the loop. Use `/rover:rover` for that.

## After stop

The continuation is stopped or marked stopped. The loop file stays. Any future `/rover:rover <file>` will bring it back with a fresh host continuation when one is available.
