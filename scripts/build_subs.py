#!/usr/bin/env python3
"""JSON cues -> <base>.ko.srt / .zh.srt / .en.srt + <base>.study.ko.ass

Usage: build_subs.py cues.json "/path/to/We Bare Bears - S01E26"
"""
import json
import os
import sys


def srt_time(t):
    return t.replace(".", ",")


def ass_time(t):
    # "HH:MM:SS,mmm" -> "H:MM:SS.cc"
    h, m, rest = t.replace(".", ",").split(":")
    s, ms = rest.split(",")
    return f"{int(h)}:{m}:{s}.{int(ms) // 10:02d}"


def ass_escape(s):
    return s.replace("\\", "\\\\").replace("{", "(").replace("}", ")").replace("\n", "\\N")


SIGN_PREFIX = {"ko": "[화면] ", "zh": "[画面] ", "en": "[Sign] "}


def write_srt(cues, path, key):
    lines = []
    n = 0
    for c in cues:
        text = (c.get(key) or "").strip()
        if text and c.get("sign"):
            text = SIGN_PREFIX[key] + text
        if not text:
            continue
        n += 1
        lines += [str(n), f"{srt_time(c['start'])} --> {srt_time(c['end'])}", text, ""]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


ASS_HEADER = """[Script Info]
Title: We Bare Bears - Korean study track
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
WrapStyle: 0
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: ROM,Helvetica Neue,38,&H00F0D8B0,&H000000FF,&H00000000,&H80000000,0,-1,0,0,100,100,1,0,1,2.5,1,2,60,60,185,1
Style: KO,Apple SD Gothic Neo,64,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,3.5,1,2,60,60,110,1
Style: ZH,PingFang SC,46,&H00B4E6FF,&H000000FF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,3,1,2,60,60,45,1
Style: SIGN,PingFang SC,44,&H00FFFFFF,&H000000FF,&H00000000,&HB0402000,0,0,0,0,100,100,0,0,3,12,0,8,60,60,40,1
Style: NOTE,PingFang SC,40,&H0066E6FF,&H000000FF,&H00000000,&HA0000000,0,0,0,0,100,100,0,0,3,10,0,7,50,50,40,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""


_G2P = None


def romanize(text):
    """Pronunciation-aware romanization: g2pk2 (applies sound changes) -> Revised Romanization."""
    global _G2P
    from korean_romanizer.romanizer import Romanizer
    try:
        if _G2P is None:
            from g2pk2 import G2p
            _G2P = G2p()
        text = _G2P(text)
    except Exception:
        pass
    import re
    r = Romanizer(text).romanize()
    r = r.replace("lr", "ll")                  # ㄹㄹ is "ll" in Revised Romanization
    r = re.sub(r"([a-z])\1\1+", r"\1\1", r)   # g2pk tensing + RR can triple a letter
    return r


NOTE_MIN_SECS = 5.0
ZH_VARIANT = os.environ.get("KSUB_ZH", "hant")


def to_variant(cues):
    """Convert Chinese (zh field + Chinese inside notes) to Traditional (Taiwan phrasing) when KSUB_ZH=hant."""
    if ZH_VARIANT != "hant":
        return cues
    try:
        import opencc
    except ImportError:
        return cues
    cc = opencc.OpenCC("s2twp")
    for c in cues:
        for k in ("zh", "note"):
            if c.get(k):
                c[k] = cc.convert(c[k])
    return cues


def secs(t):
    h, m, rest = t.replace(".", ",").split(":")
    s, ms = rest.split(",")
    return int(h) * 3600 + int(m) * 60 + int(s) + int(ms) / 1000


def fmt_secs(x):
    h, x = divmod(x, 3600)
    m, s = divmod(x, 60)
    return f"{int(h):02d}:{int(m):02d}:{int(s):02d},{int(round((s % 1) * 1000)) % 1000:03d}"


def note_end(cues, i):
    """Keep a note on screen >= NOTE_MIN_SECS. Overlapping notes are stacked by the renderer."""
    c = cues[i]
    return fmt_secs(max(secs(c["end"]), secs(c["start"]) + NOTE_MIN_SECS))


def write_ass(cues, path):
    out = [ASS_HEADER]
    for i, c in enumerate(cues):
        st, en = ass_time(c["start"]), ass_time(c["end"])
        if c.get("sign"):
            body = ass_escape(c.get("ko", ""))
            if c.get("src") == "en" and c.get("en"):
                body = ass_escape(c["en"]) + " → " + body
            rom = romanize(c.get("ko", ""))
            if rom:
                body += "\\N{\\i1\\fs32}" + ass_escape(rom) + "{\\i0\\fs44}"
            body += "\\N{\\c&H00B4E6FF&}" + ass_escape(c.get("zh", ""))
            out.append(f"Dialogue: 3,{st},{en},SIGN,,0,0,0,,{body}\n")
            if c.get("note"):
                out.append(f"Dialogue: 2,{st},{ass_time(note_end(cues, i))},NOTE,,0,0,0,,{ass_escape(c['note'])}\n")
            continue
        if c.get("ko"):
            # romanization stacked above Korean in ONE event, so wrapping never overlaps
            # interleave: each Korean line gets its own romanization line right above it
            parts = []
            for line in [l for l in c["ko"].split("\n") if l.strip()]:
                rom = romanize(line)
                if rom:
                    parts.append("{\\rROM}" + ass_escape(rom))
                parts.append("{\\rKO}" + ass_escape(line))
            out.append(f"Dialogue: 1,{st},{en},KO,,0,0,0,," + "\\N".join(parts) + "\n")
        if c.get("zh"):
            out.append(f"Dialogue: 0,{st},{en},ZH,,0,0,0,,{ass_escape(c['zh'])}\n")
        if c.get("note"):
            nen = ass_time(note_end(cues, i))
            out.append(f"Dialogue: 2,{st},{nen},NOTE,,0,0,0,,{ass_escape(c['note'])}\n")
    with open(path, "w", encoding="utf-8-sig") as f:
        f.write("".join(out))


def main():
    cues = to_variant(json.load(open(sys.argv[1], encoding="utf-8")))
    base = sys.argv[2]
    for key in ("ko", "zh", "en"):
        tag = "zh-TW" if (key == "zh" and ZH_VARIANT == "hant") else key
        write_srt(cues, f"{base}.{tag}.srt", key)
    write_ass(cues, f"{base}.study.ko.ass")
    notes = sum(1 for c in cues if c.get("note"))
    unc = sum(1 for c in cues if c.get("uncertain"))
    print(f"{len(cues)} cues, {notes} notes, {unc} uncertain -> {base}.*")


if __name__ == "__main__":
    main()
