#!/usr/bin/env bats

load helpers

setup() {
  dibs_clear_ambient_identity
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  DIBS="$REPO_ROOT/packages/dibs/bin/dibs"
  NODE_BIN="$(command -v node)"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  DIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$DIR"
  DIR="$(cd "$DIR" && pwd -P)"
}

resolve() {
  printf '%s' "$1" | "$NODE_BIN" "$DIBS" resolve
}

@test "resolve reads the session the host put in the payload" {
  payload="$(jq -cn --arg cwd "$DIR" '{session_id:"sess-payload", cwd:$cwd, tool_name:"Write", tool_input:{file_path:($cwd+"/f.txt")}}')"

  run resolve "$payload"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.session' <<< "$output")" = "sess-payload" ]
  [ "$(jq -r '.workdir' <<< "$output")" = "$DIR" ]
}

@test "resolve falls back to the environment when the payload carries no session" {
  payload="$(jq -cn --arg cwd "$DIR" '{cwd:$cwd, tool_name:"Bash", tool_input:{command:"true"}}')"

  run bash -c 'printf "%s" "$1" | CLAUDE_CODE_SESSION_ID=sess-env "$2" "$3" resolve' _ "$payload" "$NODE_BIN" "$DIBS"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.session' <<< "$output")" = "sess-env" ]
}

@test "resolve names every field it could not determine" {
  payload="$(jq -cn '{tool_name:"Bash", tool_input:{command:"true"}}')"

  run resolve "$payload"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.missing | index("session")' <<< "$output")" != "null" ]
  [ "$(jq -r '.missing | index("workdir")' <<< "$output")" != "null" ]
  [ "$(jq -r '.missing | index("description")' <<< "$output")" != "null" ]
}

@test "resolve reports a Codex payload without a workdir as missing, not as the conversation dir" {
  payload="$(jq -cn --arg cwd "$DIR" '{session_id:"sess-codex", cwd:$cwd, tool_name:"Bash", tool_input:{command:"rm -rf build"}}')"

  run bash -c 'printf "%s" "$1" | PLUGIN_ROOT=/somewhere "$2" "$3" resolve' _ "$payload" "$NODE_BIN" "$DIBS"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.agent' <<< "$output")" = "codex" ]
  [ "$(jq -r '.workdir' <<< "$output")" = "" ]
  [ "$(jq -r '.conversationDir' <<< "$output")" = "$DIR" ]
  [ "$(jq -r '.missing | index("workdir")' <<< "$output")" != "null" ]
}

@test "resolve prefers the Codex thread identifiers for owner" {
  payload="$(jq -cn --arg cwd "$DIR" '{session_id:"sess-codex", cwd:$cwd, tool_name:"Write", tool_input:{file_path:($cwd+"/f.txt")}}')"

  run bash -c 'printf "%s" "$1" | PLUGIN_ROOT=/somewhere CMUX_TAB_ID=tab-7 "$2" "$3" resolve' _ "$payload" "$NODE_BIN" "$DIBS"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.owner' <<< "$output")" = "tab-7" ]
}

@test "resolve keeps an explicit agent override" {
  payload="$(jq -cn --arg cwd "$DIR" '{session_id:"s", cwd:$cwd, tool_name:"Write", tool_input:{file_path:($cwd+"/f.txt")}}')"

  run bash -c 'printf "%s" "$1" | PLUGIN_ROOT=/somewhere DIBS_AGENT=claude "$2" "$3" resolve' _ "$payload" "$NODE_BIN" "$DIBS"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.agent' <<< "$output")" = "claude" ]
}
