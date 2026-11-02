#!/usr/bin/env python3
"""String catalog for localization: every T('...') / N('...') literal in src/, with context.

T() translates a literal where it is used, N() only marks one for extraction (the text stays
English in memory and saves and is translated where it is displayed) — see docs/localization.md.
Both take a constant literal (the T/N macros refuse anything else), so a small Haxe lexer is
enough: comments and other strings are skipped, 'a' + 'b' chains fold, escapes decode.

Each entry carries what a translator needs: file:line of every use, the enclosing Class.member,
the field or call the literal is written into (name:, note =, addOptToggle(...)), its placeholder
names, and a `// tr: ...` note from the line above.

The catalog is loc/en.json. --check also compares it with every language state (loc/<code>.json,
written by tools/loc/translate.py) and prints one line — the build runs it, so a changed string
announces itself on the next make:

    loc: 4123 strings (+2 -1 since last build) · fr: 3 new (1 changed), 1 removed

Usage: python3 tools/loc/extract.py [--check] [--strict] [--list <code>] [--root <dir>] [--selftest]
       (run from repo root; the src Makefile runs --check after every build)
"""
from __future__ import annotations

import argparse
import bisect
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import locfmt  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CATALOG = os.path.join(ROOT, "loc", "en.json")
RE_STATE = re.compile(r"^[a-z]{2,3}(-[A-Za-z0-9]{2,4})?\.json$")

RE_CLASS = re.compile(r"^\s*(?:@:\w+(?:\([^)]*\))?\s*)*(?:private\s+|extern\s+)*"
                      r"(?:class|interface|enum|abstract|typedef)\s+(\w+)", re.M)
RE_FUNC = re.compile(r"^\s*(?:(?:public|private|static|override|inline|macro|dynamic|extern)\s+)*"
                     r"function\s+(\w+)", re.M)
RE_MEMBER = re.compile(r"^  (?:(?:public|private|static|inline)\s+)*var\s+(\w+)", re.M)
RE_FIELD = re.compile(r"(\w+)\s*(?::|=|\+=)\s*$")
RE_CALLEE = re.compile(r"([\w.]+)\s*\(\s*$")
RE_NOTE = re.compile(r"^\s*//\s*tr:\s*(.*)$")
ESC = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", "'": "'", '"': '"', "0": "\0"}


# --------------------------------------------------------------------------- lexer

def skip_ws(text: str, i: int) -> int:
    """Skip whitespace and comments."""
    n = len(text)
    while i < n:
        if text[i].isspace():
            i += 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j + 1
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
        else:
            break
    return i


def read_string(text: str, i: int) -> tuple:
    """Decode the string literal at i -> (value, index after it)."""
    q = text[i]
    i += 1
    out = []
    while i < len(text):
        c = text[i]
        if c == "\\":
            e = text[i + 1]
            if e == "x":
                out.append(chr(int(text[i + 2:i + 4], 16)))
                i += 4
            elif e == "u" and text[i + 2] == "{":
                j = text.index("}", i)
                out.append(chr(int(text[i + 3:j], 16)))
                i = j + 1
            elif e == "u":
                out.append(chr(int(text[i + 2:i + 6], 16)))
                i += 6
            else:
                out.append(ESC.get(e, e))
                i += 2
            continue
        if c == q:
            s = "".join(out)
            if q == "'":
                s = s.replace("$$", "$")
            return s, i + 1
        out.append(c)
        i += 1
    raise ValueError("unterminated string")


def scan(text: str, path: str) -> tuple:
    """All T()/N() literals in one source file -> (entries, warnings)."""
    lines = [0] + [m.end() for m in re.finditer("\n", text)]
    line_of = lambda p: bisect.bisect_right(lines, p)  # noqa: E731
    marks = sorted([(m.start(1), "class", m.group(1)) for m in RE_CLASS.finditer(text)] +
                   [(m.start(1), "member", m.group(1)) for m in RE_FUNC.finditer(text)] +
                   [(m.start(1), "member", m.group(1)) for m in RE_MEMBER.finditer(text)])
    src_lines = text.split("\n")
    entries, warnings = [], []
    i, n, prev_word = 0, len(text), ""
    while i < n:
        c = text[i]
        if text.startswith("//", i) or text.startswith("/*", i):
            i = skip_ws(text, i)
            continue
        if c in "'\"":
            try:
                _, i = read_string(text, i)
            except (ValueError, IndexError):
                i += 1
            continue
        if not (c.isalpha() or c == "_"):
            i += 1
            continue
        j = i
        while j < n and (text[j].isalnum() or text[j] == "_"):
            j += 1
        word = text[i:j]
        before = text[i - 1] if i > 0 else ""
        if word in ("T", "N") and before != "." and prev_word != "function":
            k = skip_ws(text, j)
            if k < n and text[k] == "(":
                ent, warn, j = call(text, k + 1, word, path, line_of(i))
                if ent:
                    ent.update(context(text, i, marks, src_lines, line_of(i)))
                    entries.append(ent)
                if warn:
                    warnings.append(warn)
        # a mod has no T() macro: it calls Loc.tr('…') with the literal (a variable argument is a
        # display-time translation, not a source string)
        elif word == "tr" and before == "." and prev_word == "Loc":
            k = skip_ws(text, j)
            if k < n and text[k] == "(" and skip_ws(text, k + 1) < n and text[skip_ws(text, k + 1)] in "'\"":
                ent, _, j = call(text, k + 1, "T", path, line_of(i))
                if ent:
                    ent.update(context(text, i, marks, src_lines, line_of(i)))
                    entries.append(ent)
        prev_word = word
        i = j
    return entries, warnings


def call(text: str, i: int, kind: str, path: str, line: int) -> tuple:
    """Read the literal argument of a T(/N( call -> (entry, warning, index)."""
    parts = []
    while True:
        i = skip_ws(text, i)
        if i >= len(text) or text[i] not in "'\"":
            return None, f"{path}:{line}: {kind}() argument is not a string literal", i
        s, i = read_string(text, i)
        parts.append(s)
        i = skip_ws(text, i)
        if i < len(text) and text[i] == "+":
            i += 1
            continue
        break
    s = "".join(parts)
    if not s.strip():
        return None, f"{path}:{line}: {kind}('') marks an empty string (nothing to translate)", i
    try:
        vars_ = locfmt.names(s)
    except locfmt.FmtError as e:
        return None, f"{path}:{line}: bad placeholder syntax ({e}): {s[:60]}", i
    return {"s": s, "kind": kind, "loc": [f"{path}:{line}"], "vars": vars_}, None, i


def context(text: str, pos: int, marks: list, src_lines: list, line: int) -> dict:
    """Class.member around pos, the field or call the literal goes into, a // tr: note above."""
    cls, member = "", ""
    for p, kind, name in marks:
        if p > pos:
            break
        if kind == "class":
            cls, member = name, ""
        else:
            member = name
    out = {"where": f"{cls}.{member}" if member else cls}
    head = text[max(0, pos - 160):pos]
    m = RE_FIELD.search(head) or RE_CALLEE.search(head)
    if m and m.group(1) not in ("return", "var", "case"):
        out["field"] = m.group(1).split(".")[-1]
    notes = []
    k = line - 2
    while k >= 0:
        nm = RE_NOTE.match(src_lines[k])
        if not nm:
            break
        notes.insert(0, nm.group(1).strip())
        k -= 1
    if notes:
        out["note"] = " ".join(notes)
    return out


# --------------------------------------------------------------------------- catalog

def build(root: str, rel_base: str) -> tuple:
    """Scan every .hx under root -> (catalog entries in source order, warnings)."""
    merged, warnings = {}, []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for f in sorted(filenames):
            if not f.endswith(".hx"):
                continue
            path = os.path.join(dirpath, f)
            rel = os.path.relpath(path, rel_base)
            with open(path, encoding="utf-8") as fh:
                ents, warns = scan(fh.read(), rel)
            warnings += warns
            for e in ents:
                old = merged.get(e["s"])
                if old:
                    old["loc"] += e["loc"]
                else:
                    merged[e["s"]] = e
    return list(merged.values()), warnings


def load_json(path: str):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


def write_catalog(entries: list) -> None:
    os.makedirs(os.path.dirname(CATALOG), exist_ok=True)
    tmp = CATALOG + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump({"strings": entries}, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    os.replace(tmp, CATALOG)


def spot(rec: dict) -> tuple:
    """Where a string sits, line numbers aside: file, member, field."""
    loc = (rec.get("loc") or [""])[0]
    return (loc.rsplit(":", 1)[0], rec.get("where", ""), rec.get("field", ""))


def delta(entries: list, state: dict) -> dict:
    """Catalog vs one language state: new (untranslated), changed (new at a spot whose old string
    was translated), removed (translated, no longer in the catalog)."""
    done = {k: r for k, r in (state.get("strings") or {}).items() if r.get("t")}
    keys = {locfmt.sha(e["s"]): e for e in entries}
    new = [e for k, e in keys.items() if k not in done]
    removed = [r for k, r in done.items() if k not in keys]
    gone = {spot(r) for r in removed}
    changed = [e for e in new if spot(e) in gone]
    return {"new": new, "changed": changed, "removed": removed}


def languages() -> list:
    d = os.path.dirname(CATALOG)
    if not os.path.isdir(d):
        return []
    return sorted(f[:-5] for f in os.listdir(d) if RE_STATE.match(f) and f != "en.json")


def check(entries: list, before: list | None, strict: bool, list_lang: str | None) -> int:
    parts = [f"loc: {len(entries)} strings"]
    if before is not None:
        a, b = {e["s"] for e in before}, {e["s"] for e in entries}
        if a != b:
            parts[0] += f" (+{len(b - a)} -{len(a - b)} since last build)"
    stale = False
    langs = languages()
    for code in langs:
        d = delta(entries, load_json(os.path.join(os.path.dirname(CATALOG), code + ".json")) or {})
        if d["new"] or d["removed"]:
            bits = []
            if d["new"]:
                bits.append(f"{len(d['new'])} new" + (f" ({len(d['changed'])} changed)" if d["changed"] else ""))
            if d["removed"]:
                bits.append(f"{len(d['removed'])} removed")
            parts.append(f"{code}: " + ", ".join(bits))
            stale = stale or bool(d["new"])
        else:
            parts.append(f"{code}: up to date")
        if strict and d["new"] and code != list_lang:
            for e in d["new"][:30]:
                print(f"  {code} untranslated  {e['loc'][0]}: {e['s'][:100]}")
            if len(d["new"]) > 30:
                print(f"  … and {len(d['new']) - 30} more (extract.py --list {code})")
        if code == list_lang:
            for e in d["new"]:
                print(f"  new  {e['loc'][0]}: {e['s'][:100]}")
            for r in d["removed"]:
                print(f"  gone {(r.get('loc') or ['?'])[0]}: {r['s'][:100]}")
    if not langs:
        parts.append("no translations yet")
    print(" · ".join(parts))
    return 1 if (strict and stale) else 0


# --------------------------------------------------------------------------- selftest

def selftest() -> None:
    src = r'''
class Foo
{
  public static var map = [
    X => {
      // tr: shown when the goal completes
      messageComplete: "Done \"now\".",
    },
  ];

// a comment with T('not this')
  public function new()
    {
      /* block T('nor this') */
      var s = "T('inside a string')";
      label.innerHTML = T('Hello ' +
        'world.');
      name = N('police officer');
      addOptToggle(T('Skip tutorial') + ' <b>', 'x');
      log(T('{s:The} pays $$5 for {n, plural, one{# item} other{# items}}.', { s: ai, n: 2 }));
      Loc.T('dotted');
      var bad = T(someVar);
    }

  public static macro function T(s: ExprOf<String>) {}
}
'''
    ents, warns = scan(src, "src/Foo.hx")
    got = {e["s"]: e for e in ents}
    assert set(got) == {"Hello world.", "police officer", "Skip tutorial",
                        "{s:The} pays $5 for {n, plural, one{# item} other{# items}}."}, set(got)
    assert got["Hello world."]["field"] == "innerHTML"
    assert got["Hello world."]["where"] == "Foo.new"
    assert got["Hello world."]["loc"] == ["src/Foo.hx:16"]
    assert got["police officer"]["kind"] == "N" and got["police officer"]["field"] == "name"
    assert got["Skip tutorial"]["field"] == "addOptToggle"
    pays = got["{s:The} pays $5 for {n, plural, one{# item} other{# items}}."]
    assert pays["vars"] == ["s", "n"] and pays["field"] == "log"
    assert len(warns) == 1 and "src/Foo.hx:22" in warns[0], warns
    note_src = 'class A\n{\n  var x = [\n    // tr: a note\n    // tr: second line\n    { name: N("Gun") },\n  ];\n}\n'
    ents, _ = scan(note_src, "a.hx")
    assert ents[0]["note"] == "a note second line" and ents[0]["where"] == "A.x", ents
    mod_src = "class M\n{\n  function f()\n    {\n      log(Loc.tr('Mod line.'));\n      x = Loc.tr(name);\n    }\n}\n"
    ents, warns = scan(mod_src, "mod.hx")
    assert [e["s"] for e in ents] == ["Mod line."] and not warns, (ents, warns)
    e1 = {"s": "A", "loc": ["f.hx:1"], "where": "C.m", "field": "name"}
    e2 = {"s": "B", "loc": ["f.hx:9"], "where": "C.m", "field": "name"}
    st = {"strings": {locfmt.sha("A0"): {"s": "A0", "t": "a", "loc": ["f.hx:1"], "where": "C.m",
                                          "field": "name"},
                      locfmt.sha("B"): {"s": "B", "t": "b"}}}
    d = delta([e1, e2], st)
    assert [e["s"] for e in d["new"]] == ["A"] and [e["s"] for e in d["changed"]] == ["A"]
    assert [r["s"] for r in d["removed"]] == ["A0"]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="print the delta line against each language")
    ap.add_argument("--strict", action="store_true", help="exit 1 if any language has untranslated strings")
    ap.add_argument("--list", metavar="CODE", help="list new/removed strings of one language")
    ap.add_argument("--root", help="scan another source tree (a mod) and print, do not write the catalog")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        locfmt.selftest()
        selftest()
        print("extract selftest: ok")
        return 0
    if a.root:
        entries, warnings = build(a.root, a.root)
        for w in warnings:
            print("loc: warning:", w, file=sys.stderr)
        json.dump({"strings": entries}, sys.stdout, ensure_ascii=False, indent=1)
        print()
        return 0
    before = (load_json(CATALOG) or {}).get("strings")
    entries, warnings = build(os.path.join(ROOT, "src"), ROOT)
    for w in warnings:
        print("loc: warning:", w, file=sys.stderr)
    write_catalog(entries)
    if a.check or a.strict or a.list:
        return check(entries, before, a.strict, a.list)
    print(f"loc: {len(entries)} strings -> {os.path.relpath(CATALOG, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
