#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

pre_bash_payload() {
  jq -cn --arg cwd "$1" --arg cmd "$2" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, tool_input:{command:$cmd}}'
}

setup() {
  export REPO="$BATS_TEST_TMPDIR/repo"
  export WORKTREE="$BATS_TEST_TMPDIR/worktree"
  mkdir -p "$REPO"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email test@example.invalid
  git -C "$REPO" config user.name Test
  touch "$REPO/README.md"
  git -C "$REPO" add README.md
  git -C "$REPO" commit -qm initial
  git -C "$REPO" worktree add -q -b feature "$WORKTREE"
}

@test "marketplace registration from a linked worktree is denied for Codex and Claude" {
  for command in "codex plugin marketplace add ./" "claude plugin marketplace add ./"; do
    payload="$(pre_bash_payload "$WORKTREE" "$command")"

    run bash -c 'printf "%s" "$1" | DD_AGENT=codex DD_ONLY_PRETOOLUSE_GUARDS=no-worktree-marketplace bash "$2"' _ "$payload" "$DISPATCH"

    [ "$status" -eq 2 ]
    [[ "$output" == *"[dont-do-that/no-worktree-marketplace]"* ]]
  done
}

@test "marketplace registration from the canonical checkout passes" {
  payload="$(pre_bash_payload "$REPO" "codex plugin marketplace add ./")"

  run bash -c 'printf "%s" "$1" | DD_AGENT=codex DD_ONLY_PRETOOLUSE_GUARDS=no-worktree-marketplace bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
