#!/usr/bin/env bats
# Contract tests for the repair-scheduling helpers: anger-schedule (single-flight background
# investigation) and anger-resolve (close captures via a watermark).

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  SCHEDULE="$REPO/packages/anger-management/bin/anger-schedule"
  RESOLVE="$REPO/packages/anger-management/bin/anger-resolve"
  NODE_BIN="$(asdf which node 2>/dev/null || command -v node)"
  HOME="$BATS_TEST_TMPDIR/home"
  DIR="$HOME/.laicluse/anger-management"
  mkdir -p "$DIR"
  LOG="$DIR/friction.jsonl"
  # a mock runner keeps the test off the real claude CLI and fast
  export ANGER_SCHEDULE_RUNNER="cat"
  export ANGER_SCHEDULE_DELAY=1
}

run_schedule() { HOME="$HOME" ANGER_SCHEDULE_RUNNER="$ANGER_SCHEDULE_RUNNER" ANGER_SCHEDULE_DELAY="$ANGER_SCHEDULE_DELAY" "$NODE_BIN" "$SCHEDULE"; }

@test "no captures: scheduling does nothing and writes no pending marker" {
  run run_schedule
  [ "$status" -eq 0 ]
  [[ "$output" == *"no open captures"* ]]
  [ ! -f "$DIR/investigation.pending" ]
}

@test "open capture: scheduling creates a pending marker, then the background job clears it and writes findings" {
  printf '%s\n' '{"ts":"2026-06-05T09:00:00.000Z","word":"fuck","cwd":"/x","git":"main@a","note":"recurring reformat"}' > "$LOG"
  run run_schedule
  [ "$status" -eq 0 ]
  [[ "$output" == *"scheduled"* ]]
  [ -f "$DIR/investigation.pending" ]
  sleep 3
  [ ! -f "$DIR/investigation.pending" ]
  [ -f "$DIR/findings.md" ]
}

@test "single-flight: a second schedule while one is pending does not start another" {
  printf '%s\n' '{"ts":"2026-06-05T09:00:00.000Z","word":"shit","cwd":"/x","git":"main@a","note":"x"}' > "$LOG"
  HOME="$HOME" ANGER_SCHEDULE_RUNNER="$ANGER_SCHEDULE_RUNNER" ANGER_SCHEDULE_DELAY=30 "$NODE_BIN" "$SCHEDULE" >/dev/null
  [ -f "$DIR/investigation.pending" ]
  run env HOME="$HOME" ANGER_SCHEDULE_RUNNER="$ANGER_SCHEDULE_RUNNER" ANGER_SCHEDULE_DELAY=30 "$NODE_BIN" "$SCHEDULE"
  [[ "$output" == *"already pending"* ]]
}

@test "watermark: a capture covered by a prior repair is not open" {
  printf '%s\n' '{"ts":"2026-06-05T09:00:00.000Z","word":"crap","cwd":"/x","git":"main@a","note":"x"}' > "$LOG"
  printf '%s\n' '{"ts":"2026-06-05T09:10:00.000Z","verdict":"fix","covered_through":"2026-06-05T09:00:00.000Z","note":"fixed it"}' > "$DIR/repairs.jsonl"
  run run_schedule
  [[ "$output" == *"no open captures"* ]]
}

@test "anger-resolve records a repair with a covered_through watermark at the newest capture" {
  printf '%s\n%s\n' \
    '{"ts":"2026-06-05T09:00:00.000Z","word":"crap","cwd":"/x","git":"main@a","note":"a"}' \
    '{"ts":"2026-06-05T09:05:00.000Z","word":"wtf","cwd":"/x","git":"main@a","note":"b"}' > "$LOG"
  run env HOME="$HOME" "$NODE_BIN" "$RESOLVE" "loosened the reformat rule"
  [ "$status" -eq 0 ]
  [ -f "$DIR/repairs.jsonl" ]
  HOME="$HOME" "$NODE_BIN" -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.env.HOME+"/.laicluse/anger-management/repairs.jsonl","utf8").trim());if(o.covered_through!=="2026-06-05T09:05:00.000Z")process.exit(1);if(o.verdict!=="fix")process.exit(1)'
}

@test "anger-resolve refuses an empty note" {
  run env HOME="$HOME" "$NODE_BIN" "$RESOLVE"
  [ "$status" -ne 0 ]
}

@test "a stale marker from a dead worker is reclaimed so future investigations can schedule" {
  printf '%s\n' '{"ts":"2026-06-05T09:00:00.000Z","word":"fuck","cwd":"/x","git":"main@a","note":"x"}' > "$LOG"
  printf '%s\n' '{"scheduled":"2020-01-01T00:00:00.000Z","pid":999999}' > "$DIR/investigation.pending"
  run run_schedule
  [ "$status" -eq 0 ]
  [[ "$output" == *"scheduled"* ]]
}
