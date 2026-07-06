# Perf idea (deferred): merge the static city by texture

Saved for later. Not implemented — the effort/risk is an order above the wins already
banked, and it collides with the Occlusion system (see below).

## Context — what draw-call optimization already shipped

The 3D street view was draw-call-bound: at a shallow/parallel camera the whole visible
city renders, and every multi-material `BoxGeometry` cost one draw call **per face group**
(6 per box), times hundreds of visible buildings on one JS thread.

Diagnosed via the `perf street` profiler (`full=`/`base=`/`post=`/`calls=`/`tris=` line in
`StreetView.hx`) and the live `dc`/`tri` HUD counter (`vidShowFps`). Symptom: ~150ms render,
GPU **and** CPU ~idle (one core pegged issuing draws), because the cost was draw-call
*count*, not GPU/fill (only ~65k triangles).

Fixes landed (parallel-camera draw calls **10,595 → ~3,000**, FPS **6 → ~30**, no visual
change):

- **`Poly.flattenBox`** — collapses a multi-material box to **one draw call per distinct
  texture** by baking each face's texture matrix into the geometry UVs and reordering the
  index so same-image faces form one contiguous group. Single-image box (coping) → 1 call;
  clean+worn (brick/stone parapet) → 2; walls+roof (building box) → 3. Applied to building
  boxes + parapet rings + coping caps. Self-check cross-validates the UV math against three's
  own `Texture.matrix`.
- **`Buildings.mergeBand`** — merges each building's upright wall-band quads (grime, storefront
  bays, ground bands) into one mesh per material, baking rotation+position into verts with
  explicit +z-rotated normals so shading is identical. `userData.b` kept so Occlusion still
  fades per building.
- Camera far-plane clipped to just past the fog wall (`SceneSetup.hx`).
- Roof contact shadows + roof detail decals were already `InstancedMesh` (~2 calls citywide) —
  nothing to gain there.

Commits: `6a20c75` (flattenBox + fog + HUD), `8240e4d` (mergeBand).

## Approaches that are OFF the table

- **Distance-cull far detail (tried, reverted).** Parapets are the roofline silhouette —
  always visible, even at a shallow angle. Popping their geometry looks bad. Distance-culling
  *visible* geometry does not work here.
- **Pull the fog / view distance in.** Changes look/feel (shorter sightlines). Rejected.
- **Per-building merges of doors/covers/roof furniture.** Safe (no visual change) but each is
  only ~150–250 dc; several needed to move the needle. Low ROI.

## The deferred idea — two-tier static merge

The whole city is static (buildings never move), so weld every piece that shares a texture
into a few giant meshes: one for "all brick walls citywide," one for "all coping," one for
"all roofs," etc. — ~10–20 giant meshes for the whole map. A parallel camera then draws ~200
calls instead of 3,000 → ~15ms → ~60fps. Standard open-world city-render technique
(merged/batched static geometry).

### Why it isn't a drop-in

It collides with **Occlusion** (`render/Occlusion.hx`). Occlusion fades an *individual*
building to semi-transparent while it blocks the camera→player sightline, by owning that
building's own materials and easing their opacity. If all buildings share one welded mesh +
one material, you can't fade just one — it's all-or-nothing.

### What it would take

Split the city into two tiers:

- **Near tier** — the handful of buildings that can actually occlude the player (within some
  radius of the player/camera). Keep these as today's individual, fadeable meshes (current
  code path, unchanged).
- **Far tier** — everything else, welded into the giant per-texture meshes. These never fade
  (too far to occlude the player anyway).

Then re-tier as the player moves: rebuild the near set on **area movement** (not per frame),
re-welding the far tier when a building crosses the boundary. Occlusion only ever operates on
the near tier.

Extra notes:

- Welding reuses the exact bake already written for `flattenBox`/`mergeBand` (per-face UV
  transform → geometry UVs, world transform → verts). The merge step itself is the same
  vertex concat; the new work is the tiering + re-weld-on-move bookkeeping.
- Transparent/cutout passes (windows already `InstancedMesh`; doors are alphaTest) can stay
  as-is or get their own welded batch per texture.
- Watch the near/far boundary for pop: a building crossing in/out should keep identical
  geometry either way (it does — same bake), only its *fadeability* changes.

### Verdict

Only path to a big further cut (~3k → ~200 calls), but it's a real subsystem: tiering logic,
Occlusion rework, re-weld on movement. Do it only if 30fps at extreme shallow angles becomes a
real problem.
