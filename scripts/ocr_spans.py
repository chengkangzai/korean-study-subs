#!/usr/bin/env python3
"""Turn per-frame OCR json into on-screen-text spans, dropping channel logos.

Usage: ocr_spans.py ocr.json out.txt
Output lines:  OCR 08:49-08:53 | 이미지 찾을 수 없음   (conf)
"""
import json
import re
import sys

LOGO = re.compile(
    r"^(CN|C|N|CARTOON\s*NETWORK|CARTOON|NETWORK|위|베어|베어스|위\s*베어|베어\s*베어스|위\s*베어\s*베어스|곰\s*브라더스|브라더스)$",
    re.I,
)
MIN_CONF = 0.4


def fmt(t):
    m, s = divmod(t, 60)
    return f"{int(m):02d}:{int(s):02d}"


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


def keep(line):
    x, y, w, h = line["box"]
    txt = norm(line["text"])
    if not txt or line["conf"] < MIN_CONF:
        return False
    # logo corners: top-left (x<0.25,y>0.7) and top-right (x>0.75,y>0.7)
    if y > 0.68 and (x < 0.25 or x > 0.72):
        return False
    if LOGO.match(txt):
        return False
    # Korean: keep at >= MIN_CONF. English background art: keep only confident real words
    if len(re.findall(r"[가-힣]", txt)) >= 2:
        return True
    if line["conf"] >= 0.9 and re.search(r"[A-Za-z]{3,}", txt):
        return True
    return False
    return True


def main():
    frames = json.load(open(sys.argv[1], encoding="utf-8"))
    spans = {}  # text -> [start, end, maxconf]
    order = []
    for f in frames:
        texts = [l for l in f["lines"] if keep(l)]
        if not texts:
            continue
        # group lines of one frame top-to-bottom into one sign string
        texts.sort(key=lambda l: (-l["box"][1], l["box"][0]))
        sign = " / ".join(norm(l["text"]) for l in texts)
        conf = max(l["conf"] for l in texts)
        t = f["t"]
        if sign in spans and t - spans[sign][1] <= 2.0:
            spans[sign][1] = t + 1
            spans[sign][2] = max(spans[sign][2], conf)
        else:
            key = sign if sign not in spans else f"{sign}\x00{t}"
            spans[key] = [t, t + 1, conf]
            order.append(key)
    with open(sys.argv[2], "w", encoding="utf-8") as out:
        out.write("# OCR = on-screen text (Apple Vision, 1 frame/s); spans merged; logos removed\n")
        for k in order:
            st, en, c = spans[k]
            out.write(f"OCR {fmt(st)}-{fmt(en)} | {k.split(chr(0))[0]}   ({c:.2f})\n")
    print(f"{len(order)} spans -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
