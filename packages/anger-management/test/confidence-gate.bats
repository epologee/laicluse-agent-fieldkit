#!/usr/bin/env bats
# Contract tests for the anger-management diagnosis threshold.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  PROMPT="$REPO/packages/anger-management/bin/investigate.prompt.md"
  REPAIR="$REPO/packages/anger-management/skills/repair/SKILL.md"
}

@test "background investigation weighs the full history before fixing" {
  run grep -F "entire capture history" "$PROMPT"
  [ "$status" -eq 0 ]
  run grep -F "open captures" "$PROMPT"
  [ "$status" -eq 0 ]
  run grep -F "historical captures" "$PROMPT"
  [ "$status" -eq 0 ]
}

@test "background investigation requires confidence and mitigation level" {
  run grep -F "CONFIDENCE:" "$PROMPT"
  [ "$status" -eq 0 ]
  run grep -F "MITIGATION-LEVEL:" "$PROMPT"
  [ "$status" -eq 0 ]
  run grep -F "TARGET-SCOPE:" "$PROMPT"
  [ "$status" -eq 0 ]
  run grep -F "0.80" "$PROMPT"
  [ "$status" -eq 0 ]
}

@test "repair leaves the crumb trail open below the confidence threshold" {
  run grep -F "Confidence threshold" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "0.80" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "leave the captures open" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "MITIGATION-LEVEL" "$REPAIR"
  [ "$status" -eq 0 ]
}

@test "repair owns the mitigation decision before any self-improvement handoff" {
  run grep -F "do not hand the decision to self-improvement" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "do not delegate the diagnosis" "$REPAIR"
  [ "$status" -eq 0 ]
}

@test "repair carries the scope ladder before editing" {
  run grep -F "Scope ladder" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "cross-agent / cross-project" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "cross-project but stack-specific" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "one repo" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "one subproject" "$REPAIR"
  [ "$status" -eq 0 ]
}

@test "repair enforces source ownership before editing" {
  run grep -F "Source ownership rules" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "Do not patch runtime caches" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "rebuild generated adapters" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "marketplace repo" "$REPAIR"
  [ "$status" -eq 0 ]
}

@test "repair owns skill hook plugin authoring and pruning" {
  run grep -F "Skill, hook, and plugin authoring" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "sharpen an existing skill" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "hook reason text" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "Prune in the same pass" "$REPAIR"
  [ "$status" -eq 0 ]
}

@test "repair keeps captures open when the source is unknown" {
  run grep -F "If the source cannot be found" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "say exactly what you checked" "$REPAIR"
  [ "$status" -eq 0 ]
  run grep -F "leave the captures open" "$REPAIR"
  [ "$status" -eq 0 ]
}
