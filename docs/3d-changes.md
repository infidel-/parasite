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
