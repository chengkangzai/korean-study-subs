#!/usr/bin/env python3
"""cues.json + notes.json -> <out base>.study.ko.ass   (drama: official ko/zh/en stay embedded in the MKV)
Usage: drama_build.py cues.json notes.json "<out base>"
"""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_subs import write_ass, to_variant
cues = json.load(open(sys.argv[1], encoding="utf-8"))
notes = json.load(open(sys.argv[2], encoding="utf-8")) if os.path.exists(sys.argv[2]) else {}
for c in cues:
    c["note"] = notes.get(str(c["id"]))
write_ass(to_variant(cues), sys.argv[3] + ".study.ko.ass")
print(f"{len(cues)} cues, {sum(1 for c in cues if c['note'])} notes -> {sys.argv[3]}.study.ko.ass")
