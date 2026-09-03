---
name: 3d-art
description: Generate or fix 3D art for the parasite game — a glb prop, a tiling texture, a decal, a sprite, an emissive map, or a TRELLIS reference image. Use when asked for "new images", a new prop/texture/decal, when a prop or surface reads wrong (blurry, shiny, too dark, wrong colour, smeared, mush), before running `make tex` / `make models`, or when deciding whether a new object should be a generated prop, emitted geometry, or just a texture. Loads the pipeline docs; do not work these pipelines from memory.
---

# 3D art: prop, texture, or neither

`docs/3d-models.md` and `docs/3d-textures.md` hold every rule and the measurement behind it. **Read
the relevant one before spending money** — each parameter in these pipelines was fitted to a number,
and a wrong one costs $0.03 and produces art that looks like a different bug.

## Step 0 — triage, before anything is generated

Ask what CARRIES the object: its **silhouette** or its **surface**?

| the object is | build it as | why |
|---|---|---|
| axis-aligned slabs — kiosk, bench, cabinet, low wall, skip | **emitted geometry**, `render/facility/FacilityGeom.hx` (`face`/`pane`/`cap`/`add`/`geom`) + a tiling texture | exact proportions, the game's own textures at full texel density, no unwrap lottery. Guard booth **7,431 tris → 34** |
| a stripe, a rhythm, a material, a pattern you can name in one sentence | **a tiling texture** on emitted geometry | a bake cannot lose contrast the way TRELLIS lost the barrier's hazard bands (red-on-white → orange-on-tan). Boom barrier **3,098 tris → 22** |
| a real irregular silhouette — plant, rock, vehicle, machine, fixture | **a generated glb prop** | this is what a mesh generator is for |
| several objects at once (crate + sack + cable coil) | **split it and say so** — one prop each | a composite bake shatters the atlas and no tri budget buys the silhouette back |

Two smells that the surface is doing the work and you are about to generate the wrong thing: the
`models.json` note is arguing for a hand-fitted `baseColor` off the family, or the whole read is one
namable pattern.

Worked examples of the emitted route: `FacilityTables.hx`, `FacilityEntry.hx`.

## A prop → `docs/3d-models.md`

1. `generate_image` (gpt-image-2) — ONE modern object, centred, whole, clear of the frame edges,
   **isometric from above one corner**, on flat solid grey `#5a5d63`, canonical **`style_prop`**
   string appended verbatim — a reference image is an OBJECT, so it takes the prop string and never
   `style`, which is the surface one and carries the "muted desaturated palette" clause that shipped
   9 of 38 props grey. Name the object's colour and say it must stay saturated.
2. `python3 tools/propstat.py <ref>.png` — subject value against the p50 **69-77** that bakes
   correctly, frame margin, backdrop colour. Fix in code (`--lift`, `--fit`) before re-prompting.
3. `image_to_3d` (`runware-trellis-2`) — omit `remesh_project`/`mesh_cluster`, the defaults are now
   the playground's. Organic or hollow subject: `decimation_target` at the game budget + `"tris": -1`.
4. `python3 tools/propstat.py <prop>.glb` — components, split ratio, albedo, texels/tri **and
   texels per world unit at the `h` the game draws it**. Then the `models.json` entry, `make models`,
   and **re-measure the built glb**.
5. Warm the new path in `View.hx`'s `Models.get` chain, one entry per material variant.

## A texture → `docs/3d-textures.md`

`generate_image` straight into `textures-src/` with `filename_prefix=<final-label>` → `make adopt`
→ entry in `textures.json` (update `prompt`) → `make tex` → `make -C src` → `make reload`.
Never `mv`/`cp` a drop by hand. Alpha comes from `background:"transparent"`; the flat-grey chroma
route is the fallback and is still mandatory for TRELLIS references.

## Diagnosing art that came back wrong

| symptom | it is almost certainly | doc section |
|---|---|---|
| blurry, soft, softer than the ground | `tex` too low for the prop's SIZE — measure texels per world unit, not per triangle | Texture density |
| smeared, mush, "quite shit" | the atlas, not the mesh — re-measure the BUILT glb's split ratio; regenerate at budget | Generation settings |
| shattered, blobby, rounded off | the settings, not the reference — re-run with the corrected defaults first | Generation settings |
| too dark, half the prop family | self-occlusion baked into the albedo → `lift` (a gamma), not `baseColor` | Materials |
| grey, colourless, "reads as a hole" | the reference took `style` instead of `style_prop`, and/or a per-channel `baseColor` neutralised the bake — check `propstat`'s `chroma` line | Materials |
| a prop INDOORS reads as a black card | the 46-52 family is the OUTDOOR one; against the repainted interior (floor 95, wall 111) an indoor prop wants ~78 | Materials |
| wrong hue on one part only (teal body, rust windows) | a per-channel `baseColor` correcting a per-material cast → use a flat scalar | Materials |
| chrome / black under debug key `1` | metalness — read the MR map (G = roughness, B = metalness) | Materials |
| glow in the wrong place, speckles | emissive mask dilation bleeding into the next chart — `tools/emissive.py`, ship only at bleed **0** | Making a prop glow |

Never: stretch a texture, enable Draco, ship a multi-mesh glb (`Models.instanced` keeps the first
and drops the rest silently), or hand-place a build artifact in `app/`.
