#!/bin/bash
# Stop guard. Blocks verification delegation to the user.
# Pass by prefixing the conclusion with "Geverifieerd:" (verified) after actually verifying.

guard_verify() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 2000 "verification-delegation")
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0

  grep -qiE "^Geverifieerd:" <<< "$text" && return 0

  local filtered
  filtered=$(echo "$text" \
    | sed -E 's/verification[_-]delegation[_-]guard//gi' \
    | sed -E 's/`[^`]*`//g' \
    | sed -E 's/"[^"]*"//g' \
    | sed -E 's/\|[^|]*\|//g')

  local claim check action
  claim=$(grep -ciE "(zou (nu )?moeten (werken|slagen|kloppen|lukken)|dit zou moeten|should (now )?(work|be fixed|be working|be resolved)|is nu (gefixt|opgelost|hersteld)|is now (fixed|working|resolved))" <<< "$filtered")
  check=$(grep -ciE "(check of|controleer of|kun je (checken|kijken|testen|verifi)|kan je (checken|kijken|testen|verifi)|kijk of|kijk even|let me know if|can you (check|verify|confirm|test)|werkt het( nu)?\?|klopt (dat|dit)\?|wil je (het )?(testen|checken)|test (maar|'m|ff|even|eens|hem)|test het( weer)?|kijk (ff|'ns|maar)|probeer (maar|'ns|hem))" <<< "$filtered")
  action=$(grep -ciE "(refresh de (pagina|browser)|herlaad de (pagina|browser)|probeer (het |de pagina |opnieuw)?(te |eens)?|restart de (server|app)|herstart de (server|app)|try (refreshing|reloading|again|it)|reload the (page|browser))" <<< "$filtered")

  if [ "$claim" -gt 0 ] 2>/dev/null; then
    dd_emit_block verify "Unverified claim. Verify yourself and start with 'Geverifieerd:'."
  elif [ "$check" -gt 0 ] 2>/dev/null; then
    dd_emit_block verify "Verification delegated. Do it yourself and start with 'Geverifieerd:'."
  elif [ "$action" -gt 0 ] 2>/dev/null; then
    dd_emit_block verify "Action delegated. Do it yourself and start with 'Geverifieerd:'."
  fi
  return 0
}
