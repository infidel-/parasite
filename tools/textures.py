#!/usr/bin/env python3
"""Texture build: textures-src/ (1024 sources) -> textures/ (downscaled runtime).

Driven by textures-src/textures.json. For each tracked texture it:
  1. renames freshly generated gpt files (image-*/edit-* -> <label>.png) in src,
  2. downscales src -> textures/<label>.png at the entry's res (default_res else),
     only when the source is newer than the last conversion (or output missing),
  3. for class "chroma": bakes the key color to alpha before downscaling,
  4. warns when a needs_alpha texture has no real alpha (gpt can't emit it ->
     the source must be human-edited),
  5. rewrites textures.json with the new last_converted timestamps.

It never calls gpt-image-2; regeneration is manual (use the stored prompt).

Usage: python3 tools/textures.py   (run from repo root; `make tex` wraps it)
"""
import json
import os
import re
import sys
from datetime import datetime

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "textures-src")
# runtime textures are served from the electron app dir (staged into app/ by the build)
OUT_DIR = os.path.join(ROOT, "parasite", "resources", "app", "textures")
INFO = os.path.join(SRC_DIR, "textures.json")
GPT_PREFIX = re.compile(r"^(image|edit)-\d+-\d+-[0-9a-f]+-(.+)$")

warnings = []


def warn(msg):
    warnings.append(msg)
    print(f"  ! {msg}")


def rename_generated():
    """Strip gpt prefix so a freshly generated image-...-<label>.png becomes <label>.png.
    Walks subdirs (e.g. decals/) so a drop generated into textures-src/<sub>/ is renamed in place."""
    for root, _dirs, files in os.walk(SRC_DIR):
        for f in sorted(files):
            m = GPT_PREFIX.match(f)
            if not m:
                continue
            dst = m.group(2)
            os.replace(os.path.join(root, f), os.path.join(root, dst))
            print(f"  renamed {f} -> {dst}")


def has_alpha(im):
    if "A" not in im.getbands():
        return False
    lo, hi = im.getchannel("A").getextrema()
    return lo < 255  # some pixel is non-opaque


def chroma_key(im, color_hex, tol):
    """Make pixels within `tol` of color_hex transparent (RGBA out)."""
    im = im.convert("RGBA")
    c = int(color_hex, 16)
    key = np.array([(c >> 16) & 255, (c >> 8) & 255, c & 255])
    a = np.asarray(im).copy()
    dist = np.abs(a[:, :, :3].astype(int) - key).max(axis=2)
    a[dist < tol, 3] = 0
    return Image.fromarray(a, "RGBA")


def bleed_alpha(im, iters=20):
    """Overwrite (near-)transparent texels' RGB with their nearest opaque colour.
    Run AFTER the LANCZOS downscale: PIL resizes RGBA without premultiplying, so the
    alpha edge drives per-channel ringing that manufactures saturated colour at low
    alpha (invisible until straight-alpha texture filtering bleeds it out as cyan/
    magenta specks on dark walls). Flooding clean neighbour colour over those texels
    erases the junk (and leaves no dark halo). Alpha itself is left untouched."""
    im = im.convert("RGBA")
    a = np.asarray(im).astype(np.float32)
    rgb = a[:, :, :3]
    known = a[:, :, 3] > 24  # low alpha (incl. the ring fringe) = unknown colour, to be refilled
    for _ in range(iters):
        if known.all():
            break
        sums = np.zeros_like(rgb)
        cnt = np.zeros(rgb.shape[:2], np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            kn = np.roll(known, (dy, dx), (0, 1))
            sums += np.roll(rgb, (dy, dx), (0, 1)) * kn[:, :, None]
            cnt += kn
        fill = (~known) & (cnt > 0)
        rgb[fill] = sums[fill] / cnt[fill][:, None]
        known |= fill
    out = np.empty(a.shape, np.uint8)
    out[:, :, :3] = np.clip(rgb, 0, 255)
    out[:, :, 3] = np.asarray(im)[:, :, 3]
    return Image.fromarray(out, "RGBA")


def convert(label, e, default_res):
    src = os.path.join(SRC_DIR, e["src"])
    out = os.path.join(OUT_DIR, label + ".png")
    os.makedirs(os.path.dirname(out), exist_ok=True)  # nested labels (e.g. decals/...) -> subdir
    if not os.path.exists(src):
        warn(f"{label}: source {e['src']} missing")
        return False

    src_mtime = datetime.fromtimestamp(os.path.getmtime(src)).replace(microsecond=0)
    last = e.get("last_converted")
    fresh = (
        not os.path.exists(out)
        or last is None
        or src_mtime > datetime.fromisoformat(last)
    )

    res = e.get("res", default_res)
    ow, oh = (int(res[0]), int(res[1])) if isinstance(res, (list, tuple)) else (int(res), int(res))
    if fresh:
        im = Image.open(src)
        if e["class"] == "chroma":
            im = chroma_key(im, e.get("chroma", "0x000000"), e.get("tol", 24))
        im = im.resize((ow, oh), Image.LANCZOS)
        if has_alpha(im):
            im = bleed_alpha(im)  # scrub the LANCZOS colour-ring fringe at low alpha
        im.save(out)
        e["last_converted"] = src_mtime.isoformat()
        print(f"  built {label}.png  {ow}x{oh}  ({im.mode})")

    if e.get("needs_alpha") and not has_alpha(Image.open(out)):
        warn(f"{label}: needs transparency but {e['src']} is opaque — human-edit the source")
    return fresh


def main():
    # `--rename` only adopts freshly generated gpt drops (strip prefix), no baking.
    # Use for raw sources kept in textures-src/ that never go through the square bake
    # (e.g. the 16:9 storefronts): `make adopt`.
    if "--rename" in sys.argv:
        rename_generated()
        return
    if not os.path.exists(INFO):
        sys.exit(f"missing {INFO}")
    rename_generated()
    with open(INFO) as f:
        info = json.load(f)
    default_res = info.get("default_res", 512)
    os.makedirs(OUT_DIR, exist_ok=True)

    tracked = set()
    built = 0
    ok = []
    for label, e in info["textures"].items():
        tracked.add(e["src"])
        if convert(label, e, default_res):
            built += 1
        else:
            ok.append(label)
    if ok:
        print(f"  ok    {len(ok)} up to date")

    # Untracked sources (ignore the json and any un-renamed gpt drops). Walk subdirs so
    # tracked paths like "decals/foo.png" match and stray files in subfolders are flagged.
    for root, _dirs, files in os.walk(SRC_DIR):
        # skip the unused/ shelf: retired sources parked out of the pipeline, not deleted
        if "unused" in _dirs:
            _dirs.remove("unused")
        for f in files:
            # sweep editor backup files (*~) instead of leaving them to clutter the source tree
            if f.endswith("~"):
                os.remove(os.path.join(root, f))
                print(f"  removed backup {os.path.relpath(os.path.join(root, f), SRC_DIR)}")
                continue
            # skip Krita working files silently (editable source, not a texture)
            if f.endswith(".kra"):
                continue
            rel = os.path.relpath(os.path.join(root, f), SRC_DIR)
            if f == "textures.json" or GPT_PREFIX.match(f) or rel in tracked:
                continue
            warn(f"untracked source {rel} (add it to textures.json or delete it)")

    with open(INFO, "w") as f:
        json.dump(info, f, indent=2)
        f.write("\n")

    print(f"\n{built} built, {len(info['textures']) - built} up-to-date, {len(warnings)} warning(s)")
    if warnings:
        print("warnings:")
        for w in warnings:
            print("  - " + w)


if __name__ == "__main__":
    main()
