#!/bin/bash
# Run the LLM step for one episode with Codex CLI (runs on the ChatGPT plan, not Claude tokens).
# Usage: llm_episode.sh <asr|notes> <workdir> <EP> "<episode context: title / plot hint>"
#   asr   : needs <EP>.evidence.txt (+ optional <EP>.ocrspans.txt, <EP>.official.{zh,en}.srt) and <workdir>/SHOW.md
#           -> <workdir>/<EP>.json            (cue list: ko/zh/en/note/uncertain/sign)
#   notes : needs <EP>.lines.txt (from drama_prepare.py) and <workdir>/SHOW.md
#           -> <workdir>/<EP>.notes.json      ({id: note})
# Skips if the output already exists. Env: KSUB_LLM_MODEL to override the codex model.
set -uo pipefail
source "$(dirname "$0")/env.sh"
MODE=$1; W=$2; EP=$3; CTX=${4:-}
case $MODE in
  asr)   BRIEF=ASR_BRIEF.md;   OUT=$EP.json;       INPUTS="$EP.evidence.txt $EP.ocrspans.txt $EP.official.zh.srt $EP.official.en.srt" ;;
  notes) BRIEF=NOTES_BRIEF.md; OUT=$EP.notes.json; INPUTS="$EP.lines.txt" ;;
  *) echo "mode must be asr|notes" >&2; exit 2 ;;
esac
[ -s "$W/$OUT" ] && { echo "skip $EP"; exit 0; }
D="$W/llm/$EP"; rm -rf "$D"; mkdir -p "$D"
cp "$KSUB_SKILL/briefs/$BRIEF" "$D/"
[ -f "$W/SHOW.md" ] && cp "$W/SHOW.md" "$D/" || echo "(no SHOW.md)" >"$D/SHOW.md"
for f in $INPUTS; do [ -f "$W/$f" ] && cp "$W/$f" "$D/"; done
[ "$MODE" = asr ] && [ ! -f "$D/$EP.ocrspans.txt" ] && : >"$D/$EP.ocrspans.txt"
MODEL_ARGS=(); [ -n "${KSUB_LLM_MODEL:-}" ] && MODEL_ARGS=(-m "$KSUB_LLM_MODEL")
codex exec --skip-git-repo-check -s workspace-write -C "$D" ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} \
  "Read $BRIEF and SHOW.md in this directory and follow the brief exactly. Episode $EP — $CTX. Inputs in this directory: $INPUTS (some may be absent). Write $OUT in this directory, validate it, then print the brief report. Reply in English." \
  >"$D/codex.log" 2>&1
if python3 -I -c 'import json,sys;json.load(open(sys.argv[1]))' "$D/$OUT" 2>/dev/null; then
  cp "$D/$OUT" "$W/$OUT"
  echo "OK $EP tokens=$(grep -A1 '^tokens used' "$D/codex.log" | tail -1)"
else
  echo "FAIL $EP (see $D/codex.log)"
fi
