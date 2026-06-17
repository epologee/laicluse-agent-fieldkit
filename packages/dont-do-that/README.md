# dont-do-that

Guardrail hooks that push back on common AI reflexes. Each hook either blocks a
tool call, blocks the Stop event, or surfaces additional context at the moment a
mistake is likely, forcing the active agent to course-correct instead of
barreling past the issue.

Claude Code receives the full hook stack. Codex receives the same event layers
through the explicit `hooks/hooks.codex.json` source, materialized by
`bin/plugin-adapters build` as `hooks/hooks.json` in the generated Codex adapter
package. Which guard runs on which event for which agent is decided by the guard
registry (`hooks/guards.json`), not by the dispatcher or bespoke per-manifest
shell variables. Codex skips only the `premature` Stop guard, because that guard
creates a nudge turn after otherwise-complete answers, which can replace the
completed assistant message in the Mac app; the registry records that as
`premature.agents.codex: disabled` while every other Stop guard still runs for
Codex. The manifests tell the dispatcher who they are with `DD_AGENT=claude` and
`DD_AGENT=codex`; the registry resolves the rest. The operator correction skills
(`/duh` and `/just-a-question`) ship to both agents.

## Architecture

One dispatcher, `hooks/dispatch.sh`, is registered against PreToolUse (shell and file-edit matchers), PostToolUse (shell and file-edit matchers), and Stop. Claude file edits arrive as `Edit` / `Write` / `MultiEdit`; Codex patches arrive as `apply_patch`. The dispatcher reads stdin once, extracts `hook_event_name` and `tool_name`, picks the matching lane, and then reads the ordered, agent-filtered guard list for that lane from the registry (`hooks/guards.json`) rather than enumerating guards itself. Guards live under `hooks/guards/` as sourced functions, shared helpers under `hooks/lib/common.sh`. No external script runs per guard. For a one-off manual silence the dispatcher still honours `DD_SKIP_GUARDS`, `DD_ONLY_GUARDS`, and event-specific variants such as `DD_SKIP_STOP_GUARDS` as a secondary gate, but durable agent/event policy belongs in the registry, not in a shell variable.

## Guard registry

`hooks/guards.json` is the source of truth for which guard runs on which hook event for which agent. The dispatcher generates its per-lane guard list from it at runtime (a single `jq` read; `jq` is already a hard dependency of every guard), so adding, reordering, or re-scoping a guard is a registry edit, not a dispatcher edit.

The file has four parts:

- `contracts`: the payload each guard can inspect. `tool-call` is the pending tool invocation before it runs (PreToolUse), `persisted-edit` is file content or a shell command after it is applied (PostToolUse), `final-answer` is the assistant's final-turn text (Stop).
- `events`: each hook event and the contracts it `provides`. This is what makes placement checkable: a guard can only move to an event that carries the data it reads.
- `lanes`: the execution groups the dispatcher runs. Each lane names its `event`, the `tools` it matches, an output `mode` (`deny`, `context`, or `block`), and a `dispatch` style (`direct` lets a guard exit the process to block; `capture` runs each guard in a subshell and emits the first non-empty output). The Stop lanes split into `stop-tracked` (false-claims, tool-error, always run, keep their own line trackers) and `stop-mutex` (skipped once a prior Stop fire already blocked).
- `guards`: every guard, keyed by the guard id (its `hooks/guards/<id>.sh` filename, usually but not always matching its `[dont-do-that/...]` mnemonic prefix; `false-claims` emits `[dont-do-that/pre-existing]`, for example), with its `lane`, `order` within the lane, `function` name, the `contract` it inspects, and an `agents` policy map. An agent absent from the map defaults to `enabled`, so a guard with no explicit policy and any future agent run the full stack; only an explicit `disabled` removes a guard for one agent.

Example: `premature` runs on Stop for Claude but not Codex.

```json
"premature": {
  "lane": "stop-mutex",
  "order": 40,
  "function": "guard_premature",
  "contract": "final-answer",
  "agents": { "claude": "enabled", "codex": "disabled" }
}
```

A guard cannot move to an event whose contract it does not read: `premature` inspects `final-answer`, which only `Stop` provides, so placing it on a PostToolUse lane is rejected. `bin/validate-registry` enforces this and the rest of the schema (known lane, known contract, the lane event provides the guard's contract, agent values limited to `enabled`/`disabled`, unique order within a lane, and every guard backed by a `hooks/guards/<id>.sh` that defines its `function`). Run it after any registry edit:

```bash
bash packages/dont-do-that/bin/validate-registry
```

If `guards.json` is missing or not valid JSON, the dispatcher fails closed on PreToolUse: it denies the tool call with a `[dont-do-that/registry]` message instead of silently running no guards, so a corrupt registry cannot disarm the safety gates unnoticed. The PostToolUse and Stop lanes (context and nudge output, not irreversible-action gates) stay quiet in that state; the PreToolUse denial surfaces the problem on the next tool call regardless.

After editing the registry, run `bin/plugin-adapters build .` so the generated Codex adapter picks up the new `guards.json` and any manifest change. To verify an edit took effect without writing anything, `bin/plugin-adapters check .` reports drift read-only (it is what CI and a pre-commit check would run); `build` is only needed when `check` reports the adapter is behind.

### Adding a new guard

A registry entry is only half of a guard; it also needs a backing script. To add a guard with id `<id>`:

1. Write `hooks/guards/<id>.sh` defining a shell function `guard_<id>()` that reads the hook JSON on `$1` and, when it fires, calls one of the `dd_emit_*` helpers from `hooks/lib/common.sh` (`dd_emit_deny` to block a PreToolUse tool, `dd_emit_context` to surface PostToolUse context, `dd_emit_block` to block a Stop) with the `<id>` mnemonic.
2. Register it in `guards.json`: pick a `lane` whose `event` provides the `contract` your guard inspects, give it a unique `order` within that lane, name its `function`, and set an `agents` policy (omit an agent to default it to `enabled`).
3. Run `bash bin/validate-registry` to confirm the placement and the script-and-function binding.
4. Run `bin/plugin-adapters build .` to sync the Codex adapter.

The validator refuses a registry entry with no backing `hooks/guards/<id>.sh` or whose script does not define the named `function`, so a typo surfaces before the dispatcher ever sources it.

Every user-visible hook message begins with the mnemonic prefix `[dont-do-that/<code>] `. The code is a stable short identifier that maps to the guard listed below. The message itself is a single actionable line. When you want the full rule behind a code, read this file or `hooks/guards/<code>.sh`.

## Codes and guards

### PreToolUse (file edits)

**`no-code-comments`** in `hooks/guards/no-code-comments.sh`
Denies file-edit tool calls that introduce a code comment in a programming-language source file. Claude `Edit` / `Write` / `MultiEdit` inputs compare old-side and new-side content; Codex `apply_patch` inputs inspect only added patch lines per target file. The reflex to add a comment is usually a missed refactor (an intent-revealing name, an extracted method, a sharper signature), so the gate pushes back at the easy path. Per-language awk tokenizers in two modes (`slash` for C-family covering JS/TS/Swift/Kotlin/Java/Scala/Groovy/Go/Rust/C/C++/C#/Dart/Objective-C; `hash` for script-family covering Python/Ruby/Bash/Zsh/Perl/Elixir/Crystal/Rakefile/Gemfile) walk the diff character-by-character, track string state (including template literals and triple-quoted strings), and emit only real comments, never strings that contain comment-looking text. In slash mode a backslash-then-anything pair is consumed as an escape so regex-literal interiors like `/a\/b/` do not trip the `//` detector. The added-comment set is the new-side comments minus the old-side comments; a touched comment counts as added so renaming `# foo` to `# bar` is also blocked. Doc comments (`///`, `//!`, `/** */`) are blocked the same as plain comments: the operator's intent is "no inline explanation"; use `allow-comment:` if a project relies on generated API documentation from source. Non-programming-language files (markdown, JSON, YAML, HTML, CSS, ERB, env, dotfiles) pass without inspection. CSS is excluded because `/* ... */` is its only comment form and not a programming-language reflex; PHP is excluded because mixed HTML+PHP files would false-positive on the HTML parts; JSX (`.jsx`) and TSX (`.tsx`) are excluded because text content between JSX tags can contain `//` literally (`<p>// not a comment, just slash</p>`) which the tokenizer cannot distinguish from a code comment without full JSX parsing. Allow rules: comment containing `https?://` (a URL the language cannot express), comment containing `allow-comment:` followed by a reason (case-insensitive operator escape, one per comment, colon required so a passing mention of the word does not pass), pragma allowlist anchored at the start of the trimmed body (`frozen_string_literal`, `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck`, `@ts-check`, `@flow`, `noqa`, `pylint:`, `mypy:`, `pyright:`, `type:`, `eslint-disable`, `eslint-enable`, `prettier-ignore`, `biome-ignore`, `tslint:`, `rubocop:`, `sorbet:`, `stylelint-disable`, `stylelint-enable`, `go:` directives, `Generated by`, `DO NOT EDIT`, `Code generated`, `@generated`, `Auto-generated`, `Copyright`, `SPDX-License-Identifier`, `License:`, `Licensed under`, `All rights reserved`, `See LICENSE`, `encoding:`, `coding:`), or a shebang (`#!`) on line 1. Pass condition: rewrite the code for clarity (rename the variable, extract a method, sharpen the signature) instead of explaining it in a comment, or use one of the listed allow rules.

Known limitations. Ruby and Bash heredoc bodies are not shielded, so a `#`-prefixed line inside a Ruby `<<~SQL ... SQL` block or a Bash `<<EOF ... EOF` block can register as a comment when edited; use `allow-comment:` on the heredoc line if it bites. Nested JS template literals (`` `${`inner //`}` ``) may close the outer template state early; the inner `//` then fires as a comment. Triple-quoted Python or Swift strings do not handle a literal `\"` before the close, so an embedded escaped triple-quote can mis-end the string. These three cases are uncommon enough that the `allow-comment:` escape is the right exit; deeper parsing would risk new false positives.

### PreToolUse (Bash)

**`followup`** in `hooks/guards/followup.sh`
Denies `gh api` commands whose body contains deferral language ("follow-up", "wordt opgepakt", "buiten scope", "in een volgende pr", and similar) unless the body starts with `Bewust uitgesteld:`. Pass condition: prefix the body with `Bewust uitgesteld:` to claim an explicit deferral, or rewrite the body without deferral language.

**`no-worktree-deploy`** in `hooks/guards/no-worktree-deploy.sh`
Denies `ansible-playbook` invocations when the cwd is a git worktree rather than the canonical checkout. The check compares `git rev-parse --git-dir` against `--git-common-dir` (a worktree has these diverge, a regular checkout has them collapse), so the guard works for any worktree layout. Read-only flags pass: `--check`, `--syntax-check`, `--version`, `--help`, `--list-tasks`, `--list-hosts`, `--list-tags`, `-h`. Pass condition: merge the branch to the default branch first and run `ansible-playbook` from the canonical checkout, or restrict the worktree call to a read-only preview flag. Enforces the operator's "branches are never deployed from a worktree" gate so an in-flight branch cannot land on shared infrastructure before merge.

Commit-message discipline (subject banlist, rotation reminders, format/length,
body schema, push gates) lives in the `git-discipline` plugin and the
`/git-discipline:commit-discipline` skill. It used to ship from
`dont-do-that`; this README intentionally does not duplicate the contract.

### PostToolUse (file edits and shell)

**`dash`** in `hooks/guards/dash.sh`
Surfaces additional context when em-dash (U+2014) or en-dash (U+2013) appears in `.md`, `.txt`, or `.mdx` files outside of fenced code blocks, in any persisted file content, added `apply_patch` lines, or in a shell command (clipboard, pipes). Chat is not checked. Does not block, only surfaces a rewrite instruction.

**`land`** in `hooks/guards/land.sh`
Surfaces additional context when the vague "land" metaphor (`land`, `landing`, `landed`, `geland`, `landt`) appears in persisted file content, added `apply_patch` lines, or a shell command, outside of fenced code blocks. The match is a plain case-insensitive substring, so ordinary words (`Nederland`, `landscape`, `landing page`) trip it too; that is deliberate. The word is off the naming doctrine and reads as filler that names nothing concrete, but it is also an ordinary word, so this stays a gentle reminder to pick a concrete verb, never a hard gate. Does not block, only surfaces a rewrite instruction.

### Stop

**`pre-existing`** (false-claims) in `hooks/guards/false-claims.sh`
Blocks Stop when the recent assistant text relativizes a test or error as already existing before the current change. Also runs when `stop_hook_active` is true (keeps its own per-session line tracker). Pass condition: fix the failure, or formulate it as parallel work in the same directory when there is concrete evidence of a parallel session.

**`cache`** in `hooks/guards/cache.sh`
Blocks Stop when the recent assistant text blames cache for a problem on localhost. On a dev server, cache is rarely the real cause. Pass condition: investigate and name the actual root cause.

**`compliance`** in `hooks/guards/compliance.sh`
Blocks Stop when the last assistant message ends with a confirmation question ("Wil je dat ik...?", "Shall I...?", "Moet ik...?") despite a clear user instruction. Pass condition: continue the work and stop asking, or prefix the question with 🧭 for a genuine new direction.

**`premature`** in `hooks/guards/premature.sh`
Blocks Stop when the last assistant message does not end with a question AND does not end with 🏁 (finish) or 🚦 (waiting on external go) plus a substantive sentence (≥40 non-space non-emoji chars with a sentence terminator). Catches truncated close-outs and bare emoji free passes. Mutually exclusive with `compliance` by condition. Pass condition: end with 🏁 + real sentence when work is done, or 🚦 + real sentence when waiting on an external go, or keep writing.

**`prefer`** in `hooks/guards/prefer.sh`
Blocks Stop when the assistant lays out an option menu and hands the choice back without committing to one. Menu detection fires on four structural patterns (two or more `(a)`/`(b)` markers, two or more `Optie`/`Option N` items, a markdown table whose header row names an `optie`/`option`/`aanpak`/`approach`/`variant` column, or two or more ordered-list items), then gates on a choose-between signal (`welke`, `which do/would/one`, `je voorkeur`, `jouw keuze`, `do you prefer`, `your call`, and the like) so confirmation questions, status tables, and step-by-step plans stay silent. Runs before `premature` and `compliance` so a menu is judged here instead of being swallowed by the generic close-out nudges. Pass condition: state the preference you would back and why, then mark your pick with a squared-letter (🅰️/🅱️) or number-keycap (1️⃣/2️⃣) emoji; 🧭 (genuinely the operator's call) and 🚧 (WIP) also stand the guard aside. When the `rover` plugin is installed the reminder adds a `/rover:decide` pointer for genuinely hard calls.

**`verify`** (verification-delegation) in `hooks/guards/verify.sh`
Blocks Stop when the assistant delegates verification to the user ("zou moeten werken", "check of het werkt", "refresh de pagina") instead of verifying itself. Meta-references (backticks, quoted strings, table cells) are stripped before matching. Pass condition: prefix the conclusion with `Geverifieerd:` after actually running verification (screenshot, curl, test, grep).

**`duh`** in `hooks/guards/duh.sh`
Sister to `verify`. Blocks Stop when the assistant offers a recipe ("je kunt dit doen door `cmd` te draaien", "you can verify this by running `cmd`", "Run `cmd` to see the result", "open the URL in your browser") for an action it could have executed itself via available shell, file-edit, or browser tooling. Fenced code blocks are stripped first so documentation examples do not trigger. Pass condition: actually run the action and report the result, or prefix the line with `Instructie:` when the operator explicitly asked for a manual recipe.

**`tool-error`** (nudge-after-tool-error) in `hooks/guards/tool-error.sh`
Blocks Stop when the last significant event in the transcript was a failed tool call. Also runs when `stop_hook_active` is true. Maximum two nudges per session (hard cap), with LINE_FILE tracking so we only fire on new errors. Pass condition: analyse the error and retry instead of giving up.

**`estimate`** in `hooks/guards/estimate.sh`
Blocks Stop when the assistant text frames effort or scope in hours, days, weeks, or months ("een paar uur eerlijk werk", "halve dag uitzoekwerk", "dagje sleutelen", "kost een week", "takes a day", "a few days of work", "binnen een uur", "this is a week of work", and the comparison frame "option A is vandaag, option B is deze week"). LLM-trained duration claims are routinely 10x to 100x off for work an agent session can actually do, and decisions get made on the inflated figure. Mutex-respecting (skips when `stop_hook_active` is true) and runs before `premature` so the specific reason surfaces instead of the generic close-out nudge. False-positive guards drop hits on the same line as past-tense markers (geleden, ago, sinds, afgelopen), calendar and scheduling tokens (cron, every, elke, recurring, schedule), retention windows (retention, TTL, cooldown, backoff), measurement language (duration:, since, running, loopt, wait, the last, history, uptime, live, expir, bracket), legal and SLA facts (loon, opzegtermijn, SLA, jaarrekening, in productie), and absolute-time references (over X uur, tomorrow, morgen, gisteren). Pass conditions: drop the duration phrasing, replace it with a concrete count (files touched, edits, verifications), prefix the turn with `🧭` for a deferred-judgment user-choice, or close with `🚧` for WIP.

## Skills

**`/duh`** in `skills/duh/SKILL.md`
User-invocable correction skill, the read-time counterpart to the `duh` guard. The operator types `/duh` (no arguments) when the previous assistant turn offered a recipe, instruction, browser action, or confirmation question instead of executing the proposal. The skill resolves the proposal from that previous turn and runs it via the available tools. The proposal must be exactly one super-clear non-ambiguous action; if multiple distinct candidates exist in the previous turn, the skill mandates a numbered menu of every option (no upper bound; even ten) and asks the operator to pick before any execution. Different actor (one option operator-side, one assistant-side) does not collapse two options to one. Inviolable gates (push, merge to default, deploy, destructive git, external irreversible ops) are not lifted by `/duh`; they still require an explicit operator go.

**`/just-a-question`** in `skills/just-a-question/SKILL.md`
Sister to `/duh`. The operator types `/just-a-question` to mark the message as the first half of "this is a question for information, not a request for change". For the rest of that turn, all mutation tools are forbidden (file-edit tools and mutating shell commands like `git commit`/`push`/`rm`/`mv`/`launchctl`, etc.). Read-only tools stay available (file reads, search, read-only shell commands, and available explore agents). When the answer reveals an obvious fix, the skill names it but does not apply it. This is an explicit lock, not a rule for every question mark: QA/status checks on work the agent is currently driving (CI status, PR screenshots, PR body evidence, release notes) remain part of the deliverable, and a failed check is a blocker to fix. The operator can request the change in a separate turn without the `/just-a-question` prefix.

## Installation

```bash
claude plugins install dont-do-that@laicluse-agent-fieldkit
codex plugin add dont-do-that@laicluse-agent-fieldkit
```

## Disabling individual guards

The dispatcher always runs, but individual guards fire based on the message content. To silence one guard for an agent durably, set that guard's `agents.<agent>` to `disabled` in `hooks/guards.json` and run `bin/plugin-adapters build .`. For a one-off silence in your own install, set `DD_SKIP_GUARDS=<id>` (or the event-specific `DD_SKIP_STOP_GUARDS=<id>`) on the dispatcher command in your hook manifest. To silence the plugin entirely, uninstall:

```bash
claude plugins uninstall dont-do-that@laicluse-agent-fieldkit
codex plugin remove dont-do-that@laicluse-agent-fieldkit
```

## Known quirk

These hooks scan assistant transcripts for trigger phrases. Documenting or discussing the hooks themselves can trigger them (meta false positives). If you are editing the scripts or writing docs about them, expect occasional Stop blocks. The WIP escape hatch 🚧 in your assistant text skips Stop guards while you work on the hook system.

## Language

Trigger patterns match both Dutch and English phrasing. Messages are in English. Some escape tokens remain Dutch (`Bewust uitgesteld:`, `Geverifieerd:`) because they are deliberate trigger words that the agent must type verbatim to pass a guard.

## Tests

```bash
bash packages/dont-do-that/test/smoke-test.sh
```

The smoke test drives every trigger case through `hooks/dispatch.sh` with an explicit `hook_event_name`, matching the real runtime path. Exit 0 on all pass.
