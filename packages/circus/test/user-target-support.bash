#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

root="$tmp/circus"
mkdir -p "$root/shared" "$root/specific" "$tmp/out"

cat > "$root/shared/10-shared.md" <<'MD'
## Shared

Shared doctrine.
MD

cat > "$root/specific/codex.md" <<'MD'
## Codex

Codex orders.
MD

cat > "$root/specific/auto.md" <<'MD'
## Auto

Auto-detected orders.
MD

cat > "$root/specific/opencode.md" <<'MD'
## OpenCode

Disabled orders.
MD

cat > "$root/specific/missing.md" <<'MD'
## Missing

Missing detector orders.
MD

cat > "$root/targets" <<EOF
codex=$tmp/out/codex/AGENTS.md
opencode=$tmp/out/opencode/AGENTS.md supported=false
auto=$tmp/out/auto/AGENTS.md supported=auto detect=sh
missing=$tmp/out/missing/AGENTS.md supported=auto detect=definitely-missing-circus-agent
EOF

CIRCUS_ROOT="$root" "$circus_bin" build > "$tmp/build.out"

test -f "$tmp/out/codex/AGENTS.md"
test -f "$tmp/out/auto/AGENTS.md"
test ! -e "$tmp/out/opencode/AGENTS.md"
test ! -e "$tmp/out/missing/AGENTS.md"
grep -Eq '^circus: opencode +skipped \(supported=false\)$' "$tmp/build.out"
grep -Eq '^circus: missing +skipped \(detect=definitely-missing-circus-agent not found\)$' "$tmp/build.out"

CIRCUS_ROOT="$root" "$circus_bin" check > "$tmp/check.out"
grep -Fq "ok     codex" "$tmp/check.out"
grep -Fq "ok     auto" "$tmp/check.out"
grep -Eq '^skip +opencode +supported=false$' "$tmp/check.out"
grep -Eq '^skip +missing +detect=definitely-missing-circus-agent not found$' "$tmp/check.out"

CIRCUS_ROOT="$root" "$circus_bin" diff > "$tmp/diff.out"
grep -Fq "=== opencode ($tmp/out/opencode/AGENTS.md) ===" "$tmp/diff.out"
grep -Fq "(target skipped: supported=false)" "$tmp/diff.out"

CIRCUS_ROOT="$root" "$circus_bin" list > "$tmp/list.out"
grep -Eq "^  opencode +-> $tmp/out/opencode/AGENTS.md \\[skip: supported=false\\]$" "$tmp/list.out"
