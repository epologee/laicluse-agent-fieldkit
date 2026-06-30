#!/usr/bin/env bats
# Contract tests for bin/dibs release-all: release every lock this session holds
# across all directories in one sweep, keyed by holder identity (pid/session/owner).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  DIBS="$REPO_ROOT/packages/dibs/bin/dibs"
  NODE_BIN="$(command -v node)"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  A="$BATS_TEST_TMPDIR/a"
  B="$BATS_TEST_TMPDIR/b"
  C="$BATS_TEST_TMPDIR/c"
  mkdir -p "$A" "$B" "$C"
}

dibs() { "$NODE_BIN" "$DIBS" "$@"; }
lockcount() { ls "$LAICLUSE_HOME/locks" 2>/dev/null | wc -l | tr -d ' '; }

@test "release-all by pid removes every lock that pid holds across directories" {
  dibs claim "$A" --pid $$ --agent claude --json >/dev/null
  dibs claim "$B" --pid $$ --agent claude --json >/dev/null
  [ "$(lockcount)" -eq 2 ]
  run dibs release-all --pid $$
  [ "$status" -eq 0 ]
  [ "$(lockcount)" -eq 0 ]
}

@test "release-all by pid leaves locks held by a different pid intact" {
  dibs claim "$A" --pid $$ --agent claude --json >/dev/null
  dibs claim "$C" --pid 999999 --agent codex --json >/dev/null
  run dibs release-all --pid $$
  [ "$status" -eq 0 ]
  [ "$(lockcount)" -eq 1 ]
}

@test "release-all with no selector is an error and removes nothing" {
  dibs claim "$A" --pid $$ --agent claude --json >/dev/null
  run dibs release-all
  [ "$status" -ne 0 ]
  [ "$(lockcount)" -eq 1 ]
}

@test "release-all matching nothing succeeds with a zero count" {
  run dibs release-all --pid $$ --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"count": 0'
}

@test "release-all --json reports the released count and paths" {
  dibs claim "$A" --pid $$ --agent claude --json >/dev/null
  dibs claim "$B" --pid $$ --agent claude --json >/dev/null
  run dibs release-all --pid $$ --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "released-all"'
  echo "$output" | grep -q '"count": 2'
}

@test "release-all by owner and agent matches locks regardless of pid" {
  dibs claim "$A" --pid 111111 --agent codex --owner tab-7 --json >/dev/null
  dibs claim "$B" --pid 222222 --agent codex --owner tab-7 --json >/dev/null
  dibs claim "$C" --pid 333333 --agent codex --owner tab-9 --json >/dev/null
  run dibs release-all --owner tab-7 --agent codex
  [ "$status" -eq 0 ]
  [ "$(lockcount)" -eq 1 ]
}
