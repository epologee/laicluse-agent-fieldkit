---
name: rethink
description: >-
  Reconstruct a drifting project's purpose, boundaries, and promises from evidence, then write a governing manifesto before more local fixes.
---

# Rethink

Return a project to first principles when repeated local fixes no longer add up to a coherent product. Reconstruct what the system is trying to be from its documentary, technical, operational, and lived history; then turn that understanding into a manifesto that can guide future decisions without freezing today's implementation.

This is architecture archaeology and normative design. It is not backlog refinement, implementation planning, or an invitation to rewrite the system while investigating it.

## When to use

Use this workflow when any of these signals recur:

- The same problem has been reported or patched more than once.
- A claimed fix covers one touchpoint while equivalent paths keep failing.
- Work is implemented but not integrated, activated, deployed, or verified.
- Responsibilities drift between repositories, services, channels, or agents.
- The product's original purpose is no longer an effective design constraint.
- The operator asks for a first-principles rethink, an ecosystem review, or a manifesto.

Do not use it for an isolated bug with a clear owner and boundary. Do not turn its findings into implementation work unless that is separately in scope.

## Operating contract

- **Evidence before doctrine.** Do not draft the manifesto from the current conversation or README alone.
- **Whole outcome before local mechanism.** Follow each promise across every touchpoint that claims to deliver it.
- **Purpose before practice.** Preserve the durable reason for the system; treat current repositories, protocols, agents, and workflows as replaceable evidence, not eternal structure.
- **Explicit uncertainty.** Distinguish what sources prove, what they suggest, and what remains a normative choice for the operator.
- **Host-owned capabilities.** Arrange research, independent review, interviewing, and durable communication through the active host's available tools. Do not require a particular agent, plugin, interview UI, or transport.
- **No hidden implementation.** Documentation edits requested as artifacts are in scope; product fixes discovered during archaeology are findings unless separately authorized.

## Workflow

### 1. Establish the inquiry

State the system or ecosystem in scope, the symptoms that triggered the rethink, and the artifact that should result. Record the observed performance gap: what the project promises, what repeatedly happens instead, and why another local patch would be insufficient.

Build a source map before drawing conclusions. Include every relevant repository and deployed component, plus authorized sources that preserve intent or lived experience.

### 2. Reconstruct the project from evidence

Inspect the evidence deeply enough to explain both intended and actual behavior:

- Original design documents, architecture notes, READMEs, ADRs, and vocabulary.
- Current code boundaries, entry points, shared abstractions, integration paths, and repository graph.
- Git history, especially reversals, repeated fixes, migrations, and churn around the same concept.
- Tests and verification contracts: what they prove, and which user-visible promises they do not prove.
- Runtime state, queues, buses, logs, receipts, deployment records, and recovery behavior.
- Issues, transcripts, review discussions, support conversations, and explicit frustration signals.
- Authorized private notes or vaults when they contain relevant intent; keep private facts out of shareable artifacts unless explicitly cleared.

Search by concept and promise, not only by the latest symptom or current identifier. When several repositories participate in one outcome, trace the complete path across them. Treat a green local test as evidence about that boundary only.

Maintain a compact evidence ledger with four labels: `observed`, `claimed`, `inferred`, and `undecided`. Attach source locations to consequential findings so later reviewers can challenge the reconstruction without repeating the whole excavation.

### 3. Find the systemic pattern

Triangulate three views:

1. **Original intent:** what problem the project set out to solve and which qualities were meant to distinguish it.
2. **Current system:** where responsibilities, authority, state, and verification actually live now.
3. **Lived experience:** where operators and users repeatedly lose trust, time, context, or control.

Cluster incidents by violated promise rather than by file or ticket. Drill from recurring symptoms to missing meanings, ownership, authority, boundaries, or evidence. Call out places where the same responsibility is implemented in parallel, where one repository compensates for another's responsibility, and where a local success claim is mistaken for an integrated outcome.

Do not assume the original design is right because it is original, or the current implementation is right because it runs. Preserve a decision only when it still serves the reconstructed purpose.

### 4. Draft the manifesto

Write a short, aspirational design document at the level future decisions can consult. It should normally contain:

- **Purpose:** why the system exists.
- **Promise:** what participants may rely on across boundaries and failures.
- **Principles:** durable design commitments stated positively.
- **Boundaries and non-goals:** responsibilities the system must not absorb.
- **Decision test:** a small set of questions for judging future designs.
- **Ambition:** the future the project is trying to make possible.

Write principles that can survive a change of language, framework, model, repository layout, or interface. Make them concrete enough to rule out a tempting but wrong design. If a statement merely describes today's mechanism, move it to technical documentation. If it cannot change a design decision, sharpen or remove it.

Keep exact lifecycle terms, schemas, state transitions, and implementation contracts in a separate vocabulary or reference document when precision is necessary. The manifesto may link to that document without becoming it.

### 5. Stress-test the abstraction level

Arrange an independent review by a capable peer with the complete draft and evidence synthesis. Ask the reviewer to look specifically for:

- Principles too vague to reject any design.
- Mechanisms fossilized as values.
- Missing responsibility, authority, or discharge conditions.
- Promises that no observable receipt or verifier could establish.
- Contradictions between principles, vocabulary, and non-goals.
- Private or tool-specific context leaking into a shareable artifact.

Resolve factual findings directly. Present genuine normative disagreements to the operator rather than averaging them into bland prose.

### 6. Interview the operator

Ask only questions whose answers are normative and cannot be recovered from the evidence. Conduct the interview one question at a time: briefly state the tension, recommend one answer, explain its consequence, and then ask for the decision.

Use a durable interview capability when it demonstrably returns answers to the same live work context. If it loses context, leaks transport internals, or fails to deliver replies, stop using it and continue in the current interactive channel. The interview mechanism is replaceable; continuity of the inquiry is not.

Revise after each answer so later questions use the new model. Re-run independent review when an answer materially changes a boundary or principle.

### 7. Deliver a governing artifact

Before declaring the rethink complete, verify that:

- Every triggering symptom maps to at least one principle, boundary, or explicit unresolved decision.
- Every principle is supported by the reconstructed purpose and can influence a real design choice.
- The manifesto does not prescribe current tooling, topology, workflow, or vendor choices.
- Domain work remains with domain participants; coordination does not silently become execution.
- Terms have one meaning across the manifesto and any vocabulary document.
- The final artifact is shareable, internally coherent, and committed through the project's normal integration path when repository changes were requested.

Deliver the manifesto, its companion vocabulary when needed, and a concise evidence synthesis that explains the rethink's major conclusions. Keep implementation findings separate so the manifesto governs future work instead of masquerading as a task list.

## Failure modes

- Drafting values after reading only the current README.
- Writing a prettier architecture description instead of a statement of purpose and boundaries.
- Turning every historical incident into a technical rule.
- Treating repository count, agent count, or vertical slices as equivalent concepts.
- Letting the coordinating system absorb refinement or implementation responsibilities.
- Asking the operator discoverable factual questions instead of doing the archaeology.
- Producing a manifesto that celebrates aspirations but cannot reject a bad design.
- Ending with an uncommitted document, an unverified integration, or a claim that publication succeeded without checking the receiving boundary.
