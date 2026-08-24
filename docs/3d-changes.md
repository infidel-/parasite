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

## Count a prop's CONNECTED COMPONENTS — the split ratio does not catch "mostly empty"

The user hand-replaced `wild/bush-low` with one generated in the Runware web playground, saying mine
was "mostly empty", and asked whether our MCP sends the playground's settings. Measuring both settled
a question the existing rules could not even ask. Components over unique positions, union-find over
triangle edges:

| glb | tris | verts | uniq | split | **components** | **largest** |
|---|---|---|---|---|---|---|
| `rock-boulder` | 97,202 | 54,048 | 48,602 | 1.11x | **1** | 100% |
| `bush-low` (user's, now shipped) | 4,955 | 4,280 | 2,395 | 1.79x | **8** | 98.7% |
| `tree-conifer` (old settings) | 4,983 | 5,043 | 2,276 | 2.22x | **12** | 52.9% |
| `bush-low` (mine, retired) | 4,406 | 5,454 | 2,399 | 2.27x | **96** | **24.3%** |
| **PROBE — the retired bush's OWN reference, new settings** | 4,777 | — | — | **1.68x** | **1** | **100.0%** |

"Mostly empty" is literal: 96 disconnected blobs with the largest holding a quarter of the mesh — a
cloud of separate leaf clumps with air between them. Identical bbox and near-identical unique-position
count to the replacement, so **no existing measurement we take would have flagged it**: the split
ratio describes the ATLAS, and this is the SURFACE. `tree-conifer` has the same disease at half
strength and is queued for regeneration.

**The cause is the SETTINGS, and a controlled probe is the only thing that could have shown it.** The
first read here was that the reference did it — mine painted the dome as discrete leaf clumps with
dark gaps, and "TRELLIS resolves a dark gap as real air" is a tidy story that fits the data. It was
wrong. Re-running **that exact reference, unmodified**, with the corrected settings returns **1
component at 100%**, split 1.68. 96 → 1, one variable changed. Nothing about run-to-run noise reaches
that far.

So the reasoning that dismissed the settings — "UV chart clustering cannot merge disconnected
surfaces" — was itself the error: `meshCluster`'s `smoothStrength` and `thresholdConeHalfAngleRad`
reach the dual-contour remesh, not just the atlas. **Do not reason about which knob can matter; run
the one-variable job.** It cost $0.03.

**Two of the settings were outright bugs.** Against the playground payload: `meshCluster` was **dead
code** in the MCP — declared on `Trellis3dOptions` and forwarded by `buildInferenceBody`, but absent
from the tool's `inputSchema` and never set at the call site, so unreachable from the tool. And
`remesh_project` defaulted to 0.8 against the playground's 0.9. Both fixed; `mesh_cluster` now
defaults to `{1, 0, 1, PI/2}`.

The acceptance gate stands, but read it correctly: **few components, each a substantial solid piece**.
Raw counts mislead in both directions — the shipped conifer is 2 components at 51%/49% (a canopy and a
trunk, both solid) and `tree-broadleaf-full` is 17 at 93.9% (sixteen specks sharing 6.1%). Neither is
the failure. The failure is 96 pieces with the largest at 24.3%.

**A `baseColor` is fitted to one bake, and a replaced glb silently invalidates it.** The entry still
carried `0.11/0.13/0.22`, fitted to the retired mesh's baked mean sRGB 117/124/82. The replacement
bakes at **84/96/61**, which those same factors land near **29/35/30** against the prop family's
46-52 — the prop was rendering about a third too dark with nothing to indicate it. Refitted to
0.26/0.28/0.52. Its MR map was re-read on the new mesh rather than carried forward (pure green,
0/248/0, no `dropMR`), and its `seed` dropped: it belonged to the retired mesh, and the shipped one is
not reproducible from this repo at all — its reference lives only on Runware's CDN.

## Ground patches in the wilderness, and two ways a working layer reads as nothing

`render.world.Lawns`' coverage mask — one soft radial kernel per marked cell, `lighten`-unioned onto a
canvas and handed in as `alphaMap` — is now `render.world.CoverageMask`, shared with a second caller.
Extracted rather than copied because all four of its decisions are traps (`lighten` is a per-channel
MAX not an add; `flipY = false`; the repeat/offset rescale; the kernel radius must clear `CELL * 0.5`
or a run of cells beads into a string of pearls). `render.wild.WildPatches` is the new caller: two
overlays, bare earth under dead grass, over the turf.

**One deliberate divergence from Lawns: the geometry is emitted per `Chunks.CELLS` block.** Lawns
affords a single mesh because a city lawn covers a handful of alley cells; a wilderness layer spans
the whole 400-unit area, which is past `Chunks`' own size guard, so one mesh would sit at the scene
root and submit the entire area's blended fill every frame. Cost as built: **44 → 57 draw calls,
177k → 285k tris, still 60 FPS**, for two patch layers plus the small-rock batches.

Both tuning failures were invisible-by-eye and needed a measurement:

- **Coverage too dense reads as SPECKLE, not as patches.** First pass seeded at 0.07 / 0.045, which
  put **25.8%** and **18.4%** of the mask over the alphaTest line. Tinting the layers magenta showed
  them covering the entire frame — because what shows through a near-uniform mask is just the art's
  own ~38% coverage, i.e. grain. Judge the MASK, not the seed count: 0.013 / 0.008 with `KERN` raised
  7.0 → 11.0 lands 10.0% / 8.7% strong, and the blobs read as islands. `KERN` matters as much as the
  chance — 7.0 gives a blob radius of ~3.15, under one cell, which from a camera 18-55 units up is
  grain no matter how few of them there are.
- **A real value ladder, halved by opacity, drops under threshold.** Measured LINEAR luminance of the
  three arts as built: earth **0.0348** (0.73×), turf **0.0476**, dead grass **0.0560** (1.18×). At
  Lawns' own `ALPHA` 0.5 the blend collapses that to 0.87× and 1.09×, which in a frame this dark is
  nothing at all. 0.85 restores it. The trap on the other side is real too: widening the ladder in the
  TEXTURE instead, by pushing the earth's `lift` 1.15 → 1.35, computes to 0.0125 — a quarter of the
  turf, which is the sewer-valve failure where a dark overlay stops being an object and becomes a hole.

## Four trees, one per tile ID

`AreaGenerator.generateWilderness` has always dealt `TILE_TREE1 + Std.random(4)`, and the 3D area was
collapsing those four IDs two-and-two onto two models. There are four models now — conifer,
bare broadleaf, broadleaf in leaf, dead snag — mapped **one to one**, so the variant already written
into every saved grid picks the model, identically on every re-entry, with nothing persisted. Trees
are also 25% taller by request (conifer 6.0 → 7.5, bare broadleaf 5.2 → 6.5).

The three new meshes, all generated at the budget with the corrected settings:

| prop | tris | split | comps | largest | w/h | `baseColor` |
|---|---|---|---|---|---|---|
| `tree-dead` | 4,784 | 1.93 | **1** | 100.0% | 0.47 | 0.5 uniform |
| `tree-conifer` | 4,880 | **1.27** | 2 | 51.2% | 0.34 | **none** |
| `tree-broadleaf-full` | 4,660 | 1.79 | 17 | 93.9% | 1.09 | 0.78/0.44/0.53 |

Three things worth carrying:

- **A reference that reads better FLAT can remesh far worse.** The conifer was re-rolled twice. The
  lumpy tiered spruce outline — the one that looks like a conifer on screen — came back **38
  components, split 4.70**, worse than anything shipped in this repo, because TRELLIS made each tier
  its own blob. The smooth cone, which was nearly rejected for looking geometric as a 2D image, came
  back split **1.27**, the cleanest tree here. From a camera 18-55 units up the two silhouettes are
  indistinguishable. Both references are in `Unused/` for comparison.
- **`h` is width, again.** `tree-broadleaf-full` has the widest bbox of the four at **1.09**, so it is
  held to `h` 5.8 for 6.3 world units across, where the bare broadleaf at 0.84 takes `h` 6.5. The
  conifer at 0.34 is narrow enough to take the full 7.5 and still draw only 2.55 across.
- **The conifer's teal correction is gone, and the fix moved upstream.** The retired mesh baked at
  41/84/69 — twice as green as red — and needed the repo's first per-channel `baseColor`. This
  reference asks for "muted desaturated dark grey-green, mid-value, not vivid green" in as many words
  and bakes at **54/58/50**: near-neutral and already inside the prop family's 46-52, so the entry
  carries no `baseColor` at all. Correcting saturation at the source beats correcting it at the bake.
  `tree-dead` keeps a **uniform** 0.5 rather than a per-channel fit on purpose — it bakes warm at
  80/68/55 and is the one warm thing in the area, which a per-channel fit would neutralise away.

Also landed, both small: `TILE_ROCK` is **unwalkable** now, matching the four tree tiles beside it and
still see-through like them — it is written only by `generateWilderness`, and `WildProps` stands a
boulder on every one of those cells, so a walkable rock was geometry the player walked through.
Nothing to migrate: walkability is a static table, entry re-tests it through `findEmptyLocation`, and
movement tests the target cell. And the same two rock glbs are scattered again at a tenth of their
height (619 loose stones) on open cells only — `Models` caches one template per path, so a second row
over the same file is a second `InstancedMesh` and not a second load.

## How much geometry the corrected TRELLIS settings absorb, and the albedo wall behind it

The gappy-bush probe showed the corrected settings (`mesh_cluster {1,0,1,PI/2}` + `remesh_project`
0.9) taking a reference of discrete leaf clumps from 96 components to 1. That reference was only
*dark gaps*. `wild/bush-bramble` was generated to find the ceiling: a lace of interlocking arcing
canes with real see-through holes — thin structure **and** topological holes, hard on both axes.

| reference | tris | split | comps | largest |
|---|---|---|---|---|
| gappy bush (dark gaps, no thin structure) | 4,777 | 1.68 | **1** | 100.0% |
| bramble (thin canes + real holes) | 4,894 | **2.59** | 16 | 94.2% |

**Topology holds.** 15 of those 16 components share 5.8% of vertices and are detached cane *tips* —
the same speck pattern `tree-broadleaf-full` ships with at 17 / 93.9%. The plan view is a correct
radial bramble and the holes are real. But split **2.59** is the worst in this repo, so this prop can
never be decimated offline and has to keep arriving at the budget. So the line is: the settings
absorb dark-gap art completely, thin interlocking structure only mostly.

**The albedo is where it actually fails, and it is a new mode.** A prop dense enough to occlude
itself bakes that occlusion into its base colour. From the same reference value a conifer bakes at
**0.79x** and the bramble at **0.44x** — 30/29/29 against the prop family's 46-52.

Neither existing knob reaches it:

- `baseColorFactor` is a factor in `[0,1]`. It only multiplies **down**. There is no up.
- Repainting the reference does not either, and that was measured rather than assumed. The same
  image at subject p50 **53** baked 24/23/21; lifted to p50 **68** it baked 30/29/29 — a 28% brighter
  reference moved the bake 29%, proportional. Reaching 46-52 that way needs a reference brighter than
  the flat `#5a5d63` backdrop TRELLIS segments it against, which costs the segmentation.

So the correction moved to the bake: **`lift` in `models.json`**, a gamma on the base-colour MAP
(`out = (v/255)**lift`, `<1` brightens), same name and meaning as `textures.json`'s. It is the missing
inverse of `baseColor`, runs full-res before the resize like `texSrc` does, and is folded into
`last_sig`. `lift` 0.78 lands the bramble at **48/47/47**, inside the band.

Two things that rode along. The reference lift was done **in code, not by re-prompting** — a gamma on
the subject plus a re-lay on a truly flat `#5a5d63` (gpt paints a vignette: measured backdrop 82/86/91
against the 90/93/99 it was asked for). That holds the composition fixed, so the two bakes differ by
value alone, and it is free. And the MR map came back **mean 0/206/128, metalness peaking at 198** —
cyan, metallic across canes and leaves alike — where `bush-low` from the same generator peaks at 18.
`dropMR`. Re-read the MR map on every regeneration; the verdict never carries forward.

Shipped as the second `TILE_BUSH` model, picked per cell by hash at `BRAMBLE_CHANCE` 0.35 (measured
35.7% over a 100x100 grid, and 54.6% agreement with the rock split where independence predicts ~55%).
Its bbox aspect is **2.86**, the widest prop out here, so `h` 1.0 still draws 2.9 world units across —
a sprawl beside `bush-low`'s rounded scrub, which is the shape difference doing the work.

## The wilderness ground stops being a plane (`render.wild.WildHeight`)

One analytic height field — two out-of-phase sine octaves, wavelengths **72.8** and **29.0** world
units — sampled by every builder out there and by the whole actor layer. Phase-offset off the
persisted `area.id`, so two wilderness areas are not the same landform and each keeps its own hills
across saves. Measured at `RELIEF_AMP` 1 over a 400x400 sample: **3.80 units peak to trough** (half a
conifer), slope p50 **0.110** / max **0.164**, per-cell step p50 **0.272** / p95 **0.545**. Cost at
the gameplay camera: **72 calls / 334k tris**, from 73 / 309k flat — no new draw call, the extra tris
are the patch subdivision below. Verified in the running game at a grazing free-cam pose: the horizon
curves, props sit flat on the slopes, no chunk seam.

**The normal cannot be computed, only derived — and the reason is chunking, not cost.** The ground is
one mesh per `Chunks.CELLS` block, so `computeVertexNormals` on a block averages only the faces *that
block* holds; every vertex on a block edge is missing its neighbour's triangles, its normal turns, and
a lit seam runs down every chunk boundary in the area. The field is closed-form differentiable, so the
normal comes out of `normalize(-dh/dx, 1, -dh/dz)` and cannot know a block exists. Checked against a
central difference at 160k points: **max error 4e-11**, unit length, up-facing, perpendicular to both
tangents. Amplitude is a **slope** budget, not a look — every consumer downstream pays in slope.

**A cell-sized overlay quad is a CHORD, and lifting it does not fix that.** `WildPatches` laid one
flat quad per cell; over relief the ground bulges through its middle by the sagitta — **0.038** units
for the tight octave alone, against a `PATCH_Y` of 0.02. Lifting the layer clear of the bulge floats
its *edges*, where the two surfaces do agree. Subdividing to the ground's own `SUB` lattice is the
only answer that is right at both. `SUB` stays 2: the tighter octave still gets 14 samples per period,
which retires the deferred `SUB` sweep.

**`WorldCtx.floorY` answers per CELL, and that is the standing limit.** Relief reaches the actor layer
through one new hook, `WorldCtx.ground` — a world-space `(x,z) -> y` that `WildArea` points at the
field and that `World`/`SewerArea` clear. `floorY(col,row)` samples it at the cell centre, so an actor
is exact in the middle of its cell and steps a p50 of 0.272 crossing into the next (the city already
steps 0.2 over a curb). Anything holding a real world position takes `WorldCtx.floorYAt(x,z)` instead
— today that is the slime trail, a long thin ribbon that would lose whole segments to the depth test
where it dipped under a hillside. Props sink by `h * r * slope`, which is exactly the drop from centre
to downhill edge: half-buried reads as a rock, floating reads as a bug. No tilt — `PropPlace` carries
a yaw and nothing else, and a tree grows vertical whatever it stands on.

The player ring was the first thing the cell answer broke, and it is the shape of the whole class. It
already sampled the **highest** of its 4 footprint corners, for exactly this reason on city curbs —
but each corner was snapped to its grid cell, and the ring radius is 0.448 of a cell, so with the
player anywhere near a cell centre all four corners land back in that same cell and the ring reads one
flat height. Measured: ring at 0.766 + 0.06 lift, ground under its uphill arc peaking at **0.973** —
buried by 0.207, over 3x the lift, and the arc clips. Sampled by world position the max comes out at
`h + rr * (|dh/dx| + |dh/dz|)`, which is always >= the disc's true peak `h + rr * |grad|`, so it errs
by floating — the side this is allowed to fail on. `PathLine` does not have it (Catmull-Rom through
cell centres, so it already tracks the surface) and neither does `TacticalGrid` (max of adjacent
cells, so its crosses float rather than sink).

## A canopy has a CLEARANCE, and it is not the tree's height (`wild/tree-broadleaf-full`)

The player walked head-first into the foliage. The tree was 5.8 world units tall against a 3.0-unit
actor billboard, which sounds like plenty — but its crown skirted down to **~22%** of its own height,
so the leaves an actor meets were at **1.3** units. Height is not the number. The number is where the
crown FLARES, measured by binning the glb's vertices along Y and reading the radius per band:

| mesh | trunk holds | crown flares at | underside at its `h` | bbox w/h |
|---|---|---|---|---|
| original (`Unused/…-lowcrown`) | — | ~0.22 | 1.3 @ h 5.8 | 1.09 |
| parasol (`Unused/…-parasol`) | 7-8% of max radius to 0.45 | 0.55 | 3.58 @ h 6.5 | 1.10 |
| shipped | 13-16% to 0.30 | **0.35** | **3.32 @ h 9.5** | **0.71** |

**The parasol is the entry worth keeping.** Asked for a crown "clearly wider than it is tall", gpt
delivered exactly that: a 45%-deep disc on a stick 1/14 the crown's width. It cleared the player
perfectly and read as an **umbrella** from every camera angle — a field of them looked like mushrooms.
Clearance was fixed and the prop was still wrong, which is why "does it clear the actor" is not the
whole acceptance test for a tree. Before it, asking for a "compact rounded canopy" on a tall trunk
gave the opposite failure: a narrow lollipop at aspect **0.35**, the conifer's silhouette, on the one
tree of four whose job is to be the broad one.

What works is naming all three fractions at once: thick bare trunk through the bottom 40%, crown a
deep rounded dome in the top 60% and about half again as wide as it is tall, whole tree taller than
wide. That landed 4,866 tris, split 2.82, **20 components at 91.8%**, MR pure green (re-read, not
carried forward), and aspect **0.71**.

**Being tall is not what costs footprint — the bbox is.** At 0.71 this is now the narrowest-for-its-
height tree of the four, so h **9.5** draws only **6.7** world units across: *less* than the parasol
took at h 6.5 (7.15) and barely over the original's 6.3 at h 5.8. It is the tallest prop in the area
by a wide margin, which drags `PROP_CULL_R` 7.0 → 9.0 with it — `Models.cull` tests one sphere radius
for every batch, so the tallest prop sets it or that prop pops in at the frame edge. Gameplay-pose
cost went 72 calls / 334k tris → **76 / 406k**, the extra being instances the wider cull keeps.

### …and then it came out covered in coloured dots

Pure cyan, magenta, yellow and green specks all over the foliage. Not a shader problem and not the
generator's: the **2048 source atlas is clean** (0.001% of texels above saturation 0.75, and every one
of those is bark brown), while the **built 512 had 2.949%**, with the extremes at literal `0,255,255`
and `255,0,255`. So `make models` was making them.

The cause is one channel nobody asked for. `wild/tree-broadleaf-full` is the **only prop of 23** whose
base atlas arrived carrying an alpha channel — 35.4% of its texels at alpha < 8, the UV gutter. Every
other prop measures ~0%, which is why this had never shown up. That channel is not dead weight, it is
a live trap: `textureCompress` resizes through sharp, which **premultiplies, averages, and
unpremultiplies**, so a 4x4 block that is mostly gutter comes out with an averaged alpha near 1/255 and
its colour divided by that. The proof is exact — **100%** of the blown texels had alpha < 128, mean
alpha **2**, min **1**. The same bug also darkened the whole map, 85/126/84 -> 73/110/72, which had
gone unnoticed behind the dots.

The fix is in `tools/models.mjs`, last step before the resize: flatten alpha out of an OPAQUE
material's base map. **`removeAlpha`, never `flatten({background})`** — TRELLIS had already dilated the
chart colour into the gutter (its mean rgb matches the atlas mean exactly), so the channel was the only
thing wrong and compositing would have thrown that dilation away. Rebuilt: **0.002%** and mean
85/126/85, the source to within a digit.

Two things generalise. **A prop's source atlas can be perfect and its built one wrong** — every number
`propstat` reports reads the SOURCE, so none of them could have seen this; when a prop looks wrong in
the game and measures clean, measure the built glb. And the guard is scoped to OPAQUE-material base
maps because that is where it was measured and where dropping alpha is safe by definition; a prop that
genuinely needs MASK or BLEND would still explode, and near-zero alpha in its atlas is the tell.
`sewer/bags` (98.8% under alpha 128) and `wild/rock-boulder` (38.9%) also carry alpha and are NOT
affected — nothing near zero, so nothing to divide by.

## Half the grass was dark, and three had been undoing the trick that stops that

The wilderness grass came out in two populations — pale yellow-green tufts and near-black ones,
interleaved at random across the field. **Debug key `1` settled it in one screenshot**: under WYSIWYG,
which hides every light and adds a flat ambient, every tuft is the same pale green. So the split was
never albedo, and nothing in the texture, the `lift` or the `alphaTest` was involved.

`WildGrass.tuft` writes its normals pointing **straight up**, not out of each quad's face. That is a
deliberate lie and the header already explains why: a vertical quad lit by its true normal goes black
the moment it turns from the moon, and a field of them flickers as the camera orbits. What the header
did not say is that writing the normal is only half the job. The material is `DoubleSide`, and three's
`normal_fragment_begin` does:

```glsl
float faceDirection = gl_FrontFacing ? 1.0 : - 1.0;
vec3 normal = normalize( vNormal );
#ifdef DOUBLE_SIDED
	normal *= faceDirection;
#endif
```

So every **back-facing** fragment got `(0,-1,0)`: no moon term at all, and `getHemisphereLightIrradiance`
sampling the light's GROUND colour instead of its sky colour. Which of a tuft's two crossed quads faces
away is a property of the VIEW, so the dark half reshuffled as the camera turned — the exact failure
the up-normals exist to prevent, reintroduced by the engine underneath them.

The fix is one line appended after the include, `normal *= faceDirection;`, which cancels the flip
exactly (it is ±1) and lands before `lights_fragment_begin` takes its `geometryNormal = normal`, so the
moon and the hemisphere both see the sky normal. Measured over one pinned pose: green-leaning pixels
**0.17% → 0.44%** of the frame (2.6x more grass reading as grass) and frame mean luma **11.80 → 14.22**.

**The trap generalises to any material that lies about its normals.** For a normal that matches its
face the flip is correct and is exactly what it is for; it only bites where the normal was chosen to
disagree with the geometry. `WildGrass` is the only such material in the renderer — every other
`DoubleSide` Lambert here (city ground, lawns, gables, roof details, door covers) writes face-true
normals. And it is correct ONLY while the material stays `DoubleSide`: under `BackSide` the added line
would flip every fragment instead.

## The terrain band decides what a wilderness area IS (`render.wild.WildBand`)

`map.Terrain` has painted three bands over the region map since Phase 0 and nothing but area NAMING
read them: a forest tile and a mountain tile generated the identical scatter and rendered the identical
landform, so the map promised a landscape the area did not deliver. `Terrain.sample`'s own header said
it was exposed "because the wilderness generator wants the VALUE, not just the band" and it had **zero
callers**. It has two now, plus a new `Terrain.depthAt` — how far into its own band a tile sits, 0 at
the threshold and 1 at the extreme.

**The split is forced, and it is the reusable part.** Density has to be decided at GENERATION
(`AreaGenerator.generateWilderness`, persisted, `isGenerated`-gated so areas already visited keep their
mix) because walkability follows the tiles — a renderer that simply drew fewer trees would leave blocked
cells looking like open ground. Everything else is render-side (`render.wild.WildBand`, one style record
per band) and therefore applies retroactively to every wilderness area in every save.

| | forest | plains | mountain |
|---|---|---|---|
| cells with a prop tile | 10% | 2.5% | 7% |
| tree / bush / rock | 50/35/15 | 20/55/25 | 15/25/60 |
| ground | leaf litter | turf | scree |
| relief amp (edge → deep) | 0.60 → 1.00 | 0.60 → **0.30** | 1.00 → 1.80 |
| tufts × height | 2 × 1.0 | 3 × 1.3 | 1 × 0.8 |

Measured on one save, mid-area, same zoom, window focused, against Phase 2's 72 calls / 334k tris:

| band | calls | tris | submit | GPU | FPS |
|---|---|---|---|---|---|
| plains | 73 | 314.6k | 1.8ms | **6.95ms** | 60 |
| forest | 62 | 444.5k | 1.2ms | **4.92ms** | 60 |
| mountain | 52 | 501.8k | 0.99ms | **7.20ms** (peak 7.62) | 60 |

All three lock 60 with the GPU under half of a 16.7ms budget, and **the triangle count does not order
them**: the forest draws 41% more triangles than the plains and costs 2ms LESS. Plains runs 3 grass
tufts per cell against the forest's 2, and an alpha-tested tuft is fill — two crossed quads over the
whole frame — where a canopy is opaque geometry that depth-rejects. The knob to watch out here is
`tufts`, not the trees.

Three things worth keeping:

- **The mountain's relief is the one number to re-check if an actor ever reads as climbing stairs.**
  At amp 1.8, sampled over the 100x100 grid at cell centres: **6.84 units peak to trough, slope p50
  0.198 / max 0.296 (16.5 degrees), per-cell step p50 0.452 / p95 0.983 / max 1.068**. `WorldCtx.floorY`
  answers per CELL, so that step is what an actor takes crossing one — a third of its own billboard
  height at the p95, against the city's 0.2 curb. It looks right walking; the cap if it ever does not is
  `reliefMax` 1.5.
- **The plains relief row is REVERSED (max 0.30 below min 0.60) and that is not a typo.** Plains is the
  band with no character, so `depthAt` peaks where the field is FLATTEST; its deep end must be the
  gentlest ground and its edge, where the hills start, the roughest. Caught by reading the value back
  out of `WildBand.reliefAmp` over CDP, not by looking at the screen.
- **The band has to be set before the MODEL is built, not in `build()`.** `WildModel.fromArea` turns
  tile IDs into prop indices and is evaluated as the ARGUMENT to `WildArea`'s constructor, so a band set
  in `build()` would be one area late. `WildBand.use(game)` runs in `View.showWild` instead.
- **Forest density is set by the CAMERA, not by the fiction.** 0.12 / 60% trees put the actor under a
  crown most of the time — there is no occlusion fade out here, `render.Occlusion` buckets buildings and
  a wilderness area has none. 0.10 / 50% still reads as a wood against the plains' 0.025 and took 33%
  of the triangles off with it (662k → 442k).

Weighted arrays replaced the one-off chance constants: `bushes`, `rocks` and `trees` are lists of PROPS
indices where repetition IS the weight (`list[hash % list.length]`), so one mechanism covers all three
and `BRAMBLE_CHANCE` is gone. Finding one area per band to test is free from CDP —
`parasiteHx['map.Terrain'].bandAtArea(seed, x, y)` is a pure static and the seed reads out of
`host.save.read(0)`.

## A fallen log came back in three pieces, twice, and it was the ART

`wild/log-fallen`'s first reference was a trunk with a torn root plate of thin broken roots and a long
strip of bark peeled off to bare wood. TRELLIS returned **3 components, largest 54.3%** — two big blobs
of ~26k and ~22k verts, i.e. the object in halves, not a speck cloud. A re-roll on a fresh seed
(everything else identical, $0.01) came back **3 / 55.8%**: reproducible, so it was not the roll.

Repainting the subject as ONE plain solid trunk — same bark all over, no peel, no roots, "no separate
parts of any kind" in the prompt — came back **1 component / 100% / 1.25 split** in a single run.

**So the settings-first rule still holds, but its second step is a cheap re-roll before a repaint.** The
corrected `remesh_project` / `mesh_cluster` defaults are what took the gappy bush from 96 components to
1; they cannot help a reference that paints two materials meeting along a hard edge. A dark gap in the
art becomes air; a hard value break along a silhouette can become a SEAM.

The pair also settled the two decimation routes against a scatter count:

| prop | split | route | tris | tex | texels/tri |
|---|---|---|---|---|---|
| `log-fallen` | 1.25 | 100k master + meshopt | 3,112 | 384 | 47 |
| `rock-outcrop` | 1.45 | generated AT budget | 4,981 | 512 | 52 |

The outcrop's 100k master decimated fine by every number here — 1.45 split, 1 component — and still had
to be thrown away: meshopt floored it at **7,670** tris (error 0.05, flat to 0.3) and the mountain band
scatters ~200 of these per area, 1.5M triangles before culling against a whole area's 334k. So the
ratio said yes and the SCATTER said no. `tex 384` on the log is the same lesson from the other side:
3,112 tris at 512 would be 84 texels/tri, a map twice as large as the geometry can show.
