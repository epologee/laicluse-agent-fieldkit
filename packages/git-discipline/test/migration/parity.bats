#!/usr/bin/env bats
# packages/git-discipline/test/migration/parity.bats
#
# Proves that the migrated commit-subject and commit-format guards behave
# identically to the old dont-do-that guards in every observable contract:
#
#   1. A subject starting with "Fix " is denied with the [git-discipline/commit-subject]
#      mnemonic (previously [dont-do-that/commit-rule]).
#   2. The ack-rule token resolves a pending state: "# ack-rule12:bewijsstuk"
#      with the right rule-number+wachtwoord pair clears a pending rotation
#      reminder; the pair must match the mnemonic in rotation-rules.sh.
#   3. The state file is read from the new path; old state is migrated forward.
#   4. A subject starting with "Address review" is denied with rule 2.
#   5. commit-format denials use [git-discipline/commit-format] mnemonic.

GIT_DISCIPLINE_DISPATCH="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/hooks/dispatch.sh"

pretool_bash() {
  local cmd="$1"
  jq -cn --arg c "$cmd" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:$c}}'
}

setup() {
  TEST_REPO="$BATS_TEST_TMPDIR/repo"
  git init -q -b main "$TEST_REPO"
  git -C "$TEST_REPO" config user.name "Test Author"
  git -C "$TEST_REPO" config user.email "test@example.com"
  git -C "$TEST_REPO" -c core.hooksPath=/dev/null commit -q --allow-empty -m "Initial commit"
  cd "$TEST_REPO"

  # Each test gets its own isolated state file.
  STATE_FILE="$BATS_TEST_TMPDIR/commit-rule-state"
  : > "$STATE_FILE"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$STATE_FILE"
  # Ensure no old-path variable leaks in.
  unset CLAUDE_COMMIT_RULE_STATE_FILE
}

teardown() {
  rm -f "$STATE_FILE"
}

# --- 1. Fix-prefix denied with git-discipline mnemonic ---

@test "subject starting with Fix is denied with [git-discipline/commit-subject]" {
  run bash -c "echo '$(pretool_bash 'git commit -m "Fix the typo"')' | bash '$GIT_DISCIPLINE_DISPATCH' 2>&1 >/dev/null"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '\[git-discipline/commit-subject\]'
  echo "$output" | grep -q 'Rule 1/15'
}

# --- 2. ack-rule token clears pending state ---

@test "ack-rule clears Fix violation: ack-rule1:gedrag on rewrite passes" {
  # First call establishes a pending violation for Fix.
  echo "$(pretool_bash 'git commit -m "Fix the typo"')" | bash "$GIT_DISCIPLINE_DISPATCH" >/dev/null 2>/dev/null || true

  # Second call: clean subject + ack-rule1 must pass.
  run bash -c "echo '$(pretool_bash 'git commit -m "Use correct policy on read path" # ack-rule1:gedrag')' | bash '$GIT_DISCIPLINE_DISPATCH' 2>&1"
  [ "$status" -eq 0 ]
}

@test "ack-rule clears rotation reminder: ack-rule12:bewijsstuk advances state" {
  # Advance rotation to slot 12 (idx 11, rule 12) by walking through earlier slots.
  # Slot order: 3 4 5 6 7 8 9 10 11 12 13 14 (0-indexed 0..11 in _DD_ROTATION_SLOTS).
  # Slot index 8 in the array is rule 12 (1-indexed). We need rp=8 in state file.
  # Write state directly: pv=-1 pr=-1 rp=8 (points to slot index 8 => rule index 11 => rule 12).
  printf '%s\n' '-1' '-1' '8' > "$STATE_FILE"

  # Clean commit should surface rule 12 reminder.
  run bash -c "echo '$(pretool_bash 'git commit -m "Introduce session context guard"')' | bash '$GIT_DISCIPLINE_DISPATCH' 2>&1 >/dev/null"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q 'Rule 12/15'

  # Now ack-rule12 should pass it.
  run bash -c "echo '$(pretool_bash 'git commit -m "Introduce session context guard" # ack-rule12:bewijsstuk')' | bash '$GIT_DISCIPLINE_DISPATCH' 2>&1"
  [ "$status" -eq 0 ]
}

# --- 3. State file migration: old path copied to new path ---

@test "old commit-rule-state is migrated to new git-discipline-commit-rule-state on first run" {
  OLD_STATE="$(mktemp)"
  NEW_STATE="$(mktemp)"
  rm -f "$NEW_STATE"  # simulate new path not yet existing

  # Write a clean rotation state to the old file.
  printf '%s\n' '-1' '-1' '0' > "$OLD_STATE"

  export CLAUDE_COMMIT_RULE_STATE_FILE="$OLD_STATE"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$NEW_STATE"

  # Trigger the guard; it should copy OLD to NEW.
  echo "$(pretool_bash 'git commit -m "Use policy on the read path"')" \
    | bash "$GIT_DISCIPLINE_DISPATCH" >/dev/null 2>/dev/null || true

  [ -f "$NEW_STATE" ]

  rm -f "$OLD_STATE" "$NEW_STATE"
  unset CLAUDE_COMMIT_RULE_STATE_FILE
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$STATE_FILE"
}

# --- 4. "Address review" denied with rule 2 ---

@test "subject starting with Address review is denied with Rule 2/15" {
  run bash -c "echo '$(pretool_bash 'git commit -m "Address review findings"')' | bash '$GIT_DISCIPLINE_DISPATCH' 2>&1 >/dev/null"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '\[git-discipline/commit-subject\]'
  echo "$output" | grep -q 'Rule 2/15'
}

# --- 5. commit-format uses [git-discipline/commit-format] mnemonic ---

@test "subject over 72 chars is denied with [git-discipline/commit-format]" {
  printf 'pv=-1\npr=3\nrp=0\nack_pending_sha=\n' > "$STATE_FILE"
  run bash -c "echo '$(pretool_bash 'git commit -m "Override the upstream defaults that nudge multi-line commits into a heredoc form." # ack-rule4:essentie')' | bash '$GIT_DISCIPLINE_DISPATCH' 2>&1"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '\[git-discipline/commit-format\]'
  echo "$output" | grep -q 'max 72'
}
