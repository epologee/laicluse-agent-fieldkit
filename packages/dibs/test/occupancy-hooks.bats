#!/usr/bin/env bats
# Contract tests for the dibs occupancy enforcement hook. End-to-end cases run
# the real hooks/occupancy.sh; unit cases source it (the main dispatch is
# guarded behind a sourced-vs-executed check). A temp LAICLUSE_HOME keeps the
# lock store hermetic and DIBS_HOLDER_PID pins the recorded holder pid.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  HOOK="$REPO_ROOT/packages/dibs/hooks/occupancy.sh"
  NODE_BIN="$(command -v node)"
  export DIBS_BIN="$REPO_ROOT/packages/dibs/bin/dibs"
  export CLAUDE_PLUGIN_ROOT="$REPO_ROOT/packages/dibs"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  DIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$DIR"
}

dibs() { "$NODE_BIN" "$DIBS_BIN" "$@"; }

emit() {
  jq -nc --arg e "$1" --arg t "$2" --arg cwd "$DIR" \
    '{hook_event_name:$e, tool_name:$t, cwd:$cwd, session_id:"sess-1", tool_input:{file_path:($cwd+"/f.txt"), content:"x"}}'
}

run_hook() {
  emit "$1" "$2" > "$BATS_TEST_TMPDIR/in.json"
  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
}

@test "gate hard-denies a write when a live other-session agent holds the dir" {
  sleep 60 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '\[dibs/occupancy\]'
  echo "$output" | grep -qi "held by codex"
  echo "$output" | grep -qi "since"
}

@test "gate allows a different live pid of the SAME session (no self-lockout)" {
  sleep 60 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent claude --session sess-1 >/dev/null
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q '\[dibs/occupancy\]'
}

@test "gate allows a resumed codex owner even when the session id changed" {
  sleep 60 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session old-thread --owner cmux-tab-1 >/dev/null
  export DIBS_HOLDER_PID=$$ PLUGIN_ROOT="$REPO_ROOT/packages/dibs" CMUX_TAB_ID=cmux-tab-1
  jq -nc --arg cwd "$DIR" '{hook_event_name:"PreToolUse", tool_name:"Write", cwd:$cwd, session_id:"new-thread", tool_input:{file_path:($cwd+"/f.txt"), content:"x"}}' > "$BATS_TEST_TMPDIR/in.json"

  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
  local rc=$status
  run dibs check "$DIR" --json
  kill "$other" 2>/dev/null || true

  [ "$rc" -eq 0 ]
  ! echo "$output" | grep -q '\[dibs/occupancy\]'
  echo "$output" | grep -q "\"pid\": $$"
}

@test "SessionStart resume reclaims an older ownerless foreign codex lock" {
  dibs claim "$DIR" --pid $$ --agent codex --session old-thread >/dev/null
  local lockpath
  lockpath="$(dibs check "$DIR" --json | jq -r '.path')"
  jq '.hostname="some-other-host" | del(.owner)' "$lockpath" > "$lockpath.tmp"
  mv "$lockpath.tmp" "$lockpath"
  export DIBS_HOLDER_PID=$$ PLUGIN_ROOT="$REPO_ROOT/packages/dibs" CMUX_TAB_ID=cmux-tab-1
  jq -nc --arg cwd "$DIR" '{hook_event_name:"SessionStart", source:"resume", cwd:$cwd, session_id:"new-thread"}' > "$BATS_TEST_TMPDIR/in.json"

  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
  local rc=$status
  run dibs check "$DIR" --json

  [ "$rc" -eq 0 ]
  echo "$output" | grep -q "\"pid\": $$"
  echo "$output" | grep -q '"owner": "cmux-tab-1"'
}

@test "gate allows a free dir and records occupancy" {
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q "\"pid\": $$"
}

@test "gate self-heals a dead holder and allows the write" {
  sleep 60 & local dead=$!
  dibs claim "$DIR" --pid "$dead" --agent claude >/dev/null
  kill "$dead"; wait "$dead" 2>/dev/null || true
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  [ "$status" -eq 0 ]
}

@test "gate fails open when the dir does not exist" {
  rmdir "$DIR"
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  [ "$status" -eq 0 ]
}

@test "gate fails open when the payload carries no cwd" {
  sleep 60 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$
  jq -nc '{hook_event_name:"PreToolUse", tool_name:"Write", session_id:"sess-1", tool_input:{file_path:"/tmp/x.ts", content:"x"}}' > "$BATS_TEST_TMPDIR/in.json"
  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q '\[dibs/occupancy\]'
}

@test "gate fails open when the payload carries no session id" {
  sleep 60 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$
  jq -nc --arg cwd "$DIR" '{hook_event_name:"PreToolUse", tool_name:"Write", cwd:$cwd, tool_input:{file_path:($cwd+"/f.txt"), content:"x"}}' > "$BATS_TEST_TMPDIR/in.json"
  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "apply_patch gates the target git worktree instead of an occupied parent cwd" {
  local parent="$BATS_TEST_TMPDIR/repo"
  local child="$parent/worktrees/child"
  mkdir -p "$parent"
  git -C "$parent" init >/dev/null
  git -C "$parent" config user.email test@example.invalid
  git -C "$parent" config user.name Test
  echo root > "$parent/README.md"
  git -C "$parent" add README.md
  git -C "$parent" commit -m init >/dev/null
  git -C "$parent" worktree add -b child "$child" >/dev/null

  sleep 60 & local other=$!
  dibs claim "$parent" --pid "$other" --agent claude --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$
  jq -nc --arg cwd "$parent" --arg target "$child/new.txt" '
    {
      hook_event_name:"PreToolUse",
      tool_name:"apply_patch",
      cwd:$cwd,
      session_id:"sess-1",
      tool_input:{patch:"*** Begin Patch\n*** Add File: \($target)\n+ok\n*** End Patch\n"}
    }' > "$BATS_TEST_TMPDIR/in.json"

  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
  local rc=$status
  run dibs check "$child" --json
  kill "$other" 2>/dev/null || true
  [ "$rc" -eq 0 ]
  echo "$output" | grep -q "\"pid\": $$"
}

@test "SessionStart steers aside (no block) when a live other-session agent holds the dir" {
  sleep 60 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$
  run_hook SessionStart startup
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "SessionStart"
  echo "$output" | grep -qi "held by codex"
  echo "$output" | grep -qi "step aside"
}

@test "SessionStart claims a free dir silently" {
  export DIBS_HOLDER_PID=$$
  run_hook SessionStart startup
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q "\"pid\": $$"
}

@test "SessionStart surfaces enforcement-off when dibs cannot be resolved" {
  export DIBS_BIN="$BATS_TEST_TMPDIR/nonexistent-dibs"
  export CLAUDE_PLUGIN_ROOT="$BATS_TEST_TMPDIR/nowhere"
  export DIBS_HOLDER_PID=$$
  source "$HOOK"
  occ_dibs_bin() { return 1; }
  run occ_claim "$(emit SessionStart startup)"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "enforcement is OFF"
}

@test "SessionEnd releases the dir the holder held" {
  export DIBS_HOLDER_PID=$$
  dibs claim "$DIR" --pid $$ --agent claude >/dev/null
  run_hook SessionEnd ""
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"state": "free"'
}

@test "SessionEnd does not disturb a dir held by another agent" {
  sleep 60 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$
  run_hook SessionEnd ""
  local rc=$status
  run dibs check "$DIR" --json
  kill "$other" 2>/dev/null || true
  [ "$rc" -eq 0 ]
  echo "$output" | grep -q '"agent": "codex"'
}

@test "the recorded holder pid equals DIBS_HOLDER_PID, not the hook shell" {
  export DIBS_HOLDER_PID=$$
  run_hook SessionStart startup
  [ "$status" -eq 0 ]
  local lockpath
  lockpath="$(dibs check "$DIR" --json | jq -r '.path')"
  run jq -r '.pid' "$lockpath"
  [ "$output" = "$$" ]
}

@test "DIBS_OCCUPANCY=off disables enforcement entirely" {
  sleep 60 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$ DIBS_OCCUPANCY=off
  run_hook PreToolUse Write
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q '\[dibs/occupancy\]'
}

@test "holder pid walk resolves the nearest claude/codex ancestor (hermetic fake ps)" {
  unset DIBS_HOLDER_PID
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/ps" <<'PS'
#!/bin/bash
mode="$2"; pid="$4"
if [ "$mode" = "comm=" ]; then
  case "$pid" in
    100) echo "/usr/bin/foo" ;;
    200) echo "/usr/local/bin/node" ;;
    300) echo "/Users/x/.local/share/claude/versions/2.1.179" ;;
    400) echo "/bin/zsh" ;;
  esac
elif [ "$mode" = "ppid=" ]; then
  case "$pid" in
    100) echo 200 ;; 200) echo 300 ;; 300) echo 400 ;; 400) echo 1 ;;
  esac
fi
PS
  chmod +x "$BATS_TEST_TMPDIR/bin/ps"
  source "$HOOK"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run occ_holder_pid 100
  [ "$status" -eq 0 ]
  [ "$output" = "300" ]
}

@test "holder pid walk picks the inner codex, not the outer claude it runs under (hermetic fake ps)" {
  unset DIBS_HOLDER_PID
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/ps" <<'PS'
#!/bin/bash
mode="$2"; pid="$4"
if [ "$mode" = "comm=" ]; then
  case "$pid" in
    100) echo "/bin/bash" ;;
    250) echo "/Users/x/.codex/packages/standalone/releases/codex-path/codex" ;;
    350) echo "/usr/local/bin/node" ;;
    450) echo "/Users/x/.local/bin/claude" ;;
  esac
elif [ "$mode" = "ppid=" ]; then
  case "$pid" in
    100) echo 250 ;; 250) echo 350 ;; 350) echo 450 ;; 450) echo 1 ;;
  esac
fi
PS
  chmod +x "$BATS_TEST_TMPDIR/bin/ps"
  source "$HOOK"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run occ_holder_pid 100
  [ "$status" -eq 0 ]
  [ "$output" = "250" ]
}

@test "a codex launched under a claude session still labels itself codex" {
  source "$HOOK"
  PLUGIN_ROOT="/some/codex/cache" CLAUDE_PLUGIN_ROOT="/some/codex/cache" run occ_agent_label
  [ "$status" -eq 0 ]
  [ "$output" = "codex" ]
}
