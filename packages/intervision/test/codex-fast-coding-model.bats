#!/usr/bin/env bats

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  HELPER="$REPO/packages/intervision/bin/codex-fast-coding-model"
  NODE_BIN="$(asdf which node 2>/dev/null || command -v node)"
  NODE_DIR="$(dirname "$NODE_BIN")"
  FAKE_BIN="$BATS_TEST_TMPDIR/fake-bin"
  MODELS="$BATS_TEST_TMPDIR/models.json"
  mkdir -p "$FAKE_BIN"
  printf '%s\n' \
    '#!/bin/sh' \
    'if [ "$1" = "debug" ] && [ "$2" = "models" ]; then' \
    '  cat "$MODELS"' \
    '  exit 0' \
    'fi' \
    'exit 1' \
    > "$FAKE_BIN/codex"
  chmod +x "$FAKE_BIN/codex"
  export MODELS
}

run_helper() {
  PATH="$FAKE_BIN:$NODE_DIR:/usr/bin:/bin" "$NODE_BIN" "$HELPER" "$@"
}

@test "chooses the advertised Codex Spark slug" {
  printf '%s\n' '{"models":[{"slug":"gpt-6.1-codex-spark","display_name":"GPT-6.1 Codex Spark","description":"Ultra-fast coding model","visibility":"list"}]}' > "$MODELS"
  run run_helper
  [ "$status" -eq 0 ]
  [ "$output" = "gpt-6.1-codex-spark" ]
}

@test "falls back to mini when Spark is absent" {
  printf '%s\n' '{"models":[{"slug":"gpt-6.1-mini","display_name":"GPT-6.1 Mini","description":"Fast coding model","visibility":"list"}]}' > "$MODELS"
  run run_helper
  [ "$status" -eq 0 ]
  [ "$output" = "gpt-6.1-mini" ]
}

@test "rejects unsafe override values" {
  printf '%s\n' '{"models":[]}' > "$MODELS"
  run env CODEX_FAST_CODING_MODEL='bad;rm' PATH="$FAKE_BIN:$NODE_DIR:/usr/bin:/bin" "$NODE_BIN" "$HELPER"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid CODEX_FAST_CODING_MODEL"* ]]
}

@test "fails closed when the catalog has no cheap model" {
  printf '%s\n' '{"models":[{"slug":"gpt-6.1","display_name":"GPT-6.1","description":"Frontier model","visibility":"list"}]}' > "$MODELS"
  run run_helper
  [ "$status" -eq 2 ]
  [[ "$output" == *"no cheap Codex coding model"* ]]
}
