---
name: council
user-invocable: true
description: >-
  Run a five-lens critical advisory review of an idea, decision, or plan.
effort: high
---

# Council of Five Advisors

Codex execution model: use native Codex subagents when the current session
exposes them. Reviewer/advisor agents are the "hand" layer: prefer the least
token-hungry Codex subagent model that can read the brief and return a
structured critique. Keep routing, grouping, conflict resolution, and final
synthesis on the current session model. Escalate a reviewer to the current
session model only when the cheaper model cannot handle the context or the
operator explicitly asks for maximum-depth review. If no subagent facility is
available, run the same protocol as clearly separated single-session passes and
state that fallback in the final review. Do not call Claude's
`gurus:sonnet-max`; that is the Claude runtime adapter for this plugin.

LLM assistants can be agreeable by default. This skill builds a counterweight. Five adversarial agents look at your question from five fundamentally different angles, read each other's work blind, and a chairman turns it into one verdict. No diplomacy, no "it depends". The lens is the answer.

Pattern based on Ole Lehmann's "board of advisors" skill, itself inspired by parallel LLM-critique patterns advocated by Andrej Karpathy (among others). Codex variant: advisors run on the cheapest adequate native Codex subagent layer when available, or as separate single-session passes when not.

## When to use

- A decision feels like "moet ik X of Y?"
- A plan feels too smooth, approved too quietly
- An idea has not yet been tested against someone who does not live inside your head
- The active agent's previous answer felt sycophantic

Not for code review; use `/gurus:software` for that. Not for purely factual questions; use `/ground` or `/inspire` for those.

**Cost and latency.** One council invocation runs eleven advisor jobs (five lenses, five peer reviews, one chairman). With native subagents the two review phases run in parallel; in fallback mode they run serially in the session and cost less isolation. Use it when the decision justifies the cost; for quick sanity checks `/gurus:software` or direct conversation is cheaper.

## The panel

| # | Advisor | Lens |
|---|---------|------|
| 1 | **Pre-mortem** | Assumes the idea fails and tries to prove it. Looks for kill scenarios, hidden single points of failure, the way this becomes a blunder six months from now. |
| 2 | **First-principles** | Strips away all assumptions and rebuilds the problem from scratch. Asks: what is the actual problem here, independent of the proposed solution? Ignores habit, precedent, "we have always done X". |
| 3 | **Opportunity-finder** | Looks for the bigger opportunity you are too close to see. If the proposal succeeds, what sits next to it that is ten times more valuable? What is the real destination this is a step toward? |
| 4 | **Stranger** | Has zero context about you, your history, your domain. Responds as an adult hearing this problem for the first time. Asks the naive questions insiders no longer dare to ask. |
| 5 | **Action** | Only cares about what you are actually going to do right now. Abstractions, principles, theories: irrelevant. Concrete next step, this week, measurable. If you cannot describe it in one sentence, you do not have a plan. |

Characteristic tension: Pre-mortem vs Opportunity-finder (risk vs opportunity), First-principles vs Stranger (deep context vs zero context), Action vs all others (movement vs analysis).

## Protocol

### Step 1: Establish the brief

Summarize the question, decision, or plan in at most 3 sentences of neutral prose. This is what every advisor receives. No leading language ("this great idea"), no defense. Raw situation.

When it is unclear what the exact question is: ask the user **one** clarifying question before dispatching. Five agents on an unclear brief is token waste.

### Step 2: Dispatch five advisors

When native Codex subagents are available, spawn five parallel advisor agents
on the cheapest adequate reviewer model. Do not use the current session model
for every advisor by default; that recreates Claude's expensive max-effort
shape without adding signal. When subagents are unavailable, run five separate
advisor passes in the main session and keep the outputs isolated until Step 3.
Lens-specific prompts, no mutual awareness.

**Prompt template per advisor** (fill in the lens-specific instruction):

```
You are advisor [NAME] in a board of advisors review. Your role is one specific lens, not a general verdict.

[LENS INSTRUCTION from the table below]

You do not know who the other advisors are. You know there are four other lenses, but not which ones. Your work will be anonymously peer-reviewed.

## The situation

[BRIEF from step 1]

## Output (follow this format exactly)

### Core observation
One paragraph of 3 to 5 sentences. What do you see from this lens that the person may not see?

### Specific points
Numbered list of 3 to 5 points. Per point:
- What: concrete, not abstract
- Why from this lens: explicitly anchored in your role
- What the person should do with this: actionable

### What you do NOT say
Name one thing other advisors will likely say that you deliberately leave alone, because it is not your lens.

No diplomacy. No "on one hand / on the other hand". Speak from your lens.
```

**Lens instructions:**

1. **Pre-mortem**: "You assume this idea is a blunder six months from now. Your task is to reconstruct that blunder before it happens. Find the failure modes that are still invisible: dependencies that break, assumptions that hold until they don't, the human dynamics that are going to rot. Write as if you are performing the autopsy."

2. **First-principles**: "You strip away every assumption: precedent, habit, 'we always do it this way', 'this is standard'. What are the actual constraints, independent of habit or precedent? What is the actual problem here? What if there were no existing solution: how would someone solve this from scratch?"

3. **Opportunity-finder**: "You look for the bigger opportunity this person is too close to see. If the proposal succeeds, what sits next to it that is ten times more valuable? If the proposal is a step: a step toward what? Which door opens? Which bigger destination becomes reachable?"

4. **Stranger**: "You have zero context about this person, this company, this domain. You are an adult hearing this problem for the first time. Ask the naive questions insiders no longer dare to ask. Why is X even a problem? What is being taken for granted? What jargon would you want explained?"

5. **Action**: "You only care about what this person is concretely going to do this week. Abstractions, principles, theories: not your problem. You want one sentence that reads: 'On Monday I will do X, with criterion Y, done by date Z.' If that sentence is missing, write one. If the proposal contains no first step, it is not a plan."

### Step 3: Anonymize

Collect the five responses. Assign each response a random letter A through E via shuffle. Keep the mapping `{lens-name: letter}` internally as a lookup table; the orchestrator uses it in Step 4 to exclude the own letter per advisor. The responses go to the next phase anonymously.

### Step 4: Blind peer review

Again run five peer-review jobs, preferably as parallel low-cost native Codex
subagents. For each advisor:

1. Look up in the mapping from Step 3 the letter assigned to this advisor. Call it `OWN`.
2. Compose the four letters from `{A, B, C, D, E} \ {OWN}`, in order.
3. Give the advisor the original brief plus exactly these four anonymized responses.
4. The advisor's own response is included under no letter whatsoever. This is the hardest rule of the peer phase; without explicit exclusion at least one advisor gets their own work back and anonymity is lost.

**Peer review prompt:**

Each advisor receives their own variant of this prompt, with their own letter from the mapping explicitly named as excluded. Concrete example: if Pre-mortem received letter C in step 3, the prompt for Pre-mortem contains only A, B, D, and E as reviews. The prompt states that mapping inline so the orchestrator does not have to rely on external state.

```
You are advisor [NAME] from a board of advisors. You previously wrote your own review from your lens, which is not included below: your letter in the anonymous shuffle was [OWN_LETTER] and it has been deliberately excluded. You are now reading the four remaining anonymous reviews and evaluating them.

## The original situation

[BRIEF]

## The four anonymous reviews (your own letter [OWN_LETTER] has been omitted)

### Review [LETTER_1]
[CONTENT]

### Review [LETTER_2]
[CONTENT]

### Review [LETTER_3]
[CONTENT]

### Review [LETTER_4]
[CONTENT]

## What you do

For each review answer three questions:

1. **Which lens do you think this is?** One word or short phrase.
2. **What is the strongest point here?** Not diplomatic; what makes this review add something.
3. **What is the weakest point here?** Also not diplomatic; where does this review fall apart.

Then: rank the four reviews from most to least valuable for the person receiving the advice. For your top-1 and your bottom-1 give one sentence of explanation.

No half-hearted judgments. If a review is weak, say so. Your judgment is anonymous: the peers do not know who you are.
```

### Step 5: Chairman synthesis

Run the chairman synthesis on the current session model unless the operator
explicitly asks to delegate it. The chairman is the head layer, not another
cheap reviewer pass. It receives:

- The original brief
- All five original (non-anonymous) reviews with lens name
- The five peer reviews (with rankings)
- The instruction below

**Chairman prompt:**

```
You are chairman of a board of advisors. Five advisors have examined this situation from their own lens, and then blind-reviewed each other's work. Your task is one verdict the person can use.

## The situation

[BRIEF]

## The five reviews

### Pre-mortem
[CONTENT]

### First-principles
[CONTENT]

### Opportunity-finder
[CONTENT]

### Stranger
[CONTENT]

### Action
[CONTENT]

## The peer reviews

[Five peer reviews with their rankings]

## What you deliver

### Convergence
Where do at least three of the five lenses agree? That is what the person can treat as settled; further validation is not needed here.

### Divergence
Where do lenses explicitly contradict each other? Which tension must the person resolve themselves, because no single lens has the answer alone?

### Verdict
Three to five sentences. Not a summary of the reviews; your own judgment as chairman after reading everything. Write it as you would say it to the person when they walk in to ask what they can do with all this.

### Concrete next step
One sentence. What does this person do on Monday? If no lens provided a concrete step, construct one based on the convergence.

No diplomacy. No "overall good points from everyone". Take a position.
```

### Step 6: Present

Present the chairman verdict prominently, followed by the five original reviews as collapsible sources. Format:

```
## Council Verdict

### Convergence
[From chairman synthesis]

### Divergence
[From chairman synthesis]

### Verdict
[From chairman synthesis]

### Concrete next step
[From chairman synthesis]

---

<details>
<summary>Pre-mortem</summary>

[Full review]

</details>

<details>
<summary>First-principles</summary>

[Full review]

</details>

[... etc for all five]

<details>
<summary>Peer review ranking</summary>

Per advisor (by name): which review they chose as top-1 and bottom-1 (letter and corresponding lens name from the mapping), plus the one-sentence explanation per choice. No aggregation or ranking score; the individual judgments are the signal.

</details>
```

## Rules

- **Five agents, not four or six.** The lenses are chosen for mutual tension. Deviating weakens the signal.
- **No cross-vendor by default.** Run on the current Codex runtime. Do not shell out to Claude, Gemini, Grok, or another vendor unless the operator explicitly asks for that.
- **Dispatch in parallel where possible.** With native subagents, Step 2 and Step 4 are parallel. Serial fallback is acceptable only when no subagent facility is available.
- **Anonymization is mandatory.** Peer review without anonymization becomes hierarchy review ("Pre-mortem says X, they are always right"). The lens on the response must be hidden during review.
- **Chairman is not an average.** The verdict may diverge from what the majority of lenses said when the chairman sees a stronger argument in a minority lens.
- **The person decides, not the council.** Concrete next step is a proposal, not an order. The user says "doe het" or "niet dit, liever X".
