#!/bin/bash
# Stop guard, back-stop only. Catches two failure modes that end on '?':
# (a) reflex-terugkaatsing where Claude asks the user something it could
# just decide and continue, and (b) truncated generation that happened to
# stop mid-sentence on a question mark. Not a whip. Steady pacing is the
# point: when the question is reflex, answer it yourself and carry on at
# normal pace; when it is a genuine user-choice, mark with 🧭 prefix so
# the back-stop stands aside; when the work is actually done, end with
# 🏁 + sentence.

guard_compliance() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 500 "compliance-reflex")
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0

  grep -qE "^🧭" <<< "$text" && return 0
  grep -qE "🏁" <<< "$text" && return 0

  if tail -c 400 <<< "$text" \
       | grep -qiE "als (een )?side[ -]?quest|als (een )?follow[ -]?up|in een (aparte|volgende|latere|nieuwe) pr|aparte pr|separate pr|later oppakken|voor later|pak ik later|de rest (komt|volgt|later)|rest als (een )?(side|follow)"; then
    dd_emit_block compliance "Declarative deferral of in-scope work. Parking the rest as a side quest / follow-up / separate PR is the compliance reflex dressed as a decision: the operator asked for the best solution, not the cheapest slice. Do the whole thing now, or mark it deliberately: 🧭 (genuine two-outcome choice the operator must make) / 🏁 (done). A scope rule is not cover for doing less than was asked."
    return 0
  fi

  grep -qiE "(wil je dat ik|zal ik|moet ik|shall i|should i|want me to|do you want me to|wilt u dat ik|wat heeft? je voorkeur|what do you prefer|nog (updaten|aanpassen|fixen|doen|starten|draaien)).*\?\s*$" <<< "$text" \
    || return 0

  # Genuine-question hatch: words that signal a real disambiguation question.
  tail -c 200 <<< "$text" \
    | grep -qiE "(bedoel je|do you mean|of (wil je|wilt u)|or (do you|would you)|is dit beter|is this better|welke (van|optie)|which (of|option)|[0-9]+ (issues|bestanden|items|punten|commits|stappen))" \
    && return 0

  dd_emit_block compliance "'?' ending: double-check, not a whip. Reflex-ask or truncated output? Answer it yourself at your own pace, or mark deliberately: 🧭 (genuine user-choice, NOT a scope-check on a question the operator's own framework already answers; 'should I also add X?' on a trivial-yes change is reflex; 'shall I commit?' is reflex when a commit-discipline is already running, the discipline IS the framework and push is the separate gate; 'should I push?' stays a genuine question), 🏁 (done)."
}
