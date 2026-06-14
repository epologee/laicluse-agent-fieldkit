# git-discipline changelog

The post-update broadcast (see `bin/check-broadcast`) shows the topmost
section once per machine whenever the installed `version` in
`.claude-plugin/plugin.json` changes. Entry headers record the version at
which the entry was written; a pre-commit hook auto-bumps `plugin.json` on
every commit, so the header may lag the shipped version. Header numbers are
informational, the broadcast is positional.

Categories:

- **Breaking**: user must adapt (renamed commands, removed flags, hook gates)
- **Added**: new commands, new optional behavior
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

Patch-level fixes that change nothing the user can observe are intentionally
omitted; the broadcast budget is for things the user benefits from knowing.
Version numbers may therefore be non-contiguous (an internal refactor bumps
the version without producing an entry here).

## [v2.0.22]

### Changed

- **Codex now receives only the git-discipline skills it can run.** Workflow
  skills such as `commit-snipe`, `rebase-latest-default`, `push-policy`,
  `install-hooks`, and `run-spec` remain available in the generated Codex
  adapter. Claude PreToolUse control skills (`disable-discipline`,
  `enable-discipline`, `discipline-status`, `disable-git`, `enable-git`) are
  omitted from Codex because that hook layer does not exist there.

### Fixed

- **Shared push-policy lookups no longer hard-code `CLAUDE_PLUGIN_ROOT`.**
  Shared skills resolve the active plugin root from Claude's environment or
  Codex's installed plugin metadata before running `git-repo-policy`.

## [v2.0.21]

### Added

- **`Verified: agent-confirmed` is now a recognised anchor, paired with a
  required `Verified-how:` trailer.** When the agent (not the operator) ran the
  change and saw it work, `operator-confirmed` was a lie and the only honest
  fallback was a vague `n/a`. `agent-confirmed` names that case directly, and
  the companion `Verified-how:` trailer forces a concrete sentence of the shape
  "Due to \<reason\>, this was confirmed by \<what the agent ran and saw\>" (>=
  20 chars). Because that sentence lands in git, it leaves a paper trail to
  catch a dishonest self-attestation later. A bare `agent-confirmed` without
  `Verified-how:` is rejected with `missing-verified-how`.

## [v2.0.15]

### Breaking

- **Flipping the discipline or the per-repo git lock is now operator-actuated.**
  A new `sentinel-protect` guard denies any agent-driven Bash call that
  creates or removes a `git-discipline-disabled-*` or `.git/git-discipline-deny`
  sentinel, in both directions (off AND back on) and with no magic-comment or
  env-var escape. The guard runs before the disabled-sentinel early exit, so a
  session whose discipline is off cannot quietly re-enable it either. The
  toggle skills (`disable-discipline`, `enable-discipline`, `disable-git`,
  `enable-git`) now hand you a ready-to-paste `! `-prefixed command instead of
  running it; your keystroke is the switch. Read-only inspection
  (`discipline-status`) is unaffected.

### Fixed

- **Corrected the advertised `--no-verify` escape.** The commit-body deny
  message, the guard's header comment, the shared vsd-skip message, and the
  commit-discipline / install-hooks docs claimed `git commit --no-verify`
  bypasses the PreToolUse layer. It never did: the PreToolUse guards validate
  every git commit command, flags included. All texts now scope `--no-verify`
  to the git-native layer (where it is real and audit-logged) and name the
  operator-only `/git-discipline:disable-discipline` as the only PreToolUse
  off-switch. Behaviour is unchanged; only the claims moved to match it.

## [v2.0.2]

### Breaking

- **First public l'Aicluse release.** Install this plugin as
  `git-discipline@laicluse-agent-fieldkit` for migrated workflows.

## [v1.0.1]

### Breaking

- **New l'Aicluse identity.** The plugin is now installed as
  `git-discipline@laicluse-agent-fieldkit` and slash commands use the
  `/git-discipline:*` namespace.

### Changed

- **Runtime state moved under l'Aicluse storage.** New first-party state is
  written under `${LAICLUSE_HOME:-~/.laicluse}/git-discipline`.

## [v1.0.164]

### Added

- **Mark a rebase-carried commit `Discipline: skip due to rebase` and the push body-gate treats it as already-shipped instead of re-litigating its body.** `/git-discipline:rebase-latest-default` marks these for you.

## [v1.0.163]

### Fixed

- **`rebase-latest-default` now reruns CI on the rebased tip of a published branch.** When a branch has an open PR but no local tracking, the gate keys on the remote and force-pushes with a lease, instead of leaving CI on the pre-rebase commits.

## [v1.0.161]

### Fixed

- **The push gate no longer fails on commits whose `Visual:`/`Verified:` path was deleted or whose `Tests:`/`Red-then-green:` spec moved after the commit.** Those path checks now run at commit time; trailer presence and format are still enforced at push.

## [v1.0.157]

### Added

- **`/git-discipline:push-policy` decides whether and when a push fits the current repo.** A resolver derives one of five push modes from per-repo facts (collaboration, visibility, protection, access), overridable via git-local `codingAgent.git.*`.

### Changed

- **`/git-discipline:rebase-latest-default` now finishes by force-pushing a rebased upstream branch when you have write access.** The `--force-with-lease` is the completion of the rebase, gated by the push-policy; it never touches a protected default.

## [v1.0.154]

### Fixed

- **Rebased branches stop false-failing the push gates on a team repo.** A bare push scopes to `origin/<default>..HEAD` and judges only commits you authored or rebase-co-authored, so already-merged teammate commits a rebase swept in are never demanded a body or blocked.

## [v1.0.133]

### Fixed

- **push-{wip,body}-gate always pick the range from git itself, not from the bash command shape.** Anything other than an explicit `<remote> <local>:<dest>` validates `@{u}..HEAD`; shell pipes and `2>&1` no longer confuse the parser into the old 50-commit fallback.

## [v1.0.132]

### Changed

- **Rotation reminders shift to PostToolUse: only the first commit per fresh state denies; the next slot arrives as a silent `additionalContext` hint.** Commits outside Claude Code fall back to the v1.0.131 per-commit deny.

## [v1.0.131]

### Fixed

- **push-{wip,body}-gate no longer fire on `git rebase` or `git commit --amend` when the message body contains "git ... push" text.** The push-detection regex now runs against a heredoc/quoted-string-stripped copy of the command.

## [v1.0.130]

### Added

- **Version-skew warning when this session's loaded git-discipline differs from the installed version.** Surfaces parallel-session drift after `claude plugins update`; fires once per session via a `/tmp` sentinel.

## [v1.0.128]

### Breaking

- **commit-format, commit-body, commit-trailers no longer deny at commit-time.** They emit `additionalContext`; the commit lands and Claude amends. The visible deny moves to push-time via `push-body-gate`. `/git-discipline:install-hooks`' `commit-msg` is unchanged.

### Added

- **push-body-gate blocks `git push` when any commit in the range has a non-conformant body.** Same range-detection as `push-wip-gate`. Skips `Merge`/`Revert`/`fixup!`/`squash!`/`amend!`/cherry-pick. Bypass with `/git-discipline:disable-discipline`.

- **GIT_DISCIPLINE_VALIDATE_CONTEXT picks the `validate_body` source.** Values: `staged` (default), `HEAD` (just-landed delta), `<sha>` (used by push-body-gate). `commit --amend` switches to `HEAD` automatically.

## [v1.0.123]

### Fixed

- **Concurrent Claude sessions in the same repo no longer race the rotation slot.** Each session now has its own rotation state file, so a commit landing in another session does not change which rule the hook asks you to ack.

## [v1.0.120]

### Changed

- **Visual-trailer errors point at capture-route categories.** A failing `missing-visual` or `visual-na-on-ui-touch` guard now hints at where capture routes live (browser drivers, OS utilities, simulator tools, project-launch flows).

## [v1.0.117]

### Fixed

- **Commit guards no longer fire on `git commit` as substring.** Filenames in a `for`-loop (`git-discipline commit discipline.md`), `grep -n "git commit"`, or `echo` with `git commit` in a string pass cleanly.

## [v1.0.112]

### Changed

- **Rule 1 banlist widened.** `Land`, `Make`, `Work`, `Do`, `Get`, `Tweak`, `Surface`, `Address`, and `Apply` now deny at subject start. Rewrite the subject to name the actual capability change.

## [v1.0.111]

### Added

- **Rotation Rule 15 (`steiger`): no internal AI-tooling vocabulary in commit subject/body.** Targets skill names, phase terms, and politer rewrites like "consensus reached"; surfaces on rotation, not a hard block.

## [v1.0.107]

### Breaking

- **Strict commit-discipline is the default.** `GIT_DISCIPLINE_AUTONOMOUS=1` is gone (rules apply universally); bare `Red-then-green: yes`, `Visual: n/a` on UI-touch, `Verified: build-only`, and `# vsd-skip` are always rejected. `--no-verify` is the only audit-logged emergency bypass.

## [v1.0.106]

### Breaking

- **New required `Verified:` trailer.** Anchors how the change was verified: `operator-confirmed`, `<artefact path>`, `red-then-green`, `build-only`, or `n/a (reason)`. Drops on Slice opt-outs; `build-only` is rejected under `GIT_DISCIPLINE_AUTONOMOUS=1`. See `/git-discipline:commit-discipline`.

## [v1.0.102]

### Added

- **`/git-discipline:disable-git` and `/git-discipline:enable-git` lock the repo for Claude.** While the lock is on, git mutations are denied; read-only inspection (status, log, diff, show, blame) keeps working. With `/git-discipline:install-hooks` active, CLI `git commit` and `git push` are blocked too.

## [v1.0.94]

### Fixed

- **Migration of the legacy global state file no longer poisons
  new repos.** The first repo after v1.0.92 used to leave the
  global file in place, re-migrating stale rotation state into
  every later new repo. The source is now renamed to `*.migrated`
  after a successful copy.
- **Toplevel-hash portability on systems without `shasum`.** The
  fallback chain dropped to `cksum` (decimal CRC), drifting per-
  toplevel paths into a different alphabet. It now tries `md5sum`
  and `md5 -q` first, with a final degradation to the global path
  when no hex hasher exists.

### Changed

- **Empty `git rev-parse HEAD` is denied with guidance.** A
  `git commit` in a zero-commit repo used to silently lose the
  ack; the deny is now explicit: "cannot read HEAD, is this a new
  repository?" (Landed as v1.0.90; documented retroactively.)

## [v1.0.93]

### Changed

- **Deny strings are now English.** The rotation guard mixed
  Dutch and English; it is now uniformly English (`violates`,
  `password missing or wrong`, `Paste`). The ack placeholder is
  `<password>`. Tooling that grepped old fragments needs to update.

## [v1.0.92]

### Changed

- **Rotation state file is now per-repo, not per-user.** The
  global path collided across unrelated repos. It is now
  namespaced by an 8-char hash of `git rev-parse --show-toplevel`.
  The legacy file migrates atomically on first read; worktrees of
  the same repo share state.

## [v1.0.91]

### Changed

- **State file format is now key=value.** Was positional
  (line 1 = pv, ...); now `pv=-1`, `pr=-1`, `rp=0`,
  `ack_pending_sha=`. The reader still accepts legacy 3- and
  4-line forms. Tooling using `sed -n '<N>p'` should switch to
  `grep -E '^<key>='`.
- **Migration of the legacy `dont-do-that` state file is now
  atomic.** The one-shot `cp` could be raced by two Claude sessions
  starting at once; the migration now writes to a per-pid temp file
  and renames atomically.

## [v1.0.89]

### Changed

- **Broken-install deny replaces the slash-command fallback.** When
  `commit-subject.sh` cannot resolve `SKILL.md`, it now emits a loud
  `install appears broken: ... Reinstall git-discipline@laicluse-agent-fieldkit.` deny
  instead of degrading to `/git-discipline:commit-discipline`. Reinstall if
  you see this.

## [v1.0.85]

### Changed

- **Rotation slot only advances after a commit actually lands.** A commit that passed PreToolUse but failed downstream (missing `[doublecheck]`, version-bump hook error) used to burn a slot anyway; now you ack the same rule again on retry.

## [v1.0.83]

### Changed

- **Rotation deny names the SKILL.md path.** The reminder ends with `(lookup: <abs-path>, section 'Rotation reminders')` instead of `(zie /git-discipline:commit-discipline)`, so the password lookup is a direct Read; tooling that greps for the old phrase needs an update.

## [v1.0.80]

### Breaking

- **`Red-then-green` line+name forms are unified.** The bare
  `<path>:<line>` and bare `<path>:<test-name>` forms are removed.
  Use the combined form `<path>:<line> # <test-name>` instead. A
  full example trailer:

  ```
  Red-then-green: spec/foo_spec.rb:42 # SomeClass#method does the thing
  ```

  The `# ` separator is the RSpec / Cucumber wire format and is the
  only candidate that keeps `path:line` clickable in iTerm2 Semantic
  History, VSCode terminalLinkParsing, and Ghostty. The gcc-style
  `path:line: <name>` form was rejected because two of those three
  parsers greedily absorb the trailing non-numeric continuation past
  the second colon, breaking cmd-click; see
  https://github.com/microsoft/vscode/issues/127762 and
  https://github.com/ghostty-org/ghostty/discussions/11378 for the
  upstream confirmations. The file-only `<path>` form, the `yes`
  self-attestation, and `n/a (reason >= 10 chars)` are unchanged.

  New error code `red-then-green-line-out-of-range` fires when the
  named line exceeds the staged blob's line count or names line 0
  (the trailer uses 1-based numbering, matching every test runner's
  output). `red-then-green-test-not-found` continues to fire when
  the named test does not match any `it / describe / context /
  specify / @test / @Test / Scenario / func / def` declaration in
  the staged blob.

## [v1.0.73]

### Breaking

- **`Red-then-green: yes` is rejected under `GIT_DISCIPLINE_AUTONOMOUS=1`.**
  New code `red-then-green-autonomous`. The trailer must anchor the
  claim with `<path>` (staged), `<path>:<test-name>`, or `n/a
  (reason >= 10 chars)`. Outside autonomous mode `yes` still works.

### Added

- **`Red-then-green` accepts spec-path forms.** Three new shapes on top
  of the legacy `yes` and `n/a (reason)`:

  - `Red-then-green: spec/foo_spec.rb` anchors the claim to a spec file
    that this commit actually touches. New error code
    `red-then-green-path-not-in-staged` rejects random spec names.
  - `Red-then-green: spec/foo_spec.rb:starts on StartTransaction`
    identifies WHICH test was seen red, by name. New error code
    `red-then-green-test-not-found` fires when the staged blob has no
    matching `it / describe / context / specify / @test / @Test /
    Scenario / func / def` declaration.
  - `Red-then-green: spec/foo_spec.rb:42` is the line-number form; the
    staged blob must have at least that many lines.

  The validator cannot prove that the test was actually run red, but it
  can refuse claims that are not anchored anywhere. See
  `/git-discipline:commit-discipline` for the full table.

## [v1.0.61]

### Breaking

- **`# vsd-skip` no longer bypasses UI-touched commits.** New code
  `vsd-skip-ui-touch`. UI commits must use `Visual: <path>` or
  `Visual: n/a (rationale)`. Backend / spec / migration commits are
  unaffected.

### Added

- **`GIT_DISCIPLINE_AUTONOMOUS=1` strict mode for unattended commits.**
  When set, `# vsd-skip` is rejected outright
  (`vsd-skip-autonomous`) and `Visual: n/a` is rejected on UI-
  touched commits (`visual-na-autonomous`; only `Visual: <path>`).
  Ship from rover skills to tighten policy.

## [v1.0.57]

### Added

- **Post-update broadcasts.** After an update, the next git-discipline slash
  command shows a one-line summary of what changed. Runs once per
  machine per version; sentinel at
  `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/broadcasts/git-discipline-broadcast-seen`.
- **Shared marketplace whats-new reader.** Re-prints this file's section for
  the current version on demand, regardless of whether the broadcast already
  fired. Fieldkit now provides this through `/whats-new`.
