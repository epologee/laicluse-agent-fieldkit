#!/usr/bin/env bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
GIT_DISCIPLINE="$REPO_ROOT/packages/git-discipline/bin/git-discipline"
INSTALL_HOOKS="$REPO_ROOT/packages/git-discipline/skills/install-hooks/lib/install.sh"
NODE_BIN="$(asdf which node 2>/dev/null || command -v node)"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export LAICLUSE_HOME="$HOME/.laicluse"
  export PATH="$(dirname "$NODE_BIN"):$PATH"
  mkdir -p "$HOME"

  TEST_REPO="$BATS_TEST_TMPDIR/repo"
  git init -q -b main "$TEST_REPO"
  git -C "$TEST_REPO" config user.name "Test Author"
  git -C "$TEST_REPO" config user.email "test@example.com"
  git -C "$TEST_REPO" config init.defaultBranch main
  printf 'base\n' > "$TEST_REPO/file.txt"
  git -C "$TEST_REPO" add file.txt
  git -C "$TEST_REPO" commit -q -m "Initial commit"
}

commit_on_current_branch() {
  local repo="$1"
  local content="$2"
  local subject="$3"
  printf '%s\n' "$content" >> "$repo/file.txt"
  git -C "$repo" add file.txt
  git -C "$repo" commit -q -m "$subject"
}

create_feature_commit() {
  git -C "$TEST_REPO" switch -q -c feature
  commit_on_current_branch "$TEST_REPO" "feature" "Feature commit"
}

advance_local_default() {
  local default_worktree="$BATS_TEST_TMPDIR/default-worktree"
  git -C "$TEST_REPO" worktree add -q "$default_worktree" main
  printf 'default\n' > "$default_worktree/default.txt"
  git -C "$default_worktree" add default.txt
  git -C "$default_worktree" commit -q -m "Advance default"
}

add_origin() {
  REMOTE_REPO="$BATS_TEST_TMPDIR/origin.git"
  git init -q --bare "$REMOTE_REPO"
  git -C "$TEST_REPO" remote add origin "$REMOTE_REPO"
  git -C "$TEST_REPO" push -q -u origin main
  git -C "$TEST_REPO" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
}
