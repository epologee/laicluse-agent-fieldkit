#!/usr/bin/env bats
# live-pre-push.bats
# Behavioural integration test: install hooks in a fixture repo, create a
# commit whose body carries `Slice: wip`, attempt to push to a fake bare
# upstream, and prove the pre-push hook denies it. Then bypass via the env
# var and prove the push goes through.

SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
INSTALL_SH="$REPO_ROOT/packages/git-discipline/skills/install-hooks/lib/install.sh"

setup() {
  TEST_REPO="$BATS_TEST_TMPDIR/repo"
  UPSTREAM="$BATS_TEST_TMPDIR/upstream.git"
  install -d "$TEST_REPO"

  git init -q -b main --bare "$UPSTREAM"

  pushd "$TEST_REPO" >/dev/null
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test"
  git config init.defaultBranch main
  git remote add origin "$UPSTREAM"
  popd >/dev/null

  export HOME="$BATS_TEST_TMPDIR/home"
  install -d "$HOME/.claude/plugins" "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline"

  # Override the wip-push log location so we do not clobber the operator's.
  export GIT_DISCIPLINE_WIP_PUSH_LOG="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-wip-pushes.log"
}

teardown() {
  : # bats handles cleanup
}

run_install() {
  run bash -c "cd '$TEST_REPO' && bash '$INSTALL_SH'"
  [ "$status" -eq 0 ]
  rm "$TEST_REPO/.git/hooks/pre-commit"
}

# Stage a non-trivial change with the given commit message body.
make_wip_commit() {
  local msg_file="$BATS_TEST_TMPDIR/wip-msg"
  cat > "$msg_file" <<'BODY'
WIP scratch implementation

Quick draft, will rewrite tomorrow.

Slice: wip
BODY

  pushd "$TEST_REPO" >/dev/null
  printf 'first\n' > seed.txt
  git add seed.txt
  # Initial commit is trivial, so commit-msg accepts it without body schema.
  git -c commit.gpgsign=false commit -q -m "Seed initial file"
  git checkout -q -b feature

  printf 'one\ntwo\nthree\nfour\n' > scratch.txt
  printf 'aa\nbb\ncc\ndd\n' > scratch2.txt
  git add scratch.txt scratch2.txt
  # Use --no-verify on the wip commit since the body lacks Tests: trailer
  # which the commit-msg hook would otherwise demand. We are testing the
  # pre-push hook, not the commit-msg hook, so bypass at commit time.
  git -c commit.gpgsign=false commit --no-verify -q -F "$msg_file"
  popd >/dev/null
}

@test "installed pre-push blocks a push that carries a Slice: wip commit" {
  run_install
  make_wip_commit

  pushd "$TEST_REPO" >/dev/null
  run git push -u origin feature
  popd >/dev/null

  [ "$status" -ne 0 ]
  [[ "$output" == *"[git-discipline/pre-push]"* ]] || [[ "$output" == *"wip commits in push range"* ]]
}

@test "GIT_DISCIPLINE_ALLOW_WIP_PUSH=1 lets the push through and logs the bypass" {
  run_install
  make_wip_commit

  pushd "$TEST_REPO" >/dev/null
  run env GIT_DISCIPLINE_ALLOW_WIP_PUSH=1 GIT_DISCIPLINE_WIP_PUSH_LOG="$GIT_DISCIPLINE_WIP_PUSH_LOG" \
    git push -u origin feature
  popd >/dev/null

  [ "$status" -eq 0 ]

  [ -f "$GIT_DISCIPLINE_WIP_PUSH_LOG" ]
  grep -q "|env" "$GIT_DISCIPLINE_WIP_PUSH_LOG"
}

# Build a default branch that moved ahead with a commit whose body predates the
# discipline, plus a feature branch that was pushed before being rebased on top
# of it. The force-push then reports a stale remote sha for the feature branch.
make_rebased_feature() {
  pushd "$TEST_REPO" >/dev/null
  printf 'first\n' > seed.txt
  git add seed.txt
  git -c commit.gpgsign=false commit -q -m "Seed initial file"
  git push -q -u origin main
  git remote set-head origin -a >/dev/null

  git checkout -q -b feature
  printf 'one\n' > feature.txt
  git add feature.txt
  git -c commit.gpgsign=false commit -q -m "Add one feature line"
  git push -q -u origin feature

  git checkout -q main
  printf 'a\nb\nc\nd\ne\nf\n' > widget.txt
  printf 'x\ny\nz\n' > pipeline.txt
  git add widget.txt pipeline.txt
  git -c commit.gpgsign=false commit -q -m "Rework the widget pipeline"
  git push -q origin main

  git checkout -q feature
  git -c commit.gpgsign=false rebase -q main
  popd >/dev/null
}

@test "installed pre-push lets a rebased branch through instead of judging the default branch it caught up on" {
  make_rebased_feature
  run_install

  pushd "$TEST_REPO" >/dev/null
  run git push --force-with-lease origin feature
  popd >/dev/null

  [ "$status" -eq 0 ]
  [[ "$output" != *"Body schema misses in push range"* ]]
}

@test "an unreachable plugin path names the path instead of a missing subcommand" {
  run_install
  make_wip_commit

  pushd "$TEST_REPO" >/dev/null
  gone="$BATS_TEST_TMPDIR/gone-plugin"
  sed -i.bak "s#^PLUGIN_PATH=.*#PLUGIN_PATH=\"$gone\"#" .git/hooks/pre-push
  run git push -u origin feature
  popd >/dev/null

  [ "$status" -ne 0 ]
  [[ "$output" == *"no executable git-discipline at $gone/bin/git-discipline"* ]]
  [[ "$output" != *"flow command"* ]]
}
