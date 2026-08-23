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

### Sewer lighting pass: manhole shafts, failing wall fixtures, and the exit as a real prop
Four changes to the tunnels, none of them a new mechanism — every part already ships in the city.
Habitat **43 → 46 calls**, tris 5.4k → 11.8k (the prop), boot pre-warm 69 → **73** programs, sewer
entry **+9** (was +7).

**The overhead shafts are manhole light now.** `LightCone` clamped its top radius to the shared
`LAMP_CONE.topR 0.2` — a point at the bulb, right for a street lamp because there IS a bulb there.
Underground the light falls through a HOLE, so the shaft starts a manhole wide: `CONE_TOP_R 0.9`
against the unchanged 3.66 ground radius. `instanced` was already at 5 positional args, so this went
to a `LightConeOpts` typedef rather than a 6th. Verified live: sewer cones `radiusTop 0.9`, the city
warm scene still 0.2 over 239 instances. Zero draw calls either way.

**Puddles 0.5/0.6 → 0.3/0.35.** `alphaTest` is `0.35 * alpha`, so the cut follows the opacity and the
hand-cut soft edge stays proportional (0.105 / 0.1225 live).

**Weak wall fixtures between the junctions (`SewerLamps`, +2 calls).** `SewerModel` only lights 3x3
corridor corners and intersections, so a whole run of corridor had no source of its own. 12% of wall
faces now carry a fixture, placed per 2x2 BLOCK (the run-capping idiom `SewerGround` explains) off
its own mixed hash; 30% are permanently dead and 35% of the survivors sputter, decided from a second
mixed word exactly as `SceneSetup` decides it from the lamp cell in the slums. Live in the habitat:
**12 placed, 8 working, 3 of those with a non-zero phase**.

There is no model and no art. A fixture is two quads on the wall face at `y 2.2`: an additive glow
whose amber is multiplied 2.6x past 1 so it clears `BLOOM_THRESHOLD 0.75`, over a soot smudge that
doubles as the dead lamp's entire appearance. Both are `InstancedMesh` + a canvas radial gradient
(`Textures.makeGlowGradient`), so a level pays two calls however many lamps it has.

Everything else came free. A working fixture is just a `LampPost`, so it competes for the same 12-slot
pool and therefore casts fake actor shadows (`View` already fed `lampLights.active()` to `Actors` in
every area); a non-zero phase is all `LampLights` and `CastShadows` need to sputter it and to drop its
shadow while it is out. Two new `LampPost` fields carry what a wall bracket does not share with a
street lamp: `y` (2.2 vs 5.6) and `mul` (0.35 — "weak"). Both multiply only at the publish line, never
into `intens[]`, for the reason already written there: that array is the fade ease AND the
`<= 0.001 -> free the slot` test.

**`LightCone.pulse` is geometry-agnostic** — it only repacks an instance matrix buffer by the lit
mask — so the glow batch is a `ConeSet` and gets the city's outage behaviour verbatim. One change
inside it: `phase == 0` now means always-on, which lets the steady and sputtering fixtures share one
batch (a tunnel has too few to split) and fixes a latent city case where a hash landing on exactly 0
put a lamp in the flicker batch that `LampLights` treated as steady. Swept 40s of flicker time over
the live batch: packed count 8 / 7 / 6, never below 6, i.e. the 5 steady fixtures never drop and the
3 sputtering ones never go out in unison.

**The exit is `sewer-exit.glb`.** Baked 93,501 → 5,000 tris / 354KB by `make models` (single mesh,
single material, so `Models.instanced` = 1 call for every exit in the level), stood at
`EXIT_MODEL_H 4.0` so it climbs past the `WALL_H 3.0` ledge toward the hole nothing renders. New
`render.world.ObjModels` owns the type → glb map, keyed on `o.type` in the render layer so
`objects.AreaObject` stays ignorant of glbs. `Actors` gains `ActorOpts.iconOff`: the object keeps its
teal tactical ring and its through-wall silhouette (that is how an exit stays findable) and loses only
the icon quad the prop now occupies. Only tunnel areas hold one — `WorldConst` declares
`exit: 'sewer_exit'` on `AREA_SEWERS` alone.

**Trap: a prop-backed object was casting TWO shadows.** `Models.instanced` sets `castShadow`, so the
ladder throws a real shadow-map shadow — and `FlameShadows` was still painting a stretched copy of its
64px sprite silhouette on the floor underneath it. `castShadows` now skips any object with a model.

**Trap: warming an async prop.** Instancing the glb beside the rest of the sewer warm scene warms
nothing — `Models.instanced` resolves over a `GLTFLoader` callback and the mesh lands after
`compileAsync` has already walked the scene. It is instanced inside the promise chain instead, behind
a `Models.get`; boot went 69 → 73 programs, which is the prop's PBR + depth pair moving from entry to
boot. The 2 `basic` programs still compiling on entry are dir-light-count variants (1 → 0) of
city-only materials, not the new ones — they were there before this pass.

## The exit ladder marked itself: a green dot grid no lighting toggle could kill

A grid of glowing green squares crawled over the new ladder and moved with the camera. It read as a
specular pattern and was chased as one — twice, wrongly. It is the object's **own through-wall x-ray**.

`Actors.paintObjMark` paints a hatched silhouette with `depthFunc: GreaterDepth`, i.e. *draw only
where something occludes this pose* — the whole point, since that is how an object stays findable
behind a wall. `OBJMARK` carves it as `fill 'dots'`, `hatchSpacing 6`, `hatchThick 2`, colour
`0x35dd7a` at `emissive 0.9`, so on a 64px crop it is ~10 dots across and bloom washes them to
yellow-white. Before this prop existed the exit's only occluder was a wall. Now a 4-unit ladder stands
at exactly that sprite pose, so **the object occludes its own marker** and hatches itself every frame.
Fixed by making `iconOff` mean ring-only: a modelled object keeps its tactical outline and loses both
the icon and the x-ray. `paintObjMark` was at 9 positional args, so the switch went into a new
`ObjMarkOpts` rather than becoming a 10th.

**The trap is that no lighting A/B can find an overlay.** The marker is an emissive UI quad: `1`
(hide every light, full-bright ambient) leaves it, `M` (force matte) never touches it, and it does not
care what the model's material says. `6` (kill emissive) is the key that would have pointed at it.
Proving it took the opposite move — find the one material in the scene with `depthFunc === 6` and
force `colorWrite = false` on it every frame. Dots gone, ladder untouched.

**Two real material findings came out of the wrong trail, both since reverted.** The glb is a PBR
export at `metallic=1 roughness=1` **with an MR map** measuring metal **0.71** / rough **0.23**, over
a base map that is a **flat 198 grey** (range 192–205 across the whole 512², no painted detail; the UV
layout is dozens of thin packed rail/rung strips, which is why replacing that art was never the
answer). `dropMR` + a new `baseColor` bake knob flattened and darkened it — and the author wants the
sheen, so both are off again. Worth keeping written down: `dropMR` alone turns it into a WHITE plastic
ladder, because metalness 0.71 had been suppressing the diffuse to 29% and hiding that albedo.

**Two things survive.** `models.json` gained `baseColor` — a LINEAR `baseColorFactor` multiplied onto
the base map, for a prop whose authored albedo is far brighter than the art (scale a uniform map, do
not repaint it). And debug key **`M`** forces every lit material matte, in `StreetPerf.onKey` (the
fallback branch for keys `View` ignores, which already owns the scene and the HUD), stashing into
`userData.spec0`, HUD line `SPECULAR(M)`. It must null the **maps**, not just the factors —
roughness/metalness are factors the map multiplies, so clearing a factor alone leaves a mapped
material exactly as glossy. That flips `USE_METALNESSMAP`/`USE_ROUGHNESSMAP`, so one compile stall per
toggle, same as `7`. It also flattens blood/slime (`BLOOD.wetRough 0.4`/`wetMetal 0.5`), as a global
A/B should.

**And the glow on the ladder's top rail was bloom, not the sheen.** `Shift`+`1` (bloom alone) over the
rail region: mean luma **133 → 160**, with the halo spilling onto the floor and the rungs under it.
The rail is a pale face 1.6 below a bulb, clipped past 1.0 linear long before the pass runs, and
`SewerStyle.BLOOM_THRESHOLD` was **0.75** — deliberately under the street's 0.9 "so the few lamps
actually bloom against near-black surroundings". What actually lived in that 0.75-0.9 band was
over-lit SURFACES, not lamps: raised to **0.9**, near-clipped pixels on the rail go 2.8% → 0.7%, the
floor halo is gone and the rail caps keep a tight highlight. `baseColor` cannot do this job — the rail
is far enough over that it would need ~0.4, which is the dark matte ladder again.

Verified the lamps did not pay for it, by scanning the scene for any material whose colour or emissive
luminance exceeds the threshold: the wall-glow batch is additive at linear **(2.6, 1.25, 0.35)**,
luminance **1.47**, so it clears 0.9 by 63% — `Color.multiplyScalar` does not clamp, which is why an
HDR tint stays HDR. Nothing else is authored above 1 (`LAMP_CONE.opacity 0.03` was already written
against 0.9). That scan is the check to run after ANY threshold move.

## The ladder flashed on one tile: a lamp light moved, its shadow map did not

Walking past the sewer exit, the ladder blew out white for a frame on one specific step. Not the
material, not bloom on its own — **the pooled spotlight over it changed slots and left its shadow map
behind.**

`LampLights.update` re-sorted the slot CONTENTS by distance every frame so the nearest lit lamps hold
the shadow-casting slots, and published `lights[i].position` for the new owner immediately. But
casters run `shadow.autoUpdate = false` and the re-render was deferred round-robin, **one slot per
frame**. three's `WebGLShadowMap.render` `continue`s on `autoUpdate === false && needsUpdate === false`
*before* `shadow.updateMatrices(light, vp)` — so `shadow.matrix` and the shadow camera stay at the
**previous** lamp. Lighting comes from the new position, the shadow lookup from the old one. The
receiver lands outside that map, PCF returns fully lit, and it flashes. A reshuffle could hold that
mismatch for up to `shadowCasters` (8) frames.

Why that exact tile, from a live scene capture: the habitat puts a lamp **on the exit cell itself**
(`SewerModel`, bulb y **5.6**) and the ladder tops out at **4.0**, so its entire shading is one 512
map from 1.6 above it. The nearest wall lamp sits at cell offset **(+4, −1)**. Player at ladder+2:
d(exit) **2.00** vs d(wall) **2.24** — exit lamp is slot 0. Player at ladder+3: **3.00** vs **1.41** —
rank flips, slots 0 and 1 trade owners, both maps go stale, one refresh is dispatched. The exit lamp
then samples a map taken 16 units away and 3.4 lower, the ladder is outside that cone, and its 45-
intensity spot lights it unshadowed. Bloom does the rest — that rail was already the surface clipping
at 255.

Fixed by **committing the hand-off and its shadow in the same frame**: the re-sort became ONE adjacent
transposition per frame, and both swapped slots get `needsUpdate` immediately instead of queueing. The
array stays a valid permutation at every step, so no lamp is served twice; the ordering is only a
routing heuristic, so letting it converge over a few frames costs nothing. Budget goes 1 → at most 2
shadow passes on a swap frame. The round-robin drain stays for the harmless case — a FREE slot
claiming a lamp moves a light that is still at ~0 intensity, and a stale map contributes nothing
through a dark light.

**The city has the same bug and it never showed.** The moon carries the street's shadowing, so a lamp
map handing off is subtle; underground there is no moon, the lamp map is 100% of it, and
`lightRangeCells 16` against `WALL_LAMP_PCT 12` makes rank swaps fire on nearly every step.

## The prop layer grows two more batches: ghosting under the player, and a real 3D outline

Five follow-ups off playing the ladder pass. Two of them needed the same machinery, so they landed
together: **one InstancedMesh carries one material**, so every look a prop can take is its own batch
over the same placements, with `Models.cull`'s mask picking which draws each one. That is the street
lamps' lit/dead idiom verbatim. `Models.instanced`'s `?dead:Bool` was *replaced* by a
`ModelVariant` enum rather than joined by a second flag — arity stays 5 so no opts typedef is owed,
and two bools would have admitted `dead && ghost`, a state that does not exist.

**Standing on a prop fades it** (`GHOST`): a transparent clone with `depthWrite = false` — that flag
is the load-bearing one, not the alpha, because the actor billboard is depth-*tested*, so a ladder
that still writes depth rejects the player however faint it draws. The eased opacity is
`RenderConfig.PROP_GHOST`, one per batch, which is correct because the player stands in exactly one
cell. **Its material starts at opacity 1.0**, not `alpha`: the glb resolves through a loader callback
and can land after `tick`, and until the first cull the batch draws at capacity — at 1.0 that frame is
pixel-identical to the solid twin under it. Both batches keep `castShadow`: three's shadow pass
renders its own depth material and ignores transparency, so the handover pops no shadow.

**The tactical mark became an inverted hull** (`HULL`). It was `Sprites.outlineTex` — an outline
traced from the **alpha silhouette of the 2D atlas cell**, painted at the sprite pose, so with the
icon suppressed it read as a ladder-shaped green outline around nothing. The replacement is a backface
shell on geometry cloned with every vertex pushed along its normal; measured on the baked ladder, all
**4,933 verts displaced by exactly 0.015 local units** = `OBJMARK.hullW 0.06` world ÷ the 3.998
instance scale (the divide is the whole trick — the band is a world width and the shell is scaled per
instance). `paintObjMark` is now not called at all for a prop-backed object, so `ObjMarkOpts.xray`
lost its second value and was deleted.

**Both new materials compile their own program**, verified in the vendored bundle, not assumed:
`transparent` folds into the cache key at `three.global.js:36302` → `:36541`, and `BackSide` at
`:36370` → `:36531`. Both variants are warmed inside the existing `Models.get` callback in
`View.warmup` — outside that promise chain they would warm nothing. Idle they cost **zero draw
calls**: `renderInstances` early-returns on `primcount === 0` (`three.global.js:33249`) before
`info.update`, so a masked-empty batch never reaches GL.

**The wall lamps dropped to the floor.** `WALL_LAMP_Y` **2.2 → 0.6**, and `LampPost` gained `tx`/`tz`
so `LampLights` stops publishing every target straight down: a bracket now aims `WALL_LAMP_AIM 5.0`
out along its wall normal, a ~7.8° grazing beam. Captured live: every fixture at `y 0.6` with its
target 4.4 out from the bulb. `CastShadows` has **no notion of light height at all** — its length is
`spriteHeight * lenMul * distance falloff` — so the fake actor shadows would have stayed short
overhead smudges under a knee-high lamp while the real maps raked. `FlameShadows` now scales both
`lenMul` and `range` by `min(LAMP_SHADOW.lowMax, refY / post.y)`; a street lamp lands on exactly 1.0,
a 0.6 bracket on the 3.0 cap. *(Later: the scaled REACH is separately clamped to
`LAMP_SHADOW.lowRangeCells 3` — see the row below. The length keeps the full `lowMax`.)* The glow
quad's ellipse was never drawn — it is a *circular* gradient on
a square canvas stretched onto a 0.75 × 0.5 quad — so `Textures.makeRectGlowGradient` writes a rounded
-box SDF per texel instead, where the corner radius and edge softness are numbers rather than a blur's
guess.

**Litter 3×** (`60`/`24` per 1000, tunnels/rooms): it was never unwired, just swept — headless on the
warm-up demo tunnel, 117 floor cells now yield **22 fragments**. Its hash was also still the bare
`(col*A) ^ (row*B)`, the one form the verdict table records as combing on row 0 / col 0, while every
other sewer pass had moved to `SewerModel.mix`; routed through it.

**The exit shaft steps 2.0 south** (+Z, screen-down, so the lit pool lands on the walkway in front of
the ladder). `citygen.CityModel.Lamp` could not say which lamp hangs over an exit, so the tunnels took
their own `SewerLamp` record with an `exit` flag. Cone *and* spotlight move — they are independent
arrays, but a shaft whose lit pool sat elsewhere reads as two lights. `col`/`row` stay the exit cell,
which is what the pool gates player distance on.

## Two sewer light colours, and litter that had the wrong suspect

**The tunnels were lit entirely in the street's sodium amber**, shafts and wall brackets alike, so
neither read as its own kind of light. Splitting them found that `0xffb866` lives in **two** places:
`RenderConfig.LAMP_CONE.color` *and* a second hardcoded copy in `LampLights`' `new SpotLight(...)`.
Recolouring the config alone would have desynced every shaft from its own spotlight, in the city too.

The colour also has to be **per post, not per pool**. Node lamps and wall brackets are concatenated
into one flat `lampPosts` array feeding one 12-slot pool, so a single physical `SpotLight` carries a
manhole shaft on one frame and a bracket on the next — the same aliasing that produced the shadow-map
flash two entries up. So `LampPost` gained `color`, published in the publish loop beside the position
and intensity it already writes. That is free: `getProgramCacheKey` carries light **counts** only, and
`WebGLLights.setup` re-copies `light.color` unconditionally every frame
(`three.global.js:36965`) — same cost class as the `intensity` write already there. `LightConeOpts`
gained `?color` so the shaft batch can differ without touching the city's four cone call sites.

Shafts are **`0x9db4d4`**, cold pale sky down a manhole; brackets **`0xc8d69a`**, a bad fluorescent
tube. Verified live: all 7 lit lamps at `y 0.6` publish `(0.578, 0.672, 0.323)` and all 4 at `y 5.6`
publish `(0.337, 0.456, 0.658)`.

**The bloom trap is real and worth stating flatly.** The glow quad is `colour × WALL_LAMP_GLOW 2.6`,
unclamped, and `UnrealBloomPass` thresholds **linear** Rec.709 luminance where blue weighs only
**0.0722** — so a cool fixture can look bright and silently stop blooming. Measured after the swap:
`(1.502, 1.748, 0.840)`, luminance **1.63** against `BLOOM_THRESHOLD 0.9`; the amber it replaced was
1.47. Compute `Y_linear × GLOW` *before* committing to a hue.

**Litter: the obvious suspect was wrong.** It reads empty, `DECAL.debrisMul 0.55` darkens in sRGB byte
space (≈0.27× linear), and the sewer floor was re-authored far brighter than city asphalt — so the
tidy conclusion is "the trash is darker than the floor it lies on". **It is not.** Measured on the
BUILT art: a static debris sprite peaks at **175 sRGB** → ~96 after the dim, against
`app/textures/sewer/floor.png` at **66.8 mean / 75.2 max**. Litter is already ~30% *brighter* than its
floor, and raising the multiplier would have made it glow. The number that led there is in these docs:
the floor's "0.2206 mean linear" is the **source** in `textures-src`, while the built output under
`app/textures` measures 0.056 linear — a 4× gap that inverts the argument. Sample the artifact.

The decal reveal radius is not it either: `DECAL.radiusCells 20` is a 1257-cell² disc against a
166-cell² sewer footprint, and the farthest visible ground point is 11.5 cells — inside the 18.5-cell
full-opacity core.

**What it actually was: count, size and a grid.** Rates went to **180/1000 tunnels, 120 rooms** — the
room number lifted 5× because a habitat is pinned to 4-5 rooms of 5x5, so 62-77% of its floor is
`room` and the low rate was the one underfoot. Size mattered as much: `Debris` rolls
`scale 0.1 + 0.9 * rng` and draws `Sprites.SIZE(3.0) × contentFraction × scale`, measured in-engine at
**0.15 / 0.73 / 0.86 / 0.88 / 1.21** world units against a CELL of **4** — the small end is a pixel.
And a `transformable: false` fragment gets `dx = dy = angle = 0`, so the ~55% of litter big enough to
see was every piece dead-centre in its cell and axis-aligned. Both fixed in one pass over the tunnels'
own spots after generation, because the shared placer is the city's too and is already at 7 positional
args. The jitter needs no ground test — `Debris.canPlace` only rejects past 0.25 of a cell, so
anything inside that is legal by construction. On screen: **5 → 32 fragments, smallest 0.15 → 0.46,
largest 1.21 → 1.83**, still one draw call.

## A wall lamp painted through an AI's head: a shaft's render order is not a fixture's

The wall fixtures' glow batch sat at `Sprites.ORD_ACTOR + 1`, the slot `LightCone` uses, and its
bright core drew straight over an actor standing in front of it — a hard white blob on the sprite's
forehead, not a bloom halo.

**Nothing in the sprite pool writes depth.** That is deliberate (`Sprites`: tiny Y gaps z-fight at
this near/far, so renderOrder does the layering), and it means a later transparent draw is never
rejected by an earlier one — only by the opaque scene. The glow quad sits `DECAL_EPS` proud of the
wall, so it passes depth against the masonry and then paints over anyone between.

`ORD_ACTOR + 1` is *right* for a light shaft and *wrong* for a fixture, and the difference is what
the thing is: a shaft is a column of lit air an actor stands **inside**, so drawing it last and
letting it tint them is the effect. A wall lamp is a quad stuck on masonry **behind** them. New
`Sprites.ORD_FIXTURE = 4.5`, between the targeting reticle and the actor billboard — fractional so it
slots in without renumbering the other twenty call sites (`render.decals.Blood` already uses
fractional orders to break same-cell ties). The shafts stay at 6. Verified: glow batch `renderOrder`
4.5, head silhouette now cuts the fixture, only the screen-space bloom halo spills — which no depth
ordering can fix and which reads correctly.

**And the fixtures stopped being placed inside the shafts.** `SewerLamps` rejects any cell within
`WALL_LAMP_CLEAR = 2` cells of an `m.lamps` entry. The number is derived, not picked: the shaft's
ground radius is `bulbY * tan(angle) * radiusMul` = 3.66 units (0.92 cells) and a bracket throws its
own pool `WALL_LAMP_AIM 5.0` (1.25 cells) out from the wall, so they stop touching at ~2.2 cells. The
test runs on the CELL rather than the shaft's drawn centre — an exit's cone is nudged half a cell
south and the radius swallows that. It also rejects the cell *before* the block's `faces` list is
built, and the density gate multiplies by `faces.length`, so blocks near a shaft thin out on their own
while per-face density everywhere else is untouched. Habitat: **12 → 11 fixtures**, nearest one now
**10.17 units (2.54 cells)** from any shaft, every other one further. 49 → 44 draw calls.

## An image-to-3D pipeline, and the first thing convex in a tunnel

Three glbs had reached `models-src/` before this, all generated from images by hand outside the repo.
The gap between "gpt-image made a picture" and "a glb is in `models-src/`" is now a tool:
**`runware-trellis-2` MCP** (`~/git/runware-trellis-2-mcp`, one tool `image_to_3d`), wrapping
Microsoft TRELLIS 2 on Runware. ~350 lines of node/TS, registered at user scope; the key is read from
the shell at call time rather than at startup, so the process boots and lists tools without one. Its
default output dir resolves to `<git root>/models-src`, so a generated model lands where `make models`
already looks. Two settings are load-bearing: **never send `dracoCompression`** (`Models.get` builds a
bare `GLTFLoader`, so a Draco glb fails to load behind a `console.warn`), and `textureFormat: "PNG"`
because the bake re-encodes to PNG anyway. It reports `meshCount`, because `Models.instanced` takes
`firstMesh` and drops the rest silently. ~$0.02-0.03 a model, about a minute each.

**Trap: `make models` could not reach the tri target, and the error cap was the wrong lever.**
*(The conclusion drawn here — "decimate on the TRELLIS side, always" — is over-general, and the piles'
real quality defect was a different setting entirely. See "The setting the web sends and the API does
not".)* Asking
TRELLIS for `decimationTarget 20000` and meshopt for 4000 stalled at **15,824 / 13,153 tris**. Raising
`error` 0.005 → 0.03 — six times the distortion budget — only got to **13,318 / 8,975**. meshopt will
not collapse across attribute discontinuities, and a TRELLIS mesh is one dense UV atlas full of them;
the exit ladder hit its 5,000 only because it had 93,501 tris of slack. Decimate where the topology is
known instead: ask TRELLIS for `decimationTarget 5000` (its API floor) and set `tris: -1`. Result
**4,771 / 4,845 tris**, 524KB / 491KB — in band, and with authored normals still matching the surface,
which is the artifact `MODEL_SMOOTH_NORMALS` exists to paper over.

**`SewerPiles`** scatters them against wall faces, one per 2x2 block, gated
`PILE_PCT 14 × faces.length`, `SewerModel.mix` on its own multipliers, exit cells and their ring
rejected. Hugging a wall is also what keeps the walkway clear. `PILE_H 0.7`, `PILE_MARGIN 0.55` off
the wall plane, ±0.5 rad yaw wobble. No per-frame `Models.cull`: two static batches of a dozen could
never drop below one call each.

Checked headlessly *before the art existed*, through a `places(m)` split out of `build` — on the 21x21
demo, **13 piles over 84 wall faces (15.5% against `PILE_PCT` 14), longest axis run 2, zero
misplacements** (every one offset by exactly `CELL/2 − PILE_MARGIN` toward a *solid* neighbour).

**Cost, measured foregrounded and interleaved, medians of 18 samples each** (piles `visible` on/off,
which touches no program key so there is no compile inside the window):

| | on | off | Δ |
|---|---|---|---|
| GPU | **2.83ms** | 2.45ms | **+13.4%** |
| submit | 1.50ms | 1.60ms | noise — it moved the wrong way |
| calls | 52 | 50 | **+2** |
| tris | 79,374 | 12,136 | **+67,238** |

14 piles (8 + 6); the tri delta is exactly `8×4771 + 6×4845`. 13.4% of GPU for a dozen props is real,
against a 2.83ms frame with a 16.7ms budget. `submit` is untouched, which is the expected shape: two
more `InstancedMesh` draws are nothing to the CPU and 67k more triangles are something to the GPU.

**Do they finally give a wall bracket something to cast off? Barely — but the shadow is free.** The
previous pass measured six brackets lighting 0.43% of the view and shadowing nothing, because every
wall within their reach has rock behind it. In-frame A/B (offscreen target, both renders inside one
eval, all 12 spot shadows forced to refresh): piles casting vs not = **0.021% of the view, max delta
18/255**, against a 0-pixel reproducibility control and a 0-pixel restore control. Real and nearly
invisible — in that view most piles sit outside any lamp pool. But `castShadow` on vs off (both
permutations warmed first, since it IS a program key) measured **2.65 vs 2.67ms, −0.8%, calls
identical** — nothing. So the whole 13.4% above is main-pass, the shadow-pass half is free, and there
is no case for turning it off. The lever moves; it is still not the answer to that open lead.

**Trap, surfaced only because the glbs did not exist yet: a failed model load stalled boot.**
`Models.get`'s error path dropped its waiting callbacks, and `View.warmup` *sequences* on one — so two
404s left the warm chain's Promise unresolved forever, with `comp.dispose()` and
`renderer.setRenderTarget(null)` never running and the renderer left bound to the warm target.
Pre-existing (the exit ladder had the same exposure); two more paths just made it likely to fire.
Waiters now get an empty template — `instanced()` finds no mesh and draws nothing, but a sequencing
caller advances. It has to carry a child Group: `instanced` reads `pivot.children[0]`
unconditionally and a bare `Group` threw inside `firstMesh`.

## The setting the web sends and the API does not

The piles generated through the new tool came back visibly worse than the same reference run through
Runware's web playground. Diffing the two request bodies gave three candidates: `decimationTarget`
(100000 vs the 5000 the tool had settled on), `remeshProject` (**0.8 vs never sent**), and
`textureFormat` (WEBP vs PNG). PNG is lossless, so it was out. The first diagnosis blamed
`decimationTarget`, on the strength of the exit ladder arriving at 93,501 tris and looking right — and
that diagnosis was **wrong**, because the two variables had never been separated: the bad piles had a
low target *and* no projection factor.

**`remeshProject` is the real defect, and its API default is the wrong one.** Runware documents it as
*"projection factor for snapping remeshed vertices back to the original surface"*, default **0** — no
snap-back, so the dual-contour remesh keeps its own rounded-off shape and the detail the reference was
chosen for never lands. The playground sends 0.8. A further trap: the wire range is `(0, 1]`, so
sending a literal `0` is **rejected** rather than treated as the default; it has to be omitted.
`image_to_3d` now sends 0.8 unless told otherwise, plus `remesh_band` and a `meshCluster` pass-through.

**Regenerating at 100k then decimating offline stalled at half the source.** meshopt cannot collapse
an edge across an attribute discontinuity, so the number that predicts success is vertex count over
*unique position* count:

| mesh | tris | verts | unique pos | split |
|---|---|---|---|---|
| `sewer-exit` (ladder) | 93,501 | 55,080 | 46,778 | **1.18×** |
| `sewer-pile-1` @100k | 96,577 | 130,974 | 41,042 | **3.19×** |
| `sewer-pile-2` @100k | 98,961 | 201,441 | 29,452 | **6.8×** |
| the same reference through the WEB playground | 98,425 | 132,205 | 42,713 | **3.10×** |

That last row is the one that matters: the web export nobody complained about is split exactly as
badly as ours. A viewer reporting "42,647 verts" is reporting the *welded* count. There was never a
difference in the mesh — only in `remeshProject`, and in what the bake did next.

The piles have *fewer* real vertices than the ladder and 3-7× as many total: near-per-triangle UV
charts, a seam on every edge. The ladder is a hard surface with large flat charts; rubble and sacks
are curved everywhere, so the unwrapper shatters. `meshCluster` tuning — 16 global iterations, 8
refine, smoothing 4, cone threshold 2.6 rad — moved 3.19× to **3.15×**. A dead end, $0.04 to
establish. Dropping `remeshProject` reached 2.46×, but that is paying with exactly the detail it buys.

**`error` is not the lever, and the floor is hard.** Sweeping it locally on the 96k source:

```
weld()          error 0.005  96001 -> 54718
weld()          error 0.02   96001 -> 52252
weld()          error 0.30   96001 -> 52184      <- 60x the default cap, same answer
weldByPosition  error 0.02   96001 ->  3776
```

**The thing actually killing it was `tex`, and it had nothing to do with the mesh.** The number to
carry is TEXELS PER TRIANGLE. The source is authored at ~43 (96,971 triangles over a 2048² map). The
config that shipped was 4,673 triangles at `tex: 256` — **14**. At that density every crack line and
grain speckle in the atlas is gone and the prop reads as smooth flat shards, which is exactly what
"looks like garbage" meant. `tex` was not shrinking the map, it was deleting it. Hold the ratio near
what the source was authored at and the same 4,821-triangle mesh carries full crack detail.

**Dead end worth recording: baking the atlas down to per-vertex `COLOR_0`.** It works mechanically —
sample the atlas per vertex, drop the texture/UVs/MR map, weld by POSITION, and meshopt is free:
**96,971 → 3,730 tris, 14,553KB → 77KB**, zero textures, measured at **+6.5% GPU** against the old
config's +13.4%. Cheaper *and* it carried the full 97k silhouette. It was still wrong, because the
premise was wrong: the atlas is not a per-triangle patch mosaic. 130,974 verts is **1.36×** the
triangle count; a true per-triangle atlas would be 3×. Each patch carries real sub-triangle detail,
and `COLOR_0` throws all of it away — the props came out as smooth white shards. Reverted, code
removed. Two traps if it is ever right for a genuinely flat-shaded prop: sample the triangle's UV
**centroid**, never the vertex's own UV (a vertex UV sits on a chart *corner*, which is the gutter
between patches — sampling there reads the padding and the prop bakes near-black, which looks like a
lighting bug and shows up in any plain glb viewer); and `COLOR_0` is **LINEAR** while a
baseColorTexture is sRGB. The check that catches both: baked colour mean vs the atlas's own mean.

**Shipped:** TRELLIS `decimationTarget 20000` + `remeshProject 0.8`, `"tris": -1`, `"tex": 1024`
(52 texels/tri), with `sewer-pile-{1,2}-100k.glb` kept in `models-src` as archival masters — same
idiom as the existing `street-lamp-raw.glb`. For a subject meshopt cannot decimate, the file
`models.json` points at has to arrive at the game budget already; Runware unwraps and bakes *after*
its own decimation, so its output is clean at any target. **19,223 / 19,712 tris**.

Cost, window focused, interleaved, medians of 17: GPU **3.44 vs 2.44ms = +41%**, `submit` 1.70 vs
1.29, calls **+2**, tris **+272,056**. Kept, because +41% here is **+1.0ms of a 16.7ms budget in a
scene reporting 14.79ms idle** — the tunnel is the lightest scene in the game at 52 calls against the
city's 168, and piles do not exist in the city. Worth stating as a standing note: a percentage means
nothing without its denominator. The two cheaper configs measured on the same props were +13.4%
(4,673 tris / `tex: 256`) and +6.5% (vertex colours), and both looked worse. If a weaker machine ever
makes this hurt, the fallback is `decimationTarget 5000` + `tex: 512` — the same 51 texels/tri,
verified to carry the crack detail, at 67k tris instead of 272k.

**Then pile-2 rendered pure black under debug key `1`.** Its baked MR map is uniformly **cyan**;
glTF packs G = roughness, B = metalness, so that is metalness 1 across sacks, wood and cloth alike.
A metal has no diffuse term, `1` hides every light, and with no analytic light and no env map there is
nothing left to shade — so a fully metallic prop reads BLACK under WYSIWYG, not chrome. `sewer-pile-1`,
same generator and same day, came out pure green: a correct rough dielectric, no change needed.
`dropMR` on pile-2 alone. Dumping the MR texture answers this in one look and is cheaper than any
amount of in-engine A/B.

## Splitting the composite pile into four simple modern props

`sewer-pile-2` was one generation of *two sacks + rope + a tarp + a broken crate*. It shipped
undecimated at 19,712 tris with a 1024² map and still read as mush, and it read rustic — hessian and
plank boards under a present-day city. Both are the same root cause: **the reference asked for a
composite.** Fixed upstream of every bake knob by generating four separate objects instead — a 200 L
steel drum, two solid-walled plastic stacking crates, a coiled industrial cable and three tied refuse
sacks — scattered independently. Sources and outputs both moved under a `sewer/` subfolder
(`models.mjs` needed one line: `mkdirSync(dirname(out))`, the idiom `textures.json` already uses for
`decals/`).

**Split ratios, all generated at `decimationTarget 100000` + `remeshProject 0.8`:** drum
63,617 verts / 48,593 unique positions = **1.31×**, crates 90,764 / 46,236 = **1.96×**, cable
95,403 / 45,324 = **2.10×**, bags 252,243 / 20,833 = **12.1×**. Bags is the worst measured anywhere —
252k verts against 293k triangle corners is essentially a per-triangle atlas. Soft goods again, and
worse than pile-2's 6.8×: three smooth blobs give the unwrapper nothing to chart along.

**Asking meshopt for 1,200 tris got: 4,826 / 23,926 / 30,431 / (bags undecimatable).** So the split
ratio does not just rank subjects, it says where the floor lands — and ~2× is the line between the
two workflows. The drum's 4,826 is a normal prop (the exit ladder ships at 5,000) and the
100k-master-plus-offline-decimate route is right for it. Crates and cable at 22–30k are not usable,
so those were regenerated with `decimation_target 5000` and `"tris": -1`.

**The `error` sweep that nearly did not happen.** The pile-1 result (3.19×: 0.005 → 54,718,
0.30 → 52,184) had been generalised into "`error` is not the lever", and a rule was written on that
basis. Swept properly it is only true for a *shattered* atlas. On the clean drum: 0.005 → 4,826,
0.01 → 3,762, 0.02 → 3,476, asymptote **3,294** by 0.1 — a real **−32%**. crates moved −8%
(23,926 → 22,026) and cable −16% (30,431 → 25,447). So sweep `error` before accepting a clean
subject's tri count, and do not bother on a shattered one. No cap reached the target on any of them.

**Shipped:** drum decimated offline (4,826 tris), crates / cable / bags generated at budget
(4,818 / 4,891 / 4,769), all four `"tex": 512` = ~54 texels/tri, with `-100k.glb` archival masters for
the three that were regenerated. **19,304 tris across four props, against 19,712 for the one pile they
replace.** All four MR maps came back pure green — rough dielectrics, no `dropMR` anywhere, so
pile-2's cyan map was a one-off and not a property of the generator.

`SewerPiles` → `SewerProps`, and `PILE_H` / `PILE_MARGIN` became per-prop fields on a `SewerProp`
typedef: a drum is 0.9 tall on a small round footprint and a cable coil is 0.3 on a wide flat one, so
one global pair either floated one off the wall or buried the other. Placement also gained a corner
tuck — a cell with two perpendicular wall faces applies both offsets, and the yaw now comes from
`Math.atan2(nx, nz)` on the summed inward normal, which reproduces the four literals it replaced and
bisects a corner to 45° for free.

## Sewer props: a derived wall standoff, the camera-side face, and a violet albedo

Three separate faults in the four props above, all found by measuring the baked glbs rather than
looking at them.

**The standoff was hand-typed and three of five props stood inside the wall.** `Models.instanced`
scales a prop by HEIGHT alone (`targetH / t.height`), so its footprint is `nativeR/nativeY × h` —
which means a per-prop `margin` constant is stale the moment anyone edits `h`, and a *flat* prop
multiplies its width by the same factor that sets its height. Measured world radii (max XZ distance
from the bbox centre, so yaw-independent) against the authored standoffs: `sewer-pile-1` **1.425**
vs 0.55, cable **0.830** vs 0.50, bags **0.825** vs 0.40. Drum and crates were inside their margins
by luck. `SewerProp.margin` is now `r` — the footprint radius *per unit of height*, measured off the
glb — and `SewerProps` derives `margin = r * h + PROP_CLEAR`. All five clear their wall by 0.05 and
cannot drift again. Cable also went to `h 0.24` (−20%) and the drum to `h 1.8` (×2) on the same pass.

**A quarter of every prop was invisible by construction.** `CAMERA_SEWER` sits at +Z looking back
along −Z — 53° at the near preset (y16/z12), 71° at the far one (y40/z14). A prop leaning on the
SOUTH wall has that wall between it and the camera, and the wall is `WALL_H` 3.0 with a ledge
plateau on top, so it hides everything within `3.0 / tan(pitch)` = **2.25 units near, 1.05 far**. A
crate at h 0.75 standing 0.35 off the plane crosses it at y **1.22** against a 3.0 cap: not partly
occluded, gone at both zooms. Clearing the cap would need a standoff of 1.7 — parked mid-corridor —
so the fix is to never pick the face. `SewerProps.CAM_DIR` drops dir 1 before the density gate sees
it, and `PROP_PCT` went 14 → 18 to pay back the ~quarter of faces lost (13 props before, 14 after).
Cheap proof it holds: with dirs 0/2/3 only, `|yaw|` cannot exceed π/2 + `PROP_YAW_JITTER` = 2.071,
where a south face would land at ≥ π − 0.5 = 2.642. Measured max **1.923**.

**The big upright props are corner-only, and the flag has to PARTITION rather than filter.** A
1.8-tall drum or a 1.65 crate stack against a flat run of wall reads as dropped in the walkway; in
the angle of two walls it reads as stored there. Measuring first is what picked the mechanism:
corners are only **14%** of spots (2 of 14, and lower than it used to be because dropping the
camera-side face halved the Z-axis supply), so merely *excluding* a prop from flat walls would leave
14% × 1-in-5 = **0.4 a level**. Instead `SewerProp.corner` splits the table in two pools — a corner
deals only from the corner props, a flat run only from the rest — and drum + crates share the corner
pool. Both pools must stay non-empty; that is the invariant the typedef comment carries. Verified
against the floor grid rather than against the code that placed them: drum and crates **1/1** each
on cells with both a Z and an X wall, the three flat props **0/12**, none off a floor cell.

**TRELLIS invents a violet albedo from a near-black reference.** `sewer/bags` baked at mean sRGB
**77 / 62 / 99** — R above G, B far above G — from a reference painted 68 / 72 / 77 (cool, R<G<B).
Our bake is not the cause: the source 2048 map and the baked 512 agree to **1/255** on every channel
(checked on all four props), and drum / crates / cable from the same batch and the same day are all
correct. Nor is it the seed: a fresh generation came back at mean 110 / 89 / 114 and *bimodal* —
flat pink charts against black gutters, strictly worse and unfixable by a tint — so it was rolled
back to the recorded seed 1195164295. What the three correct props share is a mid-value subject
(reference luma p05 35–45); the bags are the one painted near-black at 30, and the decomposition
appears to read that darkness as shadow and lift the albedo, hue and all.

A per-channel `"baseColor": [0.32, 0.51, 0.18, 1]` was fitted to neutralise it and did work, but it
is the fallback, not the fix — a LINEAR multiply cannot recover a channel the generator threw away.
Repainting the reference does. The same subject at mid charcoal (`#3a3d42`, subject luma p05 30 →
**48**) came back at **67 / 70 / 78** — cool, neutral, tracking the reference's own 73/80/88, with a
tight spread (p05 60, p95 79) and no bimodal split. So `baseColor` is now a single uniform 0.47
darken, hue untouched, purely to land it at the drum's brightness instead of 1.5× over it. The
regen also changed the silhouette for the better — a pyramid at aspect **1.23** against the flat
1.98 heap — which cut `SewerProp.r` from 1.17 to 0.73 and wanted `h` 0.7 → 1.0 to keep its footprint.

Two things worth carrying forward. **The reference's VALUE is a generation parameter**, as much as
`remesh_project` is: paint a dark prop mid-charcoal and darken it in the bake, never paint it black.
And TRELLIS is **not bit-deterministic** — the same seed and inputs re-ran 4,769 tris as 4,627, so a
seed reproduces the look, not the file.

## `sewer-pile-1` splits into a block, a brick heap and a broken pipe

The last composite prop underground — one generation of *concrete slabs + bricks + a rusty flanged
pipe* — and by then the only expensive thing in the tunnels. Its 100k master split **3.19×**
(131,425 verts / 41,265 positions), so meshopt could never touch it and it shipped undecimated at
**19,223 tris**, four times every other prop. Live habitat: 5 instances = 96,115 of 139,557 prop
tris = **69%**. Its footprint was outsized to match — `r` 2.04 at `h` 0.7 = worldR **1.425**, i.e.
2.85 units across a 4-unit cell, parking it 0.53 off the cell centre.

**The three replacements landed exactly where the split-ratio rule predicts.** Hard surfaces
(`sewer/block` **1.23×**, `sewer/pipe` **1.32×**, the drum's class) generated once at
`decimation_target 100000` and decimated offline; rubble (`sewer/bricks`) went straight to the
budget at 5000 and ships `tris: -1`, and it came back **2.11×** — past the ~2× line, confirming the
100k route would have been wasted money on it. Nobody had to guess: the ratio was read before any
bake was chosen.

**`error` 0.01, not the habitual 0.005.** Swept on both clean subjects at target 1200: block
0.005 → 5,356, **0.01 → 3,198**, 0.02 → 2,496, asymptote 2,314; pipe 0.005 → 7,224,
**0.01 → 5,890**, 0.02 → 5,670, asymptote 5,602. 0.01 halves the block for no visible loss at prop
scale, and it is what keeps texels/tri honest — at `tex` 512 the pipe reads **45** texels/tri, right
on the ~43 a TRELLIS 2048 export is authored at, where 0.005 would have dropped it to 36 and under.

**Both concrete props needed a `baseColor` darken, and the numbers say so before the eye does.** The
prop family sits at mean sRGB ~46–49 (drum 46/47/52, crates 33/49/59, cable 32/47/56) against a
floor of 65/68/62. Pipe baked at **86/87/79** (1.8×) and block at **110/110/108** (2.4×) — pale cast
concrete, a lit lump against flat art. Uniform linear factors 0.35 and 0.22 land them at ~52 and
~55, computed as `f = (target/measured)^2.2` — the same formula that reproduces the bags' shipped
0.47 exactly. All three MR maps are pure green (R=0, B=0): rough dielectric, no `dropMR`.

**Result: 17 props for 76,968 tris, against 14 props for 139,557 — −45% while placing three more.**
Per prop 9,968 → 4,528. Draw calls did not move: with 7 table entries and 5 drawing in this level
(crates and cable rolled zero placements, and `Models.instanced` builds no mesh for an empty list),
the topbar read 50–52 dc either side. Not an A/B — the window would not foreground, the HUD held at
**1 FPS**, and `calls` swings 29–44 on pose alone down there. The tri number is the honest one; it
is inventory × instance count and pose-independent.

Placement re-verified headless on the demo tunnel with the new table: 14 props over 63 eligible
faces, **zero misplacements** (every one on a floor cell, pinned to a genuinely solid neighbour at
exactly its own `r * h + PROP_CLEAR`), 0 duplicate cells, max |yaw| **1.923** against the 2.071
camera-side bound, 2 corners and both taken by the corner pool. Live, every instance sits at exactly
`h/2`.

The last knob was scale, and it repeated the bags mistake before catching it. Heights are read off
the drum as a ruler — it ships at `h` 1.8 for a real 0.88 m 200 L drum, so **one world unit ≈
0.49 m**. The block went out at `h` 0.55 (a correct 0.40 × 0.27 × 0.19 m half-block) and read as a
speck beside its neighbours in a per-batch tint pass; **0.7** is the shipped value. That ruler is
also what killed the original "single brick" idea outright: a real brick is **0.44 world units**,
under the 0.46 floor of the 2D `SewerDebris` litter the tunnels already scatter ~22 of per level for
zero draw calls.

## Four drums in a line: the pool is dealt as a deck, not rolled

A habitat shipped with all four of its drums on one wall. Two separate things were wrong, and only
one of them was the hash — worth writing down because the hash bug is the more interesting one and
the *less* important one.

**Every roll in this system is GF(2)-affine, so `% 2` reads a single bit.** `SewerModel.mix` is a
xorshift, and xorshift, multiply-by-odd and xor are all linear over GF(2) — so the whole chain from
`(bcol, brow)` to the roll is affine, and every output bit is a fixed XOR of the coordinate bits.
`roll % cand.length` on the **2**-entry corner pool therefore extracts exactly one linear form.
Measured over a 40×40 block grid: a row band scored only ever **16 or 24** of one pick out of 40 —
never a value between — against a fair coin's continuous spread at sd 3.16. Shifting first does not
help: `(roll >>> 16) % 2` quantises just as hard, to 18/22, because a shifted bit is still one linear
form. Reducing through an odd number does, since the result then depends on all 31 bits at once
(spread 10..27, sd **3.22**). Hence `PICK_ODD = 997` before any small-pool index. The 5-entry flat
pool never had this: 5 is already coprime to 2³².

**But that was not what put four drums on the wall, and shipping it as the fix would have been
wrong.** With the odd modulus in, the same level still dealt drum ×4 / crates ×2 — it merely swapped
which cells — and the flat pool got *worse*, rolling cable for **6 of its 7** spots. The reason is
arithmetic, not hashing: a habitat's rooms are 5×5 in a band, so nearly every corner in the level
lands on the one row where their walls line up, and on 5 such spots a fair two-sided coin comes up
4-or-more the same way **37%** of the time. Independent rolls cannot fix clustering; they can only
be lucky.

**So each pool is now DEALT.** A deck per pool (0 = flat run, 1 = corner), Fisher-Yates'd off the
same hash chain on refill so a level stays fully determined by its saved grid, and popped one spot
at a time. Every entry comes out once before any repeats, which caps a run by construction. Demo
tunnel, 14 props: flat sequence `cable, bricks, block, pipe, bags | block, bags, pipe, bricks,
cable | block, bags` — each cycle a full permutation, **max run 1**, counts 3/3/2/2/2/1/1, and the
placement invariants all still hold (zero misplacements). Live habitat, the offending row 8:
`drum, drum, crates, crates, drum` — **max run 4 → 2**, corner counts 4/2 → 3/3, flat counts
cable 6-of-7 → 2/2/1/1/1.

Two is the floor for a 2-entry bag: one permutation can end on the same face the next one begins
with. Left there deliberately — two drums standing together reads as stored, four in a row reads as
a bug — and forcing perfect alternation would need a carry-over `last` and would look mechanical.

## The tunnels read as boxes, and the wall art was never the problem

"Walls are awfully orthogonal, 90 degree edges and corners". The instinct is to attack the masonry;
the measurement says do not. Wall **faces** are 0.67% of the view against the ledge **tops**' 14.68%
(recorded above), and `app/textures/sewer/wall.png` is already broken bricks, moss and missing
blocks. What actually reads as orthogonal is the **cap edge**: one dead-straight, dead-level,
high-contrast line where a lit cap meets a near-black face, repeated on a 4-unit lattice, with every
arris a 0-width crease.

Three changes, all inside `SewerGeom` + `SewerStyle`, **zero art and zero new draw calls**:

**`CAP_CHAMFER 0.25` — a 45° wedge between face and cap.** The wall face now stops at `WALL_H - c`
and a second quad carries it up and back to the cap, while the cap quad is pulled back by the same
`c` on every edge overlooking a floor cell. The two are exactly paired along an EDGE (a cap edge
insets *iff* its neighbour emits a wall against it). Swept live: **0.15 invisible at both presets,
0.45 a chunky moulding, 0.25 right** — the wedge covers ~0.25 units of screen at either preset, since
the vertical drop and the horizontal setback trade places as the pitch goes 53° → 71°. This is the
same rim the **rejected** ledge-rim darkening was after, and the reason it works here is that it is
geometry with a normal, not art faking a stripe.

**The wedge is a bevel on a plan OUTLINE, so it has to be MITRED — the first cut shipped without it
and hung quads in the air.** Run a wedge along a whole cell edge and at an **outside** corner its
last `c` has nothing underneath: both walls have receded by `d` at height `fh + d`, so the strip
beyond the corner is over open corridor. Two wedges cross in mid-air past the corner while the cap
they should have met sits `c` behind them. The dual bug is at an **inside** corner, where the two
wedges stop short of each other and leave a `c × c` notch straight through to the background.

Both are fixed by classifying each END of the top edge off two neighbours — the cell along the run
(`perp`) and the one diagonally behind it (`diag`):

| `diag` | `perp` | corner | what the end does |
|---|---|---|---|
| floor | — | outside (or two solids pinching at a point) | pull the top edge IN by `c` |
| solid | floor | straight run | nothing; the next cell emits a collinear wedge |
| solid | solid | inside | nothing, plus a vertical return triangle |

The outside case costs **no triangle** — the quad just becomes a trapezoid, and since the two wedges
already share their bottom corner, closing the top closes the whole seam along the 45° mitre. The
inside case gets a **chamfer stop**, which is how a real chamfer dies into an inside corner; note it
must NOT be fixed by extending the top edge instead, because that slides the wedge under the diagonal
cell's un-inset cap and opens a void beneath it (the cap would then need an L-shaped notch, 4 tris
instead of 2 on the biggest surface in the scene).

Verified headless on the demo tunnel, `SewerGeom.build` into a throwaway `THREE.Scene` from CDP:
**84 faces, 8 outside ends, 16 inside ends → 352 wall triangles against 84×4 + 16 = 352 exactly**, so
every stop is present and nothing else is. And the seam invariant: **all 136 interior wedge-top
vertices land exactly on a corner of the inset cap, 0 misses.** The first attempt at that test —
"is the vertex over a solid cell?" — passes on the broken build too, because the overshoot is inside
the solid cell's *footprint* and merely above its bevelled surface. Border verts legitimately miss
(the demo puts floor on the grid edge, where there is no cap cell); a real area's border is solid.

One emitter now covers all four directions, off `(p, n, s, e)` — the wall plane on the axis the face
does not run along, the sign of its inward normal there, and the two run coordinates in winding
order. The four hand-written cases it replaced could not have carried the mitre readably.

**`vertexColors` on the shell, keyed off the cell LATTICE.** A hashed value ±`TINT_AMP 0.15` at each
lattice point (rounded cell index + a coarse height band), read at the four corners of every quad.
`MeshBuf` gives each quad its own verts, so anything per-face or per-quad would step hard at every
cell boundary — the exact seam that killed the two-wall-variant experiment. Two quads meeting at a
lattice point ask the same question and get the same number, so it interpolates across a whole run
and *cannot* seam. Same attribute carries the creases: `TINT_FOOT 0.80` at the wall/floor junction,
`TINT_CORNER 0.75` down an inside corner's vertical line (both faces darken it by the same factor, so
they agree), `TINT_CHAMFER 1.08` on the wedge. That last one is small because the hemisphere fill
already ramps it — sky whole on a flat cap, midpoint on a vertical face, 85% of the way up on a 45°
wedge, ≈11% over the face against a large normal-blind ambient.

**`FLOOR_TILE`/`LEDGE_TILE` 8.0 → 7.0.** Both were exactly two cells, so the texture period landed
on the same point of the tile at every grid line and the repeat read as a pattern on the two surfaces
that fill the screen. 7.0 pushes the echo to 7 cells. One constant.

Cost is inventory, not a frame reading: **+1 quad per wall face** (habitat has 104), cap insets move
vertices without adding any, and every chamfer goes into the wall buffer it beveled — so the shell
still merges to one mesh per texture. `vertexColors` adds one program permutation per shell material,
warmed for free because `View.warmup` runs this same builder over `SewerModel.demo()`. **No `calls=`
or `tris=` claimed**: the window would not foreground, the HUD held **1 FPS**, and the topbar swung
50–56 dc / 69.9–70.6k tri on camera pose alone between otherwise identical frames.

One clamp followed: `SewerDetail.decals` now bounds decals to `WALL_H - CAP_CHAMFER`, since above
that the wall recedes and a quad set `DECAL_EPS` proud of the face plane would hang off the bevel.

Not done, and next if the line still reads too ruled: **per-cell cap height jitter** (downward only,
so the camera-clearance reason `WALL_H` is 3.0 is untouched). It needs a shared `capY()` — the wall
must take the height of the solid neighbour it faces, adjacent solid cells at different heights need
a filler quad or the plateau opens, and `SewerGround` places its ledge clutter at a hardcoded
`WALL_H`.

## Contact shadows stood up an inside wall corner

The floor/wall junction has had fake contact shadows since the tunnels landed. The vertical corners
never did, and that gap is structural rather than a tuning oversight: **nothing in the sewer lighting
can darken a vertical corner.** `AmbientLight 3.95` is normal-blind; the `HemisphereLight 1.89` keys
on `normal.y` and *both* faces of a vertical corner are vertical, so they take byte-identical hemi;
and a pooled spot out in the corridor sees both walls at once. The only engine answer is GTAO, which
measured **+140 calls / +5.4ms** and ships off.

**It costs no draw call.** The strips ride the floor strips' own `InstancedMesh` — same
`PlaneGeometry(1,1)`, same material instance, same `makeShadowGradient()` — so a whole level of them
is extra matrices in an array that already existed. No new program, no warm change, no art. Their
alpha is `SHADOW_ALPHA` by construction rather than a knob of their own. Live habitat: **21 inside
corners → 42 strips, 32 emitted**, strip batch **102 → 134**. The 10 dropped are on `dir 1` faces,
whose inward normal is `-Z` against a camera always at +Z looking back along `-Z` — backface-culled
in every pose, so those strips could never draw.

**Orientation: a yaw alone cannot place one.** The gradient runs along the quad's local +Y (v=1 is
the transparent end), so standing it up means a quarter turn about local Z first — and *which*
quarter turn depends on which END of the face the corner sits at, because yaw sets the normal and the
fade direction together. Mirroring instead would flip the winding off `FrontSide`. So: two base
quaternions, picked by `-nz * ax + nx * az < 0` against the wanted fade direction, then
`Math.atan2(nx, nz)` for the yaw — the same idiom `SewerProps` uses on its summed normal.

**And they must MEET, not cross.** Each strip stands `WALL_SHADOW_EPS` off its own wall, so a strip
running from the bare corner would poke that same distance past its perpendicular twin and paint a
small double-dark cross. Each therefore *starts* `WALL_SHADOW_EPS` along the wall as well, which is
exactly the twin's stand-off. Same lesson as the chamfer mitre, one entry above.

**Draw order was a real bug, not a nicety.** All of this is transparent with `depthWrite` off, and
every piece is a level-wide merge whose object origin is `(0,0,0)` — so three's transparent sort
compares an identical `z` for all of them and falls through to `a.id - b.id`, the order the meshes
were **constructed**. `SewerDetail.build` ran `grime, shadows, decals`, which put an `alphaTest`'d
crack decal *over* the corner shadow, replacing it rather than tinting under it. Now `grime, decals,
shadows`. `SewerStyle.WALL_SHADOW_EPS 0.07` also has to clear `DECAL_EPS 0.05` for the same reason,
as a physical gap rather than `polygonOffset`.

`TINT_CORNER` went **0.75 → 0.90**. The vertex term and the strip stack multiplicatively, and 0.75
under a 0.55-alpha black put the corner at **0.34 of base** — a hole. The vertex term is now the
broad wash under the strip, and the only thing covering the chamfer and its stop triangle, which
stand above the strip's `WALL_H - CAP_CHAMFER` top.

Verified headless on the demo before looking at it, `SewerGeom.build` into a throwaway
`THREE.Scene`: **96 strip instances = 84 flat + 12 vertical**, against 8 inside corners with 4 of
them camera-side (8×2 − 4 = 12). Every vertical instance decomposed and checked: spans exactly
y 0 → 2.75, exactly `WALL_SHADOW_W` wide, normal points into a floor cell with masonry behind it, and
its opaque end sits at exactly 0.07 **both** off the wall and along it from the corner lattice — the
meet-don't-cross invariant. Zero failures on all five.

Also found and NOT acted on: `dir == 1` (south) wall faces have normal `(0,0,-1)` and
`CAMERA_SEWER` always sits at +Z looking −Z, so **those quads are backface-culled in every pose** —
along with their grime and decals, which is ~a quarter of both passes wasted. The wall quads
themselves are not free to drop: `SewerGeom.add(..., casts = true)` and the shadow map renders from
the light, not the camera.

## The cap stops being LEVEL, and a lattice key is what makes it free

The chamfer broke the silhouette into two edges. It did not stop those edges being dead level, which
is the other half of "the tunnels read as boxes" — every wall top in the level sits at exactly
`WALL_H`, so a run of corridor draws a ruled line and every corner is a right angle in elevation too.

The report's proposal was a per-CELL height, `WALL_H − hash ∈ {0, 0.15, 0.30}`. **That formulation
is what makes the job expensive, and the cost is not the height, it is the STEP.** Two adjacent
solid cells at different heights leave a vertical gap in their shared edge — the same hole through
the plateau this doc already records for an uncapped interior cell — so every solid/solid boundary
needs a filler quad. Then the filler meets `CAP_CHAMFER`: at any corner where a perpendicular
neighbour is floor, the cap it should reach has been pulled back by `c`, so a full-width filler
sticks a zero-thickness fin `c` tall up through the bevel, and one inset to the cap's own outline
leaves a `c`-wide notch between the two cells' wedges. Fixing that is a three-case classification of
the filler's ends — the mitre problem again, on new geometry.

**Keying the height off the LATTICE instead of the cell removes the entire class.** `capY(x, z)`
hashes the *rounded* cell index, exactly as `tint` does, so it is a property of a grid POINT and not
of a cell. Two cells sharing an edge read the same two corner heights and their caps meet exactly;
a wall takes `capY` at each end of its run and its top edge tilts between them, landing on the same
two points the neighbour's cap corner does. No step exists anywhere, so no filler exists, no case
exists, and the tri count is untouched. The `CAP_CHAMFER` inset is 0.25 of a 4-unit cell, so an
inset corner rounds back to the lattice point it came from and takes the height the wedge below it
tops out at — the same rounding argument that already made the tint safe on an inset cap edge.

What it costs is that nothing may assume `WALL_H` any more. Three consumers, all real:

- `SewerDetail.decals` clamped to `WALL_H - CAP_CHAMFER`; now `SewerGeom.faceH`, the **lower** of the
  face's two corners, since a decal has to clear the bevel at the low end of a tilted edge.
- the vertical corner shadows took the same constant. They stand *off* the wall, so overshooting a
  descending edge would show a black sliver against the background with nothing to hide it. Each
  strip now takes the lower of its own two ends — the corner, and `WALL_SHADOW_W` along the edge,
  interpolated, because the top edge is a straight line between two lattice heights.
- `SewerGround`'s ledge clutter sat at a hardcoded `WALL_H + LEDGE_DECAL_Y`. A rigid quad on a
  sagging cap sinks at one end and floats at the other, so `SewerGeom.capAt` evaluates the cap
  surface at an arbitrary point — on the same two triangles `cap()` emits, diagonal `u + v = 1` —
  and each decal corner is placed on it. The floor pass is genuinely flat and keeps its constant.

`CAP_SAG` ships at **0.4**, downward only: `WALL_H` is the camera-clearance number and nothing may
rise above it. 0.4 over a 4-unit cell is a 5.7° tilt, ~3.4° on screen at either preset.

Verified headless on the demo, `SewerGeom.build` into a throwaway `THREE.Scene`: **every cap vertex
sits on `capY` of its own lattice point (0 off), none above `WALL_H`, none below `WALL_H − CAP_SAG`,
range 2.601–3.000**. Wall tris **352 against 84 faces × 4 + 16 stops = 352 exactly**, i.e. the sag
added no geometry. The seam invariant from the mitre entry still holds with the heights moving:
**0 interior misses**, 48 legitimate border verts (the demo puts floor on the grid edge). Ledge
decals: 284 verts, every one at exactly `LEDGE_DECAL_Y` above the cap surface, max tilt within a
single decal 0.182. Vertical corner strips: 12, tops now spread 2.370–2.664 where they were all
2.750, and **0 standing above their own wall**.

No `calls=` or `tris=` claimed, same limitation as the entries above — the HUD read 1 FPS. The tri
count is inventory-identical by construction, and no material, program or draw call changed.

## The sag shipped a hairline down every inside corner, and the chamfer inset is why

"There are always seams on inner corners." Real, geometric, and a regression from the entry above.
A 1-pixel pure-black line running out of every concave corner along the plateau, with the
world-tiled texture and the shading continuous straight across it — which is the tell that both
sides are **cap**, not a boundary between two different surfaces.

`cap()` sampled `capY` at its four corners, and a corner overlooking a floor cell is not at a
lattice point: it has been pulled back by `CAP_CHAMFER`. `capY` rounds it back to the lattice point
it came from — which is exactly what makes the wedge/cap seam close, and exactly what breaks this.
The neighbour across that edge is un-inset there (its own perpendicular neighbour is masonry), so it
draws a straight line between the same two lattice heights over the **full** cell while the inset
one covers 3.75 of it. Same endpoint values, different spans, so they diverge:

```
gap = (CAP_CHAMFER / CELL) * Δh = 0.0625 * Δh,   max 0.0625 * CAP_SAG = 0.025
```

Only at inside corners, because a cap edge-end insets iff its perpendicular neighbour is floor, and
the two cells across a boundary disagree about that exactly where the corridor turns concave. A
straight run agrees at both ends and is watertight, which is why the rest of the plateau was fine.

**Fix: a vertex that is not on the lattice takes its height from the SURFACE, not the lattice.**
`capAt` already evaluates the cap on the same two triangles `cap()` emits, and along a cell boundary
that reduces to the shared edge — so it *is* the line the neighbour draws. `cap()`'s corners and
`side()`'s wedge tops (at `(s2, p+o)`, not the un-inset `(s, p)`) now take it. `capAt` is exact at a
lattice point, so nothing un-inset moves.

The trap, and it is the reason this is two samplers and not one: the wall **face** top must stay on
the lattice (`capY - k`). Give it `capAt` too and the two perpendicular faces of an inside corner
sample at their own inset offsets, disagree, and the crack simply moves into the wall. Same for the
chamfer stop — its apex is on the lattice corner (`capY`), its other top vertex on the inset plane
(`capAt`), so the stop's top edge now slopes along the diagonal cell's cap edge instead of running
flat through it. Face and wedge stop being exactly `k` apart, by at most 0.025, which is the point.

Verified by a boundary-edge scan of the real emitted buffers (weld, count edge usage, keep the
count-1 edges, look for a vertex lying in the plan-interior of one at a different height) on a 44×44
grid at 50% floor — the demo tunnel is far too regular to exercise this: **295 cracks, max 0.0247,
mean 0.0082, all 295 on the ledge mesh and all on a cell boundary line → 0 cracks.** Wall tris still
352 on the demo, cap still inside `[WALL_H - CAP_SAG, WALL_H]`, all 352 face tops still on the
lattice, 200 wedge tops with 0 interior seam misses.

Second defect, same cause, fixed with it: the vertical corner shadow strip is a rectangle, and one
instance matrix cannot taper a quad, so a tilting bevel means its top edge must disagree somewhere.
It took `min` of its two ends, which puts the error **in the corner** — a lit sliver up to 0.072
where the gradient is fully opaque. It now takes the height at the corner itself and lets the far
end, where the gradient has faded to nothing, be the end that disagrees. All 12 demo strips land
exactly on the bevel bottom at their corner.

### Sewer LOS: a world-space vision mask, folded into the fog
Indoors the 3D layer hid AI and objects (`Actors`, on `playerArea.sees`) but drew the LEVEL whole —
you read the whole tunnel corner to corner and only its contents popped. `AreaView.draw` early-outs on
a 3D area, so the 2D black LOS overlay never ran down here. Now `render.sewer.SewerMask` bakes a
top-down mask (canvas + `CanvasTexture`, `MASK_PX 4` texels/cell, whole level: 300×240 for a 75×60)
and every tunnel material samples it by world XZ, mixing toward `fogColor` at `MASK_HIDDEN 0.18`.
Zero draw calls, zero passes, zero geometry — the five-mesh weld survives untouched.

**Per-cell was built first and replaced.** A cell grid cannot express a shadow edge running diagonally
off a wall corner, and — decisively — `sees()` takes INTEGER endpoints, so a per-cell mask is quantised
to the player's cell by construction and no smoothed origin can ever move it. The shape is now the
2D view's own sweep (`AreaView.buildLOSSegments`/`castLOSRay`) ported from screen px to cell units:
rays at every exposed blocker corner ±1e-4, nearest hit wins, hits in angle order ARE the polygon,
`ctx.fill()` antialiases the edge for free. Blocking is `area.canSeeThrough` (object-aware — a closed
door blocks), not the renderer's floor grid.

`MASK_R 14` is derived, not picked: `maxFootprintCells` at the sewer preset pinned to full zoom-out is
180 cells = 9.6 deep × 21.6 wide, so the ground reaches 12.2 cells at the far corner. Cost is
O(rays × segments) and both grow with it. Actors deliberately stay on `sees()`; the two disagree
within ~a cell of a corner during a move animation, which reads as a soft lead/lag at `FADE_SPEED`.

**Two defects the live census caught, both invisible to a build:**
`userData` is the WRONG place for an "already patched" flag — `Material.clone()` copies userData but
NOT `onBeforeCompile`/`customProgramCacheKey`, so every ghost clone `Models.instanced` makes from a
patched template read as patched and never was. The mark now lives on the hook function itself.
And **patching by scene traverse is wrong here**: the actor pool, path line, tactical grid and
`DecalBatch` all land in the same scene later, and the traverse overwrote DecalBatch's own
`onBeforeCompile` (per-instance alpha + atlas UV) along with its `decalInstanceAlpha` cache key. Each
tunnel builder now patches its own material as it creates it — which also buys warm parity for free,
since `View.warmup` runs those same builders. Measured after: 39 materials, 32 masked, and the 7
skipped are the hull marker (`fog:false`, by design), the actor billboards, and DecalBatch intact.
Mask programs 13 → 8; total 87 → 85 once the warm props were patched too.

### Sewer LOS: the mask origin follows the SLIDE, not the logical cell
The mask above keyed on `opts.playerCol/Row` = `game.playerArea.x/y`, which snaps to the destination
the instant an action resolves. So it did not merely fail to be smooth — it ran a whole `BASE_MS`
**ahead** of the player, swinging its shadows from a cell the billboard had not reached and holding
them there for the entire slide. `update` now takes `opts.player.x/z` (the smoothed world position,
already in `Area3DTickOpts`), converts to continuous cell coords, and keys on that quantised to
`MASK_STEP 0.05` cells. Four things had to follow the origin: the key, the polygon origin, the scan
window and the own-cell skip — the last two are the only integers in `polygon()`, and centring them
on the logical cell instead would leave the window up to a cell off the point the rays leave from
while the square range bound (built from `ox/oy`) reached past the last column ever scanned.

**It needed no gate.** Isolated, habitat, N=300 forced rebuilds: **0.30ms median** = 0.1 cell scan +
0.2 sweep/fill. The scan is 841 cells and 3476 `canSeeThrough` **regardless of level size** (a fixed
`MASK_R` window), so only the sweep grows; ~1.5ms projected on a full 75×60. The envelope is 9 frames:
`ActorAnim.slideTo` is finite — `t` clamps to 1 and its whole update is gated on `t < 1` — so a rested
origin sits exactly on the cell centre and stops. Idle costs nothing, as before.

**In-frame A/B, 5 PAIRED rounds** (rebuild forced every frame vs idle, window focused at 59.9fps,
`GPU < 100` filtered, paired so clock drift cancels). Median deltas: `upd` **+0.60ms** and `submit`
**+0.30ms**, both positive in all five rounds; `GPU` sign-flips (+0.02/+0.38/−1.39/−0.16/−0.38) =
noise, as it must be with no added calls and no added fragments; `idle` −0.70 absorbs the CPU added;
**`frame` delta 0.00 — vsync never missed**. Worst case ~0.9ms on a rebuild frame against 13.9ms of
idle, and that worst case never happens: 9 frames a move, then nothing.

Two corrections to the numbers above, both from measuring IN the frame instead of beside it. The
upload is **not** free: an isolated `texImage2D` on a throwaway GL2 context read under the 0.1ms timer
resolution at both 84×56 and 300×240, while three's real path costs `submit` **+0.30ms**. Probably
fixed overhead rather than bandwidth — the isolated test saw no scaling across 15x the texels — but a
full sewer's upload has never been measured in-frame. And in-frame `upd` (+0.60) is **2x** the
isolated tight-loop rebuild (0.30): cold cache in a real frame.

Verified live (frame timing was impossible — window occluded at 1 FPS, rAF delta 1016ms — but all of
this is synchronous CPU): at rest the new key is **70/70 = `round(3.5 / 0.05)`**, i.e. it reproduces
the old `pcol + 0.5` origin exactly; a smoothstepped 1-cell sweep rebuilds on 9 of 9 frames with key
deltas 1,2,2,3,4,3,2,2,1 (peak 0.20 cells/frame) and a white-texel census walking 2160 → 2230 of 4704
in steps of 14–25, no jump, antialiased edge texels holding 60–81 at every sub-cell origin; 6/6
bit-identical rebuilds at a **fractional** origin, which is the shimmer risk the change introduces.
`p.los false` → 4704/4704, unchanged key early-outs, `visRev++` re-fires with the origin static.

**The cost is a new divergence, and it is the opposite of the accepted one.** Actors still gate on
`playerArea.sees` at the logical cell, so where mask and actors used to snap *together* at action
time, the actors now **lead** the mask by up to one move: an AI round a corner appears while its
corner is still dark. `FADE_SPEED` softens it into a lead rather than a pop. Also unfixed: the hit-cell
reveal (`wallCol/wallRow`) still paints whole cell rects, so the polygon edge glides while the
revealed wall cells blink at cell granularity — the loudest remaining discontinuity.

Side finding: the ~11-texel one-off on the first rebuild noted in the entry above is
`AreaGame.canSeeThrough` lazily calling `recalcTile` on first touch. First rebuild warms the tiles,
every one after reads cache.

### Sewer LOS: the cell the origin straddles, and an edge hard only where it was straight
Two defects in the mask above, both found by probing the live canvas, both shipped with the polygon.

**The wall cell in the player's own column/row stayed dark however hard they stared at it.** Rays are
aimed ONLY at segment corners, and the blocker one stopped on is recovered by stepping `STEP_EPS` past
the hit — so a corner LEFT of the origin reveals the cell to its left, one RIGHT reveals the cell to
its right, and the cell the origin straddles is aimed at by nothing. Measured, player at (10,6): on the
long north wall column 10 read **0.00** while 9 and 11 read **1.00**; same on the south wall. Sweeping
the origin across two cells proved the mechanism — the dark column is exactly **`floor(ox)`** at every
sub-cell position (10.1→10.9 dark col 10, 11.25→11.5 dark col 11) and **vanishes when `ox` sits on a
cell boundary**, where the corner ray has `rx ≈ 0` and steps into the cell correctly. It only shows on
a STRAIGHT run: anywhere the geometry is irregular some other corner's ray crosses that face anyway,
which is why the chamber walls beside the player were lit while the long walls were not. The smoothed
origin did not cause it (`pcol + 0.5` straddles identically) but did add a ~1-frame flash mid-slide as
`ox` crosses the integer. **Fix: four cardinal rays** — they hit a face at exactly `x = ox` / `y = oy`,
which lands the step in precisely that cell. Complete rather than a patch: the straddle can only ever
hit `floor(ox)` and `floor(oy)`. Cost 4 rays of ~270. After: N and S both **1.00**, and the sweep's
dark set is a constant `[6,14]` (genuine occlusion) at every origin. No degeneracy — a vertical ray on
a vertical face gives `|den| ~ 6e-17` and `castRay` rejects it as parallel, correctly.

**The boundary was hard exactly where it was axis-aligned.** Canvas antialiasing writes no partial
coverage on a texel-aligned straight edge, so a scanline through the player's row was a clean
black/white step with no intermediate value anywhere, while diagonals ramped over 2-3 texels (107 mid
texels of 4704, 64 runs, median 2). The tunnels are rectilinear, so most of the boundary was that hard
case — and both sources are unavoidable: the hit-cell reveal `ctx.rect`s are always texel-aligned, and
polygon edges run along wall faces. `MASK_PX` 4 → **2** doubles the only softening a straight edge
gets, the linear ramp between two texels, to half a cell (habitat canvas 84×56 → 42×28, a 75×60 level
150×120). 1 is the floor: a revealed wall cell would be one texel and could never read fully lit.
Then `MASK_WOBBLE 1.2` world units of two-octave sine displacement on the sample UV, keyed on
`vSewerMask` — **WORLD xz and nothing else**, which glues the wobble to the level so the polygon slides
through it. Key it to anything the player carries and the whole boundary swims on every move, which is
worse than the straight line it set out to fix. Sines rather than a hash on purpose: the job is to
break a line, not to be statistically noisy, and a smooth offset keeps an edge an edge where white
noise would dither it. No new programs (85 before and after), no new fetch, no draw calls.

Rejected: a canvas blur. It keeps `MASK_PX` precision, but the benchmark read **1.6ms at 84×56 and
0.5ms at 300×240** — cheaper at 15x the pixels, i.e. it measured the `getImageData` flush and not the
blur. Not worth buying an unmeasured ~1ms per rebuild before looking at the free lever.
> The REJECTION is SUPERSEDED by "Sewer LOS: blur the visibility plane, and fade the area border"
> — re-measured with the flush amortized, the blur is **+0.08ms and flat across 15x the pixels**.
> The free lever was the right thing to try first; it just did not cover open floor.

### Sewer LOS: fade a lit wall into the dark, and wobble over masonry only
`MASK_PX` 4 → 2 above was the WRONG LEVER and is reverted. The hard 90-degree lines were never the
sampling density: they were the per-cell wall REVEAL, which painted a flat white rect and stopped at a
cell boundary. Out on open floor a straight boundary is a real ray cast past a corner and reads wrong
bent or blurred, so the two halves of the mask wanted opposite treatment, not one global softening.

**A lit wall cell now fades toward masonry the sweep never reached** (`MASK_WALL_FADE`, 0.5 cells),
painted per TEXEL because a cell can fade toward two sides at once and the value there is the MINIMUM
of the two — no stack of `createLinearGradient` gives that. Affordable because it only runs at the ENDS
of a lit run: interior cells still go into one path with one fill. The unreached cell is never painted
at all, which is what keeps it fully dark — a linear filter bleeds half a texel, so holding the last
lit texel a texel clear of the shared edge puts the whole ramp inside the cell that can be seen.
Verified: red texels across a fading cell come out `255,255,191,63` (exactly `min(1, d/0.5)`), mirrored
on the opposite side, and across ROWS where the dark neighbour is north — and **0 of 294 cells show any
red bleed into an unreached wall**.

**The wobble is now gated to masonry** by a WALLNESS channel in the mask's GREEN, so open floor keeps
the exact polygon. Green is static per level — walls do not move — so it is painted once into a
`wallLayer` canvas and blitted in as each rebuild's clear, which costs one `drawImage` instead of a
fill per wall cell. Everything after that blit composites `'lighter'` and writes RED ONLY, so the
visibility paint crosses a wall cell without trampling the wallness under it, which an opaque fill
would. Verified 294/294 cells: green matches masonry exactly. The shader takes one sample at the true
uv (for `.r` and `.g`) and one at the wobbled uv, then `mix(straight, wobbled, .g)` — 2 fetches of a
tiny cache-resident texture, and `.g` interpolating across a wall/floor boundary fades the wobble in
over a texel instead of switching it on at a seam.
`buildWallLayer` is called UNCONDITIONALLY from `attach`, not from `ensure`: `ensure` early-outs on
matching dimensions and every habitat is 21x14, so a layer cached on size alone would be the previous
level's walls. The hit cells also had to be de-duplicated (generation stamps, no cleared grid) — every
ray landing on a cell painted it again, which was harmless for a flat rect and is not for a gradient.

Left open: with these changes, `make reload` **while an area is live** logs one `Uncaught (in promise)`
with no reason — 2/2 with them, 0/2 without, and reloads from the menu are clean either way. An
`unhandledrejection` handler installed ~100ms into the new page and held 10s catches nothing, so the
rejection is in the OLD page during teardown and dies with its context. No shader error is ever logged,
programs stay at 85, and in-game there is nothing: 60fps, 42 forced rebuilds and both `los` paths give
zero rejections and zero errors. Dev-only, on an action the shipped game never performs.

### Sewer LOS: the ground debris was never masked, and `patch()` now CHAINS
Ground debris sat at full brightness in a corridor nobody could see. It rides `render.decals
.DecalBatch`, which was one of the 7 materials the mask census listed as skipped — skipped because it
carries an `onBeforeCompile` of its OWN (per-instance alpha + the atlas window) that an earlier
traverse had already overwritten once. So the fix was not to patch it, it was to stop `patch()` from
replacing: it now CHAINS a pre-existing hook, running it first and injecting into what it produced.
Safe because the two use different anchors — `<uv_vertex>`/`<opaque_fragment>` against
`<project_vertex>`/`<fog_fragment>` — and each survives the other's edits.

**The trap, and it blanked the whole frame.** Chaining the cache key the obvious way —
`prevKey = mat.customProgramCacheKey`, call it, append ours — throws on EVERY draw. three's `Material`
carries a **default `customProgramCacheKey` on the prototype** that returns
`this.onBeforeCompile.toString()`, so the field is never null, and calling it with no receiver makes
`this` undefined: `Cannot read properties of undefined (reading 'onBeforeCompile')`, 838 times, 0 draw
calls, black screen. Take the previous key only when the material owns one (`hasOwnProperty`) and call
it through `Reflect.callMethod(mat, ...)` so it gets its receiver. Verified live: the decal material
comes back keyed **`decalInstanceAlphasewerMaskb`** with both hooks intact, beside the exit ladder's
`sewerMasks` / `sewerMaskb`.

Where the patch is applied is forced by lifetime. The batch belongs to the ACTOR layer, not the area,
and its groups are built lazily on the first paint that needs one — so there is no build-time moment,
and `View`'s render loop patches them right after `actors.update`. Gated on the area being a
`SewerArea`: `Actors` is rebuilt per area (so the city gets a clean batch) but the mask uniforms are
static, and a patched material left over above ground would sample the last tunnel's canvas.
`DecalBatch` exposes MATERIALS rather than meshes because `grow()` swaps a group's mesh and keeps its
material, so a mesh list would go stale where this cannot.

Still unmasked underground, same class of bug, not touched here: the per-quad `Sprites` path — emissive
blood, wall holes, star glints. Actors and objects also ride it but are hidden outright by `sees()`, so
they do not need the mask; those three decorations do.

### Sewer LOS: blur the visibility plane, and fade the area border
Two complaints, both from standing against the outer wall of a habitat.

**The floor boundary was jagged because the mask has no ramp there at all.** The sweep is innocent —
scanlines across a diagonal shadow edge read `0 0 0 0 [96] 255 255`, stepping exactly one texel per
texel row, i.e. a clean antialiased 45 degrees. Whole-canvas census: **55 intermediate texels over the
entire floor boundary**, about one per unit of boundary length. So the complete lit/dark transition on
open floor was ONE coverage value, and `MASK_PX 4` over `CELL 4` makes a texel **one world unit** —
~30-38 screen px at `CAMERA_SEWER` (fov 45, 1920x1003 buffer). Bilinear reconstruction of a single
antialiased texel puts a staircase of that same period along the edge. Nothing to do with `MASK_WOBBLE`:
`sewerM.g` is 0 across open floor, so the straight sample is the one used.

`MASK_BLUR` (0.75 texels of gaussian) fixes it, but NOT by blurring the mask. The green masonry channel
is what the shader gates the wobble on, and smearing it would bleed the wobble a texel out onto floor.
So the red visibility plane gets a **scratch canvas of its own**: polygon, wall rects and `fadeCell` all
paint there, and it is composited in through `ctx.filter` on top of an unblurred `wallLayer` blit.
Measured after: the same scanline reads `0 1 8 41 116 199 243 254 255`, floor intermediates **55 →
311**, and **`greenNotPure` is 0** — the masonry channel is still exactly 0 or 255 everywhere.

0.75 took the band to ~3 texels, the width `MASK_WALL_FADE` already produces on the wall side, and that
still read as a straight edge — so it went to **2.0**. Swept on the live canvas (band = intermediate
texels, dim = share of genuinely lit texels under 200, bleed = mean red over never-reached texels):
`0.75 -> 867 / 1.5% / 1.9`, `1.5 -> 1485 / 5.6% / 5.2`, `2.0 -> 1826 / 14.6% / 7.5`,
`2.5 -> 2149 / 18.8% / 9.8`, `4.0 -> 2874 / 39.1% / 17.4`. It is a CONVOLUTION, so the band can only
widen by eating the lit side or spilling onto the hidden one — there is no setting that only softens,
and past ~2.5 a one-cell corridor stops reaching full brightness.

**Sigma is free; the filter CALL is what costs.** Re-measured at both: `+0.0985ms` at 84×56 and
`+0.1035ms` at 300×240 for sigma 2.0, against `+0.0765 / +0.0815` for 0.75 — i.e. flat in radius as
well as in pixels. So the knob can be tuned on looks alone.

**A bigger sigma FIGHTS the border fade, and that is structural.** `fadeCell` authors its ramp inside
ONE cell (4 texels at `MASK_PX` 4) while a sigma-2 kernel spans ~8, so the blur averages the ramp back
up toward the interior: the west border cap's outermost texel — the silhouette against no geometry at
all — went **79 (vis 0.434) at 0.75 to 103 (vis 0.511) at 2.0**. More blur makes the level's outer edge
brighter, not softer. And it bottoms out anyway: mask 0 renders at `MASK_HIDDEN` 0.18, so the outer
silhouette can never fall below 18% of a lit brick over a `0x05070a` clear. Softening THAT edge is not a
blur problem — it wants either a lower `MASK_HIDDEN` or a falloff applied AFTER the blur (a multiply
layer of `rgb(v,255,255)` scales red alone and would be blur-proof).

**Cost, and the rejection it overturns.** The earlier entry rejected this on a benchmark reading 1.6ms
at 84x56 and 0.5ms at 300x240 — cheaper at 15x the pixels, which is the tell that it timed the
`getImageData` flush. Re-measured with the flush amortized over 200 composites, A/B/A/B x5, median:
**+0.0765ms at 84x56, +0.0815ms at 300x240**. Flat across 15x the pixels, so it is fixed per-call
overhead and not fill — against a rebuild already measured at 0.30ms in the habitat.

**The area border never faded, and `dark()` said so on purpose.** It returned false off-grid, reasoning
that there is no level out there to fade into. Exactly backwards: `SewerGeom` caps EVERY solid cell and
only insets a cap edge that overlooks floor, so the border's cap runs flush to the boundary and then
there is no geometry at all — a fully lit ledge meeting the clear colour on a hard rim. That is what
standing next to the outer wall looked like, and the "fully black next tile" was absent geometry rather
than a cell at `MASK_HIDDEN`. Off-grid now counts as dark. Measured on the same habitat: col 0 rows 8-12
went from flat `255 255 255 255` to **`79 175 238 254`** west-to-east, and the south border (row 13)
with it. The cost the old comment feared does not arrive — only cells the sweep REACHED are ever tested,
so `MASK_R` bounds it.

Two holes in `dark()` deliberately left: unseen FLOOR still does not count (a one-cell-thick wall with a
hidden corridor behind it keeps a flat cap), and `fades()` is 4-connected, so a diagonal-only dark
neighbour leaves a hard corner. Neither was what the report was about.

**The level's outer rim needed a channel, not a bigger sigma.** Two independent reasons no blur setting
reaches it, both measured above: the kernel averages `fadeCell`'s one-cell ramp UP toward the interior,
and `mix(sewerMaskFloor, 1.0, m)` bottoms out at `MASK_HIDDEN` whatever `m` does. So the rim went into
the mask's unused **BLUE** channel — painted once per level beside the green masonry channel, blitted in
with it and therefore never blurred, and multiplied onto `sewerVis` AFTER the floor mix so it can reach
a true zero. One extra multiply, no extra fetch, no new programs (85 either side).

That zero is the point rather than a detail: `SewerScene` sets `scene.background` and `scene.fog` to the
same `0x05070a`, and the opaque branch fades toward `fogColor` — so vis 0 lands EXACTLY on the
background and the level stops having a silhouette instead of merely dimming toward one.

Painted as a MULTIPLY by `rgba(255,255,0,a)`. Multiply is per channel, so a source of 1 leaves red and
green exactly as painted and only the zero blue is scaled by `(1 - a)`; the four ramps each cover the
whole canvas and clamp to their far stop, so inland they are a no-op, and where two meet they multiply,
dropping a corner faster than an edge. The gradient is anchored at the outermost TEXEL CENTRE (the
half-texel inset), not at the canvas boundary — a linear fetch clamped to the edge returns that texel,
so anchoring at the boundary lands the rim at 1/8 lit instead of 0.

`MASK_EDGE_FADE` is 1.0 cell, which is exactly the always-solid border ring: measured blue
`0, 64, 128, 192, 255…` reaching full one cell in, `1056 / 4704` texels below 255, rim vis **0.000** and
the wall's inner face still **0.961**. Raising it past 1 would eat into playable floor, since the ring is
one cell thick.

Trap for anyone comparing two sewer screenshots: a capture taken while the window is throttled to 1 FPS
can be a **partially loaded scene** and look nothing like the game. The before shot read `110 geom / 177
tex`, the after `1161 geom / 291 tex` — flat and bright against the real near-black lighting. Check the
topbar geom/tex counts, not just fps.

### Sewer LOS: MASK_PX 4 → 8, paid for by not painting texel by texel
Doubling the mask (habitat `84x56 → 168x112`, a full 75x60 level `300x240 → 600x480`) is free in every
part of the rebuild except one, and ruinous in that one. Component sweep at the live cell counts, with
the `getImageData` flush amortized over 100 rebuilds:

| | clear+polygon | fadeCell | composite | total |
|---|---|---|---|---|
| `MASK_PX` 4 | 0.03 | 0.54 | 0.10 | **0.67ms** |
| `MASK_PX` 8 | 0.02 | **3.78** | 0.10 | **3.90ms** |

The polygon fill and the blur composite are both FLAT in canvas area (0.02ms at 84x56 and at 600x480;
the blur was already known flat in radius and in pixels). `fadeCell` was everything, and 7x rather than
4x, because it emitted a **1x1 `fillRect` with a freshly built `rgb(...)` string per texel** — 56 cells
x 64 texels = 3584 draw calls, each with a CSS colour parse.

**The ramp only varies along one axis unless the cell fades on both.** The usual case is masonry sitting
behind a wall the player is looking at — one fading side — and then the value is constant down a column,
so it goes out as `P` strips instead of `P*P` texels. Measured live: **27 of 37 ramped cells are
single-axis**, 10 turn a corner and still need the per-texel loop (a minimum over two axes is not a
stack of linear gradients, which is what the old comment got right). Blended, on the real 27/10 split:

| | fadeCell |
|---|---|
| before, `MASK_PX` 4, all per-texel | 0.899ms |
| `MASK_PX` 8 naive | 3.481ms |
| **`MASK_PX` 8 with strips** | **1.221ms** (600x480: 1.249) |

So 4x the texels for **+0.32ms**, and the whole rebuild lands ~1.35-1.55ms. It fires on nearly every
frame of a 9-frame slide, so that is ~9% of a 16.6ms frame while walking and nothing at all at rest.

**`MASK_BLUR` had to change units on the way.** It was a sigma in TEXELS, so doubling `MASK_PX` would
have silently halved the boundary softness in world terms. It is now in WORLD UNITS and converts at the
filter (`MASK_BLUR * MASK_PX / CELL`). The sweep table in `SewerStyle` was taken at `MASK_PX` 4 where a
texel WAS a world unit, so every number in it carries over unchanged. Everything else was already
resolution-independent: `uScale`/`uOrigin` are normalized, and `MASK_WALL_FADE` / `MASK_EDGE_FADE` /
`MASK_R` are all in cells. Verified after: canvas `168x112`, blur resolves to 1 texel, the rim ramp is
now 8 texels (`0 32 64 96 127 160 191 223 255`) and still reaches rim vis **0.000**, green channel still
exactly 0 or 255, 85 programs.

## The habitat's four objects become glb props

The habitat renders through `SewerArea`, so its walls, ledges, chamfers, clutter and exit ladder are all
real geometry — but its four defining objects were still 64px atlas cells from `entities64.png` drawn as
3.0-unit upright billboards. They now go through `render.world.ObjModels`, the seam the exit ladder
already used, at **+4 draw calls and +19,950 tris** for all four.

**`modelFor` could not tell them apart, and retyping them was the wrong fix.** `HabitatObject.init` sets
`type = 'habitat'` on all four, and `type` is persisted (`Saver` reflects every field not in
`_ignoredFields`), so splitting it per subclass would leave old saves carrying `'habitat'` while new
objects carried the new strings — and `Habitat.update` counts habitat energy off exactly that string.
New virtual `AreaObject.getModelKey()` returns `type` by default and is overridden in the four; the
three call sites (`ObjModels`, `Actors.iconOff`, `LampShadows`' double-shadow guard) switch to it.
**No save migration: nothing persisted changed**, and `imageRow`/`imageCol` still point at the atlas.

**A prop-backed object created mid-area drew NOTHING.** `Habitat.putObject` fires while the player is
standing in the habitat, but the 3D scene only rebuilds when `game.area.id` changes, while `Actors`
drops the sprite the instant the object has a model — so a freshly grown biomineral was invisible until
the area was left and re-entered. `Area3D.refreshObjects` (a no-op in the city) rebuilds the batches;
`AreaGame.addObject`/`removeObject` call it gated on `modelFor(...) != null` **and** on
`game.area == this`, so ordinary objects and other-area population never reach the view. Verified live:
the prop appears on the spot, tris 77.7k -> 82.6k (exactly one 4,827-tri biomineral), no fade-to-black.

`build()` lost its single `targetH`/`yaw` pair for a table (`keys`/`path`/`h`/`faceWall`), since one
height for five props is wrong; `SewerStyle.EXIT_MODEL_H` moved into it. Free-standing props take a
full-circle yaw hashed off their own cell so four of a kind are not clones. `View`'s warm chain now
loops that table instead of hardcoding the exit's triple.

**Cost, measured as a controlled A/B in one pose** (`habitat clear` vs `habitat all`, run twice,
identical both times): **56 dc / 77.7k tri -> 60 dc / 97.7k tri**. One call per distinct prop — the
ghost and hull batches really do cost **0** while masked empty — and `prog` held at **87** across
clear/build/tactical, so the boot warm covers every variant with no first-use compile. Standing on a
prop is **+1** (its ghost instance). Boot went 73 -> **76** programs, not the +12 predicted: all five
props share one material permutation, so the four new paths reuse the exit's programs.

**Generation: three of four were past the ~2x line, and the split ratio called it before any money was
spent.** At `decimation_target 100000`: preservator **1.34x** (the drum's class -> offline decimate,
`error` 0.01 for 48 texels/tri, 98,685 -> 5,452), biomineral **2.41x**, assimilation **2.24x**, watcher
**2.46x** -> all three regenerated at `decimation_target 5000`, `tris: -1`, landing 4,827 / 4,873 /
4,798. All four MR maps came back pure green, so **no `dropMR` anywhere**.

**The assimilation reference had to be repainted before it was generated at all.** Its first restyle
measured subject luma p05 **34** — between the p05 30 that made `sewer/bags` hallucinate a violet albedo
and the p05 48 repaint that fixed it — and was already R>G, B>>G, the exact failure signature. Repainted
to p05 **61** first. The other three cleared the band on the first edit (56 / 43 / 44 against `drum`'s
41). Biomineral still drifted in hue (olive slime -> brown, purple tendrils -> navy) with the crystal
correct; left alone, because the bags entry records a fresh seed making that kind of drift worse.

**The glow is derived from the baked albedo, not hand-painted.** `emissiveSrc` exists but the street
lamp's map was painted over a Blender layout; a TRELLIS atlas is a mosaic of hundreds of charts and is
not paintable freehand. Each prop's emissive is keyed out of its OWN baked base map — same UVs by
construction — with bands read off that atlas's measured luma percentiles rather than guessed. Guessed
thresholds produced 0.0% / 0.0% / 1.0% / 100.0% lit on the first attempt. Biomineral and watcher key on
luma (their crystal and eye discs are clean second modes); preservator does **not** (whole atlas is
39-76) and keys on **R-B**, where lavender veins sit at -14 and the amber core at +69. All four land at
11-15% of atlas lit. **No `models.mjs` change** — the output is an ordinary PNG that can be repainted in
Krita later. Cost: regenerating a glb means regenerating its emissive.

New console command for the work, since the normal path needs a live host and kills it — standing all
four up to look at them cost a spawn-attach-harden-invade cycle each:
`hab|habitat [all|biomineral|assimilation|preservator|watcher|clear] [level]`
(`console/HabitatConsole.hx`), placing on the nearest free cells in widening rings.

**Verdict: landed.** Heights (2.4 / 2.2 / 2.6 / 1.8) and the emissive bands are art values, swept live.

## One zero-length vertex normal blacks out the WHOLE frame

Reported as "the image flickers a lot on mouse movement and sometimes just becomes black". It really
did go black: the composited canvas measured mean luma **0.24 / 255** while the HUD read a healthy
60 FPS, 67 draw calls, 117.8k tris.

**The bisection, in order, because every step ruled out a whole layer.** Camera pose was correct
(follow rig over the player's cell). `SewerMask` was innocent — forcing `uFloor`/`uFloorAdd` to 1.0
lifted it only 0.24 -> 0.53. Lights were all on and at normal intensity (ambient 3.95, hemi 1.89, 12
spots at 15-45). Then rendering the same scene and camera STRAIGHT TO THE CANVAS —
`renderer.setRenderTarget(null); renderer.render(scene, camera)` — gave mean **14.28, max 219**. So the
scene was fine and the post chain was eating it. Disabling the bloom pass alone: **0.24 -> 14.15**.

**The cause is not bloom.** Reading the half-float post buffer with bloom OFF found **3 NaN texels** in
a 120x120 window over one prop. UnrealBloom downsamples to 1/32 and gaussians at every level, so one NaN
texel spreads across the whole chain, and the additive composite back over the base makes every pixel
NaN — which resolves to black. Hiding meshes one at a time pinned it to `habitat/biomineral`; swapping
its material for a `MeshBasicMaterial` cleared the frame while killing its emissive, MR maps, base map,
shadows, fog and tone mapping each changed nothing. That combination only leaves the lighting math, and
the input the lit path uses that the basic path does not is the **normal**.

`habitat/biomineral` carried **17 zero-length vertex normals**, straight out of the TRELLIS export.
`normalize(vec3(0.0))` is NaN in GLSL. That is the entire bug.

**It was never habitat-only.** The same sweep over every prop the pipeline builds:
`sewer/bags` **68**, `habitat/biomineral` 17, `sewer/cable` 2, `sewer/crates` 1, `habitat/assimilation`
1, everything else 0. So the sewers have shipped this since those props landed — the habitat only made
it constant, because the biomineral is always on screen while a bags pile usually is not. The
intermittency IS the mechanism: a zero normal is a single vertex, its interpolated neighbours are
non-zero, so a NaN fragment only appears on the frames where a pixel centre lands close enough to that
one vertex. Camera or cursor motion flips it on and off — hence "flickers".

**Fix: `fixNormals()` in `tools/models.mjs`**, run AFTER the transforms (`simplify()` welds and
collapses, so it can create one the export did not). Each bad vertex takes the area-weighted sum of the
face normals of the triangles that reference it — the standard smooth-normal sum, so the repair agrees
with the surface around it — falling back to `(0,1,0)` for a vertex with no non-degenerate neighbour. A
`PIPELINE` constant now feeds every entry's `last_sig`, so a change to what the bake DOES (not just its
per-entry params) rebuilds every prop once; bumping it rebuilt all 14.

Measured after: **0 zero normals in every built glb**, 0 NaN and 0 Inf in the post buffer over 12
frames with the cursor sweeping, and 10 consecutive frames at mean luma **14.24-14.99** where the
pre-fix frame was pinned at 0.24. Draw calls, tris and program count unchanged.

**The trap that cost the most time: `attributes.normal.array` is a LIE on these glbs.** GLTFLoader
builds `InterleavedBufferAttribute`s, so `.array` is the whole shared pos+normal+uv buffer — every
attribute reports the same length (60,720 for a 7,590-vertex prop) and a stride-3 walk reads positions
as normals. It invented zero normals that were not there and hid the real count. Use
`attr.getX/getY/getZ(i)` and `attr.count`, never `.array`.

**Verdict: landed.** Pipeline-level, so it covers every prop generated from here on.

## The organs' glow moves from the surface into the air: emissive off, coloured point lights on

Four changes to the habitat props, all author calls, all measured after.

**Emissive OFF on all four, and off properly.** `emissiveStrength: 0` now makes the bake skip the map
entirely instead of baking a map nobody sees, so the glb carries no dead texture and the material
declares no `USE_EMISSIVEMAP` — which is its own program permutation and a texture fetch per fragment.
`prog` **87 → 85**, glbs 1266/1079/1436/1008 → **1175/930/1297/897 KB**. `models.json` keeps its
`emissiveSrc` pointers, so re-enabling any one prop is a single number.

**Coloured point lights instead** (`render/particles/PropLights.hx`, `RenderConfig.PROP_LIGHT`). The two
were never a pair: an emissive map only brightens the prop's OWN texels and lights nothing around it,
while the read wanted is "this organ is a light source in the room". Colour and relative brightness live
per row in `ObjModels.MODELS.light` — each organ's own former emissive hue (crystal green `0x33bf59`,
maw violet `0x8c2ecc`, amber `0xd98c26`, flesh-pink `0xf28c80`), so the light IS the glow, relocated.

Three things about it that are not incidental:

- **Built in `SewerScene.build`, NOT `SewerArea.build`.** `View.warmup` builds its warm tunnel scene by
  calling `SewerScene.build`, so the pool is there when `compileAsync` walks it and `NUM_POINT_LIGHTS`
  (5 → **9**, the 5 idle flame lights plus 4) matches warm and real. Created a level later instead,
  every lit tunnel material would recompile on the first habitat entry. Verified by `prog` going DOWN
  87 → 85 rather than up.
- **No shadow, deliberately** — a point shadow is six cube faces per light. Reach (`distCells` 3) plus
  the vision mask are what keep an organ from lighting the corridor behind its wall: a surface the
  player cannot see is sunk to the fog colour whatever lit it.
- **No cached list.** `update()` walks the area's objects itself, so an organ grown under the player
  lights up on the frame it appears with no refresh hook, and a destroyed one fades because it stops
  being found. Fixed-pool discipline otherwise exactly as `LampLights`: nearest-N claim, fade never
  blink, `.visible` never touched.

**Specular: a `roughness` FACTOR, and the MR maps were read before guessing.** Measured green channel
p05..p95 across the four: **0.71-0.94** — uniformly matte, so nothing on them could catch a highlight
from an analytic light, which is why they read as dead putty. Blue (metalness) ~0 on all four except the
preservator's 0.14, so they were correctly dielectric and only the LEVEL was wrong. glTF multiplies
`roughnessFactor` by the map, so scaling it keeps the map's own variation (crystal glossier than slime)
and only moves the level: **0.35 / 0.45 / 0.35 / 0.30**.

That is the second road to the black frame above, and it was checked rather than assumed. GGX
`D = a2 / (PI * d^2)` with `a2 = roughness^4` blows up as roughness falls, and three's own 0.0525 clamp
peaks past the half-float ceiling at grazing incidence. Measured peak linear value in the post buffer
across four screen zones: **4.58** against 65504, i.e. **~14,000x of headroom**, 0 NaN and 0 Inf. So 0.3
is safe with margin and the "do not go far below 0.3" note in `models.json` is conservative, not
borderline.

**+20% on all four**: 2.4 → **2.88**, 2.2 → **2.64**, 2.6 → **3.12**, 1.8 → **2.16**, read back off the
live `instanceMatrix` scale as exactly those. The exit ladder stays 4.0 — it is a tuned full-cell prop,
not part of this. The light height is `h * PROP_LIGHT.yMul` and not an absolute, so it moved with them
(measured y = 3.31 / 3.04 / 3.59 / 2.48 = h x 1.15); it sits just ABOVE the crown on purpose, since a
light inside the prop reaches only backfaces and would leave the organ itself dark.

`three.PointLight` was missing `color` and `distance` — added typed to the extern rather than reached
around with `untyped`.

**Cost NOT measured.** Draw calls are unchanged (a light costs none) but the window would not take focus
and the HUD read 1 FPS, so no GPU number here is worth anything. The per-slot cost is *inferred* from
the street spotlight pool's measured ~0.32ms per light — three unrolls the point-light loop into every
lit material the same way — which is why `pool` is 4 and sized for one room, and why the pool is built
into the tunnel scene alone.

**Verdict: landed, art values open.** With four differently-coloured lights inside 3 cells every organ
is also lit by its neighbours', so the props read oily-iridescent rather than wet; the dials are
`PROP_LIGHT.distCells` (isolate each colour) and per-prop `roughness` (raise toward 0.5-0.6 to calm the
sheen).

## Prop-backed objects had NO shadow at all, and the guard that did it was my own guess

Reported as "habitat objects should throw shadows", and the cause was a comment I had written one entry
earlier: `LampShadows` skipped any object with a glb, on the reasoning that *"an object drawn as a real
3D prop already casts a REAL shadow map shadow, so a painted silhouette on top of it is a second
shadow"*. The first half is true — `Models.instanced` flags the SOLID batch `castShadow` and
`SewerGeom` builds the floor with `receiveShadow` — and the conclusion was still wrong.

**Underground the only casting lights are the pooled spotlights**, and `LAMP_LIGHT.angle` is a
36-degree half-cone from `CELL * yMul` = 5.6 up: a pool about two cells across. Ambient 3.95 and
hemisphere 1.89 carry most of the tunnel's light and neither casts anything. So a prop standing in a
lamp's pool casts, and a prop standing anywhere else — which in a 5x5 habitat room is nearly all of
them — cast nothing at all, having also been cut out of the fake pass. The guard removed; the
silhouette comes from the atlas cell via `Sprites.shadowContent`, which `iconOff` never touched, so an
object whose icon is suppressed still has one to project. Confirmed live: the exit ladder now throws a
shadow it did not have before.

Worth knowing: the ladder is the one prop that reliably DOES stand in its own lamp cone, so it is also
the one that can now show both shadows at once. If that reads wrong the fix is a per-row opt-out in
`ObjModels.MODELS`, not putting the blanket guard back.

**The assimilation arch stopped spinning.** `faceWall:Bool` could only say wall-or-hashed, so it became
`enum PropYaw { WALL; HASHED; FRONTAL; }` and the arch takes FRONTAL — a plain yaw 0, since the tunnel
camera rests looking down -Z with no yaw of its own and every one of these props was generated from a
front-on reference. It is a doorway with the orifice in one leg, and a hashed turn showed it edge-on as
often as not. FIXED and not camera-TRACKING, the same call the frontal FX quads make: a solid prop that
swung with an orbiting camera would swim against its own shadow and the floor it stands on. Verified
off the live `instanceMatrix`: both arch instances decompose to **yaw 0.0**, every other prop keeps its
hashed spread (67.7 / 20.1 / 18.3 / -21.9 degrees on the biomineral).

Its glb then turned out to be authored broadside, so an unturned placement showed the arch edge-on.
Corrected with a 90-degree entry in **`Models.yawFix`**, which bakes the turn into the verts at load —
the same mechanism street-lamp2's 90-degrees-off arm already used. That is the right home for it
because it is a fact about the MODEL, not about how a prop is posed: every placement rule inherits it,
hashed ones included, and `normalize()` measures the box after the turn so the height scaling is
unaffected. Measured after: the arch's world extents are **5.32 x 2.64 x 2.43** — its long axis now
runs across screen X (face-on) where it ran along Z (pointing away from the camera) before.

**The coloured point lights are off for now** — `PROP_LIGHT.pool: 0`, which builds none, so
`NUM_POINT_LIGHTS` drops back to the flame pool's 5 and the point-light block leaves the tunnel shaders
entirely (verified: 5 lights, all idle flame, `prog` unchanged at 85). Author call while the organs'
lighting is worked case by case. Nothing else was reverted: the table rows keep their colours, so it is
that one number to turn back on, and `PropLights.update` early-outs on an empty pool so the per-frame
object walk goes with it.

**Verdict: landed.**

## The assimilation arch is regenerated, and its 90-degree yawFix comes back out

> Corrects the "authored broadside" paragraph of the entry above, which is wrong as written.

The arch was replaced with a fresh generation (the previous one carried too much detail) and
`models.json` repointed at it: **4,970 tris**, `tris: -1`, `tex: 512` = 52 texels/tri, in band with the
other three organs. A `texSrc` now points at the atlas dumped back out of the glb, so the base colour
is repaintable in Krita without regenerating anything.

**`make model-export` was naming its dumps off the LABEL, not the source.** A label's folder and its
source's folder are independent — `habitat/assimilation` lives at `habitat/flat/assimilation.glb` — so
the export landed a folder away from the mesh it came from. Named off `e.src` now. Every other prop was
unaffected because their two paths happened to match.

**The 90-degree `Models.yawFix` entry is removed, and the measurement says it never belonged.** Raw
AABB of the new glb: **X 0.977 / Y 0.724 / Z 0.470, X/Z 2.08** — broad across X, thin in Z, i.e. the
arch already spans left-to-right, which is face-on to a camera resting down -Z. The previous model
measures the same way (**2.27**), so the earlier claim that the glb was authored broadside was wrong
about which axis, and the fix it justified was turning a face-on prop edge-on. `FRONTAL`'s plain 0 was
correct from the start. `Models.yawFix` is back to its one-line street-lamp2 form.

**Emissive was tried twice more and removed both times.** A derived map keyed off the new atlas at a
pale, unsaturated tint (`lit 4.6% of atlas`, `emissiveStrength 1.5`) read no better than the saturated
violet one before it. Back to `emissiveStrength: 0`, which skips the map entirely. Worth recording that
a regenerated mesh **invalidates its emissive map outright** — the map is keyed to the atlas, and a new
generation has entirely different UVs, so the old one lights random patches.

**Verdict: landed.**

## The organs start MOVING: a sway on the geometry, a ripple on the normal alone

Three attempts to make an organ read as alive had all been reverted (a derived emissive map twice, a
coloured point light) because each *lit* the prop instead of moving it. So animate it:
`render/world/PropShader.hx` folds two terms into the materials the props already draw with, gated by
an `anim` column on `ObjModels.MODELS` beside `h`/`yaw`/`light`; a null row is never patched. Zero draw
calls, zero passes, zero geometry. **SWAY** displaces `transformed.xz` weighted
`pow(clamp((y-base)/span,0,1), bend)` so the feet stay planted — the half that reads with no light,
because it moves the silhouette. **SHEEN** perturbs `objectNormal` only, for a highlight to crawl on.

- **Per-instance phase off `instanceMatrix[3].xz`, never `gl_InstanceID`.** `Models.cull` repacks
  survivors into the front of the buffer every frame, so a prop's index changes with the camera and an
  index-keyed phase jitters. Free, no extra attribute, and puts two organs of a kind out of phase.
- **Authored values are fractions of the prop's height**, converted at patch time off the geometry's
  bounding box (the `SewerProp.margin` -> `r` lesson: `Models.instanced` scales by height alone). Live:
  `span 0.724` local, `amp 0.0145` local = **0.053 world** at instance scale 3.646.
- **The two anchors cannot share a local.** Tilt at `<beginnormal_vertex>` (so `<defaultnormal_vertex>`
  carries it to view space free), displacement at `<begin_vertex>` before `<project_vertex>` (so
  `SewerMask` samples the moved position). The phase is recomputed at each: for an unlit material three
  wraps `<beginnormal_vertex>` in `#if defined( USE_ENVMAP ) || defined( USE_SKINNING )`. The hull is
  `MeshBasicMaterial` and takes the displacement ONLY — but must take it, or the outline detaches.
- **Two chained patches re-wrapped each other every frame.** The "already patched" mark can only be
  read on the OUTERMOST hook and each patch replaces it, so mask and anim each read the other's mark as
  absent. Measured: cache key `sewerMaskspropAnimL` **x21**, `progs` **95 -> 129 in four seconds**.
  Fixed by copying the wrapped hook's own fields onto the new one, in BOTH files.
- **...and recomputing the phase redeclared the locals: both anchors are inside `main()`.**
  `ERROR: 0:587: 'propPh' : redefinition`. **An invalid program is invisible, not black** — three logs
  once, spams `useProgram: program not valid` **x255**, mutes the context, and the prop is still
  submitted every frame rasterizing nothing. Braced each block.
- **That took half an hour from the wrong end and the console had it immediately.** Measured 60
  `renderBufferDirect`/s, `visible` true, projection validated against the ladder, forced `emissive`
  white AND `depthTest` false, sampled the mask canvas (`sewerVis` **1.000**). All five said "submitted,
  no fragments" — which IS the signature. `list_console_messages` FIRST, not last.

Verified: **0 console errors**, `prog` 88, and two frames a half-cycle apart (2.36s at `rate` 0.2) over
a 220px box per arch — **873 px changed >4 / max 51** and **1482 px / max 107** — against a wall control
of **0 px, max 1**. GPU cost **not measured**. The sheen stays faint until a prop light is back on:
`PROP_LIGHT.pool` is 0, so an organ away from a bracket has only the hemisphere term (1.89 vs ambient
3.95), where a ~5 degree tilt is a **~1.4% luminance swing**.

**Verdict: landed, art values open.**

## The organs get insides: a writhing core sprite and orbiting fireflies

`render/actors/PropFX.hx` + `core`/`fly` columns on `ObjModels.MODELS`, assimilation only. New sprites
`fx/innards`, `fx/firefly`. Core = one upright additive quad in the arch's opening, CPU scale-breath
plus a FRAGMENT-shader uv disturbance; fly = one mote circling parallel to the floor with a fading
tail, HDR-tinted so the existing bloom pass is its halo. Both columns are fractions of the row's `h`
(the arch's art is **1.35 h wide, 1 h tall, 0.65 h deep**), so a later 1.3x resize moved the quads free.

- **`transparent` + `DoubleSide` = TWO draw calls per quad.** three renders it FrontSide then BackSide,
  each its own call AND program. A/B on 16 quads: **104/72/104 = +32**, double the inventory. The split
  only orders the two faces, and additive is commutative — `forceSinglePass: true` gives **88/72/88 =
  +16**, and `propCore` programs 6 -> 3.
- **Not on `Sparks`' pool**, though `glowQuad` draws exactly the firefly. Its slots are reused by
  arbitrary callers each frame, so a per-slot shader patch leaks into whoever draws there next; it
  resets map/colour/opacity but has no uniform reset. Both entry points are at 7 positional args too.
- **Proving a fragment patch is live.** A failed `StringTools.replace` is silent — uniforms bind, the
  sprite draws, nothing warps. Frame-diffing cannot settle it (sputtering lamps moved a "static" wall
  control by 3,135 px, and the sway moves the same box). `warp: 2.0` drives every tap past
  `ClampToEdgeWrapping` and **all four membranes vanish**. That clamp is load-bearing: under
  `RepeatWrapping` a disturbed uv wraps to the opposite edge and smears the sprite over itself.
- **`IMP_ASSIMILATION` caps at level 1**, so "one firefly per level" meant one dot forever (biomineral
  3, preservator 3, watcher 2). Hence `perLevel` on the row.
- **A shared ring at one radius is a formation, not a swarm** — evenly spaced dots on a tilted circle
  read as a triangle turning. Flat ring instead, each dot rolling its own radius/height/speed/tilt from
  `fract(sin)` keyed on cell phase + index, plus radius breath, vertical wander and twinkle. Derived,
  so still no state per firefly.
- **A fading tail wants no history buffer.** The orbit is a closed form in the clock, so segment `j` is
  the same path at `t - j*gap` — exact, allocation-free, right on the frame a prop appears, and right
  at 1 FPS, where a per-frame history samples the arc ten times too coarsely.
- **Upright costs 1.57x of apparent size and no `size` buys it back**: the quad's normal sits 19 deg
  off the view leaned and 53 deg upright, projecting 0.95 vs **0.60**, and the arch caps `size`. So
  brightness is the only lever (`alpha` 0.5 -> 0.72). Depth is capped the same way — `z: 0` already
  puts the braids in front, and moving further back costs `dz*tan(53)` of `y` to stay put, 1.3x the
  move, through the floor.

Cost, 60 FPS foregrounded: **+16 calls** (94/78), `submit` **+0.15..0.30ms**. GPU sits inside the
noise — 15 interleaved pairs median **5.88/5.43**, but the spread is **4.6-7.1 on both sides** and a
5-pair sweep came out *inverted*, so call it <=~0.5ms of a 16.6ms frame that already idles 14.2ms.
`progs` **92 -> 92** across habitat entry (the boot warm covers both materials); 0 console errors.

**Verdict: landed, art values open.**

## The biomineral glows on its own SKIN: motes travelling the crystal, keyed off its albedo

`render/world/PropGlow.hx` + a `shine` column on `ObjModels.MODELS`, biomineral only. Two fragment
terms on the prop's existing material — **0 draw calls, 0 passes, 0 geometry, 0 art**. Mask = the
prop's own baked albedo keyed on greenness; motes = 8 loci on slow helices through the local bounding
box, each lighting the surface nearest it. Anchor is `<emissivemap_fragment>`, the one place
`totalEmissiveRadiance` is live AND `diffuseColor` is still in scope, so one injection gets both the
additive slot and the mask.

- **Nothing here can be keyed on uv.** The atlas is a shattered mosaic (biomineral **2.41x** split),
  so a mote walking uv space teleports across the model. Local `position` is continuous by
  construction. A hand-painted emissive map is worse still: `biomineral-emissive.png` predates the
  Aug-21 re-bake and its uvs are dead, the case already recorded above.
- **The mask band must be measured in LINEAR, and per-TRIANGLE.** Reading it off sRGB bytes gave
  "mineral 2.3 vs body 0.87" and both bands built from that were wrong. Area-weighted over triangle
  uv centroids the real ratio is body p50 **0.64** / p70 **0.90**, mineral p75 **1.36** / p95 **1.67**
  — so `[0.95, 1.35]` leaves 23.4% fully lit, 72.5% fully dark, **4.1% ramping**, and that 4.1% is
  the actual crystal/flesh boundary. Whole-atlas percentiles mislead: most of a 512 map is gutter.
- **The bug that cost the most: `fract( sin( n ) * 43758.5453 ) amplifies its input's error by
  43758.`** `vGlowPh` carried raw world coordinates (~50), a varying interpolates at ~24-bit, so it
  arrived with ~3e-6 of per-fragment error — **~13% of random jitter on every pixel**, seen as dense
  green speckle over the whole prop. Hash the instance translation in the VERTEX shader and hand the
  fragment a bounded 0..1 phase: same error becomes ~3e-8, amplified ~1e-3, speckle gone.
- **It was misdiagnosed twice first, and both were plausible.** (1) the mask band — widening it made
  it strictly worse, which should have been the tell. (2) the art's own grain: the mineral texels do
  measure sd **22.8** on mean luma 93.5 with 5.4% of neighbours jumping >12, so the story fit — but
  the `PROP_GLOW.enabled = false` build brightened 4x shows a **perfectly smooth** crystal. Building
  the off-switch A/B settled in one shot what two rounds of reasoning could not.
- **Emissive is added in LINEAR onto an albedo of ~0.03**, so the floor is small: `base` 0.10 put a
  flat 0.41 green over the mask and the prop read as one solid blob with the motes invisible inside
  it. 0.015 is a mineral that luminesces. Green is the cheap channel to bloom with — linear luminance
  weighs it **0.7152** — so `glow` 2.8 puts a mote peak at 1.09 against `BLOOM_THRESHOLD` 0.9 while
  the resting base (0.11) stays far under, i.e. only the motes halo.
- **Mote count is per ROW, never per level.** A per-instance count needs an attribute beside
  `instanceMatrix`, and `Models.cull` repacks that matrix alone every frame — the two would desync
  the moment the camera moved. The count is a LITERAL loop bound and rides the cache key
  (`sewerMaskspropGlow8`), so changing it compiles its own program, which is correct.
- **A per-facet shimmer was the third term, and it is REMOVED.** Object space quantised into cells,
  each swelling on its own beat, meant as a floor so the crystal was not dead between motes. It read
  as flat rectangular patches: a cube lattice has no relation to where the mesh's own facets are, and
  every amplitude big enough to see was big enough to show the lattice. Sizing did not save it —
  0.14 of height was smaller than a blade and read as noise, 0.22 read as boxes. **Author call: out.**
  What it was covering was real: at 8 half-size motes, whole seconds passed with every one of them
  round the back — `hotPx` **26 / 6 / 0** over three captures. Fixed properly by the arc below.
- **The motes never orbit the far side: the sweep is anchored ON THE CAMERA.** `front` is a half-arc
  and the angle ping-pongs through `camAng +/- front * sin(phase)` instead of completing a lap, so a
  mote eases, reverses at the silhouette and comes back. `front = PI` degrades to a full sweep, so
  the option is kept at no cost. The anchor cannot be a uniform — `yaw` is HASHED per placement, so
  local +Z points somewhere different for every biomineral — it is `atan2` of the camera in the
  instance's own frame, computed per vertex from `modelMatrix * instanceMatrix` and passed as a
  varying. Two traps: **`atan2( x, z )` is the natural spelling and it is 90 degrees WRONG** (the
  mote sits at `( cos, y, sin )`, so the angle pointing at the camera is `atan2( z, x )`) — it put
  the whole sweep on the flank and the far side; and the mat3 transpose is written out as two dots
  because three compiles built-in materials as **GLSL ES 1.00 even on WebGL2**, where `transpose()`
  does not exist. A 2*PI jump as the camera crosses local -Z is invisible: the angle only reaches the
  world through cos/sin.
- **The climb bell wants `sqrt( sin )`, not `sin`.** A plain bell leaves a mote under half brightness
  for half its climb, so with 8 of them several are always washed out and the prop still read
  near-empty (`hotPx` 28 / 1 / 5 with the arc alone). sqrt still reaches 0 at both ends — a floor
  would pop at the wrap — but reaches full in a fifth of the climb. And it needs `max( 0.0, ... )`:
  `sin` can return a hair below zero at the ends, `sqrt` of that is NaN, and **one NaN texel goes
  through the bloom downsample and blacks out the entire frame**, which this log already has an
  entry for. After both: `hotPx` **42 / 24 / 39 / 11** over four captures, never zero.
- **The chain is one round deep and stays that way**: marks `["sewerMask","propGlow"]`, key
  `sewerMaskspropGlow4`. The hull is skipped outright (`MeshBasicMaterial` has no
  `totalEmissiveRadiance`, and an outline marker must not glow); the ghost is patched, so the glow
  survives standing on the prop. LOS comes free — SewerMask injects after `<fog_fragment>`, i.e.
  downstream of the emissive, so an unseen crystal sinks to fog colour like everything else.

Cost, 60 FPS foregrounded, 70 samples per leg, A/B/A: GPU median **5.31 / 5.56 / 5.34** — the OFF leg
is the *highest* of the three, so the delta is inside the noise (range 3.1-8.9 throughout). `calls`
**88-90 on both**, `submit` 2.10/1.70/1.89 (noise), `progs` **92 -> 94** (+2: the solid and ghost
permutations, both boot-warmed). Motion verified by frame diff: hottest green pixel walks
816,382 -> 819,356 -> 791,347, **3.7-4.8k px changed >4** per pair in the crystal box against a wall
control of **0 px, max 1**. 0 shader errors.

**Verdict: landed, art values open.**

## The biomineral gets a real light, and LIGHTNING — fireflies were tried there first and cut

Two separate things on top of the surface glow above, both existing seams rather than new code: the
`fly` column that already drives the arch's mote, and `PROP_LIGHT.pool`, which had been sitting at 0
since the organs' lighting was pulled.

- **`pool` 0 -> 2, and only ONE row declares a `light`.** `PropLights` keys on `m.light != null`, so
  the other three organs' rows went `light: null` with their old colours kept in the comment — an
  edit to that row gives one its light back, not an edit to the pool. 2 rather than 1 because a
  habitat holds SEVERAL biominerals (`Habitat.update` sums energy over every formation), so 1 would
  light the nearest and leave its neighbour dark.
- **`NUM_POINT_LIGHTS` 5 -> 7 and `progs` did NOT move: 94 either side.** That is the payoff of
  `PropLights` being built in `SewerScene.build` rather than `SewerArea.build` — `View.warmup` builds
  its warm tunnel scene by calling that same function, so warm and real agree and no lit tunnel
  material recompiles on habitat entry. Recorded because it was predicted and it held.
- **The light is PALE green (`0x8fe3b0`), not the crystal's saturated `0x33bf59`.** A point light
  washes every surface it reaches; at full saturation it tints the masonry and floor green instead of
  reading as light coming off a green thing. The surface glow keeps the saturated tint.
- **Its cost is not resolvable on this machine.** `pool` 2 vs 0, 70 samples each: GPU median
  **5.80 vs 5.97** — the OFF leg higher again. The street pool's ~0.32ms/light predicts +0.64ms and
  that is the number to quote; it does not separate from a 2.5-13.4ms spread.
**Fireflies were the first answer and are REVERTED** — right vocabulary for the arch, wrong organ.
This one makes POWER, so it discharges. Worth keeping from that pass, because it is measured:
**every pooled quad is a draw call**, so `trail` multiplies a swarm by `trail + 1` — 21 dots took
`calls` **88-90 -> 109-111**, exactly +21, and 9 dots -> 97. The two `PropFly` fields it grew
(`front`, `weave`) went with it: only the arch uses that column now and it wants neither, so they
were dead generality on a typedef every row has to fill.

### The lightning

New `arc` column + `PropArc`, drawn by `PropFX` as **ONE mesh and ONE draw call for every bolt on
every prop in the level** — a ribbon rebuilt from scratch each frame, the `SlimeTrail` idiom. A quad
per segment would have been 30 calls for six 5-segment bolts. Nothing is stored per bolt: a slot's
life is derived from which TIME BUCKET the clock is in, so the bucket index seeds where it strikes
and the position inside the bucket is its age (`BLOOD`'s black-blood glints already work this way).
`vertexColors` carries both the fade along a bolt and its decay, so there is no map, no per-bolt
uniform and no opacity write — under additive blending a vertex colour of 0 adds nothing.

**Placement took four passes and every failure was the same mistake seen from a different angle.**

1. **Direction radially from the prop's centre** aimed every high strike at the ceiling — bolts hung
   in the air well above a crystal that had already narrowed to a point.
2. **Building the ribbon on the leaned `Sprites.TILT` plane** put every bolt above the body: the
   camera looks down ~53 degrees, so leaning a point back moves it AWAY as well as down and moving
   away raises it on screen by `dz*sin(53)` — the two stack. Upright is what the arch's core quad
   already chose (`lean: 0`) for the same reason: a flat shape hung on real vertical geometry must
   stay coplanar with it.
3. **Upright at the prop's own depth** then buried them — the body's near half swallowed the lot.
4. **Pushing the plane forward** to escape that laid them over the crystal's face like veins, and
   clawing the screen drop back costs `dz*tan(53)` = 1.3x the move in `y`, which puts every bolt at
   the crown. The same bind the core quad hit.

**The fix was none of those knobs: strike from the BODY'S OWN SURFACE.** A strike point anywhere
inside the silhouette puts the first half of the bolt behind the body, and that is what all four
passes were really fighting. Origin on the surface (`r` narrowed by the prop's own taper at that
height, the profile the surface motes' helix already uses) and direction straight out from there
means the bolt cannot re-enter the body whatever the swing — which also makes the whole screen-drop
problem disappear, since nothing has to be pushed toward the camera to stay visible.

**And then the plane itself had to go.** Confined to one upright plane a bolt can travel left, right
and up — never toward the camera, which is a third of the directions a discharge should have. The
path is now built in WORLD 3D: a strike azimuth about the prop's vertical axis (`az`, a half-range
centred on world +Z so bolts fan forward and across both flanks but not round the hidden back),
swung up or down by `spread`. Two things that fall out of it:

- **the ribbon has to billboard now.** A flat shape whose plane contains the view direction is
  invisible edge-on, so the width axis is `normalize(cross(bolt, view))` — perpendicular to both.
  One axis serves the kink as well, which keeps the zigzag facing the camera too. The view direction
  is a fixed constant, and that is honest rather than lazy: it is used ONLY to face the ribbon and
  never to place it, the whole sprite layer already assumes this camera, and a bolt lives 0.27s.
- **that cross product has a real degeneracy** — a bolt aimed exactly along the view has no width
  axis, and normalizing a zero vector is NaN. Not cosmetic: one NaN texel goes through the bloom
  downsample and blacks out the entire frame, which this log already carries an entry for. Guarded
  with an arbitrary fallback axis, which is correct because such a bolt is a point on screen anyway.

The now-meaningless `z` column was deleted rather than left at 0. Measured after: bolts span
x 662-841 and y 464-577 around a body whose silhouette is ~780-820, i.e. both flanks and clearly
forward, at 89 calls.

Also: the kink bells to 0 at the ROOT only (`sqrt(f)`, not `sin(PI*f)`) — belling both ends pulls the
tip back to the centreline and the bolt reads as a smooth worm rather than something that snapped.

**The bolt was in the bloom path and getting nothing out of it, and only a measurement showed that.**
It is HDR by construction (`0x8cff9e` linear luma 0.80 x `glow` 3.2 = 2.55 against `BLOOM_THRESHOLD`
0.9), so "is it blooming?" reads as obviously yes. Perpendicular p95-by-radius profiles say otherwise:

| source | d=0 | 1 | 2 | 4 | 6 | 8 | 10 |
|---|---|---|---|---|---|---|---|
| wall lamp (known HDR glow) | 245 | 183 | 111 | 72 | 50 | 41 | 31 |
| bolt, shipped width, clear of the crystal | 230 | 32 | 32 | 33 | — | — | — |
| the SAME bolt at `width` 0.15 (probe) | 248 | 248 | 249 | 249 | 250 | 241 | 161 -> 91 by d=18 |

**Bloom output scales with the AREA of over-threshold pixels**, and at `BLOOM_STRENGTH` 0.25 /
`BLOOM_RADIUS` 0.1 a ~5px thread contributes too little to see. Intensity is not a substitute: at
`glow` 12 the core read the same 230 (ACES saturates it) and still had no skirt.

So a bolt is now TWO ribbons down the same path — a wide soft halo (`halo` x width, `haloDim` x
brightness) and the hot core over it. Same mesh, same draw call, only vertices. Two traps in it:
the halo must carry a real cross-section GRADIENT or it is a fat glowing plank, so the emitter went
to **three vertices per station** (left edge / centreline / right edge, 4 tris per segment) with the
core pass setting edge = centre and the halo pass setting edge = 0; and the kink hash is keyed on the
bucket and slot but NOT on the pass, or the halo would run down a different zigzag than the core.
That emitter needed 17 positional args and became `render/actors/BoltOpts.hx` under the typedef rule.
After: **242 -> 181 -> 126 -> 124 -> 69 -> 56 -> 50** out to d=18 against a background of 28.

Two false leads worth naming. A whole-box profile DID show a wide skirt on the un-flared bolt — that
was the crystal's own emissive and its point light bleeding into the radius bins, and only restricting
to a bolt segment outside the silhouette gave a clean answer. And the wall-lamp control is nearly
worthless alone, because a lamp's softness could just as easily be its painted `makeRectGlowGradient`;
the wide-ribbon probe is what actually settles it.

Cost: `calls` median **85-90** across poses — the pre-firefly baseline, i.e. the lightning is **0-1
calls** and 0 while nothing is striking, flare included (it is vertices on the same ribbon). `submit`
1.79-1.90, `frame` pinned at **16.69ms** with **14.1ms idle**, 60 FPS, 0 shader errors. `progs`
**94 -> 97** at boot; sampled 40x over 6s of firing it holds at 97 with **no growth**, so the warm
covers the strike path and nothing compiles on first discharge. Which three permutations the +3 is
was not isolated.

**The GPU timer went unusable partway through and its numbers are NOT quoted.** Early samples read
median 5.69 (2.4-8.1); later ones on the same scene read median 11.02 with quartiles **5.46 / 11.02 /
15.85** — while `frame` held 16.69 and `idle` 14.1, which 11ms of GPU work cannot coexist with. That
is the documented iGPU power-state drift, and with no simultaneous A/B there is no share to extract
from it. `calls` and `idle` are the honest numbers here.

**Verdict: landed, art values open.**

## The preservator BREATHES: a swell + twist above a floor line, and an amber glow inside the pod

The third organ. Its mesh was regenerated first — an amber pod caged in purple veins, splayed into a
flat root pool — and two things about that source had to be measured before any shader work.

**`tris: 1200` silently crushed it to 1,199.** That target was written for a 65,726-vert 100k master
where the seam network floored meshopt at 5,452. The new source arrives AT the budget (4,871 tris,
3,435 verts over 2,438 positions = **1.41×**), so meshopt really did reach 1200 — a third of what
the other three habitat props ship at, sanding off the vein lattice that is the whole read. `tris:
-1`, the watcher's and crates' case. 4,871 at `tex: 512` = 54 texels/tri, in the 43-55 band.

**`h` 4.06 → 3.6.** The bbox is 1.36 h wide and 1.29 h *deep*, nearly all of it the pool, so height
is a poor proxy for how much cell a prop eats: 4.06 would have laid a 5.5-unit pool over a 4-unit
cell. 3.6 puts it at ~4.9, the width the arch already overhangs to.

**The radius profile is what the row is fitted to**, in units of its own height: 0.51 at the pool →
a **waist of 0.29 at h 0.22** where the splay ends → 0.33 by h 0.43 → 0.05 at the crown. That waist
is `pulse.floor`, and it is the one line where a discontinuity in the weight is invisible, because
the silhouette already turns a corner there.

New `pulse` column + `PropPulse`, folded into `PropShader`'s existing patch (one hook, one key). Two
terms, both gated by `smoothstep(floor, floor+soft, h)` so the roots never move: a radial **SCALE**
about the prop's own axis — a scale and not an offset, so the displacement is proportional to how
far out a vertex already is, which is both what an inflating body does and what keeps the field
continuous under any weight — and a **TWIST** about the same axis. The twist is what actually reads
as "swirl": on a body of revolution a lateral sway only leans the thing, while a turn slides its
whole painted surface around itself. It takes the instance phase ONLY, never the sway's `strand`
term — a breath whose phase varies per vertex is not a breath, it is a shear.

The ask was "swirl the purple parts". **A vertex displacement must not be masked by albedo here**: a
TRELLIS atlas cuts its charts along high-curvature ridges, which is exactly where the veins are, so a
purple/amber mask boundary lands on a UV seam and pulls duplicated vertices apart. The cage is the
only high-contrast detail on the pod, so an unmasked body swell reads as the cage writhing anyway.

The glow reuses `PropGlow` with two additions: a `PropKey` enum picking the mask ratio, and `yLo` so
the mote climb starts above the root pool (a third of a 3-mote budget otherwise lights nothing). The
key is **`g / b`** and blue alone is the discriminator — measured per triangle, area-weighted, in
linear: pod and cage carry nearly the same red and green and differ **6.7× in blue**. `min(r,g)/b`
is byte-identical on this atlas (g never exceeds r), so that fallback is dead. Modes: cage **0.5**,
pool brown **1.3**, amber **2.5-3.8** → band `[1.9, 2.7]`, 23.1% of surface lit and spread all round
the body (9-40% per 30° of azimuth), so `yaw: HASHED` stays.

**The trap: `moteR` 0.20 was too big and it did not look like "too big".** At that reach one mote
covers the entire amber face, so three of them add to a flat uniform gold panel and the pod's own
painted shading vanishes under it — it reads as a lit surface, not as something lit from inside.
0.13 (4× the biomineral's radius, ~15× its area) is a discrete blob rising inside a shell. **An
effect has to be SMALLER than the region it travels or there is nothing to see it travel against.**
The band is deliberately soft here (~20% of the surface ramping, against the biomineral's 4%): a
hard crystal-against-flesh edge was right there and is wrong here, because a soft mask IS the
gradient of light leaking through a shell.

`glow: 1.0` is not a placeholder. Every other glowing thing in this game sets it past 1 to clear
`BLOOM_THRESHOLD` 0.9; this is the one that must NOT, so the level lives entirely in `base` (0.055,
~52 sRGB of emissive over every amber texel) and `mote` (0.38). **`base` is the dominant term on
this prop and `mote` is not** — the mask covers the whole pod while three motes cover a fifth of it,
so "brighter overall" is `base`, and `mote` has to be raised with it or the travelling blob stops
reading against the floor it crosses. Peak total 0.435 → linear luminance 0.285, still well under
the threshold. The cost of a high `base` is relative contrast: it is an additive constant over an
albedo whose own variation is smaller than it, so the pod's painted internal shading flattens as it
rises. That is the dial to turn if the amber ever looks like a panel again.

**Every one of those three numbers was retuned once, and the reason is the entry below**: they were
first set against a pod that was rendering almost black, because the regenerated mesh arrived with a
metallic MR map. An emissive term is judged as a RATIO to the lit surface under it, so fixing the
material moved the target by about the amount the material had been swallowing.

Cost, A/B on the same pinned free-cam pose, same protocol both legs (fresh reload → one spawn →
pin): `calls` **57 / 57**, i.e. **zero draw-call delta**, which is the whole point of doing this in
shaders that were already running. `progs` **99 on / 91 off** — the 8 prop permutations, all present
after boot warm and none compiling on habitat entry. Program keys came out exactly as designed:
`propAnimSUL` on solid and ghost, `propAnimSUP` on the unlit tactical hull (so the outline swells
with the body), `propGlow3AMBER`, and the biomineral untouched at `propGlow8GREEN` / `propAnimSL`.
0 console errors. 60 FPS, `frame` 16.6ms, `idle` 14.8.

Motion verified against the geometry alone, with emissive killed (key `6`) so the glow could not be
mistaken for it: two frames 5.2s apart (half a ~11s breath) put the top diff-energy tile squarely on
the pod, and the apex rises ~6% of the prop's height between them.

**Verdict: landed, art values open.**

## The preservator shipped ALMOST BLACK: its regenerated MR map came back metallic

Reported as "something really wrong with texture — almost completely dark, with a little bit of
specular", which is the exact signature and not a vague complaint. A metal has **no diffuse term**;
its base colour becomes F0, the specular tint. Underground there is no env map, so with only weak
analytic light there is nothing left to shade and the prop renders near-black with a tight highlight.

Read the MR map, do not guess. glTF packs **G = roughness, B = metalness**, so one dump settles it:

| prop | MR blue (metalness) | verdict |
|---|---|---|
| **preservator** | mean 211, p05 **190**, p50 213, p95 229 | **~0.83 metal over the whole prop** |
| assimilation | 44.7 | 0.18, mild |
| watcher | 3.5 | dielectric |
| biomineral | 0.0 | dielectric |

`metallicFactor` was 1 and glTF MULTIPLIES it by the map, so the effective metalness really was 0.83.
The 2048² **source** carries it too (metalness 210), so this came out of TRELLIS — not the bake.
Base colour was never the problem: mean sRGB 83/50/45 (avg 59), in line with the prop family.

Fix is one line, `"dropMR": true` — `sewer-pile-2`'s case exactly. `models.mjs` drops the texture,
sets `metallicFactor` 0 and `roughnessFactor` 1, and the entry's own `roughness: 0.35` then re-applies
after it, landing effective roughness at 0.35 — which is where the family already sits (biomineral
0.986 × 0.35 = 0.345, watcher 0.84 × 0.3 = 0.25, assimilation 0.996 × 0.45 = 0.45). The map's
roughness variation is discarded with it, and that is a feature here: this prop's green channel spans
p05 132 to p95 233, so keeping it would have put 5% of the surface at effective roughness 0.18 —
glossier than any other organ. glb 1123KB → **747KB**, one texture lighter.

**Confirmed live before changing anything, with debug key `M`** (force every lit material matte):
under it the same three pods render exactly as the reference art, amber shells in purple vein cages.
That is what separates "the material is metallic" from "the material is metallic AND that is the
whole story" — and it also cleared the pulse and glow shaders, which were the obvious suspects since
they had just landed on this prop.

**The trap is documentation, not code.** The retired mesh's entry said "MR map pure green, no
dropMR", and that line was carried forward verbatim into the rewritten note for the regenerated one
without re-measuring. It was true of a mesh that no longer existed. TRELLIS is not bit-deterministic
and metalness is a per-generation lottery — `sewer-pile-1` came back green and `sewer-pile-2` cyan
from the same generator on the same day. **Re-read the MR map after every regeneration; a previous
entry's verdict about a prop is a claim about a FILE, not about a subject.**

Knock-on: the glow's `base` / `mote` / `moteR` all had to be retuned upward, because an emissive term
is judged as a ratio to the lit surface under it and a black surface flatters any addition. That is
its own lesson — **tune emissive last, and never on a prop whose material is still in question.**

**Verdict: landed.**

## The preservator's glow had to CROSS the bloom threshold, not sit under it

The pod shipped with `shine.glow: 1.0`, chosen deliberately so it would stay "faint and subtle".
Peak emissive was `base 0.055 + mote 0.38 = 0.435` against a tint whose linear luminance is 0.654,
i.e. **0.285 against `BLOOM_THRESHOLD` 0.9**. It could not halo by construction, and the report back
was "I don't see the yellow bloom glow. Is it there?" — which is the correct reading of a
sub-threshold emissive on an already-lit shell: it is a slightly paler shell and nothing more.

**A brightness change that never crosses the threshold is not a glow, it is a shade.** That is the
whole entry. The fix is not "more" but a term that straddles: two new `PropShine` fields, `pulse` /
`pulseRate`, multiplying the whole `glowSum` by `1 - pulse + pulse * (0.5 + 0.5 * sin(t * rate +
vGlowPh * 2pi))`, phased per instance off the hash the motes already carry.

Fitted against luminance 0.654 with `glow 3.0 / base 0.035 / mote 0.85 / pulse 0.6`:

| | breath bottom | breath top | blooms? |
|---|---|---|---|
| resting shell (mask only) | 0.048 | 0.069 | never |
| mote peak | 0.70 | **1.74** | only at the top |

So the three blobs inside the amber swell into a halo, hold it for roughly the upper third of a ~14 s
cycle and lose it again, over a shell that is ~1.9x brighter than before and never haloes at all
(`glow x base` 0.055 -> 0.105). Note `base` went DOWN while the pod got brighter — **read these as
products with `glow`, never on their own.**

Both fields are **uniforms, not literals**, so `customProgramCacheKey` is untouched: verified live,
the key is still `propGlow3AMBER` and `__progs()` holds at 100. A row can retune or disable the
breath with nothing to compile and nothing to add to the boot warm. The biomineral takes `pulse: 0`
— its motes already clip and bloom at every peak, so a breath under them would only take the halo
away and put it back.

**Verdict: landed.**

## The preservator TETHERS its preserved hosts, on the lightning's ribbon

Preserved hosts stand on the four orthogonal cells around the pod with nothing showing what holds
them. A first design moved their sprites onto the crown and was dropped before it was written: the
badge / x-ray / target-ring passes read the *stored* actor pose, not `drawActor`'s offsets, so a
lifted sprite leaves its re-invade ring on the ground behind it. The arc has no such problem — it is
drawn between two world points and touches no pose.

New `tether` column + `PropTether`, and a `drawTethers` in `PropFX` that appends into **the same
buffers the lightning already fills**, so one mesh carries every bolt and every cord in the level.
(As shipped that was a `ribbonStation` / `ribbonQuads` pair factored out of `boltRibbon` inside
`PropFX`, with the buffers renamed `bolt*` -> `ribbon*`. A later entry below moves the lot into
`render.actors.Ribbon`; the sharing is the part that survived.)

Cost is **not** "one call per cord" and **not** zero either, and the honest bound is worth writing
down: the mesh already existed, but it was `visible = false` whenever no bolt happened to be alight
(`duty 0.18`, dark ~30% of the time). A live cord keeps it up, so the true worst case is **+1 draw
call**, in those frames only. Measured live with one host preserved: `calls 72`, `submit 2.6 ms`,
`GPU 4.59 ms`, 60 FPS, `prog 100`.

Two things the bolts do that a cord must not. Its bow and waver are belled to **0 at BOTH ends** — a
cord is attached at each end, where a bolt only has to start on the body — and its brightness is
**flat along the span**, where a discharge fades away from the crystal. A link that dims toward the
far end stops reading as a link.

The flare shipped at `haloDim 0.65` for one build: `0.65 x 2.2 x 0.654 = 0.94`, over the threshold,
and a self-blooming flare 0.3 world wide reads as **a solid glowing tube leaving the pod**, not as
light. At 0.5 (0.72, under) the flare is a soft skirt and only the ~4px core straddles — 1.44 at the
peak, 0.50 at the trough. **On a thin ribbon the flare buys bloom AREA; let it bloom in its own right
and it stops being a flare.**

WHO a cord runs to is `AreaObject.getLinkedAI`, asked of the object every frame — the render layer
never learns what a preservator is, and `Preservator.onAction`'s own capacity loop was deleted in
favour of the same call, so what the player sees and what the game counts cannot drift.

**Verdict: landed.**

## A `+/-` SPREAD is not a variation when the count is ONE

The assimilation arch's firefly flew a flat hoop in the lower half of the prop. Both halves of that
came from the same mistake, and it is a general one: **every per-dot value in `drawFlies` is rolled
from a hash, and `perLevel: 1` on a level-1-capped improvement means those rolls collapse to a single
sample.** A distribution described as "spread" or "variation" then describes nothing — it is one
fixed number per cell, and it can land anywhere in the range.

Two of them bit at once:

- height `f.y 0.55 +/- f.yVar 0.28` = one draw from 0.27..0.83 h, which in this habitat came up low;
- tilt `f.tilt * (h3 * 2 - 1)` with `tilt 0.25` — a **symmetric** spread, so it rolls near zero as
  often as not, and 14 degrees is barely off horizontal even at its extreme.

`tilt` is now a signed MAGNITUDE rather than a spread: `f.tilt * (0.6 + 0.8 * h3) * (h5 < 0.5 ? -1 :
1)`, on a fifth roll for the sign. At `tilt 0.45` every ring leans 15-36 degrees and two of them
still lean opposite ways, so a swarm's circles are not parallel to each other either. `0` is the only
way back to a flat ring, which is the right thing for that to mean.

The row moved to `y 0.80 / yVar 0.10` — ring CENTRE in the upper third, kept tight so the centre
cannot leave it. The height variation is then the **lean**, not the roll: at the top of the tilt band
the dot swings `r * sin(tilt)` = 0.33 h either side of the centre, lapping from ~0.47 h up over the
crown. Measured live half an orbit apart (~2.6 s at `rate 0.18`): the dot moved ~75 px up the screen
and to the opposite side of the arch, sitting above the crown at one end of the lap and inside the
opening at the other.

**A ring that merely sits high is still a hoop. The lean is what puts it in 3D** — which is the exact
opposite of what this function's header used to claim ("a tilted ring was tried first and just looked
like a hoop turning"). That note was written when the arch had a full swarm to read depth from.

**Verdict: landed.**

## The ribbon layer split out of PropFX, on the second kind of strip and not on line count

`PropFX` reached 780 lines. That number is not why. It is **34% comment** (241 comment + 26 blank, so
~513 code) and only 5th largest in `render/` behind `View` 1217, `Actors` 1006, `ObjModels` 854 and
`RenderConfig` 847 — and adding the tethers to it had been *easy*, which is the actual test. What
changed was that a SECOND kind of strip appeared, and the ribbon subsystem turned out to be **236 of
those 513 code lines** with its own mesh, material, buffers, vertex format, upload path and warm
entry. That is a class, and it now is one: `render.actors.Ribbon`.

The two things that made it worth doing:

- **A NaN guard was living in two hand-copies.** `drawArcs` and `drawTethers` carried
  character-identical width-axis blocks — cross product, length, zero-length guard, normalize —
  differing only in variable names. Its failure mode is one NaN texel through the bloom downsample
  blacking out the entire frame, which this log already carries an entry for. **A guard that survives
  on copy discipline is a matter of time**, and a third strip would have been the third copy.
- **The one-mesh invariant became structural.** Sharing three arrays is the whole reason a level's
  every bolt and every cord is one draw call. Between two functions in one file that was a thing to
  remember; as a class it cannot be got wrong unnoticed.

What did NOT move is the PATH — how a bolt zigzags or a cord bows is prop-specific and stayed. That
is why the file landed at 630 rather than the ~430 first estimated: the path generators are ~130 code
lines and they belong where they are. **The duplication and the invariant were the win, not the line
count.**

`BoltOpts` / `TetherOpts` agreed on fourteen fields, comments and all; both now extend a shared
`RibbonPass` and add only `arc`/`bucket`/`slot` and `tether`. A follow-up review then took three more
out of it: `station` was nine all-Float args carrying **three mutually swappable coordinate triples**,
so it reads the width axis off the Ribbon's own fields instead — six args, one triple, and nothing
left that mis-orders without a compile error.

Deliberately not split: the core and the fireflies, 61 code lines between them, sharing a clock the
core material references BY IDENTITY, one per-frame object walk and one hash.

Verified rather than assumed — a refactor that quietly drops a strip looks like nothing at all. Bolts
alone `calls 73`; then the full path driven live (attach, harden grip x6, invade, preserve) to
exercise the tether arm specifically, `calls 76`, `prog 100` and zero console errors both times.

**Verdict: landed. Zero behaviour change.**

## The watcher's new mesh: three of its row's constants were fitted to the mesh it replaced

A regenerated glb is not a drop-in, and this one silently invalidated most of what its `models.json`
entry and its `ObjModels` row said. Measured, retired vs 2026-08-22: tris/verts/unique positions
4,798 vs **4,754 / 4,632 / 2,372 = 1.95x**; bbox in units of height 1.14 x 1 x 0.57 vs **0.87 x 1 x
0.57**; baked albedo mean sRGB 113/78/83 (avg 91) vs **72/42/69 (avg 61)**; best-facing azimuth
60-90 degrees straddling vs **dead-on** (0.0684 against the next bin's 0.0496).

- **`h: 2.81` was fitted to a body 1.14 h wide.** At 0.87 h wide the same number renders 2.45 world
  across against the preservator's 4.9 and the arch's 4.6 — the runt of the four. **3.5.**
- **`baseColor 0.4` was fitted to an atlas at avg 91**, to pull it to the family's 46-52. The new one
  bakes at 61 already, so 0.4 would land it near 40 — under the family, and it would crush the pale
  eye discs the row's own comment calls this prop's whole read. **Dropped.**
- `emissiveSrc` still pointed at a map painted for the retired uvs (now in `Unused/`). Dropped.

**The rule the preservator's regeneration paid for held again, and further than it was written:** it
says re-read the MR map after every generation. It should say re-read EVERY measured constant — the
MR map (0 / 214 / 5, rough dielectric, no `dropMR`) was the one thing here that had NOT changed.

**Verdict: landed.** `h` 3.5, no `baseColor`, no `emissiveSrc`, `yaw: FRONTAL` re-confirmed.

## Reading a BAKED glb's vertices gives garbage: `make models` interleaves, the TRELLIS source does not

Every measurement behind the two entries below is a hand-parse of the glb's BIN chunk. Run against
`app/models/habitat/watcher.glb` it returned eye clusters at y 1.19 and x 0.896 — outside a bounding
box 1.0 tall and 0.87 wide — and 76 single-triangle "clusters" out of 79 hits. Diagnosed as texture
gutter bleed at `tex: 512`, which was **wrong**.

The real cause: gltf-transform writes an INTERLEAVED vertex buffer. The source's bufferViews carry no
`byteStride`; the bake's carries `byteStride: 32` — POSITION 12 + TEXCOORD_0 8 + NORMAL 12 — so a flat
`new Float32Array(bin.buffer, offset, count * 3)` reads position, uv and normal as if all three were
positions. It yields plausible-looking floats, which is what made it read as a subtler bug.

Measure on the **source**. With `tris: -1` there is no weld and no simplify, so the baked geometry is
vertex-for-vertex identical and only the texture is resized — the source is both correct and higher
resolution. For a prop that IS decimated, the parse has to honour `byteStride`.

**Verdict: trap.** Check `bufferViews[].byteStride` before trusting a hand-parse — or assert the
values land inside the accessor's own declared min/max, which is the cheap check that catches it
immediately.

## The watcher's tendrils: neither `anim` nor `pulse` can move a radial fan, so `PropCurl`

The ask was "make the tentacles swirl". Both existing vertex columns were measured against the prop
and both fail, for reasons about the SHAPE rather than about tuning:

- **`PropAnim`** weights a lateral offset by a power of normalized HEIGHT. This prop's tendrils reach
  full extent in *every* height band from 0.2 up (`rMax` 0.39-0.44 throughout), so a height weight
  moves the top ones, leaves the flanking ones planted, and at any amplitude that shows it drags the
  eye-studded core with it.
- **`PropPulse.twist`** turns about the LOCAL VERTICAL. The prop is 0.87 h wide and 0.57 h deep, so a
  Y-rotation moves a tip almost entirely in DEPTH, where the tunnel camera sees nothing.

`PropCurl` is a rotation about the **local Z** — the depth axis, which under `PropYaw.FRONTAL` points
at the resting camera, so every tip sweeps ACROSS THE SCREEN whichever way it sticks out. Phase
travels with the vertex's own azimuth about that axis (`lobes`, which must be an INTEGER or the wrap
at +/-PI creases the fan along one radius), making it a wave through the fan and not a pinwheel.

**The gate took two attempts and the failed one is the useful part.** A 3D distance-from-the-body's-
centre gate looks obvious and is useless here: **797 of the 980 vertices past 0.40 are the ROOT
POOL**, which is farther from the body's centre than any tendril tip — and 0.47-0.68 from the depth
axis, farther than the tips there too. No radial gate of any kind can exclude it. `yFloor` is the
term that does, and the radial gate only separates limbs from core ABOVE it.

Measured, in units of height, above `yFloor`: distance from the depth axis runs p50 0.230 / p90 0.342
/ max 0.501, so `dFloor 0.28 -> dSoft 0.14` leaves the median body still, moves 27% partially and the
outer 3% fully. The eight eyes sit at 0.034-0.262 and their discs reach 0.295 = weight **0.009**.

Both gates are POSITIONAL, which is not incidental: the preservator entry above records that a vertex
displacement must not be masked by albedo, because a TRELLIS atlas cuts charts along high-curvature
ridges, so a colour boundary lands on a uv seam and pulls duplicated vertices apart. Duplicated verts
share a position, so a position gate cannot do that.

Verified by pixel-diffing two frames 1.8s apart over the prop: **the tendril tips streak and the core
mass and the root pool are black.** No new draw call, pass, geometry or module — a third block at
`<begin_vertex>` in `PropShader`, and the program key gains a `C`.

**Verdict: landed.** `curl 0.13` (a tip 0.42 h out moves ~9px), `rate 0.25`, `lobes 3`.

## The watcher's eyes are REPAINTED, not animated — and the mesh is why

"Can the pupils move?" cannot be answered by nudging what the generator baked: a TRELLIS atlas is a
shattered mosaic, so a baked pupil cannot be moved in uv space, and a second one drawn over it gives
two. `PropEyes` therefore **overwrites `diffuseColor`** inside a table of measured discs.

Three measurements decided the design:

- **Scale.** At `h 3.5` and the resting parasite zoom (26.4 units out, fov 45) an eye is ~15 x 8 px
  after the camera's foreshortening and a pupil ~7px. A 2-3px gaze shift only reads if the iris is a
  large fraction of the eye and the throw is large — which means owning the eye art, not nudging it.
- **Normals were rejected**, on evidence that turned out not to say what it was read as saying — see
  the follow-up entry below. Position is what shipped and it works; whether a normal-derived pupil
  could also have worked is untested.
- **The eyes look like flat faceted DIAMONDS** in an orthographic dump of the mesh. > CORRECTED
  below: that was an artefact of the dump, not the mesh.

Every eye drifts on three sines at rates it rolls for itself off the loop index, so no two are ever
aimed the same way. The gaze is projected onto each eye's own tangent plane by Gram-Schmidt against a
precomputed outward vector — no cross-product basis, which matters because several of these eyes sit
where the outward direction is almost straight up and a `cross(up, fwd)` basis would blow up.

**The first tuning shipped with pupils that did not visibly move, and the cause was three compounding
halvings, not one wrong number:**

- The tangential vector was scaled by **1/sqrt(3)**, the true bound on a vec3 of sines. Correct, and
  useless: the tangential part has a typical length near 0.8, so the typical throw was **46%** of the
  ceiling. CLAMPING to unit length instead spends the authored range on the common case and only
  trims the rare overshoot. The magnitude still varies underneath, which is what keeps a pupil
  sometimes centred and sometimes at the rim rather than endlessly circling.
- `iris 0.52` with `gaze 0.30` is a big iris with nowhere to go. **Iris and gaze are ONE decision**:
  they share the disc, and their sum is how close to the rim the iris may get. Traded to `0.42` /
  `0.48` — same 0.90 sum, most of the disc now given over to somewhere to move.
- `gazeRate 0.04` is a ~25s cycle, slower than anyone looks at one prop. **0.14**, a ~7s one.

Together: ~1px of typical travel on a 13px eye became ~3px, at 3.5x the speed. Verified across four
frames over ~9s — every eye's pupil is visibly elsewhere in each.

**A "match the body" colour has to be measured where the thing SITS.** The blink's `lid` shipped as
the prop's whole-body albedo mean, 71/41/69, and read as a hole punched in the flesh. The root pool
and the shaded back are half the surface and both far darker than the rim an eye actually sits in;
measured in an ANNULUS just outside the eight discs the flesh is **87/59/84**, 1.6x brighter in
linear. Confirmed by forcing `blinkDuty` to 0.5 temporarily rather than waiting ~29s for a blink:
a shut eye now reads as mauve flesh.

**The outward anchor must sit BEHIND the eye field, not among it.** All eight are on one near-flat
face at z 0.05-0.12, so their own centroid lands at z 0.10 — a hair in front of the central eye,
whose outward direction would then be a 0.02-long vector pointing anywhere.

Two traps in the measurement. The seed threshold is a channel RATIO, and **min/max in sRGB is not
min/max in linear** (0.82 sRGB is ~0.65 linear) — the too-tight version found 33 of 123 eye triangles
and split the big central eye into five clusters. And greedy clustering is order-dependent, so it
needs a merge-to-fixed-point pass with a merge radius at least as large as the biggest eye.

It lives in `PropGlow` rather than a module of its own: every uniform it needs is already there
(local-position varying, box frame, clock, per-instance phase), and a fourth copy of the hook-chaining
boilerplate would add another link to a cache key walked on every material. `<emissivemap_fragment>`
is the right anchor for a diffuse write too — it runs BEFORE `lights_physical_fragment`, so a
repainted eye is lit like the flesh around it rather than pasted flat over the shading.

Live: keys `propAnimCLpropGlowE8` (solid) and `propAnimCP` (hull — curl but no eyes), with the other
three organs byte-identical to before, so nothing already warmed recompiled. Zero console errors, and
the frame diff shows a distinct pupil-shift blob on each of the eight.

**Verdict: landed.** The eye table is measured off this atlas and dies with it — stated in the row.

## The repaint left a RING of every baked eye showing, and a diagnostic tool confirmed the bug it shared

Reported as "the eye overlays don't cover the underlying model eyes fully", and visible at a close
free-cam as a larger, softer pale ring with the old concentric swirl still in it, outside each clean
repainted disc. Three separate errors, and they had been propping each other up.

**1. The near-hemisphere clip was cutting the rim off every eye.** `step( 0.0, dot( dv, ef ) )` was
there to stop a sphere test painting the far side of the body. But the disc's centre sits at or near
the cap's APEX, so the entire eye lies at NEGATIVE `ax` — measured, the clip rejected **48-76% of
every disc**, and the rejection rises monotonically with radius (inner deciles ~0, the rim 8 of 9).
That is the unpainted ring, exactly.

Replaced by a CYLINDER in the eye's own frame: radial distance taken perpendicular to its axis, and
an axial slab offset back and kept tight in front. The cap spans only ~0.16 of its own radius in
depth, the far side of the body is 4-11 radii behind, and the one thing that can sit just in front is
a tendril arcing over the eye — which must not be painted white. The iris and glint moved onto the
radial component too, so both are true circles on the eye's face rather than sphere intersections.

**2. Per-triangle CENTROID sampling under-read every radius.** A centroid asks "is the middle of this
triangle pale", so every triangle straddling the sclera edge counts as flesh. Re-measured by
barycentric surface sampling, the radii move by -25% to +50% — they were not uniformly wrong, which is
why no single fudge would have fixed them.

**3. And the check inherited the bug.** The orthographic dump used to eyeball the fit painted ONE
CENTROID COLOUR PER TRIANGLE, so it showed the same under-read the fit was making — and it rendered
the eyes as flat faceted diamonds, which was then written up as a property of the mesh and used to
justify the whole design. Per-pixel uv interpolation shows what is actually there: **proper round
eyeballs, white sclera, brown iris**. The design is unaffected — a baked pupil still cannot be moved
in uv space — but the stated reason for it was wrong.

**A diagnostic that shares its subject's bias will confirm whatever the bias says.** The dump agreed
with the fit four times, because both asked the texture the same wrong question.

Also settled: two dots that look like tiny eyes measure as a vestigial bump and a hole through the
flesh, with no sclera in either. Eight eyes, not ten.

**Verdict: landed.** Full coverage at free-cam range, no spill onto tendrils or flesh.

## The gaze had to be a SACCADE, not a drift

"Jerkier, like humans look from side to side." A sum of sines sweeps smoothly and reads as floating,
whichever amplitude and rate it runs at — the failure is the shape of the motion, not its size.

An eye now HOLDS one fixation and FLICKS to the next. No state: the fixation index is `floor` of the
clock and both endpoints are hashed off that index, so `gk + 1` is the same value the next cycle
reads as its own start and the handover cannot pop. `smoothstep` over the last `gazeSnap` of the
cycle is the flick — 0.06 of a ~2.1s hold, so ~0.13s. The index wraps at 64 to keep the hash input
small (it amplifies input error by 43758); the cost is a repeat every 64 fixations, unobservable when
each eye runs at a rate of its own.

Components are hashed to -1..1 rather than normalized, so the MAGNITUDE varies too and an eye settles
near centre as often as hard to one side. Then squashed 0.55x in Y, because eyes scan side to side
far more than up and down — in WORLD axes, which is right only because every grown organ is
`PropYaw.FRONTAL`, so world Y is up on the prop and lies in every eye's tangent plane.

Verified by per-frame change over five frames at 0.45s: **mean 14.12 on one interval against 1.79,
2.93 and 3.86 on the others**. Hold, hold, flick — a drift would have been flat across all four.

**Verdict: landed.** `gazeRate 0.07` (~2.1s, spread 1.6-3.0s across the eyes), `gazeSnap 0.06`.

## The FLANK eye cannot be fitted automatically: one shared outward anchor does not serve it

Every eye takes its axis from one anchor behind the eye field, which is right for the seven on the
prop's face and wrong for the one round its side: that eye's real surface normal points further out
than the anchor says, so the tangent-plane decomposition is skewed, its radial pale profile smears,
and no plateau ever forms to measure an edge from. Two independent automated fits disagreed with each
other on it and both disagreed with what the prop looks like.

A ring-centroid re-fit did converge on the centre (two rounds, 379 then 408 pale samples, stable to
0.002) and it was RIGHT about y — but 0.01 short on both x and radius, which at this eye's size is
30%. Read off an orthographic dump instead: the sclera ran visibly down and right of the disc.

**The lesson is not "measure less".** The measurement placed seven of eight eyes to a precision no
eyeball could, and it was the measurement that showed the eighth was unreliable — the profile refused
to form a plateau, which is the fit telling you it has failed. Take the number when the shape of the
evidence is right and look at the thing when it is not.

**Verdict: landed.** `{ x: 0.266, y: 0.599, z: 0.072, r: 0.036 }`, from 0.262 / 0.606 / 0.030. Giving
this one eye an authored axis of its own was considered and skipped: one number fixed it, and a
per-eye axis is a field on every row to serve a single case.

## Tendrils that hinge are not tendrils: `wave` puts the bend ALONG the limb

The curl's rotation angle depended on a vertex's AZIMUTH about the depth axis and on the gate, but not
on how far out it sat — so every vertex of one limb leaned by the same angle and the fan swung as a
set of rigid spokes with a taper. Adding a phase term proportional to distance from the axis makes the
lean vary down a limb's own length, which is the difference between hinging and undulating. It is
SUBTRACTED against the clock, so the ripple travels from the body out to the tips rather than standing.

`wave: 2.5` cycles per prop-height, against a moving span of d 0.28..0.50 = 0.22 of the height, is a
bit over half a wave along one limb — a clear S without it folding back on itself. `curl` went 0.13 to
0.16 to compensate: the middle of an S travels less than a rigid arc's does.

**Verdict: landed.** Same cost — one more term in a `sin` already being evaluated.

## Frame-diffing anything in a tunnel is confounded by the wall lamps

An A/B of the tendrils came back 37.7% of pixels changed at mean 24.43, with the whole wall and a
broad streak lit up. `SewerLamps` runs ~30% of its fixtures dead and ~35% sputtering, so between any
two captures the lighting has moved more than the prop has.

**Verdict: trap.** Diff a region the lamps do not reach, or compare silhouettes against the dark
background instead. This is the same family as the "A/B'd across a `make reload`" entry above: hold
everything that is not the subject still, and in a tunnel the lighting is not still.

## The slime trail drew through walls: `depthTest: false` bought a curb and sold the whole scene

The ribbon shipped with `depthTest: false` on its material, commented "draw over the ground always so
the raised curb can't occlude it". It is transparent and so renders after the opaque pass, and with no
depth compare at all it painted over every wall, building and prop standing between it and the camera.

The curb worry it was bought for cannot happen, and the same commit already contains the reason: every
spine point carries **its own** `floorY(col,row)`, and a height change **forces a commit** rather than
waiting for the next `sampleW`. So the strip is never left at road height on a walkway — the two
mechanisms were written together and the flag was belt-and-braces over a fix that already held.

The other half is `Occlusion`: a building that would hide the player is faded, and below `ghostCross`
its real mesh is hidden outright while only the ghost draws, `depthWrite: false`. So a wall that could
occlude the trail is by then not writing depth, and the trail reads through it — which is exactly how
the actor sprites, the blood decals and the trail's own landing puddles have always behaved (they all
run `depthTest` on). The ribbon was the one thing in the ground-decal family opted out.

Verified in the habitat from a pinned free-cam pose: at `y 6.0` the parasite sits behind a low brick
wall and the wall face is clean; raise the same pose to `y 12.0` and the green ribbon is there in the
alley behind it. The selection ring is the control — it is genuinely `depthTest: false` (`Badges.hx`,
"always-on-top UI") and in the low shot it is drawn across the bricks while the parasite it belongs to
is hidden. That is what the trail used to do, visible side by side in one frame.

**Verdict: landed.** One flag. Cost is unchanged — same draw call, same material, same everything.
Note the neighbours that keep `depthTest: false` on purpose and are NOT this bug: `PathLine` (seeing
where a path ends around a corner is the point) and the entity badges/selection ring.

## Hiding the UI: a prop's tactical outline is NOT one of the sprite marks

Shift+Space hides the HUD and the world-anchored UI with it. `HUD.isVisible()` is the only state —
each consumer reads it once per frame and everything re-asserts from live state, so unhiding needs no
restore path and nothing can desync.

The trap: gating `Actors`' object `mark` flag and the AI badges looked complete in the follow view and
left every 3D prop **still wearing its green tactical outline**. Those are not sprite marks. A
model-backed object is outlined from its own geometry — a `ModelVariant.HULL` backface shell, packed
by `hullMask[i] = tactical` inside `ObjModels.cull`, a path the `mark` flag never reaches (and the row
comment says so: "the prop is outlined from its own geometry"). It needed a `ui` field on
`Area3DTickOpts` so the cull can ask for `tactical && opts.ui`.

**Verdict: landed.** The lesson generalises past this feature: "the object's marks" is TWO mechanisms
with one name, split by whether the object has a glb, and a change that means to reach both has to
name both.

## `sink`: an organ that GREW out of the floor should not be standing on it

`Models.normalize` puts every prop's base at y=0 and `instanced` places it there, which is right for
anything PUT somewhere — a ladder, clutter — and wrong for a grown organ, whose root rim then reads as
a lip laid on the floor. Worst on the preservator, where the flat root pool is 47% of the prop's
surface, so that rim IS the silhouette at ground level.

New `sink` column on `ObjModel`, a fraction of `h`, resolved to a per-placement `y` at build. Both
organs at **0.05** — 0.19 world on the biomineral, 0.18 on the preservator. Arch and watcher stay 0
(the arch's legs already splay flat, the watcher's skirt already dies into the floor).

**The wiring is where the work was.** `Models.instanced` is already at 5 args, so appending a 6th is
out; the offset belongs with the placement anyway. But **Haxe arrays are INVARIANT**, so adding
`?y:Float` to the inline `{ x, z, yaw }` structure broke all four producers — an `Array<{x,z,yaw}>`
will not pass as an `Array<{x,z,yaw,?y}>` even though a single value would. Hence the named
`Models.PropPlace` typedef and an annotation at each producer. An inline array literal at a call site
is fine (it types against the expected type); a pre-annotated local is not.

**Verdict: landed.** Free — it moves an instance matrix that was being composed anyway.
