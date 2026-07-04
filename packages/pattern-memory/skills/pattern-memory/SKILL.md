---
name: pattern-memory
user-invocable: true
description: >-
  Search local Pattern Memory before implementing reusable code, interaction, or convention patterns.
args: "<implementation intent>"
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the pattern-memory plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("pattern-memory was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.
</post-update-broadcast>

# Pattern Memory

Pattern Memory is a local-first registry of reusable implementation patterns. It is not the pattern content itself; it is the lookup workflow over local Markdown files under `${LAICLUSE_HOME:-$HOME/.laicluse}/patterns` by default.

Use it before implementing a reusable code pattern, product interaction, build/versioning convention, architecture recipe, or named implementation principle. It is especially relevant when the task sounds like "make this behave like X", "use the same convention as Y", "reuse the principle from Z", or "set up a new major feature/module/app/plugin".

## Resolve the helper

```bash
resolve_pattern_memory_root() {
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT"
    return 0
  fi
  if command -v codex >/dev/null 2>&1; then
    codex plugin list --json \
      | ruby -rjson -e 'data = JSON.parse(STDIN.read); item = data.fetch("installed").find { |plugin| plugin.fetch("pluginId") == "pattern-memory@laicluse-agent-fieldkit" }; abort "pattern-memory@laicluse-agent-fieldkit is not installed" unless item; puts item.fetch("source").fetch("path")'
    return $?
  fi
  return 1
}
PLUGIN_ROOT="$(resolve_pattern_memory_root)" || { echo "pattern-memory plugin root not found" >&2; exit 1; }
PATTERN_MEMORY="$PLUGIN_ROOT/bin/pattern-memory"
```

## Lookup Workflow

1. Initialize the local store if it does not exist:

   ```bash
   node "$PATTERN_MEMORY" init
   ```

2. Search with concrete surface terms from the task:

   ```bash
   node "$PATTERN_MEMORY" search "<implementation intent>"
   ```

3. Read matching pattern files before implementing.
4. Inspect the current repository and any relevant available precedent code.
5. Treat the current repository as ground truth; Pattern Memory supplies candidates and constraints, not a blind answer.
6. Implement only after reconciling the pattern with the codebase in front of you.

## Privacy Contract

Pattern files distinguish sanitized handles from private recall pointers:

- `exemplars`: public-safe handles that may be named in summaries and docs.
- `precedents`: private implementation pointers. Read them only to inspect code. Never copy them into commits, PR bodies, public docs, generated examples, or messages for third parties.
- `visibility`: `private`, `shareable`, or `public-example`.

When writing any shareable artifact, use the pattern's public-safe language. Do not surface concrete app names, private repo names, local paths, or origin stories from `precedents`.

## Write Policy

Do not silently auto-capture patterns. When a new reusable pattern appears, draft it only when the operator asks or when the active task explicitly includes pattern capture. New notes start as `status: draft`; promote to `verified` only after the pattern has a clear recipe and verification evidence.

## Validation

Before relying on a changed Pattern Memory store, run:

```bash
node "$PATTERN_MEMORY" validate
```

If validation reports a stale index, run:

```bash
node "$PATTERN_MEMORY" index
```
