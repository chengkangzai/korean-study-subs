# korean-study-subs

A [Claude Code](https://claude.com/claude-code) skill (and plain shell/Python pipeline) that turns Korean shows into **study subtitles** for learners who speak Chinese and English:

```
 [note, top-left]  조회수 (johoesu) = 照會數 → 播放量

            ige wae johoesuga icheonmani neomeo?      ← pronunciation romanization (per line)
              이게 왜 조회수가 2천만이 넘어?            ← Korean
              这个怎么会有两千多万播放量？               ← Chinese
```

- **Romanization follows pronunciation**, not spelling (g2pk2 → Revised Romanization): 같네 → *ganne*, 법대로 → *beopttaero*.
- **Learning notes** on ~1 in 3 lines: Sino-Korean ↔ hanja/中文 (`수술 (susul) = 手術`), English loanwords (`매니저 (maenijeo) = manager`), grammar endings, slang, and basic words the first time they appear.
- **On-screen text** (signs, phone screens) is OCR'd and translated, including untranslated English background art (`CAUTION → 주의 (juui) 注意`).
- Output is plain sidecar files (`.study.ko.ass`, `.ko/.zh/.en.srt`) for VLC, Jellyfin, Plex, mpv.

## Two paths

| Source | Pipeline |
|---|---|
| Video already has official Korean subtitles (most streaming WEB-DLs) | extract official ko/zh/en → LLM writes **notes only** → build |
| No Korean subtitles (dubbed cartoons, YouTube) | Whisper large-v3 **+** Apple SpeechTranscriber **+** YouTube auto-captions → LLM votes on the true line, translates, writes notes → build |

Using two independent speech models and letting them vote catches far more mistakes than one model alone. A text-only LLM can't verify what was actually said.

## Requirements
macOS 26+ (Apple `SpeechAnalyzer` + Vision), [whisper.cpp](https://github.com/ggml-org/whisper.cpp) with `ggml-large-v3.bin`, ffmpeg, yt-dlp (+ deno), [uv](https://github.com/astral-sh/uv), Swift toolchain, [Codex CLI](https://github.com/openai/codex) for the LLM step (or adapt `scripts/llm_episode.sh`).

## Use
```bash
git clone https://github.com/chengkangzai/korean-study-subs ~/.claude/skills/korean-study-subs
~/.claude/skills/korean-study-subs/scripts/setup.sh
```
Then in Claude Code: *"do Korean study subs for <show>"*, or run the stages by hand. See [`SKILL.md`](SKILL.md) for the workflow and `jobs.tsv` format, and [`references/gotchas.md`](references/gotchas.md) for the problems this pipeline already solves.

Bring your own media. This repo contains no video, audio or subtitle content.

## License
MIT
