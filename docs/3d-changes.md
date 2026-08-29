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

## The facility becomes a 3D area kind (`render.facility`) — Phase 0

`AREA_FACILITY` is the first kind with an **outdoors and an indoors at once**: the city has buildings
and no interiors, the tunnels and the wilderness have interiors and no shell. Fourth `Area3D`, built
from the SAVED cell grid like both of those — no seed, every existing save. Measured on entry:
**64-81 calls, 72-271k tris, 101 programs**, against a city's 158-288.

**No `render.Occlusion`, and that is the design.** A city fades a building while it blocks the
camera-to-player sightline, which is the right question when the player is always outside it. Here
they walk IN, so the shell fades on being INSIDE: per structure, the interior roof to 0 and the
SOUTH-facing wall faces to 0.20. South only — the camera heading is fixed with a ±30° orbit clamp, so
leaving N/E/W solid is what keeps a room reading as a room. `depthWrite` follows the opacity down, or
the faded wall still rejects everything behind it.

**The planned per-texel version (`alpha = 1 − uReveal * visAmt`) was dropped, and the reason is the
keeper: hidden ≠ covered.** The roof must be SOLID from outside, and the mask says the opposite there
— the sweep reaches a building's wall ring and stops, so every interior cell reads hidden and a
mask-driven roof would fog out into the background exactly when it should be a roof. The window-peek
half moved to the CPU instead: a structure opens when the player is inside it or within `PEEK_CELLS`
3 of one of its window cells with line of sight, recomputed only when the player's cell or
`area.visRev` moves. The roof also **splits in two** — the rim over the wall ring never fades, which
keeps the outline on screen and removes the `indoorW` vertex weight the mask version needed.

**Every window is a 2- or 3-cell RUN** (measured live: 49 openings, all 2 or 3), so the pane is
emitted per run and the art's three panes span the opening once. The generator's single-window path
has been dead for a long time: `TEMP_BUILDING_WINDOW` and `TEMP_BUILDING_VENT` are both `18`, so
`finalTiles` resolves that cell to wall + a `Vent` and `TILE_WINDOW1` is never written. The quad is
sized from the art's measured content aspect (2.009) and never stretched, so a 3-cell run stands 5.94
of `WALL_H` 6.0 and reads floor-to-ceiling while a 2-cell run is 3.96 on a real sill — two window
sizes out of one image.

**`generatorInfo` was describing one building of three.** `generate()` nulled `state.rooms/doors`
after the main building and `makeDoors` reassigned rather than appended; the hangar has no inner walls
and never went through `makeDoors` at all. Fixed at the source AND repaired for existing saves, since
the cell grid is persisted verbatim and never regenerated: `repairRooms` re-derives the rects by
flood-filling room floor bounded by walls and by LINO — lino being both the corridor floor and the
floor under every door is what separates one room from the next. Live save: **7 rooms → 24**, split
7 / 1 / 16 over the three structures, `missionHints` kept, not one tile touched. The completeness test
is a COUNT (`stored >= derived` → no-op), which can only err toward rewriting an equivalent record.

**Its own art set**, 10 new 1k sources. Linear values: exterior wall **0.0323** (just under the
asphalt it stands on), hangar cladding 0.0374, interior wall **0.0689** (2.1× the exterior — indoors
has to read as a different place the moment the roof goes), floor tile 0.0607, lino 0.0750, hangar
concrete 0.0353, grate 0.0270. Outdoors keeps `city/*`.

Two alpha traps: the **drain grate wanted no alpha at all** — as a centred sprite its cut never
happened (min alpha **112 of 255**, so `alphaTest` kept the whole square), but a drain cell is exactly
one cell, so the honest shape is a full-bleed TILE that REPLACES the floor. And
**`background:"transparent"` cuts on a generate but not on an `edit_image` re-emit**: unlit window
60.4% at alpha 0, the lit edit of that same drop **4.3%**. The edit holds composition pixel-exact, so
the unlit channel IS the lit one's correct cut — transplanted rather than re-rolled.

**Warm, measured not assumed.** First entry compiled **+10** (91 boot → 101). A facility warm scene
took boot to 96; instancing the park glbs inside the existing glb promise chain took it to 97 —
entry compiles **10 → 4**, and all five plant models cost **1** program between them. It needs its own
scene for a reason the tunnels' entry only half covers: the light counts match the city's (there is a
moon), but every lit surface here carries the vision-mask patch and the mask extends the cache key.

**The build key scheme was out of room** — sewer `-(id*2+3)` and wilderness `-(id*2+4)` are both
parities of one range, so a third grid-built kind needed the STRIDE: `gridKey(id, kind) =
-(id*4 + kind + 3)`. Riders: `getSpawnRect` gained its `'facility'` arm and unlike the wilderness's it
is **live the day it lands** (`commonAI 5`); `MeshLambertMaterial` gained typed `opacity`/`depthWrite`
rather than an `untyped` write; `Chunks` reports **1 group**, because per-structure meshes span 30×18
cells and sit past the 16-cell size guard at the scene root.

**The parking lot was the DARKEST surface in the game, and it is most of the frame.** The generator
fills the whole area with `TEMP_ALLEY` before it draws anything, so the leftover apron arrives as
`Const.TILE_ALLEY` and the obvious mapping is the city's alley art. Measured as built, linear: alley
**0.0226**, against roof 0.0275, wall 0.0323, asphalt 0.0329, grass 0.0414, walkway 0.0680. That art
was painted to be a slot between two buildings — small, and wanting to read as a hole. Out here it is
a 40-cell car park, and at 0.0226 under a 0.0275 roof the building was **1.22×** its own ground and
the whole compound read black. Swapped to `city/ground-asphalt` (a car park IS asphalt): the ladder
becomes lot 0.0329 < grass 0.0414 < walkway 0.0680, and the building reads as a darker mass ON its
tarmac. One constant.

**`city/grass` is a CUTOUT, not a ground tile, and using it as one perforated the park.** Reported as
"holes in the grass", and that is literally what they were: **47.6% of that texture is fully
transparent**, by its own prompt's design — "roughly 45 percent of the tile is left as the untouched
flat #5a5d63 grey background". It is ragged weed islands meant to be laid OVER paving by
`render.world.Lawns` with a `CoverageMask` alphaMap. As a standalone opaque surface the transparent
half renders as the flat grey `bleed_alpha` scrubbed into it, so the lawn read as clumps separated by
holes. **Full coverage is a different painting, not a setting** — new `facility/grass`, and its `lift`
0.82 was fitted against the NEIGHBOUR rather than in the abstract: as painted it measured **0.0291
linear, DARKER than the asphalt lot beside it** (0.0329), a lawn darker than its own car park. Built
it lands **0.0500**, so the ladder reads lot 0.0329 < lawn 0.0500 < walkway 0.0680. The other two
reused city tiles were checked the same way and are 100% opaque, so the defect was that one file.

**And the first attempt to judge the lot from a screenshot was invalid.** In a gameplay pose most of the
lot is outside the player's line of sight, so it renders at `MASK.hidden` 0.14 toward the sky whatever
its albedo is — the mask, not the art, is what a capture like that shows. Forcing
`VisionMask.uFloor.value` to 1.0 from CDP (a live static, restored after) is the A/B that separates
them, and it is what showed the ladder was the real defect rather than the fill.

**Measured, foregrounded at 60 FPS, 36 samples, gameplay pose:** `frame` **16.69ms** (vsync),
GPU median **7.06ms** (IQR 6.49-7.98), `submit` **1.39ms**, `idle` **14.30ms**, **68 calls /
250,394 tris**. Fill-bound like every other area on this machine — GPU is 5× submit. That lands the
facility squarely in the wilderness band (plains 73 calls / 6.95ms, forest 62 / 4.92, mountain
52 / 7.20) and nowhere near the frame budget.

## Every facility doorway was a 4x6 hole in the wall, and the leaves that fill it are not a glb — Phase 1

Item (b), render half only: `objects.Door` already had `isOpen`, `frob()`, the auto-close at two
turns and the linked halves. What was missing was any geometry — a door cell finalises to plain
`Const.TILE_FLOOR_LINO`, so Phase 0's wall pass saw corridor floor and emitted nothing. 30 holes.

**Every facility door is ONE cell; the "double" front door is two of them flanking a pier.**
`generateBuilding` draws `TEMP_BUILDING_FRONT_DOOR` over a 3-cell `drawChunk` then puts the CENTRE
cell back to wall. Measured live: 30 openings, 6 glass / 23 cabinet / 1 metal, the glass ones really
arriving as `(2,11)+(2,13)` and `(36,53)+(38,53)`. A cell is 4 units — a 2 m opening, a DOUBLE door
in any real building — so it gets two 2-unit leaves.

**A leaf is a textured box, not a generated prop.** TRELLIS was the plan and is the wrong tool: a
flat slab with a rectangular panel is the worst subject for a dual-contour remesher, which rounds the
edges off and charges $0.03 for an approximation of eight vertices. Authored in
`FacilityDoors.leafGeom()` (5 quads, 10 tris, no underside); the ART carries all three looks, which
also killed the planned `texSrc` repaints — painting into a TRELLIS atlas is per-variant manual work.

**ONE square image holds the COMPLETE shut pair and the second leaf comes free.** Left leaf u 0..0.5,
right 0.5..1; the box's BACK face carries the SAME u, so from behind it delivers the mirror — and the
mirror of the left leaf IS the right leaf, which is therefore the same geometry at `yaw + PI`. Exact,
not approximate: the sources measure **1.8-2.0 sRGB mean absolute difference about their own
midline**, i.e. grain. `DOOR_H` 4.0 of `WALL_H` 6.0 follows from square art over a 4-unit cell.

**The swing is derived, not cased.** `Ry(yaw)` takes local +x to `(cos, 0, -sin)`, so a direction's
yaw is `atan2(-z, x)`; the leaf's origin IS its hinge, so the matrix is a plain turn with no
recentring to undo (which `Models.instanced` would have forced, hence the hand-rolled batch). Leaf 0
turns by `wrap(openYaw - shutYaw)`, leaf 1 by its negative from `shutYaw + PI` — both finish along
the swing normal from opposite jambs. Verified numerically: shut `0 / 180`, open `90 / 90`. The four
combinations of run axis and swing side are what a hand-written switch gets wrong once.

**The head needed closing TWICE, and the second only showed with the camera on the floor.** A wall
cell is a whole cell, so an opening is a 4-unit-deep reveal and the lintel closes BOTH faces; the
leaves hang on the plane between them, leaving the strip above the head open. Found by putting the
free cam at y 0.6 and looking up — a black void over every doorway. The game camera pitches DOWN 51
degrees and never sees it, which is exactly why it would have shipped. Two triangles a door.

**The hangar's roll-up door existed and was invisible** — `TILE_HANGAR_DOOR` is `Wall.SHUTTER` and
Phase 0 painted it in plain cladding. Own buffer and texture now, world-aligned at `SHUTTER_TILE`
**7.0**: 24 slats per repeat puts the pitch at 0.29 units and ~20 slats up a 6-unit wall, which is
what the built frame shows. Tiling, not mapping across the run — slats are uniform.

**Measured in the built frame under debug key `1` (pure albedo), linear:** glass leaf **0.0191** <
ext wall 0.0323 < kick plate 0.0389 < walkway 0.0545 < jamb reveal 0.0670 < lino 0.0751; shutter
**0.0274** vs its own cladding 0.0375. Both reproduce their SOURCE values to four decimals, so key
`1` is a usable albedo probe. Leaf 0.59x its wall, shutter 0.73x its own — a door reads darker than
the wall it sits in, which was the ask. The kick plate that looked blown out by eye is 1.2x the
wall; no `lift` anywhere. Boot warm 97 → **98** (the leaves are an INSTANCED mask-patched lambert and
`USE_INSTANCING` is a program define, so the merged shell's program does not cover them); first entry
still compiles **4**. Gameplay pose **68 → 70 calls**, 250.4k → 250.7k tris. Timing NOT re-measured:
the window was not foregrounded (topbar 1 FPS), and +2 calls on a fill-bound frame is under the noise
an A/B could resolve.

## Half-tile walls, and the fade that dissolved the wrong ones — Facility Phase 1.5

Six defects from walking the Phase 1 build. All render-side; `FacilityModel` re-derives from the
saved grid every build, so nothing persisted moved.

**A wall face cannot be judged an occluder by its NORMAL, and the whole `*S` split went.** Phase 0
routed every `+z` face into `wInS`/`wOutS`/`panesS` and faded them to `WALL_FADE` 0.20 while the
player was inside, on the theory that a fixed camera heading makes `+z` the only direction that can
occlude. It cannot answer the question: a `+z` INNER face is, by construction, the south face of a
wall whose south neighbour is indoor floor — i.e. the NORTH wall of some room — so standing in that
room dissolved the far wall, which occludes nothing, and the room opened onto the void past the area
border. Measured at 112 px/cell, scan across the north wall: `SKY 680-1015` and `SKY 1128-1464`, both
**exactly `0x0a0e14` with min == max**, against `geom 1016-1127 (27,33,33)` for the one solid cell
between the runs. Pure background with zero variance is nothing drawn, not a ghost.

**Riding along: a faded alpha-tested pane does not fade, it SNAPS OUT.** `addPane` carried
`alphaTest: 0.5`, three tests it against `map.a * OPACITY` (`alphatest_fragment`), and at 0.20 every
fragment is discarded — so a window run vanished whole the instant the ease crossed `t = 0.625`. Two
independent bugs presenting as one symptom; the second is invisible to any reasoning about the fade
that does not know the alpha test multiplies by opacity.

Fix taken: **fade the roof and nothing else.** Four buffers deleted per structure, `WALL_FADE` gone,
no shader work, and the alphaTest interaction becomes unreachable. The height it was buying back is
paid for by the thickness change below — an occluder's reach drops from `4 + 4.9` units of z to
`2 + 4.9`, −22%.

**Walls are HALF a cell and glazing a QUARTER, off one rule with no cases.** Each side of a cell
reaches the cell boundary if the wall line *carries on* through that neighbour, else insets by
`(CELL − T) / 2`. `carries` must count a DOOR cell as well as a wall — a doorway is a hole IN the
line, not the end of it, and reading it as an end pulls both flanking slabs back and opens a 4-unit
opening out to **6**. Three things fall out for free: straight runs come out 2 thick; corners come
out a 3×3 pier that is FLUSH outside (both outer faces sit at the run's own inset) and a pilaster
inside; and a 1-thick glazing slab sits strictly inside its 2-thick neighbour, so **the neighbour's
own butt cap IS the jamb reveal**. That last one is what closed the holes between glass and wall —
they were never a texture problem (the cropped alpha bbox measures ≤1 px margin on all four sides,
content aspect 2.0088 against crop aspect 2.0088), they were a window cell being a wall cell, and a
wall only emitting faces toward NON-wall neighbours, so the run's ends emitted nothing at all.

Verified over all 572 wall cells: `run 4x2` 197 + `run 2x4` 182 at exactly 2.0, `run 4x1` 74 +
`run 1x4` 52 at exactly 1.0, `2way 3x3` 22 corners, `3way` 44, `4way` 1, **0 straight-run failures**;
**0/30 doorways off `CELL` wide**, **0/49 window runs whose cross-section is not contained** by its
flanking wall. Screen: **277,078 exact-background pixels → 170**, and the survivors are single-digit
scattered clusters in fully-hidden corners where `mix(fogColor, rgb, ~0)` lands on the fog value
honestly.

**A butt cap's texture is decided by the DIAGONAL cell, not the neighbour.** The space a cap faces is
one step along the line into the neighbour, then one step off the line toward the side the excess
sits on. Reading the neighbour gets a window jamb right and a corner pier wrong: a corner's shoulder
looks *past* the run it butts against, into the room behind it.

**Glass is half-transparent with a solid frame in ONE draw, and the split is baked in the texture.**
The source is bimodal in luma — frame 16-127 at 25.9%, glass 144-207 at 73.4%, a **0.7% valley at
128-143** — so a threshold separates them outright. New `glass_alpha` key in `tools/textures.py` on
the `lift` pattern, applied to the full-res source before the LANCZOS resize so the alpha edge
resamples soft; built map is 71,430 px at alpha 128, 23,050 at ≥250, 156,225 at 0. Material takes
`transparent` (set AFTER `VisionMask.patch`, the usual trap) and `alphaTest: 0.02`, which now only
kills the 1 px margin. Measured on screen against the map: pane **(126.4, 149.0, 156.8)** vs the
texture's glass **(147.7, 172.5, 179.4)** = 0.86×, and the arithmetic closes —
`0.502 × (147.7 + 0.55 × 147.7) + 0.498 × 30.7 = 130`, against 126 after tone mapping.

**`lift` runs BOTH ways, and this is the first entry that needed `g > 1`.** The repainted
`wall-interior` came back at linear **0.1077**, the brightest texture in the facility set and above
its own lit glass at 0.0797. `lift 1.22` put it on 0.0672, holding the green version's 0.0689;
`window-head` took 1.09 from 0.0461 to 0.0352. Built frame reproduces the sources to within 0.5 sRGB
(before: `(69.7, 80.6, 74.9)`, green-dominant; after: `(68.0, 74.7, 80.6)` against a source of
`(67.7, 74.2, 80.0)`, cool and neutral).

**The trap that nearly cost a false regression:** the "before" capture read its room floor at
`(64.7, 70.7, 74.4)` against the source's `(64, 70, 74)` — a four-decimal albedo match, i.e. debug
key `1` had been left ON by the previous session. The reload cleared it and the next frame came back
7× darker and blue, which reads exactly like a lighting regression. It is not: `1` is a full-bright
albedo probe, and the only safe comparison is probe-to-probe. Check the floor against its own source
before believing any before/after brightness claim on this area.

**Measured, both frames under key `1`:** calls **53 → 43** (four buffers deleted per structure, one
`window-head` added), tris **3.7k → 5.0k** (~800 per structure of floor strips — a wall no longer
fills its cell, so the remainder is emitted as the NEIGHBOUR's floor, indoors by `FacilityGeom` and
outdoors by `FacilityGround`, both off one shared `strips()`). 0 console errors.

**Windows do not bloom, and did not before either — do not chase it.** `WINDOW_EMISSIVE` 0.55 over an
emissiveMap whose glass is sRGB 147.7 (linear 0.295) gives 0.162 of emissive radiance against
`BLOOM_THRESHOLD` **0.9**; at alpha 1.0 it was still ~0.32. Confirmed in the built frame: the wall
beside a pane sits flat at `(7,16,32)` with no elevation past the geometric edge. Halving the glass
did not cost a glow that existed. Interior brightness is Phase 3's job (ceiling lights), not the
pane's.

## Roof line, window proportions and the room/corridor split — Facility Phase 1.6

Four more defects off walking the Phase 1.5 build. Two are the same bug in two places, one is the
art having moved under a hardcoded crop, and one is a split that had never been made.

**The roof band over a wall was 1.87× the wall, and only the INDOOR side was wrong.** `rimRect` ran
to the cell boundary on any side whose neighbour was indoor, so the never-fading band was a unit
wider than the masonry on every inboard face. Measured live over the wall ring before the fix: rim
**8008** units² against slab **4278**, with only **41 of 572** cells exact — 268 interior partitions
at 2 → 4 (a full-cell band over a half-cell wall), 126 glazing at 1 → 3, 111 exterior at 2 → 3. Once
the interior roof faded, every internal wall kept a ledge twice its own width. The band is now the
slab, and what the slab leaves is the neighbour's cell reaching in, so it takes the neighbour's
CEILING — the fading roof — exactly as it already took the neighbour's floor. After: **1.056**, and
the entire remainder is the 126 glazed cells at exactly 2.0 units² each, which is the deliberate
half-unit external head that keeps the roof line from notching in at every window run. **0**
non-glazed cells overhang. So: outdoor side keeps `WALL_T`'s inset, indoor side takes the slab's own.

**A door cell is not a wall cell, so it contributed nothing to the rim at all.** `rim` is written
only by `capTop`, and `capTop` was called only under `if (isWall)` — verified live, **0 of 30** door
cells is a wall cell. 240 units² of lintel roof therefore sat in the FADING buffer, and every one of
the 30 doorways read as a notch cut out of the wall-top ring the moment the shell revealed. `slab()`
was already right on a door (all 30 come back exactly the 2×4 lintel planes, which its own header
had claimed and nobody had used), so the fix is to run `capTop` and the strips loop for a door cell
too. Two riders fell out of the same full-cell quad: at the 7 exterior doors it hung **28 units²** of
roof, and the same 28 of corridor lino, out over the pavement — and `FacilityGround`'s strip pass
tested `isWall`, so those 7 strips got no ground either. Both passes now test `FacilityGeom.carries`.
Live census off the 30 door cells: 53 indoor strips, 6 walkway, 1 lot.

**`carries` had also taken both JAMBS off every doorway — a Phase 1.5 regression.** Found by putting
the free cam on the spine door at (10,6): two black slots, floor to lintel, either side of the
leaves. Same root as the roof band above. The flanking wall cell sees `carries` on the door cell and
takes the butt-cap branch, where the two cross-sections are identical (both `WALL_T`) and nothing is
exposed — which is true of the MASONRY and false of the hole underneath it. Before `carries` existed,
a door cell was simply a non-wall neighbour and the flanking wall emitted a full face there, so the
jamb came for free; closing the opening back to one cell removed it and nothing replaced it. The door
cell now emits its own two side reveals (`jamb`), 0..`DOOR_H`, each wound to look INWARD — `face`
with one axis collapsed onto the boundary plane, the same trick `butt` uses. +120 tris. Both
orientations checked on screen, because the two windings are hand-derived and a wrong one is
invisible from outside the opening and still black from inside. It also covers the front-door pier
for nothing: a jamb is emitted at the door's own boundary whatever sits on the far side of it.

**A centred crop cannot follow a re-cut alpha.** `loadCroppedTexture(…, 0.895, 0.446)` takes a
CENTRED rect, and the hand-re-cut lit window's content sits **9 px high of centre** (built 512: bbox
y 134..359 against a crop of y 142..369). It shaved 8 rows off the top rail and left 10 rows of empty
alpha under the glass for `alphaTest 0.02` to discard. The old numbers had only ever worked because
that texture's alpha was transplanted from `window-large.png`, whose bbox IS centred (142/142). Fixed
by cropping to the image's own alpha bbox at load — `Textures.loadAlphaCropped` — which deletes both
constants and cannot go stale. Costs one `getImageData` scan per texture, once.

**A window's height is the ART's aspect, and no code change can reach it.** `WINDOW_ASPECT` 2.02 put
a 3-cell run at 5.94 tall in a 6.0 wall: head 0.03 under the roof deck, and the sill cap skipped
outright because `lo` 0.0297 is under the 0.05 guard. **28 of 49** runs are 3-cell, so that was the
common case and not the corner one. Clamping the height in code cannot work — the hole through the
wall is cut from the same arithmetic, so a shorter pane in a full-height opening is just a gap. New
art at the measured **2.90**: a 3-cell run is 4.14 tall on a 0.93 sill, a 2-cell 2.76 on 1.62, both
with real wall above the head and both now getting a sill cap. Two notes on getting it: asking for
"exactly three times as wide as it is tall" produced a **5.22** letterbox, and what fixed it was
naming the PANE shape ("each individual pane is almost a square"); and the 1k server cannot render a
3:1 canvas at all — max edge 1024 against a 655,360-pixel floor caps canvas aspect at **1.6** — so
the unit sits in a band inside a square frame and the bbox crop takes it out. `glass_alpha [136,128]`
carried over untouched: the new source is bimodal at frame 16-127 30.6%, glass 144-207 58.8%, a
**0.2%** valley between.

**Rooms and corridors split off `Surf.LINO`, needing no `generatorInfo`.** LINO is what the generator
floors every corridor and every door cell with; TILE is room floor. Live over the two lab buildings:
**538** faces look into rooms against **218** into corridors, 12,912 vs 5,112 units², so a corridor
wall is **28.4%** of the interior surface — a third of what the player sees indoors, not a detail.
One local `look(c,r)` closure replaces the `st.hangar || !inner ? wOut : wIn` ternary at all three
call sites (plain faces, butt caps via the diagonal cell, door lintels), and costs +1 merged mesh per
non-hangar structure. `wall-interior` stays the CORRIDOR — its prompt already asked for a laboratory
corridor, so it is the art that did not have to be repainted — and the new `wall-room` is the room:
a tiled splashback over the lower 40% under painted board. It does not tile vertically and does not
need to: `face` maps v as `y / WALL_TILE` with both at 6.0, so v runs exactly 0..1 up a wall and
never wraps, which is the same reason the corridor art can carry a scuff band in its lower third.
`lift 1.23` took it from linear 0.0982 to **0.0592**, just under the room floor 0.0607 and the
corridor wall 0.0673, so a corridor still reads as the brighter spine between darker rooms.

**Measured, both frames under key `1` with the same camera:** calls **35 → 32**, tris **5.2k → 5.0k**,
0 console errors, no persisted change. A vertical profile through the north wall makes the window fix
visible in pixels: the two captures are identical from y190 to y222 (same camera, same probe), then
before goes roof → glass → floor with no wall band either side of the glass, while after gains a band
at y226-250 above it and one at y314-330 below. Phase 1.5's regression test still passes: **0** pixels
at exactly `0x0a0e14` in the room band.

`window-large.png` and `window-large-lit.png` went to the `textures-src/unused/` shelf and their
entries out of `textures.json`, the stale outputs deleted — the ribbon art replaced both and nothing
in `src/` referenced either. 191 → 189 tracked textures, `make tex` clean at 0 warnings (the shelf is
skipped by the untracked-source sweep, which is what it is for).

## A wall cell is the UNION OF ITS RUNS, not their bounding box — Facility Phase 1.7

**`slab()` is a bounding box and four passes had been reading it as the masonry.** Where the wall line
turns or branches, the runs through a cell form an L, a T or a cross and the box is strictly bigger:
a corner came out a 3x3 pier with a 1x1 shoulder standing in the room past both wall lines, which is
what "room corners have remains of old full-tile geometry" was seeing. Census over the area's 602
wall+door cells: **535** straight, **22** corners, **44** T-junctions, **1** crossing — so the Ts, at
two shoulders each, were the bigger half of it, and the crossing filled its cell outright. New
`notches()` returns the corner squares (one per PAIR of adjacent carrying directions), and the square
is handed to the DIAGONAL cell exactly as `strips()` hands a run's leftover to the neighbour beside
it: its floor, its fading ceiling, its wall paint, plus the two faces of masonry looking back at it.
**114** notches, 1 unit² each, **all 114 with an indoor diagonal**, so `FacilityGround` never sees
one. Box 4518 → masonry **4404**.

**Three consumers fall out of it and each got simpler, not harder.** `capTop` emits the union as up
to three rects (the x-run's middle band, the z-run's two arms) — verified against `box − notches` on
every one of the 602 cells, **exact to 0**, and one early-out for "no x-run" keeps a straight vertical
wall at one quad instead of three abutting ones (~900 tris). The butt caps stop comparing slab
extents, which answered the wrong question — at a corner the box reaches the boundary on the side the
OTHER run leaves through, and that read as an exposed end — and compare THICKNESS instead: 385 butt
quads → **196**, exactly 49 window runs x 2 ends x 2, i.e. nothing but the glazing reveals the rule
was ever meant to cap. Net over the whole shell: 1113 → **1338** quads, +450 tris, all of it the
corner squares gaining real surface.

**`rimRect` deleted; the roof line notches in at a window run.** Its only remaining job was to run
the band out to `WALL_T`'s inset on an OUTDOOR side — a no-op on solid wall, and half a unit of
bitumen sitting on the outside of every pane: **126** glazed cells x 2 units² = 252 units² of roof
texture on the glass. Straight roof line was not worth it. `rimRect ≡ slab` once that goes, so the
function went with it and `capTop` picks `head` or `rim` off `glazed` alone. Head cap now **504**
units² over 126 cells = exactly the 1x4 glass slab, and the rim/masonry ratio is **1.000** (1.872
before Phase 1.6, 1.056 after it).

**`WINDOW_EPS` deleted — the offset WAS the seam.** The pane stood 0.02 proud of the wall plane "so
nothing depends on polygonOffset", but the emitter cuts the opening OUT of the wall rather than
painting the pane over it, so the two are never coplanar-and-overlapping and there was nothing to
fight with. All it bought was a hundredth of a unit of open air along the head and the sill, where
the reveal's caps stop at the masonry and the glass did not. Flush now, and the run's ends close too
(the pane edge lands exactly on the flanking wall's butt cap).

**The doorway reveal is CORRIDOR whichever way it faces.** `soffit` used to take whichever of the two
flanking spaces the `k` loop read first, so an interior door was painted in the room's tile half the
time and an exterior one in the outside cladding. A doorway belongs to the circulation and not to
either space it joins — the same reason the generator floors every door cell in lino. `st.hangar ?
wOut : wCorr`, and the `soffit == null` bookkeeping goes with it. Verified from inside a room: tiled
wall either side, flat corridor paint on jamb and soffit.

`GRATE_TILE` 4.0 → **2.0**: four gratings to a cell around the central cover instead of one 2 m
square of it. The one period in `FacilityStyle` that IS a divisor of `CELL`, and deliberately — a
grating is a lattice already, so landing on the cell grid is the point rather than the mistake the
others avoid.

> The grate paragraph above is SUPERSEDED by the drain paragraph in Phase 1.8 — a drain is a fitting
> in the floor and neither one cell-wide grating nor four of them is the right answer.

## The threshold, the drain and the 2D leftovers — Facility Phase 1.8

**A drain is a fitting IN the floor, and one was already being drawn.** The cell carries an
`objects.FloorDrain`, `isGroundDecal()` true, so the actor layer had been laying its icon flat on the
floor all along — and `Surf.GRATE` was painting a cell-wide grating underneath it. One grating filling
a 2 m cell read as a vehicle pit and tiling it 2x2 read as four of them, and both were competing with
the object's own decal. So the fix is a deletion: `Surf.GRATE` falls through `floorBuf` to room floor,
and the `fGrate` buffer, `FLOOR_GRATE` and `GRATE_TILE` all go. **23 cells** in a generated area.

**The drain's art was swapped in the ATLAS, which is where that object's image lives.** `FloorDrain`
draws `ROW_OBJECT2` / `FRAME_FLOOR_DRAIN`, i.e. cell (16, 0) of `app/img/entities64.png`, and the old
icon measures an alpha bbox of exactly **32x32 centred in the 64** (856 opaque px ≈ a disc of r 16) at
mean sRGB **163/170/178** — a pale round cover, and by far the brightest thing on a facility floor.
`facility/floor-grate.png` LANCZOS'd to 32x32 and pasted into a cleared cell holds that footprint to
the pixel, so the decal's on-screen size does not move, and lands at **39/45/47** — under the 0.0607
floor it sits in, which is what a recess should read as. Two things to know if it is ever redone:
`app/` is a SYMLINK to the packaged Electron runtime and is gitignored, so that atlas is the only copy
and has no tracked source (the original is in the session scratchpad); and `make tex` does not reach
it — regenerating the source leaves the atlas on the old cut, which is what its `textures.json` note
now says.

**A doorway's floor is the two spaces it joins, not the door cell's own surface.** `strips()` hands a
wall cell's leftover to the neighbour beside it, but the door branch was still capping the SLAB in the
door cell's own lino — and a door cell's slab is its LINTEL, masonry above head height with nothing
under it, so at an exterior door 2 units of corridor lino ran out past the building line. New
`floorStrips()` collapses the slab to the wall LINE and re-runs the same decomposition, which IS the
two halves, so there is no second rule — and `stripsOf` now takes the rect so both share one body.
Census over the 30 doorways, 480 units² of threshold: TILE 144 → **288**, LINO 304 → **128**, WALKWAY
24 → **48**, LOT 4 → **8**, CONCRETE 4 → **8**. Outdoor threshold **28 → 56** units², exactly the
outer half of the 7 exterior doorways. The ceiling still comes off `strips()`: the lintel's own top is
the rim, so the two decompositions part company at a doorway and nowhere else.

**Every facility doorway had its 2D tile image lying on the threshold under the leaves.** The actor
layer's `iconOff` is computed as `ObjModels.modelFor(key) != null` and a swinging leaf pair is not a
glb prop, so a door drew both. Fixed with `FacilityDoors.draws(area, o)` OR'd into that expression —
scoped to `AREA_FACILITY` on purpose, because the corporate and underground-lab generators deal
`objects.Door` too and nothing draws leaves for those, so there the icon is still all there is. The
object marks ride the same flag, and doors never had them (`visible()` is false for a door), so
nothing else moved.

## A lab bench is a BOX, so it is merged geometry and not a prop — Facility Phase 2

The plan for this phase was two generated glbs, `facility/bench-lab` (a 1-cell casework unit) and
`facility/bench-island` (the 2x3). Neither was generated. Reading the 2D art first is what killed
them: rows 8-11 of `tileset64.png` draw a lab table as a plain top-down slab with a thin drawer strip
along its front, which is a worktop over a run of cabinets and nothing else. Six quads a cell.

What decided it was the SHAPE census, not the art. Over one facility: **207 bench cells in 81
connected blocks** — 53 of 2x1, 9 of 3x1, 7 islands of 2x3/3x2, and **11 blocks that are not
rectangles at all**, where a wall run grew into an island or into another run. A prop needs a mesh
per shape and would have shown a seam at every cell boundary of a run; those 11 have no shape to make
one for. Merged geometry never names a shape: a face is emitted toward a neighbour that is not a
bench, exactly as the wall pass emits toward a neighbour that is not a wall, and every block the
generator can lay falls out of that one predicate. `FacilityModel.tableOf` is a BLOCK test on the
tileset (rows 8-11, columns 0..7) rather than a list of the 22 `Const` names that spell out its cells
— the corp and wood/marble tables start at column 8 — and the generator's 1x1/1x3/3x1/2x3/3x2 shapes
are never read.

**The overhang comes out of the WORKTOP, and that is a UV decision rather than a modelling one.** It
was built the other way first — casework pulled back `BENCH_LIP` 0.2 from every side that does not
carry on into another bench cell, one inset rect serving all four directions because the inset and
the face plane are the same quantity. Geometrically that is fine and the corners close. It is wrong
for the ART: an inset body starts 0.2 past the cell boundary, so its world-aligned `u` starts
mid-door and the first and last cabinet of every run are cut. Growing the worktop outward instead
leaves the body spanning exact cell boundaries. Measured on a synthetic single cell: worktop
**4.4 x 4.4** = `CELL + 2*LIP`, casework **4.0 x 4.0** exactly.

**The tile period was the other half of the same bug, and `FacilityStyle`'s own note is what caused
it.** `BENCH_TILE` was set to **1.75** — the cabinet's own height — precisely to keep the horizontal
period off the cell grid, because every tile size in that file is chosen that way. That is the wrong
rule here and it shipped a visible defect: 4.0/1.75 is 2.29 repeats a cell, so the door rhythm drifts
against the grid and a run's ends land at an arbitrary phase — half a drawer, and a different half
per bench. The blanket rule is about art whose features are IRREGULAR, where a cell-aligned period
puts the same stain on every grid line and the lattice reads through. Cabinetry is the opposite case:
the repeat IS a regular rhythm and landing it on the grid is the entire point. **2.0**, half a cell,
4 doors a cell at 1.0 world unit (0.5 m) each.

Those two together are what make it exact. Over the whole area, every body quad's `u` endpoints land
on a **whole** repeat: `worstOffGrid` **0**, all **1116** endpoints at fraction **0.0**, 2 repeats a
face. A door cannot be cut on any face of any block shape, whatever the art's internal layout is.

**Two periods on two axes is why the casework cannot call `FacilityGeom.face`.** `u` is world-aligned
on `BENCH_TILE`; `v` has to run 0..1 over the body's own height so the bottom-up composition lands
whole (measured **[0, 1]** exactly). `face` has one `t`. `FacilityTables.panel` is the 8-line
emitter, going through the same now-public `FacilityGeom.ends` so the winding — the one thing here
that is invisible until a whole axis of faces disappears — is still derived in exactly one place.
There is no `BENCH_TILE`-style V constant: the body height IS the V period, by construction.

Counts, unchanged by the rework and predicted to the quad from `cells + openSides`: **764 top quads
= 206 caps + 558 edge bands** and **558 body quads**. **2 draw calls.**

No soffit under the overhang and no floor under the casework, deliberately: the open ring is 0.2
wide and at the camera's 51 degrees a ray entering at the bottom of the 0.25 edge band drops 0.25
units over the 0.2 it travels inward, so it lands on the cabinet face and there is nothing to see
through. At a CONCAVE corner — where one run meets another and the block is not a rectangle — the two
grown rects overlap by 0.2 squared; the caps are coplanar with the same texture and the same
world-aligned UVs, so that resolves to the same pixel either way, and the two edge bands cross by 0.2
world units, which reads as nothing.

Art: two textures, both 1k. `bench-top` measured **0.0203** linear and was left alone — a black epoxy
worktop being the darkest surface in the set is what gives a bench its silhouette against the 0.0607
room floor, and the trap `GROUND_LOT` records (darkest art filling the frame, whole compound reads
black) is about a ground plane. `bench-body` came back at **0.0891**, brighter than every facility
surface including the wall behind it and the floor under it, so a room read as a ring of glowing
cabinets; `lift` **1.23** — the same value its wall neighbour needed — puts it on **0.0537**, just
under `wall-room`'s 0.0592.

**`WorldCtx.ground` is what stands a decoration on its bench.** The generator writes the table
decoration onto the SAME cell as the table tile (`FacilityAreaGenerator`'s chem-lab pass), so without
this every flask and microscope sat at y = 0 with a metre of casework in front of it. `FacilityArea`
stops clearing `ground` and points it at `FacilityTables.groundY`, which answers `BENCH_H` on a bench
cell and 0 elsewhere — the one hook that exists for this, so the sprite, its shadow, its fade and the
cursor pick all follow with no code of their own. Verified both entry points agree: `floorY(22,27)`
and `floorYAt` = **2**, the cell beside it **0**. **175 of 234** decorations in the area are on a
bench.

**`objects.Decoration.isGroundDecal()` → false, with no per-row table.** The plan called for one —
rows 8/13 and 9-11/14 upright, row 12 and the papers flat. The atlas says otherwise: every icon in
rows 8-14 of `entities64.png` is painted in ELEVATION — fridges, fume cabinets, flasks, microscopes,
drums, server racks, robot arms — including row 12, which the plan had guessed was floor litter and
is actually barrels and racks. Laid flat they read as decals of furniture printed on the floor. The
only two cells that would genuinely lie down are the gloves, which is not worth a table.
`DecorationExt` keeps the default: that one carries a random angle and scale and IS floor litter.

## Indoor lighting is a world-XZ MASK, not a second set of lights — Facility Phase 3a

A facility interior was lit by the compound's own night rig, so a laboratory read as the yard with a
lid on. Two causes, not one. The roof deliberately casts no shadow (`FacilityGeom.addRoof`: a roof
that fades would still shadow, and the shadow could not fade with it), so the moon's directional term
lands on a lab floor at FULL strength through a solid ceiling — and the fill it lands over is
moon-blue, the same night as the parking lot.

**`Light.layers` does not do this, and that is worth knowing before anyone tries it again.** three's
docs read as though a light's layers pick which objects it affects. The renderer tests
`object.layers.test( camera.layers )` when it COLLECTS lights (`three.global.js:43178`, `:43351`):
a light is in the whole render or out of it. There is no per-object light filtering anywhere in the
pipeline, so two ambient lights cannot be aimed at two sets of meshes. Two render passes are the only
layer-based answer and they cost a second full frame.

What landed instead is the trick `VisionMask` already plays for line of sight.
`render.world.IndoorMask` paints a blurred step — 1 inside a building, 0 out — into a canvas, and
every lit material samples it by world XZ after `#include <lights_fragment_begin>`, where three has
gathered ambient + probe + hemi into `irradiance` and every direct light into `reflectedLight`, and
before `lights_fragment_end` combines them. So it is real light entering the shading equation, not a
tint over the result. No draw call, no pass, one fetch. Two properties fall out that a per-mesh or
per-object scheme would have had to build by hand: **movers are free** (an actor is lit by where it
STANDS, off the same lookup as the floor under it, with no `isIndoor` call on the CPU), and **the
transition is spatial** — the mask is blurred, so a doorway crossfades over the blur width with no
eased `t` and nothing to tick.

It is deliberately independent of `VisionMask` rather than folded into its spare channel: its own
canvas, varying and uniforms, so the two hooks chain in either order and the actor billboards, which
need indoor light but not the vision mask, can take it alone.

**Gated at the CALL SITE so it is a permutation and not a tax.** `VisionMask.patch` chains it only
while a mask is attached, so a city/tunnel/wilderness surface compiles exactly today's shader — a
wilderness entry added 5 programs, none carrying `indoor`. `Sprites` is the one unconditional caller,
because its pool fills lazily mid-play: a per-area decision there would either mislight the slots
made before the player walked inside or compile a program the boot warm never cached.

Three defects, all found by reading the mask canvas rather than the frame:

**`px: 2` halved the boundary before the blur ran.** `grow` is a quarter of a cell, so at 2 texels
per cell the overhang is a 0.5px `fillRect` edge and canvas resolves it as partial coverage. A lab
floor cell next to its own wall read **194/255** — 24% outdoors, standing in the middle of a room.
`px: 8` keeps the overhang on a whole texel.

**The blur is bounded above by the wall thickness.** A slab is `WALL_T` 2 units through and its two
faces have to land on opposite ends of the ramp, so a blur anywhere near the slab's own thickness
cannot separate them. At `blur 1.4` the inner face measured **0.50** and the outer **0.33** — the
whole wall lit halfway indoors. `blur: 0.5`, and `grow: WALL_T * 0.75` — PAST the inner face by that
blur rather than merely to it, since stopping at `WALL_T / 2` puts the face on the ramp's own
midpoint, which is exactly that 0.50. Fine scan across one wall after: outer face **1/255**, inner
face **240/255**.

**`isIndoor` was the wrong predicate, twice over.** The mask GROWS past a cell boundary to reach the
inner face of the wall beside it, so what the predicate has to answer is not "is this indoors" but
"is this far enough in that the grow cannot escape the building". Two cases that look unrelated fall
out of one four-neighbour test, and `FacilityModel.isInterior` is now floor-or-wall with a structure
owning all four neighbours:

- *A room divider is not floor.* A 1-cell partition is painted only by `grow` from either side, which
  covers its two faces and not the strip of mass between them — 211 cells inside one building read
  ~0.3 indoor, so dividers stayed moonlit between two lit rooms. 787 → **983** cells at ≥224, and on
  the reroll **315 of 315** partitions came back fully indoor.
- *An exterior door cell IS floor and still has to be excluded.* A door finalises to plain corridor
  lino, so `isIndoor` calls it indoors; painted whole it put a grow's worth of interior light out onto
  the PAVEMENT and onto the outward face of the shut leaves. **Reported from the game as "the wall
  shadows on the pavement behave as if no roof exists", and it was not a shadow at all** — swapping
  the mask for the black stand-in in a fixed exterior frame showed the door bays and the pavement in
  front of them lifting by up to **+11.56** mean RGB, a **6.8x** ratio, while the moon toggle barely
  moved them. One of a door cell's neighbours is the lot, so the same test excludes it and the doorway
  is reached by grow from the room behind exactly as the wall it interrupts is. After: the largest
  delta anywhere in that frame is **+0.27** (1.01x). Verified over all 33 doors of a rerolled
  facility — every interior door **255**, every exterior door **76** or less, no dark band across a
  lit building and no light on the lot.

The light that SHOULD come out of an open door is an additive spill cone and belongs to phase 3b's
lighting pass, not to this mask. An earlier draft kept the leak deliberately, calling it a free
version of that; it is not one — a spill cone is additive and shaped, while this relit the pavement
and the shut leaves as though they were indoors.

`indoorDirect` scales EVERY direct light and not just the moon: the chunk sums point, spot and
directional into one `reflectedLight` and there is no anchor between them. Accepted because it is
compensable — a fixture hung INSIDE is scaled by exactly this number, so phase 3b's ceiling lights
are tuned with it in view, while an outdoor lamp is untouched (its fragments read `inAmt` 0).

Values: `ambient 0x9fb0b4` at `2.4` and `direct 0.3`, i.e. indoor irradiance (0.83, 1.04, 1.10)
linear against the outdoor rig's (0.19, 0.27, 0.49) plus a moon term of (0.24, 0.33, 0.58) on a
floor. Predicted floor ratio **2.10 / 1.92 / 1.18** — twice as bright in R and G, barely moved in B,
so the hue leaves moon-blue. Measured live by swapping the mask texture for the black stand-in in the
same frame: the delta is confined to the indoor band and reads 1.13–1.5x in sRGB, which is that
linear ratio through the encode plus the vision mask's own falloff. Roof, sky and outdoor ground
measured **+0.00** — the roof is the one facility surface `VisionMask.patch` never touches, so the
chained hook misses it too, which is correct.

Warm parity: the mask adds a second `customProgramCacheKey`, the same thing that forced a separate
facility warm scene. `View.warmup` attaches around the facility block only and re-attaches around the
async park-plant callback; a second facility entry adds **0** programs. 0 console errors.

Not measured in ms: the window has never been OS-foregrounded (topbar reads 1 FPS).

## A LOAD does not invalidate the 3D view, so it keeps the previous save's geometry

Reported from the game as walking straight through every wall into the hangar, and as being blocked
going south with no wall in sight. Neither is a lighting bug and neither is a coordinate bug — the
scene was built from a **different cell grid than the one the game was colliding against**.

`GameScene.draw3D` skips a rebuild when `_view3dArea == game.area.id`, and `View.showFacility` skips
again when `shownKey == gridKey(area.id, 2)`. Both key on the AREA ID, and an id is **persisted** — a
load hands back the same ids attached to brand-new `AreaGame` objects. Nothing between `Loader.load`
and `applyLoaded` clears either guard, so the view keeps what it had. It bites because an area is
generated on FIRST VISIT: load an older save while standing in a facility you generated after it and
the area regenerates to a different layout under the same id.

Diagnosis, since the symptom points nowhere useful. The grid the game collides against and the model
the scene was built from were compared cell by cell in four orientations, and the shown model matched
the live grid on **0 of 4500** cells directly but **4500 of 4500** under a row mirror — this
generator's layouts differ by which edge takes the entrance road, so two rolls of one area read as
exact mirrors and the 100% is what proved the grids were simply *different*, not transformed.
`shownKey` then confirmed the scene belonged to the current area id, which is the whole bug in one
number. Forcing a rebuild flipped it to **100.0% direct**, so there is no coordinate error anywhere.

Fix: `View.forget()` (clears `shownKey`, tears nothing down) + `GameScene.forget3D()` (clears both
guards) called from `Game.applyLoaded`. **Both** guards have to go or the other still skips. Verified
by reproducing exactly: load, enter the facility — 100.0%; load AGAIN with the 3D view live, enter —
**100.0%**, with the shown structures changed, so it really did rebuild rather than keep the old one.

Worth knowing for anyone driving the game over CDP: `Game.load()` from the console used to leave the
view stale, which is how this was found and how an hour went into blaming the lighting mask.

## `TILE_BUILDING` is not only a city block, so the tactical grid skipped every facility wall

Reported from the game as the walls having no impassable hashing or dotting in tactical view, "only
windows for some reason". Exactly right, and the *only* is the clue.

`TacticalGrid.blocked` opened with an unconditional `if (area.getCellType(col, row) ==
Const.TILE_BUILDING) return;`. The comment above it argues the city case and argues it correctly — a
city footprint is unpaved, so dashes would hang in midair under a wall that hides them, and when the
block fades `Occlusion` already draws that same rectangle a hair higher. None of that survives the
move to a facility, and the guard was never told.

A facility wall IS `TILE_BUILDING`: `FacilityAreaGenerator` maps `TEMP_BUILDING_WALL`,
`TEMP_BUILDING_INNER_WALL` and `TEMP_BUILDING_VENT` all to tile 2. A facility WINDOW does not — it
maps to `TILE_WINDOW1`/`WINDOWH1..V3` (35-41). Both are unwalkable; only one hits the guard. So the
windows drew their dashes and their hatch while the wall they sit in drew nothing, which is the
inverted-looking result the report describes. `CorpAreaGenerator` uses the same three tiles.

Measured in one tactical window (`RADIUS` 16, player at 25,22): **330** blocked cells, **186 skipped**
as tile 2, 144 drawn — 38 of those the windows, the rest benches, tables and trees. Area-wide, 457
tile-2 cells against 117 window cells.

Fix: `area.isCity() &&` in front of the tile test. The city keeps today's behaviour byte for byte. A
facility wall is a half-cell slab with real floor either side of it (`FacilityGeom.strips`),
`WorldCtx.floorY` is 0 there, and no `Occlusion` runs on a facility at all, so every reason the guard
gives is absent and the marks land on visible floor.

`FacilityArea.setTactical` is an empty body whose comment claims the walls "are already handled by
render.TacticalGrid's blocked-cell pass". That claim is now true.

## A window opening is a real hole in the only mesh that casts, so the moon shone through it

Reported as building shadows still having window holes. They did, and it is not the roof — `addRoof`
sets `castShadow = false` deliberately, because the moon box follows the player and a roof casting
over its own lot would black out the building the moment you walked past it.

Two facts met. Over a window run the wall emits only the faces below the sill and above the head, so
the opening is a genuine hole in the geometry rather than a painted-over one; and of the shell's wall
buffers only `wOut` casts, while `addPane` set `castShadow = false`. Nothing filled the hole in the
shadow pass, so the moon went straight through the glass and put one clean parallelogram of light on
the floor inside the wall's own shadow, per run.

Isolated by flipping `castShadow` on the two live pane meshes and diffing the frame with the camera
pinned: **49,303** changed pixels in four parallelograms, one per window run of the near wall, max
channel delta **406/765**, and nothing else in the frame moving. Re-measured after the fix in a
rebuilt scene: the same four patches, same row bands, ~49k of an 82k total whose remainder is
frame-to-frame particle and bloom-dither noise.

Fix: `mesh.castShadow = true` in `addPane`. Two things make that enough rather than a first
approximation. The depth material carries the material's `alphaTest` (0.02), so the glass casts solid
instead of casting its own texture's holes — right for a night exterior, where a window should read as
part of the wall. And `shadowSide` flips `FrontSide` to `BackSide`, so of the two coplanar faces every
run emits (`pane` is called once outward and once inward) the shadow pass takes exactly the one facing
away from the moon, which is why no acne and no double-cast appeared.

Cost: **70 → 72** draw calls and **+1** program (one depth permutation), for 196 tris across the two
meshes. 0 console errors.

The alternative — a shadow-only quad filling each opening, or a second uncut wall buffer for the
shadow pass — buys nothing here and costs a buffer.

## A vent is cut INTO a wall, so its icon has to hang on the masonry

Reported from the game as a dotted through-wall mark lying on the ground north of the player, for
something that "needs to be on the wall, not flat on the ground".

`FacilityAreaGenerator` writes `TEMP_BUILDING_VENT` as `Const.TILE_BUILDING` and stands an
`objects.Vent` on that cell — a grille you slither through from one side of a wall to the other.
`AreaObject.isGroundDecal` defaults to true, so the actor layer laid the icon FLAT on the cell floor,
which is two units inside a `WALL_T` slab. The icon was never visible from anywhere; the only thing
that ever showed was `paintObjMark`'s `GreaterDepth` silhouette, which draws exactly where something
hides the pose — so the bug reported itself, in dots, on the ground.

The five vents in a generated area are the ONLY objects standing on a wall cell (247 objects, 5 on
masonry), and they always sit in a straight run: `carries` W/E on three of them and N/S on two, so
the exposed faces are always the two perpendicular to the run.

Fix: a third `WorldCtx` area-kind hook beside `ground` and `climbArc`, with the same contract —
`wallMounts(col, row)` returns one `WallMount` pose per exposed face, or **null** for every other
cell, so the actor layer pays one grid lookup per object and allocates nothing in the common case.
The facility points it at `FacilityGeom.wallMounts`; the city, the tunnels and the wilderness clear
it. The pose carries its own `scale`, which is what keeps `render.Actors` from importing
`FacilityStyle` to find out how thick that area kind builds a wall.

Two things fell out that are worth writing down:

- **The face's outward yaw is `Math.atan2(DC[dir], DR[dir])`** — the normal IS the direction vector
  read as (x, z). No dir-to-rotation table, and no crossing of `render.world.Geom`'s numbering, which
  orders its dirs differently from `FacilityGeom`'s.
- **Painting BOTH faces stamped a permanent dotted ghost on the roof.** The far face holds an
  identical quad that its own masonry hides, and a hidden quad is precisely what the through-wall
  mark draws — so the near face showed the real grille while the far face's mark hung 60 px above it
  on the roof. Only the side whose normal faces the camera is painted:
  `(camPos - pose) · (sin rotY, cos rotY) > 0`. Measured at the reported spot — south face **+18.88**,
  north face **−21.12**, one quad drawn.

`Sprites.paint` grew a third pose: flat decal / **wall face** / frontal upright. `faceRotY` sets
`rotation = (0, faceRotY, yaw)`, the same pose `paintWall` gives a bullet hole, and `paintObjMark`
forwards it so the mark rides the icon exactly as it does in the other two poses.

Values: `MOUNT_Y 2.0`, `MOUNT_SCALE 1.0`, `MOUNT_PROUD 0.12` (a bullet hole's nudge). At the facility
scale — `WALL_H` 6.0 is one 3 m storey — that is a 0.9 m cover spanning 0.53-1.47 m up the wall, low
enough to be a duct you slither into. It shipped first at half that size and twice that height.

### The art, and why the honest value was the wrong one

The icon was a flat pale plate with nine painted slats. `facility/vent` replaces it: a generated
galvanised grille, full-bleed square, four corner screws, real slat/slot contrast and grain. It goes
into `app/img/entities64.png` cell (row 16, col 1) at **38x40 on offset (13,12)** — the old icon's own
alpha bbox, which is exactly 1520 opaque pixels = 38x40, so that icon was a solid rect and the new one
inherits its footprint to the pixel. The 2D view's size therefore does not move, and `MOUNT_SCALE`
alone decides the 3D one. `make tex` does NOT reach the atlas; the paste is by hand, LANCZOS, cleared
cell (same trap as `facility/floor-grate`).

**Straight out of the generator it was invisible.** The old icon measured 108/121/121 sRGB against
`wall-exterior`'s 44/50/57 — more than twice the wall, which is why it read at all. The new art came
back at 51/60/66, i.e. the *same value as the wall*, and in the built frame the grille measured luma
**6.9 against the wall's 7.6** — a ratio of **0.9x**. A plate that is honestly the same steel as the
panel behind it is a plate nobody can see.

`lift` 0.7 in `textures.json` takes it to 81/92/98 and the built frame to **14.6 vs 7.6 = 1.93x**.
Deliberately UNDER the old 3.1x: the old plate had no internal contrast, so brightness was the only
thing that made it read, while this one carries its own slat pattern and does not have to be the
brightest thing on the facade. Net prominence is up regardless — 2x the linear size is 4x the area,
so 1568 px at 1.93x against 464 px at 3.1x.

Verified live: the grille stands in the wall plane at the reported cell; the roof ghost is gone; and
`wallMounts` reads **null** in a city and in the wilderness after leaving the facility, `ground` and
`climbArc` still set where they should be. 0 new console errors. **The hooks are cleared at BUILD
time and `View` skips a rebuild** — reading `WorldCtx` in the same tick as a `teleport` shows the
PREVIOUS area's hooks, because `GameScene.draw3D` rebuilds on the next frame. That cost a false
positive here.

## `worldToCell` ROUNDS, so a hatch stripe ending on a cell edge sampled the wrong cell's floor

Reported as the impassable hatch over a laboratory bench being "only half-painted".

`TacticalGrid.blocked` samples the diagonal hatch's height **per endpoint**, `WorldCtx.floorYAt(xa, s
- xa)`, so a stripe out in the wilderness follows the slope between its two ends. Every one of those
endpoints lies **exactly on a cell boundary** — the family `x + z = k * HATCH` is clipped to the
cell, so an end sits on `x0`, `x1`, `z0` or `z1`. And `CityConfig.worldToCell` is `Math.round`, not
a floor: `x0`/`z0` round back into this cell, `x1`/`z1` round into the NEXT one.

Invisible everywhere it had been used. A city floor steps only at a curb and `floorYAt` routes
through the tile grid there anyway; the wilderness relief is continuous, so a hair either side of a
boundary answers the same. A facility bench is the first surface where two edge-sharing cells stand
**2.0 units** apart — `FacilityTables.groundY` returns `BENCH_H` over a table cell and 0 beside it —
and a stripe that read the neighbour was drawn at `y = 0.06`, a metre down inside the casework.

Measured on one 3x2 island bench at (5,5)-(7,6), hatch endpoints landing on the worktop:

| cell | before | after |
|---|---|---|
| (5,5), (6,5) — far neighbours are bench | 14/14 | 14/14 |
| (7,5), (5,6), (6,6) — one outer side | 10/14 | 14/14 |
| (7,6) — far corner, two outer sides | **6/14** | 14/14 |

So it is not a triangle of each cell, it is the block's **+x/+z rim** — which over a whole run reads
as a table hatched on one half. Inside a run the far neighbour is another bench and the wrong lookup
happened to give the right answer.

Fix: `hatchY`, which nudges the sample `EPS = 0.01` toward the cell CENTRE before calling `floorYAt`.
The vertex still lands on the true endpoint, so the stripe geometry is unchanged; only the height
lookup moves, by far less than any relief the wilderness carries. Verified in the built frame: the
island and the casework runs hatch edge to edge, and geometry readback over the bench footprint gives
92 verts at `BENCH_H + Y` and 12 at floor — those 12 are the arms of the neighbouring walkable cells'
corner crosses, which belong to those cells and are correct.

## The facility gets light SOURCES — masts, ceiling fixtures and window spill — Facility Phase 3b

Phase 3a made a facility interior its own lighting ENVIRONMENT and gave it no light SOURCES. Every
room was lifted uniformly, which says the lights are on but never says where they are; the compound
outside had nothing but the moon; and a lit building gave away nothing from across the lot.

**The pool was already paid for.** `FacilityScene` has built the full 12-slot `LampLights` pool since
phase 0 and handed it no bulbs, purely so `NUM_SPOT_LIGHTS` matches every other area kind. Those
lights were already in every lit material's program key and already running their per-fragment loop.
Claiming them costs **zero** new programs — A/B'd, see below — and two features arrive free with
them, both keyed off `lampLights.active()`: the fake actor ground shadows (`LampShadows`) and the
real 512² shadow maps on the low 8 slots.

Three pieces, two files.

**`FacilityLamps`** places both bulb families off the tile grid, deterministically, no rng. Outdoor
masts follow a three-row table of (surface stood on, surface bordered) — walkway/road, lot/walkway,
grass/walkway — which is the kerb along the main road, the lot's edge against the sidewalk and the
park path, gated on `(col + row) % 6`. A mast stands on the grid VERTEX and registers in
`lampCorners`, so `ActorAnim.cornerBend` routes a diagonal slide around it exactly as in a city.
Ceiling fixtures are one per `m.rooms` entry at `ROOF_Y - 0.2`, aiming straight down. Nothing
flickers (a powered compound), so `phase` is 0 everywhere, `LightCone.pulse` is never called, and the
per-frame cost of the whole feature is one `lampLights.update`.

**`FacilityGlow`** is every additive quad in ONE draw call — lamp heads, ceiling panels, room floor
pools, window/door ground spill. They differ only in brightness, which rides `MeshBufTools.quadC`'s
per-vertex grey, so the material carries hue and HDR multiplier once. The ceiling panel is its own
mesh and NOT in `Shell.roof`, so it survives the roof fade and is what the player sees inside; from
outside the opaque roof depth-rejects it (additive with `depthWrite` off still depth-TESTS). Spill is
static because a facility door is glazed and `canSeeThrough`, so light crosses a shut leaf.

### The trap: additive quads authored against a 0..1 intuition annihilate this art

`C_POOL` was derived from `LAMP_COLOR`'s own `Y_linear` 0.435 and came out **0.25**. Measured in the
built frame: **Y 0.530 against a lit lab floor's 0.0168 — 31x the surface it was supposed to be lying
on**, a white blob with no shape left in it. The error is not in the blend, it is in the SURFACES:
this game's art is painted very dark (lab floor albedo 0.0607 linear) and its interiors render around
Y 0.017, so nothing can be predicted from the additive colour alone. Fitted off the frame instead —
rendered luminance came out **~1.3 per unit C** in this range, not the 2.05 a single blown-out sample
suggested, so the first correction (0.006, 1.47x) undershot as badly as 0.25 overshot.

| | value | measured |
|---|---|---|
| floor pool | `C_POOL` 0.25 -> 0.006 -> **0.012** | 31x -> 1.47x -> **1.93x** the same room's plain floor |
| ceiling panel | `C_PANEL` 1.0 | Y 0.900, reads as a fitting, blooms |
| window spill | `C_SPILL` 0.02 | pavement under the openings **0.020-0.038**, the gaps between them **0.006-0.009** |

The spill scan is the one that proves the geometry: 18 samples across the pavement south of a wall,
lifted 3-5x exactly under each window run and flat everywhere else.

### Zero new programs, and a pre-existing gap found while proving it

A facility entry adds **5 programs, all `depth`** — and it adds the SAME 5 with the whole lighting
pass switched off behind a temporary `__nolamps` flag (masts 0, ceilings 0). So this change costs
nothing, and the 5 are a standing gap: `compileAsync` does not compile shadow-map depth programs, and
the facility warm scene is compiled but never RENDERED, where the city's is (`comp.render()` at the
end of warmup). A city entry shows the same shape at 12 (5 depth + 5 lambert + 2 physical).

### Things that were nearly wrong

- **The prop's head is not at its centre.** `Models.normalize` centres the bbox in X/Z, and this glb's
  mast sits at local z -0.062 with the housing hanging off toward +z — so a bulb placed at the
  placement point would hang in mid air beside the fixture. `LAMP_HEAD_Y/Z` are measured off the built
  glb, and `LAMP_H` 5.9 is chosen so `LAMP_H * LAMP_HEAD_Y` = 5.60 = the city street bulb's own
  height, which lands `LampShadows`' `refY / post.y` on exactly 1.0 and needs no tuning.
- **`DoorCell.inDir` is the side the LEAVES SWING into**, not the side the lot is on. The door spill
  has to find the outdoor side itself, and only on the PERPENDICULAR axis picked off the same
  `alongX` the quad is built on — reading a neighbour along the wall line answers about the wrong
  axis and can spill a doorway's light through the masonry beside it.
- **`CEIL_MUL` is 3.3 and that is not a taste knob.** `INDOOR.direct` scales every direct light
  indoors, so a fixture at `mul` 1.0 arrives at 0.3 of a street lamp. `1 / INDOOR.direct` is the
  compensation; reaching for `LAMP_LIGHT.intensity` instead would move the city and the tunnels.
- **`VisionMask.patch` is NOT gated on attachment**, so the glow material warms the same program the
  real build renders. Checked rather than assumed — the indoor mask's `patch` IS gated, which is why
  `View.hx`'s warm block brackets the facility block with attach/detach.

**Verdict: shipped.** 35 masts, 25 fixtures over 25 rooms, 12 slots claimed. +3 draw calls (mast
batch, cone batch, glow mesh), 0 new programs, no per-frame work beyond the pool update. Perf in ms
still unmeasured — the window has never been OS-foregrounded (topbar reads 1 FPS).

## The lamp head glows off the glb, not off a card — and the panes bloom — Facility Phase 3b fixes

Four reports on 3b, all art: the cones started above the lamp, the head glow read as a sticker, the
ceiling pair was not wanted yet, and the windows did not glow from outside.

**Cones.** `RenderConfig.LAMP_CONE.startFrac` is **−0.1** — negative, which lifts the shaft a tenth
of the bulb height ABOVE the bulb so it reaches up into a street lamp whose glowing hood sits over
its light position. A facility mast's `bulbY` (`LAMP_H * LAMP_HEAD_Y` = 5.605) already IS the lens
plane, so the shaft started at **6.17**, a third of a unit clear of the top of the whole 5.9 post.
`LightConeOpts` gained an optional `startFrac`; the facility passes 0.

**The head.** It was an additive quad in `FacilityGlow`, posed FRONTAL (fixed yaw, `Sprites.TILT`) —
the right rule for an effect anchored to a world object, and the wrong tool for one anchored to a
mast that *yaws to face the surface it lights*. Fixed yaw against arbitrary yaw put the card across
the housing at whatever angle the placement happened to give it.

It glows off an **emissive map on the glb** now, the way a street lamp's lens does. AGENTS.md said
hand-painting one into an unknown TRELLIS atlas was not worth it; that is true and it does not have
to be hand-painted. The mask is **generated** — [`tools/emissive.py`](../tools/emissive.py), which
took three passes to get right and each failure is the interesting part.

**Pass 1, the whole head box** (centroid y > 0.44, z > 0.035; 220 tris, 7.25% of the atlas). The head
is a flat SLAB, so its biggest face is the top — pointing straight at a camera that looks down. It
read as a glowing white card lying on the mast.

**Pass 2, downward-facing triangles** (averaged `NORMAL`, `ny < -0.5`; 160 tris). Reported as *still*
wrong, with white polys on the pole, blamed on a generated mesh's normals. The normals were fine and
the diagnosis was wrong, which is why it got measured: rasterize the mask, then test every UNSELECTED
triangle's UV centroid against it. **22 of them sampled a lit texel, spread from y −0.498 to +0.484
and z −0.057** — the mast, down to the base plate. It was never the selection. It was the **2px
dilation**, the one that pushes the mask into the chart gutter so a resize and bilinear sampling do
not read black at a chart edge: on a mosaic atlas the next chart along is an unrelated part of the
surface, and 2px is enough to reach it.

**Pass 3, a box and a bleed mask.** Selection is a bounding box on the triangle centroid and nothing
else — no normals, stated in the coordinates the tool prints, verifiable by eye. The dilation is
masked against the rasterized coverage of every unselected triangle, and the tool reports how many
unselected triangles still sample a lit texel. It reported 22 → 0. **It was still wrong**, and the
specks were still there.

**Pass 4, and the one that actually holds: rasterize CONSERVATIVELY, and check per TRIANGLE.** Both
halves of pass 3 were too weak in the same way.

- `PIL.ImageDraw.polygon` fills by pixel CENTRE, so **a chart thinner than a texel covers nothing at
  all** — and a TRELLIS atlas is full of those. A chart that rasterizes to nothing is invisible to
  the bleed mask while the GPU still samples the texel under it. Fix: rasterize at 4x and max-pool
  down, so a texel counts as covered if ANY part of a triangle falls in it, plus `outline=255` for a
  triangle so thin even that misses. And grow the unselected coverage by one texel before
  subtracting, because a fragment does not sample one texel — bilinear reads a 2x2 neighbourhood.
- The bleed CHECK sampled each unselected triangle's UV **centroid**. A triangle with one lit corner
  still draws a speck. Fix: test the triangle's whole conservative footprint, bbox-rejected first so
  the loop stays cheap.

Re-audited under the strong test, the mask pass 3 called clean bleeds onto **9 triangles, y −0.476
to +0.463, z −0.074** — the pole, down toward the base plate. Exactly the reported specks. Under the
new pipeline, 0.

Two more things the passes settled. Author the mask at the entry's own `tex` (320 here), not at 512 —
`models.mjs` resizes it, and the resize re-introduces the ramp the bleed mask just removed. And
**where the glow goes is an art call the camera makes, not a physics one**: the head is 0.35 x 0.20 x
0.43 world units, so its lens faces away from an overhead camera and a physically-correct lens-only
map is invisible in game. The shipped box is `y ≤ 0.4845` — lens plus the sides, **top excluded**:
194 tris, 7.0% of the surface, which reads as a bright edge on a dark housing from the game camera
and as a glowing head from anywhere lower. The top face is what made pass 1 a white card.

**Windows.** `WINDOW_EMISSIVE` 0.55 → **2.2**, and the number is arithmetic. Bloom runs on the
composer's LINEAR target, before `OutputPass` tone-maps, so a pane blooms when `texel_linear *
intensity` clears `BLOOM_THRESHOLD` 0.9. The art's glass band is sRGB 144-207 = linear **0.26-0.62**
(the same histogram `addPane` splits its alpha on), so 0.55 put the brightest glass texel at 0.34 and
nothing crossed — the panes were bright, never glowing. 2.2 lands the band at 0.57-1.36: the bright
half of every pane blooms onto the facade around it, the dark frame (16-127) never does.

**Ceiling pair off.** `FacilityStyle.CEIL_GLOW = false` gates the panel and the floor pool. The
fixtures still exist and still claim spotlight slots — only the two drawn quads are gone.

Verified live at 60 FPS: 30 masts, 17 fixtures, 44 window runs, **108 programs, unchanged** (the
emissive map rides the material the warm scene already compiles). Draw calls unchanged — the glow
mesh survives on window/door spill alone.

## The window spill fans, and it casts actor shadows — Facility Phase 3b follow-up

Two art notes on the spill quads: the patch outside an opening was a rectangle, and nothing standing
in it threw a shadow.

**The fan.** A rectangle reads as a projected slide, not as light. An opening is a finite aperture and
every point of it lights every point of the ground, so what falls out of it widens. `FacilityGlow
.spill` now emits a trapezoid: the far edge is `FacilityStyle.SPILL_SPREAD` **4.0** wider per side
over a `SPILL_DEPTH` of **8.0** — one cell per side over two cells of depth, a ~27 degree fan. Wide
enough to read as a fan, narrow enough that two neighbouring runs do not merge into one lit band. The
uv stays 0..1 across the quad so the shared rounded-box gradient still fits it: the fan is two numbers
and no extra geometry, no extra draw.

**The shadows, and the plumbing they needed.** Every fake actor shadow in the game comes from
`LampLights.active()` — `View` hands that one array to `Actors.setLamps` each frame. A window is a
light with **no pool slot**: what it puts on the ground is a static quad, and giving it a real
spotlight would starve the 12 slots the masts and ceiling fixtures already compete for. So it could
never appear in `active()` and never cast. New `Area3D.shadowLamps()` — a static, built-once list of
`LampPost`s that reach `LampShadows` and nothing else; `[]` in the city, the tunnels and the
wilderness, where every light does own a slot. `View` concats only when it is non-empty.

**The height is what makes it look like a window, and it is free.** `CastShadows` has no notion of
light height; `LampShadows` compensates by scaling both the length and the reach by `refY / post.y`.
A run's glazing is vertically centred in the wall whatever its length (the pane is sized off
`WINDOW_ASPECT` and the sill takes up the slack), so `SPILL_Y` is `WALL_H / 2` = **3.0** against a
reference bulb at `CELL * yMul` = **5.6**: `low` **1.87**, reach `min(2 * 4 * 1.87, 3 * 4)` = **12**
units = 3 cells, `lenMul` `0.6 * 1.87` = **1.12**. Long shadows over a tight pool — which is what
light out of a window at chest height does.

**One source per CELL of a run, not one per run.** The reach is 3 cells and a 3-cell run is 3 cells
long, so an actor standing off one end of a centred source would be shadowed *along* the wall instead
of away from it. ~120 sources in a generated facility; `CastShadows` sorts and keeps the nearest
`LAMP_SHADOW.max` 2 per actor, so the cost is one distance test each.

Verified live at 60 FPS: 44 window runs and 23 doors on the built area, **108 programs, unchanged** —
nothing here touches a material.

**And the trapezoid still read round.** The fan alone did not fix it: the alpha map is
`Textures.makeRectGlowGradient`, whose corner radius is 0.16 of the canvas against a half-extent of
0.30 — **0.14 of straight run**, which is a squircle, not a box. That is right for the sewer wall
fixture's diffuser it was written for and wrong for ground cut by the straight jambs of an opening,
and worst on a DOOR, whose patch is one cell wide and so read as a plain blob. New optional
`radFrac`, default 0.16 so the sewer is unchanged byte for byte, `0.0` from `FacilityGlow`. Measured
on the two generated canvases: corner texel (14,14) **233 → 255**, diagonal (8,8) **0 → 92**, the
straight edges and the mid-row profile identical. The falloff still curves round the corner, which is
what a soft edge does.

## The compound gets a kerb, paint and a real park — Facility Phase 4

Outdoor dressing, and the two asks that came with it: pavement borders "like on the streets", both
at the road and at the park, and the road and the park ground sitting "a little below the walkway".

**THE SIGN IS THE WHOLE DESIGN, and it is the opposite of the city's.** `render.world.Ground` raises
its walkway `CURB_H` and leaves the road at 0. A compound cannot: `generateBuilding` writes a 2-cell
pavement apron around EVERY structure — the walkway is not two strips, it rings all three buildings —
and an indoor floor is y = 0, so raising the pavement puts a step down into every exterior doorway
and floats every wall base. So the pavement and the LOT stay at 0 with the floors, the walls, the
doors, the benches and every glow quad, and only the two surfaces nothing stands on drop under them:
`FacilityStyle.KERB_DROP` = `RenderConfig.CURB_H` = 0.2, road and grass at **−0.2**. The lot stays up
for one more reason: the sidewalk's 4×2 parking entry would otherwise be a kerb laid across a
driveway.

**One hook carried the whole area.** `FacilityTables.groundY` was already `WorldCtx.ground` (the
worktop, phase 2). Adding the surface step to it moved actors, decals, the slime trail, `PathLine`,
`TacticalGrid` and the cursor pick with no other edit. Measured over the built grid: road and every
park tile **−0.20**, walkway/lot/wall/floor **0.00**, bench cells **2.00**.

**The kerb is the city's, extracted.** New `render/world/Kerb.hx` holds the segment collect and the
mitred emit; `Ground.hx` now calls it with `(BW, BT, H, 0)` and the facility with `(BW, BT, 0,
−KERB_DROP)` — the two differ only in which of the pair moved. The miter is not optional here: the
park is *enclosed* by walkway, so its four corners are concave and two unmitred bands at one y
z-fight. Measured on the built area: **135 kerb segments — 61 walkway→road (the full 65-cell sidewalk
less its 4-cell driveway) and 74 walkway→grass — and 4 risers**, exactly the driveway, where the lot
closes its own step in asphalt. **0 wall slots**: no dropped surface touches masonry on a generated
compound, so that branch is a guard and never fires.

**The paint needed no art.** Lane lines and parking bays are geometry in the city's own
`ground-road-paint.png`, one merged mesh: the road band is found by its row extent (it is straight,
full width and has no intersection, so none of `Ground`'s crossing machinery is needed) and takes
dashed/double/dashed; a bay is struck wherever a LOT cell abuts a pavement apron, which IS the edge
cars park at, so no rectangle has to be found. Gated on the coordinate ALONG that edge, not on
`(col + row)` — the diagonal gate a lit line uses comes out stepped on a straight run.

**The park is now a layout, not a dice roll.** `generatePark` writes a 2-cell path down the park's
long axis as plain WALKWAY, which is the trick: it arrives kerbed and lit for free, because both the
ground pass and `FacilityLamps`' lit-line table key on a walkway boundary. Benches alternate sides
every 5 cells as `TILE_GRASS_UNWALKABLE`, and planting comes off 4 clump centres with density falling
with distance instead of the flat 10/30/60 per-cell roll. Generator-side, so NEW AREAS ONLY, and
nothing migrates. Verified headlessly by generating throwaway `AreaGame`s into the live region and
removing them again (768 areas before and after): 4-5 benches alternating on a 5-cell rhythm, planted
cover **42% → 22%**, and the path a clean 2×30 run from the sidewalk to the far apron.

**And the park needed a cap.** With a path through it, every grass cell down both sides borders a
walkway and qualifies as a lit line — **16 candidates** on a generated area, which lines a lawn with
street lamps. `PARK_LAMPS` = 4, the user's own number, taken row-major so which four is deterministic.

The bench is `facility/bench-park`, TRELLIS off a gpt reference: **94,576 → 2,772 tris at tex 352 =
44 texels/tri**, split 1.27× so the offline route worked, `dropMR` (metal max 255) and a straight
`baseColor` darken from atlas 86/89/90. Two reference notes worth keeping. `propstat` called the raw
drop TOUCHING THE EDGE and it was not — `BG_TOL` 60 keys gpt's own vignette as subject, so the
reported bbox was the whole canvas while the real subject had 80 px of margin; and the drop came in
at subject p50 **46** against the 69-77 that bakes correctly, fixed by `--lift 73` rather than a
re-prompt. It is the second prop with an AUTHORED FRONT after the guard rail: **the backrest sits at
z −0.163**, measured off the built mesh, so the front is local +z and `FacilityGround.facing` turns
each bench at the walkway beside it. A bench facing the shrubbery is the whole failure mode.

Verified live: **0 console errors**, programs **109** on facility entry — the same +5 depth-only gap
phase 3b already recorded, so nothing here compiles a new permutation.

## The kerb was drawn on two of four sides — Facility Phase 4 follow-up

`Kerb.emit` wound its two quads off the direction of the segment `a->b`, and `FacilityGround`
supplies that direction per cell edge. Measured by calling `Kerb.push`/`Kerb.emit` headlessly on one
cell, four times, once per edge:

| dir | outward n | top band normal | drop face normal | drawn |
|---|---|---|---|---|
| 0 (−z) | (0,−1) | **(0,−0.8,0) DOWN** | +z, **inward** | **no** |
| 1 (+z) | (0,+1) | (0,+0.8,0) | +z | yes |
| 2 (−x) | (−1,0) | (0,+0.8,0) | −x | yes |
| 3 (+x) | (+1,0) | **(0,−0.8,0) DOWN** | −x, **inward** | **no** |

So a kerb existed only on a surface's **+z and −x sides**, and both quads of a segment failed
together. What showed on the other two was `KERB_DROP` = 0.2 of unglazed slit between the walkway lip
and the surface below — no underside on the slab, so from a camera looking down it read as a **black
strip**. The bug shipped in the extraction and the city could never show it: `Ground.hx` builds its
border mesh `DoubleSide`, which flips the normal for a back face in the fragment shader, and
`FacilityGround.add` builds every ground mesh `FrontSide`.

Fix is four lines in `Kerb.push`: normalise `n` first, then swap the endpoints when
`(bx−ax)*nz − (bz−az)*nx < 0`. Re-measured after the build, all four dirs now give top +y and face =
outward. The endpoint SET is unchanged, so the miter's `vkey` join is untouched; the UV runs `0..ul`
along `a->b`, so a reversed segment tiles the other way and nothing else notices. The city is
DoubleSide and does not change.

**The trap worth keeping: a winding bug under `DoubleSide` is not latent, it is invisible.** It was
carried into a `FrontSide` consumer intact and only there did it become a symptom, in the two
directions out of four that the original author's own cell happened not to exercise.

## Four park lamps, all four on the wrong side of the park — Facility Phase 4 follow-up

`FacilityLamps.LINES` row 2 was `{ on: GRASS, by: WALKWAY }`, and every pavement in a compound
borders the lawn somewhere: the park is fully RINGED by walkway (measured, 120 grass↔walkway edges,
all against walkway). Row-major scan plus the hard cap of 4 therefore spent every lamp on the rim
before reaching the path — replayed against the real `borders()` on a live area, the four masts
landed at `[5,19] [11,19] [2,22] [13,23]`, i.e. the park's top, left and right edges, **with every
head aimed OUT of the park** (the head hangs toward `by`).

The test that separates the two is `FacilityModel.isParkPath`: a walkway cell whose walkway RUN,
measured across one axis, has grass at both ends. The generator writes the path as plain
`TEMP_WALKWAY` — which is what made it arrive kerbed and lit for free — so there is no id to test and
no rect in `generatorInfo`; what IS distinctive is lawn on both sides. Capped at `PATH_MAX` 4 cells,
or a scan crosses a compound and calls the main sidewalk a path. Verified on a live area: it returns
exactly the 50 cells (7,19)..(8,43), the whole 2×25 path and nothing else.

The scan now COLLECTS and places afterwards, because the cap cannot be applied cell by cell: taking
the first four of a row-major scan takes the first four ROWS of a path that is twenty-five long. Park
candidates are thinned with `(i + 0.5) * len / take`. Replayed: 7 candidates, all on the path verge
(cols 6 and 9 against the path at 7/8), picked at rows 24/30/36/42 over a 19..43 span. Total mast
count unchanged at 27, matching `__facility().masts`.

Aliasing worth knowing about and NOT worth fixing: candidates alternate sides because the
`(col + row) % LAMP_SPACING` gate puts one verge on rows ≡ 0 and the other on rows ≡ 3, so an even
stride lands all four on one side. A path lit down one side is what a real path looks like.

## The park's planting was four dice, not a layout — Facility Phase 4 follow-up

`generatePark` drew `PARK_CLUMPS` = 4 centres uniform over the park rect and planted within
Manhattan `PARK_CLUMP_R` = 4 of the nearest. On the live 12×25 park that left rows 38-43 — the whole
south end — with nothing on them. Not luck: re-ran the old planting 2000× on that exact rect and got
**24.8% lawn planted, 29.1% of park rows completely bare, mean longest unbroken bare band 5.8 rows of
25**, tail out to 19. Four samples cannot cover a rect however far each one reaches.

Replaced with a LATTICE: a centre every `PARK_CLUMP_STEP` = 6 cells, jittered ±1 off its node, and
`plantClump` grown around each — a tree ON the centre, trees or bushes to `PARK_CLUMP_R` = 3 halved,
bushes thinning past that, open lawn beyond. Only `TEMP_GRASS` is overwritten, so the path, the
benches and the neighbouring clump survive. Measured over 6 fresh in-engine generations: planted
**30.7-39.0%**, empty rows **0-2 of 25-30**, longest bare band **0-2**. An ASCII dump reads as tree
cores with bush skirts and real lawn between them.

`PARK_CLUMP_STEP` cannot go past 7 on this park: `gw` is 12 and the lattice starts at `STEP/2`, so
step 8 puts a single node column at x 6 and leaves the east half to a clump edge.

Dead trees dropped from the park at the same time. `finalizeTiles` picked
`Const.TILE_TREE1 + Std.random(Const.TILE_BUSH - Const.TILE_TREE1)` = `Std.random(4)`, and id +3 is
`wild/tree-dead` — 2 of 23 trees on the live area were snags. `Std.random(3)`. A maintained
institutional park does not keep dead wood.

## The park gets a railing — `facility/fence-park`

One segment per grass cell edge facing the pavement RING, and none against the path: `isParkPath`
again, the same predicate the lamps needed. No gate cell has to be cut for the way in — the path
meets the perimeter walkway-to-walkway, so those are not grass edges and the loop never reaches them.
Measured on a live area: 120 grass↔walkway edges, **70 rim and 50 path**; on a synthetic 12×14 park
built to exercise the code, 48 rim / 28 path and the batch placed **48**, zero on the path.

Second prop in the repo sized to TILE after the guard rail. `FENCE_H` is DERIVED, not chosen:
`CityConfig.CELL / FENCE_ASPECT` with the aspect measured off the glb (bbox 1.002 × 0.354 = 2.83), so
one segment draws 4.0000 units and a run meets end to end. That is also why the reference asks for
flat square end posts — a finial would show the join. `FENCE_INSET` 0.3 keeps it out of the kerb
band, which protrudes `WALKWAY_BORDER_W` over the lawn at the higher level.

The prop: **96,220 → 5,056 tris at tex 512 = 51 texels/tri**, split **1.38×** so the offline route
worked. This is the LACE case `AGENTS.md` warns about — two dozen slim balusters with real
see-through gaps — and it came back well under the ~2× line anyway, so holes did not cost the offline
route here. Components 4 at 86.3%, top pieces 41,931 / 2,709 / 1,743 / 1,701: the rail-and-baluster
span plus the end posts, the bolted-assembly shape the guard rail, the mast and the bench all record,
not the 96-at-24% blob cloud the gate exists to catch. `dropMR` (metal max 255), and `baseColor`
`[0.35, 0.52, 0.74]` — a PER-CHANNEL correction, not a flat darken, off a warm atlas mean 80/66/57;
it lands all three channels on sRGB 48, dead centre of the 46-52 family. Reference came in at subject
p50 54 and took `--lift 73`, the same too-close-to-its-own-key subject the guard rail logs (grey
steel against the `#5a5d63` backdrop, subject margin 32).

It rides the `green` array rather than a field of its own: everything that array is FOR applies to it
unchanged — one `Models.cull` per frame, one row in `__facility().batches`. The batches loop had to
learn that the last row is not in `GREEN`.

## The dead snag, the overhanging bush, and a park that joins up — Facility Phase 4 follow-up 2

**Dead trees, retroactively.** The generator stopped writing `Const.TILE_TREE1 + 3` last pass, but
that is new-areas-only and an existing park still has those cells on its grid. So the render side
drops the row too: `FacilityGround.GREEN` no longer lists `wild/tree-dead`, and `green` folds the id
onto the conifer on the way in. A REMAP and not a skip — a green cell with nothing drawn on it is a
wall the player cannot see. Measured on a freshly generated park: batches come back conifer /
broadleaf / broadleaf-full / bush-low / bench, no `tree-dead` row at all.

**Bushes over the railing and over the path, and the arithmetic was there to be read.** `bush-low`
measures aspect **1.91**, and `GREEN` draws it at `h` 1.1, so it is **2.10 world units across** — a
radius of 1.05. Its `jitter` 0.28 of a 4-unit cell reaches 1.12. **1.12 + 1.05 = 2.17 against a
half-cell of 2.0**, so at full lean a bush crossed its own cell boundary by 0.17, which put it over
the park path — and 0.47 past the railing, which stands `FENCE_INSET` 0.3 inside that boundary.

`lean()` cancels the offending axis: an offset that points at a cell which is not lawn is dropped,
one axis at a time, leaving the inward half of the spread untouched. Measured over 140 bushes on a
generated park, minimum clearance from a bush's rim to any non-lawn boundary went from **−0.17 to
+0.945**, and to the railing's inner face **+0.56**. Nothing to tune: it is a predicate, not a knob.

**Fence corners crossed instead of joining.** A corner cell fences two perpendicular edges, and each
run reaches its full half-cell along its own axis while the other run's line sits `FENCE_INSET` short
of it — so the two overlapped by exactly 0.3 at each end and read as one fence laid over another.
Every end that meets a perpendicular run is now pulled back to that run's line, with the segment
shifted half of what it lost so its far end stays put. Verified on a synthetic 12x14 park: 48
instances in **two** scales, 40 at 3.9986 world units and **8 at 3.6987** — 0.925, i.e. 3.7/4.0, and
8 = 4 corners x 2 runs. The NW corner's north run now spans x [−183.70, −180.00] and its west run z
[−195.70, −192.00]: each ends exactly on the other's line, meeting at (−183.70, −195.70).

The cost is that shortening is a UNIFORM scale, so a corner segment is 7.5% shorter in height too —
0.11 world units, under 3% of a cell. The alternative is a second glb cut for corners, which is not
worth a draw call and an atlas.

**A shrub line under the railing, and the planting doubled.** `generatePark` now walks the park
rect's border and writes a bush every `PARK_EDGE_BUSH_SPACING` = 3 cells, gated on `(x + y)` — which
on a rim run has one coordinate fixed and therefore steps evenly along it, the diagonal it would step
on elsewhere never arising. Only lawn is overwritten, so the two cells where the path crosses the rim
stay open and the way in does not need cutting.

`PARK_CLUMP_STEP` 6 → 4; clump count goes as the inverse square, so 2.25x the centres. Measured over
6 fresh in-engine generations against the previous pass:

| | before | after |
|---|---|---|
| trees | 26-29 | **45-55** (1.9x) |
| bushes | 64-102 | **131-174** (1.8x) |
| lawn planted | 30.7-39.0% | **58.3-70.4%** |
| rows completely bare | 0-2 | **0-1** |
| dead-tree tiles | 2 of 23 trees | **0** |
| rim bushes | — | 35-45 of ~76 rim cells |

Region count 768 before and after every probe, so the throwaway `AreaGame`s leak nothing.

## The bench needed COLOUR, the canopy needed burying — Facility Phase 4 follow-up 3

**Sources moved.** Every facility glb and its archived reference now lives in `models-src/facility/`
(`bench-park-100k`, `fence-park-100k`, `lamp-post-100k`, each with its `-src.png`, plus
`lamp-post-emissive.png`), matching what `sewer/` and `wild/` already do. Three `src` / `emissiveSrc`
paths in `models.json`; `make models` resolves subdirectories already.

**The bench's slats had no gaps, and the cause was that it was GREY ON GREY.** TRELLIS segments the
subject against the flat `#5a5d63` backdrop, and grey painted steel a couple of values off that
backdrop gives it nothing to resolve a hole against — so it filled the spaces between the seat slats
and returned one solid board. The fix was **colour, not settings**: a dark bottle-green cast frame
with pale olive timber separates on hue as well as value, and the gaps came back as real openings.
Two other things earned their place in the prompt — saying what the gaps ARE ("clear open gaps of
empty space… must read as real openings, not painted lines or grooves") with a count, five seat slats
and four back, and shooting **three-quarter** rather than side-on so the seat top and its gaps are
both visible to the generator.

The result: **98,934 → 3,650 tris at tex 432 = 51 texels/tri**, split 1.31×, `dropMR`, `baseColor`
`[0.65, 0.52, 0.66]` — a per-channel correction off a GREEN atlas mean 58/66/59, landing all three
channels on sRGB 46-48. Components 16 at 59.7%, top five 29,525 / 3,401 / 3,202 / 2,179 / 2,107 —
and here that is close to a **pass signal**, because those small pieces are the individual slats and
slats that are separate components are exactly what the regeneration was for.

**A regenerated prop's FRONT is not where the last one's was.** The old bench lay along local z and
faced +z. This one lies along local Z with its depth on x, and the backrest — being the tall part —
measures at mean **x −0.138** against the mesh's own −0.012, so it faces local **+X**. The yaw that
aims a +x front down (dx, dz) is `atan2(−dz, dx)`, which is the mast's `atan2(DC, DR)` **less π/2**,
and that is the one line in `facing()` that had to move with the model. Verified over every bench in
a generated park: the front's dot product with the walkway direction beside it is **1.0000**.

`PARK_BENCH_H` moved too, 1.8 → **2.34**, because the aspect went 1.98 → **1.52**. It is sized for
LENGTH (3.56 units in a 4-unit cell, what reads from overhead), which costs a bench standing 1.17 m
rather than 0.9 m. The alternative was a stubby 2.74-unit bench, which is worse from above.

**`tree-broadleaf-full` gets buried 7% of its height.** Its canopy runs to the very bottom of the
model and ends in a ragged fringe of holes and spikes where a trunk ought to be — TRELLIS was never
given a trunk to build, so no regeneration fixes it, and the wilderness's `r` does not either (that
one tilts a prop into a SLOPE, and this is worst on FLAT ground). `WildStyle.BROADLEAF_SINK` = 0.07,
read by `WildProps.sit` for the scatter and by `FacilityGround.GREEN` for the same glb in a park —
one constant, because it is a property of the mesh and not of either area. In `sit` it rides the same
instance scale as the slope correction, so a half-size thicket tree is buried half as deep. Measured
on a built park: base y **0.665 below** the surface, exactly 0.07 × 9.5.

**`tree-broadleaf` is a dead tree.** Its own `models.json` line says "bare broadleaf, thick limbs, no
foliage" — the previous pass removed only the snag at `TILE_TREE1 + 3` and left this one, which is
why dead wood was still showing. Both are gone from the park now: the generator deals
`Std.random(2) * 2` (ids +0 and +2, the two in leaf), and `FacilityGround` folds +1 → +2 and +3 → +0
on the render side so an area saved earlier is covered too. `GREEN` is four rows. Measured over 6
fresh parks: tile ids **5, 7, 9, 10, 11 only** — no 6, no 8.

**The railing stops where the path's kerb starts.** A run dying into the path mouth was taken to the
cell boundary, laying its last stretch on top of the path's own border band, which protrudes
`WALKWAY_BORDER_W` over the lawn. `endCut` now answers both pull-backs at one end — `FENCE_INSET` at
a corner, `WALKWAY_BORDER_W` at a path mouth — so the caller shortens by `lo + hi` and shifts by half
their difference either way. Verified on a synthetic park: 48 instances in **three** scales, 36 at
3.9986 (straight), **8 at 3.6987** (corners, 0.925) and **4 at 3.7987** (path mouths, 0.95 = a 0.2
cut) — 4 being 2 mouths × 2 sides, at x −166.10 and −153.90 against cell centres of −166 and −154,
i.e. shifted ∓0.10 away from the mouth.

**Trees doubled again, bushes untouched.** The tree zone was `d * 2 <= PARK_CLUMP_R` and is now
`d < PARK_CLUMP_R`. A Manhattan diamond of radius 3 holds 1 / 4 / 8 / 12 cells at d = 0..3, so the
core goes from 5 cells to 13: trees per clump 1 + 4×0.55 = 3.2 → 1 + 12×0.55 = 7.6, while bushes are
unmoved at 10.8 either way (12×0.45 core + 12×0.45 skirt against 4×0.45 + 20×0.45). Measured over 6
generations: **trees 45-55 → 80-102** (1.8×), **bushes 131-174 → 123-179** (flat), lawn planted
**58-70% → 73-81%**.
