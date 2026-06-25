#!/usr/bin/env bash
set -euo pipefail

ROOT="${SAYSAY_PLUGIN_ROOT:-$(git rev-parse --show-toplevel)}"
SAY_PHONETIC="$ROOT/packages/saysay/skills/saysay/say-phonetic"

fail() {
  printf 'saysay migration test failed: %s\n' "$1" >&2
  exit 1
}

[ -x "$SAY_PHONETIC" ] || fail 'say-phonetic script is missing or not executable'

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

export LAICLUSE_HOME="$workdir/laicluse"
export XDG_DATA_HOME="$workdir/xdg"

legacy="$XDG_DATA_HOME/saysay/phonetics.json"
canonical="$LAICLUSE_HOME/saysay/phonetics.json"

mkdir -p "$XDG_DATA_HOME/saysay"
printf '{"kbd":"keyboard"}' > "$legacy"

"$SAY_PHONETIC" list >/dev/null

[ -f "$canonical" ] || fail 'dictionary was not migrated into the LAICLUSE_HOME root'

jq -e '.kbd == "keyboard"' "$canonical" >/dev/null \
  || fail 'migrated dictionary lost its contents'

[ ! -f "$legacy" ] || fail 'legacy dictionary still present after migration; migration must move, not copy'

printf 'saysay migration test passed\n'
