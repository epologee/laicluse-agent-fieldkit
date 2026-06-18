#!/usr/bin/env bats
# prompt-present.bats
# Verifies that drydry/SKILL.md carries the "Parallel orchestrations"
# formulation prompt (9th in audit mode step 2) and the matching 5th
# contrarian question in step 2.5.
#
# The duplication shape this prompt catches is two entry points to the
# same domain action orchestrating their own preflight stack above a
# shared leaf call (see fixture-orchestration-pair.md in this dir).
# That shape was missed by drydry audits up through v1.0.12 because no
# formulation prompt asked for it.

SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SKILL_MD="$REPO_ROOT/packages/drydry/skills/drydry/SKILL.md"

@test "SKILL.md exists" {
  [ -f "$SKILL_MD" ]
}

@test "audit step 2 contains a 'Parallel orchestrations' formulation prompt" {
  grep -F -- "**Parallel orchestrations.**" "$SKILL_MD"
}

@test "the prompt names multi-entry-point domain actions" {
  grep -E -- "entry point" "$SKILL_MD"
  grep -E -- "(AppIntent|controller-action|background job|store-method)" "$SKILL_MD"
}

@test "the prompt names a shared leaf-call as the convergence point" {
  grep -F -- "shared leaf" "$SKILL_MD"
}

@test "the prompt names an anti-pattern the calling session can reject" {
  # "a bit messy" is the rejected drift hypothesis; the prompt must
  # explicitly contrast it with sharper failure modes (auth asymmetry,
  # re-implemented cleanup, missed edge-case handling, week-by-week
  # drift) so the calling session does not file a shallow finding.
  grep -E -- "(auth.*asymmetr|asymmetr.*auth|re-implemented cleanup|missed edge-case|drift.*week)" "$SKILL_MD"
}

@test "the verifier example uses a ripgrep over the shared leaf name" {
  grep -E -- "rg .*shared.leaf|rg .*leaf-call" "$SKILL_MD"
}

@test "the minimum-evidence rule mentions every formulation prompt" {
  # The min-evidence sentence must cover all prompts, including the new
  # ninth one. Phrased generically ("every formulation prompt") so the
  # rule stays correct as prompts come and go.
  grep -E -- "every formulation prompt" "$SKILL_MD"
}

@test "step 2.5 contrarian brief contains a 5th question about orchestrations" {
  # The brief lives between a "find:" line and a "Return either" line.
  # The 5th item must mention orchestration parallels and reference rg
  # over a candidate leaf-call name.
  awk '/find:/{flag=1} /Return either/{flag=0} flag' "$SKILL_MD" \
    | grep -E -- "5\. \*\*Orchestration|5\. \*\*Parallel orchestration"
}

@test "step 2.5 5th question instructs the subagent to grep candidate leaf-call names" {
  awk '/find:/{flag=1} /Return either/{flag=0} flag' "$SKILL_MD" \
    | grep -E -- "rg.*leaf-call|leaf.call.*name"
}
