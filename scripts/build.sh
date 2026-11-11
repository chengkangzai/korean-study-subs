#!/bin/bash
# Build final subtitle files for one episode.
# Usage: build.sh <asr|drama> <workdir> <EP> "<output base path without extension>"
#   asr   : <EP>.json -> <base>.ko.srt / .zh.srt / .en.srt / .study.ko.ass
#   drama : official subs -> <EP>.cues.json (if missing) + <EP>.notes.json -> <base>.study.ko.ass only
#           (official ko/zh/en stay embedded in the video)
# Jellyfin/VLC pick sidecars up when <base> equals the video file name without extension.
set -euo pipefail
source "$(dirname "$0")/env.sh"
MODE=$1; W=$2; EP=$3; BASE=$4
case $MODE in
  asr)   "$KSUB_PY" -I "$KSUB_SCRIPTS/build_subs.py" "$W/$EP.json" "$BASE" 2>&1 | grep -vi mecab ;;
  drama) [ -f "$W/$EP.cues.json" ] || python3 -I "$KSUB_SCRIPTS/drama_prepare.py" "$W" "$EP"
         "$KSUB_PY" -I "$KSUB_SCRIPTS/drama_build.py" "$W/$EP.cues.json" "$W/$EP.notes.json" "$BASE" 2>&1 | grep -vi mecab ;;
  *) echo "mode must be asr|drama" >&2; exit 2 ;;
esac
