#!/bin/bash
# On-screen text (signs, screens; Korean + confident English) for one episode via Apple Vision at 1 frame/s.
# Usage: ocr.sh <workdir> <EP> <video>
#   video = local path (a mounted NAS path works)  |  ssh:<host>:<remote path>  (frames extracted remotely, streamed as tar)
# Output: <workdir>/<EP>.ocrspans.txt
set -euo pipefail
source "$(dirname "$0")/env.sh"
W=$1; EP=$2; V=$3
[ -s "$W/$EP.ocrspans.txt" ] && exit 0
F="$W/frames/$EP"; rm -rf "$F"; mkdir -p "$F" "$W/asr/$EP"
if [[ "$V" == ssh:* ]]; then
  rest=${V#ssh:}; host=${rest%%:*}; rpath=${rest#*:}
  # -n: never let ssh eat the caller's stdin (breaks `while read` loops)
  ssh -n $KSUB_SSH_OPTS "$host" "T=\$(mktemp -d); ffmpeg -v error -i '$rpath' -vf fps=1,scale=1280:-1 -q:v 3 \$T/%05d.jpg && tar -C \$T -cf - .; rm -rf \$T" | tar -C "$F" -xf -
else
  ffmpeg -v error -i "$V" -vf "fps=1,scale=1280:-1" -q:v 3 "$F/%05d.jpg"
fi
"$KSUB_BIN/ocr_frames" "$F" "$W/asr/$EP/ocr.json" >/dev/null
python3 -I "$KSUB_SCRIPTS/ocr_spans.py" "$W/asr/$EP/ocr.json" "$W/$EP.ocrspans.txt"
rm -rf "$F"
