#!/usr/bin/env bats
# Contract tests for the dibs exclude list: directories on the list are never
# locked (claim/check report 'excluded' and no lock file is written), the list
# is managed with 'dibs exclude add|remove|list', and the agent-config homes are
# built-in defaults every install ships with.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  DIBS="$REPO_ROOT/packages/dibs/bin/dibs"
  NODE_BIN="$(command -v node)"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  DIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$DIR"
}

dibs() { "$NODE_BIN" "$DIBS" "$@"; }

@test "exclude list shows /tmp and the agent-config homes as built-in defaults" {
  run dibs exclude list
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "/tmp"
  echo "$output" | grep -q "\.claude"
  echo "$output" | grep -q "\.codex"
  echo "$output" | grep -q "opencode"
}

@test "/tmp is excluded by default without any configuration" {
  local tmpdir
  tmpdir="$(mktemp -d /tmp/dibs-exclude.XXXXXX)"
  run dibs check "$tmpdir" --json
  rmdir "$tmpdir" 2>/dev/null || true
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "excluded"'
}

@test "a configured excluded dir is not claimed and writes no lock file" {
  dibs exclude add "$DIR"
  run dibs claim "$DIR" --pid $$ --agent claude --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "excluded"'
  [ ! -d "$LAICLUSE_HOME/locks" ] || [ "$(ls "$LAICLUSE_HOME/locks" | wc -l)" -eq 0 ]
}

@test "check on an excluded dir reports excluded" {
  dibs exclude add "$DIR"
  run dibs check "$DIR" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "excluded"'
}

@test "two live sessions both pass on an excluded dir (no refusal)" {
  dibs exclude add "$DIR"
  sleep 120 & local other=$!
  dibs claim "$DIR" --pid $$ --agent claude --json
  run dibs claim "$DIR" --pid "$other" --agent codex --json
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "excluded"'
}

@test "exclude add persists to the excludes file and is idempotent" {
  run dibs exclude add "$DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "added"
  [ -f "$LAICLUSE_HOME/dibs/excludes" ]
  grep -q "work" "$LAICLUSE_HOME/dibs/excludes"

  run dibs exclude add "$DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "already"
  [ "$(grep -c "work" "$LAICLUSE_HOME/dibs/excludes")" -eq 1 ]
}

@test "exclude remove clears a configured entry and re-enables locking" {
  dibs exclude add "$DIR"
  run dibs exclude remove "$DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "removed"

  run dibs claim "$DIR" --pid $$ --agent claude --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "claimed"'
}

@test "a built-in default cannot be removed and is reported as such" {
  run dibs exclude remove "~/.claude"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "default"
}

@test "removing an unconfigured non-default path is a clear no-op" {
  run dibs exclude remove "$DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "nothing to remove"
}

@test "a file inside an excluded git worktree is also excluded (worktree root)" {
  git init -q "$DIR"
  mkdir -p "$DIR/nested"
  dibs exclude add "$DIR"
  run dibs claim "$DIR/nested" --pid $$ --agent claude --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "excluded"'
}

@test "comments and blank lines in the excludes file are ignored" {
  mkdir -p "$LAICLUSE_HOME/dibs"
  printf '# a comment\n\n%s\n' "$DIR" > "$LAICLUSE_HOME/dibs/excludes"
  run dibs check "$DIR" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "excluded"'
}
