#!/bin/bash
# Speech-to-text evidence for one episode (Whisper large-v3 + Apple SpeechTranscriber [+ YouTube auto-captions]).
# Usage: asr.sh <workdir> <EP> <source>
#   source = YouTube id/URL  (Korean audio track is pinned; YouTube auto-captions also fetched)
#          | ssh:<host>:<remote video path>  (audio extracted remotely; KSUB_SSH_OPTS / KSUB_REMOTE_FFMPEG_DIR)
#          | local video/audio file
# Output: <workdir>/<EP>.evidence.txt   (intermediates in <workdir>/asr/<EP>/)
set -euo pipefail
source "$(dirname "$0")/env.sh"
W=$1; EP=$2; SRC=$3
D="$W/asr/$EP"; mkdir -p "$D"; cd "$D"

if [ ! -f audio.wav ]; then
  if [[ "$SRC" == ssh:* ]]; then
    # remote video: extract 16 kHz mono Korean audio on the remote host, stream WAV back
    rest=${SRC#ssh:}; host=${rest%%:*}; rpath=${rest#*:}
    B=${KSUB_REMOTE_FFMPEG_DIR:+$KSUB_REMOTE_FFMPEG_DIR/}
    AIDX=$(ssh -n $KSUB_SSH_OPTS "$host" "${B}ffprobe -v error -select_streams a -show_entries stream=index:stream_tags=language -of csv=p=0 \"$rpath\"" \
      | awk -F, '$2 ~ /^(kor|ko)$/ {print $1; exit}')
    ssh -n $KSUB_SSH_OPTS "$host" "${B}ffmpeg -v error -i \"$rpath\" -map 0:${AIDX:-a:0} -ar 16000 -ac 1 -f wav -" >audio.wav
    : >audio.ko.srt
  elif [ -f "$SRC" ]; then
    # local file: first Korean audio stream if tagged, else the first audio stream
    AIDX=$(ffprobe -v error -select_streams a -show_entries stream=index:stream_tags=language -of csv=p=0 "$SRC" \
      | awk -F, '$2 ~ /^(kor|ko)$/ {print $1; exit}')
    ffmpeg -v error -y -i "$SRC" -map "0:${AIDX:-a:0}" -ar 16000 -ac 1 audio.wav
    : >audio.ko.srt
  else
    # Some videos carry YouTube AI auto-dub tracks (English) — pin the Korean one
    yt-dlp -q --no-warnings -f "bestaudio[language^=ko]/bestaudio" -x --audio-format wav \
      --postprocessor-args "ffmpeg:-ar 16000 -ac 1" -o "audio.%(ext)s" \
      --write-auto-subs --sub-langs ko --sub-format srt --convert-subs srt -- "$SRC"
  fi
fi
[ -f audio.ko.srt ] || : >audio.ko.srt

# NO VAD on purpose: VAD silently drops dialogue under background music. Hallucinations are filtered by the LLM step.
[ -f whisper.json ] || whisper-cli -m "$WHISPER_MODEL" -l ko -ojf -of whisper -mc 0 -sns -dtw large.v3 audio.wav >/dev/null 2>whisper.log
[ -f apple.json ] || "$KSUB_BIN/apple_stt" audio.wav apple.json ko_KR >/dev/null

python3 -I "$KSUB_SCRIPTS/prep_evidence.py" whisper.json apple.json audio.ko.srt "$W/$EP.evidence.txt"
