#!/usr/bin/env bats
# allow-comment: linked-worktree regression proves the common Git hook root executes.

load helpers

@test "worktree install writes the common git hooks directory and executes there" {
  # Need an initial commit before adding a worktree.
  pushd "$TEST_REPO" >/dev/null
  printf 'init\n' > README
  git add README
  git -c commit.gpgsign=false commit -q -m "init" --no-verify
  popd >/dev/null

  local worktree_dir="$BATS_TEST_TMPDIR/wt"
  pushd "$TEST_REPO" >/dev/null
  git worktree add -b feature/wt "$worktree_dir" >/dev/null
  popd >/dev/null

  run_install "$worktree_dir"
  [ "$status" -eq 0 ]

  # allow-comment: Git executes hooks from the common directory across linked worktrees.
  pushd "$worktree_dir" >/dev/null
  local gitdir
  gitdir=$(git rev-parse --git-common-dir)
  gitdir=$(cd "$gitdir" && pwd)
  popd >/dev/null

  [ -f "$gitdir/hooks/pre-commit" ]
  [ -f "$gitdir/hooks/commit-msg" ]
  [ -f "$gitdir/hooks/post-commit" ]

  printf 'one\n' > "$worktree_dir/tiny.txt"
  git -C "$worktree_dir" add tiny.txt
  run git -C "$worktree_dir" -c commit.gpgsign=false commit -m "Tiny worktree commit"
  [ "$status" -eq 0 ]
}
