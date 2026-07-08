#!/usr/bin/env bats
# Contract tests for the lock store: realpath keying under LAICLUSE_HOME, the
# sha-named path shape, and the no-flock / node-built-ins-only guarantees.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  DIBS="$REPO_ROOT/packages/dibs/bin/dibs"
  LIB="$REPO_ROOT/packages/dibs/bin/dibs-lib.mjs"
  NODE_BIN="$(command -v node)"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  DIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$DIR"
}

dibs() {
  if [ "${1:-}" = "claim" ]; then
    case " $* " in *" --description "*) : ;; *) set -- "$@" --description "test claim" ;; esac
  fi
  "$NODE_BIN" "$DIBS" "$@"
}

@test "the lock lives under LAICLUSE_HOME/locks with a 64-hex sha name" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  local files
  files="$(ls "$LAICLUSE_HOME/locks")"
  [ "$(echo "$files" | wc -l)" -eq 1 ]
  echo "$files" | grep -qE '^[0-9a-f]{64}\.lock$'
}

@test "two paths resolving to the same realpath map to the same lock" {
  local alias="$BATS_TEST_TMPDIR/alias"
  ln -s "$DIR" "$alias"
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  # Claiming via the symlink with a different pid must see the existing holder
  # (same realpath -> same lock), not a fresh free lock.
  sleep 120 & local other=$!
  run dibs claim "$alias" --pid "$other" --agent codex --json
  kill "$other" 2>/dev/null || true
  [ "$status" -ne 0 ]
  echo "$output" | grep -q '"state": "refused"'
  [ "$(ls "$LAICLUSE_HOME/locks" | wc -l)" -eq 1 ]
}

@test "the dibs sources do not depend on flock or any native lock primitive" {
  run grep -rEi "flock|O_EXLOCK|shlock|lockf\\(" "$REPO_ROOT/packages/dibs/bin"
  [ "$status" -ne 0 ]
}

@test "the dibs library imports only node built-ins" {
  run grep -E "^import .* from '" "$LIB"
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -vqE "from 'node:"
}

@test "the lock record carries realpath, pid, agent, owner, description, hostname, nonce and acquired-at" {
  dibs claim "$DIR" --pid $$ --agent claude --session abc --owner owner-1 --description "inspect stale lock" --json >/dev/null
  local rec
  rec="$(cat "$LAICLUSE_HOME"/locks/*.lock)"
  echo "$rec" | grep -q '"realpath"'
  echo "$rec" | grep -q '"pid"'
  echo "$rec" | grep -q '"agent": "claude"'
  echo "$rec" | grep -q '"owner": "owner-1"'
  echo "$rec" | grep -q '"description": "inspect stale lock"'
  echo "$rec" | grep -q '"hostname"'
  echo "$rec" | grep -q '"nonce"'
  echo "$rec" | grep -q '"acquiredAt"'
}
