#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

pre_bash_payload() {
  jq -cn --arg cwd "$1" --arg cmd "$2" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, tool_input:{command:$cmd}}'
}

run_guard() {
  local guard="$1" payload="$2"
  run bash -c 'printf "%s" "$1" | DD_AGENT=claude DD_ONLY_PRETOOLUSE_GUARDS="$3" bash "$2"' _ "$payload" "$DISPATCH" "$guard"
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

@test "pr-discipline reads a gh pr create that follows another command" {
  payload="$(pre_bash_payload "$REPO" "gh auth status && gh pr create --title 'Fix the flaky import' --body ok")"

  run_guard pr-discipline "$payload"

  [ "$status" -eq 2 ]
  [[ "$output" == *"[dont-do-that/pr-discipline]"* ]]
}

@test "pr-discipline still reads a gh pr create behind a cd" {
  payload="$(pre_bash_payload "$REPO" "cd $REPO && gh pr create --title 'Fix the flaky import' --body ok")"

  run_guard pr-discipline "$payload"

  [ "$status" -eq 2 ]
  [[ "$output" == *"[dont-do-that/pr-discipline]"* ]]
}

@test "pr-discipline passes a capability title" {
  payload="$(pre_bash_payload "$REPO" "gh auth status && gh pr create --title 'Imports survive a flaky upstream' --body ok")"

  run_guard pr-discipline "$payload"

  [ "$status" -eq 0 ]
}

@test "pr-discipline does not split on a separator inside the title" {
  payload="$(pre_bash_payload "$REPO" "gh pr create --title 'Search && filter run on one index' --body ok")"

  run_guard pr-discipline "$payload"

  [ "$status" -eq 0 ]
}

@test "no-worktree-deploy reads an ansible-playbook that follows a git command" {
  payload="$(pre_bash_payload "$WORKTREE" "git status && ansible-playbook site.yml")"

  run_guard no-worktree-deploy "$payload"

  [ "$status" -eq 2 ]
  [[ "$output" == *"[dont-do-that/no-worktree-deploy]"* ]]
}

@test "no-worktree-deploy ignores ansible-playbook named inside a git commit message" {
  payload="$(pre_bash_payload "$WORKTREE" "git commit -m 'note that ansible-playbook site.yml runs after merge'")"

  run_guard no-worktree-deploy "$payload"

  [ "$status" -eq 0 ]
}

@test "no-worktree-deploy leaves a preview run alone" {
  payload="$(pre_bash_payload "$WORKTREE" "git status && ansible-playbook site.yml --check")"

  run_guard no-worktree-deploy "$payload"

  [ "$status" -eq 0 ]
}

@test "no-worktree-deploy stays quiet in the canonical checkout" {
  payload="$(pre_bash_payload "$REPO" "git status && ansible-playbook site.yml")"

  run_guard no-worktree-deploy "$payload"

  [ "$status" -eq 0 ]
}
