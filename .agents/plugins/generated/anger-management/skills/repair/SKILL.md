---
name: repair
description: Invoked as /anger-management:repair. Reads the accumulated cuss-capture log, judges whether there is one concrete recurring thing worth fixing, and if so fixes it at the owning source, or routes it there when a gate blocks the edit. Runs only when the operator types it.
---

# Repair

Repair is where a captured problem gets fixed at its source. It takes over the
fixing steps self-improvement used to run, and it fires in two modes that differ
only in WHEN it runs and WHAT it reads. The fixing steps below are identical in
both.

This is the single place anger-management diagnoses a problem and fixes it.
Nothing else judges: the cuss commands only capture into the pile,
`/anger-management` only tallies it, and `findings.md` is this engine's own
pile-analysis cached ahead of time, never a second analyser. One analyser, fed
two ways.

## Two modes

- **Pile (cooled-down, async).** Invoked as `/anger-management:repair` or by the
  background diagnosis. It reads the whole accumulated friction log: cluster,
  weigh recurrence, gate on confidence, close the watermark. The log, verdict,
  and recording sections are pile-only.
- **Now (single instance).** Invoked from a safeword (`/safeword`, `/flugelhorn`,
  and the other safewords) with the problem the operator just caught. It works
  from that single instance: no cluster, no confidence gate, no `friction.jsonl`,
  no `anger-resolve`, no watermark. Skip straight to the fixing steps for that one
  problem.

Both modes run the same fixing steps. A bare acknowledgement is never the outcome
in either mode: end in a real source-level change, or, in now mode, the corrected
behavior shown with evidence it was a true one-off.

## The log (pile mode; global, it accumulates)

One pile for every session and every repo:
`${LAICLUSE_HOME:-~/.laicluse}/anger-management/friction.jsonl` (each line: ts, word, cwd,
git, note). Repair history: `repairs.jsonl` (past fixes, each with a `covered_through`
watermark). A background diagnosis the cooled-down agent may have written:
`findings.md`.

**Open captures** = entries with `ts` newer than the newest `covered_through` in
`repairs.jsonl` (if there is no history, all are open). Always work the WHOLE open
pile, not one entry. Also inspect the historical captures and repairs as context:
old entries are recurrence evidence, and later entries after a repair can show
that the earlier mitigation missed or overcorrected. This is why deferring helps:
every extra capture across every session sharpens the picture.

## Pile mode: read the log and judge

1. **Use the background diagnosis only if it is fresh and complete.** If `findings.md`
   exists, read its first line (`as-of: <ts>`). If no capture in the pile is newer
   than that as-of, and the diagnosis contains `CONFIDENCE:`,
   `MITIGATION-LEVEL:`, and `TARGET-SCOPE:`, it is current: use it. If captures
   are newer, there is no as-of line, or the confidence/mitigation/scope fields
   are missing, treat it as stale and investigate yourself now: read the entire
   capture history, `repairs.jsonl`, and the agent's recent session transcripts
   (Claude Code: `~/.claude/projects/`; Codex: `~/.codex/sessions/`) for what
   actually happened around those timestamps. You have the time; look properly.

2. **Cluster the open pile, then compare it to history.** Same project (cwd/git)
   or same theme across projects. The recurring thing is the signal; a lone
   one-off is noise. Historical captures can raise or lower confidence, but they
   do not close the open pile by themselves.

3. **Open with a go/no-go verdict plus confidence. This is the whole point: no
   busywork.** Confidence threshold: `0.80`. State one of three, before anything
   else, and include `CONFIDENCE: 0.xx`, `MITIGATION-LEVEL: ...`, and
   `TARGET-SCOPE: ...`:
   - **nothing**: no actionable pattern. Change NOTHING, say why in a line, done.
     This is a good, honest outcome, not a failure. Do not touch instruction
     files or any config on a vague hunch. Do not advance the watermark.
   - **not-enough-signal**: a hint, but too thin to act on. Leave the captures open to
     accumulate; say what you would want to see more of. (Do not advance the
     watermark; do not call anger-resolve.)
   - **fix**: one concrete recurring thing, named, with a specific change. Only use
     this when `CONFIDENCE` is at least `0.80` and the mitigation level is specific.

   Use these mitigation levels:
   - `hook`: hook, schema, linter, permission rule, test, or deterministic script.
   - `skill-plugin`: skill text, plugin helper, plugin metadata, or generated adapter.
   - `project-code`: a code structure that invites the repeat failure.
   - `instruction-file`: only when no stronger target fits.
   - `none`: no credible mitigation yet.

   Scope ladder:
   - `cross-agent-cross-project`: covers repos or agent clients.
   - `cross-project-stack`: covers one framework or stack.
   - `repo`: covers the current repository.
   - `subproject`: covers only below one package, app, service, or plugin.
   - `none`: no credible target scope yet.

   If confidence is below `0.80`, leave the captures open. The breadcrumb is
   useful evidence for a future pass; closing it would erase the trail before the
   pattern is understood.

4. **If the verdict is fix: scrutinise prior self-improvements first.** The operator mostly cusses
   when something RECURS despite earlier fixes. So before proposing a new rule, check
   `repairs.jsonl`: did a past repair already target this? If captures kept coming, the
   past fix probably overcorrected or missed. Prefer **reverting or loosening** that
   rule over piling another on. The right change is often subtraction.

## Fixing steps (both modes)

Now mode enters here with the single problem as the target; pile mode arrives
here only after a `fix` verdict.

1. **Choose the owner source before editing.** The diagnosis, confidence call,
   mitigation-level choice, and target-scope choice belong to anger-management:
   do not hand the decision to self-improvement and do not delegate the diagnosis
   or target-layer choice. Use the target scope to choose the broadest correct
   source:
   - cross-agent / cross-project: shared marketplace plugin, shared hook, shared
     skill, or user-level instruction source when no stronger target fits.
   - cross-project but stack-specific: framework-scoped skill, hook, or guidance.
   - one repo: repo-level code, repo-level skills/docs, hooks, or instructions.
   - one subproject: code, docs, or local instructions under that package/app.

   Source ownership rules:
   - In a marketplace repo, plugin behavior belongs in `packages/<plugin>/`, not
     user-level instructions.
   - Hook behavior belongs in the hook script, helper library, hook manifest, or
     hook reason text.
   - Skill behavior belongs in the existing skill source; sharpen an existing
     skill before creating another path.
   - Plugin metadata belongs in `.claude-plugin/plugin.json` or marketplace
     source, followed by adapter generation.
   - Do not patch runtime caches. Find the canonical source and rebuild
     generated adapters or instruction targets when the repo provides a command.
   - After changing adapter-backed sources, rebuild generated adapters before
     calling the repair done.

   Skill, hook, and plugin authoring:
   - For a skill, sharpen an existing skill with a clearer trigger,
     anti-pattern, checkpoint, or short example only when it changes future
     behavior.
   - For a hook, prefer deterministic checks and precise hook reason text.
   - For plugin metadata, keep descriptions aligned with the runtime behavior.
   - Prune in the same pass: delete, shorten, merge, or loosen rules that caused
     the repeat instead of only appending new instructions.

2. **Fix it yourself when the source is clear.** Make the smallest durable source
   change, prune duplicates in the same pass, rebuild generated outputs, and run
   focused tests or checks. If the fix crosses an explicit approval gate,
   stop at the gate with the concrete patch plan. If the source cannot be found,
   say exactly what you checked; in pile mode leave the captures open and do not
   call `anger-resolve`.

## Recording (pile mode only)

Now mode touched no log, so it records nothing and skips this section.

**Record only real fixes.** When you fixed it, or routed the fix to its source,
record it so its captures close. Resolve the
   loaded plugin root first; Claude Code exposes `${CLAUDE_PLUGIN_ROOT}`, and
   Codex exposes the install path through `codex plugin list`:

   ```bash
   resolve_anger_plugin_root() {
     if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
       printf '%s\n' "$CLAUDE_PLUGIN_ROOT"
       return 0
     fi
     if command -v codex >/dev/null 2>&1; then
       codex plugin list | awk '$1 == "anger-management@laicluse-agent-fieldkit" { print $NF; found=1; exit } END { exit found ? 0 : 1 }'
       return $?
     fi
     return 1
   }

   PLUGIN_ROOT="$(resolve_anger_plugin_root)" || { echo "anger-management plugin root not found" >&2; exit 1; }
   node "$PLUGIN_ROOT/bin/anger-resolve" --through "<as-of you worked from>" "<the change you routed>"
   ```

   Pass `--through` = the as-of of the diagnosis you acted on (the `findings.md`
   as-of, or the newest capture you actually reviewed), so captures that arrived
   DURING this repair are not silently closed. Only on a real fix at or above the
   confidence threshold; never for nothing, not-enough-signal, or unknown source.
   The watermark closes by time, so if several distinct clusters are open and you
   fix one, the others are marked covered too and will reopen on their next
   recurrence.

## Output

Keep it short, in the operator's language. The verdict (and, when fixing, the
routed change) is the whole output. In now mode, the routed change or the
evidenced one-off correction is the whole output.

## Arguments

- No argument: pile mode over the whole open pile.
- `<text>`: pile mode filtered to a word, project, or theme.
- A single problem passed in by a safeword: now mode on that one instance.
