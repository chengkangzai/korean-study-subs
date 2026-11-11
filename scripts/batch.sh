#!/bin/bash
# Run one pipeline stage over every episode in a jobs file.
# Usage: batch.sh <stage> <workdir> [parallel=1]
#
# <workdir>/jobs.tsv — one episode per line, TAB-separated, '#' comments allowed:
#   EP <TAB> source <TAB> video <TAB> outbase <TAB> context
#     EP      : short code, e.g. S01E05 / HPS01E01
#     source  : audio source for ASR — YouTube id/URL or local file ('-' if not needed)
#     video   : video for OCR / subtitle extraction — local path or ssh:<host>:<path> ('-' if none)
#     outbase : final output path without extension (= video file name sans extension, next to the video)
#     context : episode title / plot hint for the LLM
#
# Stages:
#   asr          Whisper + Apple + YouTube captions -> EP.evidence.txt     (local GPU: keep parallel=1)
#   ocr          on-screen text -> EP.ocrspans.txt
#   extract      official ko/zh/en tracks -> EP.official.*.srt
#   prepare      official subs -> EP.cues.json + EP.lines.txt                (drama with official Korean)
#   llm-asr      Codex: fix Korean, translate, notes, signs -> EP.json        (parallel 3 is fine)
#   llm-notes    Codex: notes only -> EP.notes.json
#   build-asr    -> outbase.{ko,zh,en}.srt + outbase.study.ko.ass
#   build-drama  -> outbase.study.ko.ass
set -uo pipefail
source "$(dirname "$0")/env.sh"
STAGE=$1; W=$(cd "$2" && pwd); P=${3:-1}
JOBS="$W/jobs.tsv"
[ -f "$JOBS" ] || { echo "missing $JOBS" >&2; exit 2; }
LOG="$W/batch_$STAGE.log"

one() { # EP source video outbase context
  local EP=$1 SRC=$2 VID=$3 OUT=$4 CTX=$5
  case $STAGE in
    asr)         "$KSUB_SCRIPTS/asr.sh" "$W" "$EP" "$SRC" ;;
    ocr)         [ "$VID" = - ] || "$KSUB_SCRIPTS/ocr.sh" "$W" "$EP" "$VID" ;;
    extract)     [ "$VID" = - ] || "$KSUB_SCRIPTS/extract_subs.sh" "$VID" "$W" "$EP" ;;
    prepare)     python3 -I "$KSUB_SCRIPTS/drama_prepare.py" "$W" "$EP" ;;
    llm-asr)     "$KSUB_SCRIPTS/llm_episode.sh" asr "$W" "$EP" "$CTX" ;;
    llm-notes)   "$KSUB_SCRIPTS/llm_episode.sh" notes "$W" "$EP" "$CTX" ;;
    build-asr)   "$KSUB_SCRIPTS/build.sh" asr "$W" "$EP" "$OUT" ;;
    build-drama) "$KSUB_SCRIPTS/build.sh" drama "$W" "$EP" "$OUT" ;;
    *) echo "unknown stage $STAGE" >&2; return 2 ;;
  esac
}
export -f one; export STAGE W KSUB_SCRIPTS

grep -v '^\s*#' "$JOBS" | grep -v '^\s*$' | while IFS=$'\t' read -r EP SRC VID OUT CTX; do
  printf '%s\0%s\0%s\0%s\0%s\0' "$EP" "$SRC" "$VID" "$OUT" "${CTX:-}"
done | xargs -0 -n 5 -P "$P" bash -c 'one "$0" "$@" </dev/null || echo "FAIL $0"' 2>&1 | tee "$LOG"
echo "== $STAGE done: $(grep -c '^FAIL' "$LOG") failures (log: $LOG)"
