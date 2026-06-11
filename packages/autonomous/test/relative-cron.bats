#!/usr/bin/env bats
# packages/autonomous/test/relative-cron.bats
#
# relative-cron turns a "fire N minutes from now" intent into a cron
# expression. Short intervals use */N; longer ones compute an explicit target
# minute so they do not fall into the */N alignment trap (*/20 fires at
# :00/:20/:40, not "in 20 minutes"). These cases guard the cron backoff table.

SCRIPT="$BATS_TEST_DIRNAME/../bin/relative-cron"

@test "short interval uses */N form" {
  run node "$SCRIPT" 5
  [ "$status" -eq 0 ]
  [ "$output" = "*/5 * * * *" ]
}

@test "boundary interval 10 still uses */N form" {
  run node "$SCRIPT" 10
  [ "$status" -eq 0 ]
  [ "$output" = "*/10 * * * *" ]
}

@test "long interval uses an explicit target minute, not */N" {
  run node "$SCRIPT" 20
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+\ \*\ \*\ \*\ \*$ ]]
  [[ "$output" != */* ]]
}

@test "60-minute terminal step uses an explicit minute, nudged off now" {
  run node "$SCRIPT" 60
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+\ \*\ \*\ \*\ \*$ ]]
  [[ "$output" != */* ]]
}

@test "non-integer input is rejected" {
  run node "$SCRIPT" abc
  [ "$status" -eq 1 ]
}

@test "zero is rejected" {
  run node "$SCRIPT" 0
  [ "$status" -eq 1 ]
}

@test "missing argument is rejected" {
  run node "$SCRIPT"
  [ "$status" -eq 1 ]
}
