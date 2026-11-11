#!/bin/bash
# One-time setup (idempotent): python venv for romanization, compile Apple speech/OCR tools, check deps.
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$KSUB_BIN"

echo "== dependencies"
for t in yt-dlp ffmpeg ffprobe whisper-cli uv swiftc codex deno; do
  printf "  %-12s %s\n" "$t" "$(command -v $t || echo 'MISSING')"
done
[ -f "$WHISPER_MODEL" ] || echo "  whisper model MISSING: $WHISPER_MODEL (brew install whisper-cpp; download ggml-large-v3.bin)"

echo "== python venv (3.12: python-mecab-ko has no wheels for newer pythons)"
if [ ! -x "$KSUB_PY" ]; then
  uv venv -q -p 3.12 "$KSUB_HOME/venv"
  VIRTUAL_ENV="$KSUB_HOME/venv" uv pip install -q g2pk2 python-mecab-ko korean-romanizer
fi
"$KSUB_PY" -c 'import sys; sys.path.insert(0, sys.argv[1]); from build_subs import romanize; print("  romanize test:", romanize("듣고 보니 그런 거 같네"))' "$KSUB_SCRIPTS" 2>&1 | grep -v -i mecab

echo "== compile Swift tools (macOS 26+: SpeechAnalyzer; Vision OCR)"
for t in apple_stt ocr_frames; do
  if [ ! -x "$KSUB_BIN/$t" ] || [ "$KSUB_SCRIPTS/$t.swift" -nt "$KSUB_BIN/$t" ]; then
    swiftc -O "$KSUB_SCRIPTS/$t.swift" -o "$KSUB_BIN/$t"
  fi
  echo "  $KSUB_BIN/$t"
done
echo "ok"
