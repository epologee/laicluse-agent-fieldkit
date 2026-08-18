#!/bin/bash
# packages/git-discipline/hooks/lib/published-commit.sh
#
# One answer to "has this commit already been published?".
#
# The commit discipline governs work that is still yours to shape. A commit
# that already sits on the default branch has shipped, so demanding a better
# body for it means demanding a rewrite of public history, which no push-time
# gate may ask for. Every enforcement path asks this predicate before judging a
# commit.
#
# Why here and not in the push range: a range is computed per push shape, and
# the git-native hooks carry their own copy of that arithmetic from the day
# they were installed. A rule that has to hold on every machine cannot live in
# a snapshot; it lives in the libraries the hooks load fresh on every run.
#
# Public functions:
#   published_commit_default_ref
#       Echoes origin/<default> from Git's own origin/HEAD metadata, and only
#       when that ref resolves to an object. Returns non-zero otherwise so
#       callers fall back without guessing branch names.
#   published_commit_is_published <sha>
#       Returns 0 when <sha> is an ancestor of that default branch. Without a
#       resolvable default branch it returns 1, so a repository that has no
#       origin HEAD keeps judging exactly what it judged before.

published_commit_default_ref() {
  local sym
  sym=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  [[ -z "$sym" ]] && return 1
  git rev-parse --verify --quiet "$sym" >/dev/null 2>&1 || return 1

  printf '%s' "$sym"
}

published_commit_is_published() {
  local sha="${1:-}"
  [[ -z "$sha" ]] && return 1

  local default_ref
  default_ref=$(published_commit_default_ref) || return 1

  git merge-base --is-ancestor "$sha" "$default_ref" 2>/dev/null
}
