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

## The wilderness gets two things that work like walls (`TILE_ROCK_LARGE`, `TILE_TREE_CLUSTER`)

Everything an open area blocked was one cell wide and **see-through**: `TILE_ROCK` and the four tree
tiles are `walkable 0 / seeThrough 1`, so there was no cover out there — you walk around a tree and you
can always see past it. Two multi-cell obstacles now: a **2x2 boulder** in the mountains (8 per area,
depth-scaled to 9 at the extreme) and a **2-3 x 2-3 tree thicket** in the forest (7 → 8, measured at 48
cells over 8 blobs, one of every requested shape: 2x2, 2x3, 3x2, 3x3).

**The gameplay half cost no table edit.** Row 0's spare IDs 12-15 already read `0/0` in both
`tiles.Default` tables — the `TILE_BUILDING`/`TILE_WALL` profile — so naming them was the whole change.
Verified at the accessor `AreaGame.recalcTile` actually calls: `Default.prototype.canSeeThrough(12)` and
`(13)` are both false where `ROCK(3)` and `TREE1(5)` are true. Blocking verified end-to-end in-game
with a control in the same key: from (46,40) `ArrowUp` into the rect does not move, `ArrowDown` does,
and column 48 — one past a rect at cols 46-47 — walks through. No 2D art: a wilderness area always
renders in 3D and `AreaView.draw` early-outs, so the tile pass, LOS overlay and minimap never run.

**The one-cell margin is what makes a rect recoverable without persisting it.** Only the rock needs its
rect back (it is one model over four cells), and `isBigObstacleClear` refusing to place within one cell
of another means "no rock left of me and none above me" names each 2x2 exactly once. Two allowed to
touch would read as one L and put the model on the wrong cell.

**The thicket costs zero draw calls and needed no new art**, because `WildProps.small()` had already
established the idiom: a second pass appending into the same `places[]` arrays. A thicket cell gets a
REAL tree index in `m.prop` rather than a sentinel, which does three things with one line — the
existing scatter plants its tree with the yaw and scale spread it already deals, and the cell loses its
grass and its pebbles the way any prop cell does. The pass only adds the **understorey**, which is what
a cell blocking SIGHT actually needs: a stand of bare trunks is a thing you see between however many
there are. Cells with no prop of their own but covered by a neighbour take a new `WildModel.OCCUPIED`
(-2), and the two suppression tests move from `>= 0` to `!= -1`.

**`r` turned out to be exactly the knob a multi-cell prop wanted.** `sit()` sinks a prop by
`h * r * slope` so its downhill edge meets the ground, and `r` is documented as footprint radius over
`h` — so setting the rock's `r` to 0.84 against `h` 5.0 makes `h * r` a whole CELL and the existing
function is already right for an object two cells wide. No new seating code. `sit()` did gain an
optional scale: the thicket plants trees at 0.5-0.75 and a sink computed for a full-grown one buries
them (the scatter's own ±20-30% is close enough to 1.0 to leave alone).

Measured, focused, both bands at 60 FPS with ~14.5ms idle — nowhere near a wall. Forest **56 calls /
665.5k tris / GPU 7.4-7.9 / submit 1.1**; mountain **51 / 418.2k / 5.1-5.6** away from a boulder and
**70 / 754.6k / 6.1-7.3 / submit 1.2-1.4** with several in frame. `programs` is **95 in both**, so the
new glb compiles no permutation the wilderness did not already have. These are new areas at new poses
and are NOT an A/B against Phase 3's 62/444.5k and 52/501.8k, which were different areas.

## A 2x2 boulder's reference is a CAMERA ANGLE problem, and the components gate has a blind spot

`wild/rock-large`, generated at 2k on request and shipped at 10,000 tris / `tex` 1024.

**The pancake failure is real and it is the reference's camera, not its proportions.** The first roll
asked for a boulder "seen from a low three-quarter angle... roughly twice as wide as high" and gpt drew
it from well above; its 2D bbox measured a promising 1.87 and it came back **0.845 x 0.317 x 1.001 —
widest/height 3.16**, a slab you could see over. Same failure `wild/bush-low` hit at 0.985 x 0.040 x
0.936. Re-prompted as a strict side elevation at horizon height ("the full height clearly visible as a
tall silhouette, almost none of its top surface visible") the same subject came back **0.973 x 0.597 x
1.001 = 1.68**, and at `h` 5.0 that is a boulder 8.4 units across and taller than the 3.0 actor
billboard. The elevation looked WRONG as a 2D image — a flat cutout with no depth cue at all, nothing
like `rock-cluster`'s three-quarter reference — and was baked anyway, because **a re-bake is $0.015
against $0.43 for another reference**. That is the order those two steps belong in, and the first
reference is kept in `Unused/` as `rock-large-a`.

**`propstat` called both bakes REJECT and was wrong both times.** 2 components at 50/50 reads exactly
like a blob cloud by the shipped gate (count, and largest share ≥90%). It is not: both components span
the ENTIRE bbox, their mean radii agree to 0.6%, and every vertex of one is within **0.34% of the bbox
diagonal** (p50 0.0051 against an average edge length of ~0.008) of a vertex of the other. It is ONE
closed surface partitioned into two vertex-disjoint patches along a seam. The contrast settles it:
`rock-boulder` is genuinely 1 component, and `rock-outcrop`'s second piece is a **70-vert speck 29% of
the diagonal away**. The gate reads component count and largest share and cannot separate "split along
a seam" from "flying apart" — check whether the pieces occupy the same shell before believing it.
Split is **1.09x**, the cleanest subject in this repo (below `rock-boulder`'s 1.11x), and meshopt hit
10,000 exactly.

**`tex` 1024 at 10k tris is ~105 texels/triangle, deliberately double the 43-55 band.** Texels per
triangle is a proxy for texels per screen PIXEL, and this prop is 8.4 world units across against
`rock-boulder`'s 3.3 — so it carries 16x the boulder's texels over ~7x the screen area, less than twice
as dense per pixel. The rule cut `rock-boulder` from 165 to 42 because a small prop cannot show its
map; the largest prop in the area is the case where it can.

**And its `baseColor` went the opposite way to the boulder's.** `rock-boulder`'s note says a large
smooth upward face catches the full moon term and has to sit BELOW the arithmetic (0.15 against ~0.25),
so this one went in at 0.17 — and measured on screen it was **the darkest thing in the frame**, linear
luma 0.00204 against the ground's 0.00495, the small boulder's 0.00251 and the outcrop's 0.00299. A
hole, not a rock: the sewer-valve failure. `baseColor` is a linear multiply, so 0.00204 → 0.00300 asks
for x1.47 and **0.25** landed it at **0.00318**, just above the outcrop, top of the rock family, which
is where the biggest rock belongs. The overshoot on the prediction is the tone curve. A domed mass
shows the camera mostly its sides; the boulder's rule was about a face pointing at the moon, and it does
not generalise by size.

## The tunnel vision mask is now everyone's (`render.sewer.SewerMask` → `render.world.VisionMask`)

The wilderness's two large obstacles gave an open area its first cells that block SIGHT, so the sewers'
LOS polygon had somewhere to cast from. Nothing in the algorithm was underground-specific — it sweeps
`game.area.canSeeThrough` over a cell grid — so the port needed exactly two things passed in: the
per-area-kind tuning (`render.world.VisionMaskOpts`, presets `SewerStyle.MASK` / `WildStyle.MASK`) and
the STATIC "is this cell a blocker" predicate the green channel is painted from. 14 call sites, and the
GLSL prefix went `sewerMask*` → `visMask*` with it.

**Only two of nine fields differ, and both are derived rather than tasted.** `r` 14 → **20**: the sweep's
square range bound has to sit off screen, and `CameraRig.maxFootprintCells` for `CAMERA_WILD` at 16:9 is
**305 cells** reaching 7.5 ahead / 5.4 behind / 13.4 to the side — **15.4 at the far corner** against the
sewer camera's 12.2. At 14 the bound would have been visible, reading as a vision radius the game logic
does not have (`AreaGame.isVisible` is unbounded). `hidden` 0.18 → **0.10**, inverted from the tunnel's
reasoning: underground a hard black empties the frame because the frame IS what is hidden; out here it is
one wedge behind one rock in a lit field, so it can afford to read as a real shadow.

**Cost is the opposite of what the canvas size suggests, and this file already said why.** A rebuild is
FLAT in canvas area — every part except `fadeCell`, which scales with lit BLOCKER cells, and an open area
holds ~15 blocker rects where a tunnel holds hundreds of wall cells. Measured on the live path (wrapped
`update`, 4 moves, 36 rebuilds, 800x720 canvas, player ending adjacent to a boulder): **median 0.40ms,
p90 0.70, max 0.80**, 9 rebuilds per move and then it stops dead. The sewer's own projection for a
600x480 level was ~1.5ms. Synthetic raster replay in the same renderer: habitat 168x112 0.68ms, sewer
600x480 1.14ms, wilderness 800x800 **1.34ms** — 34x the texels for 2x the time. The sweep is ~7.5k
ray/segment tests against a tunnel's ~250k. **0 draw calls, 0 passes, 0 geometry**, as underground.

**What it delivers is a cover cue, not an atmosphere layer, and that was measured before it was built.**
Over 1000 player poses against generated layouts: **1.20%** of the visible ground shadowed in a mountain
area, **1.28%** in a forest, **0.00%** on the plains, with only **~20%** of frames carrying any shadow at
all — but **up to 55%** of the frame standing beside a boulder. So it fires on contact. If it ever reads
as always-on out there, something has started writing opaque tiles that should not be.

**Verified live, in the mask's own canvas rather than off a screenshot.** Green channel: 36 marked cells
against 9 rock rects x 4 = 36, all 36 landing on the rects. Red along a ray through the near boulder:
`255, 0, 0, 0, 0, 0, 0, 0` at 2/4/6/8/12/16/19/22 cells, against a +90° control that stays `255` the whole
way — and the -90° control going dark at 12 is a SECOND boulder, not an artifact. Blue rim 64 at the
corner, 255 one cell in. The sewer branch was regression-tested headlessly off `SewerModel.demo()`:
**324 wall cells, 0 mismatch against `isFloor`**. `progs` 95 → 96, and the grass chain came out as
`wildGrassvisMasks` — `patch()` wrapping the wind hook instead of replacing it, which is the trap this
file already carries an obituary for.

**Rider, found while checking the ambush angle: `AreaGame.getSpawnRect` had no `'wilderness'` arm**, so
the largest grid in the game took the 2D canvas rect — the exact dilution that switch was written to fix.
Latent rather than live (`AREA_GROUND` declares `commonAI: 0`, so the turn spawner never runs out there),
and fixed with the one case arm. The ambush mechanism itself needed nothing: `findUnseenEmptyLocation`
already rejects any cell `isVisible` reaches, and before these obstacles a wilderness area had no unseen
cell to offer it.

## The region map's highway reaches the ground (`map.Highway`, `render.wild.WildRoad`)

`map.RoadPlan` has routed ROAD1 trunk roads across wilderness tiles since long before `AREA_GROUND`
became a 3D area kind, and the area never looked at them — the map drew a highway and the ground was the
same uniform scatter as anywhere else. Same class of lie as the terrain bands before Phase 0. An area the
map runs a road through now gets a **graded asphalt corridor**, a dashed centre line, a guard rail along
one shoulder and litter that thins with distance from it.

**Three things were free and one was not.** `Const.TILE_ROAD` (32) already existed and already read
walkable 1 / see-through 1 in both `tiles.Default` tables — row 2, one row below the two IDs the last
phase claimed — so no tile ID, no table edit, no 2D art. The corridor **persists as tiles**, so
`WildModel.fromArea` recovers its axis and offset from the road cells' own bounding box (the `rocks`
trick again) and the whole `generatorInfo` / migration / regenerate-on-entry section the original plan
carried simply evaporated. And the VisionMask needed nothing, `TILE_ROAD` being see-through.

**What was not free: the road plan is unreachable from area generation.** `roadPlanGrid` lives on the
`map.Image` at `RegionGame.regionMapImage`, which is in that class's `_ignoredFields` (never saved) and is
built lazily on the first region-map *view*; generating one allocates seventeen 832x832 grids. So this is
`map.Terrain`'s play a second time, with one difference — Terrain DUPLICATED the renderer's literals,
this **extracts** the decision. `RoadPlan.generateRoadGraph` calls `Highway.lines` passing its OWN `rng`,
so the shared draw stream is untouched; a headless caller passes a fresh `SeededRandom(mapSeed)`, which is
provably the same state (nothing consumes `rng` between `Core.initRandom` and the ROAD1 block —
`paintGround` hashes, and `paintGrainOverlay`'s 16k draws come after the roads). ROAD1 makes it small:
`walkRoad1` is dead straight, edge to edge, one plan cell wide, never overwritten, so the whole highway is
four numbers.

**That extraction can move every existing region map, so it was gated on a differential.** New
`Highway.lines` against a JS transcription of the original, over **970 seeds** at four blocker densities,
comparing all four outputs *and the final `rng.seed`* — **0 mismatches**, with all three internal paths
covered (clean early return 457, mid-loop reroll 220, fallback 83). The `rng.seed` is the load-bearing
half: it is what proves ROAD2-5, blocks, parcels and buildings still draw from the same stream.

**The halo frame is the trap, and it is worse here than for terrain.**
`RoadPlanGridOps.hasRoadTypeInRegionTile` takes FULL-CELL coordinates and does not add the halo itself —
every existing caller adds it by hand. Getting it wrong does not throw, it answers about the tile two up
and two left, which is exactly the ~40% disagreement `Terrain.bandAtArea` shipped with. `Highway.atArea`
takes region coordinates and adds `Core.HALO_CELLS` internally, once. Verified against the drawn map:
trunk at region column 16, branch on row 13 running right, matching the rendered region map tile for tile.

**The grade is analytic, derivatives included, because it has to be.** `WildHeight`'s ground normal comes
out of `gradX`/`gradZ` and never out of `computeVertexNormals` (per-chunk averaging would put a lit seam
down every block boundary), so a corridor term that skipped the derivatives would light the ground wrong
and sink props wrong. `h = f + w*(g - f)` with `g` the field sampled ON the centreline; measured live:
**on-road height spread 0.000** across the full 12-unit width with `gx` exactly 0, and **analytic vs
central-difference gradient error 0** on both axes over corridor, shoulder and far field. Every consumer
follows for nothing — mesh, patches, grass, `sit()`, actor feet, camera, `pickCell`, slime trail.

**The shoulder is what a level ribbon across falling ground costs, and it is the number to watch.** Over
a full mountain corridor, peak shoulder slope / worst per-cell step by ramp width: 2 cells 0.576 / 1.96,
**3 cells 0.494 / 1.69**, 4 cells 0.444 / 1.72, 5 cells 0.406 / 1.59 — against the natural ground's own
0.259 there. 3 takes the biggest single bite and 4 makes the STEP *worse*, because a wider ramp reaches
into steeper ground. This is a real embankment rather than a bug (a road cut has steeper batters than the
hill it crosses, which is also why the rail stands there); `WildBand.reliefMax` 1.5 is the cap already
left for it if a mountain shoulder ever reads as a cliff.

**Two render calls that went the other way to the patch layer next door.** `WildPatches` chunks because a
layer spans the area and would submit its whole blended fill every frame; a road is a STRIP — 3 cells
wide over 100 long is ~3% of the area, about 2,200 triangles of nearly no fill. Chunking it was shipped
first and measured at **TWELVE** draw calls on a 90-cell mountain area against one merged; **91 → 78 dc**
at the same pose. The dashes are one root mesh for the same reason. Patch seeding also had to be taught to
skip corridor cells explicitly: it marks off a pure cell hash and never consults `m.prop`, so unlike the
grass and the pebbles it does not get the `OCCUPIED` suppression for free.

**The dashes rendered, drew nothing, and it was WINDING.** They fired `onBeforeRender`, passed the frustum
(camera inside the bounding sphere), sat +0.03 above the asphalt, and stayed invisible through red
emissive, a 6-unit lift and `fog:false`. The corner order that gives normal +Y for an east-west road gives
**-Y** for a north-south one — swapping which world axis carries `along` reverses the triangle winding —
so `FrontSide` culled every dash on one of the two axes. One sign fixes it. The diagnosis only converged
after tinting the asphalt green proved the corridor itself was correct.

**Measured properly, as a controlled A/B in the SAME frame.** The area regenerates its scatter on every
entry (`generateWilderness` uses bare `Std.random`), so comparing two visits is worthless — instead the
road, dash and rail objects were toggled `visible` live on a focused 60 FPS window, interleaved
A/B/A/B x8, 28/30 samples, medians. Plains corridor, standing on the road: **ON 70 calls / 381,906 tris /
GPU 6.83ms / submit 1.69; OFF 66 / 178,722 / 6.61 / 1.60** — so **+4 calls, +203,184 tris, +0.22ms GPU,
+0.09ms submit**. The GPU interquartile ranges overlap almost completely (6.29-7.31 against 5.90-7.46), so
**the whole highway is not measurable in GPU time here**; frame sat at 16.69ms of a 16.7ms VSync budget
with 14.1ms idle. The 4 calls are asphalt + dashes + rail + the rail's shadow-pass draw.

**But the rail is 53% of the area's triangles, and its SHADOW is half of that.** 21 instances survive the
cull at 4,782 tris each, drawn twice — main pass and moon shadow. Toggling `castShadow` alone: **100,422
tris and one draw call, for no measurable GPU change** (6.15 vs 6.31, noise). Kept, because `tris` is an
inventory number and GPU is the cost — this file's own rule — and the moon shadow is what makes a prop
read as standing on the ground rather than pasted over it. Written down because it is the cheapest lever
in the area if the integrated-GPU baseline ever needs one: a 26% tri cut for a shadow you have to look for.

**Guard rail: the gate says REJECT and is wrong, for the third time in this file.** 11 components, largest
56.7% — but the top two are 27,691 and 17,327 verts, **92% between them**, and they are the beam and the
posts, which on a real rail are bolted rather than welded. That is the shipped conifer's 2-at-51/49 shape,
not the 96-at-24% blob cloud the gate exists to catch. Split 1.33x, and meshopt floors at **4,782** from
97,692 whatever `error` asks for (swept 0.05 and 0.3 for the identical count — the seam network is the
floor, not the cap, exactly the drum's shape). `tex` 512 = 54 texels/tri. Its `h` is set so the prop is
exactly CELL wide, so one segment per cell meets end to end; `jitter` is 0, alone in that table, because a
crash barrier is manufactured and a run at visibly different sizes reads as broken rather than varied.

**And its reference could not be measured the usual way.** gpt returned it at subject p50 121 against the
69-77 that bakes correctly, but `propstat`'s REPORTED p50 is meaningless on this subject: grey steel
against the `#5a5d63` backdrop sits so close in value that *brightening* it pushes parts out of the
distance-from-backdrop mask — coverage 6.8% → 5.4% between two lifts, and the reported p50 moved the wrong
way. Same too-close-to-its-own-key failure the grass texture hit. `lift`'s internal core mask (alpha > 0.9)
is the trustworthy one and was targeted at 73. Baked neutral at 112/110/109 with metal 255 across the whole
MR map → `dropMR` plus a straight `baseColor` darken, landing ~49 in the family's 46-52.

## Wilderness Phase 5b — both shoulders, a wandering road edge, and climbing the rail

Three follow-ups on the highway, all of them things the first pass got visibly wrong.

**The rail goes on BOTH shoulders now.** It shipped on one, chosen from the height field at the corridor
midpoint on the reasoning that a rail belongs on the side that DROPS. True of a hillside road, wrong here:
the corridor is GRADED, so `WildHeight` ramps it down symmetrically and *both* shoulders drop away from the
asphalt — the sampling was choosing between two sides that fall the same way, and a barrier on one side of
a two-lane highway read as unfinished. The second run **costs no draw call** (`Models.instanced` keeps one
`InstancedMesh` per PROPS row, so both runs are the same batch) and the placement pass got *shorter*: the
five lines that sampled the field and picked a side are gone. Measured live in a mountain area: **180
instances = 2 x 90, one batch.** The far run adds PI to its yaw so both face the road — correct by intent
and invisible in fact, since the glb is 0.05 deep against 0.40 tall and draws 0.2 world units thick.

**The straight border was TWO straight lines, and the louder one was the grass.** The asphalt ended on a
cell boundary, dead straight for the area's full ~360 units — but so did the grass, because `WildGrass`
gates per cell and all-or-nothing (a road cell is `OCCUPIED`), so the field ended in a wall of blades on
the same line. Blades measure 0.0660 linear against the ground's 0.0503 and stand up; the asphalt edge is a
value change on flat ground. A third mismatch fed both: `ROAD_RAMP` grades **12 world units** of embankment
each side while every *material* changed at 0 — the landform said embankment, the texture said ruled line.

**The alpha-ramp route was not taken, and that is this file's own result.** A cross-strip alpha ramp gives
every texel at a given distance the same alpha, so it trades a straight line for a *blurred* straight line
— which is exactly why `Textures.loadRampTexture` was deleted and why `SewerDetail.grime` moved to
hand-painted alpha. So the fix is **geometry plus density, and it needed no texture and no draw call**: the
asphalt's outer edge wanders (two sine terms of the along-coordinate, +/-1.1 world units, the two sides out
of phase so the WIDTH breathes rather than the ribbon sliding sideways), and grass thins to nothing over
the last 2 cells before it. Because the fade measures from the *wandering* edge, the thinning follows every
kink for free.

Two traps, both settled numerically in the live area rather than off a screenshot. **Tearing:**
`WildRoad.surface` pushes its own four corners per sub-quad with NO shared vertices, so every boundary
point is emitted twice and a per-vertex hash would have to agree with itself exactly — a smooth function of
the along-coordinate cannot disagree. Verified over the live road rect: **720 of 4,320 corners hit the
boundary branch, 362 distinct boundary points, 362 distinct (point, shift) pairs — bit-identical, tear
free.** **Agreement:** the grass gate and the asphalt geometry have to measure from the same edge or grass
grows under the tarmac. `WildRoad.edgeDist` sampled at 800 points sitting exactly on the wobbled edge
returns **0.000000000** at every one of them. With no road at all it returns 1e9, so an area without a
highway keeps every tuft it had — no behaviour change anywhere else.

**Climbing the rail is an animation and nothing else.** The rail stamps no tile (`placeHighway` writes only
`TILE_ROAD`, walkable and see-through), so the player has always walked straight through it and still does.
New `render.anim.Climb` lays a vertical arc over the ordinary slide — rise, **dwell**, drop — where the
dwell is the whole difference from `Leap`, whose pure sine reads as a hop; a vault has a beat at the top,
and from a camera 18-55 units up that beat is the only thing separating "climbed over it" from "jumped near
it". Verified on the real class: peak exactly 0.9, flat for 30% of the duration, ends at exactly 0, no
horizontal offset and no scale change.

**The trigger needed a channel, and `WorldCtx.ground` is its shape.** `Actors` is area-kind agnostic and
holds both cells (`a.col/a.row` and `e.mx/e.my`) right where `cornerBend` already special-cases a move —
so a nullable `WorldCtx.climbArc` set by `WildArea` and cleared by `World`/`SewerArea` beside `ground` is
the whole wiring. The rail lines are not stored: they fall out of the corridor rect and `RAIL_OFF`, the
same two numbers the instances are placed from, so animation and geometry cannot drift — and putting the
rail on **both** shoulders is what removed the side that would otherwise have had to be remembered. The
test is a sign change across the line, not a cell match, because the rail stands at a fractional offset.
Verified live at 33,45 with rails at 29.1 and 33.9: fires on **28->29 and 33->34 only**, both directions,
diagonals count once, along-road moves never. Gated on `a.fx == null`, so scenery can never clobber a melee
lunge or a leap onto a host — and `playFx` overwrites unconditionally, so a gameplay beat starting later
still wins.

**Not measured.** The window was raised but not focused (topbar read 1 FPS, and a raised CDP target is not
a focused OS window), so no GPU or submit number from this pass is trustworthy and none is recorded. What
*is* structural: the second rail run adds **0 draw calls**, and the edge wobble and grass fade add none
either — they are the same meshes with moved vertices and fewer tufts.

## The roadside litter was 3x too bright, and so was every city street

Putting the city's debris art on wilderness turf for the first time is what caught it — on asphalt there
was no bright ground beside it to be judged against. Measured through the real path (`Sprites.atlasTex`
→ `darkenCanvas`, RGB × `DECAL.debrisMul` in sRGB **bytes**, alpha untouched → sRGB texture on a lit
up-facing quad), over the content texels of `Const.STREET_DEBRIS_*`:

| | painted sRGB | delivered LINEAR at mul 0.55 | × turf | × asphalt |
|---|---|---|---|---|
| `STREET_DEBRIS_STATIC` (singles) | 199/193/187 | **0.1501** | 3.15x | 4.57x |
| `STREET_DEBRIS_TRANSFORMABLE` (clusters) | 208/208/205 | **0.1740** | 3.66x | 5.29x |

The art is painted at **paper values** and 0.55 was never going to reach the night palette from there.
Scale of the miss: the grass blades are **1.41x** the turf and `WildStyle`'s header calls them the
brightest thing out there bar the actor, while `city/ground-road-paint` — literal white lane paint —
measures **0.2402**. A crushed can was landing **62% of the way from the ground to a road marking**.

The method reconciles with every number that file already quotes, which is what makes the comparison
legitimate: turf **0.0476**, blades **0.0673** (header 0.0660), bare earth 0.0349 (0.0348), dead grass
0.0561 (0.0560), asphalt 0.0329. The one catch is that a texture with alpha must be measured over its
OPAQUE texels — whole-image gives the grass 0.0477, because it averages in the colour `bleed_alpha`
scrubbed into the transparent ones.

**`debrisMul` 0.55 → 0.40**, which delivers 0.0773 and, composited through the atlas's own alpha,
**1.27x turf / 1.57x asphalt** — just under the blades. Applied globally rather than per-area: the city
streets are that same asphalt and had the identical defect, and a wilderness-only value would have cost
a second cached atlas canvas (768x3072 RGBA, ~9.4 MB — `atlasTex` keys its cache on the mul).

**A measurement trap worth more than the fix.** Rows 41-47 are the ONLY alpha-capped block in the atlas:
they peak at alpha **127** where every other row of the 12x48 sheet peaks at 255. So litter draws at ~43%
opacity and can never read as solid whatever the mul does — and scanning those rows at the usual
`alpha > 128` reports them as **completely empty**, because nothing in them clears the threshold. Same
too-close-to-its-own-threshold failure as the guard rail's reference and the grass texture's chroma key,
and the third time this file has recorded it. `Sprites.contentRect` uses `alpha > 8`; so must any
measurement of this art.

## The wandering road edge was 2*PI too slow to see, and four other straight lines ran beside it

> SUPERSEDED by "The wandering road edge was retired for an alpha cutout, and it is not the ramp that
> failed twice" — the geometric edge is gone. The four-other-straight-lines half still stands.

The wobble shipped, ran, and changed nothing the eye could find. Two independent reasons, and the first
is arithmetic: `edgeWobble` divided the along-coordinate by `ROAD_EDGE_L1`/`L2` **raw**, so 37 and 13 are
not wavelengths but `1/k` — the real periods were `2*PI` times bigger, **232.5 and 81.7 world units, 58
and 20 CELLS**. Less than one cycle crossed the screen. Measured over the area's 400-unit span, the edge
was **never more than 3.27 degrees** off parallel with the cell boundary it was supposed to be leaving,
and wandered p50 **0.96 units** inside a 15-cell window. That is a straight line, and no amplitude could
have rescued it — raising AMP alone just slides a still-parallel edge sideways.

Fixed by making the two constants TRUE WAVELENGTHS (`along / L * 2*PI`). The first correction went to
46.0 / 15.0 at AMP 0.70 and **overshot into "psychedelic"** — which is the more useful half of the
entry, because of WHERE the overshoot was:

| | reach | edge angle | short wavelength | wander, 15-cell window |
|---|---|---|---|---|
| shipped (read as ruled) | 0.23 cell | 3.3 deg | 20.4 cells | 0.96 |
| first correction (psychedelic) | 0.33 cell | **21.2 deg** | **3.8 cells** | 2.45 |
| settled — AMP 0.50, L 62 / 27 | 0.25 cell | 9.5 deg | 6.8 cells | 1.71 |

**The reach is the same number in all three rows.** A quarter of a cell, a third of a cell — it never
mattered. What separates invisible from garish is the EDGE ANGLE and the wavelength that carries it: a
21-degree turn repeating every 3.8 cells is a scallop, deliberate and decorative, and no amount of
shrinking the amplitude would have made it read as weathering. So this knob is tuned against degrees,
not against world units, and the amplitude is close to a free variable.

The second reason is the more useful one. **Five straight edges ran down that boundary and the wobble
moved one of them.** `WildHeight.grade` (the graded flat band), `WildPatches` (per-cell `isRoad` gate),
`WildProps.small` (per-cell `m.prop` gate), and the persisted tree/rock scatter all still ended on the
ruled cell line — so a wobbling asphalt edge lay next to four ruled ones and the frame read as ruled.
Softening one line in a stack of five buys nothing; that is the transferable result.

Patches and pebbles moved onto `WildRoad.edgeDist` — patches per SUB-QUAD (quad centre, which biases
toward overlap, harmless because the asphalt sits above them at `ROAD_Y`), pebbles per instance. The
grade did NOT get a wobble: putting `edgeWobble` inside `WildHeight.blend` makes the blend vary ALONG the
corridor as well as across it, and both `gradX` and `gradZ` would need a cross term they do not have —
against the class's whole closed-form-differentiable contract. Instead the flat band is **widened by
`ROAD_EDGE_AMP * 2` = 1.4 units per side** (half-width 1.50 -> 1.85 cells), which is one addition and
guarantees the same thing: the asphalt reaches at most 1.34 out, the level ground reaches 1.40, so the
ribbon is never partly on the ramp. The extra half-cell of flat hides under the verge.

## Trees stood between the guard rail and the traffic lane, 100% of the time

Not intermittent — structural. The rail sits at `half + RAIL_OFF` = **2.4 cells** from the centreline
(29.1 / 33.9 in the live area), the asphalt edge at 1.5 (30.0 / 33.0), so the strip between them is cells
**29 and 33**. `WildProps.places` insets a scatter prop to `col + 0.35 .. col + 0.65` — which is *strictly
inside* 29.1..30.0. Every prop that rolls onto a shoulder cell lands in the strip; none can land outside
it. At band density 0.025-0.10 over two 100-cell columns that is **~5 (plains) to ~20 (forest)** per area,
and canopies draw 4.8-6.7 units across a 4-unit cell, so they overhang the traffic lane as well.

`AreaGenerator`'s scatter loop rejected only `cur == Const.TILE_ROAD`. `isBigObstacleClear` had applied a
**one-cell margin** around `TILE_ROAD` since the phase went in — its comment even says the margin "leaves
the shoulder cell free for the guard rail" — which is exactly why no boulder or thicket was ever caught
doing this and only the single-cell scatter was. The fix is that same margin, as `nearRoad(area, x, y)`.

**Not retroactive**, and for once that costs nothing: the scatter persists as tiles, so an
already-generated area keeps its shoulder trees — but the highway itself is unreleased, so no save
outside this dev session has a corridor at all. Verifying needs a never-visited wilderness area on a
highway tile.

## Every ground decal on the highway was drawn UNDER it, and the second bug hid the first

Roadside litter that lands on the asphalt is invisible. Measured live in one area: **54 of 109 spots
sit on the road and 47 of them were buried**, worst by 0.087 world units.

Two causes, stacked. The **lift ladder is out of order**: the wilderness lays four things over its own
floor — patch 0.02, patch 0.04, asphalt `ROAD_Y` 0.06, centre line `ROAD_PAINT_Y` 0.09 — and every
ground decal went down at a hardcoded **0.04**. The road is opaque and writes depth at
`ORD_DECAL − 1`; the decal batch is `transparent, depthWrite:false` at `ORD_DECAL`, so it loses the
depth test. And the **wrong sampler**: `Debris.draw` took its height from `WorldCtx.floorY(col, row)`
— the cell CENTRE — while placing the quad at `col + dx`, up to a quarter cell out. `floorYAt` exists
for exactly this and says so in its own header. Measured sampling error out here: mean 0.019, max
0.083.

**The interaction is the part worth keeping.** Fixing the sampler alone makes it *worse*: 47 buried
becomes **54**, because the seven that escaped only escaped by accident — cell-centre error happened
to push them high. Two defects of the same magnitude, one masking the other, and either fixed alone
looks like a regression.

`RenderConfig.DECAL.groundLift` 0.12 (clears the centre line, the tallest layer) plus `floorYAt` at
all three ground-decal sites — litter, batched blood, over-corpse blood. Re-measured: **0 of 54
buried.** `floorYAt` falls back to `floorY` when `WorldCtx.ground` is null, which is the city, so that
half is a no-op there.

## The wandering road edge was retired for an alpha cutout, and it is not the ramp that failed twice

The displaced boundary never worked and could not have. A vertex displacement of a straight line is
**single-valued** — one offset per along-coordinate, whatever drives it — so it reads as a wave or as
nothing. Three settings measured, and the edge ANGLE is the whole look while the reach is nearly free:
0.23 / 0.33 / 0.25 cell of reach for 3.3 / 21.2 / 9.5 degrees, landing on "invisible", "psychedelic"
and "still dumb". It is also coarse: boundary vertices sit `CELL / SUB` = **2.0 world units** apart, so
nothing under ~16 units of wavelength survives sampling, while `VisionMask` breaks its own straight
boundary at 8.2 and 2.8 units and gets away with it only because it runs **per-fragment**.

A mask cut is not single-valued. It leaves bays, spurs, detached slabs and pits, which is what no
vertex offset can produce. `WildRoad.edgeMask` bakes one: the nominal band filled white, then a pass
down each edge stamping circles centred ON the nominal line and jittered by their own radius — white
leaves a spur, black bites a bay, two whites overlapping outside merge into a slab, and one in eight is
pushed clear as an island. The mesh is emitted `ROAD_EDGE_MARGIN` = 1 cell wider than the road tiles so
there is material to carve, and `WildHeight.grade` widens with it so a surviving spur still stands on
level ground.

**This is NOT the ramp `Textures.loadRampTexture` and `SewerDetail.grime` each failed with.** Those gave
every texel at a given distance the same alpha, so the band had no shape of its own — and both were
fixed by putting the shape INTO the alpha, which is what this does. The earlier verdict row here read
that as a verdict on alpha generally. It was not, and reading it that way cost two rounds of tuning
sines.

The mask is **fitted to the corridor**, not laid over the area rect the way `CoverageMask` is —
0.098 world units per texel along and 0.083 across, against the 0.39 a 1024² area mask would give for
comparable memory. That is the opposite call to `CoverageMask`'s and for its own stated reason: its
field spans the area because its marked cells do, while a road is a strip. Bake cost 2.5 ms, 3 MB.

**`ROAD_EDGE_R_MAX` is the size of one deformity and it is the only number here anyone notices.** It
has to be judged against the ribbon AND against the screen: the road is 12 world units wide and draws
about 39 pixels per unit at this camera, so a stamp radius of 1.0 is a **39-pixel notch taking a sixth
of the road's width**. Three passes, and both of the first two were called out on sight:

| R_MAX | solid to | 50% at | gone by | band | read as |
|---|---|---|---|---|---|
| 1.8 | 3.0 | 6.1 | 10.5 | ±4 | ruined |
| 1.0 | 4.1 | 5.9 | 8.2 | ±2 | chewed |
| **0.4** | **5.29** | **5.96** | **6.79** | **±0.75** | an edge that has broken away |

The 50% crossing sits on the nominal 6.0 in all three — the band width is what changed, not the
centre. **Resolution and blob size move together**: a stamp needs ~2 texels of radius or `alphaTest`
turns it into a speckle, so shrinking the blobs from 1.0 to 0.4 required 2048 x 128 → 4096 x 192 in
the same change. Shrinking them alone would have deleted them rather than made them finer.

**The trap, and it is the third instance of one already logged twice.** `WildModel.mix` returns
`x & 0x7fffffff` — **31 bits** — so `h >> 24` leaves 0..127, and the first pass tested that window
against `ROAD_EDGE_SPUR * 1000` = 120. True 94% of the time. Every stamp came back a forced spur:
white and pushed outward, baking a solid white halo OUTSIDE the road with a black ring on the nominal
edge — the exact inverse of a crumbled edge, and a bug no screenshot would have explained. Fixed by
taking one fresh mix per quantity instead of bit-windowing a single draw, behind a `roll()` helper so
it cannot come back. Same too-close-to-its-own-threshold class as the litter alpha cap at 127 and the
guard-rail reference.

`ROAD_EDGE_STEP` must stay under `2 * R_MIN` or consecutive stamps leave gaps, and a gap is a stretch
of the nominal straight edge showing through untouched — so STEP shrinks with R_MIN, and the stamp
count with it (2,500 per bake at the shipped values).

**Then the cut became a GRADIENT**, and the reason is not only taste: at 0.098 world units per texel
against ~39 screen pixels per unit the mask is MAGNIFIED, so one texel is ~3.8 pixels and a hard
`alphaTest` shows texel stair-stepping along the edge. Blending removes that without touching the
shape. Two halves:

- each stamp is drawn as a radial gradient, solid to `1 - ROAD_EDGE_SOFT` of its radius then ramping
  to fully clear. **SOFT stays small (0.45) for the ramp reason all over this entry**: overlapping soft
  blobs average, and at this stamp density a wide rim would wash the band to one value per distance,
  which is the distance-only ramp that failed twice. Solid cores keep the union hard so only the outer
  boundary blends.
- `transparent = true` with `alphaTest` dropped to 0.12, which discards only the invisible tail.

Measured: the band is unchanged (solid to 5.38, 50% at 5.96, gone by 6.71) and **25% of texels in the
edge rows are genuinely partial** — peaking exactly at d = ±6.1 and falling to 0% partial both deeper
in and further out. The gradient softened the boundary in place rather than widening it.

Two orderings are load-bearing. `transparent` is set **after** `VisionMask.patch`, because patch reads
that flag to choose which mask branch it compiles — set first, the road flips to mode 'b' (alpha
scale) and hidden road fades out instead of darkening toward the fog, which is decal behaviour, not
ground behaviour. And the surface moves to `ORD_DECAL - 0.5`: blending puts it in the transparent
queue beside the two patch overlays at `ORD_DECAL - 1`, and at an equal renderOrder three falls back
to a distance sort, which between near-coplanar ground layers is a coin toss that flickers. The centre
line needs no such care — it is opaque, so it draws in the earlier queue and its depth writes reject
the asphalt behind it.

## The asphalt apron was zero cells wide for a release, and the fix was a verge

`ROAD_EDGE_MARGIN` shipped at 0.5 cells and **bought nothing**. The corridor is 3 cells, so
`WildModel.recoverRoad` returns `half = 1.5` and `centre = lo + 1.5`, which makes
`distTo = |row + 0.5 - centre| = |row - lo - 1|` an **integer, always**. `isCorridor` tested
`distTo < half + MARGIN` = `< 2.0`, and `2.0 < 2.0` is false — so the `distTo == 2` ring was excluded
and `isCorridor` returned exactly `isRoad`. Confirmed live: rows 71 and 75 (distTo 2) both false.

The mask meanwhile painted to `R_MAX * (1 + SPUR_PUSH)` = 0.88 units past the line, so:

- 25% of `ROAD_MASK_ACROSS`'s texels sat on geometry that does not exist;
- every stamp was centred **on** the mesh boundary, so half of each was discarded;
- **all white stamps were no-ops** — inside they whiten an already-white rect, outside they are
  clipped — which is 50% of stamps plus the whole `ROAD_EDGE_SPUR` mechanism at 100%;
- the edge could be **bitten, never grown**. Its outer envelope was a ruled line at exactly ±6.0 for
  360 units, and no mask value could move it.

Typical bite depth from the constants: `r ~ 0.3, jit ~ 0` → **0.17 units ≈ 6.6 screen pixels**, on a
12-unit ribbon. The gradient pass above then halved even that (`SOFT` shrinks each black core to 55%
of its radius) and `alphaTest` 0.12 kept 12%-opaque material, so the shallow bites stopped cutting —
which is why the straight edge came BACK after a change that was measured and correct on its own terms.

**MARGIN 1.0** admits the ring, and the cell gate is rewritten against the cell's NEAR EDGE
(`distTo - 0.5 < reach`) so a reach landing on an integer cannot silently drop a ring again. Both
reaches are half-integers on purpose. `ROAD_MASK_ACROSS` 192 → 256 because the band went 16 units wide
to 20 and 192 would have diluted R_MIN to 1.9 texels, under the ~2 a stamp needs.

**But the real answer was that the asphalt was being asked to do the wrong job.** A real road edge IS
straight, and every R_MAX looked wrong in its own way — 1.8 ruined, 1.0 chewed, 0.4 invisible — with
nothing in between, because a believable deformity on a 12-unit manufactured ribbon has to be small.
So a second ribbon went in: a **verge**, dirt shoulder from the asphalt edge out to 2.75 cells, with
the guard rail (2.4 cells) standing on it. The burden moves onto a boundary that is genuinely
irregular in life, where `VERGE_R_MAX` 1.1 is a bush-sized bite and reads as ground, not as damage.
Second win, free: a bay bitten out of the asphalt now exposes shoulder dirt instead of clean turf.

`RibbonOpts` carries the two ribbons' differences (art, tile, y, renderOrder, nominal half-width, mesh
reach in cells, stamp min/max/step, mask resolution, hash salt) — twelve values, of which eight would
have been bare positional floats. **Different salts**, or every bay in the asphalt gets a twin two
units out in the shoulder.

Measured on the baked masks, as the OUTERMOST texel over 0.5 alpha per along-column:

| ribbon | nominal | min | median | max | spread | % past nominal |
|---|---|---|---|---|---|---|
| asphalt | 6.0 | 5.23 | 6.02 | 6.72 | 1.48 | **53.3%** |
| verge | 11.0 | 8.97 | 10.94 | 12.91 | 3.94 | **49.4%** |

`% past nominal` was **0 by construction** before, with the max pinned at exactly 6.00. Mesh reaches
are 10.0 and 14.0, so neither envelope is clipped.

**The texture's `lift` had to be fitted TWICE, and the first pass is the lesson.** `wild/ground-verge`
as painted measured 0.0277 mean linear luminance — DARKER than the city asphalt it abuts at 0.0329.
`lift` 0.9 put it at 0.0381, a clean 1.16x on paper, and in the built frame the verge measured **12.6
against the asphalt's 11.3 — 1.11x, invisible**, which is exactly the failure `PATCH_ALPHA` already
records for the ground patches. 0.84 lands 0.0463 and reads **14.4-15.8 against 11.6-11.8, 1.28-1.36x**,
still under the plains turf's 0.0476. Judge a ground layer in the built frame against its NEIGHBOUR,
never as a linear number in isolation.

Four gates had to follow the verge outward or the straight line just relocates: the grass fade
(`WildGrass`, also HALVED to 1.0 cell — at 2.0 off a verge edge the corridor read 38 units wide
against a 12-unit road), the patch overlays (`WildPatches`), the loose stones (`WildProps.small`), and
the scatter exclusion (`AreaGenerator.nearRoad`, 1 cell → 2, generation-side so new areas only). The
graded flat band moved from the asphalt mesh to the verge's NOMINAL line — the ramp is a smoothstep so
its derivative is zero where it starts, and the outermost spurs still stand on flat ground without
paying the steeper batter a wider flat band costs.

Two stale comments died with it: `WildGrass` still claimed the thinning followed `WildRoad.edgeWobble`
(deleted two entries ago), and `WildArea` cited "1.25 cells" of level ground and a verge that did not
exist yet.

Cost at a pinned pose: **59 → 60 draw calls, 582.7k → 585.9k tris.**

## The tactical grid could not express a blocked cell, and 80% of them drew as open ground

`TacticalGrid` marks the shared CORNERS of walkable cells. A corner is marked when ANY of the four
cells touching it is walkable — so an obstacle with open ground around it has all four of its own
corners marked BY ITS NEIGHBOURS and draws identically to grass. Only a blob of 2x2 or larger drops an
interior corner, and one missing cross reads as nothing at all.

Measured live in a forest area, 33x30 cells around the player:

| | |
|---|---|
| non-walkable cells in window | 83 (22 rock, 44 tree, 17 thicket) |
| **that cost the lattice ZERO marks** | **66 / 83 (80%)** |
| corner marks emitted | 1043 of 1054 possible |
| so all 83 obstacles together cost | **11 marks** |

So the readout had no channel for impassability, and this is not a case where drawing FEWER marks
would have worked — the marks are on the corners, which the obstacle shares with open ground.

Fix is a second pass in the same `build()`: a dashed perimeter around every blocked cell (edges facing
a WALKABLE neighbour only — dashing shared edges too would fill a thicket's inside with a lattice),
plus a diagonal hatch. It borrows `RenderConfig.OCCLUSION.outlineDash`/`outlineGap` outright, which at
0.6 + 0.4 over a 4-unit cell is exactly four dashes per edge, so it is literally the dashed rectangle
`Occlusion` already draws around a faded building's footprint.

**The hatch is a WORLD-space line family (`x + z = k * HATCH`) clipped per cell, not a per-cell
pattern** — a stripe continues into the next blocked cell instead of stopping at the shared edge, so a
thicket hatches as one shape. `'diag'` was the one unclaimed fill in the game's pattern vocabulary
(`Sprites.patternWhiten` implements `diag|cross|scan|dots`; XRAY took `scan`, OBJMARK took `dots`).

`HATCH` shipped at 2.0 (3 stripes per cell) and that was WRONG in the frame: three long strokes read
as random scratches, not as fill, and the corner-to-corner stripe at 5.66 units visually beat the
0.6-unit dashes it was supposed to sit inside. 1.0 (7 stripes) reads as fill. Density, not width, is
what turns strokes into a pattern.

**City buildings are excluded**, and that is not a saving — it is a correctness fix. Their footprints
are unpaved (`Ground` paves road/alley/walkway only), so the dashes hang in midair under a solid wall
that hides them; and the moment the block DOES fade, which in tactical is the whole selected block,
`Occlusion` draws that identical rectangle a hair above them — two coincident HDR dash runs through
bloom. What is left is what actually surprises a player: burning barrels, unwalkable objects, blocking
decoration.

Two things fell out. `addEdge` became a general `addSeg` (per-endpoint height, arbitrary heading,
normal-widened) — the hatch is 45 degrees, and endpoint heights let a quad follow wilderness relief
instead of lying flat at the cell-centre sample. And `View.refreshObjects` now calls a new
`invalidate()`: the grid rebuilds only when the player's CELL changes, and an organ grown under a
standing player moves walkability without moving the player. That was invisible before (a blocked cell
drew like open ground either way) and this pass is exactly what makes it show.

Cost: **0 extra draw calls** — it all goes into the grid's existing single mesh and material. Geometry
predicted and measured to the quad, twice: 2306 cross + 1268 dash + 609 hatch = **4183 quads / 8366
tris**, against a 577.8k-tri scene.
