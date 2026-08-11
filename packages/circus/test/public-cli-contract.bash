#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

root="$tmp/circus"
mkdir -p "$root/shared" "$root/specific" "$tmp/out"
printf '# Shared doctrine\n' > "$root/shared/10-shared.md"
printf '# Codex specifics\n' > "$root/specific/codex.md"
printf 'codex=%s\n' "$tmp/out/AGENTS.md" > "$root/targets"

help="$($circus_bin --help)"
case "$help" in
  *"briefs every coding agent"*"generate all targets"*"shared doctrine"*"specific/ is per-agent"*) ;;
  *) echo "FAIL: public CLI help is not consistently English or specific/-based" >&2; exit 1 ;;
esac

mkdir -p "$tmp/standalone/bin"
cp "$circus_bin" "$tmp/standalone/bin/circus"
"$tmp/standalone/bin/circus" --help >/dev/null

CIRCUS_ROOT="$root" "$circus_bin" build >/dev/null
first_line="$(sed -n '1p' "$tmp/out/AGENTS.md")"
expected="<!-- GENERATED from the circus source by 'circus build'. Edit shared/ or specific/, never this file. Direct edits disappear on the next build. -->"
test "$first_line" = "$expected"
test "$(tail -c 1 "$tmp/out/AGENTS.md" | LC_ALL=C od -An -tu1 | tr -d ' ')" = "10"

sync_repo="$tmp/sync-repo"
mkdir -p "$sync_repo"
git -C "$sync_repo" init -q
git -C "$sync_repo" config user.name "Circus Test"
git -C "$sync_repo" config user.email "circus@example.test"
printf '# Original\n' > "$sync_repo/CIRCUS.md"
cp "$sync_repo/CIRCUS.md" "$sync_repo/CLAUDE.md"
cp "$sync_repo/CIRCUS.md" "$sync_repo/AGENTS.md"
git -C "$sync_repo" add CIRCUS.md CLAUDE.md AGENTS.md
git -C "$sync_repo" commit -q --no-verify -m "Test fixture"
printf '# Updated\n' > "$sync_repo/CIRCUS.md"
"$circus_bin" sync "$sync_repo" >/dev/null
for synced_file in CIRCUS.md CLAUDE.md AGENTS.md; do
  test "$(tail -c 1 "$sync_repo/$synced_file" | LC_ALL=C od -An -tu1 | tr -d ' ')" = "10"
done

echo "ok: public-cli-contract"
