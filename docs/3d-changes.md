# 3D render change log

Append-only log of every 3D/render experiment — landed, reverted, or rejected — with its measured
result and its traps. **The index, the measurement rules and the standing notes live in
[`3d-render.md`](3d-render.md) — read that first.** This file holds the bodies: find an entry by
grepping the change text out of that file's verdict table.

Entries record settled outcomes only. Every new entry gets one row in `3d-render.md`. When this file
reaches ~2600 lines, `git mv` it to `3d-changes-<YYYY-MM>.md` and start a fresh one.

Older entries live in [`3d-changes-2026-08b.md`](3d-changes-2026-08b.md) (rolled at 2581 lines) and
[`3d-changes-2026-08.md`](3d-changes-2026-08.md) (rolled at 2664 lines).

---

## The wilderness becomes a 3D area kind (`render.wild`)

`AREA_GROUND` was the last common area kind still drawn by the 2D tile renderer. It is now the third
`Area3D`: `WildArea` / `WildScene` / `WildGround` / `WildGrass` / `WildProps` / `WildModel` /
`WildStyle`, built from the area's SAVED cell grid exactly as the tunnels are — no seed, works on
every existing save, and the tile grid the pathfinder walks around is the one the props stand on.

**Measured on entry** (100x100 cells, 400 world units, host camera): **48-52 draw calls, 137-148k
tris, 60 FPS, 94 programs**. Against a city's 158-288 gameplay calls that is a cheap area, and the
whole of it is chunked ground + chunked grass + four instanced prop batches.

Four things worth carrying forward:

- **The ground is emitted per chunk, subdivided, welded and vertex-tinted.** One quad per cell is
  what the city and the sewers lay and it is not enough here: a 4-unit quad with a tiling texture on
  it reads as a tile, and open ground has no kerb, no road paint and no building edge to break the
  repeat. `SUB` 2 sub-quads per axis is 80k tris over the area, so it goes out one mesh per
  `Chunks.CELLS` block. It is NOT built on `MeshBuf`, which emits four unshared vertices per quad —
  Phase 2 displaces this lattice into relief and wants `computeVertexNormals` to smooth it, which
  unshared corners cannot do. The mottle is two low-frequency sines on the `color` channel, NOT a
  hashed lattice: a hash at sub-quad resolution is white noise and reads as static.
- **The grass wind is one vec2 attribute, not `uv`.** Phase and height weight ride in on `aWind`
  rather than being read off the quad's own `uv.y`, because `uv` is only declared when the material
  happens to define `USE_UV` and a wind term must not depend on that. `alphaTest`, never
  `transparent`: an alpha-tested opaque material draws `DoubleSide` in ONE pass where a transparent
  one draws it as two, and at this density the cut is invisible. Verified live by diffing two
  consecutive captures over a grass-only crop: **6.3% of pixels changed, max delta 45**.
- **The art carries the brightness, the moon carries the form.** The ground tile as painted measured
  **0.0208** in linear luminance — *darker* than the city road's 0.0329 — so it was lifted 0.75 in
  the texture bake to **0.0503**, between the road and the sewer floor's 0.0558. That let the fill
  come DOWN to 1.5/1.2/1.7, slightly under the city's own, where the moon is **57%** of flat-ground
  light and a prop's shadow more than halves the ground under it. The earlier pass had it backwards:
  fill pushed up to 2.1/1.7 over dark art, which flattens the frame by raising the ambient share.
- **`PropPlace` gained an optional `scale`.** `Models.instanced` scaled every instance by one
  `targetH`, so a hundred trees were one tree repeated. The per-placement multiplier has to scale the
  `normalize()` recenter offset too, or a jittered prop drifts off its own footprint.

Not done, and stated rather than skipped quietly: the `SUB` 1/2/4 sweep the plan called for was not
run. At `SUB` 2 the area draws 46–53 calls and 184–233k tris at a locked 60 FPS, i.e. it is nowhere
near a wall, and `SUB` 4 buys nothing until Phase 2 puts real relief on the lattice — which is when
the sweep is worth its measurement.

## Two wilderness bugs that both looked like missing ground

Worth one entry together, because the diagnosis is the same shape twice: something covered half the
frame in flat dark, and in both cases the geometry was innocent. The tool that settled both was a
CDP census — hook `Object3D.prototype.onBeforeRender` to capture the live `scene` (`parasiteHx` is
statics-only), then tint / hide / strip one builder's material at a time and re-measure.

**Fog, sized as if it were keyed on the player.** `FOG_NEAR/FAR` went in at 120/320 on the reasoning
that open ground should end sooner than a street. Fog is keyed on distance from the **camera**, and
this one sits 18–55 units up looking down, so at 320 the far half of every frame was already solid
background: a lit band of ground around the player with black beyond, its edge the iso-distance conic
on the ground plane — which reads exactly like a coastline, i.e. like absent geometry. Byte-measured:
with the fog off, the "band" and the "hole" were the same surface (mean 13.65 vs 13.71 over a 120px
box). Now 260/560, i.e. 0.65 and 1.4 of the 400-unit area span against the city's 0.55 and 1.2.

**A prop with no vertical profile in its reference has none in its mesh.** The bush's first reference
was a three-quarter view FROM ABOVE, and TRELLIS returned a **pancake**: bbox 0.985 × **0.040** ×
0.936, 25× wider than tall. `Models.instanced` scales by HEIGHT ALONE, so asking for `h` 1.1
multiplied it by **28** and laid 218 dark discs ~27 world units across over the whole area — again
read as terrain, not as a broken prop. Regenerated from a straight side elevation at eye level,
explicitly "two thirds as tall as it is wide, not a pancake": **0.985 × 0.564 × 0.936**.

The general rule that falls out, and the one number to check on every new prop: **`h` is not free —
a row's world WIDTH is `h × (widest / height)` of its own bbox.** Measured across this set: conifer
0.64, broadleaf 0.84, cluster 1.31, bush 1.75, **boulder 3.67**. The boulder was not broken, just
wide, and at the `h` 1.5 it went in with it drew 5.5 units across — wider than a cell; `h` 0.9 lands
it at 3.3. Both of these are cheap to catch at generation time and expensive to diagnose in a frame.

## Wilderness art: 5 TRELLIS props, and what the split ratio predicted

Five references at 1k on flat `#5a5d63`, and the split ratio (verts over unique positions) called
every outcome before a single decimation ran:

| prop | split | source | meshopt target 1200 | ships |
|---|---|---|---|---|
| `rock-boulder` | **1.11x** | 97,202 | **1,548** | 1,548, `tex` 256 |
| `rock-cluster` (100k master) | 1.74x | 99,285 | **20,433** | — master deleted |
| `rock-cluster` (at budget) | 1.39x | 4,736 | n/a (`tris` -1) | 4,736, `tex` 512 |
| `tree-broadleaf` | 2.17x | at budget | n/a | 4,934, `tex` 512 |
| `tree-conifer` | 2.21x | at budget | n/a | 4,983, `tex` 512 |
| `bush-low` | 2.27x | at budget | n/a | 4,406, `tex` 512 |

**The ~2x line is not a cliff, it is a gradient, and `rock-cluster` is the measurement that shows
it.** At 1.74x it is comfortably UNDER the line the sewer batch drew, and meshopt still stalled at
20,433 tris — four times the boulder's landing point and unusable for a prop scattered by the
hundred. Read the whole series instead: 1.11x reached 1,548, 1.31x (the drum) floored at 4,826,
1.74x at 20,433, 1.96x and up not at all. So the question is never "is it under 2x", it is "where
will it land, and is that inside the prop budget".

**`tex` had to go DOWN on the one prop that decimated properly.** 1,548 tris at `tex` 512 is 165
texels per triangle against the ~43 a TRELLIS 2048 export is authored at — a map four times larger
than the geometry can show. `tex` 256 lands it at 42. The rule cuts both ways: the sewer batch
learned not to starve a map, and this is the first prop here that had to be stopped from carrying one.

**The frame is what sets `baseColor`, not the albedo arithmetic — twice, in opposite ways.**

- `tree-conifer` needed the **first per-channel `baseColor` in the repo**. Baked at mean sRGB
  41/84/69, the canopy is twice as green as it is red, and the wilderness moon is `0x8294c0`. A blue
  key on a green albedo rendered a stand of conifers as saturated **teal** blobs, by far the loudest
  thing in a near-monochrome night frame. A uniform darken cannot fix that — the saturation is the
  problem and one factor leaves the ratio untouched. 0.55/0.35/0.45 lands it at ~29/50/46. `bush-low`
  is the same case (117/124/82 → 0.11/0.13/0.22), so per-channel is now the norm for foliage here.
- Both rocks needed to go **below** what the arithmetic asked for: 0.15 and 0.18 against the ~0.25
  and ~0.3 that put them at the prop family's nominal 46-52. The arithmetic was not wrong, the
  context is. A rock is one large smooth upward-facing surface catching the full moon term, while the
  ground around it is broken up by grass and by its own mottle — at a "correct" albedo it still read
  as pale blue ice. The number that matters is where it lands ON SCREEN beside its neighbours.

**The two ground textures, and the contrast between them is the whole read.** `wild/ground` is a
full-coverage matted-turf tile at `GROUND_TILE` 9.0 world units (deliberately not a multiple of the
4-unit cell, so the repeat does not land on the grid). `wild/grass` is the tuft sprite and its spec
is unusual enough to record: **side-on at eye level, blades rooted in and cut off by the BOTTOM edge
of the frame**, because the quad's v runs 0 at the ground to 1 at the tip — blades that stopped short
would float, and a top-down lawn tile (which is what the placeholder was) reads as a patch pasted on
the ground rather than as standing grass. Non-square `res` [256,192] keeps the source's 4:3, matching
`TUFT_W` 1.5 × `TUFT_H` 1.1. Measured after the bake: ground **0.0503** linear (after its lift),
blades **0.1385**. The blades being the lighter of the two is what makes a field read at all — there
is no lamp, no window and no kerb out here to supply a value break.

## The grass sprite: a subject too close to its own backdrop, and a lift run backwards

The tuft sprite came back from two separate faults, both in its `textures.json` entry and neither in
the shader. Worth an entry because the first is a general rule about the chroma route and the second
is the first time `lift` has been used to go *down*.

**A subject whose own colour falls inside the chroma tolerance cannot be keyed.** The source was
hand-cut and still registered `class: "chroma"`, so `make tex` kept re-keying it: blades mean
(105,104,84) against `0x5a5d63` is a **max channel diff of 15** at `tol` 24, i.e. inside the key. It
was erasing grass along with the backdrop, and what survived carried a grey wash. `class: "sprite"`
(no key, hand alpha kept, `bleed_alpha` still scrubs the transparent texels) took opaque coverage
from **2,759 to 7,666** texels — 20.3% against the source's own 20.4%. The rule that generalises:
before registering chroma, measure the SUBJECT's distance from the key, not just the backdrop's.

**A dead end on the way, recorded because it nearly shipped.** A claim that "54.5% of partial-alpha
edge texels carry backdrop grey" bought a pre-resize `bleed_alpha` pass in `tools/textures.py`. The
metric cannot work on this image at all — blade and key are ~16/255 apart, so it counts blade texels
as grey. Reverted; `tools/textures.py` is untouched. Same root cause as the fault above.

**Then `lift` backwards, g 1.4, to DARKEN.** The tuft quads carry straight-up `(0,1,0)` normals by
design (`WildGrass.tuft` — a vertical quad lit by its true normal goes black as it turns from the
moon, and the field flickers as the camera orbits). So a blade takes *exactly* the ground's
irradiance, and blade-over-ground on screen is a **pure albedo ratio** that nothing but the texture
sets. It measured **2.70×** (0.1357 vs 0.0503 linear; sRGB 104 vs 62, against a prop family at
46-52) — the loudest thing in the area bar the actor. `lift` is `out = (v/255)**g`, a plain power, so
where every other entry uses g < 1 to brighten, **g 1.4 darkens**: 0.0660 linear, **1.31×** the
ground, sRGB 73/71/53. Still the lighter of the two, so the field still reads.
