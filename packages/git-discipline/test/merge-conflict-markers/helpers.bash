#!/usr/bin/env bash
# Shared setup and fixtures for the merge-conflict-markers BATS suite.
#
# Strategy: real disposable git repos (no git-shim). The guard and the
# git-native hook both call `git diff --check` against a real working tree and
# index, so a shim would defeat the test. Mirrors install-hooks/helpers.bash.
#
# The PreToolUse path drives hooks/dispatch.sh. The conflict-marker guard sits
# among the safety locks, above the session/global disable check, so we set a
# temp LAICLUSE_HOME carrying the global-disable sentinel: that silences the
# commit-message nudge guards (which would otherwise mask an allow result) while
# leaving our guard live.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
DISPATCH="$REPO_ROOT/packages/git-discipline/hooks/dispatch.sh"
INSTALL_SH="$REPO_ROOT/packages/git-discipline/skills/install-hooks/lib/install.sh"

setup() {
  TEST_REPO="$BATS_TEST_TMPDIR/repo"
  install -d "$TEST_REPO"

  export HOME="$BATS_TEST_TMPDIR/home"
  install -d "$HOME/.claude/plugins"
  export GIT_EDITOR=true

  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  install -d "$LAICLUSE_HOME/git-discipline"
  : > "$LAICLUSE_HOME/git-discipline/git-discipline-disabled-global"

  git -C "$TEST_REPO" init -q -b main
  git -C "$TEST_REPO" config user.email "test@example.com"
  git -C "$TEST_REPO" config user.name "Test"
}

teardown() {
  : # BATS_TEST_TMPDIR cleanup handled by bats-core.
}

# seed_conflict — leaves TEST_REPO mid-merge with conflict markers in f.txt
# (working tree). git itself writes the markers, so no marker literal appears in
# this test source (which would otherwise trip the very guard under test).
seed_conflict() {
  printf 'l1\nshared\nl3\n' > "$TEST_REPO/f.txt"
  git -C "$TEST_REPO" add f.txt
  git -C "$TEST_REPO" commit -q -m "seed"
  git -C "$TEST_REPO" checkout -q -b sidebranch
  printf 'l1\nAAA\nl3\n' > "$TEST_REPO/f.txt"
  git -C "$TEST_REPO" commit -q -am "side"
  git -C "$TEST_REPO" checkout -q main
  printf 'l1\nBBB\nl3\n' > "$TEST_REPO/f.txt"
  git -C "$TEST_REPO" commit -q -am "main"
  git -C "$TEST_REPO" merge sidebranch >/dev/null 2>&1 || true
}

# seed_cherry_pick_conflict — leaves TEST_REPO mid-cherry-pick with conflict
# markers in f.txt, so `git cherry-pick --continue` is the genuine next step.
seed_cherry_pick_conflict() {
  printf 'l1\nshared\nl3\n' > "$TEST_REPO/f.txt"
  git -C "$TEST_REPO" add f.txt
  git -C "$TEST_REPO" commit -q -m "seed"
  git -C "$TEST_REPO" checkout -q -b pickfrom
  printf 'l1\nFROM-PICK\nl3\n' > "$TEST_REPO/f.txt"
  git -C "$TEST_REPO" commit -q -am "pick source"
  local pick_sha
  pick_sha=$(git -C "$TEST_REPO" rev-parse HEAD)
  git -C "$TEST_REPO" checkout -q main
  printf 'l1\nON-MAIN\nl3\n' > "$TEST_REPO/f.txt"
  git -C "$TEST_REPO" commit -q -am "main diverges"
  git -C "$TEST_REPO" cherry-pick "$pick_sha" >/dev/null 2>&1 || true
}

# seed_pasted_markers — a clean repo (no merge/rebase in progress) where a tracked
# file has a hand-pasted conflict block, staged. Proves detection fires outside any
# git operation. printf writes the markers (no marker literal at the start of a
# source line here, so this test file never trips the guard it exercises).
seed_pasted_markers() {
  printf 'before\n' > "$TEST_REPO/f.txt"
  git -C "$TEST_REPO" add f.txt
  git -C "$TEST_REPO" commit -q -m "seed"
  printf 'before\n<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> other\nafter\n' > "$TEST_REPO/f.txt"
  git -C "$TEST_REPO" add f.txt
}

# resolve_clean — replaces the conflicted file with a clean resolution, staged.
resolve_clean() {
  printf 'l1\nMERGED\nl3\n' > "$TEST_REPO/f.txt"
  git -C "$TEST_REPO" add f.txt
}

# pretool_json <command> — emits a PreToolUse:Bash payload to stdout.
pretool_json() {
  jq -cn --arg c "$1" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'
}

# run_dispatch_in_repo <command> — runs dispatch.sh with cwd=TEST_REPO so the
# guard's `git diff --check` inspects the test repo.
run_dispatch_in_repo() {
  local cmd="$1"
  pretool_json "$cmd" > "$BATS_TEST_TMPDIR/payload.json"
  run bash -c "cd '$TEST_REPO' && bash '$DISPATCH' < '$BATS_TEST_TMPDIR/payload.json'"
}
