#!/usr/bin/env python3
"""Translate the string catalog (loc/en.json) into one language with Claude, two passes.

The book pipeline in ../translate-agent did the hard part: the `claude -p` route on the Claude
subscription (no money, quota), the quota-aware retries, the reply contract with notes. That code is
copied here (chat_claude, parse_claude_json, run_cli, quota_wait_seconds, retry_at_seconds) and
trimmed to the one route. What differs from a book is the unit of work: a game string, not a block.
So state is per STRING (keyed by sha1 of the English), and batches are only transport — re-batching,
a new string or an edited one never re-translates the rest.

Each batch is a run of catalog entries from neighbouring source files (≤ BATCH_CHARS), every string
with its context line (file, Class.member, field, placeholders, // tr: note). Pass 1 translates
(loc/prompt.md + loc/style-<code>.md as the system prompt). Pass 2 revises against the same style
sheet (loc/revise.md) and returns only the strings it changes, which saves output — the quota is
eaten by output. Every translation must pass locfmt.check (placeholder names, html tags, entities,
%tokens%) and a length guard; failures go back with a nudge, up to ATTEMPTS times.

    python3 tools/loc/translate.py probe --lang fr [--batches 3] [--files cult/events,Pedia]
    python3 tools/loc/translate.py run --lang fr [--jobs 4]
    python3 tools/loc/translate.py build --lang fr        # -> electron/lang/fr.json
    python3 tools/loc/translate.py status --lang fr
    python3 tools/loc/translate.py selftest

(run from repo root; `make loc-probe`, `make loc`, `make loc-build` wrap it)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import signal
import subprocess
import sys
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fonts
import locfmt  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent.parent
LOC = ROOT / "loc"
LOGDIR = LOC / ".logs"
CATALOG = LOC / "en.json"
LANG_OUT = ROOT / "electron" / "lang"

MODEL = "claude-opus-5-5"     # the route is always the local `claude -p` (subscription)
EFFORT = "high"
PASSES = 2
TIMEOUT = 1800
BATCH_CHARS = 6000            # English characters per batch
BATCH_MAX = 80                # strings per batch
ATTEMPTS = 3                  # tries per batch until every string is in and valid
RATIO_MIN, RATIO_MAX = 0.3, 3.0
RATIO_MIN_CHARS = 16          # shorter strings skip the length guard
STATE_LOCK = threading.Lock()

NAMES = {"fr": "French", "de": "German", "es": "Spanish", "it": "Italian", "pl": "Polish",
         "pt-BR": "Brazilian Portuguese", "ru": "Russian", "uk": "Ukrainian", "tr": "Turkish",
         "zh-CN": "Simplified Chinese", "zh-TW": "Traditional Chinese", "ja": "Japanese", "ko": "Korean"}


def info(msg: str) -> None:
    print(time.strftime("%H:%M:%S"), msg, flush=True)


def warn(msg: str) -> None:
    print(time.strftime("%H:%M:%S"), "WARN", msg, flush=True)


# --------------------------------------------------------------------------- claude route
# copied from ../translate-agent/translate.py (claude-only, no session reuse: identical system
# prompts are cached across fresh sessions anyway)

RE_QUOTA = re.compile(r"rate.?limit|usage limit|quota|too many requests|429", re.I)
QUOTA_NEAR = 90.0          # percent: a window this full is the plausible culprit
QUOTA_MAX_WAIT = 6 * 3600  # never sit on a weekly window, only the short one
QUOTA_PROBE = 600          # re-probe the quota this often instead of sleeping it out
RE_RETRY_AT = re.compile(r"try again at (\d{1,2}):(\d{2})\s*(am|pm)?", re.I)
RETRY_AT_GRACE = 1800


def run_cli(cmd: list, prompt: str, timeout: float, cwd: str | None = None) -> subprocess.CompletedProcess:
    """subprocess.run whose timeout kills the whole process tree (claude is a node wrapper over a
    native binary; killing only the wrapper leaves the binary finishing — and billing — the call)."""
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, text=True, cwd=cwd, start_new_session=True)
    try:
        out, err = p.communicate(prompt, timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        p.communicate()
        raise
    return subprocess.CompletedProcess(cmd, p.returncode, out, err)


def parse_claude_json(stdout: str) -> dict:
    """Text, usage, limits out of `claude -p --output-format json` (a JSON array of events).
    Anthropic counts input_tokens WITHOUT the cached part, so the prompt total is
    input + cache_read + cache_creation."""
    out = {"text": "", "usage": {}, "limits": None, "error": ""}
    try:
        events = json.loads(stdout)
    except (json.JSONDecodeError, TypeError):
        return out
    if isinstance(events, dict):
        events = [events]
    for ev in events if isinstance(events, list) else []:
        if not isinstance(ev, dict):
            continue
        if ev.get("type") == "rate_limit_event":
            w = (ev.get("rate_limit_info") or {}).get("unifiedWindows") or {}
            prev = out["limits"] or {}
            lim = {}
            for name, key_, mins in (("five_hour", "primary", 300), ("seven_day", "secondary", 10080)):
                win = w.get(name)
                lim[key_] = ({"used_percent": float(win.get("utilization") or 0) * 100,
                              "resets_at": win.get("resetsAt") or 0, "window_minutes": mins}
                             if isinstance(win, dict) else prev.get(key_))
            out["limits"] = lim
        if ev.get("type") != "result":
            continue
        text = ev.get("result") or ""
        if ev.get("is_error"):
            errs = ev.get("errors")
            if not text and errs:
                text = json.dumps(errs, ensure_ascii=False)
            out["error"] = f"{ev.get('subtype') or 'error'}: {text}"[:600]
        else:
            out["text"] = text
        u = ev.get("usage") or {}
        cached = int(u.get("cache_read_input_tokens") or 0)
        created = int(u.get("cache_creation_input_tokens") or 0)
        out["usage"] = {
            "input": int(u.get("input_tokens") or 0) + cached + created,
            "cached": cached,
            "output": int(u.get("output_tokens") or 0),
        }
    return out


def retry_at_seconds(err: str, now: float | None = None) -> float:
    """Seconds until the wall-clock reset a refusal names ("try again at 9:02"), else 0."""
    m = RE_RETRY_AT.search(err)
    if not m:
        return 0.0
    hour, mer = int(m.group(1)), (m.group(3) or "").lower()
    if mer:
        hour = hour % 12 + (12 if mer == "pm" else 0)
    now = time.time() if now is None else now
    lt = time.localtime(now)
    target = time.mktime((lt.tm_year, lt.tm_mon, lt.tm_mday, hour, int(m.group(2)), 0, 0, 0, -1))
    if now - RETRY_AT_GRACE < target <= now:
        return 0.0
    if target <= now:
        target += 24 * 3600
    return target - now


def quota_wait_seconds(limits: dict | None, err: str, now: float | None = None,
                       concurrent: bool = False) -> float:
    """Seconds to wait for a spent window, or 0 for a real failure. With several workers the
    error text stops being a signal (a session cap reads like a spent window): only a window that
    actually reads full counts then."""
    now = time.time() if now is None else now
    named = bool(RE_QUOTA.search(err or "")) and not concurrent
    soonest = 0.0
    for kind in ("primary", "secondary"):
        w = (limits or {}).get(kind)
        if not isinstance(w, dict):
            continue
        left = (w.get("resets_at") or 0) - now
        if left <= 0 or left > QUOTA_MAX_WAIT:
            continue
        if not named and (w.get("used_percent") or 0) < QUOTA_NEAR:
            continue
        if not soonest or left < soonest:
            soonest = left
    return soonest


class CliError(RuntimeError):
    def __init__(self, msg: str, limits: dict | None):
        super().__init__(msg)
        self.limits = limits


def claude_cwd() -> Path:
    """Empty working dir: no CLAUDE.md gets auto-loaded into the translator."""
    d = LOC / ".cache" / "claude-cwd"
    d.mkdir(parents=True, exist_ok=True)
    return d


def chat_claude(system: str, user: str, log_name: str) -> dict:
    """One call through `claude -p`: no tools, no settings, no MCP. --bare is off the table: it
    disables OAuth, and OAuth is the subscription. The system prompt goes by file (argv limit)."""
    sys_file = LOC / ".cache" / f"sys-{os.getpid()}-{threading.get_ident()}.md"
    sys_file.parent.mkdir(parents=True, exist_ok=True)
    sys_file.write_text(system, encoding="utf-8")
    last, limits = "", None
    for attempt in range(1, 4):
        cmd = ["claude", "-p", "--output-format", "json", "--model", MODEL, "--effort", EFFORT,
               "--tools", "", "--setting-sources", "", "--strict-mcp-config",
               "--system-prompt-file", str(sys_file), "--session-id", str(uuid.uuid4())]
        try:
            r = run_cli(cmd, user, TIMEOUT, cwd=str(claude_cwd()))
        except subprocess.TimeoutExpired:
            last = f"claude -p gave no answer in {TIMEOUT}s"
        else:
            parsed = parse_claude_json(r.stdout)
            limits = parsed["limits"] or limits
            LOGDIR.mkdir(parents=True, exist_ok=True)
            with (LOGDIR / log_name).open("a", encoding="utf-8") as fh:
                fh.write(json.dumps({"t": time.time(), "user": user, "reply": parsed["text"],
                                     "usage": parsed["usage"], "error": parsed["error"]},
                                    ensure_ascii=False) + "\n")
            if r.returncode == 0 and parsed["text"].strip() and not parsed["error"]:
                return parsed
            last = f"code {r.returncode}, " + (parsed["error"] or r.stderr or r.stdout or "empty")[-600:]
        wait = min(2 ** attempt, 30)
        warn(f"claude attempt {attempt}/3 failed ({last}); retry in {wait}s")
        time.sleep(wait)
    raise CliError(f"claude -p failed 3 times: {last}", limits)


def call_with_quota(system: str, user: str, log_name: str, concurrent: bool) -> dict:
    """chat_claude, sleeping out a spent quota window (probing every QUOTA_PROBE seconds)."""
    while True:
        try:
            return chat_claude(system, user, log_name)
        except CliError as e:
            wait = retry_at_seconds(str(e)) or quota_wait_seconds(e.limits, str(e), concurrent=concurrent)
            if not wait:
                raise
            info(f"quota spent, waiting {int(min(wait, QUOTA_PROBE) // 60)} min")
            time.sleep(min(wait, QUOTA_PROBE))


# --------------------------------------------------------------------------- state

def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default


def save_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def state_path(code: str) -> Path:
    return LOC / f"{code}.json"


def load_state(code: str) -> dict:
    st = load_json(state_path(code), {})
    st.setdefault("strings", {})
    st.setdefault("totals", {"calls": 0, "input": 0, "output": 0})
    return st


def catalog() -> list:
    cat = load_json(CATALOG, None)
    if cat is None:
        sys.exit("no loc/en.json — run `make -C src` (or tools/loc/extract.py) first")
    return cat["strings"]


# --------------------------------------------------------------------------- batches

def batches(entries: list) -> list:
    """Greedy runs of entries in catalog (= source) order; a new file starts a new batch once the
    current one is half full, so a batch reads as one or two neighbouring files."""
    out, cur, chars, file = [], [], 0, None
    for e in entries:
        f = e["loc"][0].rsplit(":", 1)[0]
        size = len(e["s"])
        if cur and (chars + size > BATCH_CHARS or len(cur) >= BATCH_MAX or
                    (f != file and chars > BATCH_CHARS // 2)):
            out.append(cur)
            cur, chars = [], 0
        cur.append(e)
        chars += size
        file = f
    if cur:
        out.append(cur)
    return out


def ctx_line(i: int, e: dict) -> str:
    bits = [e["loc"][0] + (f" (+{len(e['loc']) - 1} more)" if len(e["loc"]) > 1 else ""), e.get("where", "")]
    if e.get("field"):
        bits.append("in " + e["field"])
    if e.get("vars"):
        bits.append("vars: " + ", ".join(e["vars"]))
    if e.get("kind") == "N":
        bits.append("stored name (shown alone or inside other strings)")
    if e.get("note"):
        bits.append("note: " + e["note"])
    return f"[{i}] " + " · ".join(b for b in bits if b)


def build_user(batch: list, bno: int, total: int, nudge: str) -> str:
    files = sorted({e["loc"][0].rsplit(":", 1)[0] for e in batch})
    parts = [f"## Batch {bno} of {total} — {', '.join(files)}",
             "Translate every string. Context line first, then the string in <s id=\"N\">…</s>."]
    for i, e in enumerate(batch, 1):
        parts.append(ctx_line(i, e) + "\n" + f'<s id="{i}">{e["s"]}</s>')
    if nudge:
        parts.append(nudge)
    return "\n\n".join(parts)


def build_revise_user(batch: list, recs: list, bno: int, total: int, nudge: str) -> str:
    parts = [f"## Batch {bno} of {total} — revise",
             "Each item: context line, the English source, the current translation. Output only the "
             "translations you change, as <s id=\"N\">…</s>; output nothing for a string you keep."]
    for i, (e, r) in enumerate(zip(batch, recs), 1):
        parts.append(ctx_line(i, e) + "\n" + f"<en>{e['s']}</en>\n" + f'<s id="{i}">{r["t"]}</s>')
    if nudge:
        parts.append(nudge)
    return "\n\n".join(parts)


RE_S = re.compile(r'<s id="(\d+)">(.*?)</s>', re.S)
RE_NOTES = re.compile(r"<notes>(.*?)</notes>", re.S)


def parse_reply(text: str) -> tuple:
    """Reply -> ({id: text}, [doubt lines], [term lines])."""
    got = {}
    for m in RE_S.finditer(text):
        got.setdefault(int(m.group(1)), m.group(2).strip())
    doubts, terms = [], []
    nm = RE_NOTES.search(text)
    for line in (nm.group(1) if nm else "").splitlines():
        s = line.strip().lstrip("-*• ").strip()
        if s.startswith("[DOUBT]"):
            doubts.append(s[7:].strip())
        elif s.startswith("[TERM]"):
            terms.append(s[6:].strip())
    return got, doubts, terms


def problem(src: str, tr: str) -> str | None:
    """Why a translation is rejected, or None."""
    if not tr.strip():
        return "empty"
    bad = locfmt.check(src, tr)
    if bad:
        return bad
    if re.search(r"\{\w+:[Tt]he\}", tr):
        return "English noun form {x:the}/{x:The} in the translation: use the forms of the style sheet"
    if starts_upper(src) and not starts_upper(tr):
        return "starts lowercase: the English starts with a capital (or a capitalized {x:Form}); a log line that starts lowercase is taken for a 1.0 mod predicate"
    if len(src) >= RATIO_MIN_CHARS:
        ratio = len(tr) / len(src)
        if not RATIO_MIN <= ratio <= RATIO_MAX:
            return f"length ratio {ratio:.2f} outside {RATIO_MIN}-{RATIO_MAX}"
    return None


RE_LEAD = re.compile(r"(?:<[^>]*>|\s|[«\"(\[])*")


def starts_upper(s: str) -> bool:
    """Does the visible text start with a capital: a capital letter, or a placeholder with a
    capitalized form ({x:The}, {x:Def}); leading tags, spaces and opening quotes skipped."""
    s = s[RE_LEAD.match(s).end():]
    m = re.match(r"\{\w+:(\w)", s)
    if m:
        return m.group(1).isupper()
    return bool(s) and s[0].isupper()


def doubt_for(doubts: list, i: int) -> str:
    for d in doubts:
        head, _, why = d.partition("|")
        if head.strip() == str(i):
            return why.strip()
    return ""


def translate_batch(code: str, system: str, batch: list, bno: int, total: int,
                    concurrent: bool) -> dict:
    """Pass 1 for one batch -> {sha: record}; strings that never validate come back as failed."""
    want = set(range(1, len(batch) + 1))
    good, reasons, doubts, terms, nudge = {}, {}, [], [], ""
    for attempt in range(1, ATTEMPTS + 1):
        data = call_with_quota(system, build_user(batch, bno, total, nudge), f"{code}.jsonl", concurrent)
        tally(code, data["usage"])
        got, d, t = parse_reply(data["text"])
        doubts += d
        terms += t
        for i in want - set(good):
            if i not in got:
                reasons[i] = "missing"
                continue
            why = problem(batch[i - 1]["s"], got[i])
            if why:
                reasons[i] = why
            else:
                good[i] = got[i]
                reasons.pop(i, None)
        if len(good) == len(want):
            break
        warn(f"batch {bno}: {len(want) - len(good)} of {len(want)} strings rejected, attempt {attempt}/{ATTEMPTS}")
        nudge = ("IMPORTANT — these strings were missing or rejected in your last answer. Output ONLY "
                 "them, same format:\n" + "\n".join(f'- [{i}] {reasons[i]}' for i in sorted(reasons)))
    out = {}
    for i, e in enumerate(batch, 1):
        rec = base_record(e)
        if i in good:
            rec.update(t=good[i], status="done", passes=[{"pass": 1, "t": good[i]}])
        else:
            rec.update(status="failed", reason=reasons.get(i, "?"))
        dbt = doubt_for(doubts, i)
        if dbt:
            rec["doubt"] = dbt
        out[locfmt.sha(e["s"])] = rec
    if terms:
        with STATE_LOCK:
            note_terms(code, terms)
    return out


def revise_batch(code: str, system: str, batch: list, recs: list, bno: int, total: int,
                 concurrent: bool) -> list:
    """Pass 2 for one batch -> records with the changes applied (invalid changes are dropped)."""
    data = call_with_quota(system, build_revise_user(batch, recs, bno, total, ""), f"{code}.jsonl", concurrent)
    tally(code, data["usage"])
    got, doubts, terms = parse_reply(data["text"])
    out = []
    for i, (e, r) in enumerate(zip(batch, recs), 1):
        r = dict(r)
        new = got.get(i)
        if new is not None and new != r["t"]:
            why = problem(e["s"], new)
            if why:
                warn(f"batch {bno}: revision of [{i}] dropped ({why})")
                new = None
        changed = new is not None and new != r["t"]
        if changed:
            r["t"] = new
        r["passes"] = r.get("passes", [])[:1] + [{"pass": 2, "t": new if changed else None}]
        dbt = doubt_for(doubts, i)
        if dbt:
            r["doubt"] = dbt
        out.append(r)
    if terms:
        with STATE_LOCK:
            note_terms(code, terms)
    return out


def base_record(e: dict) -> dict:
    return {k: e[k] for k in ("s", "loc", "where", "field", "vars", "kind", "note") if e.get(k)}


def tally(code: str, usage: dict) -> None:
    with STATE_LOCK:
        TOTALS[code]["calls"] += 1
        TOTALS[code]["input"] += usage.get("input", 0)
        TOTALS[code]["output"] += usage.get("output", 0)


TOTALS: dict = {}


def note_terms(code: str, terms: list) -> None:
    """Glossary SUGGESTIONS from the model: listed for review, never fed back automatically (in the
    book pipeline an auto-glossary in the state overrode the hand-written reference)."""
    p = LOC / ".logs" / f"{code}-terms.txt"
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as fh:
        for t in terms:
            fh.write(t + "\n")


# --------------------------------------------------------------------------- runs

def system_prompt(code: str, kind: str) -> str:
    style = LOC / f"style-{code}.md"
    if not style.exists():
        sys.exit(f"no {style.relative_to(ROOT)} — write the style sheet first")
    base = (LOC / ("prompt.md" if kind == "translate" else "revise.md")).read_text(encoding="utf-8")
    base = base.replace("{LANG}", NAMES.get(code, code)).replace("{CODE}", code)
    return base.rstrip() + "\n\n" + style.read_text(encoding="utf-8").strip() + "\n"


def pending(code: str, st: dict, entries: list) -> tuple:
    """(entries needing pass 1, entries needing pass 2) — reviewed strings are locked."""
    p1, p2 = [], []
    for e in entries:
        r = st["strings"].get(locfmt.sha(e["s"]))
        if r is None or r.get("status") == "failed":
            p1.append(e)
        elif r.get("status") == "done" and len(r.get("passes", [])) < PASSES:
            p2.append(e)
    return p1, p2


def run(code: str, limit: int | None, files: list | None, jobs: int) -> int:
    entries = catalog()
    if files:
        entries = [e for e in entries if any(f in e["loc"][0] for f in files)]
    st = load_state(code)
    TOTALS[code] = st["totals"]
    p1, p2 = pending(code, st, entries)
    b1 = batches(p1)
    if limit is not None:
        b1 = spread(b1, limit)
        keep = {locfmt.sha(e["s"]) for b in b1 for e in b}
        p2 = [e for e in p2 if locfmt.sha(e["s"]) in keep]
    info(f"{code}: {len(p1)} strings to translate in {len(b1)} batches, model {MODEL} {EFFORT}, "
         f"{PASSES} passes, {jobs} jobs")
    sys1 = system_prompt(code, "translate")

    def do1(args):
        bno, b = args
        t0 = time.time()
        recs = translate_batch(code, sys1, b, bno, len(b1), jobs > 1)
        with STATE_LOCK:
            st["strings"].update(recs)
            save_json(state_path(code), st)
        bad = sum(1 for r in recs.values() if r["status"] != "done")
        info(f"batch {bno}/{len(b1)}: {len(b) - bad}/{len(b)} done in {time.time() - t0:.0f}s"
             + (f", {bad} failed" if bad else ""))

    with ThreadPoolExecutor(max_workers=jobs) as ex:
        list(ex.map(do1, enumerate(b1, 1)))

    if PASSES >= 2:
        _, p2 = pending(code, st, entries if limit is None else [e for b in b1 for e in b] + p2)
        b2 = batches(p2)
        info(f"{code}: revising {len(p2)} strings in {len(b2)} batches")
        sys2 = system_prompt(code, "revise")

        def do2(args):
            bno, b = args
            keys = [locfmt.sha(e["s"]) for e in b]
            recs = revise_batch(code, sys2, b, [st["strings"][k] for k in keys], bno, len(b2), jobs > 1)
            changed = sum(1 for r in recs if r["passes"][-1]["t"] is not None)
            with STATE_LOCK:
                for k, r in zip(keys, recs):
                    st["strings"][k] = r
                save_json(state_path(code), st)
            info(f"revise {bno}/{len(b2)}: {changed}/{len(b)} changed")

        with ThreadPoolExecutor(max_workers=jobs) as ex:
            list(ex.map(do2, enumerate(b2, 1)))

    build(code)
    t = st["totals"]
    info(f"{code}: {t['calls']} calls total, in {t['input'] // 1000}k / out {t['output'] // 1000}k tokens")
    return 0


def spread(bs: list, n: int) -> list:
    """n batches spread over the list (first, middle, last …) so a probe samples different files."""
    if n >= len(bs):
        return bs
    if n == 1:
        return bs[:1]
    return [bs[round(i * (len(bs) - 1) / (n - 1))] for i in range(n)]


# --------------------------------------------------------------------------- human review

REVIEW_COLS = ["id", "context", "en", "tr", "doubt", "fix"]


def cell(s: str) -> str:
    """One TSV cell: tabs and newlines escaped (\\t \\n), so a row stays one line."""
    return (s or "").replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n")


def uncell(s: str) -> str:
    return re.sub(r"\\(.)", lambda m: {"t": "\t", "n": "\n"}.get(m.group(1), m.group(1)), s)


def review(code: str) -> int:
    """loc/review/<code>.tsv: every current string, those with a model doubt first. Write a
    correction in the `fix` column and run apply-review. UTF-8 with a BOM, so Excel reads the accents."""
    st = load_state(code)
    rows = []
    for e in catalog():
        k = locfmt.sha(e["s"])
        r = st["strings"].get(k)
        if not r or not r.get("t"):
            continue
        ctx = " · ".join(x for x in [e["loc"][0], e.get("where"), e.get("field") and "in " + e["field"],
                                       e.get("note") and "note: " + e["note"]] if x)
        rows.append((0 if r.get("doubt") else 1, e["loc"][0], [k, ctx, e["s"], r["t"], r.get("doubt", ""), ""]))
    rows.sort(key=lambda x: (x[0], x[1]))
    out = LOC / "review" / f"{code}.tsv"
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8-sig", newline="") as fh:
        fh.write("\t".join(REVIEW_COLS) + "\n")
        for _, _, cols in rows:
            fh.write("\t".join(cell(c) for c in cols) + "\n")
    info(f"review: {len(rows)} strings ({sum(1 for r in rows if r[0] == 0)} with doubts) -> {out.relative_to(ROOT)}")
    return 0


def apply_review(code: str, path: str | None) -> int:
    """Import the `fix` column of a review sheet: each fix must pass the same checks as a model
    translation; accepted ones become `reviewed`, which no re-run touches until the English changes."""
    src = Path(path) if path else LOC / "review" / f"{code}.tsv"
    st = load_state(code)
    ok = bad = 0
    lines = src.read_text(encoding="utf-8-sig").splitlines()
    head = lines[0].split("\t")
    for ln, line in enumerate(lines[1:], 2):
        row = dict(zip(head, line.split("\t")))
        fix = uncell(row.get("fix", "")).strip()
        if not fix:
            continue
        r = st["strings"].get(row.get("id", ""))
        if r is None:
            warn(f"line {ln}: unknown id (the English changed since the sheet was written?)")
            bad += 1
            continue
        why = problem(r["s"], fix)
        if why:
            warn(f"line {ln}: rejected ({why}): {fix[:80]}")
            bad += 1
            continue
        r["t"], r["status"] = fix, "reviewed"
        r.pop("doubt", None)
        ok += 1
    save_json(state_path(code), st)
    info(f"apply-review: {ok} applied, {bad} rejected")
    build(code)
    return 1 if bad else 0


# --------------------------------------------------------------------------- noun table

RE_NOUN_KEY = re.compile(r"[a-z][a-z' -]*")
RE_NOUN = re.compile(r'<n id="(\d+)"([^>]*)>([^<]+)</n>')
RE_ATTR = re.compile(r'(\w+)="([^"]*)"')


def noun_keys(entries: list) -> list:
    """Catalog entries that can be a {x:form} noun: short lowercase N() names (creatures, items,
    objects, effects, jobs). Over-inclusive on purpose: an unused entry costs nothing, a missing one
    makes the game fall back to a bare masculine noun (and loses the feminine job titles)."""
    return [e for e in entries
            if e.get("kind") == "N" and len(e["s"].split()) <= 4 and RE_NOUN_KEY.fullmatch(e["s"])]


def parse_nouns(text: str, batch: list) -> dict:
    """<n id=.. g=.. fs=.. elide=..>noun</n> lines -> {english: {g, s, fs?, elide?}}."""
    out = {}
    for m in RE_NOUN.finditer(text):
        i = int(m.group(1))
        if not 1 <= i <= len(batch):
            continue
        a = dict(RE_ATTR.findall(m.group(2)))
        if a.get("g") not in ("m", "f"):
            continue
        r = {"g": a["g"], "s": m.group(3).strip()}
        if a.get("fs"):
            r["fs"] = a["fs"]
        if a.get("elide") == "0":
            r["elide"] = False
        out[batch[i - 1]["s"]] = r
    return out


def nouns(code: str) -> int:
    """Fill loc/nouns-<code>.json (the runtime noun table, reviewed by hand) for every noun key
    it lacks; the interface translation of the key, when there is one, is passed so both agree."""
    path = LOC / f"nouns-{code}.json"
    table = load_json(path, {})
    st = load_state(code)
    TOTALS[code] = st["totals"]
    todo = [e for e in noun_keys(catalog()) if e["s"] not in table]
    info(f"{code}: {len(todo)} nouns to add ({len(table)} in the table)")
    style = (LOC / f"style-{code}.md").read_text(encoding="utf-8")
    system = (LOC / "nouns.md").read_text(encoding="utf-8").replace("{LANG}", NAMES.get(code, code))
    system = system.rstrip() + "\n\n" + style.strip() + "\n"
    for b0 in range(0, len(todo), 120):
        batch = todo[b0:b0 + 120]
        lines = []
        for i, e in enumerate(batch, 1):
            r = st["strings"].get(locfmt.sha(e["s"]))
            ui = f" · ui: {r['t']}" if r and r.get("t") else ""
            lines.append(f'{i}. {e["s"]} · ctx: {e["loc"][0]}{ui}')
        res = call_with_quota(system, "\n".join(lines), f"{code}-nouns.jsonl", False)
        tally(code, res["usage"])
        got = parse_nouns(res["text"], batch)
        table.update(got)
        save_json(path, dict(sorted(table.items())))
        info(f"nouns {b0 // 120 + 1}: {len(got)}/{len(batch)}")
    save_json(state_path(code), st)
    build(code)
    return 0


RE_FR_SPACE = re.compile(r" ([:;!?»])")
RE_FR_APOS = re.compile(r"(?<=\w)'(?=\w)")


def typo(code: str, s: str) -> str:
    """Deterministic typography the model is not trusted with: French non-breaking spaces before
    : ; ! ? » and after «, typographic apostrophes (only where a space or a letter pair already is)."""
    if code == "fr":
        s = RE_FR_SPACE.sub("\u00a0\\1", s).replace("« ", "«\u00a0")
        s = RE_FR_APOS.sub("’", s)
    return s


def build(code: str) -> None:
    """Runtime table electron/lang/<code>.json from the state (+ loc/nouns-<code>.json)."""
    st = load_state(code)
    strings = {r["s"]: typo(code, r["t"]) for r in st["strings"].values()
               if r.get("t") and r.get("status") in ("done", "reviewed")}
    out = {"strings": dict(sorted(strings.items()))}
    nouns = load_json(LOC / f"nouns-{code}.json", None)
    if nouns:
        out["nouns"] = nouns
    LANG_OUT.mkdir(parents=True, exist_ok=True)
    save_json(LANG_OUT / f"{code}.json", out)
    info(f"build: {len(strings)} strings -> {(LANG_OUT / (code + '.json')).relative_to(ROOT)}")
    fonts.apply(code)


def status(code: str) -> int:
    entries = catalog()
    st = load_state(code)
    keys = {locfmt.sha(e["s"]) for e in entries}
    recs = [st["strings"][k] for k in keys if k in st["strings"]]
    by = {}
    for r in recs:
        by[r.get("status")] = by.get(r.get("status"), 0) + 1
    two = sum(1 for r in recs if len(r.get("passes", [])) >= 2)
    print(f"{code}: {len(entries)} strings · " + " · ".join(f"{k} {v}" for k, v in sorted(by.items()))
          + f" · untranslated {len(entries) - len(recs)} · revised {two}")
    return 0


# --------------------------------------------------------------------------- selftest

def selftest() -> int:
    locfmt.selftest()
    got, doubts, terms = parse_reply('<s id="1">Bonjour.</s>\n<s id="2">Deux\nlignes</s>\n'
                                     "<notes>\n- [DOUBT] 2 | ambiguous\n- [TERM] host = hôte\n</notes>")
    assert got == {1: "Bonjour.", 2: "Deux\nlignes"}, got
    assert doubt_for(doubts, 2) == "ambiguous" and terms == ["host = hôte"]
    assert problem("{s:The} hits.", "{s:Def} frappe.") is None
    assert problem("{s} hits {t}.", "{s} frappe.").startswith("missing")
    assert problem("A fairly long English sentence here.", "Ok.").startswith("length")
    assert problem("Hi", "") == "empty"
    assert problem("{s:The} hits.", "{s:def} frappe.").startswith("starts lowercase")
    assert problem("<b>Yes</b>", "<b>oui</b>").startswith("starts lowercase")
    assert problem("{n} turns", "{n} tours") is None and starts_upper("« Oui")
    assert problem("{s:The} hits.", "{s:The} frappe.").startswith("English noun form")
    es = [{"s": "x" * 100, "loc": [f"src/a.hx:{i}"]} for i in range(10)] + \
         [{"s": "y" * 100, "loc": [f"src/b.hx:{i}"]} for i in range(10)]
    bs = batches(es)
    assert len(bs) == 1 and len(bs[0]) == 20
    es = [{"s": "x" * 4000, "loc": ["src/a.hx:1"]}, {"s": "y" * 100, "loc": ["src/b.hx:1"]}]
    assert [len(b) for b in batches(es)] == [1, 1]
    assert spread(list(range(10)), 3) == [0, 4, 9] or spread(list(range(10)), 3) == [0, 5, 9]
    u = build_user([{"s": "Hi {n}", "loc": ["src/a.hx:3"], "where": "A.b", "field": "label",
                     "vars": ["n"], "kind": "T"}], 1, 1, "")
    assert '<s id="1">Hi {n}</s>' in u and "vars: n" in u and "in label" in u
    got = parse_nouns('<n id="1" g="f" fs="x">policière</n>\n<n id="2" g="m" elide="0">hibou</n>'
                      '<n id="3" g="q">bad</n>', [{"s": "officer"}, {"s": "owl"}, {"s": "z"}])
    assert got == {"officer": {"g": "f", "s": "policière", "fs": "x"},
                   "owl": {"g": "m", "s": "hibou", "elide": False}}, got
    ks = [e["s"] for e in noun_keys([{"s": "dog", "kind": "N", "loc": ["src/ai/DogAI.hx:1"]},

                                     {"s": "Dog", "kind": "N", "loc": ["src/ai/DogAI.hx:2"]},
                                     {"s": "dog", "kind": "T", "loc": ["src/ai/DogAI.hx:3"]}])]
    assert ks == ["dog"], ks
    for raw in ["a\tb", "x\ny", "back\\slash \\n", ""]:
        assert uncell(cell(raw)) == raw and "\t" not in cell(raw) and "\n" not in cell(raw), raw
    assert typo("fr", "Attention ! « Oui » : l'agent") == "Attention\u00a0! «\u00a0Oui\u00a0»\u00a0: l’agent"
    assert typo("fr", "<span class='x'>a</span> &rarr; {s:def}") == "<span class='x'>a</span> &rarr; {s:def}"
    print("translate selftest: ok")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("cmd", choices=["probe", "run", "build", "status", "nouns", "review", "apply-review", "selftest"])
    ap.add_argument("--sheet", help="apply-review: the TSV to import (default loc/review/<lang>.tsv)")
    ap.add_argument("--lang", default="fr")
    ap.add_argument("--batches", type=int, default=3, help="probe: how many batches")
    ap.add_argument("--files", help="comma-separated path fragments to restrict the catalog")
    ap.add_argument("--jobs", type=int, default=1)
    a = ap.parse_args()
    if a.cmd == "selftest":
        return selftest()
    if a.cmd == "build":
        build(a.lang)
        return 0
    if a.cmd == "status":
        return status(a.lang)
    if a.cmd == "nouns":
        return nouns(a.lang)
    if a.cmd == "review":
        return review(a.lang)
    if a.cmd == "apply-review":
        return apply_review(a.lang, a.sheet)
    files = a.files.split(",") if a.files else None
    return run(a.lang, a.batches if a.cmd == "probe" else None, files, a.jobs)


if __name__ == "__main__":
    sys.exit(main())
