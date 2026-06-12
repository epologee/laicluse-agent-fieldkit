#!/usr/bin/env bats
# allow-comment: dd_cd_to_bash_target follows the repo a commit actually targets so the body validator reads the right index: the `cd <dir> &&` prefix and the `git -C <dir>` form both reposition the gate, even when the session cwd is an unrelated repo.

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  source "$SCRIPT_DIR/../../hooks/lib/common.sh"
  ORIGIN="$PWD"
  TARGET="$BATS_TEST_TMPDIR/target-repo"
  install -d "$TARGET"
}

teardown() {
  cd "$ORIGIN" 2>/dev/null || true
}

pretool_json() {
  jq -cn --arg c "$1" '{tool_input:{command:$c}}'
}

@test "cd prefix repositions the gate" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "cd $TARGET && git commit -m x")"
  [ "$PWD" = "$TARGET" ]
}

@test "git -C repositions the gate" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "git -C $TARGET commit -m x")"
  [ "$PWD" = "$TARGET" ]
}

@test "git -C with a quoted path repositions the gate" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "git -C \"$TARGET\" commit -m x")"
  [ "$PWD" = "$TARGET" ]
}

@test "cd prefix with a newline separator repositions the gate" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "$(printf 'cd %s\ngit commit -m x' "$TARGET")")"
  [ "$PWD" = "$TARGET" ]
}

@test "cd prefix with a semicolon separator repositions the gate" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "cd $TARGET; git commit -m x")"
  [ "$PWD" = "$TARGET" ]
}

@test "cd prefix wins over a later git -C" {
  cd "$ORIGIN"
  local other="$BATS_TEST_TMPDIR/other-repo"
  install -d "$other"
  dd_cd_to_bash_target "$(pretool_json "cd $TARGET && git -C $other status")"
  [ "$PWD" = "$TARGET" ]
}

@test "no cd and no -C leaves the gate where it was" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "git commit -m x")"
  [ "$PWD" = "$ORIGIN" ]
}

@test "a nonexistent -C target leaves the gate where it was" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "git -C $BATS_TEST_TMPDIR/missing commit -m x")"
  [ "$PWD" = "$ORIGIN" ]
}
