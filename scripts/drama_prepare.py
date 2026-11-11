#!/usr/bin/env python3
"""Official ko/zh/en SRTs -> cue JSON (ko + time-matched zh/en) and a numbered line list for the notes model.

Usage: drama_prepare.py <dir> <CODE>
Reads  <dir>/<CODE>.official.{ko,zh,en}.srt
Writes <dir>/<CODE>.cues.json  and  <dir>/<CODE>.lines.txt   ("id | ko | zh")
"""
import json
import re
import sys

LRM = re.compile(r"[‎‏‪-‮]")
TAG = re.compile(r"<[^>]+>|\{[^}]+\}")


def parse(path):
    try:
        raw = open(path, encoding="utf-8-sig").read()
    except FileNotFoundError:
        return []
    cues = []
    for block in re.split(r"\n\s*\n", raw.replace("\r", "").strip()):
        lines = block.strip().split("\n")
        idx = next((i for i, l in enumerate(lines) if "-->" in l), None)
        if idx is None:
            continue
        a, b = [x.strip() for x in lines[idx].split("-->")]
        text = "\n".join(LRM.sub("", TAG.sub("", l)).strip() for l in lines[idx + 1:]).strip()
        if text:
            cues.append({"start": a[:12], "end": b[:12], "text": text})
    return cues


def secs(t):
    h, m, rest = t.replace(".", ",").split(":")
    s, ms = rest.split(",")
    return int(h) * 3600 + int(m) * 60 + int(s) + int(ms) / 1000


def strip_sdh(text):
    """Remove [sound descriptions] and (speaker) labels; return dialogue only."""
    t = re.sub(r"\[[^\]]*\]", "", text)
    t = re.sub(r"^\([^)]*\)\s*", "", t, flags=re.M)
    t = re.sub(r"\n\s*\n", "\n", t)
    return "\n".join(l.strip() for l in t.split("\n") if l.strip())


def overlap_text(cue, others):
    a, b = secs(cue["start"]), secs(cue["end"])
    hits = []
    for o in others:
        oa, ob = secs(o["start"]), secs(o["end"])
        ov = min(b, ob) - max(a, oa)
        if ov > 0 and ov >= 0.3 * min(b - a, ob - oa):
            hits.append(o["text"])
        if oa > b:
            break
    return " ".join(dict.fromkeys(h.replace("\n", " ") for h in hits))


def main():
    d, code = sys.argv[1], sys.argv[2]
    ko = parse(f"{d}/{code}.official.ko.srt")
    zh = parse(f"{d}/{code}.official.zh.srt")
    en = parse(f"{d}/{code}.official.en.srt")
    out = []
    for c in ko:
        text = strip_sdh(c["text"])
        if not re.search(r"[가-힣]", text):
            continue
        if text.startswith('"') and "NETFLIX" in text.upper():
            continue
        out.append({"id": len(out) + 1, "start": c["start"], "end": c["end"], "ko": text,
                    "zh": overlap_text(c, zh), "en": overlap_text(c, en), "note": None})
    json.dump(out, open(f"{d}/{code}.cues.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    with open(f"{d}/{code}.lines.txt", "w", encoding="utf-8") as f:
        for c in out:
            f.write(f"{c['id']} | {c['ko'].replace(chr(10), ' / ')} | {c['zh']}\n")
    print(f"{code}: ko {len(ko)} -> {len(out)} dialogue cues; zh matched {sum(1 for c in out if c['zh'])}")


if __name__ == "__main__":
    main()
