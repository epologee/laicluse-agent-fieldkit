#!/bin/bash
# Smoke tests for packages/git-discipline/bin/check-broadcast.
#
# Drives the helper against a fixture plugin tree (synthetic plugin.json +
# CHANGELOG.md) under a temp HOME so the real ${LAICLUSE_HOME:-~/.laicluse}/git-discipline/broadcasts is
# never touched. Each test asserts on stdout and on whether the sentinel
# was written.
#
# Run from anywhere:
#   bash packages/git-discipline/test/broadcast/check-broadcast.test.sh
# Exit 0 = all pass, 1 = at least one failure.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HELPER="${SCRIPT_DIR}/../../bin/check-broadcast"

PASS=0
FAIL=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

ok() {
  printf 'ok: %s\n' "$1"
  PASS=$((PASS + 1))
}

setup_fixture() {
  local root
  root=$(mktemp -d)
  mkdir -p "$root/plugin/.claude-plugin"
  cat > "$root/plugin/.claude-plugin/plugin.json" <<'JSON'
{ "name": "test-plugin", "version": "9.9.9" }
JSON
  cat > "$root/plugin/CHANGELOG.md" <<'MD'
# changelog

## [v9.9.9]

### Added

- something new

## [v9.9.8]

older entry
MD
  printf '%s\n' "$root"
}

run_helper() {
  local fake_home="$1"
  local plugin_root="$2"
  shift 2
  HOME="$fake_home" CLAUDE_PLUGIN_ROOT="$plugin_root" node "$HELPER" "$@"
}

# ---------------------------------------------------------------------------
# Test 1: first run emits the latest section and writes the sentinel.
# ---------------------------------------------------------------------------
{
  fixture=$(setup_fixture)
  fake_home="$fixture/home"
  mkdir -p "$fake_home"
  out=$(run_helper "$fake_home" "$fixture/plugin")
  if grep -q '## \[v9.9.9\]' <<< "$out" && grep -q 'something new' <<< "$out"; then
    ok 'first run emits latest section'
  else
    fail "first run output missing expected lines: $out"
  fi
  sentinel="$fake_home/.laicluse/git-discipline/broadcasts/test-plugin-broadcast-seen"
  if [[ -f "$sentinel" ]] && grep -q '^9.9.9$' "$sentinel"; then
    ok 'first run writes sentinel with current version'
  else
    fail "sentinel missing or wrong content: $(cat "$sentinel" 2>/dev/null)"
  fi
}

# ---------------------------------------------------------------------------
# Test 2: second run with same version is silent and exits 0.
# ---------------------------------------------------------------------------
{
  out=$(run_helper "$fake_home" "$fixture/plugin")
  rc=$?
  if [[ -z "$out" ]] && [[ "$rc" -eq 0 ]]; then
    ok 'second run is silent at same version'
  else
    fail "expected silence; got rc=$rc out=$out"
  fi
}

# ---------------------------------------------------------------------------
# Test 3: --force re-emits regardless of sentinel.
# ---------------------------------------------------------------------------
{
  out=$(run_helper "$fake_home" "$fixture/plugin" --force)
  if grep -q '## \[v9.9.9\]' <<< "$out"; then
    ok '--force re-emits at same version'
  else
    fail "--force did not produce output: $out"
  fi
}

# ---------------------------------------------------------------------------
# Test 4: --peek emits without updating the sentinel.
# ---------------------------------------------------------------------------
{
  fixture2=$(setup_fixture)
  fake_home2="$fixture2/home"
  mkdir -p "$fake_home2"
  out=$(run_helper "$fake_home2" "$fixture2/plugin" --peek)
  sentinel2="$fake_home2/.laicluse/git-discipline/broadcasts/test-plugin-broadcast-seen"
  if grep -q '## \[v9.9.9\]' <<< "$out" && [[ ! -f "$sentinel2" ]]; then
    ok '--peek emits without writing sentinel'
  else
    fail "peek behavior wrong: out=$out, sentinel-exists=$([[ -f "$sentinel2" ]] && echo yes || echo no)"
  fi
}

# ---------------------------------------------------------------------------
# Test 5: missing CHANGELOG produces silence and no sentinel.
# ---------------------------------------------------------------------------
{
  fixture3=$(setup_fixture)
  fake_home3="$fixture3/home"
  mkdir -p "$fake_home3"
  rm "$fixture3/plugin/CHANGELOG.md"
  out=$(run_helper "$fake_home3" "$fixture3/plugin")
  sentinel3="$fake_home3/.laicluse/git-discipline/broadcasts/test-plugin-broadcast-seen"
  if [[ -z "$out" ]] && [[ ! -f "$sentinel3" ]]; then
    ok 'missing CHANGELOG: silent and no sentinel'
  else
    fail "missing CHANGELOG path wrong: out=$out, sentinel-exists=$([[ -f "$sentinel3" ]] && echo yes || echo no)"
  fi
}

# ---------------------------------------------------------------------------
# Test 6: bumping plugin.json version after sentinel re-fires the broadcast.
# ---------------------------------------------------------------------------
{
  cat > "$fixture/plugin/.claude-plugin/plugin.json" <<'JSON'
{ "name": "test-plugin", "version": "9.9.10" }
JSON
  out=$(run_helper "$fake_home" "$fixture/plugin")
  if grep -q '## \[v9.9.9\]' <<< "$out"; then
    ok 'version bump re-fires broadcast (latest section is shown)'
  else
    fail "version bump did not refire: $out"
  fi
  if grep -q '^9.9.10$' "$sentinel"; then
    ok 'sentinel updated to new version after refire'
  else
    fail "sentinel not updated: $(cat "$sentinel")"
  fi
}

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
