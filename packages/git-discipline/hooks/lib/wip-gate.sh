#!/bin/bash
# packages/git-discipline/hooks/lib/wip-gate.sh
#
# Shared library for the slice-7 wip-gate. Sourced by both the PreToolUse:Bash
# guard (hooks/guards/push-wip-gate.sh) and the git-native pre-push hook
# (skills/commit-discipline/git-hooks/pre-push). Single source of truth so the
# two enforcement paths cannot drift.
#
# The gate inspects the commits that are about to be pushed and looks at each
# commit body for a Slice trailer. When Slice equals exactly "wip", the commit
# is a work-in-progress commit and pushing it should be blocked unless the
# operator explicitly opts in.
#
# Public functions:
#   wip_gate_parse_range <upstream-ref> <local-ref>
#       Echoes the rev-list range covering <local-ref> minus the upstream and
#       minus the resolved default branch. A force-push after a rebase reports
#       the pre-rebase remote tip as its upstream, so excluding the default
#       branch as well keeps the commits the branch caught up on out of the
#       range. When neither ref resolves (initial push of a new branch in a
#       repo without an origin HEAD), echoes just "<local>" so git rev-list
#       scans every reachable commit on the new branch.
#   wip_gate_scoped_range <local-ref> <exclude-ref>...
#       Builds that range from a local ref and any number of exclusions,
#       dropping the ones that do not resolve. A single exclusion keeps the
#       readable "<exclude>..<local>" form; several emit "^a ^b <local>".
#   wip_gate_rev_list <range>
#       Runs git rev-list over a range built by the functions above. A range is
#       one or more arguments, so every caller reads it through this function
#       rather than expanding it itself.
#   wip_gate_find_wip_commits <range>
#       For each commit in <range>, parses the body via
#       `git interpret-trailers --parse` and emits the SHA on stdout when the
#       Slice trailer value is exactly "wip" (case-insensitive on the key,
#       case-sensitive on the value to match validate-body's behaviour).
#   wip_gate_should_block <bash-command-or-empty> <wip-count>
#       Returns 0 (block) when wip-count > 0 AND no bypass is active.
#       Returns 1 (allow) otherwise.
#       Bypass paths:
#         - GIT_DISCIPLINE_ALLOW_WIP_PUSH=1 in the current environment
#         - The literal string "# allow-wip-push" appears anywhere in the
#           bash command (the second argument). The git-native hook passes
#           an empty string and only the env var bypass applies there.
#   wip_gate_format_message <wip-sha-list>
#       Multi-line human-readable message naming each wip commit with its
#       short SHA + subject, plus the bypass instructions.
#   wip_gate_log_bypass <sha-csv> <branch> <mechanism>
#       Appends a single line to ${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-wip-pushes.log:
#         <ISO>|<sha-csv>|<branch>|<mechanism>
#       The log path can be overridden via $GIT_DISCIPLINE_WIP_PUSH_LOG (used by tests).
#
# Functions never exit; callers decide how to surface the verdict.

wip_gate_parse_range() {
  local upstream="$1"
  local local_ref="$2"

  local default_ref
  default_ref=$(wip_gate_resolve_default_ref)

  wip_gate_scoped_range "$local_ref" "$upstream" "$default_ref"
}

# allow-comment: wip_gate_resolve_default_ref echoes origin/<default> from Git's
# allow-comment: origin/HEAD metadata, and only when that ref resolves to an
# allow-comment: object. Returns non-zero otherwise so the caller can fall back
# allow-comment: to the tracked upstream without guessing names.
wip_gate_resolve_default_ref() {
  local sym
  sym=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  [[ -z "$sym" ]] && return 1
  git rev-parse --verify --quiet "$sym" >/dev/null 2>&1 || return 1

  printf '%s' "$sym"
}

# allow-comment: wip_gate_scoped_range <local-ref> <exclude-ref>... is the one
# allow-comment: place a push range is built. It keeps the exclusions that
# allow-comment: resolve (an empty ref, the all-zero sha git reports for a
# allow-comment: branch the remote does not have yet, and a deleted ref all drop
# allow-comment: out) and de-duplicates them, so pushing the default branch
# allow-comment: itself names its remote tip once. One exclusion prints the
# allow-comment: two-dot form both hooks have always used; two or more print
# allow-comment: caret form, which is several arguments and therefore only safe
# allow-comment: through wip_gate_rev_list.
wip_gate_scoped_range() {
  local local_ref="$1"
  shift

  local excludes="" first="" count=0 ref
  for ref in "$@"; do
    [[ -z "$ref" ]] && continue
    [[ "$ref" =~ ^0+$ ]] && continue
    case " $excludes " in *" ^$ref "*) continue ;; esac
    git rev-parse --verify --quiet "$ref" >/dev/null 2>&1 || continue

    excludes+="^$ref "
    [[ -z "$first" ]] && first="$ref"
    count=$((count + 1))
  done

  if [[ "$count" -eq 0 ]]; then
    printf '%s' "$local_ref"
  elif [[ "$count" -eq 1 ]]; then
    printf '%s..%s' "$first" "$local_ref"
  else
    printf '%s%s' "$excludes" "$local_ref"
  fi
}

# allow-comment: wip_gate_rev_list <range> is the only reader of a range built
# allow-comment: here; the caret form is several arguments, so the expansion is
# allow-comment: deliberately unquoted and lives in one place instead of at each
# allow-comment: call site.
wip_gate_rev_list() {
  local range="$1"
  [[ -z "$range" ]] && return 0

  # shellcheck disable=SC2086
  git rev-list $range 2>/dev/null || true
}

# allow-comment: wip_gate_commit_is_ours <sha> [identity-email] returns 0 when the
# allow-comment: commit is the pusher's to be held to the personal discipline:
# allow-comment: authored by the current git identity, committed by it (a rebase
# allow-comment: that rewrote a teammate commit), or carrying a Co-authored-by
# allow-comment: trailer naming it. A purely-carried teammate commit (none of the
# allow-comment: three) returns 1 and is skipped. With no identity configured the
# allow-comment: function returns 0 so the gate still enforces (range scoping has
# allow-comment: already excluded merged work).
wip_gate_commit_is_ours() {
  local sha="$1"
  local me="${2:-}"
  [[ -z "$me" ]] && me=$(git config user.email 2>/dev/null || true)
  [[ -z "$me" ]] && return 0

  local author committer
  author=$(git log -1 --pretty=format:%ae "$sha" 2>/dev/null || true)
  [[ "$author" = "$me" ]] && return 0
  committer=$(git log -1 --pretty=format:%ce "$sha" 2>/dev/null || true)
  [[ "$committer" = "$me" ]] && return 0

  local body
  body=$(git log -1 --pretty=format:%B "$sha" 2>/dev/null || true)
  case "$body" in
    *[Cc]o-[Aa]uthored-[Bb]y:*"<$me>"*) return 0 ;;
  esac

  return 1
}

# allow-comment: shared push-arg tokenizer + range resolver, consolidated
# allow-comment: from duplicate blocks in push-wip-gate.sh and push-body-
# allow-comment: gate.sh so a new push shape lands in one place.
# allow-comment: wip_gate_resolve_push_range <bash-command> strips the
# allow-comment: prefix up to " push ", tokenizes the remaining args
# allow-comment: (skipping flags and stopping at shell separators or
# allow-comment: redirections), pairs remote/refspec positionals, and
# allow-comment: resolves the rev-list range. Every shape excludes the default
# allow-comment: branch, so a rebased branch never drags the commits it caught
# allow-comment: up on into the range. With no explicit refspec that is
# allow-comment: origin/<default>..HEAD, falling back to the tracked upstream
# allow-comment: only when no default branch resolves. With an explicit
# allow-comment: remote+refspec (git push origin <branch>) both origin/<branch>
# allow-comment: and origin/<default> are excluded: after a rebase the former is
# allow-comment: the stale pre-rebase tip and the latter is what actually
# allow-comment: bounds the branch's own work. On a brand new branch's first
# allow-comment: push origin/<branch> does not resolve and that leaves
# allow-comment: origin/<default>..<local>; with neither resolving it falls back
# allow-comment: to a full local_ref scan.
wip_gate_resolve_push_range() {
  local command="$1"

  local args="${command#*push}"
  args="${args# }"
  args="${args%%#*}"

  local -a positional=()
  local tok stop=0
  for tok in $args; do
    case "$tok" in
      \;|\&|\&\&|\|\||\|) stop=1 ;;
      \>*|\<*) stop=1 ;;
      [0-9]\>*|[0-9]\<*) stop=1 ;;
    esac
    [[ "$stop" -eq 1 ]] && break
    case "$tok" in
      --) ;;
      -*) ;;
      *) positional+=("$tok") ;;
    esac
  done

  if [[ "${#positional[@]}" -eq 2 ]]; then
    local remote="${positional[0]}"
    local refspec="${positional[1]}"
    local local_ref remote_branch
    if [[ "$refspec" == *:* ]]; then
      local_ref="${refspec%%:*}"
      remote_branch="${refspec##*:}"
    else
      local_ref="$refspec"
      remote_branch="$refspec"
    fi
    [[ -z "$local_ref" ]] && local_ref="HEAD"

    local upstream="$remote/$remote_branch"
    local default_ref
    default_ref=$(wip_gate_resolve_default_ref)

    wip_gate_scoped_range "$local_ref" "$upstream" "$default_ref"
  else
    local default_ref upstream=""
    default_ref=$(wip_gate_resolve_default_ref)
    if [[ -z "$default_ref" ]]; then
      upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
    fi

    wip_gate_scoped_range "HEAD" "$default_ref" "$upstream"
  fi
}

wip_gate_find_wip_commits() {
  local range="$1"
  [[ -z "$range" ]] && return 0

  local commits sha body slice_value
  commits=$(wip_gate_rev_list "$range")
  [[ -z "$commits" ]] && return 0

  local me
  me=$(git config user.email 2>/dev/null || true)

  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    wip_gate_commit_is_ours "$sha" "$me" || continue
    body=$(git log -1 --pretty=format:%B "$sha" 2>/dev/null || true)
    [[ -z "$body" ]] && continue

    # interpret-trailers --parse emits "Key: value" lines for each trailer.
    slice_value=$(printf '%s\n' "$body" \
      | git interpret-trailers --parse 2>/dev/null \
      | awk -F': ' 'tolower($1) == "slice" { sub(/^[Ss]lice:[[:space:]]*/, "", $0); print; exit }')

    # Trim whitespace.
    slice_value="${slice_value#"${slice_value%%[![:space:]]*}"}"
    slice_value="${slice_value%"${slice_value##*[![:space:]]}"}"

    if [[ "$slice_value" = "wip" ]]; then
      printf '%s\n' "$sha"
    fi
  done <<< "$commits"
}

wip_gate_should_block() {
  local command="${1:-}"
  local wip_count="${2:-0}"

  [[ "$wip_count" -le 0 ]] && return 1

  # Env-var bypass.
  if [[ "${GIT_DISCIPLINE_ALLOW_WIP_PUSH:-0}" = "1" ]]; then
    return 1
  fi

  # Magic-comment bypass in the bash command string.
  if [[ -n "$command" ]] && grep -qF '# allow-wip-push' <<< "$command"; then
    return 1
  fi

  return 0
}

wip_gate_format_message() {
  local sha_list="$1"
  local out=""
  local sha short subject

  out+=$'wip commits in push range:\n'
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    short=$(git rev-parse --short "$sha" 2>/dev/null || printf '%s' "$sha")
    subject=$(git log -1 --pretty=format:%s "$sha" 2>/dev/null || printf '<no subject>')
    out+="  ${short} ${subject}"$'\n'
  done <<< "$sha_list"

  out+=$'\nBypass options:\n'
  out+=$'  GIT_DISCIPLINE_ALLOW_WIP_PUSH=1 git push ...   (env-var bypass)\n'
  out+=$'  git push ...   # allow-wip-push        (magic-comment bypass)\n'
  out+=$'\nUse of either bypass is logged to ${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-wip-pushes.log.\n'

  printf '%s' "$out"
}

wip_gate_log_bypass() {
  local sha_csv="$1"
  local branch="$2"
  local mechanism="$3"

  local log="${GIT_DISCIPLINE_WIP_PUSH_LOG:-${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-wip-pushes.log}"
  local dir
  dir=$(dirname "$log")
  mkdir -p "$dir" 2>/dev/null || true

  local ts_iso
  ts_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  printf '%s|%s|%s|%s\n' "$ts_iso" "$sha_csv" "$branch" "$mechanism" \
    >> "$log" 2>/dev/null || true
}
