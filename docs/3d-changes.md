# 3D render changes: what was tried and what happened

Append-only ledger of every 3D/render experiment — landed, reverted, or rejected — with its
measured result. **Read this before proposing a render change**, and add to it after trying one.
It exists because the expensive mistakes here are the ones already made once: the roof-detail
batching below was disproved a second time despite `perf-static-city-merge.md` already saying so.

Baseline hardware for all numbers: **RTX 3050**, 60fps cap, 1080p-ish, `vidAntialias=4`.
See also [`perf-static-city-merge.md`](perf-static-city-merge.md) (deferred two-tier city merge).

## How to measure (and how not to)

- **`calls=` in the `[street-render]` trace is the only draw-call number.** Enable the `perf street`
  console toggle (`render.Actors.DEBUG_PERF`) or street-debug mode (backtick).
- **The scene dump (`9`) is an INVENTORY, not a draw list.** `visibleDrawables` counts objects whose
  `visible` chain is true — frustum culling then discards most of them. Real ratio measured here:
  **1616 visibleDrawables → 435 calls**. A big number in the dump means nothing until you confirm
  those objects survive culling. Two failed experiments below came from reading the dump as draws.
- **`submit` is the CPU draw-call wall** — time inside `composer.render()` (scene walk + issuing
  draws + any driver blocking). It is the ceiling that a better GPU does **not** fix. `upd` (engine
  CPU) is ~1ms and irrelevant. `GPU=` is a real timer query (`EXT_disjoint_timer_query_webgl2`).
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
| Roof-detail material hoist | ~750 → 6 materials; **0 draw calls** | **landed** (harmless) |
| GTAO ambient occlusion | +994 calls, +10ms submit; 60 → 45fps | **landed, default OFF** `870d0f8` |
| BatchedMesh for roof details | **+4 calls, +2ms submit, −3ms idle** | **reverted — worse** |
| AgX / Neutral tone mapping | look rejected | **rejected** |
| `reversedDepthBuffer` | flips custom `depthFunc`/decal offsets; doors vanish | **rejected** |
| Distance-cull far detail | parapets are the roofline silhouette — pops | **rejected** |
| SSRPass (reflections) | style rules ban glossy/specular reflections | **rejected** |
| `RenderPixelatedPass` | total aesthetic pivot, not an enhancement | **rejected** |

## Landed

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
Opt-in only. Costs **+994 calls, +318k tris, +10ms submit, +8ms GPU → 60fps drops to ~45**.
Why so expensive: `GTAOPass._renderOverride` calls a **full `renderer.render()`**, which re-runs the
shadow-map pass — so the moon's 2048² shadow map renders **twice per frame**, the second time to feed
a `MeshNormalMaterial` that cannot sample shadows. (Measured 4.07× triangles; double-rendering alone
predicts 2×, so there is a second unidentified factor.) A disabled pass is skipped whole by the
composer, so default-off costs nothing but idle memory.

Tuning trap: `radius` is **world-space** and `CityConfig.CELL = 4`. The initial `radius: 0.25` was 6%
of one cell — invisible at city scale. Usable range starts ~1.5. Note the effect fights the art
direction ("even flat lighting, NO soft photographic shadows"), which is why it ships off.

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

## Open leads (measured, not yet acted on)

### `DecalBatch` groups are per-texture and never culled
55 live groups, `frustumCulled = false` (deliberate — the shuffling instances leave the bounding
sphere stale), so **all of them draw every frame regardless of visibility**. The instance histogram
is mostly empty draws: **49 groups hold a single instance**, 26 hold two, and the largest holds 24.
After `forceSinglePass` that is still ~55 always-on calls. Fewer/atlassed textures or a real cull
would take most of it. Untried.

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
   already culled for free. `perf-static-city-merge.md` said this in 2 lines; it was ignored.
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

### Tone mapping: AgX / Neutral
Added in r162/r165, so they are a one-line swap from `ACESFilmicToneMapping` with no bundle change
(`OutputPass` reads `renderer.toneMapping`). Tried; look rejected. Note bloom
(`BLOOM_THRESHOLD`/`toneMappingExposure`) would need retuning if ever revisited.

### `reversedDepthBuffer` (r181)
Flips custom `depthFunc` and decal polygon offsets — doors vanish. Do not enable.

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
