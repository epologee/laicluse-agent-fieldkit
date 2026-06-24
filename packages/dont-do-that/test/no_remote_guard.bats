#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

pre_bash_payload() {
  jq -cn --arg cwd "$1" --arg cmd "$2" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, tool_input:{command:$cmd}}'
}

setup() {
  export OUTSIDE="$BATS_TEST_TMPDIR/outside"
  export REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$OUTSIDE" "$REPO"
  git -C "$REPO" init -q
  git -C "$REPO" remote add origin https://example.invalid/repo.git
}

@test "no-remote guard honors Codex cwd for git push checks" {
  payload="$(pre_bash_payload "$REPO" "git push origin main")"

  run bash -c 'cd "$3" && printf "%s" "$1" | DD_AGENT=codex DD_ONLY_PRETOOLUSE_GUARDS=no-remote bash "$2"' _ "$payload" "$DISPATCH" "$OUTSIDE"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
