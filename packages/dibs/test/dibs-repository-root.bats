#!/usr/bin/env bats
# Contract tests for bin/dibs repository-root occupancy.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  DIBS="$REPO_ROOT/packages/dibs/bin/dibs"
  NODE_BIN="$(command -v node)"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  WORKTREE="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$WORKTREE/packages/alpha/src" "$WORKTREE/packages/beta/src"
  git -C "$WORKTREE" init -q
  WORKTREE="$(cd "$WORKTREE" && pwd -P)"
  ALPHA="$WORKTREE/packages/alpha"
  BETA="$WORKTREE/packages/beta"
}

dibs() { "$NODE_BIN" "$DIBS" "$@"; }

@test "claims from different subdirectories in one git worktree contend for one lock" {
  dibs claim "$ALPHA" --pid $$ --agent claude --json >/dev/null
  sleep 120 & local other=$!

  run dibs claim "$BETA" --pid "$other" --agent codex --json
  local rc=$status
  local out="$output"
  kill "$other" 2>/dev/null || true

  [ "$rc" -ne 0 ]
  echo "$out" | grep -q '"state": "refused"'
  echo "$out" | grep -q '"agent": "claude"'
  [ "$(ls "$LAICLUSE_HOME/locks" | wc -l)" -eq 1 ]
  cat "$LAICLUSE_HOME"/locks/*.lock | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s); if (r.realpath !== process.argv[1]) process.exit(1);})' "$WORKTREE"
}

@test "check and release from a sibling subdirectory use the git worktree lock" {
  dibs claim "$ALPHA" --pid $$ --agent claude --json >/dev/null

  run dibs check "$BETA" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "held"'
  echo "$output" | grep -q "\"realpath\": \"$WORKTREE\""

  run dibs release "$BETA" --pid $$
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "released"
  [ "$(ls "$LAICLUSE_HOME/locks" 2>/dev/null | wc -l)" -eq 0 ]
}
