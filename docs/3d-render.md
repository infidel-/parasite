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
| 3D sewers (`AREA_SEWERS` + `AREA_HABITAT`) | `Area3D` seam; tunnels from the SAVED cell grid, no seed; **30 calls / 5.4k tris** per level | **landed** |
| ^ sewer fill at city intensities | renders **black**, not dim — fill IS the frame with no moon; needed ~4× against the near-black first art | **trap — see the entry** |
| ^ 16-cell chunking for sewers | 4× the calls to buy culling that saves no fill; nothing fades down there | **rejected — dropped from the plan** |
| ^ sewer pre-warm in its OWN `SewerScene` | boot 64 → 68; entry still **+7** (city's own first entry is +6) | **landed, partial** |
| `AreaView.draw` early-out on a 3D area | full tile pass + LOS + minimap regen were running under the WebGL canvas | **landed** |
| Sewer art restyled to the 2D tileset (`app/img/sewers.png`) | warm rose-brown varied masonry + moss + pale cracked floor; `WALL_H` 6→3 | **landed** |
| ^ retuning albedo-compensating fill on the **sRGB** mean | 127.5/51 = 2.5× vs **6.66×** in linear — would leave it 2.7× too bright | **trap — always ratio in linear** |
| ^ albedo ratio as the fill ANSWER | holding old brightness = ambient 1.13, too dark to read the new detail; swept live → **3.95 / 1.89** | **landed (ratio is the floor, not the answer)** |
| ^ `markChannel` = "8-neighbourhood all floor" | true of every interior cell of any open space → flooded the habitat with sludge; needs a 3-wide test | **fixed — 8% of cells** |
| ^ capping only the solid cells touching floor | interior/diagonal solids left holes through the WALL_H plateau; cap every solid cell | **fixed** |
| Diagnosing dark patches by eyeballing a JPEG A/B | "looks lighter with shadows off" — sampled luma was byte-identical; blamed wall `castShadow`, reverted | **trap — sample pixels, tint meshes** |
| Two wall tile variants picked per cell (sewers) | **47% of cell boundaries seam**, median run 1 cell; no blend fixes it (block layouts differ) | **rejected — one base + overlays** |
| ^ `SewerDetail`: grime band + wall/floor contact shadows | `RoofShadows` minus the parapet-span derivation; gradients are canvas-drawn, **zero art**; +3 calls | **landed** |
| ^ `Textures.loadRampTexture` revived (was dead code) | bakes the vertical fade into an opaque tile at load → grime source needs **no hand-cut alpha** | **landed** |
| Sewer warm scene had no `MuzzleLights` pool | `NUM_POINT_LIGHTS` 5 vs 0 keyed every lit material → entry **+10 → +5**, all lambert gone | **fixed (pre-existing)** |
| Contact shadows `FrontSide` vs `DoubleSide` | transparent DoubleSide = two single-side passes → **36 → 34 calls**; program count unchanged | **landed** |
| ^ wall detail decals, merged per image | 19 on 104 faces (18.3%); 4 calls not one-per-decal (no `Occlusion` to fade them) | **landed** |
| **Sewer wall FACES are 0.67% of the view; ledge TOPS 14.68%** | at `WALL_H` 3.0 + top-down cam, 22× more ledge than wall — decals/grime paint <1% of frame | **dress the tops too — one pose, not a verdict on walls** |
| ^ that 0.67% is the FAR camera | `CAMERA_SEWER.near` is ~53° (faces plainly visible); tactical pins zoom to `far` ~70°, the view where faces matter LEAST | **`WALL_H` stays 3.0** |
| `SewerGround`: ledge rim darkening | reached **5.83%** of the view (vs the wall decals' 0.12%) and still looked wrong — **nothing stands above a wall cap**, so it is a stripe floating over a BRIGHTER face, hard edge on the silhouette flickers | **rejected — removed** |
| ^ what that taught | % of frame changed is a REACH number, not a quality one — a big reach makes an unmotivated effect worse | **standing note** |
| Capturing the scene while the window is backgrounded | throttled to ~1fps, so a 500ms `onBeforeRender` capture returns nothing and reads as "mesh missing" | **trap — capture ≥2.5s** |
| ^ `SewerGround.scatter`: ledge clutter + floor decals | 8 top-down images, hash-placed per cell, merged per image → **39 → 47 calls** for a whole level | **landed** |
| ^ DARK art on a lighter surface | puddle core **1.7 vs the walkway's 43**; valve **6.7 vs the cap's 35** (0.46x in bytes = **0.19x in LINEAR**) — reads as a hole | **translucent art → `alpha`; SOLID props → new `lift` gamma in textures.json** |
| Sewer LOS (`SewerMask`): world-XZ vision mask folded into the fog | the 2D visibility polygon in cell units, baked to a canvas, sampled per material; **0 calls, 0 passes, 0 geometry**, weld intact | **landed** |
| ^ a PER-CELL mask | `sees()` takes INTEGER endpoints, so it is quantised to the player's cell and no smoothed origin can move it; no diagonal corner shadow | **replaced by the polygon** |
| ^ `userData` as the "already patched" flag | `Material.clone()` copies userData but NOT `onBeforeCompile`/`customProgramCacheKey` — every ghost clone read as patched and was not | **trap — mark the HOOK, not the material** |
| ^ patching materials by scene traverse | the actor pool / path line / tactical grid land in the same scene later, and it OVERWROTE `DecalBatch.onBeforeCompile` + its cache key | **trap — each builder patches its own; warm parity comes free** |
| ^ mask origin = the SMOOTHED slide, not `playerArea.x/y` | the logical cell snaps at action time, so the mask ran a whole `BASE_MS` **ahead** of the billboard; **9 frames per move**, idle free. In-frame A/B, 5 paired rounds, forced every frame: `upd` **+0.60**, `submit` **+0.30**, `GPU` noise, **`frame` +0.00** | **landed — no gate needed** |
| ^ canvas→GPU upload as the per-frame risk | isolated `texImage2D` reads <0.1ms at 84×56 AND 300×240 — but three's real path costs `submit` **+0.30ms** in-frame. Likely fixed overhead, not bandwidth (no scaling across 15x texels) | **small, not free — measure IN the frame, not beside it** |
| ^ the `MASK_R` cell scan | 841 cells / 3476 `canSeeThrough` **regardless of level size** (fixed window) — only the sweep grows with the level | **scan is flat; caching it buys 0.1ms, skipped** |
| ^ actors still gate on `sees()` at the logical cell | mask and actors used to snap TOGETHER; smoothing makes actors **lead** the mask by up to one move (opposite of the accepted corner divergence) | **accepted — `FADE_SPEED` reads it as a lead** |
| ^ **corner-only rays leave one cell unreachable** | the step past a hit reveals the cell LEFT of a left corner and RIGHT of a right one, so the cell the origin straddles (`floor(ox)`/`floor(oy)`) is aimed at by nothing and stayed dark — measured col 10 **0.00** vs 9/11 at **1.00**; only shows on a STRAIGHT run | **4 cardinal rays (of ~270) — complete, not a patch** |
| ^ the mask edge was hard only where it was **axis-aligned** | canvas AA writes no partial coverage on a texel-aligned straight edge: scanline through the player's row was a clean step, diagonals ramped 2-3 texels (107 mid of 4704) | **`MASK_PX` 4→2 — WRONG LEVER, reverted; it was the per-cell wall reveal** |
| ^ `MASK_WALL_FADE`: a lit wall fades toward masonry the sweep never reached | per TEXEL, because a cell can fade two ways at once and the value is the MIN — no gradient stack gives that; only runs at the ENDS of a run. Measured `255,191,63` ramps and **0/294 cells bleed red into an unreached wall** | **landed — floor keeps the exact polygon** |
| ^ wallness in the mask's **GREEN** channel gates the wobble | static per level → painted once, blitted in as the clear; everything after composites `'lighter'` and writes RED ONLY so visibility cannot trample it. **294/294 cells match masonry** | **landed — 2 fetches of a tiny cached texture** |
| ^ ground debris drew at FULL brightness where the player cannot see | it rides `DecalBatch`, which owns an `onBeforeCompile` — so `patch()` now **chains** a pre-existing hook instead of replacing it (different anchors, both survive) | **landed — `decalInstanceAlphasewerMaskb`** |
| ^ **chaining `customProgramCacheKey` naively BLANKS THE FRAME** | three's `Material` has a DEFAULT key on the PROTOTYPE returning `this.onBeforeCompile.toString()` — never null, and unbound `this` throws on every draw: 838 errors, **0 draw calls** | **`hasOwnProperty` + `Reflect.callMethod(mat, …)`** |
| ^ where to patch a lazily-built, actor-owned material | `DecalBatch` groups are built on first paint, so no build-time moment — `View`'s loop patches after `actors.update`, gated on `SewerArea` (uniforms are static, `Actors` is per-area). Expose MATERIALS not meshes: `grow()` swaps the mesh, keeps the material | **landed** |
| ^ `ensure()` early-outs on matching dimensions | every habitat is 21×14, so anything cached per-level on SIZE alone is the previous level's — `buildWallLayer` runs from `attach` unconditionally | **trap — size is not level identity** |
| ^ world-space sine wobble on the sample UV | `MASK_WOBBLE` 1.2 world units, two octaves, keyed on `vSewerMask` ONLY — world-keyed so the polygon slides THROUGH it; player-keyed would make the whole boundary swim every move | **landed — masonry only, no new programs** |
| ^ a canvas blur to widen the ramp | benchmark read 1.6ms at 84×56 and **0.5ms at 300×240** — cheaper at 15x the pixels, so it measured the `getImageData` flush, not the blur | **rejected then — SUPERSEDED, see `MASK_BLUR`** |
| ^ **the floor boundary was ONE antialiased texel** | scanline `0 0 0 0 [96] 255 255`, a clean 45°; **55 intermediate texels over the whole floor boundary**. A texel is 1 world unit = ~30-38 screen px, so bilinear of that single coverage value staircases at exactly that period | **the sweep was innocent — raster, not geometry** |
| ^ `MASK_BLUR` 0.75 texels, on a SCRATCH canvas | red visibility plane painted separately and composited through `ctx.filter` over an unblurred `wallLayer` — blurring the finished mask would smear the GREEN channel the wobble gates on. After: `0 1 8 41 116 199 243 254 255`, intermediates **55 → 311**, `greenNotPure` **0** | **landed** |
| ^ re-measuring the blur with the flush AMORTIZED | 200 composites per sample, A/B/A/B ×5, median: **+0.0765ms at 84×56, +0.0815ms at 300×240** — flat across 15x the pixels, so fixed per-call overhead, not fill. σ 2.0 costs `+0.0985 / +0.1035` — flat in RADIUS too | **cheap — the 1.6ms was the flush; σ is free, the filter CALL costs** |
| ^ `MASK_BLUR` 0.75 → **2.0**, and what a wider σ buys | band/dim/bleed swept live: `0.75→867/1.5%/1.9`, `1.5→1485/5.6%/5.2`, `2.0→1826/14.6%/7.5`, `2.5→2149/18.8%/9.8`, `4→2874/39.1%/17.4`. A CONVOLUTION — the band only widens by eating the lit side or spilling onto the hidden one | **2.0 is the knee; past ~2.5 a 1-cell corridor stops reaching full brightness** |
| ^ **a bigger σ FIGHTS the border fade** | `fadeCell` authors its ramp inside ONE cell (4 texels) and a σ2 kernel spans ~8, so it averages back up: border cap outermost texel **79 (vis 0.434) → 103 (vis 0.511)**. And mask 0 still renders at `MASK_HIDDEN` 0.18 | **the level's outer silhouette is NOT a blur problem — wants lower `MASK_HIDDEN` or a post-blur `rgb(v,255,255)` multiply layer** |
| ^ measuring a canvas blur on a `willReadFrequently` context | software raster gives DIFFERENT pixels than the GPU one the game uses — same σ read `litMin 255` vs the live canvas's `149` | **trap — measure the LIVE canvas, not a copy** |
| ^ `MASK_EDGE_FADE`: the level's outer rim in the mask's **BLUE** channel | no σ reaches it — the kernel averages `fadeCell`'s 1-cell ramp up, AND `mix(floor,1,m)` bottoms out at `MASK_HIDDEN`. Blue is static, blitted UNBLURRED beside green, and multiplies `sewerVis` AFTER the floor mix so it can hit a true 0 | **landed — rim vis `0.000`, inner face `0.961`, 85 progs either side** |
| ^ why zero is the whole point | `SewerScene` sets `scene.background` AND `scene.fog` to the same `0x05070a`, and the opaque branch fades toward `fogColor` — so vis 0 lands EXACTLY on the background | **the silhouette stops existing, not just dims** |
| ^ painting a falloff into ONE channel | MULTIPLY by `rgba(255,255,0,a)` — per-channel, so red/green survive byte-exact and only blue scales by `(1-a)`; 4 canvas-wide ramps clamp to a no-op inland and multiply at corners | **anchor the gradient at the outermost TEXEL CENTRE — at the boundary it lands 1/8 lit, not 0** |
| ^ `MASK_PX` 4 → **8** (habitat 168×112, full level 600×480) | every part of a rebuild is FLAT in canvas area — polygon fill 0.02ms at 84×56 AND at 600×480, blur already flat in radius and pixels — except `fadeCell`, which went **0.54 → 3.78ms**, i.e. 7× not 4× | **the resolution was never the cost; one function was** |
| ^ **`fadeCell` was a 1×1 `fillRect` + a fresh `rgb(...)` string PER TEXEL** | 56 cells × 64 = 3584 draw calls each with a CSS colour parse. But the ramp only varies on ONE axis unless the cell fades on both — measured **27 of 37 ramped cells single-axis** — so those go out as `P` strips | **blended 27/10: 0.899 (PX4 per-texel) → 3.481 (PX8 naive) → 1.221ms. 4× the texels for +0.32ms** |
| ^ `MASK_BLUR` was a sigma in TEXELS | doubling `MASK_PX` would have silently halved the boundary softness in world terms; the rest of the mask constants were already in cells or normalized | **moved to WORLD UNITS, converts at the filter — the sweep table carries over unchanged** |
| ^ **the area border never faded**: `dark()` returned false off-grid | `SewerGeom` caps EVERY solid cell and insets only edges overlooking floor, so the border cap runs flush to the boundary into NO GEOMETRY — a lit ledge on a hard rim. The "fully black next tile" was absent geometry, not `MASK_HIDDEN` | **off-grid = dark; col 0 flat `255,255,255,255` → `79,175,238,254`** |
| ^ still not faded, on purpose | unseen FLOOR does not count as dark (1-cell wall + hidden corridor keeps a flat cap), and `fades()` is 4-connected (diagonal-only dark neighbour = hard corner) | **left — not what the report was** |
| ^ comparing two sewer screenshots | a capture at 1 FPS can be a PARTIALLY LOADED scene: `110 geom / 177 tex` read flat and bright, `1161 geom / 291 tex` is the real near-black look | **trap — check geom/tex counts, not just fps** |
| ^ `"lift": 0.75` baked by `make tex` | pipe 0.46→**0.68x**, valve→0.70x, grate→0.61x; ledge dark tail min 3.0→15.0 with median unmoved | **landed — alpha untouched, no re-cut** |
| **`(col*A) ^ (row*B)` collapses on row 0 / col 0** | one term is ZERO → pure arithmetic sequence → **8 props in a row** on the always-solid area border, the ledge band at the top of screen | **`SewerModel.mix` (xorshift32) on all 3 sewer passes** |
| ^ why it was missed | grid-wide rate 22.2% and a run histogram matching a true RNG — averaging buries axis-aligned structure | **trap — test down the axes, not over the grid** |
| ^ per-cell coin flip vs one prop per 2x2 block | mixing alone still deals runs of 7; block placement caps a run at **2** by construction, gate `pct × eligible cells` keeps density | **landed** |
| A/B'd across a `make reload` | "60% of the band changed" was the log panel + lamp phase + actors, not the decals | **trap — hide/restore inside ONE session** |
| Wall variants back, picked per **FACE** (`SewerStyle.WALLS`, 4 merged buffers) | the 47%-seam verdict was on a pair with DIFFERENT block layouts, so a switch moved the mortar; repaints of ONE source keep the courses aligned. **40 → 43 calls**, 73.3% of adjacent faces switch (75% ideal), habitat 28/24/28/24 | **landed** |
| ^ but the sources are near-identical | 2-5 mean bytes apart, 2-5% of texels differ >12, same mean luma; whole-texture swap moves **3.2% of wall pixels >8** head-on | **mechanism fine — variety is capped by the art** |
| Sludge gutter + ledge pipe run switched OFF | habitat **42 → 40 calls**; `markChannel` stays, so the gutter is one branch away | **landed (author call)** |
| `SewerGeom.add`: `side: casts ? FrontSide : DoubleSide` | two unrelated decisions on one flag — floor/ledge got DoubleSide only because they do not cast, so ~3k quads rasterized a back face no camera can see | **fixed — all FrontSide** |
| ^ `SewerScene` put the STEADY cone set in the `coneFlick` slot | that slot is the flickering batch `LightCone.pulse`/lampMask index against; a phase-less set silently no-ops and lampMask walks a zero-length array | **fixed — empty flick set, 0 calls** |
| `CameraRig.maxFootprintCells` hardcoded `RenderConfig.CAMERA` | the AI spawn region is sized from it, and the presets are per-area now: **city 411 cells vs sewer 180** at aspect 1.92 | **fixed — takes a `CameraOffsets`; `getSpawnRect` keys on area KIND** |
| Sewer grime band: `loadRampTexture` → hand-painted alpha | a code ramp is ONE alpha per image row, so the band had no shape — only a gradient wash; street grime stopped doing this long ago | **landed — premultiplied, 0 calls** |
| Sewer/habitat exit laid flat on the floor | the art is a side-on LADDER; `isGroundDecal()` default made it a stripe on the walkway | **landed — override like `BurningBarrel`** |
| ^ organic floor decals may cross a cell edge | a pool that stops dead on every 4-unit boundary is what gives the grid away; span 3.6 → **7.6** only where the 3x3 is all floor | **landed — 0 decals over a wall cell** |
| Sewer light shafts start a MANHOLE wide (`CONE_TOP_R` 0.9 vs the street's 0.2) | a street shaft tapers to a point because there IS a bulb there; underground the light comes through a hole. `LightConeOpts` typedef rather than a 6th positional arg | **landed — 0 calls** |
| Sewer floor puddles 0.5/0.6 → **0.30/0.35** | `alphaTest` is `0.35 * alpha`, so the cut follows and the hand-cut soft edge stays proportional | **landed** |
| `SewerLamps`: weak wall fixtures, 12% of faces, 30% dead / 35% sputtering | two quads (additive glow over a soot smudge), no model and no art; habitat **12 placed, 8 working, 3 phased**, 43 → **45 calls** | **landed** |
| ^ everything else came free from the city rig | a working fixture is just a `LampPost` → same 12-slot pool → fake actor shadows already wired; a non-zero phase is all `LampLights`/`CastShadows` need | **landed — 2 new `LampPost` fields (`y`, `mul`), published never eased** |
| ^ `LightCone.pulse` is geometry-agnostic | it only repacks an instance buffer by the lit mask, so the glow quads get the city's outage behaviour verbatim; `phase == 0` now means always-on (one batch for steady + sputtering) | **landed — also fixes a latent city hash-lands-on-0 case** |
| Sewer/habitat exit becomes `sewer-exit.glb` | 93,501 → **5,000 tris** / 354KB, single mesh → 1 call for every exit; `ObjModels` + `ActorOpts.iconOff` keeps the marks, drops the icon | **landed — +1 call** |
| ^ a prop-backed object cast TWO shadows | `Models.instanced` sets `castShadow`, and `FlameShadows` was still painting a stretched sprite silhouette under it | **fixed — `castShadows` skips modelled objects** |
| ^ warming an async prop beside the warm scene warms NOTHING | `Models.instanced` resolves over a `GLTFLoader` callback, so the mesh lands after `compileAsync` walked the scene; instanced inside the promise chain instead → boot 69 → **73**, entry +9 | **trap — instance it in the chain** |
| A green DOT GRID crawling over that ladder | the exit's own through-wall x-ray: `OBJMARK` is `fill 'dots'` at `hatchSpacing 6`, painted `depthFunc GreaterDepth` = "draw where occluded" — and the prop stands AT the sprite pose, so **the object occludes its own marker** | **fixed — `iconOff` drops the silhouette too, ring only** |
| ^ blamed on the material first (twice) | chased metalness 0.71 / roughness 0.23, then a flat-198 albedo; both real, neither was it. The marker is an emissive UI quad — no light, no material knob reaches it | **trap — an overlay survives every lighting A/B; key `6` was the one that would have pointed here** |
| ^ the ladder's PBR is FINE as authored | metallic/roughness `1/1` + MR map reads as dark metal with a bright rail highlight, which is what the prop is | **`dropMR`/`baseColor` reverted — author wants the sheen** |
| `baseColor` bake knob (linear `baseColorFactor` × the map) | for a prop whose authored albedo is far brighter than the art: a uniform map has nothing to repaint, so scale it rather than replace it via `texSrc` | **landed in `models.mjs`, unused** |
| Debug key `M`: force every lit material matte | clears metalness/roughness **and their maps** — roughness/metalness are factors the map MULTIPLIES, so clearing a factor alone leaves a mapped material as glossy as it was | **landed — `StreetPerf`, one compile stall per toggle (flips `USE_*MAP`)** |
| ^ debug `1` cannot find a gloss bug either | it hides every light and adds a full-bright ambient, and specular only exists under an analytic light | **trap — `1` = albedo, `M` = specular, `6` = emissive** |
| Sewer `BLOOM_THRESHOLD` 0.75 → **0.9** (the street's) | the ladder's pale top rail sits 1.6 under a bulb, clipped past 1.0 linear, and haloed the floor: `Shift`+`1` measured the rail region **133 → 160** mean luma | **landed — near-clipped px 2.8% → 0.7%** |
| ^ did the lamps lose their glow? (0.75 was chosen FOR them) | no: the wall-glow batch is additive at linear **(2.6, 1.25, 0.35)**, luminance **1.47** — `Color.multiplyScalar` does not clamp, so it clears 0.9 by 63%. Nothing else authored above 1 either | **checked — scan the scene for colour/emissive luma > threshold** |
| The ladder FLASHES white on one specific tile | `LampLights` re-sorted slot owners and moved `lights[i].position` at once, but casters are `shadow.autoUpdate = false` and re-rendered **one per frame** — three `continue`s past `shadow.updateMatrices` for a clean shadow, so the light is at the new lamp and its map at the old one, for up to 8 frames | **fixed — one adjacent transposition per frame, both swapped slots refreshed the SAME frame (1 → ≤2 passes)** |
| ^ why that tile: measured, not guessed | live capture — lamp sits ON the exit cell (bulb 5.6, ladder top 4.0), nearest wall lamp at cell offset (+4,−1). ladder+2: d **2.00** vs **2.24**; ladder+3: **3.00** vs **1.41** → rank flips, slots 0/1 trade owners | **the swap IS the trigger — a hand-off must move light and map together** |
| ^ the city has it too and it never showed | the moon carries street shadowing so a lamp map hand-off is subtle; underground there is no moon, and `lightRangeCells 16` × `WALL_LAMP_PCT 12` makes rank swaps fire nearly every step | **trap — a deferred shadow budget is only safe for lights that are DARK while they wait** |
| A prop the player STANDS on fades see-through | one InstancedMesh = one material, so the fade is a second batch over the same placements + a `Models.cull` mask — the lamp lit/dead idiom verbatim. `?dead:Bool` became a `ModelVariant` enum (arity stays 5, and two bools would admit `dead && ghost`) | **landed — `PROP_GHOST`, +0 calls idle** |
| ^ `depthWrite`, not the alpha, is what unhides the player | the actor billboard is depthWrite:false but still depth-TESTED, so a prop that writes depth rejects it however faint it is drawn | **trap — fading alone would have changed nothing** |
| ^ the ghost material starts at opacity **1.0** | the glb resolves in a loader callback and can land after `tick`; until the first cull the batch draws at CAPACITY, and at 1.0 that frame is pixel-identical to the solid twin under it | **trap — building it at `alpha` flashes every instance** |
| ^ both batches keep `castShadow` | three's shadow pass renders its own depth material and ignores transparency, so the batch handover pops no shadow — and `castShadow` is in the program key, never toggle it per frame | **landed — no special-casing** |
| Tactical mark on a prop-backed object traced the 2D ART | `Sprites.outlineTex` outlines the ALPHA SILHOUETTE of the atlas cell at the sprite pose; with the icon suppressed it is a ladder-shaped outline around nothing | **fixed — inverted hull on the real geometry; `paintObjMark` no longer called, `ObjMarkOpts.xray` deleted** |
| ^ hull = geometry cloned with verts pushed along their normals | measured **4,933/4,933 verts displaced by exactly 0.015** local = `OBJMARK.hullW 0.06` world ÷ the 3.998 instance scale. `OutlinePass` is NOT in the vendored bundle and would cost a re-bundle + a full-screen pass | **landed — `MeshBasicMaterial` BackSide, +1 call in tactical only** |
| ^ `transparent` and `BackSide` are BOTH in three's program cache key | `three.global.js:36302` → `:36541` (`opaque`), `:36370` → `:36531` (`flipSided`) — so ghost and hull each compile a program and must be warmed INSIDE the `Models.get` callback | **checked in the bundle, not assumed** |
| ^ a masked-empty batch costs 0 draw calls | `renderInstances` early-returns on `primcount === 0` (`three.global.js:33249`) *before* `info.update` | **measured — 46 calls with both idle batches present** |
| Sewer wall lamps 2.2 → **0.6**, aimed 5.0 out along the wall | a fixture at head height pools light at its own feet; from the floor the beam grazes at ~7.8° and everything it touches rakes a long shadow. `LampPost` gained `tx`/`tz` — `LampLights` published every target straight down | **landed — city target is a no-op (`tx/tz = x/z`)** |
| ^ the FAKE actor shadows would not have followed | `CastShadows.ShadowLight` has no height field at all: length is `spriteHeight * lenMul * distance falloff`, so a knee-high lamp threw an overhead-looking smudge while the real maps raked | **fixed — `lenMul` and `range` scaled by `min(lowMax, refY/post.y)`; a street lamp is exactly 1.0** |
| ^ the lamp glow was an ellipse | nothing drew one: a CIRCULAR gradient on a square canvas, UV-stretched onto the 0.75 × 0.5 quad | **`makeRectGlowGradient` — a rounded-box SDF per texel, so radius/softness are numbers not a blur** |
| Sewer litter read as a swept floor | never unwired — 20/8 per 1000 is a couple of dozen fragments per level. 3× to **60/24**: headless on the demo tunnel, 117 floor cells → **22 fragments** | **landed — still 1 draw call (its own `DecalBatch` group)** |
| ^ `SewerDebris` was the 4th pass still on the bare hash | `(col*A) ^ (row*B)`, the exact form recorded above as combing on row 0 / col 0, while `SewerGeom`/`SewerDetail`/`SewerGround`/`SewerLamps` had all moved to `SewerModel.mix` | **fixed — a stale comment claimed it already matched them** |
| Exit shaft steps 2.0 SOUTH (+Z) off the ladder's cell | the prop stood inside its own light column; south puts the lit pool on the walkway in FRONT of it. `citygen.CityModel.Lamp` cannot mark an exit lamp, so the tunnels took a `SewerLamp` record with an `exit` flag; cone AND spotlight move, `col`/`row` stay the exit cell (the pool's distance gate) | **landed — +0 calls** |
| Sewer gets TWO light colours, neither the street's | shafts `0x9db4d4` cold sky down a manhole, wall brackets `0xc8d69a` bad fluorescent. `0xffb866` lived in TWO places — `LAMP_CONE.color` *and* a second hardcoded copy in `LampLights`' `new SpotLight(...)`, so recolouring the config alone would desync every shaft from its own light | **landed — `LightConeOpts.?color` + `LampPost.color`, +0 calls** |
| ^ the colour has to be PER POST, not per pool | node and wall posts share one flat `lampPosts` array and one pool, so a slot carries a shaft one frame and a bracket the next. Verified live: all 7 lamps at `y 0.6` publish the fluorescent hue, all 4 at `y 5.6` the sky hue | **landed — published in the same loop as position/intensity** |
| ^ per-frame light colour is free | `getProgramCacheKey` carries light COUNTS only; `WebGLLights.setup` re-copies `light.color` unconditionally every frame (`three.global.js:36965`) and the recompile hash compares lengths | **checked in the bundle — same cost class as the `intensity` write already there** |
| ^ a cool fixture hue can silently stop blooming | the glow quad is `colour × WALL_LAMP_GLOW 2.6` unclamped, and bloom thresholds LINEAR luminance where blue weighs **0.0722**. Measured after: `(1.502, 1.748, 0.840)`, **luma 1.63** vs threshold 0.9 (the amber was 1.47) | **trap — compute `Y_linear × GLOW` BEFORE picking a hue** |
| Sewer litter 3× again — 180/1000 tunnels, **120 rooms** | a habitat is pinned to 4-5 rooms of 5x5, so **62-77% of its floor is `room`** and the low rate was the one underfoot. On screen **5 → 32** fragments | **landed — still 1 draw call (shares its `DecalBatch` group with thrown money)** |
| ^ but the real reason it read empty was SIZE | `Debris` rolls `scale 0.1 + 0.9*rng`, drawn as `Sprites.SIZE(3.0) × contentFraction × scale` — measured in-engine at **0.15 / 0.73 / 0.86 / 0.88 / 1.21** world units against a CELL of **4**. A clamp to 0.5, applied to the tunnels' own spots after generation (the shared placer is the city's too, and already at 7 args) | **fixed — min size 0.15 → 0.46, max 1.21 → 1.83** |
| ^ and the visible half of the litter was on a GRID | a `transformable: false` fragment gets `dx = dy = 0` and `angle = 0` from `addFragment`, and static is the ~55% big enough to see — every one dead-centre in its cell, axis-aligned. Jittered in the same pass, inside `canPlace`'s free ±0.25 band so no ground test is needed | **fixed** |
| ^ litter is DARKER than the sewer floor, so raise `debrisMul` | **wrong, and it would have made it glow.** Measured on the built art: a static debris sprite peaks **175 sRGB** → ~96 after the 0.55 dim, against `app/textures/sewer/floor.png` at **66.8 mean / 75.2 max**. Litter is already ~30% BRIGHTER than its floor | **rejected — the docs' 0.2206 linear floor is the SOURCE in `textures-src`, not the built output at 0.056; sample the artifact** |
| ^ the decal reveal radius is not the limiter either | `DECAL.radiusCells 20` is a 1257-cell² disc against a 166-cell² sewer footprint at full zoom-out; the farthest visible ground point is 11.5 cells, inside the 18.5-cell full-opacity core | **checked — every visible fragment is at `op` 1.0** |
| A wall lamp's glow painted THROUGH an AI's head | the fixture batch sat at `Sprites.ORD_ACTOR + 1` — the light-shaft slot. **Nothing in the sprite pool writes depth** (deliberate: tiny Y gaps z-fight, so renderOrder does the layering), so a later transparent draw is only ever rejected by the opaque scene, and the quad sits `DECAL_EPS` proud of the wall | **fixed — new `Sprites.ORD_FIXTURE = 4.5`, verified 4.5 vs the shafts' 6** |
| ^ why the shafts are RIGHT at `ORD_ACTOR + 1` | a shaft is a column of lit air an actor stands INSIDE, so drawing it last and letting it tint them is the effect. A wall lamp is a quad on masonry BEHIND them. Same additive material, opposite ordering | **standing note — order by what the thing IS, not by how it blends** |
| ^ fractional order, no renumbering | 4.5 slots between the reticle and the actor without touching the other ~20 `ORD_*` call sites; `render.decals.Blood` already uses fractional orders for same-cell ties | **landed** |
| Wall fixtures placed INSIDE the overhead shafts | two light sources on one pool of floor, the weak one only muddying it. `WALL_LAMP_CLEAR = 2` cells, derived: shaft ground radius 3.66u (0.92 cells) + a bracket's own `WALL_LAMP_AIM` reach 5.0u (1.25 cells) ≈ 2.2 | **fixed — habitat 12 → 11 fixtures, nearest now 10.17u (2.54 cells) from any shaft; 49 → 44 calls** |
| ^ reject the CELL, not the fixture | the cull runs before the block's `faces` list is built, and the density gate multiplies by `faces.length` — so blocks near a shaft thin out on their own and per-face density elsewhere is untouched | **landed — no second density knob needed** |
| **`runware-trellis-2` MCP: gpt-image → TRELLIS 2 → `models-src/`** | closes the only hand-done step in the model pipeline. one tool, key read at CALL time (boots without one), default dir `<git root>/models-src`. never sends `dracoCompression` (bare `GLTFLoader`) and reports `meshCount` (`instanced` keeps only `firstMesh`) | **landed — ~$0.03/model** |
| ^ meshopt could not reach 4000 tris; `error` was the wrong lever | 20k source stalled at 15,824/13,153; `error` 0.005 → **0.03** only reached 13,318/8,975. meshopt will not collapse across attribute discontinuities and a TRELLIS mesh is one dense UV atlas of them — the ladder only made 5,000 because it had 93,501 of slack | **decimate where the topology is known: TRELLIS `decimationTarget 5000` + `tris: -1` → 4,771/4,845** |
| ^ **the piles were mushy anyway, and the cause was NOT the tri budget** | the web playground sends `remeshProject 0.8`; the API defaults it to **0** and the tool never sent it at all. It is the factor snapping the dual-contour remesh back onto the generated surface — 0 means no snap-back. Wire range is `(0, 1]`, so a literal `0` is *rejected*, not defaulted | **fixed — `remesh_project` added, defaults 0.8. The original diagnosis (blaming `decimationTarget`) was wrong** |
| ^ can a TRELLIS mesh be decimated offline? depends entirely on the SUBJECT | verts vs *unique positions*: ladder 55,080/46,778 = **1.18×**, meshopt hit 5,000 exactly. pile-1 130,974/41,042 = **3.19×**, pile-2 201,441/29,452 = **6.8×** — near-per-triangle UV charts, an attribute break on every edge, stalled at 55k/80k against 4000 | **measure the ratio before choosing where the budget goes. hard surfaces unwrap clean; crumpled/organic ones do not** |
| ^ `meshCluster` tuning does not rescue a shattered atlas | 16 global / 8 refine iterations, smooth 4, cone 2.6 rad: **3.19× → 3.15×**. dropping `remeshProject` helped more (2.46×) but costs the detail it exists to buy | **dead end — $0.04 to learn it** |
| ^ the WEB export is split exactly as badly — there was never a mesh difference | the playground glb the user was happy with: 98,425 tris / **132,205 verts** / 42,713 unique. ours: 96,001 / 128,831 / 40,899. a viewer's "42,647 verts" is the WELDED count | **standing note — compare raw glb to raw glb, not to what a viewer prints** |
| ^ `error` is not the lever and the floor is hard | `weld()` on the 96k source: 0.005 → 54,718; 0.02 → 52,252; **0.30 → 52,184** (60× the default cap, same answer). `weldByPosition` at 0.02 → **3,776** | **the seams are the lock, not the distortion budget** |
| ^ **`tex` was the real cause of "looks like garbage", not the tri count** | TEXELS PER TRIANGLE. source is authored at ~43 (96,971 tris / 2048²). shipped config was 4,673 tris at `tex: 256` = **14**, and every crack line and grain speckle was gone — smooth flat shards | **fixed — hold the ratio: 4,821 tris → `tex: 512` (51), 19,223 → `tex: 1024` (52). `tex` was not shrinking the map, it was deleting it** |
| ^ baking the atlas down to vertex colours | `COLOR_0` + weld-by-position DOES unlock meshopt (96,971 → 3,730 tris, 77KB, no textures, +6.5% GPU) but throws away the crack/grain detail — reads as smooth white shards. the premise was wrong: 130,974 verts is **1.36×** the tri count, not the 3× a true per-triangle atlas gives | **REVERTED, code removed. traps if ever revisited: sample the triangle UV CENTROID (a vertex UV is on a chart corner = gutter → bakes near-black), and COLOR_0 is LINEAR** |
| ^ shipped config | TRELLIS `decimationTarget 20000` + `remeshProject 0.8`, `tris: -1`, `tex: 1024`; `<label>-100k.glb` kept as the archival master | **landed — 19,223 / 19,712 tris** |
| ^ its cost, focused + interleaved, median of 17 | GPU **3.44 vs 2.44ms = +41%**, submit 1.70 vs 1.29, calls **+2**, tris **+272,056** | **kept — +41% is +1.0ms of a 16.7ms budget in a scene with 14.79ms IDLE. the tunnel is the lightest scene (52 calls vs the city's 168) and piles do not exist in the city** |
| ^ read the share against the right denominator | +41% in the tunnel is not comparable to +41% in the city. earlier pile configs measured +13.4% (4.7k/tex256) and +6.5% (vertex colours) — both cheaper, both visibly worse | **standing note — a big share of a small scene is still a small number; check idle before reacting to a percentage** |
| ^ pile-2 rendered BLACK under debug key `1` | its baked MR map is uniformly **cyan** — glTF packs G=roughness/B=metalness, so metalness 1 over sacks, wood and cloth. A metal has no diffuse, and `1` hides every light, so nothing is left to shade. pile-1, same generator, same day, came out pure green (correct dielectric) | **fixed — `dropMR` on pile-2 only. Dump the MR texture; it answers in one look. And a black prop under `1` means METAL, not a dark albedo** |
| `SewerPiles`: glb clutter heaped against wall faces | per 2x2 block, `PILE_PCT 14 × faces.length`, exit ring rejected. habitat **8+6 = 14 piles** | **landed — no per-frame cull** |
| ^ its cost, foreground + interleaved, median of 18 | GPU **2.83 → 2.45ms = 13.4%**, calls **52 → 50**, tris **79,374 → 12,136** (exactly `8×4771 + 6×4845`). `submit` 1.50 vs 1.60 — moved the WRONG way, i.e. noise | **the shape to expect: +2 instanced draws is nothing to the CPU, +67k tris is something to the GPU** |
| ^ verified before the art existed | `places(m)` split out of `build`, run headless on the demo: 13 piles / 84 faces = 15.5%, longest axis run **2**, **zero** misplacements (all offset `CELL/2 − PILE_MARGIN` toward a SOLID neighbour) | **landed — the split is the check** |
| ^ do piles finally let a wall bracket cast? | in-frame A/B, all 12 spot shadows forced: **0.021% of the view, max 18/255** vs 0-pixel reproducibility AND restore controls. most piles sit outside any pool | **real but near-invisible — does NOT close that lead** |
| ^ so is their `castShadow` worth paying for? | it is not paid for: on vs off (both program permutations warmed first) = **2.65 vs 2.67ms, −0.8%, calls identical**. the 13.4% above is ALL main-pass | **keep it — the shadow-pass half is free** |
| Composite prop → four simple ones (`sewer-pile-2` becomes drum + crates + cable + bags) | the fix is the REFERENCE, not the bake. one generation of "sacks + rope + tarp + crate" shipped at 19,712 tris and read as mush; four single objects total **19,304 tris** and read right | **landed — one simple object per glb; offer the split instead of generating a composite** |
| ^ split ratios of the four, all at `decimationTarget 100000` | drum **1.31×**, crates **1.96×**, cable **2.10×**, bags **12.1×** (252,243 verts / 20,833 unique — worse than pile-2's 6.8×, essentially per-triangle) | **standing note — soft goods shatter; hard surfaces do not** |
| ^ the ratio says WHERE meshopt lands, and ~2× is the workflow line | asked for 1,200 tris: **4,826 / 23,926 / 30,431 / undecimatable**. below ~1.5× the 100k-master + offline-decimate route works; at ~2× the subject must be regenerated with `decimation_target` at the budget | **fixed — drum decimated offline, the other three regenerated at 5000** |
| ^ **`error` IS a lever on a clean atlas — the pile-1 result was over-generalised** | drum (1.31×): 0.005 → 4,826, 0.01 → 3,762, 0.02 → 3,476, asymptote **3,294** = **−32%**. crates (1.96×) −8%, cable (2.10%) −16%, pile-1 (3.19×) ~0% | **corrected — sweep `error` on a clean subject before accepting its tri count; skip it on a shattered one. no cap reached the target on any of them** |
| ^ shipped config | all four `"tex": 512` (~54 texels/tri), `-100k.glb` masters kept for the three regenerated. all four MR maps pure green — **no `dropMR` anywhere**, so pile-2's cyan map was a one-off, not a generator property | **landed — 4,826 / 4,818 / 4,891 / 4,769 tris** |
| ^ `SewerPiles` → `SewerProps`, per-prop height/standoff, corner tuck | `PILE_H`/`PILE_MARGIN` became `SewerProp` typedef fields (a drum is 0.9 tall, a cable coil 0.3); a cell with two perpendicular faces applies both offsets, and yaw is now `Math.atan2(nx, nz)` on the summed normal — reproduces the four literals it replaced and bisects a corner to 45° free | **landed** |
| ^ placement verified headless on the demo | 13 props / 84 faces = **15.5%** (`PROP_PCT` 14), even across all 5 variants, **zero** misplacements (every one on a floor cell, hugging a genuinely SOLID wall, at exactly its own margin), 0 duplicate cells, 2 corner-tucked, longest strictly-adjacent axis run **2** | **landed — `places(m)` split out of `build` is still the check** |
| ^ live in a loaded habitat | 5 batches / **14 props**: drum×4, cable×2, bags×2, crates×1, pile-1×5. every instance y = h/2 (none floating or sunk), world sizes exact (crates 0.75³, drum 0.61×0.9×0.61). **139,557 prop tris, of which `sewer-pile-1` alone is 96,115 = 69%** | **landed — pile-1 is now the only hog left** |
| ^ its cost | NOT measured. `Page.bringToFront` raises the CDP target but not the OS window: the HUD read **1 FPS** throughout, and `calls` swung 29–44 with camera pose alone | **open — needs a genuinely foregrounded window, per the measurement rules above** |
| ^ trap: a prop can be in-frustum, un-culled, submitted and still invisible | the tunnel's raised brick walkways occlude the lower channel, so a low camera aimed at a wall prop sees only ledge. `depthTest:false` did **not** expose them either. Overhead + a per-batch material tint is what actually showed all 14 | **standing note — tint the batch and go overhead; do not debug prop placement from a low free-cam** |
| Three of five sewer props were standing INSIDE the wall | `SewerProp.margin` was hand-typed while `Models.instanced` scales by HEIGHT alone, so a flat prop's footprint = `nativeR/nativeY × h` and no authored constant survives an `h` edit. Measured world radii vs the authored standoffs: pile-1 **1.425** vs 0.55, cable **0.830** vs 0.50, bags **0.825** vs 0.40 (drum and crates were fine by luck) | **fixed — `margin` replaced by `r`, the footprint radius per unit of height measured off the glb; `SewerProps` derives `margin = r * h + PROP_CLEAR`. all five now clear their wall by 0.05, verified headless** |
| ^ a quarter of every prop was invisible BY CONSTRUCTION | the south wall is between `CAMERA_SEWER` (+Z, 53° near / 71° far) and its own cell, and it is `WALL_H` tall with a ledge cap, so it hides everything within `3.0/tan(pitch)` = **2.25 / 1.05** units of it. A crate at h 0.75 / standoff 0.35 crosses the wall plane at y **1.22** against a 3.0 cap — not partly occluded, gone at every zoom. Clearing it would need a standoff of 1.7, i.e. mid-corridor | **fixed — `SewerProps.CAM_DIR` drops dir 1 from `faces`; `PROP_PCT` 14 → 18 pays back the ~quarter of faces lost. proof: max \|yaw\| **1.923** < the π/2+jitter limit 2.071, where a south face would be ≥ 2.642** |
| Big upright props stood against flat wall runs and read as dropped in the walkway | `SewerProp.corner` now PARTITIONS the table rather than filtering it: a corner spot deals only from the corner props, a flat run only from the rest. Filtering alone would have been useless — corners are **14%** of spots, so a 1-in-5 pick on top of that is 0.4 a level. Drum and crates are both `corner: true` and share those spots (crates also went `h` 1.1 → 1.65) | **landed — verified against the floor grid rather than the placement code: drum and crates 1/1 each on real corners, the three flat props 0/12, none off a floor cell** |
| TRELLIS hallucinates a VIOLET albedo from a near-black reference | `sewer/bags` baked at mean sRGB **77/62/99** (R>G, B≫G) from a reference painted 68/72/77. Not our bake — source 2048 and baked 512 means agree to **1/255**, and drum/crates/cable from the same batch are all correct. Not the seed either: a fresh seed came back *brighter* and bimodal pink/black, strictly worse | **fixed at the REFERENCE — repainted mid-charcoal (subject luma p05 30 → 48, the band the three correct props sit in) and the same generator returned 67/70/78, cool and neutral, tracking the reference hue. `baseColor` is now only a uniform 0.47 darken. A per-channel `baseColor` was tried first and is the fallback, not the fix — it cannot recover a channel the generator threw away** |
| `sewer-pile-1` (slabs + bricks + pipe) splits into `block` + `bricks` + `pipe` | the last composite, and the only expensive thing left: 3.19× split, shipped undecimated at **19,223 tris**, 5 instances = **69%** of all prop tris. worldR **1.425** = 2.85 units across a 4-unit cell | **landed — 17 props for 76,968 tris vs 14 for 139,557, −45% while placing three MORE** |
| ^ the split ratio predicted every bake before it was chosen | hard surfaces `block` **1.23×** / `pipe` **1.32×** (drum's class) → one 100k gen, decimated offline. rubble `bricks` → straight to `decimation_target 5000`, came back **2.11×**, past the ~2× line | **the rule held on first use — no money spent finding out** |
| ^ `error` 0.01 rather than the habitual 0.005 | block 0.005→5,356, **0.01→3,198**, 0.02→2,496, asym 2,314; pipe 0.005→7,224, **0.01→5,890**, asym 5,602. 0.01 also keeps the pipe at **45** texels/tri (0.005 = 36, under the authored ~43) | **landed — sweep `error` AND check texels/tri; the two pull opposite ways** |
| ^ both concrete props baked far brighter than the prop family | family is mean sRGB ~46-49 (drum 46/47/52, crates 33/49/59, cable 32/47/56) vs a **65** floor; pipe **86/87/79** (1.8×), block **110/110/108** (2.4×) | **fixed — uniform `baseColor` 0.35 / 0.22, fitted as `f = (target/measured)^2.2`, the formula that reproduces bags' shipped 0.47. all three MR maps pure green, no `dropMR`** |
| ^ the "single brick" the split started from was never buildable | the drum is the ruler — `h` 1.8 for a real 0.88m 200L drum = **1 world unit ≈ 0.49m** — so a 215mm brick is **0.44 units**, under the 0.46 floor of the 2D `SewerDebris` litter already scattered ~22×/level at zero draw calls | **shipped as a broken masonry BLOCK instead; and `h` 0.55 still read as a speck in a tint pass, so 0.7** |
| ^ draw calls did not move, and could not be A/B'd | 7 table entries but **5 batches** drew (crates/cable rolled zero placements, and `Models.instanced` builds no mesh for an empty list); topbar 50-52 dc either side. window would not foreground, HUD held **1 FPS** | **tri count is the honest number here — inventory × instances, pose-independent** |
| A habitat put all FOUR of its drums on one wall | two faults, and the interesting one was not the cause. **Every roll here is GF(2)-affine** (xorshift + multiply-by-odd + xor are all linear), so `roll % 2` on the 2-entry corner pool reads ONE linear form: over a 40×40 grid a row band scored only ever **16 or 24** of 40, never between. `(roll >>> 16) % 2` quantises identically (18/22) — a shifted bit is still one linear form | **fixed — `PICK_ODD = 997` before any small-pool index; spread opens to 10..27, sd 3.22 vs a fair coin's 3.16. The 5-entry flat pool never had it (5 is coprime to 2³²)** |
| ^ but that fix alone changed nothing, and shipping it as *the* fix would have been wrong | same level still dealt drum×4/crates×2 (it swapped cells), and the flat pool got WORSE — cable on **6 of 7** spots. A habitat's 5×5 rooms put nearly every corner on one row, and on 5 spots a fair coin lands 4-or-more alike **37%** of the time | **independent rolls cannot fix clustering, only be lucky — measure the geometry before blaming the hash** |
| ^ so each pool is DEALT as a deck, not rolled | per-pool deck, Fisher-Yates'd off the same hash chain on refill (level stays determined by its saved grid), popped one spot at a time. demo tunnel flat sequence is a full permutation per cycle, **max run 1**; live row 8 went `drum,drum,drum,drum,crates` → `drum,drum,crates,crates,drum` | **landed — max run 4 → 2, corner 4/2 → 3/3, flat cable-6-of-7 → 2/2/1/1/1, placement invariants unchanged** |
| ^ why stop at 2 and not force alternation | 2 is the floor for a 2-entry bag (a permutation can end on the face the next begins with). two drums together reads as stored; four in a row reads as a bug. perfect alternation needs a carry-over `last` and looks mechanical | **author call — bounded is the point, not zero** |
| A failed glb load stalled BOOT, not just the prop | `Models.get`'s error path dropped its waiters and `View.warmup` sequences on one — two 404s left the warm Promise unresolved, so `comp.dispose()` and `setRenderTarget(null)` never ran and the renderer stayed bound to the warm target | **fixed — waiters get an empty template (which must carry a child Group: `instanced` reads `pivot.children[0]` blind)** |
| **The tunnels read as boxes — and it is the CAP EDGE, not the masonry** | wall faces are 0.67% of the view vs the cap tops' 14.68%, and `wall.png` is already broken brick + moss. What reads orthogonal is one dead-straight high-contrast line where a lit cap meets a near-black face, on a 4-unit lattice, every arris a 0-width crease | **diagnosis — do not spend art on the wall** |
| ^ `CAP_CHAMFER` 0.25: a 45° wedge between face and cap | face stops at `WALL_H - c`, a second quad carries it up and back; the cap insets by the same `c` on every edge overlooking floor. Exactly paired (a cap edge insets *iff* its neighbour walls it), so the plateau never opens. Swept live: **0.15 invisible, 0.45 a chunky moulding, 0.25 right** | **landed — this is the rejected ledge-rim darkening done as geometry, which is why it works** |
| ^ **a bevel on a plan OUTLINE must be MITRED — shipped without it and quads hung in the air** | run a wedge along a whole cell edge and at an OUTSIDE corner its last `c` is over open corridor (both walls have receded by `d` at height `fh+d`) — two wedges crossing in mid-air past the corner. Dual bug at an INSIDE corner: a `c × c` notch straight through to the background | **fixed — classify each END off `diag`/`perp`** |
| ^ the three-case rule, and why the inside case is NOT "extend the top edge" | `diag` floor → pull IN by `c` (**no extra triangle**, the quad becomes a trapezoid; the two wedges already share their bottom corner, so closing the top closes the seam). `diag` solid + `perp` floor → straight run, nothing. `diag` solid + `perp` solid → a vertical return triangle, i.e. a real chamfer STOP. Extending instead slides the wedge under the diagonal cell's un-inset cap and opens a void — that cap would then need an L notch, 4 tris instead of 2 on the biggest surface down there | **landed — +1 tri per inside end, 0 per outside end** |
| ^ verified headless, and the OBVIOUS test is the wrong one | demo: 84 faces / 8 outside ends / 16 inside ends → **352 wall tris vs 84×4+16 = 352 exactly**, and **all 136 interior wedge-top verts land on a corner of the inset cap, 0 misses**. "Is the vertex over a solid cell?" passes on the BROKEN build — the overshoot is inside the cell's *footprint*, just above its bevelled surface | **trap — test the seam, not the footprint** |
| ^ `vertexColors` on the shell, keyed off the cell LATTICE | ±`TINT_AMP 0.15` hashed per lattice point (rounded cell index + height band), read at each quad corner. `MeshBuf` gives every quad its own verts, so per-face would step at every boundary — the two-wall-variant seam. Same channel carries `TINT_FOOT 0.80` / `TINT_CORNER 0.75` / `TINT_CHAMFER 1.08` | **landed — free unevenness, no art; a lattice key cannot seam by construction** |
| ^ `FLOOR_TILE`/`LEDGE_TILE` 8.0 → **7.0** | both were exactly 2 cells, so the texture period landed on the same point of the tile at every grid line — a visible pattern on the two surfaces that fill the screen. 7.0 pushes the echo to 7 cells | **landed — one constant** |
| ^ its cost | **not measured.** +1 quad per wall face (104 in the habitat) is the honest inventory number; window would not foreground, HUD held **1 FPS**, topbar swung 50–56 dc / 69.9–70.6k tri on pose alone | **open — same limitation as the props entry above** |
| ^ south (`dir 1`) wall faces are backface-culled in EVERY pose | normal `(0,0,-1)` against a camera always at +Z looking −Z, so their grime and decals (~a quarter of both passes) are pure waste. The wall quads are NOT free to drop: `casts = true`, and the shadow map renders from the light | **found, not acted on** |
| Contact shadows stood UP an inside wall corner | **nothing in the tunnel lighting can darken one**: ambient is normal-blind, hemi keys on `normal.y` and both faces of a vertical corner are vertical, and a corridor spot sees both walls. GTAO is the only engine answer at +140 calls, off by default. Rides the floor strips' own `InstancedMesh` — same quad, same material, same gradient — so habitat **21 inside corners → 32 strips, batch 102 → 134, +0 draw calls, +0 programs, 0 art** | **landed** |
| ^ a yaw alone cannot place one | the gradient runs along the quad's local +Y, so standing it up needs a quarter turn about local Z first — and WHICH one depends on which END of the face the corner is, since yaw sets normal and fade direction together. A mirror would flip the winding off `FrontSide` | **two base quaternions, picked by `-nz*ax + nx*az < 0`** |
| ^ and they must MEET, not cross | each strip stands `EPS` off its own wall, so one running from the bare corner pokes that far past its perpendicular twin — a small double-dark cross. Each starts `EPS` along the wall too, which is exactly the twin's stand-off | **same lesson as the chamfer mitre** |
| ^ draw order was a real bug | all of it is transparent + `depthWrite:false`, and every piece is a level-wide merge with origin `(0,0,0)` — so three compares an identical sort `z` and falls through to `a.id - b.id`, i.e. **construction order**. `grime, shadows, decals` let an `alphaTest`'d crack decal REPLACE the corner shadow | **fixed — `grime, decals, shadows`; `WALL_SHADOW_EPS 0.07` also clears `DECAL_EPS 0.05`** |
| ^ `TINT_CORNER` 0.75 → **0.90** | the vertex term and the strip multiply: 0.75 under a 0.55-alpha black put the corner at **0.34 of base**, a hole. The vertex term is now the broad wash under the strip, and the only cover for the chamfer/stop above its `WALL_H - CAP_CHAMFER` top | **landed** |
| ^ verified headless before looking | demo: **96 = 84 flat + 12 vertical** against 8 inside corners with 4 camera-side (8×2−4). Every vertical instance decomposed: spans y 0→2.75, exactly `WALL_SHADOW_W` wide, normal into a floor cell with masonry behind, opaque end at exactly 0.07 both off the wall AND along it from the corner lattice. **0 failures on 5 checks** | **the decomposition is the check** |
| **The cap stops being LEVEL — `CAP_SAG 0.4`, hashed per LATTICE point** | the chamfer split the silhouette into two edges but left both dead level, which is the other half of "reads as a box". `capY(x,z)` hashes the *rounded* cell index like `tint` does, so height is a property of a grid POINT: two cells share their corner heights, a wall tilts between its run's two, and the cap's `CAP_CHAMFER` inset rounds back to the point it came from. Downward only — `WALL_H` is the camera-clearance number | **landed — 5.7° tilt per cell, 0 extra tris, 0 extra calls, 0 art** |
| ^ why the report's per-CELL version was the expensive one | a per-cell height STEPS, and a step between two solid cells is a hole through the plateau → a filler quad on every solid/solid boundary. That filler then meets the chamfer: full-width it stands a zero-thickness fin `c` tall through the bevel, inset to the cap outline it leaves a `c`-wide notch. Three new cases, i.e. the mitre problem again on new geometry | **trap — a lattice key has no steps, so it has no fillers and no cases** |
| ^ what it costs: nothing may assume `WALL_H` | decals clamped to `WALL_H - CAP_CHAMFER` → `faceH`, the LOWER of the face's two corners. Corner shadow strips the same, interpolated over `WALL_SHADOW_W` — they stand OFF the wall, so overshooting a descending edge shows a black sliver with nothing to hide it. Ledge clutter sat at `WALL_H + LEDGE_DECAL_Y` → `capAt` per decal corner, evaluated on the same two triangles `cap()` emits | **3 consumers, all real; the floor pass is genuinely flat and keeps its constant** |
| ^ verified headless | **every cap vertex on `capY` of its own lattice point, 0 off**, none above `WALL_H`, none below `WALL_H − CAP_SAG` (range 2.601–3.000). Wall tris **352 = 84×4 + 16 exactly**, so the sag added no geometry, and the mitre seam test still shows **0 interior misses**. Ledge decals 284 verts all at exactly `LEDGE_DECAL_Y` over the surface, max tilt 0.182 within one decal. Vertical strips 12, tops 2.370–2.664 (were all 2.750), **0 over their own wall** | **landed** |
| **The sag shipped a hairline down every inside corner** | a 1px pure-black line out of every concave corner, texture and shading continuous across it — both sides are cap. `cap()` sampled `capY` at corners the chamfer had pulled back, and `capY` rounds an inset corner to the lattice point it came from. The un-inset neighbour draws the same two lattice heights over the FULL cell, the inset one over 3.75 → `gap = (CAP_CHAMFER/CELL)·Δh`, max **0.025** | **fixed — off-lattice vertices take `capAt`, not `capY`** |
| ^ why inside corners only | a cap edge-end insets iff its perpendicular neighbour is floor, and two cells across a boundary disagree about that exactly where the corridor turns concave. A straight run agrees at both ends and is watertight | **the rest of the plateau was never affected** |
| ^ the trap: it is TWO samplers, not one | the wall FACE top must stay on the lattice (`capY - k`) — give it `capAt` and the two perpendicular faces of an inside corner sample at their own inset offsets and the crack moves into the wall. Chamfer stop likewise: apex on the lattice (`capY`), other top vertex on the inset plane (`capAt`). Face and wedge stop being exactly `k` apart, by ≤0.025 | **landed** |
| ^ the demo could not see it — scan a random grid | boundary-edge scan (weld, count edge usage, keep count-1, find a vertex in the plan-interior of one at a different height) on 44×44 at 50% floor: **295 cracks, max 0.0247, mean 0.0082, all on the ledge mesh, all on a cell boundary → 0.** Demo still 352 wall tris, 0 interior seam misses | **a regular tunnel is not a test case** |
| ^ corner shadow strip put its error in the WRONG place | one instance matrix cannot taper a quad, so a tilting bevel means the rectangle disagrees somewhere. `min` of its two ends puts a lit sliver (≤0.072) **in the corner**, where the gradient is fully opaque | **fixed — take the corner's own height; the far end, where the gradient is 0, is the end that disagrees** |
| A wall bracket's FAKE shadow reached 6 cells — further than a burning barrel | `lowMax 3.0` scaled `lenMul` **and** `range` together, so `rangeCells 2 × 3.0` = 6 cells vs `FLAME.shadowRangeCells 4`. Length and reach are not the same want: a raking bracket *should* throw a long shadow, but only for actors standing in its own small pool | **fixed — new `LAMP_SHADOW.lowRangeCells 3` clamps the scaled reach only; `lenMul` keeps the full 1.8, street lamps unaffected (they scale by 1.0, under the cap)** |

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
