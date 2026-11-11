# Gotchas learned building this pipeline (2026-11-11, We Bare Bears + Hospital Playlist)

## Speech-to-text
- **Never use Whisper VAD** (`--vad`) on dubbed cartoons/dramas: it silently drops dialogue that has music underneath (lost ~6 min of a 12-min episode). Run without VAD and let the LLM drop hallucinations.
- Whisper no-VAD hallucinations to expect: YouTube outros ("다음 영상에서 만나요", "시청해주셔서 감사합니다", "구독과 좋아요"), credit lines ("한글자막"), a short line looped 10–25×, long "으아아…" runs. Rule: drop a repeat only when **W alone** has it — if Apple/YouTube also hear repeats, they're real (a koala chanting "난 귀여운 아기 코알라예요" got wrongly dropped once).
- Whisper word times at the start of a segment after music can be ~15 s early; Apple SpeechTranscriber's word times are reliable. Split cues by **word timestamps**, never by dividing a segment evenly (that put lines 2 s early).
- Apple SpeechTranscriber (macOS 26 `SpeechAnalyzer`) supports `ko_KR`, downloads its model on first use, ~16 s per 12-min episode, independent errors from Whisper → great cross-check. Weak on songs.
- Text-only LLM "cross-checking" can't verify what was said — only a second *audio* model can. Voting W/A/Y is the check.

## Romanization
- `korean-romanizer` alone spells, it doesn't pronounce (같네 → gatne). Run **g2pk2** first (applies sound changes: 같네→간네→ganne, 법대로→법때로→beopttaero), then romanize.
- `python-mecab-ko` (needed by g2pk2) has no wheels for Python ≥3.13 → separate **uv 3.12 venv** (`setup.sh`).
- Post-fixes in `romanize()`: ㄹㄹ "lr" → "ll"; collapse tripled letters (g2pk tensing + RR → "kkk").
- Two-line subtitles: romanization must be **interleaved per line** (rom1/ko1/rom2/ko2), not both rom lines above both Korean lines.

## On-screen text (OCR)
- Apple Vision `VNRecognizeTextRequest` with `ko-KR,en-US`, 1 frame/s at 1280 px ≈ 1 min per 12-min episode.
- Drop channel logos by position (top corners) + regex. Keep Korean at conf ≥0.4; English only at conf ≥0.9 (background art jitters: ALREADY/ALDEADY/READ). The LLM merges repeats and turns English signs into vocab (`CAUTION → 주의 (juui) 注意`).
- YouTube direct stream URLs (`yt-dlp -g`) return **403** to ffmpeg now — OCR from a downloaded file instead.

## YouTube / yt-dlp
- yt-dlp needs a **JS runtime (deno)** or many videos fail with "This video is not available". Install deno where yt-dlp runs (`/usr/local/bin/deno` in containers).
- Some videos carry **YouTube AI auto-dub** audio (`[en-US] dubbed-auto`) → format ids become `140-0/140-1`; pin Korean: `-f "137+140-1/137+bestaudio[language^=ko][ext=m4a]/137+140"`, audio-only `bestaudio[language^=ko]`.
- Cartoon Network Korea ("Cartoon Network Korea" channel) posts full We Bare Bears S1/S2 episodes in Korean dub; no S3; only 2 full We Baby Bears episodes.

## Shell
- `ssh` inside a `while read` loop eats the loop's stdin → only the first item runs. Always `ssh -n` (scripts do) or `</dev/null`.
- `pct exec` strips PATH → full paths or `export PATH=…` inside.
- macOS (BSD) `xargs` has no `-d` → use NUL-separated input + `xargs -0`.
- Editing a bash script while a loop is executing it can break the running loop; edit a copy or wait.

## Jellyfin / TMDB
- Name files by **TMDB numbering**, not the uploader's: Cartoon Network Korea's order ≠ TMDB (their "ep 1" Charlie and the Snake = TMDB S01E20). Match by English title; scrape `https://www.themoviedb.org/tv/<id>/season/<n>` (`<h3><a>` titles).
- Unmatched compilations → `Season 00/… S00E9x`; two-part uploads of one TMDB episode → concat into one file and shift part-2 subs.
- Sidecars: `<video basename>.ko.srt / .zh.srt / .en.srt / .study.ko.ass` next to the video; refresh the item (`POST /Items/<id>/Refresh`).
- Netflix WEB-DL MKVs often embed official kor/chi/eng subs → skip ASR entirely; the Korean track may be SDH (`[주제곡]`, `(송화)`) — strip for the study track.

## Shell / transfer
- Sourcing `scripts/env.sh` from **zsh** leaves `BASH_SOURCE` empty → paths resolve relative to cwd and can silently pick up a stale copy of the scripts. env.sh now falls back to `$0`; still prefer calling the scripts (bash shebang) over sourcing.
- Tar from macOS to Linux: set `COPYFILE_DISABLE=1` or the archive carries `._*` AppleDouble files that land next to the sidecars (Jellyfin shows them as junk subtitle tracks).
