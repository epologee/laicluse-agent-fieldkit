#!/usr/bin/env bats
# packages/rover/test/check-broadcast.bats
#
# check-broadcast emits the topmost CHANGELOG section once per machine per
# version, keyed by a sentinel under ${LAICLUSE_HOME}/rover/broadcasts. --peek
# emits without writing the sentinel; a plain run emits then writes it, so the
# next run for the same version is silent. These cases guard that contract.

SCRIPT="$BATS_TEST_DIRNAME/../bin/check-broadcast"

setup() {
  PLUGIN_ROOT="$BATS_TEST_TMPDIR/plugin"
  mkdir -p "$PLUGIN_ROOT/.claude-plugin"
  printf '{"name":"rover","version":"9.9.9"}\n' > "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  printf '# rover changelog\n\n## [v9.9.9]\n\n### Added\n\n- A test entry.\n' > "$PLUGIN_ROOT/CHANGELOG.md"
  export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
}

@test "peek emits the latest section" {
  run node "$SCRIPT" --peek
  [ "$status" -eq 0 ]
  [[ "$output" == *"## [v9.9.9]"* ]]
  [[ "$output" == *"A test entry."* ]]
}

@test "peek does not write the sentinel" {
  run node "$SCRIPT" --peek
  [ "$status" -eq 0 ]
  [ ! -f "$LAICLUSE_HOME/rover/broadcasts/rover-broadcast-seen" ]
}

@test "plain run emits then marks the version seen" {
  run node "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## [v9.9.9]"* ]]
  [ -f "$LAICLUSE_HOME/rover/broadcasts/rover-broadcast-seen" ]
}

@test "a second run for the same version is silent" {
  node "$SCRIPT" >/dev/null
  run node "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "force re-emits even after the version was seen" {
  node "$SCRIPT" >/dev/null
  run node "$SCRIPT" --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"## [v9.9.9]"* ]]
}
