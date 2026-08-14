---
name: scar-tissue
description: >-
  Use when corrective work leaves superseded residue in an artifact, or before handoff. Remove scar tissue while preserving anything with a current responsibility or reader.
---

# Scar tissue

Keep the result, not the log of every failed attempt to build it.

Scar tissue is residue from the fixing rather than structure the current system needs: a correction layered over superseded content, a temporary test whose subject is gone, a migration wrapper without a current consumer, or prose and commit history that narrate the struggle instead of the result.

## Catch it without creating ceremony

Repeated edits are normal. The trigger is not an edit count; it is an old and a new intention surviving together in the current artifact. When that happens, inspect the affected artifact and its directly related changes, then consolidate them into the form they would have had if the final decision were known at the start.

Working plans, task notes, unreleased docs, and uncommitted changes are edited in place. Append a correction only when an external reader depends on seeing the history, such as in published changelogs, released documentation, or pushed commits.

Before handoff, ask what each suspicious layer serves today. Remove duplicated, superseded, or unowned material. Keep guards against a current failure mode, compatibility paths with a named current consumer, published history, and tests that assert live behavior. Repository-specific Git, test, migration, and task-tracking rules determine how the host performs that review.

## Explicit invocation

The skill name is a noun phrase, not a literal search request. Operators often enter `$house-rules:scar-tissue` through autocomplete to ask for residue in the artifact currently under discussion. Resolve that artifact from context and inspect it; do not search for the literal words `scar-tissue` unless those words themselves were identified as the problem.

Being invoked points at a suspected scar, not a blank cheque for broad cleanup. Read the flagged artifact first. Cut a clear scar without asking, preserve something load-bearing and name its current responsibility, and surface only genuine judgment calls where removal could damage current behavior.

## Migration without residue

A migration ends with one canonical implementation at the destination. Apply the owning migration or deprecation protocol when external consumers require a transition; do not invent a forwarding path merely because the old path once existed.
