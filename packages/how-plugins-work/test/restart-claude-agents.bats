#!/usr/bin/env bats
# restart-claude-agents helper: lists running background agents and restarts
# them via claude --bg --resume, re-applying each agent's original launch flags
# from its job state so a bypassPermissions agent comes back in the same mode.

setup() {
  TESTDIR="$(mktemp -d)"
  export HOME="$TESTDIR/home"
  mkdir -p "$HOME/.claude/jobs/job1"

  export CLAUDE_BINARY="$TESTDIR/claude-stub"
  export AGENTS_JSON="$TESTDIR/agents.json"
  export CAPTURED="$TESTDIR/captured.txt"
  : > "$CAPTURED"

  cat > "$CLAUDE_BINARY" <<STUB
#!/usr/bin/env bash
if [ "\$1" = "agents" ]; then
  cat "$AGENTS_JSON"
  exit 0
fi
for arg in "\$@"; do printf '%s\n' "\$arg" >> "$CAPTURED"; done
echo "backgrounded · newjob · agentname"
STUB
  chmod +x "$CLAUDE_BINARY"

  cat > "$AGENTS_JSON" <<JSON
[
  {"pid":999999,"id":"job1","sessionId":"sess-1","cwd":"$TESTDIR","kind":"background","name":"agentname","status":"idle","state":"blocked"},
  {"pid":999998,"id":"jobdone","sessionId":"sess-2","cwd":"$TESTDIR","kind":"background","name":"doneagent","status":"idle","state":"done"}
]
JSON

  cat > "$HOME/.claude/jobs/job1/state.json" <<JSON
{"state":"blocked","respawnFlags":["--name","agentname","--permission-mode","bypassPermissions","--disallowedTools","Bash(gh pr merge*)","--setting-sources","user,project"],"resumeSessionId":"sess-1","intent":"/goal carry out the mission"}
JSON

  HELPER="${BATS_TEST_DIRNAME}/../bin/restart-claude-agents"
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "list shows running background agents and hides terminal ones" {
  run "$HELPER" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"job1"* ]]
  [[ "$output" == *"agentname"* ]]
  [[ "$output" != *"jobdone"* ]]
}

@test "restart preserves the original permission mode from job state" {
  run "$HELPER" restart job1
  [ "$status" -eq 0 ]
  grep -Fqx -- "--bg" "$CAPTURED"
  grep -Fqx -- "bypassPermissions" "$CAPTURED"
  grep -Fqx -- "--resume" "$CAPTURED"
  grep -Fqx -- "sess-1" "$CAPTURED"
}

@test "restart preserves the disallowed-tools deny list and re-passes the goal" {
  run "$HELPER" restart job1
  [ "$status" -eq 0 ]
  grep -Fqx -- "Bash(gh pr merge*)" "$CAPTURED"
  grep -Fqx -- "/goal carry out the mission" "$CAPTURED"
}
