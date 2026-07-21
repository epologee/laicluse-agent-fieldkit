#!/usr/bin/env bats

load helpers

@test "default resolves a configured local master branch" {
  git -C "$TEST_REPO" branch -m master
  git -C "$TEST_REPO" config init.defaultBranch master

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' default"

  [ "$status" -eq 0 ]
  [ "$output" = "master" ]
}
@test "origin HEAD takes precedence when resolving the default branch" {
  add_origin
  git -C "$TEST_REPO" config init.defaultBranch master

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' default"

  [ "$status" -eq 0 ]
  [ "$output" = "main" ]
}

@test "rebase local keeps the feature checked out and rebases it onto current default" {
  create_feature_commit
  local old_candidate
  old_candidate=$(git -C "$TEST_REPO" rev-parse HEAD)
  advance_local_default
  local default_tip
  default_tip=$(git -C "$TEST_REPO" rev-parse refs/heads/main)

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' rebase --local"

  [ "$status" -eq 0 ]
  [ "$(git -C "$TEST_REPO" branch --show-current)" = "feature" ]
  [ "$(git -C "$TEST_REPO" rev-parse HEAD)" != "$old_candidate" ]
  git -C "$TEST_REPO" merge-base --is-ancestor "$default_tip" HEAD
}
