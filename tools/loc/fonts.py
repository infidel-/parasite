#!/usr/bin/env python3
"""Which Options fonts can draw a language: fc-query coverage against its translated strings.

The fonts offered in Options (Config.fonts / Config.fontsTitle in src/Config.hx, read from there so
the list has one source) were picked for English. Measured for French: Dusty, DemunLotion and
FlipsideBrk have no accented letters at all, Eurocorp and Xball have no œ. A missing glyph falls back
one character at a time to some system font, so a font is offered for a language only when it covers
the characters its translation actually uses.

The character set comes from the translated strings themselves (electron/lang/<code>.json), so a
new character in a new translation is caught on the next build. A character used fewer than
RARE times (Ÿ, a stray symbol) does not disqualify a font: the CSS glyph fallback (Orkney-Regular,
appended to --text-font by Config) draws it.

The allowed lists go into the same lang file as `fonts` / `fontsTitle`; Options shows only those,
and Config falls back to the language default when the saved font is not among them.

Usage: python3 tools/loc/fonts.py --lang fr [--report]   (translate.py build runs it)
       python3 tools/loc/fonts.py --selftest
"""
from __future__ import annotations

import argparse
import json
import os
import re

import locfmt
import subprocess
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from env import path  # noqa: E402  (tools/env.py: app/ is BUILD/resources/app)

ROOT = Path(__file__).resolve().parent.parent.parent
FONT_DIR = path("app/fonts")
CONFIG = ROOT / "src" / "Config.hx"
LANG_OUT = ROOT / "electron" / "lang"
RARE = 3  # characters used fewer times than this do not disqualify a font


def offered() -> tuple:
    """(text fonts, title fonts) as listed in src/Config.hx."""
    src = CONFIG.read_text(encoding="utf-8")

    def arr(name: str) -> list:
        m = re.search(r"static var " + name + r"\s*=\s*\[(.*?)\];", src, re.S)
        return re.findall(r"'([^']+)'", m.group(1)) if m else []

    return arr("fonts"), arr("fontsTitle")


def charset(path: Path) -> set:
    """Code points a font file covers, per fc-query."""
    out = subprocess.run(["fc-query", "--format=%{charset}", str(path)],
                         capture_output=True, text=True).stdout
    s = set()
    for part in out.split():
        a, _, b = part.partition("-")
        s.update(range(int(a, 16), int(b or a, 16) + 1))
    return s


def font_file(name: str) -> Path | None:
    for ext in (".ttf", ".otf"):
        p = FONT_DIR / (name + ext)
        if p.exists():
            return p
    return None


def every_case(s: str) -> str:
    """The text of a template with every plural/select case kept and placeholder names dropped."""
    def walk(segs):
        return "".join(seg[1] if seg[0] == "text" else "" if seg[0] == "var" else
                       "".join(walk(body) for _, body in seg[3]) for seg in segs)
    try:
        return walk(locfmt.parse(s))
    except ValueError:
        return re.sub(r"\{[^{}]*\}", "", s)


def needed(strings: list) -> Counter:
    """Character use counts of the translations, markup and whitespace stripped."""
    c = Counter()
    for s in strings:
        s = re.sub(r"<[^>]*>|&#?\w+;|%\w+%", "", every_case(s))
        c.update(ch for ch in s if not ch.isspace())
    return c


def allowed(fonts: list, need: Counter, cover) -> tuple:
    """(fonts covering every character used RARE+ times, {font: missing chars})."""
    must = {ch for ch, n in need.items() if n >= RARE}
    ok, miss = [], {}
    for f in fonts:
        cs = cover(f)
        if cs is None:
            miss[f] = "(no font file)"
            continue
        m = "".join(sorted(ch for ch in must if ord(ch) not in cs))
        if m:
            miss[f] = m
        else:
            ok.append(f)
    return ok, miss


def apply(code: str, report: bool = False) -> dict:
    """Write fonts/fontsTitle into electron/lang/<code>.json; returns the updated file."""
    path = LANG_OUT / f"{code}.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    need = needed(list(data.get("strings", {}).values()))
    cache = {}

    def cover(name: str):
        if name not in cache:
            p = font_file(name)
            cache[name] = charset(p) if p else None
        return cache[name]

    text, title = offered()
    data["fonts"], miss_t = allowed(text, need, cover)
    data["fontsTitle"], miss_h = allowed(title, need, cover)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"fonts: {code}: text {len(data['fonts'])}/{len(text)}, title {len(data['fontsTitle'])}/{len(title)}")
    if report:
        for f, m in sorted({**miss_t, **miss_h}.items()):
            print(f"  {f:18} missing {m}")
    return data


def selftest() -> None:
    need = needed(["Le cœur bat", "<b>œil</b> {s:def} %x%", "sœur", "Ÿ"])
    assert need["œ"] == 3 and "Ÿ" in need and "<" not in need and "{" not in need and "%" not in need
    covers = {"Full": {ord(c) for c in "Lecœurbatilsœ"} | {ord("Ÿ")},
              "NoOe": {ord(c) for c in "Lecurbatils"},
              "Gone": None}
    ok, miss = allowed(["Full", "NoOe", "Gone"], need, lambda f: covers[f])
    assert ok == ["Full"] and miss["NoOe"] == "œ" and miss["Gone"] == "(no font file)", (ok, miss)
    text, title = offered()
    assert "Virtucorp" in text and "Cruiser2015" in title, (text, title)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--lang")
    ap.add_argument("--report", action="store_true", help="list what each rejected font lacks")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        selftest()
        print("fonts selftest: ok")
        return 0
    if not a.lang:
        ap.error("--lang is required")
    apply(a.lang, a.report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
