#!/usr/bin/env bats
# allow-comment: range scoping for the FIRST push of a new branch made via the
# allow-comment: explicit `git push -u origin <branch>` idiom. The explicit
# allow-comment: remote/refspec path built upstream="origin/<branch>", which
# allow-comment: does not resolve yet on a brand new branch, and fell back to
# allow-comment: scanning every commit reachable from the local ref instead of
# allow-comment: trying origin/<default>..<local> first. That dragged the
# allow-comment: entire pre-discipline repo history into the push-body-gate
# allow-comment: check on every first push of a feature branch.

load helpers

@test "first push via 'git push -u origin <branch>' scopes to origin/<default>..local when it resolves" {
  export GIT_DISCIPLINE_PUSH_BODY_GATE_DISABLED=0
  export GIT_SHIM_ORIGIN_HEAD="refs/remotes/origin/master"
  export GIT_SHIM_VERIFY_REFS="origin/master"

  wip_shim_set_revlist "feature/new-thing" $'oldnoncompliant1'
  wip_shim_set_subject "oldnoncompliant1" "Old pre-discipline commit"
  wip_shim_set_body "oldnoncompliant1" "Old pre-discipline commit"

  wip_shim_set_revlist "origin/master..feature/new-thing" $'newcompliant1'
  wip_shim_set_subject "newcompliant1" "Tiny scoped tweak"
  wip_shim_set_body "newcompliant1" "Tiny scoped tweak"
  wip_shim_set_show "newcompliant1" " 1 file changed, 1 insertion(+)" "a.rb"

  run_dispatch 'git push -u origin feature/new-thing'

  [ "$status" -eq 0 ]
  [[ "$output" != *"push-body-gate"* ]]
}

@test "no resolvable default branch still falls back to the local-ref-only scan" {
  export GIT_DISCIPLINE_PUSH_BODY_GATE_DISABLED=0
  export GIT_SHIM_ORIGIN_HEAD=""
  export GIT_SHIM_VERIFY_REFS=""

  wip_shim_set_revlist "feature/new-thing" $'oldnoncompliant1'
  wip_shim_set_subject "oldnoncompliant1" "Old pre-discipline commit"
  wip_shim_set_body "oldnoncompliant1" "Old pre-discipline commit"

  run_dispatch 'git push -u origin feature/new-thing'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-body-gate]"* ]]
  [[ "$output" == *"missing-body"* ]]
}
