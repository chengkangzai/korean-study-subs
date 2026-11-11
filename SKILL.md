---
name: korean-study-subs
description: Make Korean-learning "study subtitles" for a show or video — Korean + pronunciation romanization above each line + Chinese below + learning notes (Sino-Korean hanja links, English loanwords, grammar, slang) + on-screen signs — as Jellyfin/VLC sidecar files. Use when the user wants to learn Korean from a drama/cartoon/YouTube playlist, asks for Korean subs, romanization, "study subs", "legend"/notes, or to add another show to the pipeline (e.g. "do study subs for <show>", "add season 2", "make Korean subs for this playlist").
---

# Korean study subtitles

**If `LOCAL.md` exists next to this file, read it first** — it holds the user's hosts, paths, preferences and what's already done.

Default viewer profile (edit the briefs to change it): native Mandarin + English speaker, **beginner** Korean, can't read Hangul yet. Output per episode, next to the video:
- `<video>.study.ko.ass` — the study track: pronunciation romanization (g2pk2) interleaved **above each Korean line**, Korean, Chinese below (Traditional by default — `KSUB_ZH=hant|hans`; Traditional matches hanja); yellow notes top-left (≥5 s, stacked); on-screen signs top-centre (English signs shown as `CAUTION → 주의`).
- For ASR shows also `.ko.srt / .zh.srt / .en.srt` (dramas keep their embedded official tracks).

Read `references/gotchas.md` before changing anything — every rule there cost a debugging round.

## Pick the path
| Source has… | Path | LLM does |
|---|---|---|
| Official Korean subs embedded (e.g. streaming WEB-DL) | **drama**: extract → prepare → llm-notes → build-drama | notes only (cheap, ~60k tokens / 90-min ep) |
| No Korean subs (dubbed cartoon, YouTube, older drama) | **asr**: asr → ocr → (extract zh/en if any) → llm-asr → build-asr | fix Korean from 3 transcripts, zh/en (or reuse official), notes, signs |

Check first: `ffprobe -v error -select_streams s -show_entries stream=index:stream_tags=language,title -of csv=p=0 <file>`.

## Run it
All scripts in `scripts/`; one working dir per show. Run `scripts/setup.sh` once (idempotent: Python 3.12 venv for g2pk2 + mecab, compiles `apple_stt` / `ocr_frames` into `~/.cache/korean-study-subs/bin`). Needs macOS 26+, whisper.cpp + `ggml-large-v3.bin`, ffmpeg, yt-dlp + deno, uv, Codex CLI.

1. **Workdir** per show with:
   - `SHOW.md` — 3–8 lines: show, premise, character names as `한글 Romanized 中文`, recurring terms, whether official zh/en exist. The LLM reads it every episode.
   - `jobs.tsv` — TAB-separated `EP  source  video  outbase  context` (see header of `scripts/batch.sh`).
     - `source`: YouTube id, local file, or `ssh:<host>:<path>`; `video`: local/mounted path or `ssh:<host>:<path>`; `outbase`: final path without extension = video name sans extension.
     - For Jellyfin/Plex, name episodes by **TMDB numbering** (match English titles; see gotchas) so metadata lines up.
2. Stages (`scripts/batch.sh <stage> <workdir> [parallel]`):
   - asr path: `asr` (P=1, GPU) → `ocr` → `extract` (if official zh/en) → `llm-asr` (P=3) → `build-asr`
   - drama path: `extract` → `prepare` → `llm-notes` (P=3) → `build-drama`
   - Remote sources: `KSUB_SSH_OPTS` (e.g. `-p 2222`) and `KSUB_REMOTE_FFMPEG_DIR` (if ffmpeg isn't on the remote PATH).
3. **Pilot one episode first** and open it in VLC (`open -a VLC <video>`; VLC auto-loads sidecars; pick `study.ko.ass`). Confirm with the user before running a whole season.
4. Every stage skips finished outputs → rerun after fixing; delete `<EP>.json` / `<EP>.notes.json` to force an LLM redo.
5. Jellyfin: sidecars next to the video, then refresh the item (`POST /Items/<id>/Refresh`).

## LLM step
`scripts/llm_episode.sh` runs **Codex CLI** (`codex exec`). Briefs: `briefs/ASR_BRIEF.md`, `briefs/NOTES_BRIEF.md`. In the pilot Codex beat a Sonnet subagent (finer cue splits, more notes, signs). Any agent can follow the same briefs if Codex is unavailable (set `KSUB_LLM_MODEL` to pick a Codex model).

Notes style: ~1 in 3 lines; every Korean word in a note followed by `(romanization)`; Sino-Korean ↔ hanja/中文 first (`조회수 (johoesu) = 照會數 → 播放量`), loanwords (`매니저 (maenijeo) = manager (-er→-어 eo)`), mnemonics (`핸드폰 = hand phone ≈ 手机`), grammar, slang, and **basic words the first time** (`이 사람아 (i sarama)`); no filler.

## Tweaking
- Look/feel (fonts, sizes, colours, note duration `NOTE_MIN_SECS`, sign style): `scripts/build_subs.py` (`ASS_HEADER`).
- Romanization fixes: `romanize()` in `scripts/build_subs.py`.
- OCR filters (logo positions, confidence): `scripts/ocr_spans.py`.
- Note density/priorities and viewer profile: the briefs.
