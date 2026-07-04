#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  PATTERN_MEMORY="$REPO_ROOT/packages/pattern-memory/bin/pattern-memory"
  NODE_BIN="$(command -v node)"
  ROOT="$BATS_TEST_TMPDIR/patterns"
}

run_pattern_memory() { "$NODE_BIN" "$PATTERN_MEMORY" "$@"; }

@test "init creates a standalone git-backed pattern store" {
  run run_pattern_memory init --root "$ROOT" --json
  [ "$status" -eq 0 ]
  [ -d "$ROOT/.git" ]
  [ -f "$ROOT/README.md" ]
  [ -f "$ROOT/SCHEMA.md" ]
  [ -f "$ROOT/INDEX.md" ]
  [ -f "$ROOT/patterns/example-map-like-canvas-interaction.md" ]
  echo "$output" | grep -q '"gitInitialized": true'
}

@test "search returns sanitized metadata and not private precedents" {
  run_pattern_memory init --root "$ROOT" > /dev/null
  perl -0pi -e 's/precedents: \[\]/precedents:\n  - private-app-token-that-must-not-print/' "$ROOT/patterns/example-map-like-canvas-interaction.md"
  run run_pattern_memory search "canvas zoom" --root "$ROOT"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "example-map-like-canvas-interaction"
  echo "$output" | grep -q "map-like canvas"
  ! echo "$output" | grep -q "private-app-token-that-must-not-print"
}

@test "validate fails when the generated index is stale" {
  run_pattern_memory init --root "$ROOT" > /dev/null
  printf '\nmanual drift\n' >> "$ROOT/INDEX.md"
  run run_pattern_memory validate --root "$ROOT"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "INDEX.md is stale"
}

@test "index --check passes after rebuild" {
  run_pattern_memory init --root "$ROOT" > /dev/null
  run_pattern_memory index --root "$ROOT" > /dev/null
  run run_pattern_memory index --root "$ROOT" --check
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "INDEX.md is current"
}

@test "init refuses a root nested inside a parent git worktree" {
  PROJECT="$BATS_TEST_TMPDIR/project"
  mkdir -p "$PROJECT"
  git -C "$PROJECT" init -q
  run run_pattern_memory init --root "$PROJECT/patterns"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "outside project git worktrees"
}
