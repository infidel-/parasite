# 3D render: how to measure, and what every experiment concluded

**Read this before proposing or starting any render change.** It is the index and the standing rules;
it is meant to stay small. The full write-up of every experiment — landed, reverted or rejected, with
its numbers and its traps — lives in [`3d-changes.md`](3d-changes.md). Find an entry there by grepping
the heading named in the verdict table below.

**Appending after you try something:** write the entry in `3d-changes.md`, add **one row** here. The
row is the index; an entry with no row is invisible. Keep entries to ~25 lines — what changed, the
measured numbers, the trap, the verdict. Record settled outcomes only: no `IN PROGRESS`, no `pending`,
no "checked X and it was clean". If it is not settled, it is not an entry yet. When a new entry
invalidates an old one, mark the old heading `> SUPERSEDED by <heading>`. When `3d-changes.md` reaches
~2600 lines, `git mv` it to `3d-changes-<YYYY-MM>.md` and start a fresh one.

## Baselines

All numbers come from one of two machines, and **most of the guidance inverts between them**:

- **RTX 3050**, 60fps cap, 1080p-ish, `vidAntialias=4`. `submit`-bound: the CPU draw-call wall is the
  ceiling and a better GPU does not move it.
- **Integrated Vega** (`AMD Radeon(TM) Graphics 0x1638`), added 2026-07-28. **Fill-bound**: `GPU=`
  exceeds `submit=`, `calls` do not move with window size, and draw-call work is not the lever. See
  "the frame is GPU-bound on an integrated Radeon" in the log before applying anything here to it.

**Which view a number came from matters more than the number.** Gameplay is a zoom lerp, not a set of
modes (`RenderConfig.CAMERA`, `CameraRig`): zoom 0 = close, ~30° above ground; zoom 1 = top-down.
Resting targets are capped (`parasiteZoom: 0.30`, `hostZoom: 0.60`) and `tactical` is pinned at 1.0.
Measured across views and spots, **gameplay runs 158–288 calls**. Separately, the street-debug
**free-cam** (backtick) can go fully parallel and render the whole city — ~230 buildings — which no
gameplay camera does. It is a dev tool; the two-tier merge lead below is the only entry targeting it.

## How to measure (and how not to)

- **`calls=` in the `[street-render]` trace is the only draw-call number.** Enable the `perf street`
  console toggle (`render.Actors.DEBUG_PERF`) or street-debug mode (backtick). The trace is emitted
  by `StreetPerf.hx:228` (`frame=/GPU=/submit=/upd=/idle=/calls=/tris=/programs=/shdw=/heap=`).
- **The scene dump (`9`) is an INVENTORY, not a draw list.** `visibleDrawables` counts objects whose
  `visible` chain is true — frustum culling then discards most of them. Real ratio measured here:
  **1616 visibleDrawables → 435 calls**. A big number in the dump means nothing until you confirm
  those objects survive culling. Two failed experiments came from reading the dump as draws.
- **`submit` is the CPU draw-call wall** — time inside `composer.render()` (scene walk + issuing
  draws + any driver blocking). `upd` (engine CPU) is ~1ms and irrelevant. `GPU=` is a real timer
  query (`EXT_disjoint_timer_query_webgl2`). Compare the two before assuming which wall you are on:
  they sit at `4.75` vs `4.66` with AO off, but AO flips the frame GPU-bound. "Submit is the wall" is
  the default, not a law — and on the iGPU it is simply false.
- **Always A/B against a measured baseline in the same view.** Both `follow` and `tactical` — they
  differ (tactical draws ~80 more calls and ~2ms more submit).

### Measuring on a weak / integrated GPU

The numbers lie unless you do all of this — every rule here was paid for by a wrong conclusion:

- **Pin the camera.** `render.Tools.freeCam` is a static, so
  `parasiteHx['render.Tools'].freeCam.lookFrom(...)` reproduces an exact frame across reloads *and*
  rebuilds (verified: 209/210/211 calls, 104,480/104,482/104,484 tris across three builds).
- **Interleave A/B/A/B and take the MEDIAN.** Means get destroyed by outliers — one run turned a real
  −19% win into a bogus −7% loss.
- **Warm the shader permutations first.** Keys `5`/`7` change the program key; the first toggle
  compiles a fresh set inside your measurement window. `(COMPILE)`-tagged trace lines are filtered.
- **Never compare across sessions.** An integrated Radeon switches power state mid-run: the identical
  pinned frame was measured at both 11.61ms and 4.06ms. Shares (`1 − off/on`) survive clock drift;
  absolute ms do not.
- **The game window must be FOCUSED and in the foreground.** Backgrounded, the compositor throttles to
  ~1fps and the timer query spans the whole idle gap, so `GPU` reads ~**1015ms** and an A/B comes out
  *inverted*. Any scripted sweep should filter samples (`GPU < 100`) and check the topbar fps.
- **Verify the thing the system is actually keyed on.** The lamp pool keys on distance to the PLAYER,
  so a free-cam-only screenshot A/B cannot see what lowering it costs — and nearly shipped a bad default.

### Attributing every draw call (the census)

`calls=` gives a total but not a culprit. To get the real per-object breakdown **without touching
shipped code**, patch from CDP (`three.global.js` exposes `window.THREE`):

- `Object3D.prototype.onBeforeRender` fires once per **post-cull** draw (`WebGLRenderer.js:2014`) —
  the only honest "what actually drew" list. Its first arg **is the renderer**, which is the one way
  to reach the live renderer from JS (`parasiteHx` is statics-only).
- Wrap `renderer.renderBufferDirect` (an **instance** property, `WebGLRenderer.js:1104`, not on the
  prototype) and read `renderer.info.render.calls` before/after each call — the delta attributes
  draws exactly, instead of assuming one call per object.
- Classify by the `scene` arg: `null` → **shadow pass** (`WebGLShadowMap` calls `renderBufferDirect`
  directly and never fires `onBeforeRender`, so shadow draws are invisible to the object hook);
  `scene.isScene === true` → main scene; anything else → **post fullscreen quad**.
- In the shadow pass `material` is the depth override — read `object.material.userData.cls` for
  identity. In the main pass `onBeforeRender` receives the **group's** material, so multi-material
  walls attribute per face (better than the dump).
- Wrap the body in `try/catch`: an exception inside the wrapper propagates into the render loop and
  silently yields an empty census.

Measured this way, **tactical = 513 calls: 175 shadow / 324 main / 14 post**.

## Verdict table

Bodies in [`3d-changes.md`](3d-changes.md) — grep the change text.

### Perf and render engineering

| change | result | verdict |
|---|---|---|
| `flattenBox` + `mergeBand` | 10,595 → ~3,000 calls free-cam, 6 → 30fps | **landed** `6a20c75` `8240e4d` |
| MSAA via composer render targets | real AA, was previously absent entirely | **landed** `729c064` |
| Parapet ring merge per building | 583 → 436 calls, submit 10 → 7.3ms | **landed** `1183cff` |
| Ghost overlay capacity fix | fixes a hard `RangeError` crash | **landed** `5a6ae04` |
| `forceSinglePass` on decal materials | 513 → 458 calls (−11%), no visual change | **landed** |
| Merged city-wide shadow caster | shadow pass 175 → 16 calls | **landed** |
| ^ the two together, measured in-game | calls −44/−52%, **submit −25%**, +2ms idle | **landed** |
| Decals sample the atlas (per-instance UV rect) | 55 → **2** decal calls; 210 → 158 total | **landed** |
| `allowOverride:false` + `OVERLAY_EPS` | fixes 2 invisible-until-AO-on z-fight bugs | **landed** |
| GTAO ambient occlusion | +140 calls, +5.4ms GPU; flips the frame GPU-bound | **landed, default OFF** `870d0f8` |
| Roof-detail material hoist | ~750 → 6 materials; **0 draw calls** | **landed** (hygiene only) |
| Corpse-vs-blood: `depthWrite` + per-cell Y slots | killed the flip, bought per-pixel z-fight flicker | **reverted — worse** |
| Corpse-vs-blood: `renderOrder` tiers | stable layering, extra draw only in corpse cells | **landed** |
| Wall graffiti vs doors: door-span overlap skip | decals no longer clip doors | **landed** |
| Gas-burst shader pre-warm (4 programs) | first burst 167ms spike → **0 new programs** | **landed** |
| Boot pre-warm at the menu | first city entry ~2s black → **7** programs | **landed** |
| Actors + ground decals `receiveShadow` | `receiveShadow` is a UNIFORM: no recompile, no call delta | **landed** |
| Window light switches (scale-0 stand-in) | calls 151 → 151, +37 meshes, lit ratio stationary | **landed** |
| Object marks: tactical ring + through-wall x-ray | **+1 call, +2 tris** per marked object surviving cull | **landed** |
| iGPU is FILL-bound, not submit-bound | `GPU 11.2 > submit`; calls flat as the window grows | **diagnosis — inverted the ranking** |
| GPU-side A/B keys `V` / `Shift+1` / `Shift+5` | isolates render scale, bloom alone, cones alone | **landed** (permanent) |
| Render scale (`vidRenderScale`, default 100) | 1.25 → 1.00 = **−29% GPU**, zero visual change | **landed** |
| `LAMP_LIGHT.pool` 12 → 6 as a new default | −19% GPU but spends a tuned art value | **reverted** |
| ^ shipped as `vidLampLights` (Off/4/8/12, def. 12) | linear **0.32ms per light**; Off = −42% | **landed** |
| **MeshStandard → MeshLambert on city surfaces** | **−42% GPU**, calls/tris unchanged | **landed — largest win here** |
| `vidBloom` (Off/On, default On) | −3.1…3.4ms (22–24%), calls 151 → 138 | **landed** |
| AO pass was sized in CSS px | wrong AO resolution once render scale shipped | **fixed** |
| Re-attribution after Lambert | floor 32% / spots 31% / bloom 25% / shadows 15% / cones 0% | **current ranking** |
| Shadow box size (`MOON_SHADOW.halfExtent`) | best safe win ~21 calls; coverage-bound below 75 | **not a lever** |
| BatchedMesh for roof details | **+4 calls, +2ms submit, −3ms idle** | **reverted — worse** |
| Atlas the WALL textures like the decals | walls tile; an atlas cannot wrap inside a sub-rect | **rejected — wrong tool** |
| Texture array for walls (3 calls/box → 1) | ~20 calls in one sample; enables the static merge | **open lead, unmeasured** |
| Two-tier static city merge | ~3k → ~200 calls **in the debug free-cam only** | **open lead, deferred** |
| Bloom as Off / Low / High | needs the pass rebuilt; raising the threshold saves nothing | **rejected** |
| Pull the fog / view distance in | shorter sightlines — look/feel | **rejected** |
| Per-building merges of doors / covers / roof furniture | low ROI; doors are ~5 calls in view | **rejected** |
| AgX / Neutral tone mapping | look rejected | **rejected** |
| `reversedDepthBuffer` | flips custom `depthFunc`/decal offsets; doors vanish | **rejected** |
| Distance-cull far detail | parapets are the roofline silhouette — pops | **rejected** |
| SSRPass (reflections) | style rules ban glossy/specular reflections | **rejected** |
| `RenderPixelatedPass` | total aesthetic pivot, not an enhancement | **rejected** |
| `forceSinglePass` on `LightCone` as a perf item | cones measure 0% of the frame, twice | **rejected as perf** (valid hygiene) |

### Area styles, city gen and art

| change | result | verdict |
|---|---|---|
| Downtown style + generator (`AREA_CITY_HIGH`) | `CityProfile` (gen) + `AreaStyle` (render) split; 43 bldgs / maxH 113 | **landed** |
| Downtown iterations (spacing, podium/cap bands, clearance, entrances, aspect rule, no back walls, shape rolls) | 6 successive passes; residential byte-identical throughout | **landed** |
| Glass-tower cell-locked window grid (`winPerCell`) | whole windows + zero pitch drift; pitch = `CELL` | **landed** |
| Glass-tower sparse accents (tint/lit panes) | ~5 draws per glass tower | **landed** |
| Setback tiers start at their deck (`buriedH`) | kills nested fade outlines; drops ~29% of buried wall area | **landed** |
| Sleek facade 4; brick capped to mid-rise | 13.1 sleek/city, brick high-rises 14.9 → 0 | **landed** |
| Per-style facade names (`AreaStyle.facadeNames`) | removes a Poly-class debugging trap; no visual change | **landed** |
| Rooftop helipad decal on tall towers | ~1 quad per pad, replaces the detail grid; ≈ neutral | **landed** |
| Downtown `street-lamp2` PBR prop | + `Models.get` bakes node transforms into geometry | **landed** |
| Slums style + generator (`AREA_CITY_LOW`) | third variant; `houseMaxSide 4`; DEFAULT byte-identical over 40 seeds | **landed** |
| Slums pass 2: barrels, dark shopfronts, broken lamps | barrels 1.52 → 6.44/city; dead lamps cost +1 draw call | **landed** |
| Lamp outages: flicker cones, dead lens, blackout | per-frame instance repack + baked `deadMap`; **+1 mesh** | **landed** |
| Gable roofs overhang, slopes become thin slabs | draw calls unchanged, tris/roof 4 → 20 | **landed** |
| Flat-roof dressing leaked under the slums gable | `Roofs.isGabled` gate; 0 stray decals/shadows | **landed** |
| Dead lawns: tighter repeat + vertex-alpha fringe | fixed visibility; borders still cell-shaped | **superseded** |
| ^ round outlines via a baked coverage `alphaMap` | 5688 → 2100 tris, still 1 mesh / 1 draw call | **landed** |
| Slums masonry fronts get their own art | 3 tiles edited off the residential base | **landed** |
| Wall decals: albedo tint, shadow receipt, per-image classes | 2–3.5× too bright → `WALLDECAL_TINT`; fixes an editor crash | **landed** |
| `CityStyle` extracted; textures sorted `city/decals/fx` | no visual change; 144/144 texture paths verified | **landed** |
| Weeds in medium courtyards | 4 style knobs + 1 texture, zero render code, 1 draw call | **landed** |

### FX, UI and the view itself

| change | result | verdict |
|---|---|---|
| Slime trail (crawl ribbon + landing puddle) | hand-built strip, **1 draw call**, ~26 verts | **landed** |
| Mouse move-path preview + click-to-move in 3D | **2 draw calls** while a walkable tile is hovered | **landed** |
| Rename `StreetView` → `render.View`, `#streetview` → `#view` | pure rename, no render change | **landed** |
| `vidBrightness` (50–150%, default 100) | exposure is a per-frame uniform: no recompile, no re-assert | **landed** |
| Lobbed projectiles (`arc`) + a `'blood'` projectile type | 3 extra sprites per swing on the existing pooled batch | **landed** |

## Standing notes

- **three is vendored** as `electron/three.global.js`, built from `tools/three-entry.js` via
  `node tools/build-three.mjs` (**no `make three` target** despite the comment). Core objects
  (`BatchedMesh`) are already bundled via `export * from 'three'`; `examples/jsm` ones
  (`GTAOPass`, `mergeGeometries`) need an explicit export **and** an entry in the `REQUIRED` guard.
- **`Occlusion` is the constraint on every batching idea.** Buildings must fade independently, so any
  merge must stay inside one building, or ship an ownership map. `pick()` size-guards city-wide
  meshes out (they land in `__occ.skipped()`), and a `userData.b` tag overrides the guard.
- **Batch only geometry that survives culling.** `BatchedMesh` frustum-tests every instance on the CPU
  each frame, so batching mostly-culled objects is a pessimization; an off-screen `InstancedMesh` is
  one bounding-sphere reject.
- **Per-call cost is not uniform.** Shadow draws are depth-only and averaged ~9.5µs against ~23µs for
  the survivors. Never convert a call count into a `submit` estimate.
- **An object that renders correctly only because of a material flag is a bug waiting for the next
  override pass.** `scene.overrideMaterial` replaces the material outright and drops `colorWrite`,
  `depthTest` and `polygonOffset`. Prefer real geometric separation, or `allowOverride: false`.
- **If an overlay is coplanar with a wall, give it a physical gap** (`OVERLAY_EPS`). `polygonOffset`
  alone has failed three times.
- **Anything that mutates an instance buffer after build must tell the `Occlusion` ghost** — the ghost
  is a snapshot taken at first fade, and it is the copy that draws while the real mesh is hidden.
- **A "turn it off" effect has to turn off every source.** A lamp has four: the pooled `SpotLight`, the
  additive `LightCone`, the fake ground shadow, and the glb's **emissive head** (independent of every
  light in the scene, and it feeds bloom directly).
- **`receiveShadow` is a uniform; `castShadow` is baked into the program key.** Flipping the first is
  free per-frame. Do not generalise from one to the other.
- `addRoofDetails` uses `Math.random()` for the type shuffle and yaw, so roof furniture is **not**
  seed-deterministic (unlike `Debris`) and reshuffles on re-entry. Unexamined; may be intentional.

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

**Read the scope line first:** this targets the **street-debug free-cam at a parallel angle**, the one
view that renders the whole city. The goal was making that dev view usable, not player framerate.

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

### The floor — 32% of the frame, never attacked

Raw texture bandwidth, overdraw, the two RGBA16F composer targets and the `OutputPass` blit, measured
with all lighting and post off. Invariant across lamp counts (4.69 at pool 12, 4.55 at pool 0), which
is what makes it a real target rather than a measurement artefact. Suspects: stacked transparent
overlays (grime, wall decals, storefront bands and doors all draw *over* the wall via `polygonOffset`,
each a full lit fragment pass), and the FP16 composer target format. **No existing debug key isolates
overlay overdraw** — that instrumentation is the first step.
