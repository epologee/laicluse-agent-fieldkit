#!/usr/bin/env bats

load helpers

setup() {
  dibs_clear_ambient_identity
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  DIBS="$REPO_ROOT/packages/dibs/bin/dibs"
  NODE_BIN="$(command -v node)"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  DIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$DIR"
}

dibs() { "$NODE_BIN" "$DIBS" "$@"; }

hold_it() {
  dibs claim "$DIR" --pid $$ --agent claude --session sess-a --owner tab-1 --description "held for the self checks" --json >/dev/null
}

@test "check calls the holding session itself" {
  hold_it
  run dibs check "$DIR" --session sess-a --agent claude --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.self' <<< "$output")" = "true" ]
  [ "$(jq -r '.selfReason' <<< "$output")" = "session" ]
}

@test "check calls a resumed session with the same owner itself" {
  hold_it
  run dibs check "$DIR" --session sess-b --owner tab-1 --agent claude --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.self' <<< "$output")" = "true" ]
  [ "$(jq -r '.selfReason' <<< "$output")" = "owner" ]
}

@test "an owner shared with another agent is not itself" {
  hold_it
  run dibs check "$DIR" --session sess-b --owner tab-1 --agent codex --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.self' <<< "$output")" = "false" ]
}

@test "a stranger session is not itself" {
  hold_it
  run dibs check "$DIR" --session sess-z --owner tab-9 --agent claude --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.self' <<< "$output")" = "false" ]
}

@test "check without an identity says nothing about self" {
  hold_it
  run dibs check "$DIR" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.self' <<< "$output")" = "false" ]
  [ "$(jq -r '.selfReason' <<< "$output")" = "no-identity" ]
}
