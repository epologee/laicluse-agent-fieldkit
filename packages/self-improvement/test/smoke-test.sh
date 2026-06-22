#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

source_skill="packages/self-improvement/skills/self-improvement/SKILL.md"
generated_skill=".agents/plugins/generated/self-improvement/skills/self-improvement/SKILL.md"
source_manifest="packages/self-improvement/.claude-plugin/plugin.json"
generated_manifest=".agents/plugins/generated/self-improvement/.codex-plugin/plugin.json"

ruby -ryaml -e '
  ARGV.each do |path|
    YAML.safe_load(File.read(path).split(/^---\s*$/)[1])
  end
' "$source_skill" "$generated_skill"

jq -e '.name == "self-improvement" and (.description | test("durable target"))' \
  "$source_manifest" >/dev/null
jq -e '.name == "self-improvement" and .interface.displayName == "Self Improvement"' \
  "$generated_manifest" >/dev/null

bin/plugin-adapters check . >/dev/null

if rg -n '/legacy marketplace|gitgit|Claude behavior|Claude Code ecosystem|~/.claude' \
  --glob '!packages/self-improvement/test/smoke-test.sh' \
  packages/self-improvement .agents/plugins/generated/self-improvement; then
  printf 'self-improvement smoke: legacy terms found\n' >&2
  exit 1
fi

printf 'self-improvement smoke: ok\n'
