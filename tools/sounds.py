#!/usr/bin/env python3
"""Sound build: sounds-src/<area>/*.wav (generated takes) -> app/sound/<area>/<name><N>.mp3.

Driven by art/sounds.json (tracked; the wavs it points at are not). Each entry is one game sound
key ('<area>/<name>') with its variants (one wav each, written by the fal-sfx MCP). For each variant it:
  1. downmixes to mono (nothing in the game pans),
  2. a one-shot: trims leading silence; a loop the model did not loop itself: crossfades the tail
     into the head (equal power, seam_ms) so the file wraps without a click,
  3. high-passes at 40 Hz, 6 dB/octave (one pole): rumble nothing in the game needs. a loop is
     filtered as two copies back to back and the second kept, so the filter starts the file in the
     state the file's own end left it in and the wrap stays seamless,
  4. applies one static gain onto the entry's lufs (default_lufs else) and a -1 dBFS limiter —
     static, not loudnorm's dynamic mode, so a loop's level does not breathe,
  5. encodes mp3 at default_bitrate to app/sound/<area>/<name><N>.mp3, N the variant's position
     in the entry (1-9) — the wav's own <key>-<model><N> name is dropped. the game's sound key is
     then '<area>/<name>' (the main process lists one level of area folders),
  6. rewrites sounds.json with last_converted / last_sig / last_outputs.

It never touches a sound it did not make: an entry whose key matches any mp3 in its area folder
that is not in its own last_outputs is refused (the 220 shipped sounds, a mod's, a renamed entry's), and
nothing in app/sound is ever deleted. It never generates audio; that is the fal-sfx MCP.

Usage: python3 tools/sounds.py [--check]   (run from repo root; `make sounds` wraps it)
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "sounds-src")
# served from the electron app dir: shipped sounds flat, ours in one folder per area
OUT_DIR = os.path.join(ROOT, "parasite", "resources", "app", "sound")
INFO = os.path.join(ROOT, "art", "sounds.json")

warnings = []


def warn(msg):
    warnings.append(msg)
    print(f"  ! {msg}")


def ff(args):
    """run ffmpeg quietly and return its stderr (where ebur128 prints)."""
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-y"] + args, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr[-800:])
    return r.stderr


def probe_duration(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
        capture_output=True, text=True, check=True,
    ).stdout
    return float(out.strip())


def loudness(path):
    """integrated loudness in LUFS (ebur128 summary)."""
    m = re.search(r"Summary:.*?I:\s+(-?[\d.]+|-inf) LUFS", ff(["-i", path, "-af", "ebur128", "-f", "null", "-"]), re.S)
    return -70.0 if m is None or m.group(1) == "-inf" else float(m.group(1))


def shape(src, tmp, loop, native, seam):
    """mono + trim (one-shot) or seam crossfade (loop the model did not loop) -> tmp wav."""
    if not loop:
        chain = "aformat=channel_layouts=mono,silenceremove=start_periods=1:start_threshold=-50dB"
        ff(["-i", src, "-af", chain, "-c:a", "pcm_s16le", tmp])
        return
    if native:
        ff(["-i", src, "-af", "aformat=channel_layouts=mono", "-c:a", "pcm_s16le", tmp])
        return
    # out = [head*fadein + tail*fadeout] + body. the body ends where the tail began, and the tail is
    # what the head was mixed with, so the wrap point is continuous. qsin = equal power, so a noisy
    # bed does not dip 3 dB mid-seam the way a linear fade does
    length = probe_duration(src)
    xf = min(seam, length / 4)
    graph = (
        f"[0]aformat=channel_layouts=mono,asplit=3[a][b][c];"
        f"[a]atrim=0:{xf},asetpts=PTS-STARTPTS,afade=t=in:d={xf}:curve=qsin[h];"
        f"[b]atrim=start={length - xf},asetpts=PTS-STARTPTS,afade=t=out:d={xf}:curve=qsin[t];"
        f"[c]atrim={xf}:{length - xf},asetpts=PTS-STARTPTS[m];"
        f"[h][t]amerge=inputs=2,pan=mono|c0=c0+c1[x];"
        f"[x][m]concat=n=2:v=0:a=1[o]"
    )
    ff(["-i", src, "-filter_complex", graph, "-map", "[o]", "-c:a", "pcm_s16le", tmp])


# the rumble cut, measured after so the gain lands on the filtered level
HIGHPASS = "highpass=f=40:poles=1"


def highpass(src, out, loop):
    if not loop:
        ff(["-i", src, "-af", HIGHPASS, "-c:a", "pcm_s16le", out])
        return
    n = int(ff(["-i", src, "-af", "astats=measure_overall=Number_of_samples:measure_perchannel=0", "-f", "null", "-"])
        .split("Number of samples:")[-1].split()[0].split(".")[0])
    ff(["-i", src, "-i", src, "-filter_complex",
        f"[0][1]concat=n=2:v=0:a=1,{HIGHPASS},atrim=start_sample={n},asetpts=PTS-STARTPTS[o]",
        "-map", "[o]", "-c:a", "pcm_s16le", out])


def bake(src, out, loop, native, seam, lufs, bitrate):
    with tempfile.TemporaryDirectory() as d:
        shaped = os.path.join(d, "shaped.wav")
        shape(src, shaped, loop, native, seam)
        tmp = os.path.join(d, "filtered.wav")
        highpass(shaped, tmp, loop)
        gain = lufs - loudness(tmp)
        # level=0: 4.4's alimiter auto-levels the output back up by default
        chain = f"volume={gain:.2f}dB,alimiter=limit=0.891:level=0"
        ff(["-i", tmp, "-af", chain, "-ac", "1", "-ar", "44100", "-c:a", "libmp3lame", "-b:a", bitrate, out])


def foreign(area, name, owned, out_dir):
    """mp3s in the area folder that the game would read as this key and that this entry did not write."""
    pat = re.compile(re.escape(name) + r"\d?\.mp3$")
    d = os.path.join(out_dir, area)
    files = os.listdir(d) if os.path.isdir(d) else []
    return [f"{area}/{f}" for f in files if pat.fullmatch(f) and f"{area}/{f}" not in owned]


def convert(key, e, info, src_dir, out_dir):
    """bake one entry when due. returns True if built. key is the game's own '<area>/<name>'."""
    # the game key's variant digit is the take's POSITION in the entry, not the digit in its file
    # name: the wav is <key>-<model><N>.wav, and two models' first takes are both N=1
    area = e["area"]
    name = key.split("/")[-1]
    # one level, no dot: the game lists one folder deep and cuts a key at its first '.'
    if not re.fullmatch(r"[a-z0-9_-]+", area) or key != f"{area}/{name}":
        warn(f"{key}: REFUSED, key must be '<area>/<name>' with area one plain folder name")
        return False
    outs = [
        (os.path.join(src_dir, v["file"]), f"{area}/{name}{i + 1}.mp3", v.get("native_loop", False))
        for i, v in enumerate(e["variants"][:9])
    ]
    clash = foreign(area, name, set(e.get("last_outputs", [])), out_dir)
    if clash:
        warn(f"{key}: REFUSED, would join or overwrite sounds this pipeline did not make: {', '.join(sorted(clash))}")
        return False
    missing = [s for s, _o, _n in outs if not os.path.exists(s)]
    if missing:
        warn(f"{key}: source missing {', '.join(os.path.relpath(m, src_dir) for m in missing)}")
        return False

    lufs = e.get("lufs", info["default_lufs"])
    sig = f"{lufs}/{info['default_bitrate']}/{e['loop']}/{info['seam_ms']}/hp40"
    last = e.get("last_converted")
    newest = max(datetime.fromtimestamp(os.path.getmtime(s)).replace(microsecond=0) for s, _o, _n in outs)
    fresh = (
        last is None
        or newest > datetime.fromisoformat(last)
        or sig != e.get("last_sig")
        or any(not os.path.exists(os.path.join(out_dir, o)) for _s, o, _n in outs)
    )
    if not fresh:
        return False
    os.makedirs(os.path.join(out_dir, area), exist_ok=True)
    for s, o, native in outs:
        bake(s, os.path.join(out_dir, o), e["loop"], native, info["seam_ms"] / 1000, lufs, info["default_bitrate"])
        print(f"  built {o}")
    e["last_converted"] = datetime.now().replace(microsecond=0).isoformat()
    e["last_sig"] = sig
    e["last_outputs"] = sorted(set(e.get("last_outputs", [])) | {o for _s, o, _n in outs})
    return True


def run(info_path, src_dir, out_dir):
    with open(info_path) as f:
        info = json.load(f)
    built = sum(convert(n, e, info, src_dir, out_dir) for n, e in info["sounds"].items())

    # untracked wavs. `_`-prefixed folders (bake-offs) and unused/used shelves are skipped
    tracked = {v["file"] for e in info["sounds"].values() for v in e["variants"]}
    for root, dirs, files in os.walk(src_dir):
        dirs[:] = [d for d in dirs if not d.startswith("_") and d.lower() not in ("unused", "used")]
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), src_dir)
            if f.endswith(".wav") and rel not in tracked:
                warn(f"untracked source {rel} (add it to sounds.json or delete it)")

    with open(info_path, "w") as f:
        json.dump(info, f, indent=2)
        f.write("\n")
    print(f"\n{built} built, {len(info['sounds']) - built} up-to-date or skipped, {len(warnings)} warning(s)")
    return info


def check():
    """self-check on synthetic audio in a temp dir: a crossfaded loop lands mono, at the target
    loudness, one seam shorter; a one-shot is trimmed; a key that clashes with a foreign mp3 is refused."""
    with tempfile.TemporaryDirectory() as d:
        src, out = os.path.join(d, "src"), os.path.join(d, "out")
        os.makedirs(os.path.join(src, "t"))
        os.makedirs(out)
        ff(["-f", "lavfi", "-i", "anoisesrc=d=4:c=pink:a=0.3", "-ac", "2", os.path.join(src, "t", "hum-sonilo1.wav")])
        ff(["-f", "lavfi", "-i", "anoisesrc=d=4:c=brown:a=0.3", os.path.join(src, "t", "hum-elevenlabs1.wav")])
        ff(["-f", "lavfi", "-i", "anullsrc=d=0.5", "-f", "lavfi", "-i", "sine=f=440:d=1",
            "-filter_complex", "[0][1]concat=n=2:v=0:a=1", os.path.join(src, "t", "ping1.wav")])
        ff(["-f", "lavfi", "-i", "sine=f=200:d=1", os.path.join(src, "t", "old1.wav")])
        os.makedirs(os.path.join(out, "t"))
        open(os.path.join(out, "t", "old1.mp3"), "wb").write(b"shipped")
        var = lambda f: [{"file": f"t/{f}", "native_loop": False}]
        info = {
            "default_lufs": -26, "default_bitrate": "128k", "seam_ms": 500,
            "sounds": {
                "t/hum": {"area": "t", "loop": True, "variants": var("hum-sonilo1.wav") + var("hum-elevenlabs1.wav")},
                "t/ping": {"area": "t", "loop": False, "variants": var("ping1.wav")},
                "t/old": {"area": "t", "loop": False, "variants": var("old1.wav")},
            },
        }
        path = os.path.join(d, "sounds.json")
        json.dump(info, open(path, "w"))
        res = run(path, src, out)
        hum = os.path.join(out, "t", "hum1.mp3")
        ch = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=channels", "-of", "csv=p=0", hum],
                            capture_output=True, text=True).stdout.strip()
        assert ch == "1", ch
        assert abs(loudness(hum) - -26) < 1, loudness(hum)
        assert abs(probe_duration(hum) - 3.5) < 0.1, probe_duration(hum)
        assert probe_duration(os.path.join(out, "t", "ping1.mp3")) < 1.2
        assert open(os.path.join(out, "t", "old1.mp3"), "rb").read() == b"shipped"
        assert "last_converted" not in res["sounds"]["t/old"]
        assert res["sounds"]["t/hum"]["last_outputs"] == ["t/hum1.mp3", "t/hum2.mp3"]
        # a second run builds nothing: the entry now owns its output and is up to date
        warnings.clear()
        assert not convert("t/hum", res["sounds"]["t/hum"], res, src, out)
    print("check ok")


if __name__ == "__main__":
    if "--check" in sys.argv:
        check()
    else:
        run(INFO, SRC_DIR, OUT_DIR)
