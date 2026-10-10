# Emitted geometry: building a thing out of quads

WHETHER a thing should be geometry rather than a generated glb is decided elsewhere — the
silhouette-vs-surface triage in [`3d-models.md`](3d-models.md) and the `3d-art` skill. **This page is
HOW to build one once that call is made**, and it exists so the same four mistakes are not made
again on the next fitting.

Worked examples: [`render/facility/FacilityDeco.hx`](../src/render/facility/FacilityDeco.hx) (three
pieces of room furniture, per-face textures, an alpha-cut frame, turned boxes) and
[`render/facility/FacilityTables.hx`](../src/render/facility/FacilityTables.hx) (benches and corridor
casework, one shape recovered from neighbours). The emitters themselves live in
[`render/facility/FacilityGeom.hx`](../src/render/facility/FacilityGeom.hx) and
[`render/world/MeshBuf.hx`](../src/render/world/MeshBuf.hx).

**New findings go here, not into `CLAUDE.md`.** One bullet per lesson, the number that proves it
inline. A whole experiment still gets its entry in [`3d-changes.md`](3d-changes.md) and its row in
[`3d-render.md`](3d-render.md); this page is the distilled how-to.

## ONE TEXTURE PER FACE, not one per object

The mistake everything else on this page is downstream of. A fitting dressed in a single sheet is
wrong on every face that is not the face the sheet was drawn for, and it is wrong the same way each
time — measured on the first `FacilityDeco` build: **book spines lying flat across a bookcase's TOP
and running down its SIDES, cardboard boxes wearing the shelving's STEEL, a server rack's own vent
panel seen from above.** A face is a different SURFACE from the face beside it. Give it its own art.

- **Key the buffers by TEXTURE, not by object kind.** Two families sharing a material then share a
  draw call for free — the rack's sides and top ride the shelving's perforated steel because they
  really are the same metal.
- The cost is one merged mesh per texture. Measured at the gameplay camera: **78 calls vs 72** with
  6 of 8 meshes in frame, **240 tris for every fitting in the compound**. Triangles are never the
  constraint here; materials are.
- Reuse across families is fine when the material is genuinely the same, and a lie when it is not.
  "It is also grey" is not the same material.

## Which faces exist at all

- **No back** on anything standing against masonry — it is buried in the wall.
- **No bottom.** This camera pitches 51 degrees DOWN and never sees under a thing standing on the
  floor (`FacilityRoof.box`'s own finding).
- **No lid over contents.** At that pitch the top is most of what is read, so a cap over an open
  unit hides everything inside it and the thing reads as a closed slab — which is exactly what a
  plain textured box would have given, i.e. the whole composite wasted.
- A **zero-thickness** quad (a bare shelf) needs `side: DoubleSide`. An opaque material draws
  DoubleSide in ONE pass, so it is free.

## Tiling or 0..1 — and the aspect lock nobody expects

**Tile by default.** World-aligned UVs (`u = worldPos / TILE`) never stretch, and two units of a kind
in one room sample different phases of the sheet, so the variation is free and there is no per-unit
art. `TILE` is a MATERIAL scale — a perforation pitch, a wood grain, a rack unit's height — chosen
against the thing it draws and never against the object's own size.

**Map 0..1 only when the image is ONE authored composition**: a frame with holes in it, a front whose
three rows must differ from each other. Then:

- **The face's aspect is LOCKED to the image's**, or the art is stretched. Write the dimension as the
  product that produced it (`DECO_SHELF_D = DECO_SHELF_H * 0.640625` is a 656x1024 source), so the
  coupling cannot be edited away by accident.
- **A STANDALONE gpt-image-2 gen at 1k caps what that aspect can be**: a source needs **655,360
  pixels with no edge over 1024**, both multiples of 16. So on that route nothing narrower than
  **~0.64** and nothing wider than **1.6** exists — a 1024x512 top (524k) is refused outright.
  **A CROP off a packed sheet has no such floor**, and that is the way out: `deco-bookcase-front` is
  a 616x1024 sub-rect of one 1024 square, aspect **0.6016**, with the same unit's two tiling swatches
  in the strip beside it. Either check the aspect is legal before designing a face around it, or put
  the face on a sheet — see the packed-sheet bullet in [`3d-textures.md`](3d-textures.md).
- **Never CLAMP a 0..1 face — SLIDE it.** A clamp is a stretch. `FacilityGeom.slab` insets a wall
  face by a unit wherever the wall line stops, so a unit centred on its cell can hang past the end
  of the wall it is bolted to; the corridor casework clamps both ends and the lab kit rejects the
  cell, and neither is available to something already in the save. `FacilityDeco.fit` slides the
  span inside the masonry and only squeezes when the masonry is genuinely narrower.

## Read the geometry OFF the art

When the art has structure the geometry must agree with — rails on a frame, a course on a panel —
**measure it and derive the constants**, do not space things evenly and hope. Binning opaque coverage
per row of the built alpha put the shelving frame's cross rails at **0.063 / 0.381 / 0.699 / 0.954**
of its height:

```python
al = np.asarray(Image.open(built).convert('RGBA'))[:, :, 3]
cov = (al[:, int(w*0.25):int(w*0.75)] > 128).mean(axis=1)   # ignore the uprights
rows = [i for i in range(h) if cov[i] > 0.5]                # then group consecutive runs
```

Spaced evenly against whatever the generator happened to draw, a shelf floats between two rails and
the unit reads as a wire cage with slabs in it. Re-measure after every re-roll of that source.

- **Never sit a horizontal quad at floor height.** At y = 0 it is coplanar with the room floor and
  z-fights across its whole footprint. Give it the art's own foot offset.

## Values: fit them LIVE, and know what `lift` can and cannot do

- **An interior VERTICAL face renders at roughly a fifth of its albedo here; a horizontal one at
  ~0.71.** Measured: a 47-mean bookcase front drew **15** against a floor at 79 and a wall at 64.
  A dark painting is not a dark object indoors, it is an invisible one. Fit at the game camera; do
  not predict off the albedo (ACES has a toe — see [`3d-render.md`](3d-render.md)).
- **`lift` is a GAMMA.** It moves the VALUE and SCALES whatever cast the art already has; `g < 1`
  brightens, `g > 1` darkens. It cannot desaturate: at `g` 1.28 a roll's R−B went **58.6 → 59.3**.
- **So hue is fixed by re-rolling, never by lifting** — the >6 channel-spread rule in
  [`3d-textures.md`](3d-textures.md). A shelf sheet at spread **13.4** rendered visibly teal
  (24.5/39.5/45.8); the neutral-hue clause returned **1.7**.
- **A chroma TARGET is unreachable from prose.** Three rolls for cardboard: "warm tan-brown" → R−B
  **67**, "greyed, very low chroma" → R−B **8.5**, naming the number outright → R−B **58.6**. What
  fixed it was not words but **company: drawn BESIDE the grey steel on one packed sheet**, the same
  prompt returned channel spread **48** and the boxes finally read as cardboard. Two faces of one
  fitting that must not be confused with each other are an argument to generate them TOGETHER — see
  the packed-sheet bullet in [`3d-textures.md`](3d-textures.md), and **ask the user which route**.
- Fit against the neighbours, not in the abstract: boxes at lift 0.66 measured **79 on top against a
  floor at 79** and were the brightest thing in the room; the shipped tile lands 68/58 over the
  steel's 54, and a re-roll's `lift` is solved to hit that same built mean so the A/B tests the art.

## Alpha-cut faces

- **Opaque `alphaTest`, not `transparent`.** It draws DoubleSide in one pass and still writes depth,
  where a transparent twin sorts against every other see-through thing in the level for nothing.
- Leave `transparent` false so `VisionMask.patch` compiles its darkening branch rather than the
  alpha-scaling one (the trap `FacilityGeom.addPane` records).
- **A THIN-WIRE CUT VANISHES WITH DISTANCE, and the tile size is the knob, not the cut.** The mip
  chain AVERAGES alpha, so a wire 13 px wide in a 512 sheet drawn at 256 texels per world unit
  (`military/chainlink` at one sheet per 2 units) is under the cut by the time the camera is 60 units
  off: the whole perimeter rendered as bare posts. One sheet per **4** units (128 texels/unit) with
  the cut at **0.3** reads at the gameplay distance. Size an alpha-cut mesh for the mip it is SEEN at.
- **Honest member width reads as WIRE.** Real angle iron at ~4.6% of the image width is 0.077 world
  units of steel, and on screen that is a wire cage. The frame was regenerated at 12% uprights and
  5% rails: opaque fraction **26% → 39%**. Measure the opaque fraction, not the intent.

## Standing it against a wall, and turning it

- Take the rect off **`FacilityGeom.slab`'s own face**, never the cell boundary — the slab is a unit
  inside the cell wherever the wall line carries on.
- Depth against a wall is a LOOK decision, not a gameplay one, when the cell is already unwalkable.
  It is a gameplay one on a walkable cell — see `CASE_D`'s header.
- **A turn costs geometry twice.** Turning a box about its centre reaches `hd·cos J + hw·sin J`, so
  the half-depth that still fits inside a shelf is `(deep/2 − hw·sin J) / cos J` — the lab trolley's
  `KIT_GAP` arithmetic solved for the box — **and the same swing along the other axis has to be
  clamped separately**, or an end-bay piece turns its corner out through the frame.
- Size a repeated piece in **WORLD units** with its slot only as a cap. Sized as a fraction of its
  bay, one box on a 2.6 shelf came out **1.6 wide**.
- Every roll comes off `FacilityModel.mix` on the cell (and the sub-index), never `Math.random()` —
  a unit has to come back identical on every rebuild of the same area.

## Wiring one up

1. One `MeshBuf` per texture; `FacilityGeom.geom(b)` → `VisionMask.patch(new MeshLambertMaterial({
   map: Textures.loadTexture(tex, 'wall', 1) }))`, `receiveShadow = true`, `castShadow = false`.
   `VisionMask.patch` folds in `IndoorMask` for free when a mask is attached.
2. `ContactMask.prop(x0, x1, z0, z1)` per unit, and the pass must run **before**
   `ContactMask.repaint()` in the area's `build`.
3. **Warm it**: mirror the pass in `FacilityWarm`, and make sure `FacilityModel.demo()` contains one
   of every variant — a material with nothing to emit in the warm scene compiles its program on the
   first real area entry instead (measured precedent: 91 → 101 programs).
4. If it replaces an object's sprite, suppress that sprite through `Actors`' `iconOff` with a
   stateless predicate (`FacilityDoors.draws` / `FacilityDeco.draws` are the two shapes).
5. **Measure the calls** with a visible-toggle A/B at a pinned camera, median over ~7 frames, reading
   `renderer.info.render.calls` — not the scene dump. See [`3d-render.md`](3d-render.md).

## The emitters

`FacilityGeom`: `face` (vertical, world-tiled), `pane` (vertical, 0..1), `cap` / `capDown`
(horizontal), `ends` (the winding — getting it backwards makes a whole axis of faces vanish silently),
`plane`, `geom`, `add`. `MeshBuf`: `quad`, `quadC` (one grey per vertex), `quadRGB` (three
independent numbers per vertex — used to carry level, blink phase and hue on one additive mesh).
Anything not axis-aligned builds its own corners and winds them in one consistent cycle; see
`FacilityDeco.crate`.
