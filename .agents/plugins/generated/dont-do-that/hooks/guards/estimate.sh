#!/bin/bash

guard_estimate() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 1200 "estimate")
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0

  grep -qE "^🧭" <<< "$text" && return 0

  local skip_pat
  skip_pat='geleden|(^| )ago( |$|[.,;:!?])|sinds |afgelopen |history|(^| )live( |$|[.,;:!?])|uptime|deadline|expir|cooldown|retention|ttl|backoff|recurring|(^| )schedule( |$|[.,;:!?])|(^| )cron( |$|[.,;:!?])|(^| )every (day|hour|week|month)|(^| )elke (dag|uur|week|maand)|loon|opzegtermijn|(^| )sla( |$|[.,;:!?])|jaarrekening|in productie|gisteren|tomorrow|morgen|over (een |een paar |paar |[0-9]+ ?)?(uur|dag|week|maand)|duration:|bracket|(^| )wait( |$|[.,;:!?])|(^| )loopt( |$|[.,;:!?])|running |(^| )since( |$|[.,;:!?])|the last|afgelopen [0-9]'

  local hit_pat
  hit_pat='(een |een paar |paar |1 |één |2 |twee |3 |drie |vier |vijf )?(uur|uren|dag|dagen|week|weken|maand|maanden)( eerlijk)? (werk|denkwerk|bouwwerk|uitzoekwerk|implementatie)( |$|[.,;:!?])|halve (dag|week|maand|middag|avond)( |$|[.,;:!?])|(^| )(dagje|weekje|weekendje|maandje)( |$|[.,;:!?])|(kost|duurt|takes?|would take|will take|gaat (je |me |ons )?(kosten|duren)) (een |een paar |paar |a |a few |the better part of )?(uur|uren|dag|dagen|week|weken|maand|maanden|hours?|days?|weeks?|months?)( |$|[.,;:!?])|(a |a few |a couple of |few |couple of )(hours?|days?|weeks?|months?) of (work|effort|coding|hacking|implementation|debugging|setup)( |$|[.,;:!?])|binnen (een |de )?(uur|dag|week|maand)( |$|[.,;:!?])|(this|deze) (is|wordt) (a |an |een )?(day|week|month|dag|week|maand)( of)? (work|werk)( |$|[.,;:!?])|(option|optie) [a-z] (is|wordt) (vandaag|deze week|today|this week)( |$|[.,;:!?])|vandaag.{0,20}(deze week|paar dagen|paar weken)|(deze week|paar dagen|paar weken).{0,20}vandaag'

  local violation
  violation=$(awk -v hit="$hit_pat" -v skip="$skip_pat" '
    /^```/ { in_code = !in_code; next }
    in_code { next }
    {
      if (match(tolower($0), hit) && !match(tolower($0), skip)) {
        print NR": "$0
        exit
      }
    }
  ' <<< "$text")

  [ -z "$violation" ] && return 0

  dd_emit_block estimate "Time-estimate phrasing in assistant text: ${violation}. Drop the hours/days/weeks framing or replace it with a concrete count (files touched, edits, verifications). LLM-trained duration claims are routinely 10x-100x off for work a session actually does."
}
