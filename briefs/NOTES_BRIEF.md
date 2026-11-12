# Brief: learning notes for a Korean drama (official subtitles)

Viewer: native Mandarin Chinese + English speaker, BEGINNER in Korean (cannot read Hangul yet; a romanization line is already shown above every subtitle).

## Input: `<CODE>.lines.txt`
One line per subtitle: `id | Korean (official) | Chinese (official, time-matched)`. The Korean and Chinese are correct — do NOT change or retranslate them.

## Task
Write short learning notes ("legend") on **35–40% of lines** (e.g. 500 lines → 175–200 notes; never below 33%), choosing the lines where a note teaches the most. The viewer is a beginner: explain basic high-frequency words, address terms and endings the FIRST time they appear (e.g. `사람 (saram) = 人; 이 사람아 (i sarama) = "你这个人啊"(亲昵/责备的称呼), -아 (-a) = 呼格`, `올해 (olhae) = 今年`, `운 (un) = 運 → 运气`), not only advanced vocabulary. A note may cover 2 items from the same line, separated by "；". Spread them through the episode. No filler like "与中文同义" / "same as Chinese" — every word of the note must teach something. Never repeat a note within the episode (a word already explained is not explained again).

EVERY Korean word or ending in a note is followed by its pronunciation romanization in parentheses. ≤ 80 chars per note. Chinese + Korean (English OK for grammar terms). Priority:
1. Sino-Korean words ↔ hanja/Chinese — the biggest win for this viewer: `수술 (susul) = 手術 → 手术`, `환자 (hwanja) = 患者`, `교수님 (gyosunim) = 教授+님(尊称)`.
2. English loanwords (외래어): `커피 (keopi) = coffee (f→ㅍ p)`; spelling patterns (f→ㅍ, -er→-어, -tion→-션); false friends (`파이팅 (paiting) = 加油`); mnemonics (`핸드폰 (haendeupon) = hand phone ≈ 手机`).
3. Grammar endings & speech levels: `-거든 (-geodeun) = 解释理由/"…的嘛"`, `-니까 (-nikka) = 因为…所以`; honorific vs casual (반말/존댓말) when the switch matters.
4. Casual expressions, slang, interjections and address terms: `어휴 (eohyu) = 唉/天啊`, `형 (hyeong) = 哥(男称)`.

## Output
Write ONLY `<CODE>.notes.json`: a JSON object mapping id (as string) → note, e.g. `{"2": "커피 (keopi) = coffee (f→ㅍ p)", "11": "…"}`.
Validate: `python3 -I -c 'import json,sys;json.load(open(sys.argv[1]))' FILE`. Do not create other files.
Before finishing, count: notes ÷ lines must be ≥ 0.33 — if lower, add notes (basic words, endings, address terms are fine). Report briefly: number of notes, the ratio, and 5 sample notes.
