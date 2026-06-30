#!/usr/bin/env bats
# test/build-pages/plugin-detail-pages.bats
#
# build-pages owns the public website. Plugin detail pages are generated from
# package READMEs so deep links stay synchronized with marketplace changes.

SCRIPT="$BATS_TEST_DIRNAME/../../bin/build-pages"

setup() {
  export REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p \
    "$REPO/.claude-plugin" \
    "$REPO/.agents/plugins" \
    "$REPO/packages/dibs/.claude-plugin" \
    "$REPO/packages/clipboard/.claude-plugin" \
    "$REPO/docs/agent-fieldkit/removed"

  cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "demo-marketplace",
  "plugins": [
    { "name": "dibs", "description": "demo dibs plugin", "source": "./packages/dibs" },
    { "name": "clipboard", "description": "demo clipboard plugin", "source": "./packages/clipboard" }
  ]
}
JSON
  cat > "$REPO/.agents/plugins/marketplace.json" <<'JSON'
{
  "name": "demo-marketplace",
  "plugins": [
    { "name": "dibs" },
    { "name": "clipboard" }
  ]
}
JSON
  cat > "$REPO/packages/dibs/.claude-plugin/plugin.json" <<'JSON'
{ "name": "dibs", "description": "demo dibs plugin", "version": "2.0.23" }
JSON
  cat > "$REPO/packages/clipboard/.claude-plugin/plugin.json" <<'JSON'
{ "name": "clipboard", "description": "demo clipboard plugin", "version": "2.0.10" }
JSON
  cat > "$REPO/packages/dibs/README.md" <<'MD'
# dibs

A single-occupancy lock for a working directory with an [external reference](https://example.test/dibs) and `inline code`.

## CLI

```bash
dibs claim <dir>
```

## Commands

| Command | Purpose |
|---------|---------|
| `dibs check` | Reports status |

- Claims a directory.
- Reports the current holder.
MD
  cat > "$REPO/packages/clipboard/README.md" <<'MD'
# clipboard

Copy answer content to a clipboard.
MD
  cat > "$REPO/docs/index.html" <<'HTML'
<link rel="canonical" href="https://example.test/old/">
<meta property="og:url" content="https://example.test/old/">
<meta property="og:image" content="https://example.test/assets/og-image.png?v=dev">
<meta property="og:image:secure_url" content="https://example.test/assets/og-image.png?v=dev">
<meta name="twitter:image" content="https://example.test/assets/og-image.png?v=dev">
HTML
  cat > "$REPO/docs/agent-fieldkit/removed/index.html" <<'HTML'
stale plugin page
HTML
  node "$SCRIPT" "$REPO" > /dev/null
}

@test "build-pages writes one detail page per current plugin" {
  [ -f "$REPO/docs/agent-fieldkit/dibs/index.html" ]
  [ -f "$REPO/docs/agent-fieldkit/clipboard/index.html" ]
}

@test "detail pages render package README content" {
  grep -q '<h1>dibs</h1>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q 'A single-occupancy lock for a working directory' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<h2 id="cli">CLI</h2>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<pre><code class="language-bash">dibs claim &lt;dir&gt;' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<a href="https://example.test/dibs">external reference</a>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<table>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q 'Reports status' "$REPO/docs/agent-fieldkit/dibs/index.html"
}

@test "detail pages expose canonical deep-link metadata" {
  grep -q '<title>dibs · l'\''Aicluse Agent Fieldkit</title>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<link rel="canonical" href="https://laicluse.com/agent-fieldkit/dibs/">' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<meta property="og:url" content="https://laicluse.com/agent-fieldkit/dibs/">' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<meta property="og:title" content="dibs · l'\''Aicluse Agent Fieldkit">' "$REPO/docs/agent-fieldkit/dibs/index.html"
}

@test "site data points catalog cards at generated detail pages" {
  run node -e 'const data=require(process.argv[1]); const plugin=data.plugins.find((item)=>item.name==="dibs"); process.stdout.write(plugin.detailPath)' "$REPO/docs/site-data.json"
  [ "$output" = "agent-fieldkit/dibs/" ]
}

@test "stale plugin detail pages are removed on rebuild" {
  [ ! -e "$REPO/docs/agent-fieldkit/removed/index.html" ]
}
