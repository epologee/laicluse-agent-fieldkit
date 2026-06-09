---
name: how-plugins-work
description: >-
  Use when diagnosing Unknown command errors, slash-command autocomplete misses,
  cross-agent skill or plugin marketplace sync, or any confusion about how plugin
  and skill names resolve in Claude Code, Codex, and future coding agents. Living
  document explaining plugin naming, skill resolution, multi-agent adapter
  boundaries, marketplace aliases, runtime caches, and the plugin:skill
  invocation pattern, based on empirical testing.
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the how-plugins-work plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("how-plugins-work was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. Codex currently has no equivalent
post-update broadcast path in this plugin; skip this block silently there.
</post-update-broadcast>

# How Plugins Work

A living document on how plugin and skill names flow through Claude Code, Codex,
and future coding-agent systems. Based on empirical testing with the legacy
`leclause` marketplace in Claude Code 2.1.x, plus local CLI verification for
Codex during the l'Aicluse migration.

## l'Aicluse migration state

This copy is the first local slice of `laicluse-agent-tools`. It is not public
yet and has no remote. Existing external users should keep using
`@leclause`. They should not uninstall, reinstall, or rename anything until the
old marketplace contains actionable migration stubs.

The future public alias is `@laicluse-agent-tools`. A marketplace alias is an
installation identity, not a branch name and not an automatic rename target.
`how-plugins-work@leclause` and `how-plugins-work@laicluse-agent-tools` can
coexist during the transition.

## The three names

A skill in a marketplace plugin has three independent names:

1. **Plugin name** (`plugin.json` > `name`): determines the namespace.
2. **Skill name** (directory name under `skills/`): determines the identity.
3. **Marketplace name** (marketplace.json > `name` or the `@marketplace` identifier): determines the source.

These three names are completely independent of each other. Claude Code and
Codex combine them in different ways in different places.

## Where each appears in Claude Code (empirically verified)

| Context | What appears | Example |
|---------|--------------|---------|
| `claude plugin list` | `<plugin>@<marketplace>` | `how-plugins-work@leclause` |
| `claude plugin install` | `<plugin>@<marketplace>` | `claude plugin install how-plugins-work@leclause` |
| `settings.json` enabledPlugins | `"<plugin>@<marketplace>": true` | `"how-plugins-work@leclause": true` |
| `installed_plugins.json` key | `"<plugin>@<marketplace>"` | `"how-plugins-work@leclause": [...]` |
| Plugin cache path | `cache/<marketplace>/<plugin>/<version>/skills/<skill>/` | `cache/leclause/how-plugins-work/<version>/skills/how-plugins-work/` |
| `skill-budget` SOURCE column | `<plugin>` | `how-plugins-work` |
| `skill-budget` NAME column | `<skill>` | `how-plugins-work` |
| System-reminder skill list | `<plugin>:<skill>` | `how-plugins-work:how-plugins-work` |
| TUI autocomplete | `/<plugin>:<skill>` | `/how-plugins-work:how-plugins-work` |
| Skill tool invocation | `Skill("<plugin>:<skill>")` or bare `Skill("<skill>")` | `Skill("how-plugins-work")` |
| Slash command (bare) | `/<skill>` (if unique) | `/how-plugins-work` |
| `claude agents` | `<plugin>:<name> · <model>` | `gurus:sonnet-max · sonnet` |
| Agent tool invocation | `subagent_type: "<plugin>:<name>"` | `subagent_type: "gurus:sonnet-max"` |
| Plugin-shipped agent source | `packages/<plugin>/agents/<name>.md` | `packages/gurus/agents/sonnet-max.md` |

### Observations

**Plugin name appears in five contexts:** plugin list, settings.json, installed_plugins.json, skill-budget SOURCE, and as namespace prefix in system-reminders and autocomplete.

**Skill name appears in three contexts:** skill-budget NAME, as suffix after the colon in system-reminders, and as bare slash command.

**Marketplace name appears in two contexts:** after the `@` sign in plugin list and settings.json. Never in the skill invocation itself.

**The `<plugin>:<skill>` combination** is how the model sees the skill in system-reminders and how it calls the Skill tool. When plugin and skill share the same name, you get `how-plugins-work:how-plugins-work`. The bare shortcut `/how-plugins-work` works when there are no name conflicts.

## Where each appears in Codex

Codex uses the same shared `skills/<skill>/SKILL.md` body, but it reads Codex
metadata instead of Claude metadata. Local CLI help verified on 2026-06-09:

| Context | What appears | Example |
|---------|--------------|---------|
| Marketplace add | local path or Git source | `codex plugin marketplace add ./` |
| Plugin install | `<plugin>@<marketplace>` | `codex plugin add how-plugins-work@laicluse-agent-tools` |
| Marketplace index | `.agents/plugins/marketplace.json` | `name: laicluse-agent-tools` |
| Plugin source path | `plugins[].source.path` | `./packages/how-plugins-work` |
| Plugin manifest | `.codex-plugin/plugin.json` | generated from `.claude-plugin/plugin.json` |
| Skill body | `skills/<skill>/SKILL.md` | shared with Claude |

Important differences from Claude:

- Codex marketplace metadata lives under `.agents/plugins/`, not
  `.claude-plugin/`.
- The Codex plugin manifest is stricter JSON generated into
  `.codex-plugin/plugin.json`.
- Codex frontmatter parsing uses stricter YAML behavior; a `description` with
  YAML-special punctuation must use a folded scalar.
- Generated Codex targets are adapter files. Edit the Claude/source metadata or
  the shared `SKILL.md`, then run `bin/plugin-adapters build .`.
- Claude-only frontmatter keys such as `user-invocable` stay in the shared
  source for Claude, but Codex receives a generated sanitized copy when needed.

## Uniqueness and conflicts

### Within a marketplace

The unique key is `<plugin.json name>@<marketplace>`. The plugin name comes from `plugin.json`, not from the directory name. If two packages have the same `name` in their `plugin.json`, they claim the same key and overwrite each other on install.

Two **different plugins** in the same marketplace may contain a skill with the same name. They are namespaced: `pluginA:review` vs `pluginB:review`. But bare `/review` then becomes ambiguous.

### Across marketplaces

`superpowers@claude-plugins-official` and `superpowers@leclause` can coexist (different keys). But `Skill("superpowers:brainstorming")` contains no marketplace, so if both have a `brainstorming` skill the resolution is unpredictable. Avoid plugin names that already exist in other installed marketplaces.

## SKILL.md frontmatter

### name

Optional. When present it must match the directory name. If they do not match, documented bugs exist: the model cannot find the skill on invocation (anthropics/claude-code#22063). The directory name is always the source of truth.

### user-invocable

**Always set explicitly.** Although the binary code (below) suggests the default is `true`, in practice skills without explicit `user-invocable: true` do not always appear in autocomplete. Always set the field explicitly: `true` for slash commands, `false` for skills that are model-triggered only.

Binary code from Claude Code 2.1.92 (the default `true` is not reliable for plugins):
```javascript
T = H["user-invocable"] === void 0 ? !0 : G0H(H["user-invocable"])
```

### disable-model-invocation

When `true`: the model cannot auto-activate the skill based on context. The skill is then only reachable via explicit slash command. Useful for skills that should never be auto-triggered (e.g. `/clipboard`, `/saysay`). Reduces the active context budget in `skill-budget`.

**The flag replaces "Use ONLY when..." prose in the description.** A description like `Use ONLY when the operator types /foo. Do not auto-invoke. <what it does>` is two layers of the same intent: the prose tries to talk Claude out of auto-triggering, while the harness already enforces it via `disable-model-invocation: true`. Pick the flag, drop the prose, and let the description describe what the skill does. Every "Use ONLY when..." token costs every session that loads the skill list, forever; the flag costs nothing.

### description

What the model sees in the skill list and uses to decide auto-invocation. Two anti-patterns to avoid:

- **"Use when the user types /X to ..." prefix.** When the skill has `disable-model-invocation: true`, the slash command is the only way in, so the prefix is redundant. When the skill is model-triggerable, the trigger lives in the auto-invocation criteria the rest of the description describes; restating the slash form is noise.
- **Embedding the skill body in the description.** Disambiguation rules, edge cases, and step-by-step procedures belong in the body, not the description. The description is read on every turn the skill list is loaded; the body is read only when the skill is invoked.

Lean reference: `dont-do-that:just-a-question` describes what the skill enforces in two short sentences and parks the rest in the body.

### Frontmatter must be strict YAML

Claude Code's frontmatter parser is lenient: a plain scalar `description:` that contains `: ` (colon-space), starts with a quote, or holds other YAML-special punctuation still loads, because the parser just grabs the rest of the line. Strict YAML parsers (Ruby's psych, and the Codex `.codex-plugin` toolchain that reads the same SKILL.md) reject it with `mapping values are not allowed in this context`. The two readers then disagree on a file that looked fine in Claude Code.

Keep every frontmatter value valid under a strict parser so the file means the same thing in every consumer. When a `description` contains `: `, a leading quote, or a leading `#` / `|` / `>` / `@`, use a folded block scalar instead of an inline plain scalar:

```yaml
description: >-
  Speech mode: Claude speaks every response aloud via macOS say. /saysay off to exit.
```

`>-` folds the indented lines into one space-joined string and strips the trailing newline, so the parsed value is byte-identical to the intended one-liner, colons and quotes preserved. A plain one-line scalar stays fine when the text carries no YAML-special punctuation; reach for `>-` only when it does. Verify with a strict parser before shipping:

```bash
ruby -ryaml -e 'YAML.safe_load(File.read(ARGV[0]).split(/^---\s*$/)[1])' SKILL.md
```

## Cross-agent skill and plugin sync

Agent Skills are the portable layer. Keep `skills/<skill>/SKILL.md` as the shared source whenever the workflow can mean the same thing across Claude Code, Codex, and other skills-aware clients. Do not copy the skill body into an agent-specific tree just because a second client needs different installation metadata.

Plugin and marketplace manifests are adapter layers. Claude Code and Codex both load `skills/`, but they do not use the same manifest and marketplace files:

| Layer | Shared source | Claude Code adapter | Codex adapter |
|-------|---------------|---------------------|---------------|
| Skill body | `skills/<skill>/SKILL.md` | loaded from the plugin root | loaded from the plugin root |
| Plugin manifest | package identity and component paths | `.claude-plugin/plugin.json` | `.codex-plugin/plugin.json` |
| Marketplace index | curated plugin list | `.claude-plugin/marketplace.json` | `.agents/plugins/marketplace.json` |
| Runtime cache | none; cache is output | `~/.claude/plugins/cache/...` | `~/.codex/plugins/cache/...` |

### Source and target roles

Every duplicated-looking file should have one explicit role:

- **Source.** Hand-edited truth, usually the shared skill body or the primary marketplace manifest.
- **Generated target.** Agent-specific manifest or catalog written from the source by a deterministic builder.
- **Runtime cache.** Install output. Never edit it as source and never use it to prove the repo is current.
- **Forked semantics.** A deliberate divergence because two agents cannot support the same behavior. Name the drift hypothesis so future maintainers know why the fork exists.

If a file is a generated target, the repo should expose the usual three verbs:

```bash
<sync-tool> build
<sync-tool> check
<sync-tool> diff
```

`build` rewrites adapter files from the source, `check` exits non-zero on drift, and `diff` shows the exact generated change. This is the minimum contract that makes metadata duplication acceptable: a reviewer can tell whether the duplicate is another truth or a projection.

### What belongs in shared SKILL.md

Keep shared skill text in agent-neutral language when possible: "the active agent", "the shell-command tool", "the plugin root", "the installed cache". Use Claude-specific names only when the behavior is genuinely Claude-specific, such as `/reload-plugins`, `Skill("<plugin>:<skill>")`, `CLAUDE_PLUGIN_ROOT`, or Claude hook events.

When a shared skill has a Claude-only block and still wants to be packaged for other clients, prefer one of these shapes:

- A clearly labelled Claude-only section that other clients can ignore.
- A generic instruction with runtime-specific examples underneath.
- A generated sanitized adapter view, if a client rejects the frontmatter or body syntax outright.

Do not remove Claude frontmatter or hook guidance merely to satisfy another client. If another client needs stricter metadata, generate the stricter view or manifest beside the Claude source.

### Direction of dependency

Public plugin documentation may define the generic sync contract. Private or project-specific generators may consume that contract and even assume this skill is installed. The reverse dependency is not allowed: a public plugin should not name a private synchronizer, private path, personal doctrine repo, or local machine convention.

## Model selection

A skill **cannot** change the session model. The model the user chose at session start (or via `/model`) runs through all turns, including turns fired by cron. A skill that outputs `/model <name>` as text behaves like a fake user input, is unreliable, and persists after the skill run, corrupting the user session.

**Subagents can.** The `Agent`/`Task` tool accepts a `model` parameter (`haiku`, `sonnet`, `opus`). A subagent runs in a separate conversation context with its own model, returns a result, and does not touch the session model. This is the correct mechanism for:

- Token savings in cron-driven loops (delegate poll work to a Sonnet subagent)
- Parallel independent tasks (multiple agents on different models at the same time)
- Reserving the session model for reasoning while mechanical work runs cheaper

**Rule of thumb:** session model = head, subagent = hand. Give subagents work that requires no interpretation (running commands, reading files and returning them raw, scraping gh). Keep interpretation and decisions on the session model.

**Effort cannot be set per invocation.** The Agent tool only accepts `model` inline, not `effort`. The only route to run a subagent at `effort: max` (or any other level) is via a plugin-shipped or user-level agent definition with the `effort` frontmatter field. See "Plugin-shipped subagents" below.

## Plugin-shipped subagents

In addition to skills, a plugin can also ship subagent definitions under `packages/<plugin>/agents/<name>.md`. This is simultaneously the only way to make a pre-configured `model` + `effort` combination available for runtime spawn, because the Agent tool only accepts `model` inline.

### Frontmatter

Supported: `name`, `description`, `model` (`sonnet`/`opus`/`haiku`), `effort` (`low`/`medium`/`high`/`xhigh`/`max`). Ignored for security reasons when the agent comes from a plugin: `hooks`, `mcpServers`, `permissionMode`. If those fields are needed, copy the agent definition to `~/.claude/agents/` or `.claude/agents/`.

Example (empirically working in the leclause marketplace):

```markdown
---
name: sonnet-max
description: Generic subagent pinned to Sonnet at maximum effort.
model: sonnet
effort: max
---

Execute the invoker's prompt and return the result.
```

### Invocation

Plugin-shipped agents follow the same `<plugin>:<name>` namespace as skills. Call via the `Agent`/`Task` tool with `subagent_type: "<plugin>:<name>"`. For the example agent in `packages/gurus/agents/sonnet-max.md`: `subagent_type: "gurus:sonnet-max"`.

**Bare name does NOT work.** Unlike skills, where `/how-plugins-work` resolves as a bare slash command when unique, the Agent tool always requires the namespaced form for plugin-shipped agents. Empirical confirmation in Claude Code 2.1.92: `subagent_type: "sonnet-max"` fails, `subagent_type: "gurus:sonnet-max"` works.

### Verification without pushing

Three levels, from lightest to heaviest:

1. **`claude agents`.** Shows all loaded agents in `<plugin>:<name> · <model>` format. Runs against the current install cache; only works after a successful `claude plugin update`.
2. **`claude --plugin-dir ./packages/<plugin> agents`.** Loads the local plugin for one CLI session without mutating the install cache. Fastest way to test a change before commit/install. Note: the `--plugin-dir` flag is global; `claude agents --plugin-dir X` fails with `unknown option`, `claude --plugin-dir X agents` works.
3. **Live spawn test via `claude -p`.**

   ```bash
   claude -p --allow-dangerously-skip-permissions --output-format json \
     "Use the Task tool with subagent_type '<plugin>:<name>'. Ask for the string PING_42."
   ```

   The JSON output contains a `modelUsage` section with the configured model as a separate key (e.g. `claude-sonnet-4-6`). Two models in `modelUsage` (session + subagent) is the strongest evidence that the subagent was truly spawned with the desired model. The `effort` value is not visible in `modelUsage` or elsewhere in the CLI output; for that it rests on a documentation assumption.

   **What `claude -p` does and does not test for cron-driven features.** Print mode is one-shot: one prompt, one answer, session over. The cron itself does not fire in `-p` (it lives on an idle interactive REPL), so auto-triggering ticks is ruled out. What `-p` can do well: test per-tick behavior by supplying a pre-constructed state and asking the session to "follow the Instructions for the current Phase as if a tick was fired". For the autonomous rover: write a stub loopfile with the desired Phase and (optionally) an aged timestamp in the Log, then start `claude -p "Read .autonomous/X.md and act on the current Phase as if a cron tick just fired."`. That validates fuse/timeout/backoff logic without waiting for real wallclock. To also confirm cron-firing itself, fall back to a fresh interactive session (`claude` in a new terminal or iTerm2 pane). Claude has shell access and can spawn `-p` itself; do not dictate this to the user when you can run it yourself.

### Local marketplace for persistent install without pushing

Claude Code: `claude plugins marketplace add ./` re-points an existing
marketplace alias to the local path, provided `.claude-plugin/marketplace.json`
claims the same alias. After that, `claude plugins update
<plugin>@<marketplace>` pulls from the local working copy instead of the remote.
Useful for end-to-end testing of plugin changes without pushing first.

Codex: `codex plugin marketplace add ./` registers the local marketplace source,
and `codex plugin add <plugin>@<marketplace>` installs from that configured
marketplace. Codex reads `.agents/plugins/marketplace.json`, follows
`plugins[].source.path`, and then reads the package `.codex-plugin/plugin.json`.

**Gotcha 1: cascade-uninstall on marketplace remove.** `claude plugin marketplace remove <alias>` does not only remove the marketplace configuration; it also uninstalls every plugin that was installed via that alias. Empirically tested in Claude Code 2.1.92: a leclause marketplace with 18 installed plugins crashed to 0 after a single `remove`. Re-adding the marketplace does not automatically restore the plugins; each plugin must be explicitly re-invoked with `claude plugin install <plugin>@<alias>`. For a local dev session where you switch between path-based and remote-based marketplace with the same alias: this means a re-install of every plugin that comes from that alias, not just a config change.

**Reverting to remote: silent overwrite, no cascade.** The symmetric path from path-based back to remote works without `marketplace remove`: `claude plugins marketplace add <owner>/<repo>` (e.g. `claude plugins marketplace add epologee/leclause-skills`) overwrites the existing alias's `source.source` field in-place from `directory` to `github`, provided `marketplace.json`'s `name` claims the same alias again. Empirically tested in Claude Code 2.1.119: all 18 installed leclause plugins remained intact; no cascade-uninstall, no re-install batch needed. The old `path` field stays as residue in the settings.json record, but the active `source.source: github` wins and `claude plugins update` pulls from the remote from that point. Same silent-overwrite mechanism as the gotcha-free overwrite to path-based, just in reverse.

For `laicluse-agent-tools`, there is no remote yet. Do not document or execute a
remote revert until the repo has actually been published.

## marketplace.json `source` must be a real subpath

The `plugins[*].source` field in `marketplace.json` passes through two layers, and the difference between them can be misleading (Claude Code 2.1.119, empirical against `epologee/apples`):

- **Schema validation.** `"source": "."` fails with `Invalid input` on `claude plugin marketplace add`. `"source": "./"` succeeds and the marketplace lands in `~/.claude/settings.json` under `extraKnownMarketplaces`. The schema therefore rejects the bare dot but accepts the slash variant.
- **Runtime resolution.** `"./"` survives schema validation but does not resolve. Symptoms:
  - `claude plugin marketplace list` does not show the marketplace.
  - `claude plugin marketplace update <name>` says `Marketplace not found`.
  - `claude plugin install <plugin>@<marketplace>` fails with `Plugin "<plugin>" not found in marketplace`.
  - The settings.json entry remains as an orphan; `enabledPlugins` has `<plugin>@<marketplace>: true` even though nothing ever installed.

**Conclusion.** `source` must be a real subdirectory, not the marketplace root. Working forms in this setup: `"./packages/<plugin>"` (leclause), `"./plugins/<plugin>"` (stekker-brains). Single-plugin repo where the plugin claims the root: move `.claude-plugin/plugin.json` and `skills/` to e.g. `./packages/<plugin>/` and update `source` accordingly. The marketplace-level `.claude-plugin/marketplace.json` stays at repo root.

**Local-vs-remote is not a factor.** The schema test was only run against a local directory, but both local and remote (leclause, stekker-brains) marketplaces in the active setup already use subpaths. The rule is source-independent.

**Diagnostic signal chain.** When `claude plugin marketplace add` succeeds but `claude plugin marketplace list` does not show the marketplace and install fails with "Plugin not found in marketplace", `source` is the first thing to verify. Schema pass does not imply runtime pass.

## Reading env vars from settings.json

The `env` section of `~/.claude/settings.json` exports variables to child bash processes that Claude Code spawns. Those values are **not visible in Claude's conversation context**. A skill that wants to condition behavior on an env var must query the value via bash. Claude does not "know" the value on its own and will guess.

Two anti-patterns that often occur together:

1. **Implicit check.** SKILL.md writes "if `VAR` is not set, do X" without a prescribed bash step that queries the value. Claude must then realize a check is needed and usually guesses "unset".
2. **Passive code fence.** SKILL.md puts the action bash in a ```bash block without an imperative label. Claude may read it as an example and skip execution.

**Pattern:** one explicit "RUN THIS FIRST" step that combines bash check and action and prints a marker output that the next step branches on. No condition line elsewhere in the markdown that leans on implicit knowledge about an env value.

```bash
# First action of every invocation:
state="${VAR:-unset}"
[ "$state" = "on" ] && do_the_thing &
echo "state=$state"
```

Then a decision table driven by `state`, not by markdown prose:

| `state` | Next action |
|---------|-------------|
| `on` | Continue normally; no reveal |
| `off` | Continue normally; no reveal |
| `unset` | Append one-time reveal-PS at end |

**First-run reveal via the env var itself.** An elegant mute without a state file on disk: `on`/`off` both suppress the hint, absent shows it once. Only robust if step 1 hard-reads the value; otherwise the elegance breaks and the hint is shown randomly.

Empirically observed in whywhy v1.0.10 (2026-04-22): the reveal-PS appeared for a user who had had `WHYWHY_JINGLE=on` in settings for 3 days, while the jingle did not play. Both symptoms of Claude not having read the env value: the reveal condition guessed "unset", and the afplay fence was not executed.

**Session-lifetime footnote.** Env updates in `settings.json` are only seen by new Claude Code sessions. A session that started before a settings commit keeps the old values until restart. When diagnosing strange behavior ("var is set to on but skill behaves as unset"), compare the session start time with the commit that added the var before blaming the skill itself.

## Symlinks and cross-platform

The leclause and l'Aicluse marketplaces are symlink-free. Every skill lives in one place under `packages/<plugin>/skills/<skill>/`, without shared source via symlinks. Pre-commit and CI reject symlinks in the repo. The reason is Windows: Git for Windows has `core.symlinks=false` as default, so on clone symlinks are converted to text files containing the target path, and runtime resolution in Claude Code fails. A symlink-free layout works on macOS, Linux, and Windows without extra consumer setup.

Anthropic docs do mention that Claude Code preserves symlinks in the install cache ([Plugins reference, Plugin caching and file resolution](https://code.claude.com/docs/en/plugins-reference)), but that requires the symlinks to survive the clone in the first place. The three alternatives explored in an earlier experiment (`git-subdir`, `rsync -aL` materialization via release branch, `CLAUDE_CODE_PLUGIN_SEED_DIR`) all turned out to require more consumer setup than a flat, symlink-free layout. The repo is aligned accordingly.

## Hooks

Hooks (SessionStart, PreToolUse, PostToolUse, Stop, and the other lifecycle events) do NOT live in `plugin.json`. A `hooks` key in `plugin.json` is rejected by `claude plugins validate` with `hooks: Invalid input`, and on install silently stripped without a runtime error. The working path is a separate `<plugin>/hooks/hooks.json` (or a custom location via `"hooks": "./path"` in plugin.json).

### Schema

The schema has a double `hooks` nesting that is easy to get wrong. Working example for SessionStart:

```json
{
  "description": "Optional: surfaces in claude plugins inspect.",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/install.sh"
          }
        ]
      }
    ]
  }
}
```

The outer `"hooks"` is the object that groups events; within each event entry there is a **second** `"hooks": [...]` array containing the actual commands. Omit that nesting and the plugin validates but the hook array comes through the validator as the wrong type.

### Matcher syntax

`matcher` is always a regex string, not an object. For PreToolUse / PostToolUse it matches on tool name (`"Bash"`, `"Edit|Write"`). For SessionStart it matches on source: one of `startup`, `resume`, `clear`, `compact` (or a pipe combination like `"startup|resume"`). Omitting `matcher` means fire on all sources; for an install hook that has nothing to do on `/clear` or an auto-compact, `"matcher": "startup|resume"` is the efficient choice.

Confirmed in Claude Code 2.x: `claude plugins validate` accepts both a missing matcher and the regex string. The object format `{"source": [...]}` does NOT work, despite some LLM suggestions naming that form.

### Validate before shipping

`claude plugins validate <path>` is the canonical pre-ship sanity check for every plugin manifest or hooks change. It runs against the local source path (not the install cache) and catches schema violations that would otherwise only become visible on a colleague's first install, often silently.

```bash
claude plugins validate ./packages/<plugin>
```

Run it after EVERY change to `plugin.json` or `hooks/hooks.json`. Not a replacement for a real install test, but a free first filter.

## Versioning

The `version` field in `plugin.json` is updated automatically by the marketplace
pre-commit hook. The format is `1.0.{commits}` where `{commits}` is the number
of commits that touched `packages/<name>/` or `skills/<name>/`. In
multi-agent repos, the same hook must rebuild generated Codex manifests after a
Claude manifest version bump; otherwise `.claude-plugin/plugin.json` and
`.codex-plugin/plugin.json` drift in the same commit.

## What lands in the plugin cache

Claude Code installs a plugin from the repo subpath specified in `marketplace.json` (usually `packages/<plugin>/`) and drops the full contents of that subpath into the cache. That means: `.claude-plugin/`, `skills/`, the plugin-level `README.md`, `bin/`, **and** `hooks/` (including the `hooks/hooks.json` manifest plus all hook scripts) all land there. Files outside the subpath (for example the repo-root `README.md` or the repo-root `bin/`) do not come along, because the plugin source starts at `packages/<plugin>/`, not at the repo root.

Empirically tested against `autonomous@leclause` version 1.0.23:

```
$HOME/.claude/plugins/cache/leclause/autonomous/1.0.23/
├── .claude-plugin/
│   └── plugin.json
├── README.md            (plugin-level, not repo-root)
├── bin/
│   └── relative-cron    (consumer-facing helper)
└── skills/
    └── <skill>/...
```

Older cache versions of the same plugin may have a different layout, depending on what was in the repo at the time of that install. Inspecting a cache against an old version proves nothing about the current source layout; test against a fresh `claude plugins update`.

## The path to the active install

The authoritative source for "which version is running now" is `~/.claude/plugins/installed_plugins.json`:

```bash
jq -r '.plugins["<plugin>@<marketplace>"][0].installPath' ~/.claude/plugins/installed_plugins.json
```

That path is the **plugin root in the cache**, not the repo root. It contains `.claude-plugin/`, `skills/`, `bin/` (if the plugin source has it), and the plugin-level `README.md`. Concrete path templates:

| Target | Correct path | Wrong path |
|--------|-------------|----------|
| Skill resource | `$installPath/skills/<skill>/<file>` | `$installPath/packages/<plugin>/skills/<skill>/<file>` |
| Bin script | `$installPath/bin/<script>` | `$installPath/packages/<plugin>/bin/<script>` |
| Plugin manifest | `$installPath/.claude-plugin/plugin.json` | (no other) |
| Hooks manifest | `$installPath/hooks/hooks.json` | `$installPath/.claude-plugin/plugin.json` (see Hooks section) |
| Hook script | `$installPath/hooks/<script>` (referenced via `${CLAUDE_PLUGIN_ROOT}/hooks/<script>` in hooks.json) | (absolute paths; do not work cross-machine) |

The `packages/<plugin>/` prefix only exists in the source repo, not in the cache. The `ls -1dt ... | head -1` trick against `~/.claude/plugins/cache/<marketplace>/<plugin>/` points to the same path but relies on mtime ordering and is therefore not stable; the `jq` lookup works deterministically.

## `/reload-plugins` and `/reload-skills`: re-read the installed set, do not update it

`/reload-plugins` is a TUI slash command that re-loads the currently-installed plugin set into the running session without a full restart. Its output looks like:

```
Reloaded: 32 plugins · 0 skills · 7 agents · 8 hooks · 0 plugin MCP servers · 0 plugin LSP servers
```

What it does: re-reads `installed_plugins.json` and re-binds every plugin, agent, hook, skill, and MCP/LSP server from each plugin's active `installPath` (the cache snapshot). It is the in-session alternative to the session restart that the troubleshooting steps below otherwise flag with 🚦.

What it does NOT do: it is not `claude plugins install` / `update`. It does not bump a cache version, does not rewrite `installPath` or `lastUpdated`, and does not re-resolve a `directory`-source marketplace against your working tree.

Empirically tested in Claude Code 2.1.156, with the leclause marketplace registered as a `directory` source pointing at the working copy. The working tree carried a new `wip_gate_commit_is_ours` function in `gitgit`'s `hooks/lib/wip-gate.sh`, committed on local `main`, while the active install was `cache/leclause/gitgit/1.0.135`. After `/reload-plugins`:

- gitgit stayed at version 1.0.135, identical `installPath` and `lastUpdated`; no new cache directory appeared.
- The active `installPath` still served the old code: `grep wip_gate_commit_is_ours "$installPath/hooks/lib/wip-gate.sh"` found nothing, even though the working-tree file had it.

Conclusion: editing a directory-backed marketplace's working tree and running `/reload-plugins` does NOT make the edit live; the reload re-loads the same stale cache snapshot. To pick up working-tree edits you must first `claude plugins update <plugin>@<marketplace>`, which copies the current working tree into a fresh cache version and rewrites `installPath`; only then does `/reload-plugins` (or a restart) load the new code. `/reload-plugins` usefully replaces the restart in the second half of that loop, never the update in the first half. The update snapshots the working tree as-is, including any uncommitted changes, so land or stash unrelated work first if you want a clean snapshot.

`/reload-skills` is the skill-catalog counterpart and behaves the same way against the same cache snapshots. Its output looks like:

```
Reloaded skills: 148 skills available (no changes)
```

It re-reads the full skill catalog (every plugin's `skills/` plus user-level skills) and reports the count, with a `(no changes)` suffix when the reloaded set is byte-identical to what was already loaded. It is complementary to `/reload-plugins`: the plugin reload re-binds plugins, agents, hooks, and MCP/LSP servers but reported `0 skills`, while the skill reload owns the `148 skills`. The same empirical run confirmed it does not pull working-tree edits either: after `/reload-skills`, how-plugins-work stayed at version 1.0.25 with the identical `installPath`, and the new section marker was still absent from the active cache SKILL.md while present in the working tree. So `(no changes)` here means "the installed cache snapshot is unchanged", not "your working-tree edits were checked and skipped". Reload never looks at the working tree. The update-then-reload loop above is the same for skills.

## Troubleshooting: "Unknown command: /xyz"

Observed symptom: user types `/rover` (or `/autonomous:rover`) and Claude Code replies `Unknown command`. Diagnose and fix. Do not narrate steps for the user to execute; Claude has shell access and can run the same commands. Dictating install commands is condescending when Claude can just install.

**Step 0 (mandatory, no exceptions).** Run `claude plugins list` yourself before forming any hypothesis. This command is the single source of truth. If the plugin is absent, every theory about prefixing, namespacing, or skill resolution is noise.

1. **Plugin not listed.** Run `claude plugins install <plugin>@<marketplace>`. The Claude process inherits the CLI so this just works. The only thing that is not Claude's to do is loading the freshly-installed plugin: the user runs `/reload-plugins` (in-session, no restart) or restarts the session. Flag that with 🚦 and wait for user go.

2. **Plugin listed but disabled.** Patch `~/.claude/settings.json` `enabledPlugins` to `"<plugin>@<marketplace>": true`. This is a user-level file; ask first before editing.

3. **Marketplace source out of date.** If the plugin only exists on a local branch that the marketplace source (GitHub or local path) has not seen, the install will fail. Fix the source: push the branch (requires user go) or re-point the marketplace at the working copy.

4. **Skill missing `user-invocable: true`.** Without the flag the skill is model-triggered only and no slash command appears. Edit the frontmatter.

5. **Skill name collision across enabled plugins.** Bare `/<skill>` only resolves when unique. Use `/<plugin>:<skill>` via autocomplete.

6. **Stale cache path.** Cached versions live under `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. A long-running session may point at an older cached skill set. Flag 🚦 for a restart, or `/reload-plugins` to re-bind the installed set in-session (note: reload re-reads the same `installPath`; it does not pick up working-tree edits without a prior `claude plugins update`, see the `/reload-plugins` section).

Never advise the user to prefix or de-prefix a slash command without having run step 0. "Namespacing is required" is a guess when the actual failure is almost always install state, enable state, or a stale session. And never dictate `claude plugins install ...` at the user; run it.

## Troubleshooting: Codex plugin install misses

Observed symptom: a Codex session does not see a plugin or skill expected from a
local marketplace.

1. Run `codex plugin marketplace list` and confirm the marketplace name and root.
2. Run `codex plugin list` and confirm the plugin appears under the expected
   marketplace.
3. Run `codex plugin add <plugin>@<marketplace>` if the plugin is not installed.
4. If the plugin exists in Claude metadata but not Codex, run
   `bin/plugin-adapters check .`; drift means the Codex adapter files are stale.
5. If `codex plugin add` cannot find the plugin, inspect
   `.agents/plugins/marketplace.json` first, then the package
   `.codex-plugin/plugin.json`.

Do not inspect `~/.codex/plugins/cache` as source. It is a runtime snapshot.

## Experiment metadata

- Original experiment: `hpw@leclause` (short plugin name, 2026-04-06)
- Renamed to: `how-plugins-work@leclause` (plugin = skill name, 2026-04-07)
- Cache layout + installPath verification: 2026-04-19 (against `autonomous@leclause` 1.0.23)
- Claude Code version: 2.1.92
- Marketplace: leclause (local directory)
- l'Aicluse local slice: `how-plugins-work@laicluse-agent-tools`, 2026-06-09
- Codex CLI command forms verified via local `codex plugin --help`, 2026-06-09
