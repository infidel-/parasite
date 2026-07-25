# 3D render changes: what was tried and what happened

Append-only ledger of every 3D/render experiment — landed, reverted, or rejected — with its
measured result. **Read this before proposing a render change**, and add to it after trying one.
It exists because the expensive mistakes here are the ones already made once: the roof-detail
batching below was disproved a second time despite a note already saying so in two lines.

Baseline hardware for all numbers: **RTX 3050**, 60fps cap, 1080p-ish, `vidAntialias=4`.

**Which view a number came from matters more than the number.** Gameplay is a zoom lerp, not a set of
modes (`RenderConfig.CAMERA`, `CameraRig`): zoom 0 = close, ~30° above ground; zoom 1 = top-down.
Resting targets are capped (`parasiteZoom: 0.30`, `hostZoom: 0.60`) and `tactical` is pinned at 1.0.
Measured across views and spots, **gameplay runs 158–288 calls**. Separately, the street-debug
**free-cam** (backtick) can go fully parallel and render the whole city — ~230 buildings — which no
gameplay camera does. It is a dev tool; the two-tier merge lead below is the only entry targeting it.

## How to measure (and how not to)

- **`calls=` in the `[street-render]` trace is the only draw-call number.** Enable the `perf street`
  console toggle (`render.Actors.DEBUG_PERF`) or street-debug mode (backtick). The trace is emitted
  by `StreetPerf.hx:228` (`frame=/GPU=/submit=/upd=/idle=/calls=/tris=/programs=/shdw=/heap=`) — it
  used to live in `StreetView.hx` with `full=`/`base=`/`post=` fields, which no longer exist.
- **The scene dump (`9`) is an INVENTORY, not a draw list.** `visibleDrawables` counts objects whose
  `visible` chain is true — frustum culling then discards most of them. Real ratio measured here:
  **1616 visibleDrawables → 435 calls**. A big number in the dump means nothing until you confirm
  those objects survive culling. Two failed experiments below came from reading the dump as draws.
- **`submit` is the CPU draw-call wall** — time inside `composer.render()` (scene walk + issuing
  draws + any driver blocking). It is the ceiling that a better GPU does **not** fix. `upd` (engine
  CPU) is ~1ms and irrelevant. `GPU=` is a real timer query (`EXT_disjoint_timer_query_webgl2`).
  Compare the two before assuming which wall you are on: they sit at `4.75` vs `4.66` with AO off,
  but AO flips the frame GPU-bound (see the GTAO entry). "Submit is the wall" is the default, not a law.
- **Always A/B against a measured baseline in the same view.** Both `follow` and `tactical` — they
  differ (tactical draws ~80 more calls and ~2ms more submit).

### Attributing every draw call (the census)

`calls=` gives a total but not a culprit. To get the real per-object breakdown **without touching
shipped code**, patch from CDP (`three.global.js` exposes `window.THREE`):

- `Object3D.prototype.onBeforeRender` fires once per **post-cull** draw (`WebGLRenderer.js:2014`) —
  this is the only honest "what actually drew" list. Its first arg **is the renderer**, which is the
  one way to reach the live renderer from JS (`parasiteHx` is statics-only).
- Wrap `renderer.renderBufferDirect` (an **instance** property, `WebGLRenderer.js:1104`, not on the
  prototype) and read `renderer.info.render.calls` before/after each call — the delta attributes
  draws exactly, instead of assuming one call per object.
- Classify by the `scene` arg: `null` → **shadow pass** (`WebGLShadowMap` calls `renderBufferDirect`
  directly and never fires `onBeforeRender`, so shadow draws are invisible to the object hook);
  `scene.isScene === true` → main scene; anything else → **post fullscreen quad** (`FullScreenQuad`
  calls `renderer.render(mesh, cam)`, passing a *Mesh* as the scene).
- In the shadow pass `material` is the depth override — read `object.material.userData.cls` for
  identity. In the main pass `onBeforeRender` receives the **group's** material, so multi-material
  walls attribute per face (better than the dump).
- Wrap the body in `try/catch`: an exception inside the wrapper propagates into the render loop and
  silently yields an empty census.

Measured this way, **tactical = 513 calls: 175 shadow / 324 main / 14 post**.

## Verdict table

| change | result | verdict |
|---|---|---|
| `flattenBox` + `mergeBand` (earlier) | 10,595 → ~3,000 calls, 6 → 30fps | **landed** |
| MSAA via composer render targets | real AA, was previously absent entirely | **landed** `729c064` |
| Parapet ring merge per building | 583 → 436 calls, submit 10 → 7.3ms | **landed** `1183cff` |
| Ghost overlay capacity fix | fixes a hard `RangeError` crash | **landed** `5a6ae04` |
| `forceSinglePass` on decal materials | 513 → 458 calls (−55, −11%), no visual change | **landed** |
| Merged city-wide shadow caster | shadow pass 175 → 16 calls | **landed** |
| ^ the two together, measured in-game | calls −44/−52%, **submit −25%**, +2ms idle | **landed** |
| Decals sample the atlas (per-instance UV rect) | 55 → **2** decal calls; 210 → 158 total | **landed** |
| Atlas the WALL textures the same way | walls tile; an atlas cannot wrap inside a sub-rect | **rejected — wrong tool** |
| Texture array for walls (3 calls/box → 1) | ~20 calls in one sample; enables the static merge | **open lead, unmeasured** |
| Two-tier static city merge | ~3k → ~200 calls **in the debug free-cam only**; gameplay is 158–288 | **open lead, deferred** |
| Pull the fog / view distance in | shorter sightlines — look/feel | **rejected** |
| Per-building merges of doors/covers/roof furniture | low ROI; doors are ~5 calls in view | **rejected** |
| Roof-detail material hoist | ~750 → 6 materials; **0 draw calls** | **landed** (harmless) |
| GTAO ambient occlusion | +994 calls, +10ms submit; 60 → 45fps | **landed, default OFF** `870d0f8` |
| BatchedMesh for roof details | **+4 calls, +2ms submit, −3ms idle** | **reverted — worse** |
| AgX / Neutral tone mapping | look rejected | **rejected** |
| `reversedDepthBuffer` | flips custom `depthFunc`/decal offsets; doors vanish | **rejected** |
| Distance-cull far detail | parapets are the roofline silhouette — pops | **rejected** |
| SSRPass (reflections) | style rules ban glossy/specular reflections | **rejected** |
| `RenderPixelatedPass` | total aesthetic pivot, not an enhancement | **rejected** |

## Landed

### `flattenBox` + `mergeBand` — `6a20c75`, `8240e4d` (the original draw-call fix)
The founding entry, kept because it explains why boxes cost what they cost today. Symptom: **~150ms
render with GPU *and* CPU near idle** (one core pegged issuing draws) at only ~65k triangles — the
cost was draw-call **count**, not fill. Cause: every multi-material `BoxGeometry` cost one draw call
**per face group** (6 per box), times every visible building, on one JS thread.

- **`Poly.flattenBox`** (`Poly.hx:47`) — collapses a multi-material box to **one call per distinct
  texture** by baking each face's texture matrix into the geometry UVs and reordering the index so
  same-image faces form one contiguous group. Coping (single image) → 1; parapet (clean+worn) → 2;
  building box (walls+roof) → 3. A self-check cross-validates the UV math against three's own
  `Texture.matrix`. **That 3 is a floor, not a bug** — see the texture-array lead below.
- **`Buildings.mergeBand`** (`Buildings.hx:273`) — merges each building's upright wall-band quads
  (grime, storefront bays, ground bands) into one mesh per material, baking rotation+position into
  verts with explicit +z-rotated normals so shading is identical. `userData.b` kept so `Occlusion`
  still fades per building.
- Camera far-plane clipped to just past the fog wall (`SceneSetup.hx:51-58`,
  `far = CELL * GRID * 1.25`): past it every building is solid fog yet still drawn, so a parallel
  camera rendered the far half of the city for nothing. Clipping lets three frustum-cull it.

**Free-cam parallel view: 10,595 → ~3,000 calls, 6 → ~30fps, no visual change.** Those numbers are
from the free-cam, not gameplay — do not compare them to the 158–288 figures elsewhere in this doc.

### MSAA antialiasing — `729c064`
The renderer asked for `antialias: true`, but **every frame goes through the `EffectComposer`**,
which renders to an offscreen target; the final `OutputPass` blits a fullscreen quad, which has no
geometry edges to smooth. So the flag did nothing and the game had **no AA at all**. Fix: set
`samples` on the composer's own render targets (`StreetView.setAA`), config `vidAntialias`
(Off/2/4/8, default 4). Renderer `antialias` set to `false` — with a composer it is pure waste.

### Parapet ring merge per building — `1183cff`
`parapetRing` emitted 4 corner posts + N rim spans as **individual meshes**, ×3 rings per building →
~24 meshes/building, 723 citywide. All single-tex segments carry baked UVs and an identity map
transform (`Poly.flattenBox`), so they differ only by placement. Now baked into verts and merged
per ring. **723 → 410 meshes; calls 583 → 436; submit 10 → 7.3ms; idle 6 → 8.6ms.**

Two traps, both real:
- The merged mesh is world-baked, so it sits at the origin → `pick()`'s position fallback would
  bucket it into whatever building covers the city centre. **`userData.b` is load-bearing** — the
  size guard in `pick()` rejects it otherwise and parapets silently stop fading.
- `brickMats` picks clean-vs-worn per face, so an all-clean and an all-worn segment **both** collapse
  to a "single" material — with *different textures*. Merging must bucket by **texture source**, or
  worn parapets get repainted clean. `flattenBox` hardcodes the cls to `parapet-coping`, so the scene
  dump labels both identically and **will not show this bug**.

### GTAO ambient occlusion — `870d0f8`, default OFF
Opt-in only. Why it costs anything: `GTAOPass._renderOverride` calls a **full `renderer.render()`**
with `scene.overrideMaterial` set, so the whole scene is drawn a second time through a
`MeshNormalMaterial` — and that re-runs the shadow-map pass too (the moon's 2048² map renders twice
per frame, the second time to feed a material that cannot sample shadows). A disabled pass is skipped
whole by the composer, so default-off costs nothing but idle memory.

**Its cost is a function of the scene, so it fell as the scene shrank.** Originally
**+994 calls, +318k tris, +10ms submit, +8ms GPU → 60fps drops to ~45**. Re-measured after the decal
+ shadow work (same spot, follow view):

| | calls | tris | GPU | submit | idle |
|---|---|---|---|---|---|
| AO off | 158 | 95k | 4.75 | 4.66 | 11.4 |
| AO on | 298 | 177k | 10.2 | 8.1 | 7.85 |

**+140 calls, +5.4ms GPU, +3.5ms submit — holds 60fps with ~7.8ms idle.** ~7× cheaper in calls than
the original measurement, purely because AO re-draws whatever the scene is.

**It also flips which wall is being hit, and that is the part that matters.** AO off:
`GPU 4.71 ≈ submit 4.70` — CPU/draw-call-bound, the regime everything else in this doc targets. AO on:
`GPU 10.14 > submit 8.89` — **GPU-bound**. The standing note "a better GPU does not fix submit" stops
applying with AO on; the inverse does. That is why it still ships **off by default** despite now
fitting the frame: this machine absorbs +5.4ms of GPU, and the weak-laptop target is exactly the case
these numbers cannot speak for. Flip the default only after measuring there.

Tuning trap: `radius` is **world-space** and `CityConfig.CELL = 4`. The initial `radius: 0.25` was 6%
of one cell — invisible at city scale. Usable range starts ~1.5. Note the effect fights the art
direction ("even flat lighting, NO soft photographic shadows"), which is why it ships off.

### `scene.overrideMaterial` silently discards per-material depth tricks
Two AO bugs, one root cause — worth stating once because nothing about it is local to GTAO. Any pass
that renders through `scene.overrideMaterial` **replaces the material outright**
(`WebGLRenderer.js:1996`), so every flag the object relied on is gone: `colorWrite`, `depthTest`,
`polygonOffset`. Both bugs were invisible until someone actually turned AO on.

1. **The merged shadow caster wrote depth into the AO prepass.** It is only invisible because of
   `colorWrite: false`; under the override it drew its building volumes coplanar with the real walls
   and the whole facade z-fought. Fix: **`allowOverride: false`** (`Material.js:437`, default true) —
   three's own opt-out, which keeps our material on the mesh so it goes on writing nothing no matter
   who renders the scene. The shadow map is unaffected either way (`WebGLShadowMap` swaps in its own
   depth material, and ignores `overrideMaterial` entirely).
2. **Flush wall overlays z-fought.** Storefront bays, doors, grime bands, wall decals and entrances
   all sit dead flush and rely on `polygonOffset` to win. The override drops it. `allowOverride` is
   **not** the fix here — unlike the caster, these *should* appear in the normal buffer, and opting
   them out would make them write albedo into it instead of normals. Fix: stand them physically proud
   (`Geom.buildingFaces(..., eps)`), `OVERLAY_EPS = 0.02`. Only the shopfront was visibly bad — a bay
   covers its entire wall, while the others are small patches — so only it was changed. `Entrances.hx`
   had already tuned this by hand: 0.06 gaps visibly, 0.01 is flush.

Rule of thumb: **an object that renders correctly only because of a material flag is a bug waiting for
the next override pass.** Prefer real geometric separation, or `allowOverride: false` when the object
is meant to be invisible everywhere.

### Ghost overlay capacity fix — `5a6ae04`
`makeGhostMesh` allocated the ghost at `real.count` then copied the source's *entire*
`instanceMatrix.array` → `RangeError` whenever `count < capacity`. That is normal: `Models.cull()`
packs visible instances and drives `count` down every frame, and `DecalBatch` allocates at `CAP`.
Now sized by capacity, count mirrored.

### `forceSinglePass` on decal materials
`WebGLRenderer.js:2021`: a material with `transparent === true` **and** `side === DoubleSide` **and**
`forceSinglePass === false` is drawn **twice** — a `BackSide` pass then a `FrontSide` pass, each one
also setting `material.needsUpdate = true`, every object every frame. That split only earns its cost
on closed geometry where both faces can be visible at once. `DecalBatch` quads are **flat planes** —
the back pass is a pure duplicate. Setting `forceSinglePass: true`: **513 → 458 calls**, verified by
live A/B (flip → measure → revert → baseline returned).

Other `transparent` + `DoubleSide` materials trip the same path and are all flat quads (`Sparks`,
`Beams`, `Sprites`, `GasCloud3D`, `ScreamPulse3D`, `LightCone`, the `Occlusion` ghost). Each is only
a few calls today, but the same one-line fix applies to any of them.

### Merged city-wide shadow caster — the shadow pass was 34% of the frame
**175 of 513 calls were the moon's shadow map**, 160 of them building walls. Cause: `flattenBox`
leaves ~3 material groups on each building box, and `WebGLShadowMap` draws **one depth call per
group** (`WebGLShadowMap.js:358-379`) even though every group resolves to the same depth material.
54 buildings in the shadow box × 3 groups = 160 calls to render *untextured depth*.

Fix: bake every building box into ONE position-only `BufferGeometry` (`Buildings.addShadowCaster`)
and make it the sole caster; the boxes keep `receiveShadow` and lose `castShadow`.
**462 → 304 calls, shadow 175 → 16**, verified by live A/B (add proxy → measure → revert → baseline
returned). Whole city = **2.7k tris**, so the merge is free — this was pure call overhead, the exact
opposite of the roof-detail case below (batch only what isn't already culled *and* is call-bound).

The caster is invisible **only** because of `colorWrite: false`, which any `overrideMaterial` pass
throws away — it shipped in `f465c1d` flickering the whole facade under GTAO, and nobody saw it
because AO defaults off. It now carries `allowOverride: false`; see the `overrideMaterial` entry
below before giving this mesh any new material flag.

In-game result of this + `forceSinglePass`, measured at one spot in both views:

| view | calls | submit | idle |
|---|---|---|---|
| follow | 435 → **211** | 7.3 → **~5.4ms** | 8.6 → **~10.5** |
| tactical | 513 → **288** | 8.6–8.9 → **~6.6ms** | 6.8–7.4 → **~9.3** |

Both were already pinned at the 60fps cap, so the win is **~2ms/frame of headroom**, not fps.
Note calls fell ~45% but `submit` only 25%: the removed calls averaged ~9.5µs while the survivors
average ~23µs. Shadow draws are depth-only with no material binding — they were the **cheap** calls.
**Per-call cost is not uniform; do not convert a call count into a submit estimate.**

Facts worth keeping:
- **three has no shadow-only object.** `WebGLShadowMap.renderObject` tests `object.layers` against
  the **VIEW** camera (`WebGLRenderer.js:1622` passes it in; `WebGLShadowMap.js:347` tests it), so a
  layer the camera can't see hides the object from the shadow map too. `material.visible = false`
  and `object.visible = false` also skip the shadow pass. Hence the proxy draws once in the beauty
  pass with `colorWrite: false` — one call that writes nothing. That is the floor, not an oversight.
- The depth material needs **position only** (walls are opaque, no `alphaTest`), which also sidesteps
  attribute-set mismatches when merging.
- Lamp spotlights contribute ~0 shadow draws in practice; the moon was the whole cost.
- The proxy lands in `__occ.skipped()` (world-baked → origin → `pick()`'s size guard rejects it).
  Correct: it is invisible and must never fade.

### Shadow box size is NOT the lever (measured)
Sweeping `MOON_SHADOW.halfExtent` at a fixed view: 90→175, 75→154, 60→116, 45→78, 30→39 shadow
calls. But the camera's measured ground footprint is **radius 69** from the focus, so the box cannot
go below ~75 without dropping shadows off visible ground — and it must actually run *wider* than the
footprint on the light side, since off-screen buildings cast **into** view (`MOON_DIR` is ~48° up, so
a 30-unit building throws a ~27-unit shadow). Shrinking XY silently deletes those casters. The
existing `halfExtent: 90` vs footprint 69 is about the right margin. Best safe win was ~21 calls;
the merge above got 158 without touching coverage.

### Decals sample the atlas directly — 55 decal calls → 2
Closes the "`DecalBatch` groups are per-texture" open lead, and the lead named the wrong cause.

`Sprites.tex()`/`texContent()` take the packed `entities` atlas and cut **every cell into its own
`CanvasTexture`** (cached per `imageName:ix:iy:male:mul`). `DecalBatch` keyed its groups on
`tex.uuid`, so each cell opened its own group: **55 groups for 122 decals**, one draw each. We were
un-atlasing an atlas and then paying per cell for it.

Fix: keep one full-atlas texture per `(imageName, male, mul)` — `mul` has only 2 values — and pass
each cell's UV rect on an `instanceUV` vec4 attribute beside the existing `instanceAlpha`, remapping
`vMapUv` after `#include <uv_vertex>`. The group key becomes the atlas + `rough`/`metal`:

| | groups | decal calls | total calls |
|---|---|---|---|
| before | 55 | 55 | 210 |
| after | **2** | **2** | **158** |

The two survivors are exactly the two materials: matte debris/money (`rough 1`, 106 instances) and
wet blood (`rough 0.4`, 16). 210 − 158 = 52 ≈ the 53 groups removed, so nothing else moved.

Facts worth keeping:
- **Mipmaps had to go off** (`generateMipmaps = false`, `minFilter = LinearFilter`). Cells sit
  edge-to-edge, so a coarse mip averages neighbouring cells and a decal samples its neighbour's
  pixels at distance. The per-cell crops could mip safely *because* each owned a texture; an atlas
  cell cannot. Decals radius-fade out before they minify far enough for aliasing to beat the bleed —
  visually signed off. If shimmer ever shows up, the fix is padded atlas gutters, not a revert.
- **Half-texel inset on every rect**, same reason: a linear tap exactly on a cell boundary pulls in
  the neighbour. Verified in the buffer: cells come out `63×62` px, not `64×64`.
- The `tex()` crop path stays for the quad decals (wall blood, emissive acid/slime/black). Only the
  batched path moved, so a crop is now cut only for splats that actually need one.
- Costs **~19MB of GPU texture** (two darkened 768×3072 atlas copies) the tiny crops didn't. Folding
  `mul` into `material.color` would halve that but multiplies in linear space, not sRGB like
  `darkenCanvas` — a different look for no draw-call gain. Not done.

Verifying UV plumbing without a screenshot: read `instanceUV` off the geometry in the census wrapper
and check the rects are in-bounds, distinct, and land on the cell grid (`u` stepped by exactly
`64/768`). That caught nothing here, but it is what separates "rects are self-consistent" from "each
decal got its own cell" — only the second is visible, and only to a human.

## Open leads (not yet acted on)

### Walls cost 3 calls per box — an atlas will NOT fix it, a texture array would
`flattenBox`'s floor is **one call per distinct texture**, so a building box costs 3 (walls, worn,
roof) and a parapet 2. In one follow-view census that was ~10 boxes × 3 = 30 calls; collapsing them
to 1 each saves ~20 of 158. **Unmeasured beyond that sample — get a real A/B before believing it.**

**Why the decal fix does not transfer.** Walls *tile*: `repeat.set(wWorld / TILE, …)`
(`Buildings.hx:72`) runs UVs 0→4 across a face and the wrap mode turns `u = 3.2` back into `0.2`,
which is what gives real brick at any building size without stretching. Wrapping is a property of the
**whole texture**, not of a sub-rectangle inside it — walk `u` past your cell's edge in an atlas and
you do not restart the brick, **you slide into the neighbouring image**. Decals could be atlassed
precisely because a decal quad samples its cell **once** (UV 0→1, nothing to wrap). Same word,
different problem. `fract()` in the shader fakes the wrap but breaks mipmapping — the UV jump at each
tile seam blows up the derivatives and the GPU picks the blurriest mip, a visible seam per tile
(fixable with `textureGrad` + padding, i.e. owning custom sampling for every wall in the game).

**The right tool is `DataArrayTexture`**: N full textures as layers, sampled
`texture(tMap, vec3(u, v, layer))`. Each layer is its own complete 0→1 space, so wrapping, mipmaps and
anisotropy all work per layer and brick in layer 3 cannot reach layer 4. `flattenBox` already bakes
per-face texture matrices into the geometry UVs — this adds a per-face `layer` attribute beside them
plus an `onBeforeCompile` patch to sample the array (same move as `instanceUV` in `DecalBatch`).

**The strategic half is bigger than the ~20 calls.** Every wall box would share **one material**,
which is the precondition for welding buildings into a few giant meshes — see the two-tier merge lead
below. The array does not remove that plan's real blocker (`Occlusion` fades one building at a time),
it removes the texture obstacle under it.

**Cost:** all layers must share size + format; the array is built by blitting every wall PNG into one
buffer (build step or load-time canvas); ~20 layers × 512² ≈ 20MB + mips; per-texture `roughness` has
to go uniform or ride another attribute; and every wall material becomes a custom shader we own.
Subsystem-scale. Weigh against a frame that currently runs **158 calls / 4.66ms submit / 11.4ms idle**
— i.e. ~30% used. **Measure on the weak-hardware target before spending this.**

### Two-tier static city merge — for the debug free-cam, not for players
Absorbed from `perf-static-city-merge.md` (deleted; see git history for the original). **Read the
scope line first, because the doc it came from was written before the scope was obvious:** this
targets the **street-debug free-cam at a parallel angle**, the one view that renders the whole city.
The goal was making that dev view usable, not player framerate.

Gameplay does not need it, and that is measured, not assumed: the city is **226–233 buildings**
(`CityGen.generate`, seeds 1-3), while gameplay runs **158–288 calls** (follow 158, zoom-out ~202,
tactical 288). Fog + the far-plane clip + frustum culling already discard ~200 of ~230 buildings
before a draw is issued. **Do not cite this entry as a player-facing perf win.**

The idea: the city is static, so weld every piece sharing a texture into a few giant meshes — "all
brick walls citywide", "all coping", "all roofs" — ~10–20 meshes for the whole map. The free-cam then
draws ~200 calls instead of ~3,000. Standard merged-static-geometry technique.

**The blocker is `Occlusion`.** It fades an *individual* building while it blocks the camera→player
sightline, by owning that building's materials and easing their opacity. One welded mesh + one
material = all-or-nothing fading. The fix is tiering:

- **Near tier** — the handful of buildings that can actually occlude the player. Stays on today's
  individual fadeable meshes, code path unchanged.
- **Far tier** — everything else, welded, never fades (too far to occlude anyway).
- Re-tier on **area movement**, not per frame, re-welding when a building crosses the boundary.
  `Occlusion` only ever sees the near tier.

Notes: welding reuses the bake already written for `flattenBox`/`mergeBand` (per-face UV transform →
geometry UVs, world transform → verts) — the merge is the same vertex concat, and the new work is the
tiering + re-weld bookkeeping. Weld granularity is capped at one mesh per texture because each wall
texture is its own `Texture`; a `DataArrayTexture` (lead above) would lift that cap, though it does
**not** touch the `Occlusion` blocker. Transparent/cutout passes (windows are already `InstancedMesh`,
doors are alphaTest) can stay as-is. Watch the near/far boundary for pop — geometry is identical
either side (same bake), only fadeability changes.

**Verdict: deferred.** Only path to a big cut in the free-cam view, but it is a real subsystem —
tiering, `Occlusion` rework, re-weld on movement. Player-facing perf does not need it. Do it only if
the debug free-cam's usability is worth a subsystem.

## Reverted / rejected

### BatchedMesh for roof details — reverted, measured worse
Hypothesis: 737 roof-detail `InstancedMesh`es (one per building × detail type) = 737 draws → batch
into 6. `BatchedMesh.setVisibleAt` even solves the per-building fade constraint, so the ownership
contract was built (`OccBatch` on `batch.userData`, batch-aware `FadeMesh`, ghost rebuilt from the
per-building geometry) and **the fade worked correctly**.

It still lost, in tactical (the view where every rooftop is on screen):

| tactical | unbatched | batched |
|---|---|---|
| calls | **513** | 517 |
| submit | **8.6–8.9ms** | 10.1–12.2ms |
| idle | **6.8–7.4ms** | 3.6–5.6ms |

Two reasons, both worth remembering:
1. **Roof details contribute ~0 draws in any view.** They sit on rooftops; the follow cam is ~30°
   above ground looking *at* the player. Even in tactical, unbatched cost 4 *fewer* calls. They were
   already culled for free. The old merge notes said this in 2 lines and it was ignored — which is
   why that entry now lives above rather than in a doc nobody opened.
   Later confirmed by the census: of 513 tactical calls, roof details are **1**.
2. **`BatchedMesh` is a pessimization for mostly-culled geometry.** `perObjectFrustumCulled = true`
   frustum-tests **every instance on the CPU every frame** and rebuilds the multi-draw list. An
   off-screen `InstancedMesh` is **one** bounding-sphere reject in `projectObject`. Batching traded 1
   cheap test for ~737. That is the +2ms of submit.

**Rule of thumb: batch only geometry that actually survives culling.** Parapets qualify (roofline
silhouette, always visible). Roof furniture does not.

### Roof-detail material hoist — landed but bought nothing
`addRoofDetails` allocated a fresh `MeshStandardMaterial` per (building × type) — ~750 identical
materials where 6 do. Hoisted; correct and harmless. **Zero draw-call change** — shared materials do
not merge draws. Kept for hygiene, not perf.

### Pull the fog / view distance in
Would cut what the parallel free-cam draws at the root. Rejected: shorter sightlines change the
look/feel. The far-plane clip (`SceneSetup.hx:51-58`) already takes the free half of this — it culls
what the fog has *already* made invisible, which costs nothing visually.

### Per-building merges of doors / covers / roof furniture
Safe (no visual change) but low ROI, and the original note's "~150–250 dc each" is meaningless now —
that was a share of a 3,000-call free-cam frame, and the whole gameplay frame is ~158. Current census
puts doors at ~5 four-vert `PlaneGeometry` objects, 1 call each. The conclusion survives its number:
several merges would be needed to move anything, so it stays unmerged.

### Tone mapping: AgX / Neutral
Added in r162/r165, so they are a one-line swap from `ACESFilmicToneMapping` with no bundle change
(`OutputPass` reads `renderer.toneMapping`). Tried; look rejected. Note bloom
(`BLOOM_THRESHOLD`/`toneMappingExposure`) would need retuning if ever revisited.

### `reversedDepthBuffer` (r181)
Flips custom `depthFunc` and decal polygon offsets — doors vanish. Do not enable.

### Corpse-vs-blood layering (z-fight flip, then flicker) — depthWrite fails, renderOrder tiers win
**Symptom:** flat corpses and blood splats sit ~coplanar, all `depthWrite:false` at the same
`renderOrder` (`ORD_DECAL`). three sorts equal-renderOrder transparents by camera distance, so the
tiny depth tie between a body and the blood under it flipped sign as the camera orbited — who's on
top changed every camera move. The old 0.01 Y offsets were invisible (depth never written).

**Attempt 1 — depthWrite + per-cell Y slot → REVERTED (z-fight flicker).** Made the whole
ground-decal layer `depthWrite:true` and encoded appearance order as a tiny Y bump per cell-slot
(`layerBase/layerEps/layerMax`, alphaTest to stop transparent corners depth-clipping). Killed the
flip but **traded it for per-pixel z-fight flicker** — worse. Why it can't work here: camera
`near=0.1`, `far=CELL·GRID·1.25=500`, non-reversed depth → resolvable Y-gap `Δz ≈ 6e-7·z²` ≈ 0.002
at mid-range, 0.006 at the far edge. The body↔adjacent-blood gap was a half-slot = **0.0025**, under
precision → flicker. And the Y budget is capped: decals must stay under the 0.06 fake-shadow plane,
so `0.03 headroom / ~0.015 min-safe-gap ≈ 2 layers` — nowhere near enough for N-deep appearance
stacks. **This is the `Entrances.hx:54` / `reversedDepthBuffer` lesson again: coplanar decal
layering here is done with `renderOrder` or `polygonOffset`, never tiny Y nudges.** depthWrite
between near-coplanar transparent quads z-fights, full stop.

**Attempt 2 — renderOrder tiers, hybrid batch (landed).** Everything back to `depthWrite:false` (no
depth compare between decals = no flicker, no flip possible). Layering is pure paint order via
`renderOrder`, with new tiers in `Sprites`: `ORD_DECAL(0) < ORD_CORPSE(1) < ORD_BLOODOVER(2) <
ORD_SHADOW(3) < ORD_MARK(4) < ORD_ACTOR(5)`.
- Bulk blood + debris + blood that *predates* a corpse in its cell → stay batched at `ORD_DECAL` (one
  InstancedMesh draws its instances in insertion order, so blood-vs-blood is already stable — that
  never flipped; only body-vs-batch did).
- Flat corpse → `ORD_CORPSE`, painted over the blood present when it fell.
- Blood sprayed *after* a corpse (its per-cell push-index ≥ the corpse's landing slot) → pulled from
  the batch to an **individual** quad at `ORD_BLOODOVER + idx*0.001` (fractional bump breaks
  same-cell ties) so it paints over the body. This is the only extra-draw-call path, and it fires
  **only in corpse cells for post-corpse splats** — bulk blood everywhere else is untouched.
- Corpse landing slot = decoration count in its cell on first sighting, snapshotted render-side
  (`Actors._bodyStackSlot`, no save field). Cells with a corpse are published each frame in
  `Actors._corpseCells` (object loop runs before `decals.paint`) and read via `Decals.corpseSlotAt`.
- **(a) corpses cast no shadow** already — `FlameShadows.castShadows` skips `isGroundDecal()`.
- **Known ceiling (accepted):** `renderOrder` overrides the transparent distance-sort, so a corpse
  (1) / over-blood (2) can paint over a spatially-nearer *bulk* decal in a different cell. Flat
  ground decals rarely overlap across cells at the near-overhead street cam, so it's cosmetic — and
  it's *stable* (no flicker/flip), which is the whole point. **TODO measure:** confirm at a grazing
  angle, and check the per-quad count in a corpse-heavy view (`calls=`).

### Wall graffiti clipping doors — door-span overlap skip (landed)
`WallDecals` bakes graffiti/posters/cracks only on **worn** faces; doors also land on worn faces
(side/maintenance at `BACK_ENTRANCE_WORN_PCT`, rarely a windowless worn street front), so the two
roamed the same face independently and occasionally overlapped — the deferral was self-marked at
`WallDecals.hx` (old `ponytail:` comment) and in `CLAUDE.md`. `doorRuns` alone can't fix it: it
returns candidate open runs, not the placed door's jittered interval (over-rejects yet still misses).
**Fix (landed):** `Entrances.place()` publishes each door's along-face span into
`WorldCtx.doorSpans` (`{b, dir, lo, hi}`, same face-center + `off` convention decals use); `WallDecals`
skips any decal whose `[off±size/2]` overlaps a span on the same building+face. `Entrances.add` runs
before `WallDecals.add`, so spans exist first. Along-face interval only — decals vertically overlap
door height nearly always, so the horizontal test is sufficient and conservative. Render-only, no save
field. **Skipped:** cover-lintel avoidance (covers sit narrow + above the door, not the reported clip).

### First gas burst hitch — shader pre-warm of the puff programs (landed)
First `panicGas`/`paralysisGas` per GL context stalled ~150–200ms (measured via `__progs()` diff +
`StreetPerf` trace `COMPILE +4`): `GasCloud3D` spawns puffs on demand, so their shader programs were
not in the scene at street warm and the driver compiled them mid-burst. **Root cause (fully decoded):**
the puff material is `MeshStandardMaterial` transparent + **DoubleSide**, which three renders as TWO
single-side passes — a FrontSide (`flipSided=false`) and a BackSide (`flipSided=true`) draw, each its
own program — times TWO material variants (baked-blob w/ `normalMap` vs atlas-art w/o) = **4 programs**.
Confirmed by diffing `renderer.info.programs` cacheKeys: 1st layer mask bit 7 = `normalMapTangentSpace`,
2nd layer mask bit 12 = `flipSided`. **Fix (landed):** `GasCloud3D.warmupMeshes()` builds 4 throwaway
meshes ({blob, atlas} × {`FrontSide`, `BackSide`} — explicit per-side so `compileAsync` compiles both
from params alone, no in-frustum render needed); `StreetView` parks them in the scene for the warm,
renders once, then removes the **meshes** but **retains the materials** in `GasCloud3D.warmMats`
(static). three's program cache is refcounted + **cacheKey-shared**, so keeping the 4 materials alive
keeps the 4 programs cached for the GL context, and every real puff (different material instance, same
key) reuses them. **Verified:** first burst `addedN=0` new programs, zero frame spike (was 167ms).
**Failed approaches (do not repeat):** (a) warming a single normalMap mesh, or (b) two meshes both
`DoubleSide`, or (c) removing+**disposing** the warm meshes — all still recompiled: (a)/(b) missed the
`flipSided` back-side program (`compile()` derives one side from params, the back-side program is only
made when the DoubleSide object is actually two-pass rendered), and (c) disposing releases the program
from the refcounted cache immediately. Also added `window.__progs()` debug hook (`StreetView`, shader
cacheKey cache) — the tool that cracked this; keep it.

### Boot pre-warm — first city entry stalled ~2s under black compiling the whole material set (landed)
The gas fix warmed one on-demand effect; this generalizes it. First city entry per GL context stalled
~2s of black-with-HUD-on-top because `StreetView.buildFrom` ran the shader warm (`compileAsync` + a
throwaway `composer.render()`) **inline on entry, under the fader** — the driver compiled every
MeshStandard permutation (buildings/windows/ground/roofs/entrances/walldecals + instanced variants) on
demand, one entry, in view of the player. **Fix (landed):** `StreetView.warmup()`, fired off the **menu
idle** (`Main`, 300ms after mods load, on the hidden `#streetview` canvas → invisible). It builds a
**throwaway city with the REAL builders** — `CityGen.generate(1)` + `SceneSetup.buildScene` +
`World.build` — so the material / instancing set is correct *by construction* with zero enumeration to
rot. Sets `_warmed` so the real entry skips its inline warm and `present()`s immediately.

**Two bugs this cost live-testing to find (both would silently defeat any warm), measured via `__progs()`
diff (menu baseline vs first entry):**

1. **`compileAsync` compiles for the CURRENTLY-BOUND render target's color space.** The game renders
   scene → the `EffectComposer`'s LINEAR intermediate target (`srgb-linear`), then `OutputPass` converts to
   sRGB. `compileAsync(scene, camera)` with the default framebuffer bound compiles the `srgb` variant — the
   WRONG program — and every real `srgb-linear` program still compiles on entry. The color space is baked
   into the cacheKey (`srgb` vs `srgb-linear` field). **Fix:** `renderer.setRenderTarget(comp.renderTarget1)`
   BEFORE `compileAsync`, restore `null` after. `compile()` walks the whole scene (not frustum-culled), so
   this warms every material's real program in parallel, view-independent — no camera framing needed.
2. **`NUM_POINT_LIGHTS` is NOT constant across cities.** `MuzzleLights` (pool 5) is always added by `Actors`,
   but `FlameLights` is added by `FlameShadows` **only in `AREA_CITY_LOW`** (barrel cities) — so point lights
   are 5 in normal cities, 10 in low-tier. That count is baked into EVERY lit program. The warm must carry
   the SAME pool set as the target area or all ~15 MeshStandard programs recompile on entry (measured: warm
   with 0 pools → +24 on entry; warm with both pools/10 → still +24 because live was 5; warm with just
   `MuzzleLights`/5 → +7). **Both counts are warmed via TWO `compileAsync` passes**: pass 1 with
   `MuzzleLights` only (5), then `new FlameLights(g)` bumps `NUM_POINT_LIGHTS` to 10 and pass 2 recompiles
   the lit set at 10. Both program sets persist (three releases a program only on `material.dispose()`, and
   the warm scene is retained), so BOTH the common cities AND the low-tier **new-game start** (which is
   `AREA_CITY_LOW`) enter with zero lit recompiles. Verified via `__progs()`: 14 physical programs at
   `,1,5,12,` (5 point lights) + 14 at `,1,10,12,` (10) — exact mirror, 28 total.
- **Shadow depth programs need the shadow PASS to actually run.** `compileAsync` doesn't compile the
  shadow-map depth materials. `warmup()` calls `SceneSetup.fitMoon(moon, cityCentre)` so the moon's shadow
  box covers the city-wide caster, then the throwaway `composer.render()` runs the depth pass and compiles
  them. (Cutout/alphaTest depth variants for windows/doors still compile on entry — cheap, left.)

Facts that made it work (and the traps):
- **On-demand effects aren't in the static scene**, so they're parked as throwaway meshes for the warm:
  gas via `GasCloud3D.warmupMeshes()`, actor sprites via new `Sprites.warmupMeshes()` (1×1 placeholder
  map/emissiveMap — the program key needs the DEFINES present, not pixels), beams/sparks by calling their
  **real spawn code** once (no material config to drift). Silent-scream (`ScreamPulse3D` ctor reads live
  `game.area`) and occlusion **ghosts** (`MeshLambert`, compile on first *fade*) are left on-demand — both
  cheap one-off first-use hitches; add their own `warmupMeshes` later if ever noticed.
- **The DoubleSide two-pass law is general, so the clone pass is general.** Per the gas entry, a
  `transparent`+`DoubleSide`+`!forceSinglePass` material renders as two `flipSided` passes = two programs,
  and `compileAsync` on the DoubleSide material compiles a `doubleSided` program the runtime never uses.
  `warmup()` traverses the built scene and, for each such material, adds explicit **FrontSide + BackSide**
  clone meshes — one pass covers windows, sprites, beams, sparks, everything, instead of per-module code.
- **Blending is render STATE, not a shader define** → not in the program cacheKey. So MeshBasic transparent
  DoubleSide no-map (beams / spark streaks / the player **ring**) all share ONE program, and the map variant
  (spark glow/flame) another. Warming beams+sparks covers ring and tactical for free.
- **Do NOT dispose the warm geometry.** Several geometries are shared static models / particle quads
  (`Models.instanced`, gas `quadGeo`); disposing them breaks the real build. The whole warm scene is
  retained in a static (`warmHold`) — three releases a program only on `material.dispose()`, so holding the
  materials keeps the programs cached. Cost: one throwaway city's geometry resident. Upgrade path if boot
  RAM matters: selectively dispose only the per-build `World.build` geometries (the safe ones).
- Textures need only be **assigned**, not decoded, for the correct program — `Textures.loadTexture` returns
  the `Texture` object synchronously, so warming at the menu (before any decode) still keys every `map`
  define right. **KHR_parallel_shader_compile is present** (measured), so `compileAsync` is genuinely parallel.

**Verified (measured, normal city):** first city entry compiles **7** programs vs the full lit set before
— 3 position/alphaTest `depth` (shadow cutout variants), 2 `MeshLambert` occlusion ghosts (deferred by
design — compile on first *fade*), 1 actor `DecalBatch` (`decalInstanceAlpha`, actor-side, compiles on
first blood/debris decal), 1 `MeshStandard` GLTF prop material (models load async; not decoded at the
300ms menu warm — timing-bound, not worth forcing model-load into the warm path). The whole expensive
MeshStandard bulk (buildings/windows/ground/roofs/walls/sprites) is warmed at the menu. **`(c)` progress
bar** from the ask is moot: with the warm moved off entry, entry is just the fast synchronous build, no
long black — nothing to put a bar on.

## Downtown area style (LANDED) — per-area render + gen split

Downtown (`AREA_CITY_HIGH`) now generates + renders distinctly from residential. Two split
points, both defaulting to the old behavior so LOW/MEDIUM stay byte-identical:

- **Gen:** `citygen.CityProfile` (typedef of every area-dependent knob) + `Profiles.DEFAULT`
  (verbatim old `CityConfig` values) + `profiles.DowntownProfile` + `Downtown.emitTower`
  (stacked concentric setback-tower massing, Option A — no `CityModel` change). `CityGen.generate`
  gained `?profile`; both call sites (`CityAreaGenerator`, `StreetView.show`) pass
  `Profiles.forDowntown(area.downtownGen)`. Persisted `AreaGame.downtownGen` bool (default false)
  keeps old-save downtown areas on the residential profile so their persisted `_cells` still match
  the render. **Measured headless (seed 1): default 226 buildings / maxH 30 / 0 tall (unchanged);
  downtown 43 buildings / maxH 113 / avg width 6.7 / 15 towers >60u.**
- **Render:** `render.world.AreaStyle` (texture sets + facade behavior) + `DowntownStyle`, threaded
  via `WorldCtx.style` from `World.build(?style)`. `DEFAULT` reuses the exact `TEXTURES` arrays +
  `RenderConfig` constants (identical refs → residential pixel-identical). Every render-side
  `b.facade == 3` "metal warehouse" test became `style.isSpecial(facade)` (`specialSlot` = 3
  residential, −1 downtown), so downtown facade-3 is a glass tower (windows + flat roof), not a
  gable warehouse. Downtown: unique plaza walkway + service alley tiles, glass curtain facades,
  **dark back-face material** on worn/buried faces (NOT geometry removal — keeps the merged shadow
  caster + Occlusion full-box invariants, see the caster entry above), `Roofs.addDowntownRoof`
  (thin coping ring + a mechanical-penthouse box **baked into the merged moon caster** like the main
  box). 10 new `textures/downtown/*` (1k, chroma-keyed glass window sprites).
- **Deferred (ponytail):** `warmup()` still warms only the DEFAULT style, so the first downtown
  city entry per GL context pays a one-off shader compile for the downtown-only materials (glass
  emissive / dark back / penthouse). Add a second `World.build(..., DowntownStyle.get())` warm pass
  (mirrors the existing 10-light second pass) if that hitch is ever noticed. Glass windows reuse the
  punched-window instanced placement (not an edge-to-edge curtain) over a baked mullion facade —
  upgrade to a dedicated Curtain placement if the spacing reads wrong.

### Follow-ups (iterated on feedback — LANDED)

Five reported issues, all fixed. Measured headless (seed 1496888906): downtown **38 → 109
buildings**, building tiles **793 → 2096**, alley coverage **52% → 39%**, 0 blank boxes; residential
unchanged (seeds 1/1337/99999 → 226/221/202).

- **(a) Tower shadows truncated ("too small"):** `MOON_SHADOW.distance` 120 → **200** (+ `far`
  260 → 400). The moon's up-offset is `distance * MOON_DIR.y (0.74)`; at 120 that put the light plane
  at ~89, **below** a ~113-unit full-glass tower top, so the shadow cast from a point above the light
  truncated. Ortho shadow quality is **independent of distance** (only `halfExtent`/`mapSize` set texel
  size), so this is free for residential. `halfExtent` left at 90 — a tower's ~102u shadow can clip at
  the box edge when far from the player; accepted.
- **(b) Empty blocks + no small buildings + tight spacing:** root cause — interior downtown boxes
  front only a 1-cell **alley**, and `hasOuter` (landlocked drop) counts road/walkway only, so every
  non-tower box was dropped and the block read empty (all survivors were `shapeKeep` towers). Fixes:
  `CityProfile.keepAlleyFront` (downtown) keeps any box that isn't fully buried (`notBuried`);
  `CityProfile.blockGap` (residential 1 → identical stream; downtown **3**) widens split gaps to real
  back alleys; downtown `minFloors` 6 → **2** + concrete/stone caps 16/14 → **12/10** so small
  footprints stay mid-rise (medium-city look); a **facade remap** on the existing single draw makes big
  footprints glass towers (2/3) and small ones concrete/stone mid-rises (0/1). Result: 80 mid-rises +
  29 glass towers.
- **(c) Full-glass skyscrapers:** facade 3 = new `downtown/facade-glass-full` (dense edge-to-edge
  curtain, tiles both axes) + residential 0/1 keep punched windows, so 3 reads as a glass wall vs 2's
  mullioned spandrel. `floorCap[3]` 30 (tallest).
- **(d) Penthouse punched through the setback shaft:** `addDowntownRoof` drew a mechanical penthouse
  on **every** tier's centre, but a lower tier's centre is occupied by the tier above. `Building.roofPenthouse`
  (new transient) — `Downtown.tryTower` marks all but the topmost tier false; only the top tier gets a
  bulkhead. Lower tiers keep their coping ring.
- **(e) Upper-tier windows clipped into the tier-below roof:** stacked ground-anchored tiers drew
  windows from floor 0, so an upper shaft's lowest exposed row sank into the setback deck.
  `Building.winFloorLo` (new transient) — `tryTower` starts each upper tier's windows just above the
  tier-below roofline (`round((prevH-GROUND_H)/FLOOR_H)`); `Windows.add` loops `winFloorLo...floors`.
  Also drops the buried hidden-window emission (perf).
- **warmup** now builds a throwaway downtown city into the warm scene (the deferral noted above is
  resolved), so the first downtown entry reuses cached programs (58 warmed, console clean).

### Glass-tower window scale + edge alignment (iterated — LANDED)

- **Symptom chain:** the baked glass curtain read at inconsistent scale between towers, and windows
  were cut mid-pane at the wall edges.
- **Why (scale):** wall tiling used `round(faceLen / WALL_TILE)` with `WALL_TILE=12` — only 1–2 tiles
  fit a 3–6-cell (12–24u) tower face, so integer rounding made the effective tile size drift 10–16u
  building-to-building (a ~20% scale mismatch). A first pass switched glass to exact `faceLen/tile`
  (constant pitch) — but a **non-integer** repeat then cut the texture mid-window at the edge.
- **Root tension:** faces are quantized to the 4u `CELL` grid. Whole windows need an **integer**
  repeat; identical scale needs constant pitch. Both hold only when pitch divides the cell, so the
  largest no-drift window pitch is **one window per cell (4u)**. Bigger windows on a 3-cell face force
  either drift or a cut — unavoidable.
- **Landed (cell-lock):** `AreaStyle.winPerCell` (per facade; downtown `[0,0,1,1]`). Glass slots tile
  `repeat_h = wholeCells × k` (integer → whole windows), `repeat_v = round(b.h/(CELL/k))`; pitch
  `= CELL/k = 4u`, **identical on every tower, zero drift**. `k=1` shipped. Non-glass + residential keep
  the rounded tiling (`winPerCell` null). Replaced the earlier `wallScale` exact-tiling stopgap.
- **Textures:** `facade-glass-1` (silver) + `facade-glass-full` (blue-grey) regen'd as **single-window
  seamless tiles** — one pane + half-mullion on each of the four edges, so integer tiling butts into a
  continuous grid with no half windows. Overlay window quads stay off on glass (`noWinSlots=[2,3]`);
  the window grid lives entirely in the baked facade.
- **Alternatives rejected:** round-to-whole-window (whole edges but ~30% pitch drift on narrow faces at
  big window sizes); instanced glass panels (guaranteed alignment via the existing per-floor system, but
  more instances on tall towers). Cell-lock chosen — only option with both exact alignment and no drift.

### Glass-tower window variety — sparse scattered accents (LANDED)

- **Why:** the cell-locked baked grid is uniform (every pane identical). Wanted per-window tint/texture
  variety + lit/glowing panes without losing the cheap baked base or the alignment.
- **Approach (sparse overlay):** keep the uniform baked tile as the base; `Windows.addGlassAccents`
  instances a *fraction* of the cells as tint/lit panes over it, on the **same** cell grid (repeat_v =
  `round(b.h/CELL)`, cell centres match the baked tiling exactly). Deterministic per-cell hash (stable
  frame-to-frame, no `Math.random` swim): ~6% lit, ~15% one-of-4 tint variants, ~79% stay base (no
  instance). Bucketed **per building** (`userData.b`) so Occlusion fades them with the tower; skips
  `isWornFace` faces (baked blank `facade-glass-back`). Lit = emissive+bloom (`glassAccentLit`, warm).
- **Style knobs:** `AreaStyle.glassAccents[4]` + `glassAccentLit` + `glassAccentRatio`/`glassLitRatio`.
  Textures: 5 new `downtown/glass-accent-{1..4,lit}` single-window seamless tiles (256²).
- **Why not the other two:** every-window instanced = full scatter but ~2–3× the instances (GPU) for a
  similar draw count; baked per-face canvas = zero extra draws but VRAM + build-hitch + most code. Sparse
  keeps the cheap base and adds only accent buckets.
- **Perf:** buckets are per-building-per-variant (Occlusion needs per-building meshes), so **~5 draws per
  glass tower** — same mechanism/scale as the residential window instancing already shipped, not free but
  in-band. **Measure `calls=` in a downtown area;** if it bites, atlas the 4 tints into one material via a
  per-instance UV/`instanceColor` to collapse the dark buckets to one (→ ~2 draws/tower).
- **Note:** `__check` counts glass towers + landlocked interior tiers as `winless` (no window *instances*
  — baked/interior). Pre-existing false-positive, unrelated to accents.

## Standing notes

- **three is vendored** as `electron/three.global.js`, built from `tools/three-entry.js` via
  `node tools/build-three.mjs` (**no `make three` target** despite the comment). Core objects
  (`BatchedMesh`) are already bundled via `export * from 'three'`; `examples/jsm` ones
  (`GTAOPass`, `mergeGeometries`) need an explicit export **and** an entry in the `REQUIRED` guard.
- **`Occlusion` is the constraint on every batching idea.** Buildings must fade independently, so any
  merge must stay inside one building, or ship an ownership map. `pick()` size-guards city-wide
  meshes out (they land in `__occ.skipped()`), and a `userData.b` tag overrides the guard.
- `addRoofDetails` uses `Math.random()` for the type shuffle and yaw, so roof furniture is **not**
  seed-deterministic (unlike `Debris`) and reshuffles on re-entry. Unexamined; may be intentional.

## Slime trail (LANDED) — free-parasite crawl ribbon + landing puddle

- **What:** `render/particles/SlimeTrail.hx`. Green slime ribbon behind the free (`PLR_STATE_PARASITE`)
  parasite as it crawls, plus a fading ground puddle on each leap on/off a host. Config in
  `RenderConfig.SLIME`, texture `textures/slime-trail.png` (chroma `#5a5d63`). Driven from
  `Actors.update` (one `slimeTrail.update` after `decals.paint`); puddles dropped in
  `startJumpOnFace`/`startLeaveHost`.
- **Chose hand-built triangle strip over `three.meshline`/`TubeGeometry`.** No MeshLine in the vendored
  three; the externs already have `BufferGeometry.setAttribute/setIndex` + `Float32BufferAttribute`, so
  the ribbon is one `Mesh` whose geometry is rebuilt each frame from a ~13-point position history
  (tail→head). No new bundle, no new extern. One draw call, ~26 verts — `submit` cost negligible.
- **Ribbon shape:** miter tangent = average of the two adjacent segment dirs (plain bevel at corners, no
  miter-length spike — safe on sharp turns). Width + **vertex-color alpha** both ramp 0→1 over
  `fadeCells` from the tail, so it necks to a point and dissolves; head stays full-width, glued under the
  parasite sprite. `uv.u` = cumulative path length in tiles → the slime texture tiles down the length
  (UV stretch on uneven spacing is fine, by design). Needs `vertexColors:true` + RGBA color attribute
  (three 0.181 applies vertex alpha) + explicit up-normals (flat strip, else black under lighting).
- **`frustumCulled = false`** on the mesh: geometry is rebuilt every frame so the cached bounding sphere
  goes stale; the mesh is tiny and always hugs the player, so skipping the cull is cheaper than
  recomputing bounds. Set `untyped` (not in the `Object3D` extern).
- **Occlusion:** the >guard-size ribbon lands in `__occ.skipped()` like the lamp cones — it will **not**
  wrongly fade, but also will **not** hide when the parasite ducks behind a wall. Accepted for a ground trail.
- **Render-only, NOT persisted** (no save fields). Trade-off: trail clears on host-entry / area-exit /
  reload; the puddle fades rather than lingering like a blood `SPLAT`. Upgrade path if a persistent puddle
  is wanted: drop a real slime `SPLAT` decoration (`ParticleSplat` row `ROW_SPACESHIP2`/`SLIME_LARGE`,
  already green-glow + save-safe) at the jump cell instead of `addPuddle`.
- **Verified:** builds clean; street view loads with no console error and no texture-fallback warning
  (module constructs + `update` runs every frame). The active ribbon/puddle path fires only when the
  player is a moving free parasite — **not** self-testable from CDP (no JS path to the live `Game`); needs
  an in-game detach-and-walk to eyeball.

### Follow-ups (iterated on feedback)

- **Head shape:** the flat leading cut read as a straight line under the parasite. Tried a round
  slime-blob sprite overlay glued at the head (rejected — didn't like it). Landed on a **width taper**:
  the head narrows to `headMinFrac` of full over `headFadeCells` (mirror of the tail taper but width-only,
  alpha stays full so the fresh end still reads). `headMinFrac` is the live knob: 0 = comet point, 0.35 =
  rounded nub (shipped), 1 = old flat cut.
- **Waviness:** each committed spine point stores a lateral **off** (random-walk, clamped to
  `waveAmpCells` — smooth meander, not per-frame jitter) and a **ww** width multiplier
  (`widthJitter`, irregular non-parallel edges). Stored at commit so they don't swim as the ribbon
  scrolls; the live head inherits the last committed `off` for continuity. `Math.random()` is fine here
  (render-only FX, not seed-sensitive).
- **Curb step (the real bug), final approach:** the ribbon bridged the `CURB_H` (0.2) road↔walkway step.
  Confirmed via `parasiteHx['render.world.WorldCtx'].floorY(col,row)` from CDP that floor height is correct
  (walkway cols = 0.2, road = 0), so the bug was purely how the strip spanned the step. Iterations:
  (1) per-point `y` sampled at each point's **own world pos** (`CityConfig.worldToCell` + `WorldCtx.floorY`),
  not the parasite's logical cell (which snaps mid-slide) — kept; (2) force a spine commit the instant
  floor height changes (`stepThresh = CURB_H*0.5`) so a point lands on each side of the curb — kept, keeps
  the rise sharp; (3) tried **breaking** the strip at the step — REJECTED, the gap read as the trail
  vanishing at the curb, and where it didn't fire a ramp clipped *into* the raised walkway ("goes under the
  walkway"); (4) **`depthTest:false` on the ribbon material** — SHIPPED. The curb can't occlude the trail,
  so it drapes continuously over the step drawn on top. Verified in-game (drove the parasite across a curb
  via CDP key-presses + screenshots). Trade-off: a foreground occluder between trail and camera (lamp post,
  wall corner) won't hide the trail — rare in the follow view, the parasite itself still draws over it via
  `renderOrder`.
- **CDP driving notes (for next time):** the wheel-zoom listener is gated on `game.ui.state==DEFAULT` +
  `!debug.on` (the objectives panel blocks it) — synthetic wheel events do nothing; don't fight it. Menu
  buttons are HTML but screenshot px ≠ CSS px (viewport ~1108 wide vs 1920 shot) — find buttons by
  `getBoundingClientRect`, not screenshot coords. Movement via `press_key` ArrowKeys works regardless.

## Downtown setback towers: window-grid alignment + tier survival (2026-07-22) — SHIPPED

Three defects reported from `BDump` dumps ("windows still partially in roof", "bldgs occupy same
space"). Diagnosed headlessly via `parasiteHx['citygen.CityGen'].generate(seed, DowntownProfile.INSTANCE)`
— no save load needed. Note `BDump` prints `facade` **by parity only** (`facade%2==1 ? 'brick' : 'plain'`),
so a dumped glass tower reads as "plain"/"brick"; check the floor count against `floorCap` to recover the
real slot.

- **(a) The setback deck sliced a window row — two mismatched vertical grids.** Height quantizes as
  `GROUND_H + f*FLOOR_H + TOP_MARGIN` (`4 + 3.6f + 1.2`); the cell-locked curtain wall tiles at
  `rows = round(h/CELL)`, pitch `h/rows`, anchored at `y=0`. The two grids share no common factor, so a
  tier's roofline landed mid-row of the tier above — **70 of 74 decks across 5 seeds cut a window**
  (`h=88` standing on `h=73.6` → deck at 18.4 rows). Fixed with `Downtown.glassHeight`: glass-tower
  heights snap to a whole number of `CELL`s, making the pitch exactly `CELL`, so the ground band
  (`GROUND_H == CELL`) and every deck land on a row boundary. `tryTower` emits snapped; a pass after
  `buildings = shaped` catches the plain boxes, courtyard strips and `finishP`-adjusted pieces. Heights
  only — footprints and tiles are untouched.
- **(b) `winFloorLo` was dead code.** Set by `tryTower`, read only at `Windows.add:68` — which bails on
  `noWinSlots=[2,3]`. And `tryTower` needs `minSide>=5`, which the facade remap always sends to slot 2/3,
  so **every tier is glass** (143/143 over 5 seeds) → the buried-floor suppression never ran once.
  Replaced the field with `Building.buriedH:Float` (the deck's world height, not a floor index) and taught
  `addGlassAccents` to start at `round(buriedH/rowH)`. Skips **~28% of all glass cell-faces** — they are
  enclosed by the tier below and never visible. Extreme case: 22 of one tier's 23 rows.
- **(c) Carves shredded tower stacks.** `carveCourtyard` and the L-turn road carve run `subtractRect` over
  *every* building in a block, tiers included, and `subtractRect` minted fresh `Building`s carrying only
  geometry — dropping `shapeKeep`, `winFloorLo`, `winForce`, `roofPenthouse`. Measured consequences:
  pieces became drop-eligible, lower tiers regained a penthouse that punches into the shaft above, and one
  rect cutting the whole stack along the same line left coplanar walls (4 pairs in seed 269197337).
  `reshapeLarge` already exempted `winForce`/`winBlock` pieces; `carveCourtyard` did not. Fixes: (1) skip
  the courtyard carve on any block holding a `shapeKeep` piece — the roll is still drawn so the stream is
  untouched; (2) `subtractRect` propagates the massing hints, gated on `b.shapeKeep`, which only tower
  tiers carry that early; (3) a pass after the road carves restores the ledge by pulling a tier in one cell
  on any face it still shares with the tier it rises out of.

**Verification.** Residential had to stay byte-identical: hashed `generate(seed)` output (footprint,
height, facade, winForce/winBlock, shop, shapeKeep, penthouse) over 10 seeds, `git stash`ed the change,
rebuilt, re-hashed — **all 10 hashes identical**. Downtown: 40 seeds / 1226 glass buildings / 467 setback
tiers → **0** unsnapped heights, 0 sliced decks, 0 coplanar tier walls, 0 orphan tiers, 0 ghost penthouses.

**Found but NOT fixed (pre-existing, downtown-only):** `subdivide` emits zero-area footprints under the
downtown profile (`w=0` or `d=0`, ~4 per city, facade 0/1, never tiers — residential produces none).
Most likely the wider `blockGap: 3` / `setback: 2`. Out of scope here; fixing it moves downtown layout.

## SHIPPED — Downtown: per-type spacing, podium + parapet bands, tower entrances (2026-07-22)

Seven follow-up defects on the same downtown pass.

- **(a) `blockGap: 3` spaced EVERY downtown building 3 cells apart** — only skyscrapers should get the
  ring; mid-rises should read as a medium city. Fixed without any post-pass trimming: `blockGap` goes
  back to the residential `1`, and a glass leaf insets itself `CityConfig.TOWER_CLEAR = 2` cells per side
  in `leaf()` before `tryTower`/`mk`. Gaps come out tower↔anything `2+1 = 3`, mid↔mid `1`, tower↔tower `5`,
  tower↔road `setback 2 + 2 = 4`. `keepAlleyFront` deleted (with `notBuried`) so downtown obeys the
  residential landlocked-drop / back-wall rule; `courtyardChance` → 0 because that branch runs *before*
  the tower branch and would bypass the inset.
  **Density trap:** the inset forces the glass threshold from `minSide>=5` to `>=5+2*TOWER_CLEAR = 9`, and
  at the old `maxBuilding: 14` / `earlyLeafChance: 0.15` almost no leaf is that square — measured **2.5
  towers per city**, down from ~30 glass pieces. Swept the two knobs headlessly (12 combinations);
  `16 / 0.7` restores **~9.6 tower bases + 11.2 setback tiers per city**. Worth remembering: leaf
  *squareness*, not block size, is what gates tower count.
- **(b) The parapet coping ate the top window row.** The coping ring sits `PARAPET_T/2 + E` proud of the
  wall and sinks `PARAPET_EMBED` into it, so it overhangs the top of a cell-locked grid that ran to the
  very top of the box. `glassHeight` now budgets `GLASS_CAP_ROWS = 1` extra row, drawn as an opaque
  spandrel band — which is what a real curtain wall does at the parapet.
- **(e) Bottom two floors are now a solid podium** (`GLASS_PODIUM_ROWS = 2`), same band machinery, new
  `downtown/podium-light|dark` granite art. Both bands are merged quads through `mergeBand` (extended
  with `baseY` + a vertical UV repeat `ry`), so they cost **one draw call each per tower** and keep
  `userData.b` for Occlusion. Podium is skipped on a tier with `buriedH > 0` (its base is inside the tier
  below). Both tile on the cell grid — podium tile 2 cells × 2 rows, cap tile 1 × 1 — so nothing stretches.
  Depth order on a tower face: wall `0` → bands `BAND_EPS 0.004 / offset -1` → doors `0.01 / -2`. The
  grime band is skipped on glass towers: at `eps 0` with `depthWrite:false` it would lose the depth test
  to the podium anyway, and the podium owns that band now.
- **(c)/(d) Roof decals.** `addRoofDetails` now skips any building with `roofPenthouse == false` — only
  lower setback tiers clear that flag, and their exposed deck is a one-cell ring, so a top-down decal ran
  straight into the tier wall above. And the penthouse placement moved into a pure
  `Roofs.penthouseRect(b, center, w, d)` so the detail pass can reserve the same rect and drop the sectors
  under it (decals were poking through the bulkhead).
- **(f)/(g) Tower entrances.** `Entrances` read `TEXTURES.doors` (a 3-entry masonry set) indexed
  `facade % 3`, so glass facade 2 got a stone door and facade 3 a concrete one — and downtown facade 1 is
  *stone* (`wall-3`) yet got the *brick* door. Door/worn/cover sets and a new `coverShape` (which cover
  geometry a facade uses) moved onto `AreaStyle`; DEFAULT reproduces the old `switch (di)` exactly. Glass
  towers get generated lobby doors + a shared steel service door + a flat metal canopy. The quad is now
  cell-locked for glass slots: a square `GLASS_PODIUM_ROWS * CELL` (= 2 cells × 2 rows, filling the
  podium) with its along-face offset snapped to cell boundaries, so it lines up with the window grid
  instead of floating at `DOOR_SIZE 3.9`.

**Verification.** Residential byte-identical again (same 10-seed hash / stash / rebuild / re-hash method —
all 10 identical). Downtown over 40 seeds: **0** clearance violations at either rule, **0** non-`CELL`
heights, min glass footprint side 3. Flush (`gap == 0`) pairs are excluded from the spacing scan — those
are attached pieces of one carved building, normal in residential too.

**Gotcha found while measuring:** a road/courtyard carve could leave a glass tower as a 2-cell-wide sliver
at 20+ storeys — a wall, not a building, and with its clearance ring gone (5 cases / 40 seeds). Now
dropped alongside the height snap. The zero-area-footprint bug noted in the previous entry is gone with
`blockGap: 3`.

## SHIPPED — Downtown: clearance vs the street, density, mid-rise stacks (2026-07-23)

Follow-up on the entry above: the uniform tower step-back was measurably wrong in three ways at once.

- **The step-back must not apply toward the street.** Insetting a tower on all four sides put a 2-cell
  ring of *alley* between it and the walkway. Fixed by threading an `edges` bitmask through `subdivide`
  (which of a rect's four sides are still the BLOCK's outer edge; a split clears the bit it created), and
  stepping back only on interior sides. A block edge already faces the road setback, so a tower now sits
  directly on the walkway like everything else. The glass test moved onto the POST-step-back footprint,
  which is also what let the two knobs come back down. Measured: **99% of tower bases touch a walkway.**
- **`setback: 2` was hiding the walkway.** A cell two out from a road is not road-adjacent, so
  `touchesRoad` classified it ALLEY — every downtown building sat one dead strip back from its pavement.
  Set to `1`, like residential. **100% of mid-rises now touch a walkway** (was 89%).
- **Downtown was mostly empty: 15.9% building / 47.3% alley** (residential 37.9 / 13.5). The two fixes
  above are most of it; result **43.7% building / 19.8% alley**, i.e. denser than residential, which is
  right for downtown. Tile-class histograms over 30 seeds are the cheap way to see this — a building
  count alone hides it completely.
- **`tryTower` ran for mid-rise facades too.** Facade 0/1 leaves were becoming setback stacks, and
  `tryTower` marks every piece `shapeKeep`, which exempts it from the landlocked drop — so stranded
  mid-rise wedding cakes survived fronting nothing but alley (11% of them). They also went through
  `Windows.add` (glass slots don't), which draws the punched grid from floor 0, so the windows ran down
  *inside the tier below* — the reported "windows intersect with roof". `tryTower` is now gated to
  `glassTypes`; mid-rises are plain boxes under the ordinary residential rules.
- **Degenerate tiers.** Tiers were emitted that rise one CELL above their deck — or *exactly* the deck
  height (invisible, coplanar roofs). For glass the entire exposed shaft was then the parapet cap row, so
  no glass showed at all. `tryTower` now enforces `h >= prevH + (GLASS_CAP_ROWS + 1) * CELL` and stops
  stacking once that pushes past the facade's storey cap. **0 starved tiers / 716.**

**`glassHeight` does not survive a round trip through its own output** — worth remembering. The
end-of-`generate` snap re-derives a floor count as `(h - GROUND_H - TOP_MARGIN) / FLOOR_H`, which cannot
see the `GLASS_CAP_ROWS` that `glassHeight` added, so re-snapping an already-snapped height inflates it
one row — **for all 29 valid floor counts, not an edge case**. Tower tiers were being inflated *after*
`buriedH` recorded the deck below, leaving every stack's deck off by a row (found because a dump showed
`buried=76` under a tier of `h=80`). The snap now skips `shapeKeep` pieces, which this early are exactly
`tryTower`'s (composites are tagged later, in `keepComposite`). Deck now matches exactly on **702/716**
tiers; the remaining 14 are tiers whose host was trimmed by a road carve so the tier overhangs its deck
by a cell — the known carve interaction, not inflation.

**Verification.** Residential byte-identical (same 10-seed hash method) after every one of these — the
`edges` parameter and the glass gate are inside `if (p.downtown)` / `glassTypes`, so no rng moves.
Downtown over 30 seeds: 0 starved tiers, 0 non-CELL glass heights, 100% / 99% walkway adjacency.
**Residual: 4 clearance breaks over 30 seeds** (~1 city in 8 has one pair of towers 1–2 cells apart),
all traceable to carve fragments. Left alone — enforcing it needs the trimming machinery the step-back
approach was chosen to avoid.

## SHIPPED — Downtown band scale + band z-fight (2026-07-23)

Two follow-ups on the podium/cap bands from the entry above, both reported from in-engine.

- **The bands tiled at their own height, not at the window pitch.** The podium quad is
  `GLASS_PODIUM_ROWS * CELL` = 8 tall and I set `rx = faceW / podH`, `ry = 1` — one texture tile
  spanning 2 cells × 2 rows, so the plinth stonework rendered at double the size of the panes directly
  above it and read giant. Both bands now tile at `CELL` on both axes (`rx = faceW / CELL`,
  `ry = h / CELL`), which is the window pitch, so the tile size is continuous up the facade. Cap was
  already right by accident (`capH == CELL`). The cell-locked entrance had the same bug by construction
  — `doorSide` returned `GLASS_PODIUM_ROWS * CELL`; now `CELL`, one podium tile, and ~the residential
  `DOOR_SIZE` 3.9 so it reads as a door again. `snapOff` needs no change: it steps by whatever `s` is.
- **`BAND_EPS = 0.004` z-fought with the wall as the camera pulled back** — flush-plus-`polygonOffset`
  is not enough, for the reason already written next to the shop bays: a pass that swaps the material
  (GTAO's prepass) drops the offset, and only a real geometric gap survives it. 0.004 held up close and
  lost at distance. `BAND_EPS = OVERLAY_EPS` (0.02) now, the same value the shop bays landed on. Doors
  have to stay in front of the band they sit on, so cell-locked entrances moved 0.01 → 0.03; residential
  doors are untouched at 0.01 (0.06 was measured as a visible gap there).

Third time this codebase has paid for assuming `polygonOffset` alone holds a coplanar overlay off a
wall. **If an overlay is coplanar with a wall, give it a physical gap.**

## SHIPPED — Downtown: parapet on the wall head (cap band deleted), aspect rule (2026-07-23)

**The whole `GLASS_CAP_ROWS` mechanism was solving a self-inflicted problem and is gone.** The
downtown coping ring hung `PARAPET_EMBED` (0.6) *over* the top of the wall, guillotining the top window
row; I paid for that with an extra CELL of tower height carrying an opaque spandrel band. Wrong end of
the problem. The ring's inner face is already exactly flush with the wall plane
(`wWorld/2 + T/2 + E` centre, `(T + 2E)/2` half-width → inner face at `wWorld/2`) and its footprint is
entirely *outside* the roof, so there is **nothing coplanar for the embed to protect against** — the
0.6 was pure inheritance from the masonry parapet, which is a genuine wall continuation. Downtown now
uses `embed = 0.05`, purely to kill a grazing-angle seam. The coping rides on the wall head, the top
row is a real window floor, and `GLASS_CAP_ROWS` / `AreaStyle.glassCap` / the cap `mergeBand` /
`glassHeight`'s extra row / the row clamp in `addGlassAccents` all deleted. `tryTower`'s minimum rise
becomes a plain `2 * CELL`. Bonus: with the embed gone, `glassHeight` is idempotent again, which was
the subtle bug in the entry above.

**MAX_ASPECT = 3 (longest:shortest footprint side), enforced in two places.** Reported case: a 2×15
mid-rise and a 3×13 tower tier. Three independent producers, so one fix was not enough:
- **The split.** `cut = x0 + 3 + rng() * (w - 6 - (gap - 1))` can leave a child **2** cells wide, not
  the ">= 3" its comment claims. Downtown now refuses to stop subdividing a rect over the ratio
  (`thin`, gated on `p.downtown` so the residential rng stream is untouched — `&&` short-circuits
  before the `earlyLeafChance` draw).
- **`tryTower`.** An inset eats the short side twice as fast in relative terms, so an oblong base
  reaches a slab in one step (5×15 → 3×13). Tiers now stop on ratio as well as on size. The base is
  tested too, so `tryTower` can now emit **zero** pieces and must return false — it was returning true
  with an empty `pieces`, which would have left a silent hole.
- **A final post-pass**, because neither of the above can see the real footprint: a square leaf still
  becomes a razor blade by stepping back (9×16 leaf → 5×16 tower) or by being carved (an L-turn road
  leaves a 2×14 strip). Over-ratio buildings get their long side trimmed; setback tiers can only be
  dropped, since trimming would slide them off their deck.

Measured, 30 seeds: **51 over-ratio buildings → 0, worst ratio 7.00 → exactly 3.00.** Cost is nil —
118.9 → 118.5 buildings/city, 43.2% → 42.9% building tiles. Tower health unchanged: 670/670 upper-tier
decks land on a window-row boundary, 0 starved tiers, 0 non-CELL glass heights, and no tower is so
short the podium swallows it (minimum 1 glass row above the plinth).

**`Check` was failing every downtown city — 57 of 107 "windowless".** Glass facades are in
`noWinSlots`: `Windows.add` skips them because the window grid is baked into the curtain-wall art, so
`winSeen` is never set for a tower and `expectWindows` fires on every one. `noWinSlots` now joins
shop/metal in `exemptArt`, which is the same idea — the art carries what the pass would have emitted.

## SHIPPED — Downtown: no back walls on high-rises, shape rolls re-enabled (2026-07-23)

**High-rises are windowed on all four faces — done in the RENDER layer, not citygen.** The obvious
implementation is `winForce = [0,1,2,3]` in the generator, and it is wrong: `Geom.frontInfo` bails to
"composite" the moment `winForce != null`, so **63% of downtown buildings would have silently lost
their storefront band** (and their `Check` doorless guarantee) as a side effect of a texture decision.
Built and measured that version before backing it out. It is now `AreaStyle.noBackWallsFloors` (6
downtown, 0 = off), read by `Geom.noBackWalls` and OR'd into the `forceWin` term in `isWornFace` and
`Windows.add`. Footprints, `frontInfo`, `Check` and the band all stay as they were. One trap in the
wiring: `Windows.add`'s inset-grid branch (`forced && b.winInset > 0`) has to keep keying off the
building's OWN `winForce`, or a tall courtyard strip's street faces get dragged onto the inner wall's
centred inset grid.

**The courtyard/L/T/+ rolls are back on downtown, at residential rates**, gated in `leaf()` to the
mid-rise infill (facade 0/1). A shape is built on the RAW leaf rect, so on a glass leaf it would throw
away the step-back that buys a tower its clearance ring — and the tiered massing is the point of that
facade. The `&& shapes` term is appended AFTER the `rng()` draw in each roll, so the draw still happens
either way. Result: downtown P/L/T/+ per city = 0.0 / 0.8 / 0.7 / 0.3 against residential's
0.2 / 0.6 / 0.9 / 0.3 — parity. Towers untouched at ~10 stacks (50.6 glass pieces, 40.9 upper tiers).

**Composite pieces are now exempt from the MAX_ASPECT and thin-footprint rules**, which the previous
entry's post-pass would otherwise have wrecked: a courtyard arm is deliberately 2 cells thick and a
T/+ stem is deliberately tall (`piece()` bypasses `mk`'s cap on purpose). They are not `shapeKeep` yet
at that point in the pipeline — `keepComposite` tags them later — so the pass builds an `ObjectMap`
from the group arrays and skips by identity. Object identity is sound here precisely because a carve
replaces a piece with a NEW `Building`, which `keepComposite` then drops the whole group for.

**Carve fragments kept their parent's height.** Reported: a 2×15 footprint 12 storeys tall. `mk` caps a
thin leaf's storeys by its short side, but an L-turn road carve slices a 6×6/12-storey box down to
2 cells wide and copies `b.h` across untouched. Same post-pass re-applies the cap to the final
footprint (tiers and composites exempt). Over 30 seeds: **0 non-composite buildings over the ratio or
over the thin-footprint storey cap**, worst ratio exactly 3.00. Residential is untouched throughout —
every gate is `p.downtown`, and it still measures 213.4 bldgs/city with identical shape counts.

## Mouse move-path preview + click-to-move (2D mouse support in 3D)

**Landed.** The old 2D area-mouse behaviour (`ui.Mouse`) now drives the 3D street view too: hover
re-paths, LMB moves/attacks the hovered tile, and the cursor art swaps move/blocked/melee/ranged/info
by the tile under it. `#streetview` (zIndex 1) covers `#canvas`, so `#canvas`'s own listeners never fire
in a city — the move/click listeners were added on the street canvas in `StreetView` and forwarded to
`game.scene.mouse`. `ui.Mouse` got a `street()` branch on three view-specific bits only: the tile pick
(`StreetView.pickCell` — unproject the cursor, intersect the ground plane at the player's floor, refine
once at the hit cell's own curb height; no `Raycaster`, the ground is a plane), the cursor's target
element (`#streetview` vs `#canvas`), and LOS (`game.scene.area.isVisible` reads the 2D tile cache,
which isn't maintained in 3D → fall back to `playerArea.sees`, same source `Actors.pickAI` uses). Every
attack/move/reach/targeting/forma rule is reused unchanged. `ui.Mouse` is ticked every frame from the
render loop because the camera + player move under a still cursor; its own stale-check (picked cell +
player cell) keeps that to one plane-pick when nothing moved.

**The preview ribbon** (`render.PathLine`) is one triangle-strip ground ribbon + a `RingGeometry` target
dot, both on a single HDR `MeshBasicMaterial` (`toneMapped:false`, green ×5 glow so bloom picks it up,
`depthTest:false` so it drapes over curbs and stays readable around corners — same choice as the slime
trail). The centreline is the pathfinder's cell list resampled at 6 samples/cell, offset by a scrolling
sine tapered to 0 at both ends (stays glued to the player + dot). **Waviness is host-control-driven**:
`amp ∝ (100 - hostControl)/100`, so full control (or a free parasite, treated as 100) draws dead
straight and losing control grows the wobble. Fed through the existing single funnel
`AreaView.updatePath`/`clearPath` (which every `Mouse` path call already routes through), so targeting
and forma modes clear it for free. **Cost: 2 draw calls** (ribbon + dot) only while a walkable tile is
hovered, both frustum-culling-exempt small meshes; geometry rebuilt per frame while visible (same
pattern + budget as `SlimeTrail`, which is also a per-frame strip rebuild). No new `submit` measurement
taken yet — it only draws during hover and is 2 unlit quads, well under the ~435-call follow-view
baseline; measure `calls=` before/after a hover in the follow view if it ever looks suspect.

## Downtown: brick high-rise removed, sleek modern high-rise added (facade 4)

**Landed.** Two coupled changes to the downtown facade set. **(1)** Brick/stone (facade 1) is barred
from high-rise height: `DowntownProfile.floorCap[1]` 10→5 and `maxFloorsBrick` 16→5 (both are needed —
the L/T/+ centre-strip path `CityGen.finishP` clamps to `maxFloorsBrick`, not `floorCap`). Brick still
generates, only ever as a short mid-rise now. **(2)** A 5th facade, `4 = 'sleek'` (white precast piers +
dark vertical glass ribbons, cool-white glow), added as the tall non-glass type. It is minted from the
existing `leaf()` facade draw with **no new rng** — the one remap line became `>= 5 ? 2 + facade % 3 :
facade & 1`, so a big footprint's draw `0..3` maps to `{2,3,4,2}` (glass-light 50% / glass-dark 25% /
sleek 25%). Added to `glassTypes`/`winPerCell`/`noWinSlots`, so it inherits `Downtown.tryTower` setback
massing, the cell-locked curtain-window grid, the podium band, and the cell-locked lobby entrance with
no new render code. All downtown `AreaStyle` arrays + `RenderConfig.FACADE_NAMES` extended to length 5.

**"No tint accents" (user choice):** `glassAccents[4] = []` (empty, non-null → the lit path still runs,
zero tint variants). This forced a one-line guard in `Windows.addGlassAccents` — the tint branch did
`(hv >>> 16) % nVar`, which is a modulo-zero crash when `nVar == 0`; now gated on `nVar > 0`, so an
empty accent set is lit-panes-only.

**Measured headless over 40 seeds** (`CityGen.generate(seed, DowntownProfile.INSTANCE)`): brick max
floors **5**, brick high-rise count **0** (was ~14.9/city), brick still 34.8/city. Sleek 13.1/city, of
which 11.6 high-rise and 10.3 `shapeKeep` setback towers, **0** non-CELL heights. Glass high-rise
33.5/city + sleek 11.6 ≈ the old 45/city — no net loss of tall buildings, sleek simply took ~25% of the
big-footprint slots off glass. **Residential untouched by construction:** the only `generate()`-reachable
edit is the one `leaf()` line, inside `if (p.downtown)`; every other change is downtown-profile or
render-only.

**Textures (1k, gpt-image-2):** `downtown/glass-sleek` (baked curtain), `podium-sleek`, `door-cover-sleek`
(opaque tiles), `entrance-sleek` (opaque, edited from the podium like the other lobby doors), and
`window-sleek-lit` (the scattered cool-white lit pane — `class:sprite needs_alpha`, currently baked
OPAQUE and warns until its window alpha is hand-cut; `alphaTest 0.5` is a no-op until then, so lit panes
glow the whole cell meanwhile — degrades cleanly). In-engine visual pass still pending (needs a downtown
area loaded): confirm sleek reads white-pier/dark-ribbon, podium solid, lobby entrance on-grid, no accent
crash, `window.__check` 0 fails.

## SHIPPED — Setback tiers start at their deck, not the street (2026-07-24)

`Downtown.tryTower` emits N concentric pieces, and every one of them was a **ground-anchored** box: a
tier's shaft ran all the way down through the tier below to the pavement. Invisible while solid, but two
artifacts fell out of it. **(a)** Each tier is its own `Occ` record with its own fade, so a sightline that
clipped the outer tier but missed the inner column left the outer see-through with a fully solid inner box
standing inside it. **(b)** `Occlusion` builds a plate + dashed footprint outline per building, so a faded
3-tier tower drew three nested dashed rectangles on the pavement.

Fix is render-side only — the generator already recorded the deck height in `buriedH`, it was just being
used for window-row skipping. `Buildings.build` now starts the box at `baseY = buriedH - CELL` with
`boxH = b.h - baseY`, and `Occlusion` skips the plate/outline entirely when `buriedH > 0`. The one-CELL
overlap below the deck matters twice: the box's bottom face would otherwise be exactly coplanar with the
roof it lands on (z-fight), and `buriedH` is a CELL multiple, so the cell-locked window grid stays on its
CELL boundary and the wall UV repeat stays integer. `wallH` and the merged shadow-caster bake follow
`boxH`/`baseY`.

Nothing else needed changing: the podium band was already skipped for `buriedH > 0`; `addGlassAccents`
places instances at absolute world Y and already skips rows below `buriedH`; grime is skipped for
cell-locked facades; `addGround`'s storefront band is skipped because tower tiers are `winForce`'d on all
four sides; and an inset tier's faces are never street-adjacent, so `Entrances` never doored them.

The `Occ` AABB is deliberately left spanning y `0..maxY` for buried tiers: over-reporting occlusion at
street level makes an inner shaft fade in step with the base tier it stands on, which is the reading we
want. Side benefit — the buried shaft geometry (~29% of a stepped tower's wall area) leaves the beauty and
depth passes.

## SHIPPED — Per-style facade names (Poly classes stopped lying) (2026-07-24)

No visual change; this is a **debugging trap** removed. Every Poly class string (`wall-$n`, `roof-$n`,
`storefront-$n`, `door-$n`, `door-cover-$n`) was built from the global `RenderConfig.FACADE_NAMES`
= `['concrete','brick','stone','metal','sleek']`, which is the RESIDENTIAL slot order. Downtown reuses
the same indices for different art, so slot 1 (stone, `wall-3.png`) was tagged `wall-brick` and slot 2
(`downtown/glass-light.png`) was tagged `wall-stone`. Two consequences: `Poly.info` is first-write-wins
across areas, so the UV editor reported the residential texture path for those classes; and
`Poly.tex['wall-stone']` held residential stone AND downtown glass-light, so one wheel-scroll shifted
both.

Cost of the lie, measured: chasing why `COVER_SLOPE_RISE` "did nothing" on a downtown setback tower.
`__dbg.find('door-cover-stone')` returned that tower's canopy, so the stone constant looked like the
knob — but `door-cover-stone` in downtown is facade 2, `coverShape 1`, a `BoxGeometry` of height
`COVER_METAL_H = 0.07`. The actual sloped cap on that seed lives under `door-cover-brick` (facade 1,
`BufferGeometry`, y extent = `COVER_SLOPE_RISE` exactly). `BDump` had the same bug from the other
direction (`facade % 2 == 1 ? 'brick' : 'plain'`).

Fix: `AreaStyle.facadeNames` (defaults to `FACADE_NAMES`) + `facadeName(f)`, used by `Buildings`,
`Entrances`, and `BDump` (which now prints `facade=<index>:<name>`, index first — the index is what code
keys off). Downtown declares `['concrete','stone','glass-light','glass-dark','sleek']`, so slot 1 now
correctly SHARES `wall-stone`/`door-stone`/`door-cover-stone` with residential (same art) while the glass
towers get their own classes. `Roofs.brickMats` still uses `FACADE_NAMES` on purpose: it is reached only
via `addParapet` (`!roofDowntown`), and it already hardcodes `RenderConfig.TEXTURES` for its texture path.

Caveat: any localStorage UV edit under an old downtown class name is now orphaned — `PolyMeta.OVERRIDES`
is empty, so nothing in-repo needed remapping.

## SHIPPED — Rooftop helipad decal on tall towers (2026-07-25)

A chance for a tall, wide downtown roof to carry a **centred helicopter landing deck** instead of its
mechanical penthouse + AC-clutter detail grid. New `downtown/helipad.png` (1k source → 512² opaque
tile): dark charcoal deck, grey circle + H, corner hatches, dim amber perimeter dots.

Wiring (style-driven, so residential/default is untouched — both new `AreaStyle` fields default to
off):
- `AreaStyle.helipadTex` (null = area has no pads) + `helipadChance` (odds an *eligible* roof gets one)
  + `helipadFacades` (facade slots allowed; null = any). Downtown sets `helipad.png` / `0.35` / `[2,3]`
  — the two glass **skyscrapers** only, NOT concrete/stone mid-rises or the sleek high-rise (facade 4).
  Restricted eligibility measured at ~13.8 tall roofs/city × 0.35 ≈ 4.8 pads (facade 2 ≫ 3, tracking
  the 50/25 light/dark tower split).
- `RenderConfig.HELIPAD_SIZE 16` (= 4 cells), `HELIPAD_MIN_FLOORS 12`, `HELIPAD_MIN_CELLS 4` (deck
  side, min tower height, min short-side cells). First cut used `MIN_CELLS 6` and produced **zero**
  visible pads: measured headlessly (`parasiteHx['citygen.CityGen'].generate(seed, DowntownProfile)`,
  12 seeds), tall `roofPenthouse` roofs by short-side cells were `{3:61, 4:102, 5:89, 6:50, ...}` —
  the ≥6 gate left ~11/city × 0.35 ≈ 3–4 pads spread across the whole map, and a setback tower's TOP
  tier (the only one with `roofPenthouse`) is usually 4–5 cells, so the widest natural candidates were
  all excluded. Dropping to 4 → ~27/city ≈ 9 pads. Pad side = `min(HELIPAD_SIZE, minSide - 2*margin)`,
  so a 4-cell top roof (16 world) gets a 12.8-wide deck filling it with a 1.6 margin ring.
- `Roofs.helipadRect(b,...)` — deterministic from the footprint (`(col*197+row*71)%100 < chance*100`),
  same pattern as `penthouseRect`, so `addDowntownRoof` and `addRoofDetails` agree on it with no shared
  state. Gated on `b.roofPenthouse` (only the top tier of a setback tower — a lower deck is a one-cell
  ring). Pad side = `min(HELIPAD_SIZE, minSide - 2*ROOF_DETAIL_MARGIN)`.
- A pad **owns the roof**: `addDowntownRoof` early-returns before the penthouse box when a rect exists;
  `addRoofDetails` drops one centred quad (`roof-helipad`, `userData.b` tagged for Occlusion) and
  `continue`s past the sector grid. One shared `padMat` city-wide.

Draw-call cost: one extra quad per pad building, in place of ~6–9 sector detail instances that were
already ~1 call in any street view (rooftops, follow cam is ~30°). Net ≈ neutral; **not re-measured**
(rooftop decals are off-screen in the follow/tactical cams the census uses — see the roof-detail
entries above). No new material permutation: `MeshStandard` opaque, same family as the detail decals.

Not verified in-engine yet (reload lands on the menu; needs a downtown save loaded to eyeball a pad).

## SHIPPED — Downtown swaps to the street-lamp2 (PBR) prop (2026-07-25)

Downtown now instances `models/street-lamp2.glb` (PBR: base + normal + metallic-roughness) instead of
the residential `street-lamp.glb`. Style-driven, so residential is byte-identical.

Lamps are placed once, citywide, in `SceneSetup.buildScene` (not per-`AreaStyle` before). It read
`RenderConfig.MODELS.streetLamp` + `LAMP_LIGHT` hardcoded. New `AreaStyle.lamp:LampProp`
(`{model, dx, dz, pdx, pdz}`, null = residential) carries **only the per-model placement geometry** —
which glb + where the bulb (`dx/dz`) and post (`pdx/pdz`) sit. `buildScene` gained an optional `style`
arg; `StreetView.buildFrom` now computes `areaStyle` before the call and passes it (moved up from after
`World.build`, which is where `WorldCtx.style` gets set — too late for SceneSetup).

**Why the light budget stays global (deliberately NOT per-area).** The live spotlights are a fixed pool
(`LAMP_LIGHT.pool = 12`, `LampLights`) sized to keep `NUM_SPOT_LIGHTS` constant so lit materials never
recompile. A per-area pool size would change that constant → full shader recompile on the downtown
transition, the exact hitch the pool exists to avoid. So the pool + shadow casters + bulb height
(`yMul`) + cone (`angle`) stay on `LAMP_LIGHT`, shared; only the model geometry is per-area. The two
lamps share `yMul 1.4` / `angle π/5`, so the pool spotlight sits at the right bulb with zero changes to
`LampLights` (bulb x/z are pre-baked into `lampPosts` at placement time; the pool just reads those).

Warm pass: `street-lamp2` is a distinct PBR material program, so `warmup()` instances one into the warm
scene (after the downtown `World.build`) — first downtown entry reuses it instead of compiling on frame
one.

Deleted the dead, incomplete `RenderConfig.LAMP_LIGHT2` (declared, **zero reads** anywhere — it was WIP
tuning: missing `pdx/pdz`, plus `markerVisible`/`tdx/tdz` which are dead on `LAMP_LIGHT` too). Its live
values (`dx 1.0, dz 0.0`) moved into `DowntownStyle.lamp`; post nudge starts from the residential kerb
(`pdx 2.0, pdz 2.6`).

**Placement offsets are WIP starting values — the arm geometry differs, so `dx/dz/pdx/pdz` need an
in-engine eyeball** (bulb over the road edge, post on the kerb). Verified the wiring headlessly
(residential `lamp == null`, downtown `lamp.model == street-lamp2`); NOT yet eyeballed in a loaded
downtown area.

**Fix: bake node transforms into geometry — street-lamp2's upright pose lived in a node quat, and
`instanced()` discards node transforms.** Reported "lying down"; several blind `rotateX/Z` corrections
only made it worse (one baked a `rotateX(π/2)` that put the pole on Z, so `normalize()` read
`height = size.y = 0.13` and scaled the model **48×** — the "huge" sprawl). Real cause, found by measuring
the mesh node (`o.quaternion`, `o.geometry.boundingBox`): street-lamp2's mesh carries a **90°-about-X node
quaternion** (`0.707,0,0,0.707`) standing up a raw geometry that is itself lying (`geomSize Z=1.128`).
`normalize()` measures with `Box3.setFromObject` (world matrices → sees it upright, height right), but
`Models.instanced` reads the **raw** `firstMesh().geometry` and builds transforms from scratch, ignoring
the node quat → it draws the lying geometry at the correct height (hence "size ok, lying down"). lamp1's
node is identity, so it never showed.

Fix in `Models.get`: after load, `updateMatrixWorld` then bake each mesh's `matrixWorld` into its
geometry (`geometry.applyMatrix4`, also transforms normals) and reset the node to identity. The verts are
then self-standing, so both the `instanced()` and `place()` paths are correct, and `normalize()` still
measures the same box. Identity nodes (lamp1) are a no-op. This is the general version of the
"instanced() assumes the mesh sits at the template root" caveat — now it's guaranteed at load.

## Slums area style + generator (LANDED) — per-area render + gen split, third variant

Third area variant after downtown, using the same two split points (`citygen.CityProfile` for
generation, `render.world.AreaStyle` for render). `AREA_CITY_LOW` now generates and renders as slums;
MEDIUM keeps the residential default and HIGH keeps downtown. New: `citygen.profiles.SlumsProfile`,
`render.world.SlumsStyle`, `render.world.Lawns`.

**Dispatch moved from a bool to the area type.** `Profiles.forDowntown(Bool)` /
`AreaStyle.forDowntown(Bool)` became `forArea(_AreaType)`, and the persisted `AreaGame.downtownGen` flag
was **deleted** — three variants do not fit one bool, and the type is already on the area. Verified an
existing autosave still loads (the stale `downtownGen` key in the save is simply ignored) and its
downtown area still renders with `__check.pass`.

**Two new facade slots (4 clapboard cottage, 5 cinderblock bungalow), single-floor.** `CityGen.leaf()`
remaps the ONE existing facade draw — `facade >= 2 && maxSide <= houseMaxSide` → `houseSlots[facade-2]`
— exactly like downtown's remap. **No new rng call**, so the seeded stream cannot shift. Single-floor
comes from `floorCap[4] = floorCap[5] = 1` (`mk()` clamps to it → `h = 8.8`), not from a special case.
A leaf that small can never reach the courtyard/L/T/+ branches (all need `w >= 7 && d >= 7`), so a house
is always a plain rectangle — which is what `addGableRoof` requires.

**Measured, 40 seeds, stash-rebuild-rehash against HEAD: the DEFAULT building list is byte-identical**
(hash of `col,row,w,d,h,roof,facade,shop` matched on all 40). Re-checked after the `houseMaxSide` tune.

**`houseMaxSide` is the knob that matters, and 5 was wrong.** Measured over 30 seeds:

| houseMaxSide | houses | stone (2) | metal (3) |
|---|---|---|---|
| 3 | 5.5% | 22.3% | 14.3% |
| **4** | **21.0%** | **14.3%** | **10.3%** |
| 5 | 35.6% | 6.9% | 5.3% |

At 5 the two house types all but wipe out stone and the metal warehouses — the district stops reading as
the same city. Landed on 4. Slums vs MEDIUM over 30 seeds: 231 vs 209 buildings, mean footprint 15.05 vs
17.39 cells, mean height **10.97 vs 15.09**, building tiles 34.8% vs 36.3% (alley 18.6 vs 17.1). Barrels
untouched — `courtyardBlockChance` deliberately left at the residential 0.35 because
`CityAreaGenerator.placeBurningBarrels` places one per carved courtyard (3.5 vs 3.7 courtyards a city).

**Lawns are a render-only pass, NOT a new `Tile`.** A fifth tile value would have rippled into the
persisted `_cells`, walkability, `WorldCtx.floorY`, `Ground.isLower`, `Debris.isStreet` and `Occlusion`.
Instead `Lawns.build` paints alpha-cutout quads over the *alley* cells ringing a house, gated by the same
footprint-hash idiom as `Geom.frontInfo` (deterministic, no rng). Measured: **1 mesh / 1 draw call**, 216
cells = 9.3% of the city's alley, 50.9% of eligible buildings; the downtown and residential styles emit
zero (null `lawnTex`). Walkway cells are excluded on purpose — they sit at `CURB_H` and some are
chamfered (`Ground.bevelAt`), so with `setback: 1` the lawns read as side and back yards. The mesh is
world-baked with no `userData.b` (it is ground, it must not fade with one building), so it correctly
shows up in `__occ.skipped()`.

**Four hardcoded facade assumptions had to become style fields**, all defaulting to today's behaviour:
`masonrySlots` (was `b.facade == 1 || b.facade == 2` in `Buildings`), `noStoreSlots` (folded into
`Geom.frontInfo` so `Windows`/`Entrances`/`Check` all agree), `gableSlots` + `gableRoofs` (the gable gate
was `isSpecial`, which also implies a roll-up door and no windows — the two had to be split, or a cottage
got a warehouse door). `addGableRoof` also took a `roofPath` and now names its Poly classes from
`style.facadeName` instead of the literal `'roof-gable-metal'`.

**Latent bug found: `Roofs.brickMats` indexed `RenderConfig.FACADE_NAMES[b.facade]` and
`TEXTURES.walls[b.facade]` RAW.** Harmless while every style had at most 4 masonry slots; with 6 slots it
reads past the end and tags materials `parapet-null` with an undefined path. Now style-driven and
modulo-wrapped. Same class of bug as the `facadeNames` lesson above — worth grepping for any other raw
`[b.facade]` indexing.

**Textures: all 19 generated, nothing borrowed.** Three slums grounds, both house walls + worn, the
shingle roof, the dead lawn, both window sets + lit, both door sets + worn, both door-cover swatches.
Every worn/lit variant was made with `edit_image` off its own clean base, not generated fresh, so the
palette matches across faces of one building — a separately-generated worn wall drifts in hue and the
seam shows at the corner.

**The doors and windows are chroma-keyed, NOT hand-cut — that is new for cutout art here.** The
residential doors/windows were hand-edited for alpha, which is why the pipeline only ever gray-keyed roof
details. Generating a door/window centred on a flat `#5a5d63` field and registering `class:"chroma"`
gets `make tex` to bake the alpha automatically, with no hand step. Two prompt rules make it safe at
`tol: 24`: state the exact hex and demand a hard edge with no glow/halo/drop-shadow (a soft falloff
leaves a grey fringe the key cannot resolve), and explicitly forbid medium neutral grey *inside* the
subject so nothing in the art falls within tolerance. Verified by measuring baked alpha coverage against
the prompt's stated geometry — doors 42-49% opaque against ~39% intended (door + casing), windows
20-27% against 16-19% — i.e. the key removed the field and nothing else. Worth doing this way for any
future cutout that is a discrete object on a background; it does not suit art that must bleed to the
tile edge.

**Not yet eyeballed in a loaded slums area.** Coverage so far is `StreetView.warmup()`, which now builds
a throwaway slums city at boot: every slums render pass (slums ground, facades 4/5, the gable roof,
`Lawns`, entrances, windows) executed with zero console errors and no `[textures] missing` warnings. The
open questions a real walk-through has to answer are the ones the numbers cannot: whether the two house
types read as distinct at street distance, whether `winCrop` frames each new sash correctly (it sets the
pane's aspect via `winH = WIN_W * y/x`), whether the porch/awning covers sit right on an 8.8-unit wall,
and whether the lawns land thick enough at `lawnChance 0.5` on alley cells only.

---

## Flat-roof dressing leaked under the slums gable (LANDED)

Reported from a loaded slums area: clapboard cottages had contact shadows and detail decals on their
roofs, mostly buried under the gable slopes.

`addRoofShadows` and `addRoofDetails` both gated on `style.isSpecial(b.facade)` — "is this the metal
warehouse", which used to be the only gabled slot. Adding `gableSlots` gave the style a second way to
be gabled, and neither pass knew about it, so the cottages kept the flat-roof dressing their buried box
top nominally has. Wasted geometry, and it pokes through the slopes at grazing angles.

The gate is now `Roofs.isGabled(b)` (`b.shop < 0 && style.isGable(b.facade)`) in both passes, and
`Buildings` derives its own `gable` from the same helper — the three had to agree and were three
separate expressions. Folding `b.shop < 0` in also fixes a latent case the old gate got backwards: a
warehouse downgraded to a single-story shop gets a flat parapet from `Buildings`, but `isSpecial` was
skipping its shadows, so it had a parapet casting nothing.

Measured on the live slums save (245 buildings, 23 gabled cottages + 23 warehouses) by re-running both
passes into a throwaway `THREE.Scene` and testing against the gabled footprints: **0** detail decals
tagged to a gabled building (674 remain citywide), **0** of 1592 shadow instances inside a gabled
footprint at its roof height. The lesson generalises: any pass keyed on `isSpecial` is really asking
"does this slot have a gable", and needs re-reading whenever a style adds a roof shape.
