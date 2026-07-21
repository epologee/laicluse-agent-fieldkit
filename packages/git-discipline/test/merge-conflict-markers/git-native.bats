#!/usr/bin/env bats
# packages/git-discipline/test/merge-conflict-markers/git-native.bats
#
# git-native layer for the conflict-marker guard. Installs the commit-msg hook
# via install-hooks into a real repo, then drives real `git commit` to prove a
# CLI commit (outside the PreToolUse layer) cannot land a half-resolved merge,
# and that a clean resolution or the env-var escape commits normally.
#
# --no-edit reuses git's prepared "Merge branch ..." message, which the body
# validator classifies as a skip, so these tests isolate the conflict gate.

load helpers

install_git_native() {
  run bash -c "cd '$TEST_REPO' && bash '$INSTALL_SH'"
  [ "$status" -eq 0 ]
  [ -x "$TEST_REPO/.git/hooks/commit-msg" ]
  rm "$TEST_REPO/.git/hooks/pre-commit"
}

@test "CLI commit with staged conflict markers is blocked and HEAD does not move" {
  install_git_native
  seed_conflict
  git -C "$TEST_REPO" add f.txt   # stage the still-conflicted file
  local before
  before=$(git -C "$TEST_REPO" rev-parse HEAD)

  run git -C "$TEST_REPO" commit --no-edit
  [ "$status" -ne 0 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
  [[ "$output" == *"f.txt"* ]]

  local after
  after=$(git -C "$TEST_REPO" rev-parse HEAD)
  [ "$before" = "$after" ]
}

@test "CLI commit after a clean resolution lands and HEAD advances" {
  install_git_native
  seed_conflict
  resolve_clean
  local before
  before=$(git -C "$TEST_REPO" rev-parse HEAD)

  run git -C "$TEST_REPO" commit --no-edit
  [ "$status" -eq 0 ]

  local after
  after=$(git -C "$TEST_REPO" rev-parse HEAD)
  [ "$before" != "$after" ]
}

@test "git -c <opt> commit with staged markers is still blocked at the git-native layer" {
  # The PreToolUse commit predicate does not classify `git -c ... commit`, but the
  # git-native commit-msg hook fires whatever flags precede `commit`, so a CLI
  # commit cannot smuggle markers past this layer with a -c prefix.
  install_git_native
  seed_conflict
  git -C "$TEST_REPO" add f.txt
  local before
  before=$(git -C "$TEST_REPO" rev-parse HEAD)

  run git -C "$TEST_REPO" -c core.pager=cat commit --no-edit
  [ "$status" -ne 0 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]

  local after
  after=$(git -C "$TEST_REPO" rev-parse HEAD)
  [ "$before" = "$after" ]
}

@test "CLI cherry-pick --continue with staged markers is blocked at the git-native layer" {
  install_git_native
  seed_cherry_pick_conflict
  git -C "$TEST_REPO" add f.txt
  local before
  before=$(git -C "$TEST_REPO" rev-parse HEAD)

  run git -C "$TEST_REPO" cherry-pick --continue
  [ "$status" -ne 0 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]

  local after
  after=$(git -C "$TEST_REPO" rev-parse HEAD)
  [ "$before" = "$after" ]
}

@test "CLI commit of a hand-pasted conflict block (no merge) is blocked at the git-native layer" {
  install_git_native
  seed_pasted_markers
  local before
  before=$(git -C "$TEST_REPO" rev-parse HEAD)

  run git -C "$TEST_REPO" commit -m "land it"
  [ "$status" -ne 0 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]

  local after
  after=$(git -C "$TEST_REPO" rev-parse HEAD)
  [ "$before" = "$after" ]
}

@test "env-var escape lets a CLI commit land despite markers" {
  install_git_native
  seed_conflict
  git -C "$TEST_REPO" add f.txt
  local before
  before=$(git -C "$TEST_REPO" rev-parse HEAD)

  run env GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS=1 git -C "$TEST_REPO" commit --no-edit
  [ "$status" -eq 0 ]

  local after
  after=$(git -C "$TEST_REPO" rev-parse HEAD)
  [ "$before" != "$after" ]
}
