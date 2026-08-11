# 3D render change log

Append-only log of every 3D/render experiment — landed, reverted, or rejected — with its measured
result and its traps. **The index, the measurement rules and the standing notes live in
[`3d-render.md`](3d-render.md) — read that first.** This file holds the bodies: find an entry by
grepping the change text out of that file's verdict table.

Entries record settled outcomes only. Every new entry gets one row in `3d-render.md`. When this file
reaches ~2600 lines, `git mv` it to `3d-changes-<YYYY-MM>.md` and start a fresh one.

Older entries live in [`3d-changes-2026-08.md`](3d-changes-2026-08.md) (rolled at 2664 lines).

## Landed

### Sewer ledge rim darkening — TRIED, REJECTED, REMOVED
The wall pass ended on a measurement: at `WALL_H 3.0` and the near-top-down sewer camera, wall FACES
are 0.67% of the 3D view against ledge TOPS at 14.68%. So the next dressing goes on the horizontal
surfaces. New `render.sewer.SewerGround` is the horizontal twin of `SewerDetail` (which owns the wall
face), called from `SewerGeom.build` beside it so `View.warmup` — which runs `SewerModel.demo()`
through that same function — pre-warms its materials with no second wiring point.

**The problem it solves:** from that pitch the ledge plateau and the floor read as two flat planes
3 units apart with almost no wall face visible between them, so the tunnel has a weak silhouette. A
band of grime/occlusion along the inner rim of every ledge is what separates them.

**It is the SAME pass as `SewerDetail.shadows()`'s strips with the cell test inverted** — that one
walks FLOOR cells and lays a band toward each solid neighbour, this one walks SOLID cells and lays it
toward each floor neighbour. The yaw table is **identical**, not mirrored: in both cases the
gradient's opaque end points at the neighbour that triggered the strip, so the same four
`(yaw, position)` rows apply. Planning notes that said "shift the yaws 180 deg" were wrong.

**No corner radials.** `SewerDetail` needs them for the nook two perpendicular bands cannot reach; a
ledge's exposed corners are CONVEX, so there is no nook — the two bands already meet there. And no
art at all: `Textures.makeShadowGradient()` draws the ramp on a canvas at runtime.

**Measured, habitat:** 104 rim instances at `y = 3.02` (`WALL_H + RIM_Y`), scale `4 x 1`
(`CELL x RIM_W`), opacity 0.45, one `InstancedMesh` — **38 -> 39 draw calls**. 104 rims against 104
wall faces is the expected identity: every face's solid side has exactly one mirror rim.

**Coverage is the number that matters here.** A rim-on/off PNG diff of the 3D-view crop changed
**5.83% of the view** (mean luma drop 7.7, max 28.7). The entire four-image wall-decal pass changed
**0.12%** of the same crop. Roughly 50x the reach for a fifth of the draw calls — which is the whole
argument for dressing the tops, quantified.

**Trap avoided:** the instanced-mesh lookup by `material.opacity` needs a capture window longer than
one frame. Backgrounded, the Electron window throttles to ~1fps, so a 500ms
`Object3D.prototype.onBeforeRender` capture returns an empty set and reads as "the mesh is not in the
scene". 2500ms found it. Same trap as the GPU-timing one: a backgrounded window lies about everything
time-based.

**Then it was cut, and the coverage number is exactly why the measurement did not save it.** In
motion the band shimmers, and zoomed in it plainly reads wrong. The cause is structural, not a
tuning miss: **nothing STANDS above a wall cap.** A roof gets this band because a parapet rises over
it; here the cap just ends, so the darkening is an unmotivated stripe floating over a wall face that
is *brighter* than the stripe — and its hard opaque end lands exactly on the ledge silhouette, where
subpixel disagreement between the quad edge and the geometry edge flickers as the camera moves.
Inset it and you get a bright rim line instead; soften it and it stops separating anything.

**Standing lesson: 5.83% of the frame changed is a reach number, not a quality one.** It says the
effect is visible everywhere, which is exactly what makes an unmotivated effect worse rather than
better. `SewerStyle` keeps a comment where the constants were so this is not re-derived.

### Sewer ledge-top clutter + floor decals — `SewerGround.scatter`
8 top-down images (4 on the wall caps: pipe run, valve wheel, rubble, moss; 4 on the walkway: two
puddles, a drain grate, a spill stain), hash-placed per cell and merged per image — **one draw call
per image whatever the level size**, because with no `Occlusion` pass underground nothing needs to
fade individually. `RoofDetails` instances per building for exactly that reason and could not be
reused. Habitat: **39 -> 47 calls**, 2.2k tris.

One `scatter()` drives both surfaces off `SewerScatterOpts`; `solid:true` walks wall-cap cells and
also selects the hash multipliers, and gates the two floor-only rules (no decals in the sludge
channel, halved rate in generator rooms — the 8-vs-20 split `sewer/Debris` already uses). Every quad
is clamped inside its own cell, which is what stops a prop overhanging the drop — much of a tunnel
wall is one cell wide.

**Organic vs manufactured is the axis that matters for variety, not per-image tuning.** A puddle, a
moss patch, a rubble pile take a FREE rotation and independent per-axis scale jitter (0.70-1.35),
because no two are alike. A pipe, a valve, a drain grate are never turned at all and jitter uniformly
(0.85-1.15): they came out of a mould, and a grate sitting at 23 degrees reads as a mistake rather
than as variety. Free rotation is what forces the fit test to use the ROTATED footprint
(`|w·cosθ| + |d·sinθ|`), shrinking both axes by one factor so the shape survives the clamp.

**The one real trap: DARK art on a lighter surface reads as a HOLE, and opacity is the wrong cure.**
gpt paints a rusted pipe near-black. Measured in texture space against the surface each lands on:
pipe **0.46x** the ledge cap, valve 0.48x, grate 0.42x the walkway, puddle 0.37x. Those byte ratios
understate it — three decodes sRGB to LINEAR before the Lambert multiply, so the valve is **0.19x**
the cap *in light*, and it rendered at luma 6.7 against 35.7. (That is 0.188, against the predicted
0.189: the renderer was exactly right, the art was 5x too dark.) Same trap the sludge tile hit.

Dropping material `opacity` fixes the VALUE and ruins the object — a see-through cast-iron valve.
So it splits by what the thing is: translucent art (both puddles 0.5/0.6, the stain 0.8) keeps a low
opacity, because shallow water really is see-through and letting the walkway read through it is what
stops it looking like a pit. Solid props stay at 1.0 and get their source brightened instead, by a
new per-label `"lift"` gamma in `textures.json` that `make tex` bakes (`out = (v/255)^g`, g<1 lifts
darks and leaves the top end alone). `lift: 0.75` moved pipe 0.46 -> **0.68x**, valve 0.48 -> 0.70x,
grate 0.42 -> 0.61x — matching `moss`, which at 0.70x always read correctly. In-render the ledge
band's dark tail went **min 3.0 -> 15.0, p1 7.7 -> 20.3** with its median untouched at 35: the holes
filled in, the cap did not change. Alpha is untouched by the lift, so hand-cut cut-outs survive with
no re-cutting. `alphaTest` is scaled by each type's opacity — three cuts on `opacity * texel alpha`,
so an unscaled threshold would eat the edges of exactly the types needing the softest ones.

**Rates by eye after measuring, not before:** 15%/12% left the caps visibly bare in the habitat, so
22% (ledge) / 16% (floor). A/B'd in-session: ledge props alone change 0.33% of the full frame in the
default pose, floor decals 0.52% of the 3D crop, both far above the wall decals' 0.12%.

### The footprint hash degenerates on row 0 and column 0 — `SewerModel.mix`
Reported as "top decals in 6 tiles one after another, looks too fake", and it was worse than that:
**eight in a row**, at `(0,0)` through `(7,0)`.

`hh = (col * A) ^ (row * B)` has no avalanche at all, and on the grid's first row the second term is
exactly **zero**, so it collapses to a pure arithmetic sequence. At row 0 the ledge hash is `col *
40503`, and `40503 % 100 == 3`, so `hh % 100 == (col * 3) % 100` and a "22% of cells" test selects
**cols 0-7, 34-40, 67-73, 100-107** — runs of 8 and 7, repeating every 33 cells. Column 0 collapses
the same way (`92821 % 100 == 21`) into an even ladder at rows 0, 1, 5, 10, 15, 20, 24... The live
scene dump matched the prediction cell for cell. Row 0 and column 0 are the always-solid **area
border**, i.e. the ledge band across the top of the screen, so the worst case sat where the player
looks. Both sibling passes had it too: floor decals combed row 0 at cols 0, 6, 12, 18, 24, 30 (step
17), `SewerDetail`'s wall decals at 0, 5, 10, 15, 24, 29 (step 21). `sewer/Debris` is the one that
got it right — it seeds `CityGen.mulberry32(h)` rather than slicing raw bits.

**Grid-wide statistics actively hid this.** Over 120x120 the raw hash gives a 22.2% rate against a
22% target and a run histogram nearly identical to a true RNG. The pathology lives only on the lines
where one term vanishes, and averaging over 14,400 cells buries it. Aggregate randomness tests cannot
see axis-aligned structure; look down the axes.

Two fixes, both needed, both measured over the same 120x120 grid:

| | worst run |
|---|---|
| raw hash | **8** (rows 0 and 41) |
| `SewerModel.mix` — xorshift32 over the same hash | 7 |
| + one prop per 2x2 BLOCK instead of a per-cell coin flip | **2** |

`mix` is xorshift32: shifts and xors only, so it is exact in Haxe/JS `Int` with no `Math.imul`
(`CityGen` needs `js.Syntax` for mulberry32's multiplies), plus a golden-ratio xor to kill the
`h == 0` fixed point that made cell (0,0) always place. It fixes the collapse — row 0 becomes
1, 3, 5, 12, 16, 18, 23, 31 — but an independent coin flip at 22% still deals runs of 5-7 somewhere,
and a run of 5 looks as deliberate as a run of 8. So placement also moved to **one prop per 2x2
block**, `RoofDetails`' sector idea in miniature, which caps a run at two by construction. The gate
is `pct * (eligible cells in this block)`, so a one-cell-wide wall — most of a tunnel — comes out at
the same per-cell density as an open plateau instead of twice it. Live after: worst row run **2** on
the ledge, **1** on the floor.

### Review fixes over the 3D-tunnel branch
Thirteen findings from a review of the whole uncommitted branch. The ones that touch the render:

**`DoubleSide` on the floor and the ledge was a side effect of not casting shadows.**
`SewerGeom.add` wrote `side: casts ? FrontSide : DoubleSide` — two unrelated decisions on one flag.
Both horizontals are wound so `computeVertexNormals` gives +Y and the sewer camera is always above
them, so a back face is never seen; the whole level now emits `FrontSide` and the back faces of
~3k ledge/floor quads stop being rasterized. Verified live: all 18 shell + dressing meshes report
`side 0`, nothing vanished.

**`SewerScene` returned the ALL-bulbs steady cone set in the bundle's `coneFlick` slot.** That slot
is documented as the FLICKERING batch, which `LightCone.pulse` and `CityArea.tick`'s lampMask loop
index against. A tunnel lamp never flickers, so the honest answer is an EMPTY set: the steady batch
is now built and discarded exactly as the city does it, and `coneFlick` gets
`LightCone.instanced(coneGroup, [], ...)`, which builds no mesh at all. Zero draw-call change (the
scene still holds one cone InstancedMesh) and the contract stops lying.

**`CameraRig.maxFootprintCells` hardcoded `RenderConfig.CAMERA`.** It sizes the AI spawn region, and
the presets went per-area when the tunnels landed. It takes a `CameraOffsets` argument now, and
`AreaGame.getSpawnRect` picks by area KIND rather than `isCity()` — so sewers and habitats stop
falling back to the 2D canvas rect (which scales with pixel count, the bug 414648a fixed for
cities). Measured at aspect 1.92: **city 411 cells, sewer 180**. Passing the city preset to a tunnel
would have over-sized the spawn region by 2.3x. fov stays global — no area kind changes it.

**Dead weight removed:** `Textures.loadRampTexture` (both grime bands now carry painted alpha),
`Sewers.FLOOR_DECOR_META` (its last reader went with the 2D sewer decorator), and the `Sewer.channel`
grid plus the O(w*h*9) pass that filled it on every build and every boot warm.

**`render.sewer.Debris` was `render.world.Debris` retyped**, down to the 8-try offset loop, and it
shadowed the class name. The sprite/transform/offset placement now lives once in
`world.Debris.addFragment`, which takes the ground test as an argument — a street tile in the city,
`SewerModel.isFloor` underground. What is genuinely different stays split: the city's radial cluster
against the tunnels' orthogonal one (a corridor is 3 cells wide, so a radius-2 spray would spend most
of its rolls on wall cells). The rest is `render.sewer.SewerDebris`, ~60 lines. Checked through the
static entry points: city LOW 452 spots / HIGH 58 / LOW+highCrime 1464 (the tier curve intact), all
in-grid; the warm-up demo tunnel 5 spots, every one on floor and every overhang landing on floor.

### Sewer grime: code ramp -> hand-painted alpha, and the exit ladder stands up
Two small ones, same theme: stop faking what the art can say.

**The grime band read vague, and the reason was the alpha.** `SewerDetail.grime` loaded an opaque tile
through `Textures.loadRampTexture`, which writes `alpha = (y/h)^ease * peak` — one alpha value per
image ROW. So every texel at a given height faded identically: a gradient wash with no shape of its
own, over a single tile, level-wide. The street path stopped doing this a while ago —
`render.world.Buildings` loads `decals/grime-1..3` with the alpha HAND-PAINTED into the source, which
is what lets a drip or a mould bloom read as a separate stain rather than as a stripe.

The sewer band now does the same: plain `loadTexture`, `premultiplyAlpha` on the texture and
`premultipliedAlpha` on the material, `wrapT` clamped (v spans the band exactly once). The
premultiply is not optional with hand-painted alpha — saturated junk RGB under near-transparent
texels bleeds out as coloured specks once minified, the same trap `tools/textures.py`'s `bleed_alpha`
covers on the downscale. `GRIME_PEAK` / `GRIME_EASE` are gone with the ramp; `GRIME_OPACITY` 0.7 now
scales the source's own alpha. `Texture.premultiplyAlpha` went into the three extern rather than
being poked with `untyped` as `Buildings` does. Zero draw-call change (habitat stays 40).

**The sewer/habitat exit was lying on the floor.** Both exits draw `Const.FRAME_SEWER_EXIT`, which is
a LADDER seen from the side — laid flat by the default `isGroundDecal()` it read as a stripe painted
on the walkway. One override each (`objects/mission/SewerExit`, `HabitatExit`), the same one
`BurningBarrel` uses, and it stands upright with the actor tilt like every other vertical prop.

### Wall variants per FACE, sludge and pipes off, decals allowed across a cell edge
Four things that pull the same way: less repetition per level, less of what did not read.

**Wall variants come back, picked PER FACE — and the old rejection does not apply to them.** That
verdict ("47% of cell boundaries changed variant, median unbroken run 1 cell") was measured on a
clean/worn PAIR of independently painted tiles with DIFFERENT block layouts, so every switch MOVED
the mortar; no blend could fix it either. These four are repaints of one source: the courses line up
across a switch and only the wear differs, which is a discontinuity in the dirt, not in the masonry.
`SewerGeom` keeps one `MeshBuf` per variation and each face picks its own with
`mix((col*30011) ^ (row*50021) ^ (dir*70001)) % 4`, mixed because the raw hash combs the area border
and with its own multipliers so a face's texture does not correlate with the decal `SewerDetail`
rolls for it. Merged per variation, so a whole level still costs one draw call each: **40 → 43**.
Measured over a 120x120 grid the hash switches variant on **73.3%** of horizontal and 70.8% of
vertical adjacent faces against the 75% ideal, spread 25.1/24.9/25.1/24.9. Live in the habitat: 104
faces split **28/24/28/24**, median run 1, max 3.

**A caveat the numbers make plain: the art has to carry it.** As painted, the four variants differ by
a mean of 2-5 bytes out of 255, with only 2-5% of texels differing by more than 12 and identical mean
luma (79.4 / 80.3 / 79.4 / 79.1) — a 2x2 montage of them reads as one continuous wall. Swapping the
whole wall texture in-render, head-on at close range where the wall covers 21.5% of the frame, moved
**3.2% of wall pixels by >8 and 0.8% by >24** against a 0.4% noise floor. The mechanism is doing
exactly what it is asked to; per-face variety is only ever as visible as the difference between the
sources.

**Sludge and the pipe run are off.** The gutter read as a dark stripe rather than as water, and the
ledge pipes never had an orientation that made sense (top-down art, never turned, so every pipe in
the level ran east–west whatever wall it sat on). `SewerGeom` lays walkway over the channel cells and
`SewerGround` drops `TOP_PIPE` from its type list: habitat **42 → 40 calls**. The `channel` grid and
the pass that filled it went with them (see the review-fixes entry) — and with nothing drawn there, the
floor scatter's "skip the channel" rule went too, which is what stops a bare undecorated stripe down
the middle of every corridor. `TOP_MOSS` also halved (2.6 x 2.2 → 1.3 x 1.1): at full size a patch
filled its cell and read as a tile swap rather than as growth.

**Organic decals may now cross a cell edge.** A puddle clamped inside its 4-unit cell announces the
grid — the outline stops dead on the same line every time. `SewerScatterOpts.cross` widens the span
from `CELL - 2*margin` (3.6) to `2*CELL - 2*margin` (7.6) for `organic` types only, and only where
`open3x3` says the whole 3x3 around the cell is the same surface, so the quad can never reach under a
wall or over the ledge drop. It is off on the ledge entirely: most of a tunnel wall is one cell wide.
Measured live — every floor decal's AABB covers floor cells only, and the widened span is rare
because a 3-wide corridor only qualifies down its centre line, which is the right amount.

**Never A/B across a reload.** The first ledge measurement came out at 60% of the band changed, which
is not decals — it was a before-reload shot against an after-reload one, with the log panel, the
lamp phase and the actor state all different. Hide and restore the meshes inside one session.
