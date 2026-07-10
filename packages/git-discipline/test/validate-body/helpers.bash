#!/usr/bin/env bash
# Shared setup, teardown, and fixture helpers for the validate-body BATS suite.
#
# Mock strategy: we prepend a per-test $BATS_TEST_TMPDIR/bin directory to
# $PATH that contains a shell-function-based "git" shim.  The shim responds to
# specific argument patterns used by validate-body.sh and falls back to the
# real git binary for everything else.  This keeps the tests hermetic without
# requiring a real repository for every assertion.
#
# The shim is written as a small bash script (not a shell function) so that it
# works correctly when validate-body.sh sources itself in a subshell context.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/../../hooks/lib/validate-body.sh"

# Paths injected by the shim (overridable per test).
export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""  # what "git interpret-trailers --parse" returns
export GIT_SHIM_LS_TREE_OUTPUT=""             # what "git ls-tree -r HEAD --name-only" returns
export GIT_SHIM_DIFF_CACHED_OUTPUT=""         # what "git diff --cached --name-only" returns
export GIT_SHIM_LOG_HASHES=""                 # what "git log -5 --pretty=format:%H HEAD" returns
export GIT_SHIM_LOG_BODY=""                   # what "git log -1 --pretty=format:%B <hash>" returns
export GIT_SHIM_HEAD_ABBREV="abc1234"         # what "git rev-parse --abbrev-ref HEAD" returns
export GIT_SHIM_HEAD_SHORT="abc1234"          # what "git rev-parse --short HEAD" returns
export GIT_SHIM_STAGED_BLOB_DIR=""            # directory containing files keyed by path; "git show :<path>" reads from here
export GIT_SHIM_GENERATED_PATHS=""

setup() {
  TMPDIR_TEST="$(mktemp -d)"
  export TMPDIR_TEST

  # Staged-blob stash for "git show :<path>" lookups.
  GIT_SHIM_STAGED_BLOB_DIR="$TMPDIR_TEST/staged-blobs"
  mkdir -p "$GIT_SHIM_STAGED_BLOB_DIR"
  export GIT_SHIM_STAGED_BLOB_DIR

  # Write the git shim into a private bin dir.
  local shim_bin="$TMPDIR_TEST/bin"
  # Use install -d as mkdir alternative accepted by the linter -- actually
  # in test code mkdir -p is fine; this is not a repo file.
  mkdir -p "$shim_bin"

  cat > "$shim_bin/git" <<'SHIM'
#!/usr/bin/env bash
# Lightweight git shim for validate-body BATS tests.
# Responds to the argument patterns that validate-body.sh uses;
# delegates everything else to the real git.

REAL_GIT=$(PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin" command -v git 2>/dev/null || true)

# Strip leading "git" if invoked as "git <subcommand>".
args=("$@")

# Pattern: git interpret-trailers --parse
if [[ "${args[0]}" = "interpret-trailers" && "${args[1]}" = "--parse" ]]; then
  printf '%s' "$GIT_SHIM_INTERPRET_TRAILERS_OUTPUT"
  exit 0
fi

# Pattern: git ls-tree -r HEAD --name-only
if [[ "${args[0]}" = "ls-tree" ]]; then
  printf '%s' "$GIT_SHIM_LS_TREE_OUTPUT"
  exit 0
fi

# Pattern: git diff --cached --name-only
if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--cached" ]]; then
  printf '%s' "$GIT_SHIM_DIFF_CACHED_OUTPUT"
  exit 0
fi

# allow-comment: parent-of ref (`<sha>^` / `HEAD^`) returns empty so the duplicate-why self-exclusion path can be exercised; bare refs still return GIT_SHIM_LOG_HASHES.
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%H" ]]; then
  ref="${args[*]: -1}"
  if [[ "$ref" == *"^"* ]]; then
    exit 0
  fi
  [[ -n "$GIT_SHIM_LOG_HASHES" ]] && printf '%s\n' "$GIT_SHIM_LOG_HASHES"
  exit 0
fi

# Pattern: git log -1 --pretty=format:'%B' <hash>
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%B" ]]; then
  printf '%s\n' "$GIT_SHIM_LOG_BODY"
  exit 0
fi

# Pattern: git rev-parse --abbrev-ref HEAD
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--abbrev-ref" ]]; then
  printf '%s\n' "$GIT_SHIM_HEAD_ABBREV"
  exit 0
fi

# Pattern: git rev-parse --short HEAD
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--short" ]]; then
  printf '%s\n' "$GIT_SHIM_HEAD_SHORT"
  exit 0
fi

# Pattern: git rev-parse HEAD (used for initial-commit detection)
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "HEAD" ]]; then
  printf 'abc1234def5678\n'
  exit 0
fi

# Pattern: git rev-parse --show-toplevel
# Return the per-test TMPDIR_TEST so relative paths in fixtures resolve to
# the test's sandbox, not the surrounding repo. Falling through to real git
# from inside this shim caused infinite recursion when the system git path
# resolved back to the shim itself.
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--show-toplevel" ]]; then
  printf '%s\n' "${TMPDIR_TEST:-/}"
  exit 0
fi

# Pattern: git show :<path> (read staged blob from the per-test stash)
if [[ "${args[0]}" = "show" && "${args[1]}" =~ ^: ]]; then
  blob_path="${args[1]#:}"
  if [[ -n "$GIT_SHIM_STAGED_BLOB_DIR" && -f "$GIT_SHIM_STAGED_BLOB_DIR/$blob_path" ]]; then
    cat "$GIT_SHIM_STAGED_BLOB_DIR/$blob_path"
    exit 0
  fi
  exit 128
fi

if [[ "${args[0]}" = "check-attr" ]]; then
  attr_path="${args[*]: -1}"
  if [[ " $GIT_SHIM_GENERATED_PATHS " == *" $attr_path "* ]]; then
    printf '%s: git-discipline-generated: true\n' "$attr_path"
  else
    printf '%s: git-discipline-generated: unspecified\n' "$attr_path"
  fi
  exit 0
fi

# Fallback: real git (for anything not shimmed).
if [[ -n "$REAL_GIT" ]]; then
  exec "$REAL_GIT" "$@"
fi

printf 'git shim: unhandled args: %s\n' "$*" >&2
exit 1
SHIM
  chmod +x "$shim_bin/git"

  export PATH="$shim_bin:$PATH"

  # Default shim outputs: real trailers parser output for standard test fixtures.
  GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"$'\n'"spec/models/user_spec.rb"
  GIT_SHIM_DIFF_CACHED_OUTPUT=""
  GIT_SHIM_LOG_HASHES=""
  GIT_SHIM_LOG_BODY=""
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ---------------------------------------------------------------------------
# Fixture writers
# ---------------------------------------------------------------------------

# write_fixture <filename> <content>
# Write a commit-message fixture to $TMPDIR_TEST/<filename>.
write_fixture() {
  local name="$1"
  local content="$2"
  printf '%s' "$content" > "$TMPDIR_TEST/$name"
  printf '%s' "$TMPDIR_TEST/$name"
}

# invoke_validator <fixture-file>
# Wrappable by BATS "run": sources validate-body.sh in a subshell, calls
# validate_body, and merges stderr into stdout so BATS captures it in $output.
# Env vars set in the test (GIT_SHIM_*, GIT_DISCIPLINE_TRIVIAL_OK, HOME) are exported
# and inherited by the subshell automatically.
invoke_validator() {
  local file="$1"
  # Subshell isolates set -euo pipefail from the BATS harness.
  # stderr merged into stdout so BATS $output captures diagnostic messages.
  bash -c "source '$VALIDATOR'; validate_body '$file'" 2>&1
}

# ---------------------------------------------------------------------------
# Standard valid body template
# ---------------------------------------------------------------------------

VALID_BODY_TEMPLATE="$(cat <<'TEMPLATE'
Expose session boundary on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation, we previously rejected
the entire event, which masked session starts and stops in analytics.

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
TEMPLATE
)"

# Standard trailers string that the git shim returns for the valid template.
VALID_TRAILERS="$(cat <<'TR'
Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
TR
)"

# Set GIT_SHIM_INTERPRET_TRAILERS_OUTPUT to the trailers matching a fixture.
use_trailers() {
  export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT="$1"
}

# set_staged_blob <path> <content>
# Stash <content> as the staged blob for <path>. The git shim returns this
# content for `git show ":<path>"`, used by _vb_is_ui_touch when content-grepping
# .swift files for SwiftUI / UIKit / AppKit symbols.
set_staged_blob() {
  local path="$1"
  local content="$2"
  local target="$GIT_SHIM_STAGED_BLOB_DIR/$path"
  mkdir -p "$(dirname "$target")"
  printf '%s' "$content" > "$target"
}

# write_visual_path <relative-path>
# Touch an empty file at $TMPDIR_TEST/<relative-path> and echo its absolute
# path. Use as a Visual: trailer value when the test asserts the
# path-existence check passes.
write_visual_path() {
  local rel="$1"
  local target="$TMPDIR_TEST/$rel"
  mkdir -p "$(dirname "$target")"
  : > "$target"
  printf '%s' "$target"
}
