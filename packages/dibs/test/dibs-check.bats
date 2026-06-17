#!/usr/bin/env bats
# Contract tests for bin/dibs check: free vs holder reporting, liveness.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  DIBS="$REPO_ROOT/packages/dibs/bin/dibs"
  NODE_BIN="$(command -v node)"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  DIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$DIR"
}

dibs() { "$NODE_BIN" "$DIBS" "$@"; }

@test "check reports a free dir as free" {
  run dibs check "$DIR" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "free"'
}

@test "check reports the holder, pid and acquired-at for a held dir" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  run dibs check "$DIR" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "held"'
  echo "$output" | grep -q '"agent": "claude"'
  echo "$output" | grep -q '"acquiredAt"'
  echo "$output" | grep -q '"alive": true'
}

@test "check human output names the holder and since-when" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  run dibs check "$DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "held by claude"
  echo "$output" | grep -qi "alive"
}

@test "check on a non-existent directory errors clearly" {
  run dibs check "$BATS_TEST_TMPDIR/nope"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "does not exist"
}

@test "the held report names the holder host for cross-host diagnosis" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  run dibs check "$DIR"
  echo "$output" | grep -qiE "on [^ ]+ since"
}

@test "check reports a dead holder as not alive and stale" {
  sleep 120 & local holder=$!
  dibs claim "$DIR" --pid "$holder" --agent claude --json >/dev/null
  kill "$holder"; wait "$holder" 2>/dev/null || true
  run dibs check "$DIR" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"alive": false'
  echo "$output" | grep -q '"stale": true'
}
