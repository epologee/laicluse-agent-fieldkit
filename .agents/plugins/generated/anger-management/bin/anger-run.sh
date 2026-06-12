# allow-comment: no shebang on purpose (bin/ shebang policy); env-driven background worker, invoked as `bash anger-run.sh` by anger-schedule
sleep "${ANGER_DELAY:-1342}"
asof=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat "$ANGER_PROMPT" | $ANGER_RUNNER > "$ANGER_TMP" 2> "$ANGER_ERR"
if [ -s "$ANGER_TMP" ]; then
  { printf 'as-of: %s\n\n' "$asof"; cat "$ANGER_TMP"; } > "$ANGER_FINDINGS"
else
  printf 'as-of: %s\n\nVERDICT: nothing (investigation failed; see investigate.err)\n' "$asof" > "$ANGER_FINDINGS"
fi
rm -f "$ANGER_TMP" "$ANGER_PENDING"
