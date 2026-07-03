#!/usr/bin/env bats
# test/build-pages/apps.bats
#
# build-pages emits a Vocalist product page alongside the plugin catalog. These
# assertions guard that the route, metadata, install one-liner, and release
# links stay aligned with the public Homebrew cask hand-off.

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

Demo package readme.
MD
  cat > "$REPO/docs/agent-fieldkit/index.html" <<'HTML'
<link rel="canonical" href="https://example.test/old/">
<meta property="og:url" content="https://example.test/old/">
<meta property="og:image" content="https://example.test/assets/og-image.png?v=dev">
<meta property="og:image:secure_url" content="https://example.test/assets/og-image.png?v=dev">
<meta name="twitter:image" content="https://example.test/assets/og-image.png?v=dev">
<link rel="stylesheet" href="styles.css">
<section id="apps"><div id="app-breakout"></div></section>
<script src="site.js"></script>
HTML
  node "$SCRIPT" "$REPO" > /dev/null
}

@test "site-data.json carries a Vocalist app breakout entry" {
  run node -e 'const a=require(process.argv[1]).apps||[];const v=a.find(x=>x.name==="Vocalist");process.exit(v?0:1)' "$REPO/docs/site-data.json"
  [ "$status" -eq 0 ]
}

@test "the Vocalist entry has the brew one-liner and Releases DMG URL" {
  run node -e 'const v=require(process.argv[1]).apps.find(x=>x.name==="Vocalist");const commands=(v.runCommands||[]).map(x=>x.command).join(" ");const ok=v.brew==="brew install --cask laicluse/tap/vocalist" && v.pluginInstall==="vocalist plugin install" && commands.includes("/vocalist:hands-free") && commands.includes("$vocalist:hands-free") && commands.includes("vocalist claude") && commands.includes("vocalist codex") && /github.com\/laicluse\/vocalist-releases\/releases/.test(v.dmgUrl);process.exit(ok?0:1)' "$REPO/docs/site-data.json"
  [ "$status" -eq 0 ]
}

@test "the Vocalist entry states the Tahoe requirement and lists features" {
  run node -e 'const v=require(process.argv[1]).apps.find(x=>x.name==="Vocalist");const ok=/Tahoe/.test(v.requirement) && Array.isArray(v.features) && v.features.length>=1;process.exit(ok?0:1)' "$REPO/docs/site-data.json"
  [ "$status" -eq 0 ]
}

@test "build-pages writes a standalone /vocalist product route" {
  [ -f "$REPO/docs/vocalist/index.html" ]
  grep -q '<link rel="canonical" href="https://laicluse.com/vocalist/">' "$REPO/docs/vocalist/index.html"
  grep -q '<meta property="og:url" content="https://laicluse.com/vocalist/">' "$REPO/docs/vocalist/index.html"
  grep -q '<meta property="og:site_name" content="l'"'"'Aicluse Apps">' "$REPO/docs/vocalist/index.html"
  grep -Eq '<meta property="og:image" content="https://laicluse\.com/assets/vocalist-og-image\.png\?v=[0-9a-f]{10}">' "$REPO/docs/vocalist/index.html"
  grep -Eq '<meta property="og:image:secure_url" content="https://laicluse\.com/assets/vocalist-og-image\.png\?v=[0-9a-f]{10}">' "$REPO/docs/vocalist/index.html"
  grep -Eq '<meta name="twitter:image" content="https://laicluse\.com/assets/vocalist-og-image\.png\?v=[0-9a-f]{10}">' "$REPO/docs/vocalist/index.html"
  run grep -q '<meta property="og:site_name" content="l'"'"'Aicluse Agent Fieldkit">' "$REPO/docs/vocalist/index.html"
  [ "$status" -ne 0 ]
  grep -q '<title>Vocalist</title>' "$REPO/docs/vocalist/index.html"
  grep -q '<a class="brand" href="../" aria-label="l'"'"'Aicluse Apps">' "$REPO/docs/vocalist/index.html"
  grep -q '<span class="wordmark" aria-hidden="true"></span><span class="brand-suffix">Apps</span><span class="sr-only">l'"'"'Aicluse Apps</span>' "$REPO/docs/vocalist/index.html"
  run grep -q 'brand-mark" aria-hidden="true">V</span>' "$REPO/docs/vocalist/index.html"
  [ "$status" -ne 0 ]
}

@test "build-pages writes a Vocalist-specific social card" {
  [ -f "$REPO/docs/assets/vocalist-og-card.svg" ]
  grep -q '>Apps<' "$REPO/docs/assets/vocalist-og-card.svg"
  grep -q 'Vocalist' "$REPO/docs/assets/vocalist-og-card.svg"
  grep -q 'Hands-free prompting' "$REPO/docs/assets/vocalist-og-card.svg"
  grep -q 'for Codex + Claude Code.' "$REPO/docs/assets/vocalist-og-card.svg"
  grep -q 'CMUX + terminal' "$REPO/docs/assets/vocalist-og-card.svg"
  grep -q 'Refactor notes' "$REPO/docs/assets/vocalist-og-card.svg"
  grep -q 'agent terminal' "$REPO/docs/assets/vocalist-og-card.svg"
  run node "$BATS_TEST_DIRNAME/assert-svg-text-bounds.js" "$REPO/docs/assets/vocalist-og-card.svg"
  [ "$status" -eq 0 ]
  run grep -E "Snell|l'Aicluse Apps" "$REPO/docs/assets/vocalist-og-card.svg"
  [ "$status" -ne 0 ]
  run grep -E 'PROMPT PREVIEW|brew install --cask|LOCAL STT|NO CLOUD|Agent Fieldkit' "$REPO/docs/assets/vocalist-og-card.svg"
  [ "$status" -ne 0 ]
  run grep -q 'Guardrails for coding agents' "$REPO/docs/assets/vocalist-og-card.svg"
  [ "$status" -ne 0 ]

  if ! command -v rsvg-convert > /dev/null 2>&1 && ! command -v vips > /dev/null 2>&1; then
    skip "no SVG rasterizer available"
  fi
  [ -f "$REPO/docs/assets/vocalist-og-image.png" ]
  run node -e 'const b=require("fs").readFileSync(process.argv[1]);process.stdout.write(b.readUInt32BE(16)+"x"+b.readUInt32BE(20))' "$REPO/docs/assets/vocalist-og-image.png"
  [ "$output" = "1200x630" ]
}

@test "the /vocalist route carries the public install and release links" {
  grep -q 'Install, connect, run' "$REPO/docs/vocalist/index.html"
  grep -q 'brew install --cask laicluse/tap/vocalist' "$REPO/docs/vocalist/index.html"
  grep -q 'vocalist plugin install' "$REPO/docs/vocalist/index.html"
  grep -q '<pre data-copyable><code>brew install --cask laicluse/tap/vocalist</code></pre>' "$REPO/docs/vocalist/index.html"
  grep -q '<pre data-copyable><code>vocalist plugin install</code></pre>' "$REPO/docs/vocalist/index.html"
  grep -Eq '<script src="../code-panel-copy\.js\?v=[0-9a-f]{10}"></script>' "$REPO/docs/vocalist/index.html"
  grep -q '3. Run Vocalist' "$REPO/docs/vocalist/index.html"
  grep -q '<code>/vocalist:hands-free</code>' "$REPO/docs/vocalist/index.html"
  grep -Fq '<code>$vocalist:hands-free</code>' "$REPO/docs/vocalist/index.html"
  grep -q '<code>vocalist claude</code>' "$REPO/docs/vocalist/index.html"
  grep -q '<code>vocalist codex</code>' "$REPO/docs/vocalist/index.html"
  grep -q 'https://github.com/laicluse/vocalist-releases/releases/latest' "$REPO/docs/vocalist/index.html"
  grep -q 'laicluse.com/vocalist' "$REPO/docs/vocalist/index.html"
  run grep -q 'epologee/tap/vocalist' "$REPO/docs/vocalist/index.html"
  [ "$status" -ne 0 ]
}

@test "the /vocalist route does not present the app as source-first" {
  run grep -E 'Source code|>GitHub<|github.com/epologee/vocalist</a>' "$REPO/docs/vocalist/index.html"
  [ "$status" -ne 0 ]
  run node -e 'const v=require(process.argv[1]).apps.find(x=>x.name==="Vocalist");process.exit(Object.hasOwn(v,"repoUrl")?1:0)' "$REPO/docs/site-data.json"
  [ "$status" -eq 0 ]
}

@test "the /vocalist route states the local transcription privacy posture" {
  grep -q 'Local Parakeet speech-to-text' "$REPO/docs/vocalist/index.html"
  grep -q 'no cloud, no API keys' "$REPO/docs/vocalist/index.html"
}

@test "the /vocalist route explains the app in user terms" {
  grep -q 'Mac menu-bar app' "$REPO/docs/vocalist/index.html"
  grep -q 'floating bubble' "$REPO/docs/vocalist/index.html"
  grep -q 'active agent terminal in CMUX' "$REPO/docs/vocalist/index.html"
  grep -q 'registered terminal session' "$REPO/docs/vocalist/index.html"
  grep -q 'frontmost app is a browser' "$REPO/docs/vocalist/index.html"
  grep -q 'Codex and Claude Code' "$REPO/docs/vocalist/index.html"
  grep -q 'Speech-to-text runs locally' "$REPO/docs/vocalist/index.html"
}

@test "the /vocalist route explains the two-piece app plus plugin setup" {
  grep -q 'Mac menu-bar app plus a coding-agent plugin' "$REPO/docs/vocalist/index.html"
  grep -q 'Homebrew installs the app, the CLI, and the bundled plugin marketplace' "$REPO/docs/vocalist/index.html"
  grep -q 'Agent plugin included' "$REPO/docs/vocalist/index.html"
  grep -q '/vocalist:hands-free' "$REPO/docs/vocalist/index.html"
  grep -Fq '$vocalist:hands-free' "$REPO/docs/vocalist/index.html"
  run grep -E '<code>/hands-free</code>|<code>\\$hands-free</code>|Claude Code /hands-free|Codex \\$hands-free' "$REPO/docs/vocalist/index.html"
  [ "$status" -ne 0 ]
  grep -q 'transcribed-turn' "$REPO/docs/vocalist/index.html"
}

@test "the /vocalist route marks spoken prompts with the microphone emoji first" {
  grep -Fq '🎙️ Refactor the release checklist and summarize what changed <span class="vocalist-command-token">[over]</span>' "$REPO/docs/vocalist/index.html"
  grep -q 'The leading <strong>🎙️</strong> is not decoration' "$REPO/docs/vocalist/index.html"
  grep -Fq '🎙️ Fix the relase checlist thing and run the tast that covers it <span class="vocalist-command-token">[over]</span>' "$REPO/docs/vocalist/index.html"
  grep -q 'id="transcribed-turn"' "$REPO/docs/vocalist/index.html"
  run grep -q ', over' "$REPO/docs/vocalist/index.html"
  [ "$status" -ne 0 ]
}

@test "the /vocalist route explains configurable multilingual voice commands" {
  grep -q 'Mapped words, not fixed words' "$REPO/docs/vocalist/index.html"
  grep -q 'In settings, choose which words' "$REPO/docs/vocalist/index.html"
  grep -q 'Multilingual on purpose' "$REPO/docs/vocalist/index.html"
  grep -q 'A single prompt can mix languages' "$REPO/docs/vocalist/index.html"
  grep -q 'Example mappings' "$REPO/docs/vocalist/index.html"
  grep -q '<code>over</code><span>Return</span><em>send the prompt</em>' "$REPO/docs/vocalist/index.html"
  grep -q '<code>scratch that</code><span>Escape</span><em>clear or cancel the pending turn</em>' "$REPO/docs/vocalist/index.html"
  run grep -E 'nu jij|nee opnieuw|nee onderbreken|volgende|vorige|naar rechts|naar links' "$REPO/docs/vocalist/index.html"
  [ "$status" -ne 0 ]
}

@test "the /vocalist route links full-duplex prompting to saysay" {
  grep -q 'Want full-duplex hands-free prompting' "$REPO/docs/vocalist/index.html"
  grep -q 'href="/agent-fieldkit/saysay/"' "$REPO/docs/vocalist/index.html"
  grep -q 'Use headphones' "$REPO/docs/vocalist/index.html"
  grep -q 'does not have echo cancellation yet' "$REPO/docs/vocalist/index.html"
}

@test "the /vocalist route explains voice commands and CMUX support" {
  grep -q 'Voice commands' "$REPO/docs/vocalist/index.html"
  grep -q 'spoken at the end of a turn' "$REPO/docs/vocalist/index.html"
  grep -q 'Deepest support is CMUX' "$REPO/docs/vocalist/index.html"
  grep -q 'Run it from your own terminal' "$REPO/docs/vocalist/index.html"
  grep -q '<code>vocalist claude</code>' "$REPO/docs/vocalist/index.html"
  grep -q '<code>vocalist codex</code>' "$REPO/docs/vocalist/index.html"
  run grep -q 'Other tmux-style apps would need an adapter' "$REPO/docs/vocalist/index.html"
  [ "$status" -ne 0 ]
}

@test "the /vocalist route includes a BYOT prompt for non-CMUX stacks" {
  grep -q 'B.Y.O.T.' "$REPO/docs/vocalist/index.html"
  grep -q 'Bring your own tokens' "$REPO/docs/vocalist/index.html"
  grep -q "So, you're not using a Mac, CMUX, or this exact terminal stack" "$REPO/docs/vocalist/index.html"
  grep -q 'Build a local voice-to-agent app like laicluse.com/vocalist for your own platform and terminal stack' "$REPO/docs/vocalist/index.html"
  grep -Fq 'Swift 6.2' "$REPO/docs/vocalist/index.html"
  grep -Fq 'FluidAudio 0.15.4' "$REPO/docs/vocalist/index.html"
  grep -Fq 'AsrModels.downloadAndLoad(version: .v3)' "$REPO/docs/vocalist/index.html"
  grep -Fq 'cmux top --all --processes --json' "$REPO/docs/vocalist/index.html"
  grep -Fq 'vocalist claude' "$REPO/docs/vocalist/index.html"
  grep -Fq 'vocalist codex' "$REPO/docs/vocalist/index.html"
  grep -Fq 'https://laicluse.com/vocalist/#transcribed-turn' "$REPO/docs/vocalist/index.html"
  grep -Fq '$conveyor:order-status' "$REPO/docs/vocalist/index.html"
  grep -q 'two pieces: the Mac app plus a small coding-agent plugin' "$REPO/docs/vocalist/index.html"
  grep -q 'This prompt was originally borrowed from laicluse.com/vocalist/' "$REPO/docs/vocalist/index.html"
  grep -q 'vocalist-byot-prompt' "$REPO/docs/styles.css"
  grep -q 'max-height: none;' "$REPO/docs/styles.css"
  grep -q 'overflow: visible;' "$REPO/docs/styles.css"
  grep -q 'white-space: pre-wrap;' "$REPO/docs/styles.css"
  grep -q 'display: block;' "$REPO/docs/styles.css"
}

@test "the /vocalist route includes a native technical layer diagram" {
  grep -q 'vocalist-layer-map' "$REPO/docs/vocalist/index.html"
  grep -q 'Capture, Segment, Transcribe, Shape, Deliver' "$REPO/docs/vocalist/index.html"
  grep -q 'CMUX or terminal pane' "$REPO/docs/vocalist/index.html"
  run grep -q 'vocalist-complexity-slide.png' "$REPO/docs/vocalist/index.html"
  [ "$status" -ne 0 ]
}

@test "the Fieldkit page exposes Vocalist as an app breakout" {
  grep -q 'id="apps"' "$BATS_TEST_DIRNAME/../../docs/agent-fieldkit/index.html"
  grep -q 'id="app-breakout"' "$BATS_TEST_DIRNAME/../../docs/agent-fieldkit/index.html"
  grep -q 'href="/vocalist/"' "$BATS_TEST_DIRNAME/../../docs/agent-fieldkit/index.html"
  grep -q 'siteHref(app.pagePath)' "$BATS_TEST_DIRNAME/../../docs/site.js"
}

@test "the /vocalist route avoids release-pipeline copy" {
  run grep -E 'One cask|signed app bundle|notarized artifact|cask points|DMG is published' "$REPO/docs/vocalist/index.html"
  [ "$status" -ne 0 ]
}

@test "the /vocalist route avoids internal terminal implementation jargon" {
  run grep -E 'focused cmux|coding-agent surface|\\$ focused' "$REPO/docs/vocalist/index.html"
  [ "$status" -ne 0 ]
}
