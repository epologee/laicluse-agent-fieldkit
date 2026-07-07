---
name: second-opinion
description: >-
  Get a Claude second opinion on recent work or a design from Codex.
---

# Second opinion

Intervision is peer consultation: equals looking at each other's work, not a
supervisor looking down. Etymology says it plainly, `inter-` (between, among,
together) against `super-` (from above). This skill brings a second coding
agent in as that peer for an independent read. You hand it the work just done
or just discussed, it looks with fresh eyes and different training, and the two
of you talk it through.

The peer here is Claude, reached through `claude -p`. It runs from the same
repository, on its own login, with its own model behind it. That independence is
the whole point; a peer trained the same way as you would only echo you. Run it
with `DD_HEADLESS=1 --setting-sources "" --tools ""` so local Claude Code stop
hooks and user instructions do not overwrite the peer's actual answer.

## The peer has to be there

Before asking, confirm the peer exists:

```bash
command -v claude >/dev/null 2>&1 || { echo "claude CLI not found; intervision needs a peer to ask. Install and log in to Claude Code first."; }
```

If `claude` is missing, say so plainly and stop. There is no peer to ask, and
pretending otherwise wastes the operator's time. This is the one hard
precondition.

## Three ways to get the second opinion

Pick by what just happened. All three run through `claude -p`, and they
combine: review a diff first, then go back and forth on whatever the review
leaves open.

**1. Check work just done, when there is a diff.** Claude does not have Codex's
dedicated `review` subcommand, so hand it the actual status and diff on stdin.
Do not summarize the work first:

```bash
{
  printf 'Peer review this repository change. Report bugs, risks, regressions, and missing tests first. Do not edit files.\n\n'
  printf '## git status --short\n'
  git status --short
  printf '\n## staged diff\n'
  git diff --cached --no-ext-diff
  printf '\n## unstaged diff\n'
  git diff --no-ext-diff
  printf '\n## untracked files\n'
  git ls-files --others --exclude-standard
} | DD_HEADLESS=1 claude -p --input-format text --setting-sources "" --tools ""
```

For a branch or single commit, replace the diff block with the concrete range:

```bash
DEFAULT=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
if [ -z "$DEFAULT" ]; then
  echo "cannot determine default branch from origin/HEAD; pass an explicit range" >&2
  exit 1
fi
{
  printf 'Peer review this branch diff. Report findings first and do not edit files.\n\n'
  git diff --no-ext-diff "$DEFAULT"...HEAD
} | DD_HEADLESS=1 claude -p --input-format text --setting-sources "" --tools ""

{
  printf 'Peer review this commit. Report findings first and do not edit files.\n\n'
  git show --stat --patch <sha>
} | DD_HEADLESS=1 claude -p --input-format text --setting-sources "" --tools ""
```

**2. Weigh a design just discussed, when there is no code yet.** Give Claude
the actual design context on stdin. Keep the shaky parts in; a flattering
summary buys a flattering review.

```bash
DD_HEADLESS=1 claude -p --input-format text --setting-sources "" --tools "" <<'PROMPT'
Peer review this plan before we build it. Do not edit files.
<paste the design, the trade-off, the open question, including the parts we are unsure about>
PROMPT
```

**3. Go back and forth.** A single answer is consultation; intervision is a
conversation. Continue with a fresh `claude -p` handoff that quotes the peer's
prior finding and your evidence. Do not loop on vibes; push one concrete point
at a time.

```bash
DD_HEADLESS=1 claude -p --input-format text --setting-sources "" --tools "" <<'PROMPT'
You flagged X as a race. The lock at <file:line> already serialises that path.
Does that change your read? Do not edit files.
PROMPT
```

Keep going until each disagreement is either resolved or sharpened into a
question the operator should decide. If two rounds pass with no movement, stop
and surface the disagreement to the operator with both positions rather than
looping.

## How to do it well

The round-trip only earns its cost if the handoff is honest.

- **Give the peer the real work, not a summary you are proud of.** Point it at
  the actual diff, or paste the actual design with the shaky parts left in.
- **Keep the artifact scope intact.** If the operator asks for a language check
  on a sentence, paragraph, PR body, or release note, hand the whole text to the
  peer. Do not narrow a failed peer call to one suspicious word and then report
  the result as a second opinion on the full wording. If the full-scope peer
  call cannot produce a usable answer, say the second opinion is blocked.
- **Read for the disagreement, not the agreement.** The peer agreeing is cheap
  and tells you little. The signal is where its independent read diverges from
  yours.
- **Stay a peer, not a deferrer.** A second agent is not an authority. When the
  peer is wrong, say so and push back. When it is right, concede plainly.
- **Keep the peer reviewing, not editing.** `--tools ""` removes file and shell
  tools from the Claude handoff; the prompt still says "do not edit files"
  because the peer is there to propose, not land changes.
- **Never expand the handoff through the shell.** A pasted design or follow-up
  is arbitrary text and may contain `$(...)`, backticks, or quotes. Feed it on
  stdin through a quoted heredoc (`<<'PROMPT' ... PROMPT`), never as a
  double-quoted argument, so the shell passes it to the peer verbatim instead
  of executing part of it.

## Bringing findings home

The peer's output is a pile of findings, not a to-do list. Each finding gets one
honest fate:

- **Fix it** when it is real and the change earns its weight.
- **Skip it on cost versus value** when the fix would add more than it lifts,
  with a one-line reason.
- **Reject it** when it is hollow, with the evidence that makes it hollow.

Then surface the exchange to the operator: what the peer raised, what you did
with each point, and where the two of you still disagree. Do not smooth the
disagreements away. They are the most useful thing intervision produces, because
they mark the spots neither agent can settle alone.
