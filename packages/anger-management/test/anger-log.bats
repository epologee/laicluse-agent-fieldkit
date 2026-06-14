#!/usr/bin/env bats
# Contract tests for bin/anger-log: the JSONL shape that /anger-management reads.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  LOG_BIN="$REPO/packages/anger-management/bin/anger-log"
  NODE_BIN="$(asdf which node 2>/dev/null || command -v node)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  LOG="$HOME/.laicluse/anger-management/friction.jsonl"
}

# Read field <key> from the last JSONL line via node.
field() {
  HOME="$HOME" "$NODE_BIN" -e '
    const fs = require("fs");
    const lines = fs.readFileSync(process.argv[1], "utf8").trim().split("\n");
    const o = JSON.parse(lines[lines.length - 1]);
    process.stdout.write(String(o[process.argv[2]]));
  ' "$LOG" "$1"
}

@test "heredoc note is captured with word, note, ts and cwd keys" {
  HOME="$HOME" "$NODE_BIN" "$LOG_BIN" shit <<'PN'
verifier counted wrong commits
PN
  [ "$(field word)" = "shit" ]
  [ "$(field note)" = "verifier counted wrong commits" ]
  [ -n "$(field ts)" ]
  [ -n "$(field cwd)" ]
}

@test "word-only via /dev/null stores an empty note without hanging" {
  HOME="$HOME" "$NODE_BIN" "$LOG_BIN" wtf </dev/null
  [ "$(field word)" = "wtf" ]
  [ "$(field note)" = "" ]
}

@test "shell metacharacters in the note are stored literally, never executed" {
  HOME="$HOME" "$NODE_BIN" "$LOG_BIN" fuck <<'PN'
$(touch PWNED) `id` "x" ; rm -rf /
PN
  [ ! -e "$BATS_TEST_TMPDIR/PWNED" ]
  [ ! -e PWNED ]
  [[ "$(field note)" == *'$(touch PWNED)'* ]]
}

@test "an over-long note is capped at 200 characters" {
  printf 'x%.0s' {1..500} | HOME="$HOME" "$NODE_BIN" "$LOG_BIN" crap
  [ "$(field note | wc -c | tr -d ' ')" -le 200 ]
}

@test "a non-git working directory yields an empty git field" {
  cd "$BATS_TEST_TMPDIR"
  HOME="$HOME" "$NODE_BIN" "$LOG_BIN" bullshit </dev/null
  [ "$(field git)" = "" ]
}

@test "a missing word argument exits non-zero" {
  run env HOME="$HOME" "$NODE_BIN" "$LOG_BIN"
  [ "$status" -ne 0 ]
}
