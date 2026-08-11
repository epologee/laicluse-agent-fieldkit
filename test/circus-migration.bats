#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	CIRCUS="$REPO_ROOT/packages/circus/bin/circus"
}

@test "Circus owns Fieldkit adapter generation and versioning" {
	[ -x "$CIRCUS" ]
	[ "$(cat "$REPO_ROOT/.plugin-version-prefix")" = "2.0" ]

	run "$CIRCUS" plugins --help
	[ "$status" -eq 0 ]
	[[ "$output" == *"circus plugins versions"* ]]

	[ ! -e "$REPO_ROOT/bin/plugin-adapters" ]
	[ ! -e "$REPO_ROOT/bin/plugin-versions" ]
}

@test "Fieldkit pre-commit invokes the canonical Circus package" {
	run grep -F 'packages/circus/bin/circus' "$REPO_ROOT/hooks/pre-commit"
	[ "$status" -eq 0 ]
}
