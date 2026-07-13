#!/usr/bin/env bats

setup() {
	PACKAGE_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	REFERENCE="$PACKAGE_ROOT/skills/how-plugins-work/SKILL.md"
	CLOSEOUT="$PACKAGE_ROOT/skills/test-before-push/SKILL.md"
}

runtime_closeout_section() {
	awk '
		/^## Multi-agent runtime closeout$/ { active = 1; next }
		active && /^## / { exit }
		active { print }
	' "$REFERENCE"
}

@test "the general plugin workflow installs and verifies both runtimes" {
	run runtime_closeout_section
	[ "$status" -eq 0 ]
	[[ "$output" == *"claude plugins update"* ]]
	[[ "$output" == *"codex plugin add"* ]]
	[[ "$output" == *"installed_plugins.json"* ]]
	[[ "$output" == *"codex plugin list --json"* ]]
}

@test "the runtime closeout routes plugin work before completion or push" {
	run ruby -ryaml -e '
		parts = File.read(ARGV.fetch(0)).split(/^---\s*$/)
		puts YAML.safe_load(parts.fetch(1)).fetch("description")
	' "$CLOSEOUT"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Claude Code and Codex"* ]]
	[[ "$output" == *"before completion or push"* ]]
}
