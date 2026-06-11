#!/usr/bin/env bats
# test/plugin-adapters/skip-worktrees.bats
#
# A linked git worktree under <repo>/worktrees/ carries its own generated
# adapter targets. The drift check walks the repo with find, so without a
# prune it reports every worktree copy as "an unexpected generated adapter
# target" and blocks every commit in the canonical checkout while a
# worktree exists (observed live during the split-autonomous merge).

SCRIPT="$BATS_TEST_DIRNAME/../../bin/plugin-adapters"

setup() {
  export REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.claude-plugin" "$REPO/packages/demo/.claude-plugin" "$REPO/packages/demo/skills/demo"
  cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "demo-marketplace",
  "plugins": [ { "name": "demo", "description": "demo plugin", "source": "./packages/demo" } ]
}
JSON
  cat > "$REPO/packages/demo/.claude-plugin/plugin.json" <<'JSON'
{ "name": "demo", "description": "demo plugin", "version": "1.0.0" }
JSON
  cat > "$REPO/packages/demo/skills/demo/SKILL.md" <<'MD'
---
name: demo
description: demo skill
---

# Demo
MD
  bash "$SCRIPT" build "$REPO" > /dev/null
}

@test "check passes on a freshly built repo" {
  run bash "$SCRIPT" check "$REPO"
  [ "$status" -eq 0 ]
}

@test "check ignores generated targets inside worktrees/" {
  mkdir -p "$REPO/worktrees/some-mission"
  cp -R "$REPO/.agents" "$REPO/.claude-plugin" "$REPO/packages" "$REPO/worktrees/some-mission/"

  run bash "$SCRIPT" check "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" != *"worktrees/some-mission"* ]]
}
