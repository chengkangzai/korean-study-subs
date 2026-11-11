# Sourced by every korean-study-subs script.
# BASH_SOURCE is empty when sourced from zsh; zsh sets $0 to the sourced file
KSUB_SKILL="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
KSUB_SCRIPTS="$KSUB_SKILL/scripts"
KSUB_HOME="${KSUB_HOME:-$HOME/.cache/korean-study-subs}"   # venv + compiled tools
KSUB_BIN="$KSUB_HOME/bin"
KSUB_PY="$KSUB_HOME/venv/bin/python"                      # python 3.12 venv with g2pk2 + mecab
WHISPER_MODELS="${WHISPER_MODELS:-$HOME/.cache/whisper-cpp}"
WHISPER_MODEL="${WHISPER_MODEL:-$WHISPER_MODELS/ggml-large-v3.bin}"
# yt-dlp needs a JS runtime (deno) for many YouTube videos
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export PYTHONWARNINGS=ignore
# extra ssh options for ssh:<host>:<path> sources, e.g. KSUB_SSH_OPTS="-p 2222"
KSUB_SSH_OPTS="${KSUB_SSH_OPTS:-}"
# Chinese line on the study track: hant (Traditional, default — matches hanja, best for Sino-Korean) | hans (Simplified)
export KSUB_ZH="${KSUB_ZH:-hant}"
