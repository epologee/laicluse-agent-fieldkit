#!/usr/bin/env bats

setup() {
  SKILL="$BATS_TEST_DIRNAME/skills/scar-tissue/SKILL.md"
}

migration_section() {
  awk '
    /^## Migration without residue$/ { active = 1; next }
    active && /^## / { exit }
    active { print }
  ' "$SKILL"
}

@test "migration guidance leaves one canonical implementation" {
  run migration_section
  [ "$status" -eq 0 ]
  [[ "$output" =~ canonical[[:space:]]+implementation ]]
  [[ "$output" =~ plugin.*tombstone ]]
  [[ "$output" =~ skill.*remove ]]
}

@test "migration design triggers the scar-tissue review" {
  run ruby -ryaml -e '
    parts = File.read(ARGV.fetch(0)).split(/^---\s*$/)
    puts YAML.safe_load(parts.fetch(1)).fetch("description")
  ' "$SKILL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"migration"* ]]
  [[ "$output" == *"compatibility"* ]]
}
