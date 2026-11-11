#!/bin/bash
# Extract official Korean / Simplified Chinese / English subtitle tracks from an MKV/MP4 as SRT.
# Usage: extract_subs.sh <video> <workdir> <EP>
#   video = local path  |  ssh:<host>:<remote path>   (set KSUB_REMOTE_FFMPEG_DIR for a non-PATH ffmpeg,
#                                                       e.g. /var/packages/ffmpeg/target/bin on Synology)
# Output: <workdir>/<EP>.official.{ko,zh,en}.srt  (only those that exist). Prints which stream went where.
# Track choice: ko = plain Korean (not Forced/SDH/DUB, falls back to SDH); zh = 简/Simplified; en = not DUB/SDH.
set -euo pipefail
source "$(dirname "$0")/env.sh"
V=$1; W=$2; EP=$3
mkdir -p "$W"
if [[ "$V" == ssh:* ]]; then
  rest=${V#ssh:}; host=${rest%%:*}; rpath=${rest#*:}
  B=${KSUB_REMOTE_FFMPEG_DIR:+$KSUB_REMOTE_FFMPEG_DIR/}
  run_probe() { ssh -n $KSUB_SSH_OPTS "$host" "${B}ffprobe -v error -select_streams s -show_entries stream=index:stream_tags=language,title -of csv=p=0 \"$rpath\""; }
  run_extract() { ssh -n $KSUB_SSH_OPTS "$host" "${B}ffmpeg -v error -i \"$rpath\" -map 0:$1 -f srt -"; }
else
  run_probe() { ffprobe -v error -select_streams s -show_entries stream=index:stream_tags=language,title -of csv=p=0 "$V"; }
  run_extract() { ffmpeg -v error -i "$V" -map "0:$1" -f srt -; }
fi
MAP=$(run_probe)
pick() { echo "$MAP" | awk -F, -v L="$1" -v I="$2" -v X="$3" '$2 ~ L && $3 ~ I && ($3 == "" || X == "" || $3 !~ X) {print $1; exit}'; }
KO=$(pick '^(kor|ko)$' '' 'Forced|SDH|DUB'); [ -z "$KO" ] && KO=$(pick '^(kor|ko)$' '' 'Forced')
ZH=$(pick '^(chi|zho|zh)$' '简|Simplified|Hans' 'Forced'); [ -z "$ZH" ] && ZH=$(pick '^(chi|zho|zh)$' '' 'Forced|Traditional|繁|Hant')
EN=$(pick '^(eng|en)$' '' 'DUB|SDH|Forced'); [ -z "$EN" ] && EN=$(pick '^(eng|en)$' '' 'Forced')
echo "$EP subtitle streams: ko=${KO:--} zh=${ZH:--} en=${EN:--}"
for pair in "ko:$KO" "zh:$ZH" "en:$EN"; do
  lang=${pair%%:*}; idx=${pair#*:}
  [ -n "$idx" ] && run_extract "$idx" >"$W/$EP.official.$lang.srt"
done
