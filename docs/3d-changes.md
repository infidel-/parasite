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
