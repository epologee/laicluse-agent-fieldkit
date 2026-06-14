#!/usr/bin/env bats
# test/plugin-versions/merge-head-count.bats
#
# During a merge commit, HEAD still points at the pre-merge default tip, so a
# commit count over HEAD alone misses every branch commit and rewrites the
# version DOWNWARD inside the merge itself (observed: 2.0.15 -> 2.0.6). The
# staged-mode bump must count commits reachable from HEAD *and* MERGE_HEAD.

SCRIPT="$BATS_TEST_DIRNAME/../../bin/plugin-versions"

setup() {
  export REPO="$BATS_TEST_TMPDIR/repo"
  git init -q "$REPO"
  cd "$REPO"
  git config user.email test@example.invalid
  git config user.name "Bats Test"
  git config commit.gpgsign false
  git config core.hooksPath /dev/null

  mkdir -p .claude-plugin packages/demo/.claude-plugin
  cat > .claude-plugin/marketplace.json <<'JSON'
{ "plugins": [ { "name": "demo", "description": "demo plugin" } ] }
JSON
  cat > packages/demo/.claude-plugin/plugin.json <<'JSON'
{ "name": "demo", "description": "demo plugin", "version": "2.0.1" }
JSON
  git add -A
  git commit -qm "init demo plugin"
}

@test "staged mode counts MERGE_HEAD history during a merge commit" {
  git checkout -qb feature
  echo one > packages/demo/one.txt
  git add packages/demo/one.txt
  git commit -qm "feature commit one"
  echo two > packages/demo/two.txt
  git add packages/demo/two.txt
  git commit -qm "feature commit two"

  git checkout -q main 2>/dev/null || git checkout -q master
  git merge --no-ff --no-commit feature

  PLUGIN_VERSIONS_GIT_CMD="git commit" run bash "$SCRIPT" --staged

  [ "$status" -eq 0 ]
  version=$(jq -r '.version' packages/demo/.claude-plugin/plugin.json)
  # 1 init + 2 feature commits reachable via MERGE_HEAD, +1 for the merge
  # commit about to land.
  [ "$version" = "2.0.4" ]
}

@test "staged mode without a merge in progress keeps the plain HEAD count" {
  echo three > packages/demo/three.txt
  git add packages/demo/three.txt

  PLUGIN_VERSIONS_GIT_CMD="git commit" run bash "$SCRIPT" --staged

  [ "$status" -eq 0 ]
  version=$(jq -r '.version' packages/demo/.claude-plugin/plugin.json)
  # 1 init commit, +1 for the commit about to land.
  [ "$version" = "2.0.2" ]
}
