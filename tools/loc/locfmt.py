"""Placeholder syntax of loc.Loc (src/l10n/Loc.hx), mirrored for the Python tools.

The game's formatter and these tools must agree on what a template is: the extractor lists the
placeholder names of each string, the translator's validator rejects a translation whose names,
html tags or %tokens% differ from the source. Grammar (docs/localization.md):

    {name}                      plain value
    {name:form}                 noun form (the/a, def/indef/de/a); capital first letter capitalises
    {name, plural, one{..} other{..} =0{..}}   # inside a body is the number
    {name, select, m{..} f{..} other{..}}

Usage: imported by tools/loc/extract.py and tools/loc/translate.py.
"""
from __future__ import annotations

import hashlib
import html
import re
from collections import Counter

RE_TAG = re.compile(r"<\s*(/?)\s*([a-zA-Z][\w-]*)")
RE_ENTITY = re.compile(r"&#?\w+;")
RE_TOKEN = re.compile(r"%\w+%")


class FmtError(ValueError):
    pass


def sha(s: str) -> str:
    """State key of one source string."""
    return hashlib.sha1(s.encode("utf-8")).hexdigest()[:16]


def parse(s: str) -> list:
    """Template -> segments: ('text', s) | ('var', name, form) | ('choice', name, type, [(key, segs)])."""
    segs, pos = _segs(s, 0, False)
    return segs


def _segs(s: str, pos: int, nested: bool) -> tuple:
    out, buf = [], []
    while pos < len(s):
        c = s[pos]
        if c == "}" and nested:
            break
        if c != "{":
            buf.append(c)
            pos += 1
            continue
        if buf:
            out.append(("text", "".join(buf)))
            buf = []
        seg, pos = _placeholder(s, pos + 1)
        out.append(seg)
    if nested and pos >= len(s):
        raise FmtError("unclosed choice body")
    if buf:
        out.append(("text", "".join(buf)))
    return out, pos


def _until(s: str, pos: int, stops: str) -> tuple:
    start = pos
    while pos < len(s) and s[pos] not in stops:
        if s[pos] == "{":
            raise FmtError("stray { in a placeholder")
        pos += 1
    if pos >= len(s):
        raise FmtError("unclosed placeholder")
    t = s[start:pos].strip()
    if not t:
        raise FmtError("empty placeholder part")
    return t, pos


def _placeholder(s: str, pos: int) -> tuple:
    name, pos = _until(s, pos, ":,}")
    c = s[pos]
    pos += 1
    if c == "}":
        return ("var", name, ""), pos
    if c == ":":
        form, pos = _until(s, pos, "}")
        return ("var", name, form), pos + 1
    kind, pos = _until(s, pos, ",")
    pos += 1
    if kind not in ("plural", "select"):
        raise FmtError(f'unknown choice type "{kind}"')
    cases = []
    while True:
        while pos < len(s) and s[pos] == " ":
            pos += 1
        if pos >= len(s):
            raise FmtError("unclosed choice")
        if s[pos] == "}":
            pos += 1
            break
        key, pos = _until(s, pos, "{")
        body, pos = _segs(s, pos + 1, True)
        cases.append((key, body))
        pos += 1
    return ("choice", name, kind, cases), pos


def names(s: str) -> list:
    """Placeholder names in order of first use, choice bodies included."""
    out = []

    def walk(segs):
        for seg in segs:
            if seg[0] == "text":
                continue
            if seg[1] not in out:
                out.append(seg[1])
            if seg[0] == "choice":
                for _, body in seg[3]:
                    walk(body)

    walk(parse(s))
    return out


def text_parts(s: str) -> str:
    """The literal text of a template (choice bodies included), placeholders dropped."""
    out = []

    def walk(segs):
        for seg in segs:
            if seg[0] == "text":
                out.append(seg[1])
            elif seg[0] == "choice":
                for _, body in seg[3]:
                    walk(body)

    walk(parse(s))
    return "".join(out)


def visible(s: str) -> str:
    """What a player could see of a template: each placeholder as its name, each choice as its
    longest case (the select/plural syntax itself is not text and must not count as length)."""
    def render(segs):
        out = []
        for seg in segs:
            if seg[0] == "text":
                out.append(seg[1])
            elif seg[0] == "var":
                out.append(seg[1])
            else:
                out.append(max((render(body) for _, body in seg[3]), key=len, default=""))
        return "".join(out)

    return render(parse(s))


def markup(s: str) -> Counter:
    """Multiset of what a translation must keep: placeholder names (+forms are free), html tag
    names, entities (except a letter's or an apostrophe's) and %tokens%."""
    c = Counter()
    for n in names(s):
        c["{" + n + "}"] += 1
    for close, tag in RE_TAG.findall(s):
        c["<" + close + tag.lower() + ">"] += 1
    for e in RE_ENTITY.findall(s):
        # an entity for a letter or an apostrophe (&#233;, &#39;) is text, not markup: free to change
        ch = html.unescape(e)
        if len(ch) == 1 and (ch.isalpha() or ch in "'’"):
            continue
        c[e] += 1
    for t in RE_TOKEN.findall(s):
        c[t] += 1
    return c


def check(src: str, tr: str) -> str | None:
    """Why a translation does not fit its source, or None."""
    try:
        parse(tr)
    except FmtError as e:
        return f"bad placeholder syntax: {e}"
    a, b = markup(src), markup(tr)
    if a != b:
        lost = a - b
        extra = b - a
        bits = []
        if lost:
            bits.append("missing " + " ".join(sorted(lost)))
        if extra:
            bits.append("extra " + " ".join(sorted(extra)))
        return "; ".join(bits)
    return None


def selftest() -> None:
    assert names("{a:The} {n, plural, one{# {b}} other{#}} {a}") == ["a", "n", "b"]
    assert names("plain") == []
    assert text_parts("{n, plural, one{# turn} other{# turns}}") == "# turn# turns"
    for bad in ["{oops", "{n, plural, one{x}", "{n, maybe, a{b}}", "{}", "{a{b}}"]:
        try:
            parse(bad)
        except FmtError:
            continue
        raise AssertionError(bad)
    assert check("{s:The} hits <b>{t}</b>.", "{s:Def} frappe <b>{t}</b>.") is None
    assert "missing" in check("{s} hits {t}.", "{s} frappe.")
    assert "extra" in check("Hi.", "Salut {x}.")
    assert check("a %name% b", "a b") is not None
    assert check("x &rarr; y", "x &rarr; y") is None
    assert check("The Lobbyist&#39;s Expos&#233;", "Die Kommunion des Lobbyisten") is None
    assert check("R&#38;D", "F und E") is not None
    assert check("<span class=a>x</span>", "<span class=b>y</span>") is None
    assert sha("abc") == sha("abc") and len(sha("abc")) == 16
    assert visible("+{v} {p, select, media{médias} other{x}} power") == "+v médias power"
    assert visible("{n, plural, one{# turn} other{# turns}}") == "# turns"


if __name__ == "__main__":
    selftest()
    print("locfmt selftest: ok")
