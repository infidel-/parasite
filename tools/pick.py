#!/usr/bin/env python3
"""The pick page: one local HTML page for a round of visual choices, opened in Chrome's main profile.

    python3 tools/pick.py SPEC.json [--no-open]

SPEC (paths relative to the spec's folder):
    {"title": "...", "tests": [{"name": "dockside", "note": "what to look for",
                                "files": [{"src": "a.png", "label": "2.5", "note": "..."}]}]}
    An option whose src ends in .wav or .mp3 is a sound: an audio player that plays when the option is shown.

Writes <spec dir>/pick.html (ported from nullstone's tools/pick.py, 2026-11-26: "redo html preview like we do in
other projects"; parasite has no scene panel, so every image shows whole, no crop). Every image shows at 50% or
100% of its pixels (screen pixels, its CSS width divided by
devicePixelRatio; 50% by default, Z or the bar's buttons switch), never scaled up, never fitted to the window
(the user, 2026-11-09: "100% is still too much"). Per section: keys 1-9 or a click flip the options,
F shows the whole frame, and one choice is either an option or the section's own text (each clears the
other). Every change copies all the choices to the clipboard, one line per section, to paste back, a saved mask
named on its section's line (the user, 2026-11-13: it read "no choice" after SAVE MASK). The
same shape as reaper-control's A/B page (the user, 2026-11-07).

M (any keyboard layout: keys go by e.code) or a section's PAINT MASK button paints a MASK on its whole frame (the user, 2026-11-11: "update the preview code so that i can
paint the masks right there with a brush"): drag paints, right-drag erases, [ ] size the brush, C clears. SAVE MASK
downloads mask-<section>-<time>.png to Chrome's download folder (here C:\1: `download.default_directory` in the Default
profile's Preferences) at the source's own size, transparent where
painted: the API mask for an edit of that image as it stands, and the area `tools/patch.py paste` takes back. The
painting survives a reload (localStorage).
"""
import json
import subprocess
import sys
from pathlib import Path

from env import path

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"


PAGE = r"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>%TITLE%</title>
<style>
body{background:#111;color:#ddd;font:15px/1.4 monospace;margin:16px 16px 60px}
h1{color:#fc6;font-size:20px;margin:0 0 4px}
section{margin:22px 0;padding:10px;border:1px solid #333}
section.on{border-color:#6a85a8}
h2{color:#fc6;margin:0 0 4px;font-size:17px}
.note{color:#9aa;margin:0 0 8px}
.opts{display:flex;gap:6px;flex-wrap:wrap;margin:6px 0}
.opt{padding:4px 10px;border:1px solid #555;cursor:pointer;user-select:none}
.opt.show{background:#2a3b55;border-color:#9cf}
.opt.pick{outline:2px solid #3fe04f}
.opt i{color:#9aa;font-style:normal}
section{overflow-x:auto}
img{display:block;image-rendering:pixelated;cursor:pointer}
.stage{position:relative;display:inline-block}
.stage canvas{position:absolute;left:0;top:0;opacity:.45;cursor:crosshair;display:none}
.ring{position:absolute;border:1px solid #fff;border-radius:50%;pointer-events:none;display:none;box-shadow:0 0 0 1px #000}
section.painting{border-color:#f55}
section.painting .stage canvas,section.painting .ring{display:block}
.paint{color:#f99}
.half img{image-rendering:auto}
#bar button.on{background:#2a3b55;color:#fff}
section>p>input{width:60%;background:#000;color:#ddd;border:1px solid #555;font:inherit;padding:3px}
#bar{position:fixed;left:0;right:0;bottom:0;background:#000;border-top:1px solid #333;padding:8px 16px}
#status{color:#3fe04f;margin-left:12px}
</style></head><body>
<h1>%TITLE%</h1>
<p class="note">Each option is shown whole at 50% or 100% of its pixels (Z switches), never scaled up. Hover a section:
keys 1-9 flip its options, F toggles the whole frame. Click an option's label to show it, and its PICK box to choose
it, or type into the section's box instead (reroll notes). Every change copies all the choices to the clipboard.
M (or PAINT MASK) paints a mask on the whole frame: drag paints, right-drag erases, [ ] brush size, C clears, SAVE MASK downloads it.</p>
<div id="tests"></div>
<div id="bar"><button id="copy">Copy all</button> <button id="z50">50%</button><button id="z100">100%</button><span id="status"></span></div>
<script>
const DATA = %DATA%;
const KEY = "pick " + DATA.title;
const state = JSON.parse(localStorage.getItem(KEY) || "{}");  // name -> {pick, text}
let cur = 0;
const $ = id => document.getElementById(id);
let zoom = +(localStorage.getItem("pick zoom") || 0.5);  // of the image's own pixels, never above 1
// the image at its zoom, and a paint overlay beside it at the same CSS width (its height follows its own pixels)
const size = img => {
  img.style.width = img.naturalWidth * zoom / devicePixelRatio + "px";
  img.nextElementSibling.style.width = img.style.width;
};
function setZoom(z) {
  zoom = z;
  localStorage.setItem("pick zoom", z);
  document.body.classList.toggle("half", z < 1);
  $("z50").classList.toggle("on", z < 1);
  $("z100").classList.toggle("on", z === 1);
  document.querySelectorAll("section img").forEach(size);
}
const secs = DATA.tests.map((t, ti) => {
  const s = document.createElement("section");
  s.innerHTML = `<h2>${ti + 1}. ${t.name}</h2><p class="note">${t.note || ""}</p><div class="opts"></div>
    <div class="stage"><img><canvas></canvas><div class="ring"></div></div><audio controls hidden></audio>
    <p class="paint" hidden>MASK: brush <b></b> px. Drag paints, right-drag erases, [ ] size, C clears, M stops.
    <button>SAVE MASK</button></p><p><input placeholder="or a note: reroll, darker, ..."> <button class="mbtn">PAINT MASK (M)</button></p>`;
  const opts = s.querySelector(".opts"), img = s.querySelector("img"), au = s.querySelector("audio"),
    inp = s.querySelector("input");
  const st = state[t.name] || (state[t.name] = {pick: null, text: ""});
  let showing = 0, full = !!t.full;
  // the mask: painted at the full frame's own pixels, kept per section across reloads
  const cv = s.querySelector("canvas"), ctx = cv.getContext("2d"), ring = s.querySelector(".ring"),
    pbar = s.querySelector(".paint"), MKEY = KEY + " mask " + t.name;
  let painting = false, brush = 48, last = null, erase = false;
  const at = e => { const r = cv.getBoundingClientRect(); return [(e.clientX - r.left) * cv.width / r.width, (e.clientY - r.top) * cv.height / r.height]; };
  const stroke = (a, b) => {
    ctx.globalCompositeOperation = erase ? "destination-out" : "source-over";
    ctx.strokeStyle = "#f00"; ctx.lineWidth = brush; ctx.lineCap = "round";
    ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke();
  };
  const follow = e => {
    const r = cv.getBoundingClientRect(), d = brush * r.width / cv.width;
    ring.style.cssText = `width:${d}px;height:${d}px;left:${e.clientX - r.left - d / 2}px;top:${e.clientY - r.top - d / 2}px`;
  };
  cv.onpointerdown = e => { cv.setPointerCapture(e.pointerId); erase = e.button === 2; last = at(e); stroke(last, last); };
  cv.onpointermove = e => { follow(e); if (!last) return; const p = at(e); stroke(last, p); last = p; };
  cv.onpointerup = () => { last = null; try { localStorage.setItem(MKEY, cv.toDataURL()); } catch (e) { say("Mask not kept: storage full"); } };
  cv.oncontextmenu = e => e.preventDefault();
  s.querySelector(".mbtn").onclick = () => paint(!painting);
  const brushText = () => pbar.querySelector("b").textContent = brush;
  // paint mode on the whole frame of the option on show: the overlay sized to its pixels, a kept mask redrawn
  const paint = on => {
    painting = on;
    s.classList.toggle("painting", on);
    pbar.hidden = !on;
    if (!on) return;
    full = true;
    show(showing);
    const ready = () => {
      if (cv.width !== img.naturalWidth || cv.height !== img.naturalHeight) {
        cv.width = img.naturalWidth; cv.height = img.naturalHeight;
        const kept = localStorage.getItem(MKEY);
        if (kept) { const k = new Image(); k.onload = () => ctx.drawImage(k, 0, 0); k.src = kept; }
      }
      size(img); brushText();
    };
    img.complete && img.naturalWidth ? ready() : img.addEventListener("load", ready, {once: true});
  };
  // the mask as the API wants it: opaque everywhere, transparent where painted, at the source's own size
  pbar.querySelector("button").onclick = () => {
    const m = document.createElement("canvas"), c = m.getContext("2d");
    m.width = cv.width; m.height = cv.height;
    c.fillStyle = "#000"; c.fillRect(0, 0, m.width, m.height);
    c.globalCompositeOperation = "destination-out"; c.drawImage(cv, 0, 0);
    const slug = t.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
    const stamp = new Date().toTimeString().slice(0, 8).replace(/:/g, "");
    m.toBlob(b => {
      const a = document.createElement("a");
      a.href = URL.createObjectURL(b); a.download = `mask-${slug}-${stamp}.png`; a.click();
      // the copied choices say so: a section whose answer is a mask has no option or note to show for it
      st.mask = a.download;
      copy();
      say("Saved " + a.download + ", choices copied");
    });
  };
  const show = i => {
    showing = i;
    const f = t.files[i];
    img.hidden = !!f.audio;
    au.hidden = !f.audio;
    if (f.audio) { au.src = f.full; au.play().catch(() => {}); }
    else img.src = full ? f.full : f.crop;
    [...opts.children].forEach((o, j) => o.classList.toggle("show", j === i));
  };
  const mark = () => [...opts.children].forEach((o, j) => o.classList.toggle("pick", st.pick === j));
  t.files.forEach((f, i) => {
    const o = document.createElement("span");
    o.className = "opt";
    o.innerHTML = `[${i + 1}] ${f.label} <i>${f.note || ""}</i> <label><input type="checkbox"> PICK</label>`;
    const cb = o.querySelector("input");
    cb.checked = st.pick === i;
    o.onclick = e => { if (e.target !== cb && e.target.tagName !== "LABEL") show(i); };
    cb.onchange = () => {
      st.pick = cb.checked ? i : null;
      if (cb.checked) { st.text = ""; inp.value = ""; }
      opts.querySelectorAll("input").forEach((c, j) => c.checked = st.pick === j);
      mark(); copy();
    };
    opts.append(o);
  });
  inp.value = st.text;
  inp.oninput = () => {
    st.text = inp.value;
    if (inp.value.trim()) { st.pick = null; opts.querySelectorAll("input").forEach(c => c.checked = false); mark(); }
    copy();
  };
  img.onload = () => size(img);
  img.onclick = () => show((showing + 1) % t.files.length);
  s.onmouseenter = () => { cur = ti; secs.forEach((x, j) => x.el.classList.toggle("on", j === ti)); };
  $("tests").append(s);
  mark(); show(st.pick ?? 0);
  return {el: s, show, files: t.files, get showing() { return showing; },
    toggle() { if (!painting) { full = !full; show(showing); } },
    get painting() { return painting; }, paint,
    resize(d) { brush = Math.max(4, Math.min(400, brush + d)); brushText(); },
    clear() { ctx.clearRect(0, 0, cv.width, cv.height); localStorage.removeItem(MKEY); }};
});
document.addEventListener("keydown", e => {
  if (e.target.tagName === "INPUT" && e.target.type !== "checkbox") return;
  // the physical key, not the character: on a Russian layout M types "ь" (the user, 2026-11-13: "press m doesn't work")
  const k = e.code, n = +(k.match(/^(?:Digit|Numpad)(\d)$/) || [])[1] || 0;
  if (n >= 1 && n <= secs[cur].files.length) secs[cur].show(n - 1);
  if (k === "KeyF") secs[cur].toggle();
  if (k === "KeyZ") setZoom(zoom < 1 ? 1 : 0.5);
  if (k === "KeyM") secs[cur].paint(!secs[cur].painting);
  if (secs[cur].painting && k === "BracketLeft") secs[cur].resize(-8);
  if (secs[cur].painting && k === "BracketRight") secs[cur].resize(8);
  if (secs[cur].painting && k === "KeyC") secs[cur].clear();
});
function text() {
  return DATA.tests.map((t, ti) => {
    const st = state[t.name], own = (st.text || "").trim();
    const what = st.pick != null ? t.files[st.pick].label : own ? `"${own}"` : "";
    const mask = st.mask ? `mask saved (${st.mask})` : "";
    return `${ti + 1} ${t.name}: ` + ([what, mask].filter(x => x).join(", ") || "no choice");
  }).join("\n");
}
let quiet;
function say(m) { $("status").textContent = m; clearTimeout(quiet); quiet = setTimeout(() => $("status").textContent = "", 4000); }
function legacy(s) {  // synchronous, so it works inside the click or keystroke on a file:// page; keeps the caret
  const back = document.activeElement, a = back && back.selectionStart, b = back && back.selectionEnd;
  const ta = document.createElement("textarea");
  ta.value = s; ta.readOnly = true; ta.style.cssText = "position:fixed;top:0;left:0;opacity:0";
  document.body.append(ta); ta.select();
  let ok = false; try { ok = document.execCommand("copy"); } catch (e) {}
  ta.remove();
  if (back && back.focus) { back.focus(); if (typeof a === "number" && back.setSelectionRange) back.setSelectionRange(a, b); }
  return ok;
}
function copy() {  // every change copies all the choices
  localStorage.setItem(KEY, JSON.stringify(state));
  const s = text();
  if (legacy(s)) return say("Copied");
  navigator.clipboard.writeText(s).then(() => say("Copied"), () => say("Not copied: this browser blocks the clipboard"));
}
$("copy").onclick = copy;
$("z50").onclick = () => setZoom(0.5);
$("z100").onclick = () => setZoom(1);
setZoom(zoom);
</script></body></html>
"""


def main():
    # a leading sprites-src/ (or other shorthand folder name) resolves to its env dir (tools/env.py)
    spec_path = (Path(sys.argv[1]) if Path(sys.argv[1]).exists() else path(sys.argv[1])).resolve()
    root = spec_path.parent
    spec = json.loads(spec_path.read_text())
    for t in spec["tests"]:
        for f in t["files"]:
            f["full"] = f["crop"] = f["src"]
            f["audio"] = f["src"].lower().endswith((".wav", ".mp3"))
    page = root / "pick.html"
    page.write_text(PAGE.replace("%TITLE%", spec["title"]).replace("%DATA%", json.dumps(spec)))
    print(page)
    if "--no-open" not in sys.argv:
        url = "file:///" + subprocess.run(["wslpath", "-m", str(page)], capture_output=True, text=True,
            check=True).stdout.strip().replace(" ", "%20")
        # the user's main profile (`Default`), through cmd's `start` from /mnt/c: a direct chrome.exe launch from WSL
        # hung and opened nothing. The caller checks the window title came up (CLAUDE.md)
        subprocess.run(["cmd.exe", "/c", "start", "", CHROME, "--profile-directory=Default", url], cwd="/mnt/c",
            check=True)


if __name__ == "__main__":
    main()
