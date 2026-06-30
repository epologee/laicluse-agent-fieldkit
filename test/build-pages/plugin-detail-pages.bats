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

## Parser cases

| Prompt input | What the session writes | Expected hits |
|--------------|-------------------------|---------------|
| Plate audit | Pattern `plate-outside-formatter`: run `rg -n '\\(plate\\|kenteken)\\b' Sources/` | One regex cell |

## Code spans

Nested JS template literals (`` `${`inner //`}` ``) may close the outer template state early.

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
  cat > "$REPO/docs/agent-fieldkit/index.html" <<'HTML'
<link rel="canonical" href="https://example.test/old/">
<meta property="og:url" content="https://example.test/old/">
<meta property="og:image" content="https://example.test/assets/og-image.png?v=dev">
<meta property="og:image:secure_url" content="https://example.test/assets/og-image.png?v=dev">
<meta name="twitter:image" content="https://example.test/assets/og-image.png?v=dev">
<link rel="stylesheet" href="styles.css">
<script src="site.js"></script>
HTML
  cat > "$REPO/docs/agent-fieldkit/removed/index.html" <<'HTML'
stale plugin page
HTML
  node "$SCRIPT" "$REPO" > /dev/null
}

@test "build-pages writes one detail page per current plugin" {
  [ -f "$REPO/docs/agent-fieldkit/index.html" ]
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

@test "README tables keep escaped pipes inside code spans in the same cell" {
  run node - <<'NODE' "$REPO/docs/agent-fieldkit/dibs/index.html"
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const table = html.match(/<h2 id="parser-cases">Parser cases<\/h2>\n(<table>[\s\S]*?<\/table>)/);
if (!table) throw new Error("parser cases table not found");
const rows = [...table[1].matchAll(/<tr>([\s\S]*?)<\/tr>/g)].map((match) => match[1]);
const bodyRow = rows[rows.length - 1];
const bodyCells = [...bodyRow.matchAll(/<td>/g)].length;
if (bodyCells !== 3) throw new Error(`expected 3 body cells, got ${bodyCells}`);
if (!bodyRow.includes("\\\\|kenteken")) throw new Error("escaped pipe moved out of regex cell");
NODE
  [ "$status" -eq 0 ]
}

@test "README rendering supports variable-length backtick code spans" {
  run node - <<'NODE' "$REPO/docs/agent-fieldkit/dibs/index.html"
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
if (!html.includes("<code>`${`inner //`}`</code>")) {
  throw new Error("variable-length backtick code span did not render as one code element");
}
NODE
  [ "$status" -eq 0 ]
}

@test "detail pages expose canonical deep-link metadata" {
  grep -q '<title>dibs · l'\''Aicluse Agent Fieldkit</title>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<link rel="canonical" href="https://laicluse.com/agent-fieldkit/dibs/">' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<meta property="og:url" content="https://laicluse.com/agent-fieldkit/dibs/">' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<meta property="og:title" content="dibs · l'\''Aicluse Agent Fieldkit">' "$REPO/docs/agent-fieldkit/dibs/index.html"
}

@test "detail pages link back to the Fieldkit landing" {
  grep -q '<link rel="stylesheet" href="../../styles.css">' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<a class="brand" href="../" aria-label="l'\''Aicluse Agent Fieldkit home">' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<a href="../#catalog">Catalog</a>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<a class="back-link" href="../#catalog">Catalog</a>' "$REPO/docs/agent-fieldkit/dibs/index.html"
}

@test "site data points catalog cards at generated detail pages" {
  run node -e 'const data=require(process.argv[1]); const plugin=data.plugins.find((item)=>item.name==="dibs"); process.stdout.write(plugin.detailPath)' "$REPO/docs/site-data.json"
  [ "$output" = "agent-fieldkit/dibs/" ]
}

@test "stale plugin detail pages are removed on rebuild" {
  [ ! -e "$REPO/docs/agent-fieldkit/removed/index.html" ]
}
