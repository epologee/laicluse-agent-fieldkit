#!/usr/bin/env bash
set -euo pipefail

ROOT="${SAYSAY_PLUGIN_ROOT:-$(git rev-parse --show-toplevel)}"
SKILL_DIR="$ROOT/packages/saysay/skills/saysay"
CLAUDE_SKILL="$SKILL_DIR/SKILL.claude.md"
CODEX_SKILL="$SKILL_DIR/SKILL.codex.md"
CLAUDE_RUNTIME="$SKILL_DIR/SKILL.md"
CODEX_RUNTIME="$ROOT/.agents/plugins/generated/saysay/skills/saysay/SKILL.md"

fail() {
  printf 'saysay agent invocation test failed: %s\n' "$1" >&2
  exit 1
}

for path in "$CLAUDE_SKILL" "$CODEX_SKILL" "$CLAUDE_RUNTIME" "$CODEX_RUNTIME"; do
  [ -f "$path" ] || fail "missing skill file: $path"
done

grep -Fq 'run_in_background: true' "$CLAUDE_SKILL" \
  || fail 'Claude source must use the Bash background control'
grep -Fq 'run_in_background: true' "$CLAUDE_RUNTIME" \
  || fail 'Claude runtime must retain the Bash background control'

for path in "$CODEX_SKILL" "$CODEX_RUNTIME"; do
  grep -Eiq 'foreground' "$path" \
    || fail "Codex skill must keep saysay in the foreground: $path"
  grep -Eiq 'yield' "$path" \
    || fail "Codex skill must yield the live tool session: $path"
  grep -Fq 'Do not append `&`' "$path" \
    || fail "Codex skill must forbid detached shell backgrounding: $path"
  ! grep -Fq 'append `&` and do not wait on it' "$path" \
    || fail "Codex skill still recommends the broken detached invocation: $path"
done

printf 'saysay agent invocation test passed\n'
