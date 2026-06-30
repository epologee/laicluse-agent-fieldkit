#!/usr/bin/env bats
# test/build-pages/catalog-navigation.bats
#
# Browser-level checks for the generated static catalog experience.

DOCS_DIR="$BATS_TEST_DIRNAME/../../docs"

setup() {
  if ! python3 - <<'PY' >/dev/null 2>&1
from playwright.sync_api import sync_playwright
PY
  then
    skip "python playwright unavailable"
  fi

  export PORT
  PORT=$(python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)
  python3 -m http.server --bind 127.0.0.1 --directory "$DOCS_DIR" "$PORT" > "$BATS_TEST_TMPDIR/server.log" 2>&1 &
  export SERVER_PID=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fsS "http://127.0.0.1:$PORT/" >/dev/null; then
      return 0
    fi
    sleep 0.2
  done
  cat "$BATS_TEST_TMPDIR/server.log" >&2
  return 1
}

teardown() {
  if [ -n "${SERVER_PID:-}" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}

@test "mobile Browse plugins anchor scrolls below the sticky header" {
  run python3 - <<'PY'
import os
from playwright.sync_api import sync_playwright

with sync_playwright() as playwright:
	browser = playwright.chromium.launch()
	page = browser.new_page(viewport={"width": 390, "height": 1000})
	page.goto(f"http://127.0.0.1:{os.environ['PORT']}/#catalog")
	page.wait_for_timeout(250)
	result = page.evaluate("""() => {
const headerBottom = document.querySelector('.site-header').getBoundingClientRect().bottom;
const titleTop = document.querySelector('#catalog-title').getBoundingClientRect().top;
return { headerBottom, titleTop, clearsHeader: titleTop >= headerBottom + 8 };
}""")
	browser.close()
	if not result["clearsHeader"]:
		raise SystemExit(f"catalog title top {result['titleTop']} is under header bottom {result['headerBottom']}")
PY
  [ "$status" -eq 0 ]
}

@test "catalog cards expose an explicit Details action" {
  run python3 - <<'PY'
import os
from playwright.sync_api import sync_playwright

with sync_playwright() as playwright:
	browser = playwright.chromium.launch()
	page = browser.new_page(viewport={"width": 1440, "height": 1000})
	page.goto(f"http://127.0.0.1:{os.environ['PORT']}/")
	page.wait_for_selector('.plugin-grid .plugin-card')
	count = page.locator('article.plugin-card a[href="agent-fieldkit/dibs/"]', has_text='Details').count()
	browser.close()
	if count != 1:
		raise SystemExit(f"expected one dibs Details link, got {count}")
PY
  [ "$status" -eq 0 ]
}

@test "changelog plugin titles link to plugin detail pages" {
  run python3 - <<'PY'
import os
from playwright.sync_api import sync_playwright

with sync_playwright() as playwright:
	browser = playwright.chromium.launch()
	page = browser.new_page(viewport={"width": 1440, "height": 1000})
	page.goto(f"http://127.0.0.1:{os.environ['PORT']}/#changelog")
	page.wait_for_selector('.change-item')
	count = page.locator('article.change-item a[href="agent-fieldkit/dibs/"]', has_text='dibs').count()
	browser.close()
	if count != 1:
		raise SystemExit(f"expected one dibs changelog title detail link, got {count}")
PY
  [ "$status" -eq 0 ]
}
