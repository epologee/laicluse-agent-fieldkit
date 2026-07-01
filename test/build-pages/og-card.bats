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
  mkdir -p "$REPO/.claude-plugin" "$REPO/packages/demo/.claude-plugin" "$REPO/docs/agent-fieldkit"
  cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "demo-marketplace",
  "plugins": [ { "name": "demo", "description": "demo plugin", "source": "./packages/demo" } ]
}
JSON
  cat > "$REPO/packages/demo/.claude-plugin/plugin.json" <<'JSON'
{ "name": "demo", "description": "demo plugin", "version": "2.0.1" }
JSON
  cat > "$REPO/packages/demo/README.md" <<'MD'
# demo

Demo plugin.
MD
  cat > "$REPO/docs/index.html" <<'HTML'
<link rel="canonical" href="https://example.test/old/">
<meta property="og:url" content="https://example.test/old/">
<meta property="og:image" content="https://example.test/assets/og-image.png?v=dev">
<meta property="og:image:secure_url" content="https://example.test/assets/og-image.png?v=dev">
<meta name="twitter:image" content="https://example.test/assets/og-image.png?v=dev">
HTML
  cat > "$REPO/docs/agent-fieldkit/index.html" <<'HTML'
<link rel="canonical" href="https://example.test/old/">
<meta property="og:title" content="l'Aicluse Agent Fieldkit">
<meta property="og:description" content="A public Claude Code and Codex plugin marketplace for agent guardrails, workflow discipline, peer review, autonomous work, feedback repair, and changelogs.">
<meta property="og:url" content="https://example.test/old/">
<meta property="og:image" content="https://example.test/assets/og-image.png?v=dev">
<meta property="og:image:secure_url" content="https://example.test/assets/og-image.png?v=dev">
<meta name="twitter:title" content="l'Aicluse Agent Fieldkit">
<meta name="twitter:description" content="Guardrails for coding agents that touch real repositories. A public Claude Code and Codex plugin marketplace.">
<meta name="twitter:image" content="https://example.test/assets/og-image.png?v=dev">
<link rel="stylesheet" href="styles.css">
<script src="site.js"></script>
HTML
  node "$SCRIPT" "$REPO" > /dev/null
}

@test "the SVG card carries the live plugin count" {
  grep -q "1 PLUGINS" "$REPO/docs/assets/og-card.svg"
}

@test "the meta hash replaces the dev placeholder" {
  run grep -c 'og-image.png?v=dev' "$REPO/docs/index.html"
  [ "$output" -eq 0 ]
  run grep -c 'og-image.png?v=dev' "$REPO/docs/agent-fieldkit/index.html"
  [ "$output" -eq 0 ]
  grep -Eq 'og-image\.png\?v=[0-9a-f]{10}' "$REPO/docs/agent-fieldkit/index.html"
}

@test "the Fieldkit landing canonical and social URLs use the subdirectory URL" {
  grep -q '<link rel="canonical" href="https://laicluse.com/agent-fieldkit/">' "$REPO/docs/agent-fieldkit/index.html"
  grep -q '<meta property="og:url" content="https://laicluse.com/agent-fieldkit/">' "$REPO/docs/agent-fieldkit/index.html"
  grep -Eq '<meta property="og:image" content="https://laicluse\.com/assets/og-image\.png\?v=[0-9a-f]{10}">' "$REPO/docs/agent-fieldkit/index.html"
  grep -Eq '<meta property="og:image:secure_url" content="https://laicluse\.com/assets/og-image\.png\?v=[0-9a-f]{10}">' "$REPO/docs/agent-fieldkit/index.html"
  grep -Eq '<meta name="twitter:image" content="https://laicluse\.com/assets/og-image\.png\?v=[0-9a-f]{10}">' "$REPO/docs/agent-fieldkit/index.html"
}

@test "the root page redirects to Fieldkit with the same share card metadata" {
  grep -q '<meta http-equiv="refresh" content="0; url=/agent-fieldkit/">' "$REPO/docs/index.html"
  grep -q 'window.location.replace(target.href);' "$REPO/docs/index.html"
  grep -q '<link rel="canonical" href="https://laicluse.com/agent-fieldkit/">' "$REPO/docs/index.html"
  grep -q '<meta property="og:url" content="https://laicluse.com/agent-fieldkit/">' "$REPO/docs/index.html"
  run node - <<'NODE' "$REPO/docs/index.html" "$REPO/docs/agent-fieldkit/index.html"
const fs = require("fs");
const [rootPath, fieldkitPath] = process.argv.slice(2);
const root = fs.readFileSync(rootPath, "utf8");
const fieldkit = fs.readFileSync(fieldkitPath, "utf8");
const content = (html, pattern) => {
	const match = html.match(pattern);
	if (!match) throw new Error(`missing ${pattern}`);
	return match[1];
};
const fields = [
	/property="og:title" content="([^"]+)"/,
	/property="og:description" content="([^"]+)"/,
	/property="og:image" content="([^"]+)"/,
	/name="twitter:title" content="([^"]+)"/,
	/name="twitter:description" content="([^"]+)"/,
	/name="twitter:image" content="([^"]+)"/,
];
for (const field of fields) {
	const rootValue = content(root, field);
	const fieldkitValue = content(fieldkit, field);
	if (rootValue !== fieldkitValue) throw new Error(`${field} differs`);
}
NODE
  [ "$status" -eq 0 ]
}

@test "the Fieldkit landing loads shared assets from the parent directory" {
  grep -q '<link rel="stylesheet" href="../styles.css">' "$REPO/docs/agent-fieldkit/index.html"
  grep -q '<script src="../agent-command-switch.js"></script>' "$REPO/docs/agent-fieldkit/index.html"
  grep -q '<script src="../site.js"></script>' "$REPO/docs/agent-fieldkit/index.html"
}

@test "the rasterized PNG keeps the 1200x630 OG dimensions" {
  if ! command -v rsvg-convert > /dev/null 2>&1 && ! command -v vips > /dev/null 2>&1; then
    skip "no SVG rasterizer available"
  fi
  [ -f "$REPO/docs/assets/og-image.png" ]
  run node -e 'const b=require("fs").readFileSync(process.argv[1]);process.stdout.write(b.readUInt32BE(16)+"x"+b.readUInt32BE(20))' "$REPO/docs/assets/og-image.png"
  [ "$output" = "1200x630" ]
}
