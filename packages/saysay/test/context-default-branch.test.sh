#!/usr/bin/env bash
set -euo pipefail

ROOT="${SAYSAY_PLUGIN_ROOT:-$(git rev-parse --show-toplevel)}"
SAYSAY="$ROOT/packages/saysay/bin/saysay"

fail() {
  printf 'saysay context test failed: %s\n' "$1" >&2
  exit 1
}

[ -x "$SAYSAY" ] || fail 'saysay script is missing or not executable'

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

fakebin="$workdir/bin"
repo="$workdir/repo"
capture="$workdir/spoken.txt"
mkdir -p "$fakebin" "$repo"

cat > "$fakebin/say" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
audiofile=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      audiofile="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
cat > "$SAYSAY_CAPTURE"
[ -n "$audiofile" ] && : > "$audiofile"
SH
chmod +x "$fakebin/say"

cat > "$fakebin/afplay" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$fakebin/afplay"

git -C "$repo" init -q -b trunk
git -C "$repo" config user.email t@t.t
git -C "$repo" config user.name t
git -C "$repo" commit -q --allow-empty -m init
git -C "$repo" remote add origin git@github.com:example/vault.git
git -C "$repo" update-ref refs/remotes/origin/trunk HEAD
git -C "$repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk

(
  cd "$repo"
  PATH="$fakebin:$PATH" SAYSAY_CAPTURE="$capture" "$SAYSAY" <<'TEXT'
Hello.
TEXT
)

grep -q '^example vault, Hello\.$' "$capture" \
  || fail "default branch context should use repo label, got: $(cat "$capture")"

git -C "$repo" symbolic-ref --delete refs/remotes/origin/HEAD
git -C "$repo" checkout -q -b main
git -C "$repo" checkout -q trunk
rm -f "$capture"

(
  cd "$repo"
  PATH="$fakebin:$PATH" SAYSAY_CAPTURE="$capture" "$SAYSAY" <<'TEXT'
Hello again.
TEXT
)

grep -q '^example vault, Hello again\.$' "$capture" \
  || fail "current HEAD fallback should use repo label, got: $(cat "$capture")"

printf 'saysay context test passed\n'
