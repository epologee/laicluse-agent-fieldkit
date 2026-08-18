#!/usr/bin/env bats
# allow-comment: range scoping. After a feature branch is rebased onto a default
# allow-comment: branch that moved many commits ahead, the stale remote feature
# allow-comment: ref (@{u}) sweeps every catching-up commit into the push range.
# allow-comment: The body gate must instead scope to origin/<default>..HEAD so
# allow-comment: already-on-default commits are never judged.

load helpers

setup_default_scope() {
  export GIT_DISCIPLINE_PUSH_BODY_GATE_DISABLED=0
  export GIT_SHIM_ORIGIN_HEAD="refs/remotes/origin/master"
  export GIT_SHIM_VERIFY_REFS="origin/master origin/feature"
  export GIT_SHIM_UPSTREAM="origin/feature"
}

@test "force-push of a rebased branch ignores already-on-default commits" {
  setup_default_scope

  wip_shim_set_revlist "origin/master..HEAD" $'newone111111'
  wip_shim_set_revlist "origin/feature..HEAD" \
    $'newone111111\nmerged0aaaaa\nmerged0bbbbb'

  wip_shim_set_subject "newone111111" "Tiny scoped tweak"
  wip_shim_set_body "newone111111" "Tiny scoped tweak"
  wip_shim_set_show "newone111111" " 1 file changed, 1 insertion(+)" "a.rb"

  wip_shim_set_subject "merged0aaaaa" "Capture charger make and model"
  wip_shim_set_body "merged0aaaaa" "Capture charger make and model"
  wip_shim_set_subject "merged0bbbbb" "Bundle PNG logos for supported brands"
  wip_shim_set_body "merged0bbbbb" "Bundle PNG logos for supported brands"

  run_dispatch 'git push --force-with-lease'

  [ "$status" -eq 0 ]
  [[ "$output" != *"push-body-gate"* ]]
}

@test "no resolvable default branch falls back to the tracked upstream range" {
  export GIT_DISCIPLINE_PUSH_BODY_GATE_DISABLED=0
  export GIT_SHIM_ORIGIN_HEAD=""
  export GIT_SHIM_VERIFY_REFS="origin/feature"
  export GIT_SHIM_UPSTREAM="origin/feature"

  wip_shim_set_revlist "origin/feature..HEAD" $'ownsubjonly1'
  wip_shim_set_subject "ownsubjonly1" "Own work without a body"
  wip_shim_set_body "ownsubjonly1" "Own work without a body"

  run_dispatch 'git push'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-body-gate]"* ]]
}

@test "force-push naming remote and branch ignores already-on-default commits" {
  setup_default_scope

  wip_shim_set_revlist "^origin/feature ^origin/master feature" $'newone111111'
  wip_shim_set_revlist "origin/feature..feature" \
    $'newone111111\nmerged0aaaaa\nmerged0bbbbb'

  wip_shim_set_subject "newone111111" "Tiny scoped tweak"
  wip_shim_set_body "newone111111" "Tiny scoped tweak"
  wip_shim_set_show "newone111111" " 1 file changed, 1 insertion(+)" "a.rb"

  wip_shim_set_subject "merged0aaaaa" "Capture charger make and model"
  wip_shim_set_body "merged0aaaaa" "Capture charger make and model"
  wip_shim_set_subject "merged0bbbbb" "Bundle PNG logos for supported brands"
  wip_shim_set_body "merged0bbbbb" "Bundle PNG logos for supported brands"

  run_dispatch 'git push --force-with-lease origin feature'

  [ "$status" -eq 0 ]
  [[ "$output" != *"push-body-gate"* ]]
}

@test "own commit outside the default branch is still gated on that push shape" {
  setup_default_scope

  wip_shim_set_revlist "^origin/feature ^origin/master feature" $'ownnobody001'
  wip_shim_set_subject "ownnobody001" "Add the thing without a body"
  wip_shim_set_body "ownnobody001" "Add the thing without a body"

  run_dispatch 'git push --force-with-lease origin feature'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-body-gate]"* ]]
  [[ "$output" == *"missing-body"* ]]
}
