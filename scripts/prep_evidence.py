#!/usr/bin/env python3
"""Merge whisper (-ojf), Apple STT json and YouTube srt into one compact evidence file.

Usage: prep_evidence.py whisper.json apple.json youtube.srt out.txt

Each word is printed as  word@start  ; low-confidence words get a suffix  ~0.31
"""
import json
import re
import sys

LOW = 0.5


def fmt(t):
    m, s = divmod(t, 60)
    return f"{int(m):02d}:{s:04.1f}"


def whisper_lines(path):
    d = json.load(open(path, encoding="utf-8", errors="replace"))
    out = []
    for seg in d["transcription"]:
        words = []  # [text, start, minp]
        for t in seg["tokens"]:
            txt = t["text"]
            if txt.startswith("[_") or not txt.strip():
                continue
            st = t["offsets"]["from"] / 1000
            p = t.get("p", 1.0)
            if txt.startswith(" ") or not words:
                words.append([txt.strip(), st, p])
            else:
                words[-1][0] += txt
                words[-1][2] = min(words[-1][2], p)
        if not words:
            continue
        body = " ".join(
            f"{w}@{s:.1f}" + (f"~{p:.2f}" if p < LOW else "") for w, s, p in words
        )
        out.append((words[0][1], f"W {fmt(words[0][1])}-{fmt(seg['offsets']['to'] / 1000)} | {body}"))
    return out


def apple_lines(path):
    out = []
    for seg in json.load(open(path, encoding="utf-8")):
        words = []  # merge runs into space-delimited words
        for w in seg["words"]:
            txt = w["t"]
            c = w.get("c")
            c = 1.0 if c is None else c
            if txt.startswith(" ") or not words:
                if txt.strip():
                    words.append([txt.strip(), w["s"], c])
            else:
                words[-1][0] += txt.strip()
                words[-1][2] = min(words[-1][2], c)
        if not words:
            continue
        body = " ".join(
            f"{w}@{s:.1f}" + (f"~{c:.2f}" if c < LOW else "") for w, s, c in words
        )
        out.append((seg["start"], f"A {fmt(seg['start'])}-{fmt(seg['end'])} | {body}"))
    return out


def youtube_lines(path):
    out = []
    raw = open(path, encoding="utf-8").read().strip()
    seen = set()
    for block in re.split(r"\n\s*\n", raw):
        lines = block.strip().split("\n")
        if len(lines) < 3:
            continue
        h, m, rest = lines[1].split(" --> ")[0].split(":")
        st = int(h) * 3600 + int(m) * 60 + float(rest.replace(",", "."))
        text = " ".join(lines[2:]).strip()
        if not text or text in seen or re.fullmatch(r"\[[^\]]+\]", text):
            continue
        seen.add(text)
        out.append((st, f"Y {fmt(st)} | {text}"))
    return out


def main():
    w, a, y, outp = sys.argv[1:5]
    rows = whisper_lines(w) + apple_lines(a) + youtube_lines(y)
    rows.sort(key=lambda r: r[0])
    with open(outp, "w", encoding="utf-8") as f:
        f.write("# W=Whisper large-v3 (word@sec, ~p = low confidence)  A=Apple SpeechTranscriber  Y=YouTube auto-captions (rolling, approx)\n")
        f.write("\n".join(r[1] for r in rows) + "\n")
    print(f"{len(rows)} rows -> {outp}")


if __name__ == "__main__":
    main()
