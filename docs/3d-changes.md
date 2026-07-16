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

## Verdict table

| change | result | verdict |
|---|---|---|
| `flattenBox` + `mergeBand` (earlier) | 10,595 → ~3,000 calls, 6 → 30fps | **landed** |
| MSAA via composer render targets | real AA, was previously absent entirely | **landed** `729c064` |
| Parapet ring merge per building | 583 → 436 calls, submit 10 → 7.3ms | **landed** `1183cff` |
| Ghost overlay capacity fix | fixes a hard `RangeError` crash | **landed** `5a6ae04` |
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
