#!/bin/bash
# Stop guard. Blocks "you can do this by XYZ"-style instructions when XYZ is
# something Claude itself could have executed via Bash, Edit, browser tools,
# or any other available capability. The reflex this catches: handing the
# operator a recipe instead of running it. Sister to verify.sh; verify covers
# delegated verification, duh covers delegated execution.
#
# Pass condition: actually run the action and report the result, or prefix
# the relevant line with "Instructie:" when the operator explicitly asked
# for a manual recipe (teaching/documentation context).

guard_duh() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 2000 "duh")
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0

  # Explicit instruction-request acknowledged by the assistant.
  grep -qiE "^Instructie:" <<< "$text" && return 0

  # Drop fenced code blocks: example commands inside ``` are documentation,
  # not delegated actions.
  local filtered
  filtered=$(echo "$text" | awk '
    /^```/ { in_fence = !in_fence; next }
    !in_fence
  ')
  # Drop our own meta-references so docs about the guard do not self-trigger.
  filtered=$(echo "$filtered" | sed -E 's/\[dont-do-that\/duh\]//g; s/\b(duh|do-that)\b//gi')

  local offer imperative openit
  # "je kunt / je kan / you can ... door|met|by ... `cmd`"
  # Note: [^.] is enough; grep regex `.` already excludes newline, and `\n`
  # inside a character class is read as the literal letters `\` and `n`,
  # which would silently exclude every word containing `n`.
  offer=$(grep -ciE "(je (kunt|kan)|u kunt|you can) [^.]{0,150}(door|met|by) [^.]{0,150}\`[^\`]+\`" <<< "$filtered")
  # Imperative line: "Run `cmd`" / "Draai `cmd`" / "Voer `cmd` uit" / "Execute `cmd`"
  imperative=$(grep -ciE "(^|\n[[:space:]]*|[.!?][[:space:]]+)(Run|Draai|Voer|Execute|Probeer|Try)[[:space:]][^.!?\n]{0,120}\`[^\`]+\`" <<< "$filtered")
  # Open URL / browser / terminal as a directive
  openit=$(grep -ciE "(open|navigeer|navigate|ga) [^.]{0,80}(in (je|de|your|the) (browser|terminal)|naar (http|localhost)|to (http|localhost))" <<< "$filtered")

  if [ "$offer" -gt 0 ] 2>/dev/null; then
    dd_emit_block duh "Instruction offered instead of executed. Run it yourself or prefix with 'Instructie:'."
  elif [ "$imperative" -gt 0 ] 2>/dev/null; then
    dd_emit_block duh "Imperative recipe without execution. Run the command yourself or prefix with 'Instructie:'."
  elif [ "$openit" -gt 0 ] 2>/dev/null; then
    dd_emit_block duh "Browser/terminal action delegated. Use your tools or prefix with 'Instructie:'."
  fi
  return 0
}
