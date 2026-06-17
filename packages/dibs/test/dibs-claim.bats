#!/usr/bin/env bats
# Contract tests for bin/dibs claim: exclusive occupancy, refuse-with-holder,
# idempotent re-claim, and stale takeover when the holder pid is dead.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  DIBS="$REPO_ROOT/packages/dibs/bin/dibs"
  NODE_BIN="$(command -v node)"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  DIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$DIR"
}

dibs() { "$NODE_BIN" "$DIBS" "$@"; }

@test "claim on a free dir succeeds and writes a lock file" {
  run dibs claim "$DIR" --pid $$ --agent claude --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "claimed"'
  [ "$(ls "$LAICLUSE_HOME/locks" | wc -l)" -eq 1 ]
}

@test "a second live claimer is refused and told who holds it and since when" {
  dibs claim "$DIR" --pid $$ --agent claude --json
  sleep 120 & local other=$!
  run dibs claim "$DIR" --pid "$other" --agent codex
  kill "$other" 2>/dev/null || true
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "refused"
  echo "$output" | grep -qi "held by claude"
  echo "$output" | grep -qi "since"
}

@test "refused claim under --json reports state refused and the holder" {
  dibs claim "$DIR" --pid $$ --agent claude --json
  sleep 120 & local other=$!
  run dibs claim "$DIR" --pid "$other" --agent codex --json
  kill "$other" 2>/dev/null || true
  [ "$status" -ne 0 ]
  echo "$output" | grep -q '"state": "refused"'
  echo "$output" | grep -q '"agent": "claude"'
  echo "$output" | grep -q '"acquiredAt"'
}

@test "re-claim by the same pid is idempotent (held-by-self)" {
  dibs claim "$DIR" --pid $$ --agent claude --json
  run dibs claim "$DIR" --pid $$ --agent claude --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "held-by-self"'
}

@test "a dead holder's lock is taken over by the next claimer" {
  sleep 120 & local holder=$!
  dibs claim "$DIR" --pid "$holder" --agent claude --json
  kill "$holder"; wait "$holder" 2>/dev/null || true
  run dibs claim "$DIR" --pid $$ --agent codex --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "took-over-stale"'
  echo "$output" | grep -q '"reason": "holder-dead"'
}

@test "a live holder on this host is respected (not broken)" {
  sleep 120 & local holder=$!
  dibs claim "$DIR" --pid "$holder" --agent claude --json
  run dibs claim "$DIR" --pid $$ --agent codex --json
  kill "$holder" 2>/dev/null || true
  [ "$status" -ne 0 ]
  echo "$output" | grep -q '"state": "refused"'
  echo "$output" | grep -q '"reason": "holder-alive"'
}

@test "a foreign-host lock is respected even when its pid is locally alive" {
  run dibs check "$DIR" --json
  local lockpath
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  lockpath="$(dibs check "$DIR" --json | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).path))')"
  "$NODE_BIN" -e 'const fs=require("fs");const p=process.argv[1];const r=JSON.parse(fs.readFileSync(p,"utf8"));r.hostname="some-other-host";r.pid='"$$"';fs.writeFileSync(p,JSON.stringify(r))' "$lockpath"
  run dibs claim "$DIR" --pid $$ --agent codex --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -q '"reason": "foreign-host"'
}

@test "claim refuses a directory that does not exist" {
  run dibs claim "$BATS_TEST_TMPDIR/nope" --pid $$ --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "does not exist"
}

@test "an unknown option gives a clear error, not parser advice" {
  run dibs claim "$DIR" --bogus --pid $$
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "unknown option"
}

@test "concurrent claimers on a free dir yield exactly one holder" {
  local n=20
  declare -a holders=()
  for i in $(seq 1 $n); do
    sleep 30 & holders+=($!)
  done
  local outdir="$BATS_TEST_TMPDIR/out"
  mkdir -p "$outdir"
  for i in $(seq 1 $n); do
    ( dibs claim "$DIR" --pid "${holders[$((i - 1))]}" --agent "a$i" --json >/dev/null 2>&1; echo $? >"$outdir/$i.rc" ) &
  done
  wait
  for h in "${holders[@]}"; do kill "$h" 2>/dev/null || true; done
  local ok=0
  for i in $(seq 1 $n); do
    [ "$(cat "$outdir/$i.rc")" -eq 0 ] && ok=$((ok + 1))
  done
  [ "$ok" -eq 1 ]
  [ "$(ls "$LAICLUSE_HOME/locks" | wc -l)" -eq 1 ]
}

@test "a corrupt lock file is reported and taken over by the next claimer" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  printf 'not json{' > "$LAICLUSE_HOME"/locks/*.lock
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"state": "corrupt"'
  run dibs claim "$DIR" --pid $$ --agent codex --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "took-over-stale"'
  echo "$output" | grep -q '"reason": "corrupt"'
}

@test "an age-capped stale foreign lock can be taken over" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  local lockpath
  lockpath="$(dibs check "$DIR" --json | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).path))')"
  "$NODE_BIN" -e 'const fs=require("fs");const p=process.argv[1];const r=JSON.parse(fs.readFileSync(p,"utf8"));r.hostname="some-other-host";r.acquiredAt="2000-01-01T00:00:00.000Z";fs.writeFileSync(p,JSON.stringify(r))' "$lockpath"
  run dibs claim "$DIR" --pid $$ --agent codex --max-age-hours 1 --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "took-over-stale"'
}
