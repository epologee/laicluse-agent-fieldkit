#!/usr/bin/env bats
# allow-comment: regression for the heredoc/quoted-string false-positive in the push-detection regex; `dd_is_git_push_command` must not match a bash command whose `git ... push` token sequence only appears inside a quoted string or heredoc body.

COMMON="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/hooks/lib/common.sh"

@test "dd_is_git_push_command: bare 'git push' is detected" {
  run bash -c "source '$COMMON'; dd_is_git_push_command 'git push'"
  [ "$status" -eq 0 ]
}

@test "dd_is_git_push_command: 'git push origin main' is detected" {
  run bash -c "source '$COMMON'; dd_is_git_push_command 'git push origin main'"
  [ "$status" -eq 0 ]
}

@test "dd_is_git_push_command: 'git push --force-with-lease' is detected" {
  run bash -c "source '$COMMON'; dd_is_git_push_command 'git push --force-with-lease'"
  [ "$status" -eq 0 ]
}

@test "dd_is_git_push_command: 'GIT_VAR=1 git push' with env-var prefix is detected" {
  run bash -c "source '$COMMON'; dd_is_git_push_command 'GIT_VAR=1 git push'"
  [ "$status" -eq 0 ]
}

@test "dd_is_git_push_command: 'git rebase -i' alone is not detected" {
  run bash -c "source '$COMMON'; dd_is_git_push_command 'git rebase -i HEAD~3'"
  [ "$status" -eq 1 ]
}

@test "dd_is_git_push_command: 'git stash push -- path' is not detected" {
  run bash -c "source '$COMMON'; dd_is_git_push_command 'git stash push -- packages/foo'"
  [ "$status" -eq 1 ]
}

@test "dd_is_git_push_command: 'git stash push -m msg' is not detected" {
  run bash -c "source '$COMMON'; dd_is_git_push_command 'git stash push -m wip'"
  [ "$status" -eq 1 ]
}

@test "dd_is_git_push_command: 'git -c user.name=x push' with a global option is detected" {
  run bash -c "source '$COMMON'; dd_is_git_push_command 'git -c user.name=x push'"
  [ "$status" -eq 0 ]
}

@test "dd_is_git_push_command: 'git -C /repo push origin main' is detected" {
  run bash -c "source '$COMMON'; dd_is_git_push_command 'git -C /repo push origin main'"
  [ "$status" -eq 0 ]
}

@test "dd_is_git_push_command: 'git commit -m \"...push range...\"' inside quotes is not detected" {
  run bash -c "source '$COMMON'; dd_is_git_push_command 'git commit -m \"validate_body ran git log -5 HEAD regardless of which commit was being validated push range becomes a fallback later\"'"
  [ "$status" -eq 1 ]
}

@test "dd_is_git_push_command: 'git commit -m \$(cat <<EOF ... push ... EOF)' heredoc is not detected" {
  run bash -c "source '$COMMON'; dd_is_git_push_command \$'git commit -m \"\$(cat <<EOF\\nWHY paragraph\\ngit log -5 HEAD plus push range\\nEOF\\n)\"'"
  [ "$status" -eq 1 ]
}
