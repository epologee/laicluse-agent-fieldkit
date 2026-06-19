#!/usr/bin/env bats
# test/build-pages/og-card.bats
#
# build-pages renders a share card from live marketplace data and stamps a
# cache-busting hash into the head. These assertions guard that the SVG always
# carries the live plugin count, the rasterized PNG keeps the declared
# 1200x630 OG dimensions, and the meta hash stops being the "dev" placeholder.

SCRIPT="$BATS_TEST_DIRNAME/../../bin/build-pages"

setup() {
  export REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.claude-plugin" "$REPO/packages/demo/.claude-plugin" "$REPO/docs"
  cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "demo-marketplace",
  "plugins": [ { "name": "demo", "description": "demo plugin", "source": "./packages/demo" } ]
}
JSON
  cat > "$REPO/packages/demo/.claude-plugin/plugin.json" <<'JSON'
{ "name": "demo", "description": "demo plugin", "version": "2.0.1" }
JSON
  cat > "$REPO/docs/index.html" <<'HTML'
<meta property="og:image" content="https://example.test/assets/og-image.png?v=dev">
<meta name="twitter:image" content="https://example.test/assets/og-image.png?v=dev">
HTML
  node "$SCRIPT" "$REPO" > /dev/null
}

@test "the SVG card carries the live plugin count" {
  grep -q "1 PLUGINS" "$REPO/docs/assets/og-card.svg"
}

@test "the meta hash replaces the dev placeholder" {
  run grep -c 'og-image.png?v=dev' "$REPO/docs/index.html"
  [ "$output" -eq 0 ]
  grep -Eq 'og-image\.png\?v=[0-9a-f]{10}' "$REPO/docs/index.html"
}

@test "the rasterized PNG keeps the 1200x630 OG dimensions" {
  if ! command -v rsvg-convert > /dev/null 2>&1 && ! command -v vips > /dev/null 2>&1; then
    skip "no SVG rasterizer available"
  fi
  [ -f "$REPO/docs/assets/og-image.png" ]
  run node -e 'const b=require("fs").readFileSync(process.argv[1]);process.stdout.write(b.readUInt32BE(16)+"x"+b.readUInt32BE(20))' "$REPO/docs/assets/og-image.png"
  [ "$output" = "1200x630" ]
}
