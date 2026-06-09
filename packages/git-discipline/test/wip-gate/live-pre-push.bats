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
  run git push -u origin main
  popd >/dev/null

  [ "$status" -ne 0 ]
  [[ "$output" == *"[git-discipline/pre-push]"* ]] || [[ "$output" == *"wip commits in push range"* ]]
}

@test "GIT_DISCIPLINE_ALLOW_WIP_PUSH=1 lets the push through and logs the bypass" {
  run_install
  make_wip_commit

  pushd "$TEST_REPO" >/dev/null
  run env GIT_DISCIPLINE_ALLOW_WIP_PUSH=1 GIT_DISCIPLINE_WIP_PUSH_LOG="$GIT_DISCIPLINE_WIP_PUSH_LOG" \
    git push -u origin main
  popd >/dev/null

  [ "$status" -eq 0 ]

  [ -f "$GIT_DISCIPLINE_WIP_PUSH_LOG" ]
  grep -q "|env" "$GIT_DISCIPLINE_WIP_PUSH_LOG"
}
