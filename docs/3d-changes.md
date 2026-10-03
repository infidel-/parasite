# 3D render changes — running log

Append-only. One entry per experiment, ~25 lines: what changed, the measured numbers, the trap, the
verdict. Settled outcomes only. Every entry needs a matching row in
[`3d-render.md`](3d-render.md)'s verdict table, or it is invisible. Earlier entries are in
`3d-changes-2026-09e.md` and its predecessors.

## Corp reception counter in the wall line

The reception's wall onto the corridor is replaced post to post by `TILE_CORP_RECEPTION_COUNTER`
(gen side: `docs/area-gen.md` "THE RECEPTION FRONTS THE CORRIDOR MOUTH"). `render.corp.CorpReception`
emits it; `CorpModel` reads the id as `Surf.RECEPTION` floor with `CorpFurniture.FIT_COUNTER` on it.

- **NOT A WALL VALUE, and that is the whole design.** A `Wall.COUNTER` was planned; it would have had
  the corner posts CARRY into it (`FacilityGeom.carries`), and a carried neighbour gets no face — a
  hole in the masonry up to the ceiling. As `Wall.OPEN` each post ends its partition in a full-height
  face of its own, the vision mask sees over the counter with no predicate touched, and the floor
  runs through under it. The counter's ends run INTO the post cells to `thick / 2` off their centre,
  or a (CELL - thick) / 2 gap opened against every post.
- **Two tiers inside the one 4.0 wall cell**, `u` off the wall line: body −0.2..0.8 to 2.1, a marble
  ledge to `REC_LEDGE_H` 2.2 overhanging the corridor by 0.25, and a worktop −1.9..−0.2 at `DESK_H`.
  Marble top on the boardroom's Phong (`glossy`), front in `reception-front`, room face in the
  kitchen's oak `counter-front`. Receptionist's chair, monitor and keyboard into `CorpProps`' own
  batches; `MON_BACK`/`KEY_FWD` were fitted to a 3.30 top and put the keys off a 1.7 one.
- **Trinkets** (`reception_build.py`, 48/44/248 tris, 0 holes / 0 coplanar / 1 island): phone,
  WELCOME board, bell, plus the desk plant and five `desk-clutter` decals, laid out and not rolled
  (`CorpReception.dress`). The board went 2x → **3x** (at 2x its face was 44 x 16 px) and one cell IN
  from the lift end, where the outer wall's rim hid it from the rig camera.
- **Logo**: `reception-logo` 0..1 at its measured 2.74 on the wall the counter faces. The walk
  across the room first asked `isWall`, went OUT THROUGH THE STAFF DOOR and hung the logo in the next
  room; it stops at the wall LINE (`carries`) and slides to solid masonry. `CorpSigns` keeps its
  framed art `REC_LOGO_CLEAR` 2 cells off it.
- **Cost, measured live** (3 interleaved on/off pairs, one pose, zoomed on the room): **190 vs 179
  calls, +11** — six meshes plus their shadow-map draws. Warm: the demo model carries a 2-cell
  counter, so both marbles, the Phong top and the logo compile at boot.

Verdict: **landed.**

## Corp reception desks draw as desk glbs, not boardroom slabs

The reception's back office (`gen.corp.CorpRooms.backOffice`, `docs/area-gen.md`) lays back-to-back
desk banks on `Surf.RECEPTION`. `CorpFurniture.slabTop` listed RECEPTION among the table surfaces,
for the OLD edge-row counter, so a bank came out as one boardroom slab with fascia and blade legs
and monitors on it — the "four bare tables" bug the cubicle farm already had once.

- **RECEPTION joins OPEN/CUBICLE in `deskCell` and leaves `slabTop`**: every reception table is a
  `corp/desk-bench` glb. The only other reception tables are `decorateWalls`' lone wall tables, which
  were desk glbs already by the lone rule. An old save's edge-row counter now draws as a row of desks.
- **Seating needs nothing new.** `CorpProps.backHand` tries the two z hands first, so a bank running
  along x finds its partner row as the back and seats the chair on the open side; the generator lays
  banks along x only, because a bank along z would take its own run neighbour as the back.
- **A receptionist per station** (`Const.receptionStations`, one per 3 cells): chair, monitor and
  keyboard per station, a phone each on the side away from the lift-end plant, the sticky notes
  dropped where they would land under that plant.
- Live: a 5 x 7 room took one 2-desk bank, a wide one a 12-desk bank and two stations. Everything
  rides existing batches (chair, workstation, desk-bench, phone), so no new batch; draw calls not A/B measured.

Verdict: **landed.**

## Corp reception counter: ends proud of the post closed, arrises rounded, phone rebuilt

- **The counter is deeper than the post it is set into, on purpose** (front 0.8, ledge 1.05 off the
  wall line against a post's `thick / 2` 0.667), and its ends at a masonry post emitted NOTHING —
  right for the part inside the post, wrong for the 0.13 (body) and 0.38 (ledge) standing proud of
  it. Reported off a face pick as protruding round the wall corner with a quad missing.
  `CorpReception.ends` now emits, at a masonry end, only the across-run strips outside the post's
  `slab`; at an open end the whole face, as before.
- **Rounded top arrises** on the ledge (every open hand) and the worktop (all but the body hand):
  `CorpFurniture.roundEdge` / `inset` made public, `roundEdge` takes its radius (`REC_ROUND` 0.06
  here, `TABLE_ROUND` 0.05 for the boardroom as before). Faces stop `rad` short of the top; the strip
  proud of a post runs to the top, since there is no band there to hand over to.
- **The phone was four boxes at 48 tris**, reported as "really blocky". Rebuilt in
  `reception_build.py`: a body rounded in plan with a sloped, chamfered top, a waisted lathe handset
  front to back on two cradles along the slope, the key pad in the slope, a cord to the flank.
  **362 tris**, 0 holes / 0 coplanar / 1 island. `REC_PHONE_H` 0.321 / `REC_PHONE_R` 1.4255 off the
  new 0.458 x 0.437 x 0.161.

Verdict: **landed.**

## Corp glb batches take the indoor swap whenever their glb lands

Reported as a dark blue desk plant on the reception ledge. The texture is neutral (pot 47,47,46),
and so were the material, the vertex data and the fog. What was missing was the patch: four
batches — `desk-plant`, `rec-phone`, `rec-board`, `rec-bell` — carried `visionMask` and no
`indoorMask`, so they were lit by the outdoor rig (ambient `46536b`, hemisphere `56668c`, moon
`8294c0`). Pot rendered `18,24,38`.

- **Cause: the warm, and my reception counter in its demo model.** `CorpWarm` builds the demo plate
  with `IndoorMask` attached and detaches it at the end, but `CorpProps.batch` patches in the glb's
  LOAD CALLBACK, which lands after the detach. `VisionMask.patch` folds in the indoor swap only while
  `IndoorMask.on`, the SOLID material is the path's shared template, and the patch marks it — so the
  first patch wins for every tower after. Before `CorpModel.demo` carried a counter, the warm's
  `CorpClutter.build` placed none of these four and its later per-path loop patched them correctly.
- **Fix: `CorpProps.batch` calls `IndoorMask.patch` itself**, after `VisionMask.patchMesh` — a no-op
  where it already went in, and a no-op for any fragment the mask reads as outdoor. The same reason
  `render.particles.Sprites` patches unconditionally.
- Verified live: no corp instanced batch left with `visionMask` and without `indoorMask`, and the pot
  renders neutral 22,22,22.

Verdict: **landed.** A glb patched in a load callback cannot trust a mask's `on` flag at build time.

## Corp security room: seated console, wall racks, low wall machine, video wall, lockers, CCTV cams

The probed "quad desk" at y 1.9 was not the desk: it was the lid of `CorpDeco.box` K_MACHINE, the
last laminate casework in the tower. The console was a 3-cell SERVER run that `deskCell` sent to a
worktop slab, and no monitor, keyboard or chair was ever seated on SERVER. Gen side:
`docs/area-gen.md` "THE SECURITY ROOM".

- **Console.** `CorpModel.securityDesk` joins `deskCell` and `CorpProps.desks`/`claims`/`manned`, so
  the run is desk-bench glbs with monitors, keyboards and chairs. `securityPostDesk` (the middle
  cell) gets no chair, because the guard stands there.
- **Racks** on `TILE_RACK_HIGH` keep `FIT_RACK` (`wallFits` clears it on the 222 twin only), and
  `CorpFurniture.rack`'s front search skips wall neighbours, so the east column faces the room.
- **Wall machine** (`CorpFurniture.machine`): a half-height two-bay rack against the wall, from
  `RACK_TOP`/`RACK_SIDE` and a cropped `RACK_FRONT` (uv v 0..0.5, `u` over 2 bays), with LEDs in the
  blink mesh. It replaces the laminate box in the server room as well. **TRAP:** a wall prop lives in
  the 1.4 margin between the cell edge and the slab face, so a search window sized to the cell
  missed it.
- **Video wall** (`CorpSecurity.build`): one `corp/cctv-wall` pane per console cell on the north
  slab face + 0.06, its own emissive Lambert (map = emissiveMap), no shadows. `CorpSigns` keeps
  framed art off those cells (`videoClear`).
- **Lockers** (`FIT_LOCKER` 7): per-face emission (a `locker-front` pane, `RACK_SIDE` on free ends
  only, a `RACK_TOP` cap) with one `FacilityDetail.ground` per run.
- **Cams** (`CorpSecurity.cams`): the corridor and reception inside corners with a solid north wall,
  hash-thinned 1 in `CAM_EVERY` 2, the `corp/wall-cam` glb (124 tris) turned 0.3 toward the floor.
  The recording light is a new `FacilityDeco.blink` mode: blue > 7.5 means red (`DECO_LED_RED`), and
  it rides the existing LED mesh.

Calls A/B in the security view: video wall +1, lockers +1, cams +2. The machine and console ride
existing batches and were not A/B measured. Warm: the screens material and the wall-cam path
are in `CorpWarm`.

Verdict: **landed.**

## Corp object props: the gun cabinet glbs, and the per-frame pass the tower never ran

The gun cabinet (`objects.GunCabinet`) is the tower's first `render.world.ObjModels` glb:
`gunCabinet`/`gunCabinetOpen`, hand-modelled at 108/264 tris, with a WALL yaw.

- **`ObjModel.off`**: a local [x, z] offset rotated by the yaw. The carcass stands in the margin
  between its cell and the slab (`GUN_CAB_BACK`), and the open glb's footprint centre is
  (-0.231, -1.172) off the shut one's. Without the offset, `Models.normalize`'s recentre would jump
  the carcass when it opens.
- **The lid rendered moonlit navy**: ObjModels batches took no indoor swap. `CorpArea.patchObj` now
  applies `ObjModels.patchRow` and then `IndoorMask.patch`, in `CorpProps.batch`'s order, from
  `indoorProps` and from `CorpWarm`. The warm covers all three variants of every `models/corp/` row.
- **Cost +10 calls → +2.** `CorpArea.tick` never called `ObjModels.cull`, so the ghost (transparent)
  and hull twins drew every frame. It now runs FacilityArea's three lines (cull, `PropShader.tick`,
  `PropGlow.tick`).
- **TRAP: `refreshObjects` left the OLD batches drawing, for doors as well.** `Chunks.build` sweeps
  every mesh already in the scene into chunk groups, and a glb cached by the warm is instanced
  SYNCHRONOUSLY at build time, so the props and door leaves ended up in chunk groups.
  `scene.remove` was a no-op on them. After an open, the shut cabinet and a second set of door
  leaves stayed on screen. `ObjModels.dispose` and `FacilityDoors.dispose` now call
  `removeFromParent`, which fixes every area kind, and it was added to the `Object3D` extern.

Verified live: after an open, only the open batch is in the scene, one door batch per texture, and
the ghost/hull counts are 0.

Verdict: **landed.**

## Security room pass two: own steel, racks on the wall, a lit header, feeds that cut

Four reports off face picks.

- **Reused textures.** The lockers wore `rack-side`/`rack-top`, and the cabinet's sheet packed the
  same two. Both now have their own, from one packed 1k sheet (`corp/security-pack`, $0.0555):
  ribbed charcoal locker ends and a plain lid, riveted gunmetal cabinet flanks and a brushed lid.
  Each crop is WHOLE PERIODS of its pattern: ribs at a measured 107.7 px (431 square), rivets at
  90.9 x 86.6 (364 x 346, a 5% squeeze that the round rivets hide). Each lift is solved onto its own
  front's built value (0.0525 / 0.0523), and all four built within 0.0001. `LOCKER_TILE` = one tile
  per locker height, so the four ribs sit on a bank as real pressings would. Cabinet `R_PLAIN` was
  re-measured clear of the rivets (sd 1.59 against the cell's 4.46).
- **Painted guns nobody can take.** `corp/gun-cabinet-inside` is an `edit_image` of the first roll:
  empty hooks, saddles and foam cut-outs ($0.039). Lift re-solved 0.834 -> 0.809 onto the first
  roll's built 0.0368.
- **Racks against the wall.** `CorpFurniture.rack` pushes a slab to its AISLE, which is right in a
  server room rank and left the security column a cell-deep gap from its wall. With masonry on its
  back hand, the back now goes to the slab's room face (lockerRect's rule).
- **The wall column is walkable** (`Const.TILE_CORP_WALL_RACK`, gen side in `docs/area-gen.md`), so a
  wall-backed rack is `RACK_WALL_D` 1.3 deep and stands in the wall's margin like the lockers.
- **SECURITY header** over every doorway into the room, on the lintel's outside face (the door
  cell's slab IS the lintel, FacilityExit's plane). A 3.2 x 0.52 emissive pane at y 4.95, between the
  4.2 door head and the 5.8 ceiling. The source is a 1024x640 gen on black, cropped to the frame's
  measured bbox (990 x 161).
- **Feeds cut between views** (`CorpSecurity.feeds`). Each panel's u carries its index in the whole
  part. The shader re-deals each screen's feed off a hash of (panel, screen, epoch) every
  `FEED_TURNS` 40, staggered per screen, with a `FEED_STATIC` 5% snow burst at each cut. The clock is
  BASE_MS-relative (`CorpSecurity.tick`). Screens are the art's MEASURED cells: columns on thirds,
  but the row gap is at 324 of 672, not the half. `textureGrad` samples off the continuous uv so the
  jump at a screen edge does not drop to the smallest mip.
- **TRAP: `onBeforeCompile` sees `#include <map_fragment>` UNEXPANDED.** A replace on
  `texture2D( map, vMapUv )` matched nothing and compiled clean; the feed function was there and
  never called. The chunk is swapped in expanded, from `THREE.ShaderChunk` (added to the extern),
  with the sample replaced inside it. ANGLE also warns on dynamic `vec3[int]` indexing, so the screen
  edges are selects.

Calls A/B at the security view: locker ends +1, locker lid +1, header +1; the video wall is still
+1, with the animation inside the same draw. Warm: the header's plain emissive lambert has its own
`CorpWarm` pane (a second key beside the feed-patched wall).

Verdict: **landed.**

## Gun cabinet door swings open in the vertex shader

"armory locker door open anim - we need it". The Open action flips the model key and
`CorpArea.refreshObjects` rebuilds the batch, so the door POPPED from shut to swung.

- **The open glb's leaf is built SHUT** (`gun_cabinet_build.py`), `LEAF_GAP` 0.01 proud of the
  carcass front, so the swap itself shows nothing. Footprint centre (-0.231, -1.172) -> (0, -0.03),
  `CorpStyle.GUN_CAB_OPEN_*`. 264 tris, unchanged.
- **`CorpSecurity.swing`** turns every vertex deeper than `GUN_CAB_LEAF_Z` 0.655 (glb frame, glTF z =
  Blender -y, half way across the gap) about the hinge (-1.2, 0.66) by `smoothstep(cabSwing) *
  -1.745`, position after `<begin_vertex>` and objectNormal after `<beginnormal_vertex>`. Solid, ghost
  and hull, all through `CorpArea.patchObj`, so the warm spells the same keys.
- **TRAP: the hull is normal-inflated geometry** (`Models.hullGeo`, 0.06 out), which pushes the
  carcass front past the leaf threshold. The test reads `position - normal * inflate`, with
  `OBJMARK.hullW` for the hull (instance scale is 1, the glb is authored at `GUN_CAB_H`).
- **Timing**: `uSwing` is set to 1 at area build (a cabinet found open is open) and zeroed by
  `refreshObjects` when the open batch gains a placement; `tick` runs it over `GUN_CAB_SWING_TURNS` 3
  (450 ms at BASE_MS 150; 1 turn was a blink). One uniform for every open cabinet: a second one
  opened on the same floor re-swings the first.
- Shadow depth is not patched: the leaf's shadow stays shut. Not visible at the ceiling lamps' angle.

Verified live: mid-swing frozen at 0.45 reads as a door at 45 degrees, 1.0 lands where the old baked
leaf stood. No new draw call, no new program family (same row, one more key suffix).

Verdict: **landed.**

## Security room: rack and cabinet wall contact, door-only ghost, cabinet off perimeter walls

Three reports, one pass.

- **No wall contact shadow on the racks or the cabinet.** A wall-backed rack laid `ContactMask.prop`
  alone, the floor half. It now takes `FacilityDetail.ground` once per COLUMN from its first cell
  (`CorpFurniture.rackGround`, the locker bank's rule; mid-room ranks keep the floor field). The
  cabinet is an object prop that no fitting pass sees: `CorpSecurity.ground` lays its locker cell's
  `lockerRect` narrowed to `GUN_CAB_W` 2.4, after `CorpSecurity.build` and before `halos`.
- **"can you make only door transparent?"** The ghost faded the whole cabinet. Now the shut glb is
  the open glb's geometry (leaf built shut, 264 tris), so the leaf is a separable part in both, and
  a row flag `ObjModel.ghostPart` keeps the SOLID drawing the placement under the player.
  `CorpSecurity.door` splits them: the ghost discards everything but the leaf, and the solid
  discards the leaf of the one instance whose `instanceMatrix[3].xz` matches `uGhost`, which
  `ghostDoor` sets after `ObjModels.cull` from the batch's `solid.centres[ghostIdx]`. Leaf test =
  `swing`'s (`position.z > GUN_CAB_LEAF_Z`). OPEN ONLY: "don't fade CLOSED door". A shut cabinet
  stands in the wall's margin and hides nobody, so its row is `noGhost` (never takes the ghost
  index) and keeps no door patch.
- **TRAP found on the way: the cabinet sat 0.4 inside a perimeter wall.** Its `off` is written
  against a partition's room face (`GUN_CAB_BACK`), and the tower's perimeter is 2.0 thick against
  1.2. Cut open, the carcass showed the wall's own face where its back panel was, and shut, its
  front stood 0.4 behind the lockers. `ObjModels.build` takes an optional `wall` hook now, added to
  a WALL-yawed row's depth; `CorpArea.objWall` answers `(thick - WALL_INNER) / 2` off the wall
  objYaw picks. Measured: the centre moved -172.75 -> -172.35, front flush with the locker bank.

Verified live with the ghost forced onto the cabinet: carcass solid, leaf gone, dark interior.
0 new draw calls; two new program keys (`cabdoor`, `cabdoorghost`), warmed through `patchObj`.

Verdict: **landed.**

## Corp lift shaft: the drop under the lift car is an exposed steel frame, no lit bays

Reported off a face pick: `corp facade textures/downtown/glass-dark.png` at (31, -38, -101), "outer
walls under the elevator should not have glowing windows and should have another texture".

- **What it was.** `gen.blocks.ElevatorBlock` hangs the 3x3 car OUTSIDE the wall ring, so its posts
  and glazing are perimeter cells, and `CorpFacade.build` dropped each one to the street as curtain
  wall with lit bays like the rest of the tower: a glowing glass column under a glass box.
- **The test.** `CorpFacade.liftAt`: a perimeter cell with a `Surf.LIFT` cell anywhere in its 3x3.
  The car floor is the only LIFT on the plate apart from the lift door. Diagonals count, so the corner
  posts are included. The tower's own wall either side is two cells from the floor and keeps its
  glazing.
- **The look.** Its own art, `corp/lift-shaft`: the exposed steel frame a panoramic car rides on,
  two X-braced bays square with guide rails and hoist cables in the void behind. Repeated at
  `CorpStyle.SHAFT_TILE` 12, i.e. one bay per storey (WALL_H 6). The drop, its ledge cap and its
  notch faces go into a separate `shaft` buffer with no `drop` bays.
- **TRAP: the first pass borrowed `downtown/wall-mechanical`** (the penthouse bulkhead: louvred vent
  panels) and was rejected on sight, because a lift shaft is not a rooftop plant room. This is
  [`3d-textures.md`](3d-textures.md)'s "a new object wants new labels" rule biting again.
- **TRAP: the model did not centre the frame on the edges** as the prompt asked, so the raw drop
  wraps as a doubled column and a doubled beam. The column-to-column crop is `[34,30,956,956]`,
  measured off the drop; the `textures.json` note has the numbers. It also needed `lift` 0.87 to land
  at built sRGB 35.6 beside `downtown/glass-dark`'s 34.8. At 27.8 the frame sank into the night.

Measured live on area 5646: shaft mesh 26 quads over x 15..31, z -116..-96. No lit-bay or
glass-dark vertex lies inside that box except on the tower's own x = 15 face, which is outside the
shaft. +1 draw call (one more `add` mesh) and one new 512 texture. One gen, $0.0557.

Verdict: **landed.**

## Corp glb props cull per instance on their own bounding spheres

From the corp perf report (live census, six investigations). `CorpStyle.PROP_CULL_R` was 120 and
`Models.cull` treats it as the radius of a sphere at every placement, so it was a 30-cell MARGIN and
not a draw distance: the chair batch drew 63 of 63 with none on screen, and 25-40 of the 34 batches
per spot had nothing in view. Each of them also drew again into the moon map every frame.

- **`Models.cullExact`**, corp only (the glb and clutter-prop batches). Each placement's own world
  bounding sphere (geometry sphere × `getMaxScaleOnAxis`, baked once on first call) + `PROP_CULL_R`,
  now **2**: it covers the sway shader and the moon throw of the tallest prop (arch-shelf, 4.8).
- **Visible instances are packed first and the hidden ones AFTER them**, so the buffer always holds
  the whole set. `onBeforeShadow` sets `count` to all of them and `onAfterShadow` hands the visible
  count back: **every shadow pass draws the full set.** TRAP: the spot maps are frozen
  (`autoUpdate = false`, refreshed on a slot swap), so a map that refreshed off the camera's subset
  would keep that hole until the slot next changed owner. Measured before the fix: 2-4 of the 8 maps
  per spot serve lamps whose casters are all off screen.
- `mesh.visible = count > 0 || keep`, where `keep` means a shadow map renders this frame. This phase
  keeps everything listed, because the moon still renders every frame.
- `Models.cull` is unchanged. The doors pose their matrices every tick, so baked spheres cannot serve
  them, and facility, city and ObjModels keep their radius.

Measured on the RTX 3050 Ti laptop, A/B/A/B at one pose, 5 × 30 frames, medians (old = cull at 120):
lift **194 → 169** calls, 1.09M → 655k tris; cubicle **164 → 138**, 1.19M → 679k; security
**180 → 156**; lift tactical **218 → 193**. Submit was flat (the empty batches are still listed);
GPU −1.0 ms in follow view, tactical within noise. Pixel diff against a control frame was zero at the
cubicle, the cubicle in tactical, the lift and exec, and zero with all 8 spot maps forced to refresh
at the cubicle and the kitchen.

Verdict: **landed.**

## Corp lift's blank elevator sprites dropped; transparent DoubleSide quads draw in one pass

Why the lift read ~200 calls against a room's ~165. Two causes, both measured live off a per-call census.

- **The nine `elevator` objects painted nothing, at 36 calls.** `GenSpawner` spawns each lift cell as
  `new Elevator(...)` with no image, so it falls back to `entities` cell (0,0), which is fully
  transparent (alpha extrema 0,0). No `iconOff` hook covered `type == 'elevator'`, so `Actors`
  painted an icon, a hatched silhouette and, in tactical, a ring per cell. `CorpDeco.draws` now
  answers true for a corp elevator, and the mark and ring follow, because both are gated on `iconOff`.
  The underground lab's elevators keep their art: the gate is `AREA_CORP` only.
- **`forceSinglePass`** on the sprite pool (and `Sprites.warmupMeshes`, so `Warmup.splitDoubleSided`
  stops warming a Front/Back pair the game no longer draws), the corp lamp floor/ceiling glow, the
  deco LED glow and the player ring. Each is one flat quad with no self-overlap, and most are
  additive, so the default back-then-front split was a second call for an identical image. The pool
  keeps DoubleSide because `faceX` mirrors by negative scale.

Measured on the 3050 Ti laptop, census after vs the phase 1 commit: lift **169 → 127**, lift
tactical **193 → 133**, cubicle 138 → 133, security 156 → 147. A/B/A/B submit: lift 3.3 → 2.6 ms,
lift tactical 4.1 → 2.7, security 3.3 → 2.8. Pixel diff below the control frame at the lift, lift
tactical and the cubicle. No new program: the two first-use compiles seen while sweeping (glossy Phong
furniture and the ring's plain basic program on first tactical) were first-use compiles before too.

Verdict: **landed. The lift is a room now.**

## Actor sprite crops read back from CPU-backed canvases (walk hitches, every area)

Found while walking the corp corridor: on 3 of 46 steps the first frame after the step took
31-53 ms, all of it `upd`, and the game's own `[street-perf] SPIKE 46ms … actors=410` agreed.

- **Cause.** On a texture-cache miss (an NPC cell or skin variant seen for the first time),
  `Sprites.tex` crops into a DEFAULT 2D canvas and `darkenCanvas` runs `getImageData`/`putImageData`,
  because `DECAL.actorMul` is 0.7. A default canvas is GPU-backed, so each readback is a synchronous
  GPU round trip: **~34 ms each** on the Radeon iGPU (the `drawImage` crop alone is 0.1 ms).
  `patternWhiten` (x-ray `silTex`) and `boxOf` (`texContent`, `cellBox`) do the same.
- **Fix.** `getContext('2d', { willReadFrequently: true })` on the six canvases that are read back
  (`tex`, `silTex`, `texContent` scratch + crop, `cellBox`, `atlasTex`), the idiom `PolyProbe`
  already uses. Same pixels, same `texCache`; only the backing moves to the CPU.
- Not corp-specific code. Corp just hits it hardest: a crowd of ~400 actors over male/female × 3 skin
  atlases misses the cache constantly on a walk.

Measured on the 3050 Ti laptop, the same 46-step corridor walk on a fresh cache: `Sprites.tex` max
**27.2 → 7.6 ms**, `silTex` **13.3 → 1.0 ms**, `texContent` 3.3 → 1.4 ms, max frame `upd` **53 → 17.6 ms**.
The 17.6 is `mouse.update` (13.5 ms) on one step, a separate cost, not chased.

Verdict: **landed.**

## Corp moon frozen, empty prop batches leave the list, small props stop casting

- **The moon.** Corp builds the compound's rig (`FacilityScene.build`) and keeps its DirectionalLight
  but never calls `SceneSetup.fitMoon`. The ortho box therefore sits at the world origin, over the
  plate's SE corner (exec wing and lift on the old fixture), and at `INDOOR.direct` 0.22 its shadows
  are faint. It was `autoUpdate`, so every frame it re-drew every caster on the floor: 42-47 calls,
  ~0.5M tris. `CorpArea.scene` now freezes it (`autoUpdate = false`, `needsUpdate = true`). `tick`
  re-renders it whenever the count of LANDED glb batches changes, because the loader resolves after
  the first frame and a map frozen before the props arrive has none of them. Fitting it to the player
  was measured too: same cost, plus faint moon shadows over the whole floor. Rejected.
- **CORRECTION** to "the tower's furniture CASTS" (+26 calls, 133/107 at a held pose): no spot map
  refreshes at a held pose, so that delta was this moon pass, not the ceiling spotlights.
- **Empty batches.** With the moon frozen, `cullExact`'s `keep` is
  `LampLights.lastShadowRenders > 0 || moon.shadow.needsUpdate`. On every other frame a batch with no
  instance in view is `visible = false` and leaves the render list. That is the half of phase 1 that
  moves `submit`: a zero-count batch still costs `renderBufferDirect` its state setup.
- **Non-casting.** `CorpStyle.SHADOWLESS` lists plant, keyboard, exec plaque and photo, wall cam,
  desk mug and bottle, kitchen coffee and microwave. Whiteboard and mirror (emitted, flat on the
  wall) pass `casts = false`. Measured beforehand with all 8 spot maps forced and the moon off: 0 px
  for the plant, ≤ 0.005% for the rest. The plant is 4,206 tris × 82, 60% of the prop triangles
  that went into every map on refresh. Monitor (0.15%) and chairs (0.19%) keep casting.

Measured on the 3050 Ti laptop (new fixture, slot 5: the autosave was deleted by a game over), old
arm = moon live + everything casting + keep forced, A/B/A/B 5 × 30 medians:

| spot | calls | tris | submit ms | GPU ms |
|---|---|---|---|---|
| lift 29,43 | 151 → **106** | 745k → 90k | 2.6 → 1.9 | 7.2 → 5.9 |
| cubicle 48,10 | 123 → **81** | 810k → 155k | 2.4 → 1.7 | 5.1 → 4.2 |
| security 9,39 | 140 → **95** | 748k → 93k | 2.6 → 1.9 | 4.7 → 3.8 |
| exec 37,21 | 138 → **95** | 774k → 119k | 2.6 → 1.9 | 4.6 → 3.9 |
| lift tactical | 152 → **107** | 763k → 108k | 2.7 → 2.2 | 4.7 → 4.2 |

Pixel diff against a control frame was at or below noise at all five, and again with every spot map
forced to refresh at the cubicle and exec.

Verdict: **landed.**

## Corp street and its blur pass gated on the view reaching past the plate

The street is 24 calls of ring-wide meshes (15 opaque per-texture, lit bays, roof decals, crowd). Each
spans the whole ring round the tower, so its bounding sphere always passes the frustum and it drew
from every room. `StreetBlur`'s fullscreen pass ran with it, ~0.5 ms. Measured beforehand: street
pixels on screen 0% at the corridor, exec, meeting and server rooms; 21% at the lift.

- **`CorpArea.overPlate`.** The section of the view frustum by the floor plane (y = 0) is the convex
  quad of the four screen-corner rays' hits, so every downward ray crosses the floor inside it. If
  every cell in that quad's bounding rect (and the camera's own) is tower, every ray meets the floor
  before anything below the plate's edge. The test is per cell (`isIndoor || carries`, the facade's
  own predicate) and not the plate rect, because the rect holds the reentrant corner slots, which
  are open to the street.
- `tick` sets `street.group.visible` off it, never before `CorpStreet.settled()` (hiding the group
  before its frozen shadow map is written writes the map empty) and never under the free cam.
  `View` sets `streetBlur.pass.enabled` off `CorpArea.streetShown` each frame. The facade's own
  blurred meshes stay outside the group: by the same argument they cannot show when the gate is shut.

Measured on the 3050 Ti laptop, slot 5. The gate shut at exec 37,21, the plate 29,24 and archive
15,16, and stayed open at the lift, cubicle, security, kitchen and both tactical views. Forced-open vs
gated pixel diff: 0 at exec and the plate. At the archive the only difference was the server rack's
LED blink, which the control frame caught in another state. A/B/A/B where shut: calls **97 → 72**,
97 → 72, 109 → 84; submit −0.2…0.4 ms; GPU −0.7…1.1 ms.

Verdict: **landed.**

## Corp glbs on Lambert, and the street sun without its shadow: both rejected on sight

Two GPU levers from the corp perf report, measured as runtime arms on the 3050 Ti laptop (slot 5)
and shown side by side before any code.

- **Lambert.** 31 of the 32 corp glb batches stay `MeshStandardMaterial` because the hand-modelled
  set bakes `roughnessFactor` 0.72 and `Models.toLambert` keeps anything under 1 on Standard (only
  the TRELLIS plant is Lambert). Swapping them changed 1.1-2.5% of pixels, slightly darker, max
  30-61 levels. The visible loss is the ceiling lamps' sheen on glb surfaces, clearest as the lamp
  pool on the exec walnut desk going flat. GPU −0.2…0.6 ms.
- **Street sun `castShadow` off.** Every lit fragment samples the frozen street sun's 2048 map as
  well as the spot maps. Off: the faint diagonal window-mullion shadows on the office floors go, and
  so do the street buildings' sun shadows (11.5% of pixels at the lift, all small). GPU −0.3…0.6 ms.
- Rejected by the user from the comparison sheets: neither margin is worth its look on this machine.
  The route if either is revisited: `"roughness": 1` per corp `art/models.json` entry; for the sun,
  bake the street shadows into vertex colour and drop the caster.

Verdict: **rejected — look.**

## Corp per-texture meshes merged onto texture arrays (`CorpMerge`)

The open lead "walls cost 3 calls per box — a texture array would" (see `3d-render.md`), done for the
corp floor. Every emitter here merges its quads into one mesh PER TEXTURE (`FacilityGeom.add` and
`addFloor`, `CorpStreet.add`, `CorpFacade.add`), so a view drew ~10-13 wall meshes, 4-6 floors and
24 street meshes that differ in nothing but their map.

- **`render.corp.CorpMerge`** buckets every opaque, front-faced, plainly mapped lambert by program
  (the patch chain's cache key), castShadow, receiveShadow, vertexColors, colour attribute, colour
  and renderOrder. A parent at IDENTITY (the scene, any `Chunks` group) counts as one; the street
  group, 114 units down, keeps its own buckets so the gate still hides them. Each bucket of 2+
  becomes ONE mesh: the geometries concatenated (`mergeGeometries`) with a per-vertex `layer`, the
  first member's material re-used, and a `DataArrayTexture` (512², sRGB, repeat, mips) sampled where
  three samples `map`. The map stays bound, so USE_MAP, vMapUv and every mask patch are untouched,
  and only the diffuse read moves. The rest are freed.
- **Runs in `tick`**, once every candidate map has loaded (sizes are only known then) and
  `CorpStreet.settled()` (the street's casters are the meshes being replaced). Signs2 (1024²), the
  whiteboard (512x384) and the cable (256²) keep their own meshes. `CorpWarm` merges its demo plate
  with a 1x1 single-layer array: the program is the same and the full blank array cost the warm
  ~1.3 s (now 878 ms against ~700).
- **TRAP: the opaque sort.** A plate-wide merged mesh sorts BEHIND the street by bounding-sphere
  depth, so the street got fully shaded and then painted over: +0.6..0.9 ms GPU in the prototype.
  `CorpStyle.OUTSIDE_ORDER` 1 pins the street and the facade after the interior.
- **TRAP: Haxe hoists a method off a Dynamic receiver** when an arg is an array comprehension:
  `g.setAttribute('layer', new X([for ...]))` compiled to `let f = g.setAttribute; ... f(...)`, and
  three's method then ran with no `this`. Build the array first.
- The CPU copy of each array is dropped in `onUpdate`, once the GPU has it.

Live on slot 5: **55 meshes → 6** (street 15, shell 15, casting shell 11, floors 8, facade 3,
archive vertex-coloured 3). Separate sessions on the 3050 Ti laptop (no in-session toggle once the
originals are freed), merged vs unmerged: calls cubicle **81 → 55**, exec 70 → 52, lift
**106 → 70**, kitchen 92 → 61, archive 77 → 56; submit −0.1…0.2 ms; GPU −0.4…1.0 ms. Screenshots
pixel-identical at 4 of 5 spots; at the lift, 2 edge pixels at the end of one floor seam row (a depth
tie under the new draw order).

Verdict: **landed.**

## Corp facade ledges: capping on the glazing, shaft art folded on the lift

The 0.5-wide ledge `CorpFacade.build` caps at WALL_BASE, where a glazed cell's slab (GLASS_T)
stands half a unit inside the ring plane the drop hangs on. 96 quads on the probed plate.

- **On the glazing (87) it wore the curtain wall**, via `FacilityGeom.cap` at FACADE_TILE 4: a
  0.125-of-a-bay slice (64 px, cut through the middle of a window) laid flat on a sill with no
  window under it. No mapping fixes that, so it moved to the SOFFIT's buffer (`CorpStyle.CAP`,
  `corp/cap-alu`, the same capping as the plate's wall and window heads — prompted as the flat top
  of a curtain-wall head), at WALL_TILE. Same merged mesh, so no draw call and no new layer.
- **On the lift (9) it went into the shaft buffer at the FACADE tile**: lift-shaft at 4 against the
  shaft face's 12, and `cap`'s planar x/z put the run in v on the two z hands, rotated 90° to the
  face below. New `CorpFacade.ledge` folds the art over the edge: u = run coord / SHAFT_TILE as
  `face` maps it, v = (WALL_BASE + distance in from the outer plane) / SHAFT_TILE. Live: the dir-2
  ledge at x −91 reads u −2.000 at z −24 (the face's own u there), v −0.017 on the outer edge
  (the face's top) → 0.025 inside.
- **TRAP: `PolyProbe` reported every face of a `CorpMerge` mesh as its FIRST member's map** — it
  read `mat.map`, which the merge leaves bound to member 0. The lift ledges and shaft faces said
  `glass-dark`. The merge now keeps `userData.layerMaps` and the probe picks the face's `layer`.

Verdict: **landed** (layers and UVs read back live; look not yet signed off).

## Empty instanced batches leave the render list (`Models.cull`)

`Models.cull` capped `count` at the visible instance count but left the mesh `visible`, so a batch
with nothing in frame still went through three's full per-object setup — program, uniforms, VAO —
and was skipped only at the draw. It counts as **0 calls**, which is why no census ever showed it:
the facility had 32–57 such batches every frame (lab-report §A). One line now sets
`visible = count > 0` after the pack. It covers every caller at once: facility glbs and roof
clutter, lamps, doors, city lamp batches, wild props and `ObjModels` solid/ghost/hull.

- Shadows are unaffected: a `cull` batch only ever cast its camera subset, so an empty one cast
  nothing. `cullExact` keeps its own `keep` rule.
- Checked: nothing else in the game writes `visible` on a culled batch (the facility roof fade and
  `Occlusion` act on shell meshes), and the warm scenes never run `cull`, so no program is skipped.

Measured on the Radeon iGPU (ANGLE D3D11, canvas 1040x647) in one session, slot 6, interleaved old/new (old = the shipped `cull` plus
`visible = true`), 4 rounds × 40 frames, 60 fps gate: calls and tris identical at every spot.

| spot | submit old → new (mean ms) |
|---|---|
| parking | 3.67 → 2.06 |
| park | 4.67 → 3.33 |
| office110 | 4.51 → 3.70 |
| lab115 | 4.78 → 2.75 |

Verdict: **landed.**

## Hand-modelled facility, wild and scenario-a glbs back to Lambert (`roughness: 1`)

`models-src/facility/buildlib.py` bakes `Roughness 0.72, Metallic 0` into every glb it builds, and
`Models.toLambert` keeps MeshStandard for anything under roughness 1, so 54 props shipped on the PBR
path with nobody having asked for specular: 47 facility (indoor kit plus booth, barrier, park bench and
fence, lot cone and reel, roof clutter), the 4 wild trees and bushes, and scenario-a case/console/slot
(lab-report §G). All carry the same material, a dielectric with F0 ≈ 0.04, so all lose the same weak
lobe: nothing visible under the indoor lamps (office and lab pixel-identical), the faint blue moon glint
outdoors (park 6% darker).

- Fix at the manifest, not the lib: `"roughness": 1` on the 54 entries in `art/models.json`, rebaked by
  `make models`. Corp shares `buildlib.py` and keeps 0.72 (the walnut desk's lamp sheen, rejected
  before); the ship (0.80) keeps its sheen by choice; habitat is intentional.
- Live: the only MeshStandard instanced mesh left in the facility is the ship.

Measured on the Radeon (ANGLE D3D11, canvas 1040x647), slot 6, across a reload (so indicative): park
GPU median **7.29 → 4.74 ms**, office110 5.13 → 4.61 ms. The report's same-session A/B was −21…23% at
park.

Verdict: **landed.**

## Facility shafts, glow and roof clutter draw in one pass; shafts cull per instance; pickCell rect cached

Three transparent DoubleSide materials took three's two-pass path (back faces, then front), and
three sets `needsUpdate` before each side pass, so getParameters and the program key were rebuilt
twice per mesh per frame (~35–45 µs each, lab-report §E). `forceSinglePass` now goes on the light-cone
material (`LightCone.instanced`, every area), the facility glow (`FacilityGlow`) and the roof clutter
(`FacilityRoof.pack`). The cones and glow are additive, so order-free. The roof clutter is alpha-CUT
and writes depth, so one pass gives the same fragments.

- **The facility's two cone batches (masts, door lamps) drew every shaft from everywhere:**
  `frustumCulled = false`, because the mesh-wide sphere sits at the origin. `ConeSet` now carries
  per-shaft mid-points plus a bounding radius, and the new `LightCone.cull` packs the visible ones
  through `Models.cull`. That is for steady sets only; a `pulse()`d set would fight it over the
  packed prefix. `FacilityLamps.LampSet.cones` hands them to the tick.
- `View.pickCell` / `updateHoverTooltip` read `getBoundingClientRect()` every frame, forcing a style
  recalc over the HUD. The rect is now cached in `View.clientRect()` and dropped on resize and on canvas
  show/hide. Checked: a resize re-reads it once, then no reads for the next second.

Measured on the Radeon (canvas 1040x647), slot 6, interleaved old/new (old = two-pass on the 5
materials + full cone pack), 4×40 frames:

| spot | calls | tris | submit (mean ms) |
|---|---|---|---|
| office110 | 129 → 124 | 56.5k → 54.3k | 3.23 → 3.02 |
| park | 116 → 111 | 206k → 204k | 2.93 → 2.72 |
| parking | 58 → 53 | 21.4k → 19.2k | 1.67 → 1.52 |

Pixel diff old vs new: gate 0. Office110, park and overlookT: 0.001–0.005% of pixels, scattered over the
whole frame, against a control-vs-control noise of 0.002–0.06% (fireflies, HUD pulse). Splitting
two-pass from no-cull gave the same scatter for each. A wrongly culled shaft would be one faint
contiguous patch.

Verdict: **landed.**

## Facility spot shadows: only the masts take casting slots (`LampPost.noCast`)

The facility's 12-slot pool routed ceiling, corridor and door fixtures into the 8 casting slots the
same way it routed masts. Those lights throw no visible shadow: all 8 spot shadows at intensity 0
change 0.000–0.006% of pixels at every indoor spot. Meanwhile the one-transposition routing sort never
converges while the player moves, so a walk re-rendered 1.74–1.90 spot maps on 90–97% of frames
(lab-report §C).

- `LampPost` gets an optional `noCast`. `LampLights` ranks a noCast post after every casting one, so the
  casting slots go to the nearest masts. A noCast post that still lands in a casting slot (fewer lit
  masts than slots) has its shadow intensity held at 0 and its map never marked dirty. The fade edge
  ignores a noCast boundary lamp. `FacilityLamps` marks the ceilings, corridors and doors. City,
  sewer and wild never set it.
- **One casting slot was tried and rejected on look.** It is the Radeon's GPU lever (−12…15% at park;
  each slot is a PCF lookup in every lit fragment, and 2 slots cost almost what 8 do). But two masts at
  equal distance put the shadow-fade ramp at 0, and the pole streaks the masts throw into each other's
  pools go: gate 0.79% of pixels, 0.2% by >16 levels. Kept at 8.

Measured on the Radeon, slot 6:
- **Walk** (setPath (40,19) → S2 corridor, 48 cells): **0 spot-map renders** against the report's
  1.74–1.90 per frame on the same route.
- **Pixel diff** against the old routing: gate 0, office110/lab115 0.001–0.002%, park 0.006% (control
  noise 0.002–0.055%).

Verdict: **landed** (masts-only); **rejected — look** (1 casting slot).

## Facility moon snapped to a 4-cell grid and frozen; full caster set on render frames

`fitMoon` tracked the smoothed player exactly, and the moon's 2048 map re-rendered every frame:
7–22 calls, 2k–128k tris (lab-report §D). The box now moves in `FacilityStyle.MOON_SNAP` (4-cell) steps
(`FacilityArea.moonTick`), and `moon.shadow.autoUpdate` is off. The map renders again when the box
snaps, a glb batch lands (object-prop solids included), a roof eases (`ease` now reports it) or a door
leaf turns (`FacilityDoors.tick` split into `swing`, which reports movement, and `cull`).

- **The full caster set on render frames.** A frozen map drawn off the camera's subset keeps the hole
  (report: park 5.5% of pixels wrong viewed 4 cells off). `Models.cull` and `ObjModels.cull` take an
  optional `all` that skips the frustum test, and the facility passes it on any frame a moon or spot map
  renders. The main pass draws the off-screen instances that frame too, which is harmless. Masks still
  apply, so a faded roof's clutter stays out. Unlike corp's `cullExact`, this needs no sphere bake and
  keeps the masks and the doors.
- **TRAP: `area.visRev` is not a sightline-change signal.** `AreaGame.updateVisibility` bumps it on every
  player step. Used as a trigger, it re-rendered the map on 68 of 450 walk frames.
- An opened container's shut/open batch swap waits for the next snap to show in the map (`ponytail:`
  in `moonTick`).
- **TRAP for whoever reuses the report's harness:** `a4/setup.js`'s undo sets `moon.shadow.autoUpdate =
  true`. Every run after the first walk measured an unfrozen moon until that line was removed.

Measured on the Radeon, slot 6, god mode on (the walk dies otherwise):
- **Walk** (49 cells): moon calls **11.3 → 2.4 per frame**, max submit 7.2 ms (no render-frame spike).
- **Steady state:** shadow calls 10–17 → **0**. Interleaved against `autoUpdate = true`: office110
  124 → 110 calls, submit −0.21 ms; parking 52 → 42, −0.17 ms; park 111 → 94 calls and 204k → 138k tris,
  submit +0.12 ms (within park's run-to-run spread).
- **Frozen vs a forced fresh render:** at 6 spots after arrival, and at two walk ends after up to 2
  cells inside a snap, every diff is at or under control noise (max 0.021% vs noise 0.042%).

Verdict: **landed.**

## First-visit hitches: prime render of the fresh build, warm draws everything, maps upload on load

A fresh-reload tour of 14 facility spots (lab-report §H harness) still spiked on first visits after the
perf work above:

| spot | before | after | what it was |
|---|---|---|---|
| hangar | 378 ms | 4 | rig cable program, 340 ms (never in the warm scene: it needs the real area's ship) |
| office110 | 124 | 84 | the instanced decal program (left), plus clutter-sheet uploads |
| washroom102 | 71 | 5 | stall panel's first draw, no new program (ANGLE links lazily), plus 10 uploads |
| gate | 50 | 4 | lit window band program |
| parking | 56 | 56 | UI path-line dot first draw (left) |
| park | 43 | 56 | firefly program (left) |

Three changes:
- **`View.prime`.** Right after `buildFrom` builds the area, before any tick has culled a batch or a
  chunk, it renders the composer once with `frustumCulled` off on everything and
  `shadowMap.autoUpdate` off, behind the load cover. Every material the real build holds compiles
  and links there. Shadows sit the frame out because a frozen moon map would otherwise bake casters the
  culls are about to drop.
- **`Warmup.compile`'s trailing render draws everything**, for the same lazy-link reason.
- **`Textures.loadTexture` uploads on image load** (`renderer.initTexture`, with `Textures.renderer`
  set in `View.ensureCore`). Every call makes a NEW Texture, so no warm upload ever served the real
  build. Tour uploads went from 71 calls / 146 ms to 51 / 35 ms.

Left: the instanced decal program (office110, patched per area on first paint), the firefly program
(park), the UI path-line dot and the sprite pool's first draw. Tour run-to-run spread is wide
(office110 94–152 ms on unchanged code), so read single spikes loosely.

Verdict: **landed** (hangar, washroom and gate hitches gone; decal and firefly open).

## Facility per-texture meshes merged (`CorpMerge`) and range-culled inside the merge (`RangeCull`)

61 of the facility's 87 non-instanced meshes were compound-wide merges (radius 50–176). `Chunks` skips
anything over 64, so they drew from everywhere, and the generous spheres were where most of the
zero-pixel draws came from (lab-report §B). Chunking them was measured worse (office110T 153 → 298
calls). What landed:

- **`CorpMerge.merge` on the facility** (`FacilityArea.merge`, retried each tick until every map has
  loaded): 44 meshes → 4 (walls/casework/signage/ground, floors, casters, non-fading decks). Roof
  members are held back with the new `userData.noMerge` (checked in `CorpMerge.fits`), because they
  fade and hide per structure. `FacilityWarm` runs `CorpMerge.merge(sc, true)` so the `|layers`
  programs are warm.
- **`render.RangeCull`**: each merged mesh's index is re-sorted IN PLACE by 8-cell block
  (`FacilityStyle.RANGE_BLOCK`), keeping each block's index span and world box. Per frame it draws from
  the first block in frame to the last, or leaves the list when none is. A **casting** mesh's
  `onBeforeShadow`/`onAfterShadow` put the full range back for every shadow pass. On a shadow-render
  frame (`all`) an empty caster stays listed. Calls can only go down and sort order is untouched.
- Skipped from the prototype: the roof-on gate. It is not pixel-clean, and with a clean margin it is
  worth 0…−4 calls.

Measured on the Radeon (canvas 1040x647), slot 6:
- **Calls**, merged against the phase-5 state (cross-reload; calls are deterministic): office110 110 → 84,
  park 94 → 76, parking 42 → 37.
- **Range cull against merge-only**, interleaved: same calls, tris −9…−16k, **GPU −0.4…−0.9 ms**
  (office110 5.04 → 4.58, parking 4.17 → 3.30, hangar 6.67 → 5.75), submit 0…−0.24 ms.
- **Pixel diff** range against no-range: 0–0.007% (control 0–0.19%). The moon map re-rendered with and
  without the range cull is the same within noise at park/office110/gate/overlookT.

**Whole stack** (§A–§H, this session's entries; Radeon, cross-session against the phase-1 "old" arm):
submit office110 4.51 → 2.28 ms, park 4.67 → 2.09, parking 3.67 → 1.20; calls 129 → 84, 116 → 76,
58 → 37; steady-state shadow calls 7–17 → 0; park GPU 7.3 → 4.7 ms.

Verdict: **landed.**

## The corp stairs: a two-cell switchback glb and a floor HOLE (`FacilityModel.FIT_HOLE`)

> SUPERSEDED by "The corp stairs as a 2x2 U-stairwell, cut away"

The stairs were a flat ground-decal sprite (frame 9). Now a hand-modelled glb
(`models-src/corp/stairs_build.py`, **924 tris**, `check` holes 0 / coplanar 0 / islands 1 /
texel_off 0) over TWO cells: a 7-riser flight UP on the stairs cell (3.4 of 4.0 wide, run on to 3.6
into the strip before the end window, ~30°) and a 6-riser flight DOWN into a well on the sealed cell
to its right (`gen.corp.CorpTemp.stairsTwin`, `TILE_FLOOR_CARPET + 16`). Art is one packed gen,
`corp/stairs-pack` → tread (carpet + alu nosing band), riser, well concrete, rail stainless.

- **The hole is ONE floor cap.** `CorpModel.fitOf` answers the twin with `FacilityModel.FIT_HOLE`
  (99) and `FacilityGeom` skips that cell's own cap only; the strips the neighbouring walls hand the
  cell keep their floor, so the hole is exactly the cell and independent of wall thickness.
- **Everything under the floor is built OVERSIZE** (well walls 0.4 thick, the down flight starting
  0.4 under the front neighbour, running 1.0 under the back strip): the neighbours' floors hide it,
  so the hole stays closed whichever way the placement lands, and no wall-thickness case has to fit.
- **Trap: the WALL yaw's `wall()` correction.** The stairs always face the end WINDOW, so
  `CorpArea.objWall` shifts the prop by `(GLASS_T − WALL_INNER)/2` = −0.1; `CorpStyle.STAIRS_WALL`
  takes it back out in the row's `off`, with the bbox centre (2.3025, 0.4) and `sink` 2.8 / 7.8784.
- **Trap: the post/bar flank gap.** An 0.08 post under a 0.1 bar leaves 0.01 per side — exactly
  `check`'s threshold, 12 coplanar pairs. Post 0.06.
- Ghost fade on the stairs cell keeps the well dark (no void through the hole); no `noGhost`.

Seen in game at zoom 0 and 0.6: up flight, rails, nosings and the well read; no gap at the hole's
edges. Calls not measured: one more instanced batch on a corp floor.

Verdict: **landed.**

## The corp stairs as a 2x2 U-stairwell, cut away

Reported on the two-cell model: the down flight ended on a WALL, the corridor cell in front of the
well covered its lower half, and the window cell's floor strip (1.5 wide, laid by `floorStrips` off
the twin's own floor) hung in mid-air over the well's back. Now a real U-stair over FOUR cells
(`models-src/corp/stairs_build.py`, **1,828 tris**, `check` 0 / 0 / 1 / 0): both flights start at
the corridor edge and run to the window, 6 treads at 0.45 × 1.0 then a landing at ±3.15 that spans
BOTH lanes; off the down landing the next flight down doubles back UNDER the up flight, off the up
landing the next flight up doubles back OVER the down flight and is cut after 3 steps (a section, or
it roofs the down flight over). Sealed cells: `gen.corp.CorpTemp.stairsCells` (twin, the cell toward
the corridor, its twin); the stairs cell stays walkable and floored, under the up flight's body.

- **The well stops ON the cell edges now.** The old oversize ran the well 1.4 under the window strip,
  which is exactly what hung. With the walls on the edges every wall cell's strip is a LEDGE round the
  well instead, so `FacilityGeom` needed no change: no strip skipping.
- **Trap: a FINAL id written before finalize is read as a ROOM ID.** Sealing the well before the
  doors (so no room opens onto it) with `TILE_FLOOR_CARPET + 16` = 215 broke 86 seeds — room ids
  are stamped from 100 up, so doors named "room 215" and later passes reopened the well. A temp id
  of its own, `CorpTemp.BLDG_WELL` (47, mapped in `finalTiles`), and `doorSpots` refusing any spot
  touching it: 3000 seeds clean, with a new oracle check that no door spawn touches a well cell.
- **The game camera's yaw is fixed** (`CameraRig` orbits ±`orbitYawMax` only), so a floor is seen
  from the corridor, from the window side or from either flank; checked all four with the free cam.
  From the corridor the down landing sits under the stub, visible but unlit at −3.15.
- **All four cells are sealed and the object stands OFF the wall**, on the corridor-side cell of
  the up lane, used from any of its eight neighbours (`Stairs.canActivateNear`; the AI's leave-area
  command targets those neighbours too). With no wall beside it the WALL yaw finds the end wall
  ACROSS the well instead (`CorpArea.objYaw`: a hole cell whose right-hand twin is a hole too, then
  the wall — the twin test is what tells the end window from the side wall past the twin), and
  `objWall`'s glass correction is 0, so `STAIRS_WALL` is gone. `CorpStyle.STAIRS_*`: h 11.2261,
  sink 6.6 / h, bbox centre (2.0, 2.54) off the object's cell.
- **Trap: a flat face takes u on its LONGEST edge** (`buildlib.frame`). The up landing's tread was
  3.46 wide by 3.64 deep and wore its art 90° against the landing beside it; it now spans the body's
  full 3.76.
- **Trap: the window's glass is INSET behind its slab face.** The up landing ran to 3.6, 0.1 into
  the slab, and showed through the pane: it stops at 3.48 now.
- **No corridor lamp over the well** (`CorpLamps.corridors` skips `FIT_HOLE`): a panel hung over the
  flights.
- **Trap: a tread label mapped WHOLE is a density per tread.** On a 3.46 × 1.04 tread the art ran
  143 × 477 px/unit (grain stretched 3.3:1) beside the stringer's tiled 243 × 243, and a 3.5-deep
  landing wore a 0.74-deep nosing. Split: the label's carpet square TILES like every other face
  (~186 px/unit, laid before `grid_cut`) and its ribbed band is a 0.14 nosing STRIP of its own,
  mapped whole — the ribs run along u, so its length stretch is invisible.
- **Trap: a tread is not flush unless it is flush on THREE sides.** The slabs ran 0.27 short of the
  up body's flank (half-width 1.7 on a body to −2.0) and their nosing 0.04 proud of the riser, and
  at 0.06 thick they read as a second step laid on the first. Now 0.02 thick, flush over the riser,
  and the body's own span plus 0.012 at each end — not 0: a slab end exactly on the body's STEPPED
  flank is a non-convex face, and `check`'s separating-axis overlap test reported 40 false pairs
  there. Each landing is one slab over both lanes, the carpet tiling so its shape turns nothing.
  2,376 tris, `check` 0 / 0 / 1 / 0.
- **The well's DARKNESS is COLOR_0**, baked by depth in the build (1 at the floor, (1 − z/−4.5)² to
  0 at −4.5, falling fastest at the top: a smoothstep to −5.5 left the first metre of the well lit): the bottom of the next flight down reads as black and not as a wall, for no draw call
  and no texture (three's `USE_COLOR`, carried by `Models.toLambert`). Blender's exporter only
  writes a colour attribute a material reads, so the script passes `export_vertex_color="ACTIVE"`;
  `make models` keeps it (no `ao` on this entry to overwrite it).

Verdict: **landed.** Calls not measured (still one instanced batch).


## Lamp families weighted by how much of the texel is lamp (`PropGlow` lamps)

Reported: the facility spaceship flickers, "showing yellow glowies", when the camera moves back, and
so does the study console.

- **Cause.** `PropGlow`'s lamp term matches the emissive MARKER map by normalised hue and then added
  the family's full HDR colour (`color * glow * base`) to any texel whose max channel passed the 0.004
  NaN gate. Value was thrown away by design so a `--modulate`d marker still matched. But mipmapping
  makes value carry COVERAGE: a minified map averages each lamp into the black texels and gutter
  round it, the hue survives the average, and a texel that is a tenth lamp lit as a whole lamp.
  The lit area therefore grows with distance, and trilinear blending between two mip levels flips
  texels in and out as the camera moves. The flicker was those texels changing.
- **Measured off the shipped maps** (2x2 box mip chain, the family's own tol). Every lit mip-0 texel
  is the flat marker value (ship 224, console 240). Share of matched texels at value ≤ 0.5:
  - ship amber: 0% at mip 0, 18% at mip 2, 27% at mip 3, 42% at mip 4, 62% at mip 5.
  - ship cyan: the same shape.
  - console violet: 33-59% across mips 2-4.
  - matched share of the ship texture: 3.7% at mip 0 → 5.8% at mip 4 → 12.9% at mip 6.
- **Fix.** One line in the shader: `lw *= min(lmx / 0.85, 1.0)`. A fully covered texel still lights
  at 100% because both markers are over 0.85, and a blended texel lights in proportion to its
  coverage, so the emitted energy matches the lamp's true area at every mip. No uniform, no change to
  the program cache key, no draw call.
- **Measured live**, pinned free-cam over the ship (rig offset (0, 40.16, 16), and 2.5x that for
  "pulled back"). Yellow-speck pixels on the hull, entrance excluded:
  - before: near 5.0 and far 35.5 per 10k px (7x denser at range).
  - after: near 1.4 and far 5.2.
  - At range the entrance went from a blob back to its slotted shape. Near-pose bloom on the entrance
    is unchanged to the eye, and the console readout is unchanged at both poses.
- **Trap.** The `art/models.json` console note and this shader's own comment called the term "flat
  over every matched texel" as if that were a property of the art. It holds only at mip 0. Any rule
  about how a marker map lights has to hold at the mip the camera actually samples.

Verdict: **bug, fixed.**

## The scenario console and slots lost their lamps to the Lambert switch (`PropGlow.patch` guard)

Reported right after the coverage weighting above as "you killed purple glow on the terminals". It was
not that commit.

- **Cause.** af943d92 (2026-10-02) put the scenario console, case and slot on `"roughness": 1`, so
  `Models.toLambert` swaps their materials for `MeshLambertMaterial`. `PropGlow.patch` returned early
  on anything that is not `isMeshStandardMaterial`, so the lamp families stopped on both props.
  Nothing reported it: no error, no warning, just a flat violet marker at emissiveStrength 0.35 where
  the haloing, breathing screen and sockets had been. That entry's "indoors nothing" was measured on
  specular alone. Live, the console and slot materials carried no `propLampFull` uniform; the ship,
  still Standard at roughness 0.80, did.
- **Fix.** The guard accepts Lambert too. Lambert's fragment shader has `<emissivemap_fragment>`,
  `totalEmissiveRadiance`, `diffuseColor` and `normal`, which is everything the patch reads, so it
  compiles unchanged. Every shine and eyes row is a habitat prop, and those stay Standard, so no other
  prop changes. Facility warm went from 107 to 108 programs, so the new program is warm before area
  entry.
- **And the coverage floor became per family** (`PropLamp.full`, uniform `propLampFull`). The console
  map ships at 512, and its glyph strokes are 1-2 texels: 38% of its matched texels are partial at
  mip 0. Glow energy kept at 0.85 is 72% at mip 0, 59% at mip 1, 57% at mip 2 and 50% at mip 3. Its
  peak was tuned to 1.31 against `BLOOM_THRESHOLD` 0.9, so it would never cross. The ship's two
  families set `full: 0.85` (its marker is flat 224, so it keeps 100% at mip 0 and 86% at mip 2). The
  console and slots omit it, which means hue-only as before. Their bleed stays inside the readout
  rather than landing on a hull.
- **Trap.** The A/B in the entry above showed the console "unchanged" because the lamp term was not
  running on it in either leg. An unchanged prop in an A/B is a reason to check that the patch is on
  the material (`renderer.properties.get(mat).uniforms`), not a pass.

Verdict: **bug, fixed.** Console screen and slot sockets halo and breathe again, seen at a pinned close-up.

## The hangar's cable fan only runs from machines, nearest first (`FacilityHangar.fan`)

Reported: cables running from the ship to waste bins and drums, while machinery on both sides of the
pad had none.

- **Cause.** `fan` ran a lead from every cell of the shed with `deco != 0`, scanning row by row and
  stopping at `CABLE_RUN_MAX` 8. `deco` holds every fitting kind, including the bins and drums
  `HangarBlock.slot` places on spare floor. So the top rows (drums, bins and a corner rack) used up
  the 8 runs before the scan reached the west and east machine banks.
- **Fix.** Candidates are now only `FIT_RACK`, `FIT_RACK_LOW`, `FIT_MACHINE`, `FIT_MACHINE_LOW` and
  `FIT_ANALYSER`, sorted by distance to the podium and capped as before. The four carved banks are
  8 cells, so they take the whole cap ahead of the corner racks. Same mesh, so no change in draw
  calls.
- Seen live at a pinned top-down view of the Dogwood Heights hangar: all four banks wired, no lead to
  any bin or drum.

Verdict: **bug, fixed.**

## Hangar power generators, and MESSY cable bundles from the corner racks (`FIT_GENERATOR`, `StripOpts.mess`)

Asked for: a power generator glb, two or three of them in the shed, with the corner machines cabled
to them by messy runs as a new cable setting.

- **The prop.** `models-src/facility/generator_build.py`, hand-modelled like the rest of the shed's
  machines (rack, machine cube, analyser, podium). A skid, an olive drab enclosure, intake louvres
  on the long sides, a radiator grille on the -x end, a control box on the +x end, and a muffler,
  exhaust stack and filler cap on the roof. It lies DOWN where the others stand up, and the roof
  furniture carries its silhouette.
  - 1,024 tris, 3.04 x 1.58 x 2.36. `check`: holes 0, coplanar 0, islands 1.
  - Wears its own pack4 sheet (`facility/generator-pack4.png`, one 1k gen, $0.056): panel, louvre,
    control, skid.
  - Lifts fitted to the analyser in the same shed: built sRGB 50-62 against its 48-60. propstat on
    the built glb: sampled 61/64/51 against the analyser's 59/65/59, chroma 13.6 against 5.7.
  - One density for the whole model (`scale` = the skid's length). The control face is the
    exception: it maps its cell whole because the cell is a composition.
- **Placement.** `gen.blocks.HangarBlock.generators` carves 2-3 on the OPEN FLOOR, each inset two
  cells off a corner. Corners holding a rack bay go first, then the rest in a rolled order.
  - A generator needs bare neighbours all round and one clear cell between it and the pad (so the
    pad's walkable ring survives), the machine banks and other generators.
  - The carve has to read the pad and bank NODES by rect: none of them is filled yet at carve time,
    so the grid still shows concrete where they will stand.
  - The first cut used a 2-cell pad margin. The corner insets sit exactly 2 off the pad, so that
    margin rejected them: **1.34 per shed. At 1 it is 2.49**. All 3000 seeds pass, reachability
    included.
  - Frame key 18/3, `blocks: ['hangar']`, which is no room role: nothing rolls it and
    `GenCheck.decoBlocks` makes no claim on it.
- **The cables.** `FacilityHangar.power` throws a bundle of 2-3 strands from every rack unit in the
  shed to the nearest generator. The bundles go into the fan's borrowed buffer, so 0 draw calls.
  - Each strand rolls its own splay at both ends (±0.35), bow size and side, and kink.
  - Each strand lies 0.012 above the one before, because a messy bundle crosses itself and two
    ribbons in one plane z-fight.
  - `StripOpts.mess` is world units of extra wander: two harmonics at seeded frequencies
    (5-9 and 11-17 half-waves) on a sqrt taper, so the tangle reaches almost to the plugs, at
    `CABLE_MESS_STEPS` 4x the segments so a kink is a curve and not a corner.
- **Saves.** New compounds only, the user's call: a hangar generated before this has no
  generators, and its racks stay unplugged.

Verdict: **landed.** Seen live on a regenerated Dogwood Heights hangar: two gensets off the racked
corners, each taking an L of racks' bundles across the floor.

## Facility glb fittings stop casting a fake shadow of their unused atlas icon (`LampShadows`)

Reported by pick next to the new generator ("sprite pool 5, canvas 51x58") and next to an analyser
("sprite pool 1, canvas 72x73"), as a fake shadow coming off a 3D object.

- **Cause.** `LampShadows.castShadows` runs `actorShadow` on every non-decal object. That function
  blurs the object's ATLAS cell into a black silhouette (`Sprites.shadowContent`) and
  `CastShadows.project` lays it on the floor at the object's pose. The corp fix ("dark round
  shadows of nothing") excluded `CorpDeco.draws` objects, and nothing excluded the facility's
  equivalent, `FacilityDeco.draws`. So every fitting Const.FACILITY_DECO lists cast a shadow of an
  icon nothing draws. Row 18/3 is a stale 2D-era row, so the generator cast the outline of whatever
  old art sits in that cell.
- **Measured.** The canvases are the icon's alpha box plus `shadowSoftPx * 2` (6) px of padding on
  each side, against `app/img/entities64.png`, the atlas the game actually loads (the 512-wide copy
  under assets/ is stale and has those cells empty): 18/3 content 39x46 → 51x58, 8/5 content
  60x61 → 72x73, both exact.
- **Fix.** `!FacilityDeco.draws(area, o)` in the caster condition. `floor_drain` and office-desk
  bench decorations also answer `draws`, and both were already excluded (ground decal / spriteScale
  under 1), so they don't change.
- **What remains under a fitting:** the `ContactMask.prop` floor pool (and the wall halo where there is
  a wall). The glb batches themselves are `castShadow = false` by design (`FacilityDeco.fittings`:
  a casting instanced batch is a second draw call in the shadow pass), so a free-standing fitting
  like the generator now has a contact pool and no cast shadow.

Verdict: **bug, fixed.** Live: 0 visible sprite-pool quads within a cell of the 8 facility fittings in
the regenerated Dogwood Heights compound.

## Desk L corner: the overhang is asked of the RECT, not of the cell (`FacilityTables.lipped`)

Reported by pick on four edge-band faces of office 113's L desk (desk-top.png, v 0.35..0.4, u spans
of 0.28 and 0.32 of a tile) as "the L corner does not blend with the tables".

- **Cause.** `build` grew each slab by `BENCH_LIP` on a side only when the NEIGHBOUR CELL was not a
  table. An L corner is two rects, the leg and the stub, and each one's open front faces a bench
  cell, namely the other arm. So the leg's front and the stub's side took no lip, while the next
  cell of each arm, with bare floor in front, did. Both arms came out with a `BENCH_LIP` jog at the
  corner cell, and the slivers the user picked are the edge band's `exposed` spans filling it.
- **Fix.** `lipped(m, cell, si, col, row, dir)`: a side grows when `exposed` returns any span on
  it, except the side a door leaf swings past (`facesDoor`, unchanged). A full lab bench next to
  another full cell is fully met, so nothing grows there, the same as before. At the L, the leg's
  grown front overlaps the stub by `BENCH_LIP`, the same coplanar overlap the concave-corner note
  in `build` already accepts. The stub's in-cell face toward the leg is now fully met, so it stops
  growing into the leg as well.
- **Measured.** Seed 616109408, office 113, before/after crop at 4x: both arm fronts are one
  straight line through the corner cell. Same buffers and quad count, so +0 calls and +0 programs.
  Lab benches checked live in lab 108: unchanged.

Verdict: **bug, fixed.**

## Corp washroom vanity as a glb per basin cell (`corp/vanity`, `CorpProps.basins`)

Reported as "toilet lacks sinks". Two faults, one of them in the generator.

- **Generator.** `CorpRooms.toilet` centred the basin run blind and skipped the cell under a doorway,
  so a door in the middle of the basin wall split a three-basin run into two LONE fixtures.
  `CorpFurniture.washroom` tells a basin from a WC cubicle by contiguity alone, so both came out as
  cubicles: area 6475 room 106, four stalls and no sink. The run now slides to the most central span
  with no cell at a doorway (`clearSpan`, every hand via `atDoor`), two cells minimum, swapping walls
  with the stalls when its own wall cannot fit two. `GenCheck.corpWashroomSane` asserts it: **20
  failures in 3000 corp seeds before, 0 after.**
- **Render.** Even an intact run was a closed slab of vanity-top over counter-front, with no bowl and
  no tap. The `CORP_TAP` decoration the generator lays on it has no renderer outside the kitchen.
  It is now `models-src/corp/vanity_build.py`, kitchen_build's sink counter cloned at `VANITY_H`
  1.7: **896 tris, 4.0 x 1.32 x 2.43**, a glazed bowl, a gooseneck tap and wood doors. `check` reads
  0/0/1/0. Each cell stands one against the run's wall with `stalls`' slab offset, a run butts
  into one worktop, and `FacilityDetail.ground` runs once per run. The mirror stays emitted.
- **Sheet** `vanity-sheet.png` is pasted from art the tower already owns: counter-front's middle
  door panel (between its grooves, so a door does not repeat the slab's painted ones), vanity-top,
  the kitchen counter's steel and dark, and the corp WC's glaze. No `baseColor`/`lift`.
- **Measured.** Area 6475 washroom at 16,45, same follow pose: **69 → 70 dc, 123.7k → 126.4k tris**.
  That is the one new batch. The emitted slab's two labels stay drawn by others, so nothing came back.

Verdict: **landed.**
