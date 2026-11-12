# Brief: Korean study subtitles from speech-to-text (no official Korean subtitles available)

Read `SHOW.md` in this directory first: show context, character names (Korean / Chinese / English), recurring terms, and any official zh/en subtitles to use as a meaning reference.

Viewer: native Mandarin Chinese + English speaker, BEGINNER in Korean (cannot read Hangul yet). Romanization is added automatically by the build script — do not write it except inside notes.

## Input: `<EP>.evidence.txt` (speech) and `<EP>.ocrspans.txt` (on-screen text; may be empty)
Three independent speech-to-text hypotheses of the SAME audio, merged and sorted by time:
- `W` = Whisper large-v3. `word@seconds`; `~0.23` suffix = low confidence. Good words, but hallucinates over music, and word times at the START of a segment that follows music/silence can be badly early (e.g. first word @0.1 when the line is really @16).
- `A` = Apple SpeechTranscriber. Independent model; word times usually accurate; good on fast casual speech; weak on songs (outputs junk syllables) and misspells names/loanwords.
- `OCR` = on-screen Korean text (signs, screens, title cards) read from video frames at 1 frame/s by Apple Vision. Time span is approximate (±1 s). Vision can misread letters (e.g. 농놀 for 넘넘) — fix from context.
- `Y` = YouTube auto-captions. Rolling, approximate timing, words split across rows. Third opinion for words only.

You cannot hear the audio. Reconstruct the true line by voting:
- W and A agree (allowing spacing/punctuation) → accept, confident.
- Disagree → pick using Y as tie-breaker + story/character context + Korean grammar. Mark `"uncertain": true` if still unsure.
- Only one source has the line → keep only if plausible dialogue; uncertain unless it's clearly coherent.

DROP: hallucinations ("다음 영상에서 만나요", "시청해주셔서 감사합니다", "구독", "한글자막", "뉴스"), a line repeated 3+ times in a row by W ONLY (if A or Y also hear the repeats, they are real — a character repeating themselves, a chant or a song — KEEP every repeat as its own cue), long repeated syllables (으아아…, 으으으), lone punctuation, junk syllable strings. Songs: keep lyrics when W/Y give coherent text; mark uncertain.

Names: use the glossary in `SHOW.md`; fix misheard names and loanwords to match it.

## On-screen text (OCR rows)
Make one cue per meaningful sign with `"sign": true`: start = span start, end = max(span end, start + 3 s). `ko` = the corrected sign text; translate in `zh`/`en`; a note if useful (signs are often great vocabulary). Skip OCR junk. Sign cues may overlap dialogue cues — that's fine.
English signs (untranslated background art, e.g. CAUTION, STOP!, OUT TODAY): the viewer wants these too, as vocabulary. Repair OCR jitter (ALDEADY→ALREADY, CAUTiON→CAUTION); skip fragments that aren't recoverable words (ITABLE, IMATE, SEADY); merge adjacent rows of the same sign; show the same sign at most once per scene/minute. For an English sign: `ko` = natural Korean rendering (e.g. CAUTION → 주의, STOP → 멈춤, OUT TODAY → 오늘 출시), `en` = the original English text, `zh` = Chinese, and `src`: "en". Korean signs: `src`: "ko".

## Timing
Use word timestamps. Each cue: start = first word's start (prefer A's time when W's is suspicious), end = start of the next cue's first word or ~0.3 s after the last word, whichever is earlier; minimum 0.8 s, maximum 6 s. Split at sentence boundaries; a cue ≤ ~30 Korean chars. Never estimate times by dividing a long segment evenly — use the word times.

## Official translations (optional)
If `<EP>.official.zh.srt` / `<EP>.official.en.srt` exist, use them as the meaning reference (they are correct translations) and copy their wording into `zh`/`en` for the matching time range instead of translating yourself. They never replace the Korean.

## Output fields per cue
- `ko`: corrected Korean.
- `zh`: natural Simplified Chinese subtitle.
- `en`: natural English subtitle.
- `note`: optional learning legend. EVERY Korean word or ending in a note is followed by its pronunciation romanization in parentheses, e.g. `조회수 (johoesu) = 照會數 → 播放量`, `-니까 (-nikka) = 因为…所以`, `매니저 (maenijeo) = manager (-er→-어 eo)`. The viewer cannot read Hangul yet. on **35–40% of dialogue cues** (never below 33% — count before finishing and add more if short), ≤ 80 chars, Chinese+Korean (English OK). No filler like "与中文同义" — every word must teach something. The viewer is a beginner: also explain basic high-frequency words, address terms and endings the FIRST time they appear (e.g. `사람 (saram) = 人; 이 사람아 (i sarama) = "你这个人啊", -아 (-a) = 呼格`). Never repeat a note within the episode. Priority:
  1. Sino-Korean word ↔ hanja/Chinese: `조회수 (johoesu) = 照會數 → 播放量`
  2. English loanwords (외래어): `매니저 (maenijeo) = manager (-er→-어 eo)`; spelling patterns (f→ㅍ, -er→-어, -tion→-션); flag false friends (`파이팅 (paiting) = 加油`); mnemonics like `핸드폰 (haendeupon) = hand phone ≈ 手机`.
  3. Grammar endings: `-니까 (-nikka) = 因为…所以`
  4. Casual expressions/slang: `꼴까닥하다 (kkolkkadakada) = 嗝屁(俗)`
- `uncertain`: true/false.
- `sign`: true only for on-screen text cues (omit or false for dialogue). `src`: "ko"/"en" for signs only.

## Output
Write ONLY `<EP>.json` (path given), a JSON array in time order:
`{"start":"00:02:13,900","end":"00:02:17,900","ko":"…","zh":"…","en":"…","note":null,"uncertain":false,"sign":false}`
Validate: `python3 -I -c 'import json,sys;json.load(open(sys.argv[1]))' FILE`. Do not create any other files (no helper scripts outside /tmp of your own; delete any you make).

Report briefly: cues, dropped, uncertain count + timestamps, 3 sample notes.
