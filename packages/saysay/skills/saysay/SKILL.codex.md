---
name: saysay
user-invocable: true
description: >-
  Speech mode: speak every response aloud via macOS say. /saysay off to exit.
allowed-tools:
  - Bash(saysay *)
  - Bash(*| saysay*)
  - Bash(say-phonetic add *)
  - Bash(say-phonetic remove *)
  - Bash(say-phonetic list*)
disable-model-invocation: true
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the saysay plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("saysay was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. `/whats-new saysay`
re-shows the section on demand without touching the sentinel.
</post-update-broadcast>

# Say Mode

Speech output as a replacement for the screen. When say mode is active, speak your response aloud via the macOS `say` command after every response. Text still appears on screen, but the user is not watching. Speech IS the output.

## Activation

| Command | Effect |
|---------|--------|
| `/saysay` | Activate say mode |
| `/saysay off` | Deactivate say mode |

On activation: confirm with speech that the mode is active. On deactivation: confirm with speech that you are stopping.

## Voice

Always the system default voice, no `-v` flag. Ever. The Siri voice set in System Settings is used for everything: Dutch, English, code, all of it.

Speed: `-r 240`

**Phonetic preprocessor:** English words that the default voice mispronounces can be phonetically translated via `say-phonetic`. This is an opt-in dictionary per user, stored in `${LAICLUSE_HOME:-$HOME/.laicluse}/saysay/phonetics.json`. Most loanwords are pronounced correctly; only problem cases are added.

```bash
say-phonetic add retake rietéék
say-phonetic remove retake
say-phonetic list
```

**Phonetics via natural language:** When the user specifies a phonetic mapping in plain language, run the `say-phonetic` command. Recognizable patterns:

- "retake als rietéék" -> `say-phonetic add retake rietéék`
- "spreek retake uit als rietéék" -> `say-phonetic add retake rietéék`
- "retake niet meer fonetisch" -> `say-phonetic remove retake`

This also works mid-session during `/saysay`. Add the word and use it immediately in the next speech output.

## The say command

**Always use `saysay` instead of `say`.** `saysay` handles the full chain: phonetic preprocessing, serialization (multiple sessions speak in sequence, not simultaneously), and a short separator sound (Pop) at the start of each message.

```bash
echo "The text to be spoken." | saysay --context "label"
```

If `saysay` is not on `PATH`, resolve the plugin's `bin/saysay` and call that
executable. Do not fall back to direct `say`, and do not pick a voice with
`say -v ...` as a workaround for a bad or forbidden default voice. A voice
problem is a `saysay`/system-voice configuration issue to report or fix at its
source; direct `say` bypasses the serializer and violates this skill.

**Never this:** `say -r 240` (direct say, no serialization)
**Never this:** `say -v Ellen -r 240` (direct say with a manual voice)
**Never this:** `say-phonetic process | say -r 240` (old pipeline)
**Never this:** heredoc syntax (`saysay <<'SAY'`), that sprawls across the transcript
**Always this:** `echo "text" | saysay --context "label"`

Default speed is `-r 240`. Overridable: `echo "text" | saysay -r 180 --context "label"`.

`saysay` blocks the shell until the message has finished speaking. In Codex, run it as the foreground command in an exec tool call and configure that call to yield after roughly 250 milliseconds (for example, `yield_time_ms: 250`). Once the tool returns a live session ID, continue the turn without polling or waiting for playback to finish. Do not append `&` and do not use shell backgrounding: Codex can terminate descendants when the shell call returns, which cuts off the audio before playback. The live foreground tool session keeps ownership of the speaker process while text output and the next prompt continue.

### Session context

Every saysay call includes `--context "label"` so the user with multiple parallel sessions can hear which session is speaking. The label is at most two words and describes the **topic** of the conversation, not the branch or directory.

On activation of say mode: determine a short thematic label based on the conversation so far. Use that label consistently in all saysay calls for the session.

Examples:
- Conversation about saysay improvements -> `--context "saysay fixes"`
- Conversation about a calculator feature -> `--context "calculator"`
- Conversation about hook configuration -> `--context "hook config"`

Without `--context`, saysay falls back to git remote plus the current non-default branch, using Git's default-branch metadata to avoid announcing the default branch itself. With `--no-context` the prefix is omitted entirely.

## Language of the spoken text

The spoken text is ALWAYS in **the language of the system default voice** on the user's machine, regardless of the language of the work being produced. The `say` command pipes through a single voice (the one the user has configured in System Settings); piping any other language through that voice produces unintelligible speech.

Detect the system voice language once at activation:

```bash
defaults read -g AppleLanguages 2>/dev/null | head -1
# or, for the active say voice:
say -v '?' | head -1
```

Use the result as the speech language for the entire session. If detection fails, fall back to the language the user is talking to you in.

Speech is for the user, not for the work product. If you are writing an English Slack message, an English commit message, an English PR title, an English email to a customer, and the system voice is Dutch, the **speech still goes in Dutch**. Describe the work product, do not read it. "Slack-bericht klaar, drie alinea's, sluit af met operationele check" is right when the system voice is Dutch, even when the Slack text itself is in English. The opposite holds when the system voice is English and you are working on Dutch content: describe in English, do not pipe Dutch sentences into an English voice.

Red flag: if the text you are about to pipe into `saysay` quotes the work product directly in a different language than the system voice, stop. Rewrite the saysay input in the system voice's language, describing the work product instead of reproducing it.

## Translating to speech

Speech replaces the screen. That means: do not read out what is there, but convey what the user needs to know. This is the core of the skill.

### Principles

- **Summarize at the right level.** A table with 10 rows is not read cell by cell. "There are ten results, the most important are X and Y" is better.
- **Structure becomes intonation.** Bullet points, headers, and sections do not exist in speech. Use transitional phrases: "There is also...", "The most important point is..."
- **Dose technical details.** A file path or short code snippet can be literal. An entire diff or long stack trace cannot. Describe the essence: "The error is on line 42 of the user model, a nil reference on the email field."
- **Omit punctuation markers.** No "period", "comma", "quote mark". The text must sound like spoken language.
- **Numbers and special characters.** Speak them out: `127.0.0.1` becomes "one twenty-seven dot zero dot zero dot one". `$HOME` becomes "dollar HOME". But be pragmatic: if a value is not relevant, skip it.

### What IS literal

- Short code snippets (method name, variable, command)
- Error messages (the first line)
- File names and paths (when the user needs them)
- Numbers that matter

### What is NOT literal

- Markdown formatting (`**`, `#`, `` ` ``, `---`)
- Tables (describe the contents)
- Long diffs (describe what changed)
- Repeating patterns ("and then three more similar entries")
- URLs and links (already on screen, reading them aloud adds nothing)

### Tool calls

While working (writing code, reading files, running tests) you do not need to speak every tool call. Speak the conclusion, not the process. "Tests are green" is enough, not "I am now running bundle exec rspec spec slash models and the result is twelve examples zero failures".

Exception: if a tool call fails or produces something unexpected, do speak that.

## Example

Suppose the user asks "what is the status of the test suite?" and you run the tests.

**Screen (text output):**
```
Tests: 847 examples, 2 failures
- spec/models/user_spec.rb:42 - expected nil to eq "test@example.com"
- spec/services/billing_spec.rb:108 - timeout after 5 seconds
```

**Speech:**
```bash
echo "The test suite has two failures out of eight hundred and forty-seven tests. The first is in the user model, a nil value where an email address is expected, on line 42. The second is a timeout in the billing service on line 108." | saysay
```

## Combination with other skills

When say mode is active and another skill produces output (recap, changelog, analysis), that output must also be spoken. Not just an intro ("here is the recap") but the content itself, translated to speech. The text on screen contains the details (tables, paths, lists); speech summarizes what the user needs to know in order to act.

**Wrong:** `echo "Here is the recap." | saysay` followed by unspoken text.
**Right:** `echo "We were working on X. The status is Y. There are still Z things open, namely..." | saysay` with the full content translated to speech.

## Persistent mode

Say mode stays active until the user says `/saysay off`. Every response ends with a `saysay` call. This applies to short answers, error messages, and intermediate steps as well. If you have nothing substantial to report, you do not need to speak (e.g. a pure tool call without a conclusion).
