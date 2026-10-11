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

## Corp washroom mirror hung off the WALL cell's slab, not the basin cell's

Reported by a pick at local z -20.06 as "mirror hangs in the air in front of the washroom".

- **Cause.** `CorpFurniture.washroom` took `FacilityGeom.plane(slab(m, col, row), dir, ...)`, which is
  the BASIN cell's own slab. A room cell carries no inset, so its plane is the cell boundary
  (-20.0, then MIRROR_EPS past it). A corp wall slab sits INSIDE its cell, so its room face is
  inset by `(CELL - thick) / 2`, and the mirror floated that far off the masonry. The comment above
  the loop already said "on the slab's face, not the cell boundary"; the call did the opposite.
- **Fix.** `plane(slab(m, wall cell), dir ^ 1, MIRROR_EPS)`: the wall slab's room side.
- **Measured.** Area 6475 washroom at 16,45, close render: the mirror band is flat on the tiles and the
  vanity taps stand in front of it. Same quads in the same buffer, so +0 calls.

Verdict: **bug, fixed.**

## Corp mirror lifted to a grey: `corp/mirror` lift 1.187 → 0.72

Reported as "make it gray, not so dark". The band was built at **54.8 srgb**, a black sheet against
wall-washroom at 105.9. It is a gamma `lift` alone, since the art is neutral and only its value was
wrong. 0.774 measured 92.7 (glass band 87.3), and **0.72 gives 99.5 / linear 0.1305**: one step under the
wall, so the glass still reads as its own plane. The stainless edges lift with it. There is still
no reflection: no cube, no planar pass, and the mirror is not on PropEnv.

Verdict: **landed.**

## Corp WC cubicle: a plain grey panel, half as thick (`corp/stall-panel`, `STALL_T` 0.3 → 0.15)

> SUPERSEDED by Corp WC cubicle: the panel art on the broad faces, plain laminate on the lid and ends

Reported off a pick on a panel's top as "should just be gray", plus "make the stall walls 50% thinner".

- **Cause.** The label was the whole laminate quadrant of `wet-pack`, which is an authored panel with
  a stainless rail along its top and a shadow-gap seam down its centre. `CorpFurniture.panel` maps
  that one texture onto all five faces of a thin box at `PARTITION_TILE`, so every edge strip and
  every top carried slices of rail and seam.
- **First fix, and its trap.** Cropping a plain 240² patch of the left panel kills the rail and the
  seam, but **a window cut out of a tileable sheet does not tile on its own**. The quadrant carries a
  baked top-to-bottom gradient of **4.4 counts over any 240 rows**. The best of every window
  scanned was still 4.40 top to bottom, and the 2.8 wrap drew a band across every panel.
- **Fix.** A DERIVED source, `textures-src/corp/stall-panel.png`: that crop, with each row's and
  each column's luma drift subtracted. Opposite edges now match within **0.02**, the grain stays
  (std 1.55), and the recipe is in the manifest note. `lift` 1.1 → **93.2 srgb**, under the wall's
  106 so a back panel does not melt into the masonry it stands on.
- `STALL_T` 0.15. Every panel is emitted ±T/2 about its line, so nothing else moves.

Verdict: **landed.**

## Corp WC cubicle: the panel art on the broad faces, plain laminate on the lid and ends

The entry above misread the report. The pick was on a panel's LID, and "should just be gray" meant
the lid, not the panel. The broad faces were fine.

- **Fix.** `corp/stall-panel` is back to the whole wet-pack quadrant (74.4 srgb). The detrended plain
  patch is a label of its own, **`corp/stall-edge`**, at the panel's lift 1.324 (75.2 srgb), so it
  reads as the same laminate. `CorpFurniture.panel` puts STALL_PANEL on the two broad faces
  (whichever axis the rect is longer on) and STALL_EDGE on the two narrow ends and the lid: one
  texture per face. That is +1 shell buffer. `STALL_T` 0.15 stays.
- **Trap.** `tools/textures.py`'s staleness test covers lift, sat, cells, glass and regrid, but **not
  `crop`**. Reverting a label's crop left the derived art in `app/` while the build said nothing.
  Delete the built png to force it.

Verdict: **landed.**

## Corp washroom floor: a grout line across the wrap (`corp/floor-washroom`)

Reported off a pick in the washroom as "floor texture is not fully seamless".

- **Cause.** The 1024 solo source draws its 5 px grout at 337..341 and 682..686, three tiles a repeat,
  and **nothing at 0/1024**. Every repeat therefore laid one double-width tile. On screen the lines
  ran 240 / 123 / 240 / 122 px apart where they should be even.
- **Fix.** Cols and rows 1022..2 are a copy of the 337..341 line, so the crossings come along with
  it. They are painted over the pristine drop, parked in `textures-src/corp/Unused/`, and the
  manifest note records it. The built mean is unchanged (93.8 → 94.0).
- **Measured.** A top-down render of the area 6475 washroom shows every grout line evenly spaced.

Verdict: **bug, fixed.**

## Wilderness hollows darken by depth (`WildHeight.shade`)

Asked for as "darken the lower parts of the ground for a better 3D look, like the corp stairs". The
stairwell bakes depth into `COLOR_0`. The wilderness ground already had a vertex-colour channel (the
sine mottle), so the same idea went onto it at no cost in draw calls or materials.

- **What.** `WildHeight.shade(x, z)` normalises the height by the field's own peak
  (`1.9 * reliefAmp`, so every band shades over the same fraction of its range) and falls
  quadratically from the crest to `1 - SHADE_DEPTH` at the trough. It is then **divided by its own
  mid-height value**, so the frame's mean level holds and only the contrast moves.
- **Every drape takes it.** The ground multiplies it into its mottle. Patches, verge, asphalt, road
  paint and grass tufts each got a `color` attribute plus `vertexColors`, so no layer sits bright
  over a dark hollow. The grass material is shared with `FacilityLawn`, which writes no colour
  attribute (a missing one reads black), so only `WildGrass.build` turns `vertexColors` on. That is
  a settable field on the `MeshLambertMaterial` extern now.
- **First cut too weak.** The shade ran only across the bottom 60% of the range at depth 0.45, which
  moved a forest frame (reliefAmp 0.73) by about 2 luma at most and was invisible. The second cut
  runs the full range at 0.6 and normalises at mid-height.
- **Measured.** Same save and pose, column means across the frame (sRGB luma):

  | | Range | Frame mean |
  |---|---|---|
  | Flat (shade off) | 10.0–15.0 | 12.7 |
  | Shade at 0.6 | 9.4–16.7 | 13.0 |

  The hollow left of the player and the crest at centre now read as landform.

Verdict: **landed. +0 calls.**

## Wilderness props are hand-modelled: every TRELLIS glb out here but the bramble

Asked for as: remove the TRELLIS guard rail and make a Blender one, use the facility's hand trees and
bushes in the wilderness too, and redo the rocks, logs and dead trees in Blender.

- **What.** The scatter now draws the park's own hand planting: the conifer (824 tris), the in-leaf
  broadleaf (800) and both shrubs. The shrub tile deals dome and upright off a band list, as
  `BUSH_DOME` and a new `BUSH_UPRIGHT` row appended at index 14. Eight more were built in
  `models-src/wild`:

  | Build script | Models | Tris (old TRELLIS) |
  |---|---|---|
  | `guard_rail_build.py` | W-beam on two posts, amber reflector caps | 384 (4,782) |
  | `deadwood_build.py` | snag / bare broadleaf (both wind-twisted, crooked, unlike limbs) / log | 400 / 588 / 116 (4,784 / 4,934 / 3,112) |
  | `rock_build.py` | boulder / cluster / outcrop / 2x2 | 170 / 490 / 488 / 728 (1,548 / 4,736 / 4,981 / 10,000) |

  Each was sized to the aspect of the glb it replaced, within 0.07 (the bare broadleaf, 0.91 against
  0.84, is the loosest), so no `h` or `r` in `WildStyle.PROPS` moved. The eleven old glbs went to
  `models-src/wild/Unused/`, and `FacilityStyle.PLANT_BLENDER` went with its dead branch. Two
  `sink` fields went too, because nothing is buried any more.
- **Art.** Two pack4 gens:
  - `rock-sheet.png`: granite, lichen, dead bark, deadwood.
  - `rail-sheet.png`: galvanised beam, post steel, grime, amber reflector.

  Both went through `sheet_build.py`, which now takes a sheet name and a LUMA target. A luma target
  is levelled by a flat scalar, so the hue holds. The rocks and the rail tile in-cell
  (`grid_cut` + `tile_uv`, TILE 2.0). The wood bookmatches its bark up the limb, at the same ~127
  texels a unit.
- **Measured.** Same forest save and pose:
  - Frame triangles went **787k → 161.5k**.
  - Calls went 66 → 68 (one more shrub batch).
  - No console errors.
  - `buildlib.check` read 0 holes / 0 coplanar / 1 island / `texel_off` 0 on all eight.
- **Trap.** A vertex set taken before `bmesh.ops.bisect_plane` is not a stable fence. Chipping blob
  N of a multi-blob rock cut into the earlier blobs too, and `check` read 26 coplanar pairs at gap 0
  on the cluster: slivers of old blobs lying on the new cut. The fix is to build each blob in its own
  bmesh and append it with `from_mesh`.

Verdict: **landed. -80% frame triangles on a forest frame; +2 calls.**

## Sewer / habitat exit ladder is hand-modelled, against a N/W/E room wall

Reported as: the sewer exit is fully white now.

- **Cause.** The TRELLIS exit (`models-src/sewer/exit.glb`, Aug 12) baked a FLAT base colour: grey 198, sd 1, nothing in it. Its MR map was 0.7 metal. It read dark only while props drew PBR, because a metal puts its colour into a reflection there was no env map for. `Models.toLambert` (Aug 31) drops metalness for any entry without `roughness` < 1, so the bare 198 drew near-white under the shaft lamp.
- **What.** `models-src/sewer/ladder_build.py` builds the replacement on the `buildlib` route:
  - two 8-sided smooth rails 1.1 apart and 7 rungs at a 0.5 pitch;
  - two bracket pairs, bars buried into wall plates, both under `WALL_H` 3.0;
  - rails running on to `h` 4.0, so the ladder climbs past the ledge.
  It is **528 tris** (5,000), 1.28 x 0.395 x 4.0 at world size. `check` reads 0 holes / 0 coplanar / 1 island, `texel_off` 0, worst 1.04. `art/models.json` keeps the `sewer/exit` key, so no path, row or warm entry moved.
- **Art.** Its own pack4, `ladder-sheet.png`: rail iron, hand-worn rung iron, bracket scale, and grimed rail under z 1.0. It went through `sheet_build.py` onto luma 46 / 56 / 44 / 40 against the sewer family's measured 41-48. The rung sits a step brighter on purpose, so the rungs are what read. The built glb measures luma ~47 at chroma 27, with no `baseColor`, and `roughness` 1 keeps it on Lambert.
- **Placement.** Exits used to sit at room CENTRES, standing free about 2 units off any wall.
  - `SewerAreaGenerator.wallSpot` now puts each one on a random north, west or east side, never south: the camera looks north, so a south-wall ladder would stand behind its wall. Each side is scanned from its middle outward to the corners.
  - `SewerArea.objWall` steps a walled exit `CELL/2 - EXIT_DEPTH/2` onto the masonry. `objYaw` lost its south branch.
  - Headless, over 100 generated levels: **145 exits, N 103 / W 22 / E 20 / S 0 / free 0**.
  - Seen live, flush on a north wall and climbing onto the cap.
  - Old saves keep centred exits, which draw free-standing and unturned, exactly as before.
- **Shadow and brackets, from the first look in game.**
  - The shaft lamp's 2.0 south step was written for a centred ladder. Against a wall it put the lamp 3.8 off, and the ladder projected at NDC y 1.45 in the spot's shadow camera (72 degree cone, pointed straight down), so it was neither lit nor shadowed. A walled exit's lamp now stays over the cell, 1.8 in front of the ladder (`SewerModel.exitWalled`, one answer shared by the yaw, the standoff and the lamp). The ladder is inside that camera up to z ~3.1.
  - A/B on the ladder's `castShadow`, shadow maps forced: **705 px darkened, by up to 110**, a rail-and-rung shadow on the wall behind it.
  - The upper bracket pair at 2.75 hung in front of the cap chamfer: the vertical face can stop at 3.0 - `CAP_SAG` 0.4 - `CAP_CHAMFER` 0.25 = 2.35. It moved to 2.15.
- **Trap.** A sewer room is 5x5 and a tunnel is 3 wide and centred, so a tunnel mouth takes EVERY middle cell of a side. Scanning the middle three only, 12 of 92 exits found no wall and fell back to the centre. The corners always keep theirs, which is also why north comes out heavy: a corner is north first, for the generator's tally and the renderer's yaw alike.

Verdict: **landed. White exit fixed at the source; 5,000 → 528 tris; every new exit is wall-backed.**

## Sewer water: wet pools and trickles (`render.sewer.SewerWater`)

Asked for: shallow pools and small ribbon streams in the sewers. The third attempt at water down here.

- **Why the first two failed, and the same reason both times.** The sludge gutter read as a dark stripe and the puddle decals (Lambert, opacity 0.30/0.35, art prompted "matte, NO reflections") as faint smears. Every tunnel surface is Lambert under ambient 3.95 + hemi 1.89, so water could only be drawn as DARKER albedo, which reads as a pit. What says liquid at this pitch is the sheen — and blood decals already ship one (`BLOOD.wetRough`).
- **What.** One packed 1k sheet (`sewer/water-sheet.png`, sunburst, `high`): three pool cut-outs plus a left-to-right flowing swatch. It ships as two labels: `sewer/water-pools` (chroma, `res` 1024, runtime uv rects per cell, so 1 material for every pool) and `sewer/water-stream` (tile, `crop` searched for the best horizontal wrap, wrapH **3.69** against an interior 1.3). Both meshes are `MeshStandardMaterial`, roughness 0.4, opacity 0.92, VisionMask-patched, built from `SewerGround.build` so the warm demo compiles them.
  - **Pools:** under 55% of the corridor-node lamps (pushed 3.0 south, into the glint), and a 6%-per-cell scatter (halved in rooms). They shrink until the rotated footprint lies on floor and keep clear of each other.
  - **Trickles:** off a SEEPAGE-stained N/W/E face (`SewerDetail.seepAt`, now the one home of the per-face decal roll). 70% of those faces run 3-9 units out, and only if a pool fits at the end. A strip is 4 verts across (alpha 0/1/1/0), u in world units over `STREAM_TILE`, and the flow is a CPU `map.offset.x` scroll from `SewerArea.tick` (0.6 u/s), so there is no shader patch to chain.
- **Measured live, habitat.** 6 pools + 1 trickle (15 spine points), **0 samples off the floor** for either. Old puddle meshes 0. Warm went **94 → 95 programs**, even though the demo tunnel rolls 0 trickles (4 pools): the stream mesh is added EMPTY on purpose, and an empty index range submits no call.
- **Trap 1: a lift fitted on the whole cut-out is fitted on the rim.** The silt rim is 0.105 linear, 1.6x the water's 0.065. Fitting the mean to 0.8x floor (lift 1.23) put the WATER at 0.65x and it read as a dark cloud. Re-fitted on blue-dominant pixels only (74% of the cut): **1.12 → 0.85x**.
- **Trap 2: a pale key leaves a pale outline.** `#5a5d63` was unusable (the rim sits within 24 of it), so the sheet was keyed on its own `#c8c8c8`. At `tol` 24 the LANCZOS blend of rim into key survived as a white ring round every pool; **`tol` 90 cut 4,125 px** and the ring went.
- **Trap 3: a tight glint misses.** A node bulb's mirror point lands at `bulb + 0.156 × (camera − bulb)` in xz (5.6 / (30.4 + 5.6) at this rig). That is ~3u off the bulb whenever the player is off to one side, so roughness 0.1 put the lobe just outside a 4.3u pool. A flat 0.05-albedo test quad showed it plainly: invisible at 0.1 and at 1.0, a broad sheen on the near edge at 0.45. Shipped **0.4**.
- **What it does NOT do.** Away from a lamp a pool sits at 0.85x the walkway and is quiet, and a trickle is a faint thread. That is the lighting, not a bug. The knobs are `POOL_ROUGH`, the pools' `lift`, and `LAMP_POOL_PCT`.

Verdict: **landed. Water reads as wet where a lamp reaches it; puddle decals retired (−2 meshes), pools +1, trickles +1.**

## Sewer water surface shader: ripples, varied roughness, tamed glint (`SewerWater.surface`)

Asked: the pools carried "a very even white specular highlight". Cause: a flat plane at one roughness
(0.4) under one overhead shaft draws the same smooth GGX disc on every pool, and the `9db4d4` shaft at
intensity 45 drove it to near-white. A/B with the patch neutralised (amp 0, rough 0.4 everywhere, no
tint or knee) reproduced exactly that: a white cloud-shaped blob filling the lit half of the pool.

One `onBeforeCompile`, applied BEFORE `VisionMask.patch` so the mask chains over it (own key
`sewerWater`), on both the pool and the trickle material:
- **ripples**: four directional sines in WORLD xz (λ 0.9-2.3u, unrelated angles), analytic
  gradient → shading normal. World space, not uv: the pools are atlas cells drawn at 3-7u, so a
  normal map on their uv would ripple at a different scale per pool. Amplitude is damped to 0.25x on
  slow value-noise "scum" patches.
- **roughness**: 0.18 on water, 0.65 on the silt rim (albedo luminance 0.07..0.10 linear) and up to
  60% of the way there on the scum patches. The ripple tilt is what lets a smooth surface still find
  the glint — the trap that forced the first cut to a uniform 0.4 (the mirror point wanders ~5u).
- **highlight**: `directSpecular *= 0x8f9a7a`, then a Reinhard knee on the peak channel (cap 0.9):
  asymptotic, so no flat plateau; hue-preserving, where a per-channel clamp bleaches it.
- clock: `uTime` in BASE_MS turns off `SewerWater.tick` (measured 6.55/s against 6.67 expected);
  phase rate 0.06 rad/turn pools, 0.15 trickles.

Tuned live via the shared uniform objects: amp 0.25 / cap 0.6 gave faint diagonal bands; **0.35 /
0.9** gives bright broken caustic-like squiggles across the lit half. Warm 95 → 95 (the patched
material replaces the plain one), 0 programs with diagnostics, +0 calls. An unlit pool or trickle is
unchanged: still only the sheen says "water", and there is none without a lamp.

## Sewer water ripples at PUDDLE scale: shallow noise film, not waves

Feedback on the shader above: "scale is wrong, that's supposed to be a human-sized puddle", "which is
also not deep at all". The four sines ran at λ 0.9-2.3 WORLD units against a 4-unit cell that is
one person, so a 3-7u pool carried ripples half a body long: the look of deep water.
- `WATER_SCALE` (ripple units per world unit) was added first. At **5** the same sines drew a
  regular **chain-mail plaid**: summed sines interfere into a visible grid once several periods fit
  in a pool.
- **Sines replaced by two drifting octaves of value noise**, slope by forward difference (3 height
  evaluations, about 24 hashes per fragment on a few hundred pixels). That is irregular by
  construction.
- Live A/B on the lamp pool: scale 3 / slope 0.12 mottled; 5 / 0.08 grainy "crumpled foil";
  **4 / 0.05** a still, thin film with a soft irregular glint, which is what ankle-deep water does.
  Trickles 0.1.
- Roughness split, tint and knee unchanged. Warm 95 flat, 0 failed programs.

Trap: the earlier amp 0.35 "caustic squiggles" looked good in a crop and was wrong in kind. Judge
water against the size of the actor standing next to it, not on its own.

## Actor hit flash: `Effect` got a GLOW channel (host breaking: red flash + shake)

When degradation brings the player's host close to collapse (`Player.isHostBreaking` turns true
inside `EvolutionManager.turnDegrade`), the host sprite flashes red once and shakes, and a red
cracked-heart badge joins its badge row.
- `render.anim.Effect` gained `glow` (color) and `glowInt` (intensity), refreshed per frame like the
  offsets. `Actors.drawActor` paints `emissive: fx.glow, emissiveInt: max(lamp, fx.glowInt)` while
  it is lit; otherwise the flame flicker as before. Sprite quads are created with `emissiveMap = the
  sprite`, so the define is stable: no recompile, no new program, +0 calls.
- `BreakShake extends Shake`: `glowInt = peak * sin(pi k)` over `BASE_MS * 3`, jitter 0.09 CELL.
- Emissive MULTIPLIES the sprite's own texels. `#f26a6a` (the HUD alert red) at 1.6 turned a yellow
  face orange and a white shirt pink; raising the peak to 2.4 only saturated toward the same hues.
  `#ff2a2a` at **2.0** reads red on skin and cloth alike.

Trap: CDP `take_screenshot` returned frames seconds after the eval that started the flash. Three
captures of a 450ms flash (and one of a 4s one) showed nothing, which looked like a dead emissive
path until a 30s stretch (`RenderConfig.BREAKING.ms` patched live, it is not inlined) showed it.
Verify a one-shot effect by sampling `actors.get(e).fx` per rAF, or stretch it, never by a single
screenshot.

## Corp desk phones: the reception phone glb on every `CORP_TABLE_PHONE` cell (`CorpClutter.deskPhones`)

The generator deals `Const.CORP_TABLE_PHONE` onto exec, small-office, boardroom and reception wall
desks, and nothing drew it: rows 23-39 are suppressed (`CorpDeco.draws`) and the desk clutter sheet's
own phone lands at random. Invisible until the phone started RINGING (`corp/phone`,
render.corp.CorpSounds), reported as "phone 5% on the exec desk, I see no phone there".
- `CorpDeco.K_PHONE` (row 25, cols 6-9). `CorpClutter.phoneCells` = those decorations on a worktop
  (`m.table`) that is not a kitchen counter; the sound rings off the same list, so every ring has a
  phone and every phone can ring.
- `deskPhones` runs before any decal rolls: the cell's claims (`CorpProps.claims`, or
  `CorpExec.claims` on an exec desk), rejection-sampled like a decal, footprint
  `REC_PHONE_R x REC_PHONE_H` (0.46 radius), top = `CorpFurniture.topH(surf)` or `EXEC_DESK_H`.
  Yaw faces AWAY from the first claim (the screen), so it turns to whoever sits there, ±0.35 rad.
- Its box joins the claims (`execClaims`, else `phoneSlots` read by `cell`), so no decal lands under
  it; a `FacilityDetail.deck` pool for the contact shadow, like the promoted desk props.
- **Into `rec.phones`: the reception counter's batch.** Same glb, same height, so **+0 draw calls**
  (77-78 dc before and after on the same floor), and the path was already warmed (`CorpWarm`).

Measured on a regenerated floor: 6 markers, 6 phones drawn (1 boardroom, 4 exec, 1 office). Trap:
a phone on a cell with no claims (a boardroom slab) has no screen to turn from, so it takes the cell
hash's yaw; that is right for a shared table and would be wrong on a desk.

## The military base renders through the FACILITY renderer (`View.showFacility`, `Surf.WILD`, `MilitaryMargin`)

`AREA_MILITARY_BASE` was the last 2D area besides the underground lab. Its new generator
(`gen.military.MilitaryGen`) lays a lab compound's buildings and hangar inside a fence ring, so it is
drawn by `render.facility.FacilityArea` with no `Area3D` of its own: `GameScene.is3DArea` and
`draw3D` route `'militaryBase'` to `showFacility`; it warms under its own `warmKey`
(`FacilityWarm.build` plus `MilitaryMargin.warmProps()`, **108 programs, 3.5s**, once per session).
- **`Surf.WILD`**: a base has no park, so `FacilityModel.fromArea` turns every `GRASS` cell of a base
  into WILD, and `surfOf` maps the margin's rocks and thickets there. The park's railing, kerbs, bins
  and plants all test `GRASS` and so never touch it. WILD sits at **y 0**, not `-KERB_DROP`, because
  the wilderness scatter planted on it sits on a flat field at 0.
- **`MilitaryMargin`** reuses `WildModel.fromArea` and `WildProps.build` with
  `WildBand.reliefAmp = 0`. Every non-WILD cell is marked `OCCUPIED`, so neither the scatter nor
  `WildProps.small`'s loose stones land inside the fence; `road = null`, so no guard rail runs the
  base's road. The ground takes `WildBand.cur.ground`, the band's own turf.
- The base's row-19 tiles read as `LOT` (tents, containers, vehicles, pad), BEFORE the `OFFSET_ROW8`
  catch-all that would have made them room floor and roofed them.

Trap: the fence ring went in as `LOT` too, and `FacilityPaint.isEntry` takes ANY lot cell within the
pavement band of the road. The fence line on the gate side is two rows off the road, so the whole
fence joined the gate mouth, its bounding box spanned the base, and `FacilityEntry.find` returned
null: no booth, no barrier. The fence, its torn panels and its towers now stand on a `WALKWAY`
footing strip, and the gate builds (`barrier-hand.glb:1`, `booth-hand.glb:1`). The facility's
`FacilityLamps` stand masts along that strip as perimeter lights.

Measured on an 80x60 base from a high free-cam pose: **111-130 calls, 330-400k triangles**; at the
gate from outside **111 calls, 330k**.

## The military base's furniture is EMITTED (`render.military.MilitaryGeom`)

Everything a base stands on its row-19 tiles is axis-aligned slabs or a rhythm of a material, so all
of it is quads plus a tiling texture, one mesh per texture: the opaque ones through
`FacilityGeom.add`, the three see-through ones (chain-link, razor wire, camo net) as opaque
`alphaTest` DoubleSide, the `FacilityCable.add` material, so no new program.
- **Fence**: two cells high (`FENCE_H` = 2 x CELL), a pane per ring cell on the cell's centre line, a
  post at every cell edge, the razor coil along the top (v 0..1 over 1.6, u at the 1024x640 source's
  aspect). A breach cell takes `military/chainlink-torn` 0..1 over its lower CELL x CELL. The gate
  mouth and the pedestrian gap carry no pane.
- **Watchtower** over its 2x2: concrete legs, an olive deck, parapet, roof posts and an overhanging
  roof, a sandbag ring at its foot. EMITTED and not hand-modelled in Blender as the plan said: its
  read is boxes, and the route needs no running Blender.
- **Tent**: canvas walls to a 2.2 eave and two slopes to a 5.6 ridge along its long axis, gables
  as degenerate quads; the slope's v runs its own length so the canvas is not squashed by the pitch.
- **Container**: 3 cells from its origin, corrugated sides and lid, `military/container-door` 0..1 on
  its west end, its height locked to that crop (`CONT_H = CONT_W * 546 / 508`).
- **Camo net** on four poles over every tank and humvee footprint, 0.6 past it; **helipad** concrete
  as a cap 0.02 over the lot; **armory lockers** through `CorpFurniture.lockerBack/lockerRect` in the
  corp art, the **safe** a squat box with `military/safe-front` (lift 0.68, the indoor value); both
  objects' sprites go through `MilitaryGeom.draws` in `Actors.iconOff`.

Art: `military/mil-pack-a` (canvas, olive corrugation, painted concrete, container ribs; seams
measured at exactly 512) and `mil-pack-b` (sandbags, apron, container door end, safe front; seams at
x 511/508 and y 478-480, crops cut to them) on gpt-image-2.5-sunburst, plus four solo
`background:"transparent"` gens. The camo net came back **90% opaque** with its gaps painted and was
re-cut with `edit_image` (48%). Total **$0.39**.

Trap: at one chain-link sheet per 2 units the mesh did not render at all from the gameplay distance.
The mips average the 13 px wire's alpha under the cut; one sheet per 4 units and a 0.3 cut fixed it
(`docs/3d-geometry.md`, Alpha-cut faces).

## The military base's hardware is GENERATED (`render.military.MilitaryVehicles`)

Tank and humvees in the motor pool, a helicopter on the pad, a plane in the hangar: carried by
their outline, so TRELLIS glbs by the `facility/car` route, generated AT the budget
(`decimation_target` 10000, ships `tris: -1`), one instanced batch per model posed off the origin
tile `MilitaryGen.vehicle` stamped, centred on its `Const.MIL_*_SIZE` footprint.
- References: gpt-image-2.5-sunburst high, `style_prop`, isometric on `#5a5d63`. Three came back
  under the p50 69-77 band (tank 65, humvee 59, heli 54) and were fixed in code with `propstat
  --lift`, not re-rolled. The humvee needed `--lift 84` and lost its green doing it (chroma 8.6).
- `propstat` called all four COMPONENTS REJECT (largest 61-65%). They are not, for the car's reason:
  wheels, tracks, rotor and skids are separate pieces of one hard object.
- **Two lie across their footprint**: the humvee along local x, and the plane's WINGSPAN along local
  z. Both take a quarter turn. Read it off a top-down silhouette of the glb before posing, not off
  the reference.
- Heights fitted to the footprints off `widest/height`: tank 4.9, humvee 3.8, heli 9.0, plane 7.5.
  The plane is under the hangar vault's crown.
- Values: outdoor ones at 46-56 through a flat `baseColor`. The plane is INDOORS, so it goes to 77-86
  (0.6, not propstat's 0.23). The heli's flat 0.16 shipped LIME (42/54/35) beside the tank's olive.
  Its cast is the whole body, so per-channel 0.18/0.13/0.14 is right (0.16/0.11/0.16 went grey).
- **Trap**: a vehicle's footprint tiles mapped to LOT surf, which would lay an asphalt patch inside
  the hangar under the plane. `FacilityModel.fromArea` now gives each footprint cell the surf of the
  cell west of it (left to right, so a run carries it in). The heli footprint takes the apron too.
- Camo nets over EVERY vehicle hid the whole motor pool from the camera (five camo sheets, nothing
  under them). Now every other vehicle gets one.
- **Helipad marking**: one alphaTest quad over the pad's square. gpt ignored `background:
  "transparent"` and painted the pad (a flat 44/47/51 slab). It is keyed on that measured colour
  (`class: chroma`, tol 40) instead of re-cut; the chips key out as holes. Lift 1.4: at sRGB 121 it
  was the brightest thing in the night frame, glowing through the vision mask; now 93.

## The military base wears its OWN art: `MilitaryStyle.shell()` and `rig()`

Reported from the game as "why did you fully reuse facility?": the base had gone 3D through the
facility renderer with no `ShellOpts` at all, so it wore the lab's cladding, glazing, doors, roofs,
hangar and lamps, plus the CITY's asphalt, pavement, kerbs and road paint. Corp had already proved
the route (share the emitters, share no art), so the fix is that route finished:
- **13 constants were still hardcoded at their emitters** and are now `@:optional` `ShellTex`
  fields: the hangar wall and vault, road/walkway/lot/kerb, paint, keep-clear zone, grime, cable,
  electrical pack, and the mast/fixture/bulkhead light colours. The door-lamp `hood` is REQUIRED,
  because corp reaches `FacilityGeom.build` too. `FacilityScene.build`'s sky/fog arguments plus its
  three hardcoded fill colours became `FacilityRigOpts` (`FacilityStyle.rig()`, `CorpStyle.rig()`,
  `MilitaryStyle.rig()`). `FacilityGlow` caches its lamp/door ratio, so the cache resets per build.
- **Two kinds of art.** Plain tiles were three packed sheets: block wall, felt roof, coping and head;
  asphalt, footpath, kerb and the vault's ribs; shutter slats, hangar cladding, lamp hood and cable.
  **Anything whose LAYOUT the code measured was repainted from its own facility source by
  `edit_image`** ("keep the composition EXACTLY"), with the source's alpha re-applied afterwards
  (the raw edits are kept in `military/Unused/`):
  - the two window units, so `WINDOW_ASPECT` 2.90 and 1.963 hold untouched;
  - the high light well, which still lands on its crop;
  - the four door pairs;
  - the hazard hatch;
  - the PACK64 electrical sheet, where every cell stayed in its slot;
  - the grime band.

  Not one aspect or cell index had to change.
- **Trap: the edit INVERTED the road paint.** `city/ground-road-paint` is solid paint with key-grey
  chips, and the edit painted grey ground with yellow flecks. It is a colour change of a chip pattern,
  so it was done in code (the source luma tinted to 196/158/52) and not re-rolled.
- **Values**: each label's lift is the gamma that takes its raw build to its facility counterpart's
  built linear. The raw values were up to 3.3x off (block wall 0.1075 against 0.0327, yellow hatch
  0.24 against 0.07); all landed within 10%. The base's indoor aisle marks lose `MARK_COLOR`, which
  would have tinted the yellow paint yellow again.
- **The warm is unchanged on purpose**: a program keys on material FEATURES, not on which texture
  or light colour, so the facility demo already compiles everything the base's art draws with.
- The hangar cladding's crop was cut to 13 whole rib periods (494 px): the 504 crop wrapped at
  23.3 against an inner step of 5.4.

## The military base's rooms are its own: barracks, mess, briefing, HQ, latrine, armory

**What changed:** the base's rooms had worn the lab's interior: lab floors and walls, a desk quota,
the janitor's kit and corp's locker art. They are now dealt as their own kinds
(`FacilityRooms.militaryThemes`) and furnished by `gen.military.MilitaryRooms`.

- The furniture is 5 floor tiles plus 11 furniture tiles on `Const` row 20.
- `render.military.MilitaryInterior` emits the furniture into `MilitaryGeom`'s per-texture buffers,
  one texture per face, with one `FacilityDetail.ground` per run.
- New `Surf` values BARRACKS/MESS/BRIEFING/HQ (22-25), with `SURF_SLOTS` 26. The latrine is WASH
  and the corridor is LINO, each in the base's own art.
- `isIndoor` is now `>= TILE && != WILD`, because the new surfaces sit above WILD.
- `MilitaryStyle.shell()` swaps every interior floor and wall face.
- The lockers, the gun cabinet (no longer corp's glb, via the `ObjModels` gate) and the safe's
  steel wear the base's art.
- The janitor's kit and the indoor bins are gated off in a base.

**Numbers:**
- Art: 6 packed 1k sheets at $0.055 each: floors, wall faces, furniture materials, and two sheets
  of authored fronts (map board, cubicle door, filing cabinet, locker, gun rack, footlocker lid).
- Each of the 25 labels was fitted (`g = ln(target)/ln(raw)`) to its facility counterpart's built
  linear. Furniture targets ~78 sRGB indoors.
- `make gen --type military`: 3000 seeds clean.
- Live: a briefing-room frame draws 55 calls and 24k tris.

**Traps:**
- A run is the longest straight line of one tile, x tried first, with taken cells marked. Two desks
  on two walls meet at the room's corner, and a both-axes origin test drops the second one.
- `area regen` re-entered the base with no 3D scene. Reload the forced autosave (slot 0) instead.

**Verdict:** landed.

## The military base's yard, gate and roofs are its own: no facility glb left in a base

**What changed:** a live inventory of the base still found facility kit:
- the 7 roof glbs (condenser, dish, hatch, isolator, vent, duct, tank) and the roof-litter atlas;
- the lot's cones, tyres and reels, and 66 facility lamp posts;
- the facility booth and barrier glbs;
- the corridor exit-sign and wall-point sheets.

`render.military.MilitaryYard` emits the base's own on the SAME spots each pass already derives:
- `FacilityEntry.find` → a sandbagged guard post with a corrugated roof and a whip aerial, plus
  `FacilityEntry.barrier`, made public and given its textures, in `military/boom-arm`;
- `FacilityDebris.spots`, split out of `place` → ammo crate stacks and octagonal fuel drums;
- `FacilityLamps`' places → steel floodlight masts with a crossbar and two lamp boxes, at the glow's
  own `reach`/`bulbY`;
- `FacilityRoof`'s deck lists and `*Of` owners → per structure, a sandbag nest, water tanks, an
  aerial and plain steel service kit. These go onto each deck via `addDeck`, so they fade with it.
- The gate gets `TILE_MIL_JERSEY` jersey barriers, stamped by the generator (unwalkable).
- `ShellTex` gains `exitSign`/`wallPoints`/`roofClutter`.

**Numbers:**
- Art: one packed sheet (boom bands, crate lid, drum top, drum side) and three `edit_image` repaints
  with the layout kept. The roof litter's alpha was re-applied from the facility source.
- Levels were fitted to each facility counterpart's built linear.
- `make gen --type military`: 2000 seeds clean.
- No new glbs and no warm change.

**Traps:**
- A crop change does not make `tools/textures.py` rebuild: it keys on the source mtime and the
  lift. Drop `last_converted` to force it.
- An unset `res` builds a 2:1 crop square, so set `res` to the crop's aspect.
- The jersey long faces were wound inward on the first pass. Check `(p1-p0)×(p2-p0)` against the
  face's outward side: `FacilityGeom.face`'s dir 1 is the reference.

**Verdict:** landed.


## Military base fix pass: towers inside the corners, closed fence corners, base meshes cast, margin patches

**Changed:**
- `MilitaryGen.perimeter` stands each 2x2 tower ONE CELL INSIDE its corner, on the EDGE lot, and
  the ring runs unbroken behind it. On the corner, the tower's inset left a gap each side of its
  legs that read as a way through.
- `MilitaryGeom.fence` is neighbour-driven: a straight cell spans its width, a CORNER cell is two
  half-runs at a right angle. Posts fall on every second cell edge plus each end and corner (half
  as many).
- `military/chainlink` is cropped to 1020x905, five by four whole diamonds. The pure periods are
  203.9 x 226.2 px, measured by shift correlation of the alpha; the obvious 113 px is a half-step of
  the centred lattice and correlates at 0.002. It is mapped at that aspect (`CHAIN_V`), so it now
  wraps vertically.
- Tower: legs from the ground (they started on top of the sandbag ring), a parapet with an inside
  face and a rim (single-sided, it read as a hole from in the tower), and an emitted steel ladder on
  the face toward the base's middle.
- Every `MilitaryGeom` opaque buffer casts (`FacilityGeom.add(.., true, true)`); jerseys, tents,
  towers and crates read pasted on under the moon. The shadow map was already on in the base: moon
  2048 plus eight lamp spots at 512.
- `MilitaryMargin` lays `WildPatches` over the margin only, through a new `keep` cell filter.

**Trap:** `WildHeight.shade` divided by `reliefAmp`, which the base zeroes. Every patch vertex
colour came out NaN, and the NaN spread through the bloom chain and blacked the WHOLE frame, HUD
aside, while the renderer kept drawing 77 calls. Found by hiding every alpha-mapped mesh at
runtime. Flat now reads mid-range, a shade of exactly 1.

**Verdict:** landed. Military gen clean on 500 seeds.

## Military base fence: galvanised pipe posts and a razor-wire COIL that reads round from any side

**Changed:**
- Fence posts are 8-sided galvanised pipes (`MilitaryGeom.pipe`, `military/galvanized`) instead of
  boxes in the tower's olive sheeting; the tower ladder's rails are the same pipe.
- The razor wire is an 8-sided alpha-cut TUBE, 1.12 across (30% under the old 1.6 strip), resting on
  the fence top. Its art is a HELIX: u is one turn round the tube, v repeats every 1.4 world units,
  and four interleaved strands put a loop every 0.35. Seen through the tube, the front strands and
  the back ones slope opposite ways and cross like a concertina coil's, from every camera angle;
  the flat strip read as a painted band from above.
- Art: `mil-pack-m` (burlap, galvanised steel, olive mast paint, floodlight front) plus one solo
  alpha gen, **$0.17** with the failed re-cut. Lifts were fitted to the family: galvanised and coil
  to the chainlink's 0.104, burlap to the old sandbag's 0.0437, mast paint to the olive sheeting's
  0.0505.

**Trap:** the coil drop's spacing and barb phase drifted, so no crop of it wrapped (row seam step
0.08 against 0.007 inside). It also came back OPAQUE on a dark ground despite
`background:"transparent"`, and an `edit_image` re-cut returned a half-transparent ground (alpha
mean 0.36, no clear pixels). `tools/razorcoil.py` keys alpha off luminance (72-86; the drop is
cleanly bimodal), rotates one strand flat, and lays it back as the helix with 12 whole barb
periods a turn. Seamless by construction, square texels. Both raw drops are parked in
`textures-src/unused/military/`.

**Verdict:** landed.

## Military base: hand-modelled sandbags stacked in courses, a floodlight mast on the lamp contract, city lamps outside

**Changed:**
- **Sandbags.** One bag (`models-src/military/basekit_build.py`, 76 tris): a rounded section swept
  1.2 along x, swelling to the middle and pinched at the tied ends, one course (0.32) high. It
  replaces the sandbag sheet on emitted slabs, which did not wrap. `MilitaryBags.ring` stacks it
  round a rect in running bond: odd courses are offset half a bag, each bag is turned ±0.07 and
  nudged ±0.05 off a hash, and a door side is left open.
  - Placed at the tower foot (3 courses, open at the ladder), the guard post (5) and the roof
    nests (4).
  - Two batches: ground bags (`MilitaryGeom.build` returns them; culled with the margin and added
    to the shadow casters) and roof bags (`Roof.bagB`/`bagOf`, masked with their roof like the
    tanks). A generated base had 322 and 76.
- **Floodlight mast** (428 tris): a tapered 12-sided pole on a galvanised flange, a collar, a swept
  outreach arm and a pitched head wearing the lens art. It is on the FACILITY LAMP'S head contract
  (LAMP_H tall, head at `LAMP_HEAD_Y`/`LAMP_HEAD_Z` of it), so `FacilityLamps` draws it in place of
  `facilityLamp` and its cone lands on the head. The emitted box mast put a lamp either side of the
  cone's one bulb, reported as cones not lining up.
- **Outside the fence the lamps are the city's** `streetLamp`, with the bulb at `LAMP_LIGHT.dz`.
  That is 15 on a generated base, against 33 masts.
- The model sheet is `tools/modelsheet.py` over the BUILT labels, so the fitted lifts ride along.

**Traps:**
- `Models.normalize` recentres a glb on its BBOX, so the head offset is measured from the bbox
  centre and not the pole. The flange behind and the head's own reach in front both move that
  centre, and the head went 0.708 → 0.672 out to land at 0.3542 against the contract's 0.354. The
  script reads it back off the built mesh.
- `isOutsideBase` counts the RING as outside. 20 of the first 35 "street" lamps stood on fence
  footing lighting the yard; the ring tiles are excluded.
- Blender was not running and the MCP's CLI tool could not find it. The build ran headless
  through interop: `blender.exe -b --factory-startup --python-expr`.

**Verdict:** landed. `buildlib.check`: 0 holes and 0 coplanar on both. The mast's one `texel_off`
is the lens, which takes its whole cell by design.

## Military base fix round 3, quick fixes: no floating bags, no mast in a tower, a clear gate approach

**Changed:**
- `MilitaryBags.ring` keeps each side's bag centres per course, and lays a bag above the first
  course only where its centre is over one below. The door test is per bag, so the gap fell
  differently on each course and left top-course bags beside the ladder doorway hanging. A
  regenerated base measured 0 unsupported of 236 ground and 72 roof bags.
- `FacilityLamps` skips a lit-line hit on or beside `TILE_MIL_TOWER` in a base. Tower cells read as
  WALKWAY, so the scan stood a mast in the tower's ladder. Now 0 of 31 masts are within a cell of a
  tower.
- `MilitaryYard` keeps the yard clutter 4 cells clear of the gate's hole, so no crate stack stands
  in front of the boom.
- The tower roof slab is 0.2 thick, from 0.4.

**Verdict:** landed.

## Military base: its own steels, off the green window-head

**Changed:** every `TEX_STEEL` in MilitaryGeom/Yard/Interior was `MilitaryStyle.WINDOW_HEAD`. It is an
olive lintel strip, and it covered bunk posts, table legs, desk sides, file cabinets, lockers, the
safe, the barrier cabinet, the guard post, roof kit and crate ends. The user picked it off five
different objects. New sheet `mil-pack-n` (one packed gen, gpt-image-2.5 sunburst high), each cell
listed with what it now covers:
- `enamel` (raw 0.096 linear, no lift): bunk posts, table legs, desk sides;
- `gunmetal` (raw 0.025, lift 0.84 → 0.042): file cabinets, the safe, the barrier cabinet. At 0.025 a
  solid side read as a hole against the office floor's 0.110;
- `chequer`: roof hatches;
- `cot-top`: reserved for the medical bay.

The rest moved onto existing textures:
- `galvanized`: guard-post frame, aerials, vents, duct, junction boxes;
- `mast-paint` (olive enamel, matching their olive fronts): locker sides and tops;
- `crate-side` planks: footlocker sides and crate ends.

`window-head` is left only on the shell's real window heads.

**Verdict:** landed.

## Military base: the yard kit hand-modelled (drum, crate, container, roof tank) and a sharp mast

**Changed:** four emitted props became glbs from `models-src/military/yardkit_build.py` (headless
Blender), each one instanced batch:
- **drum** (636 tris): the facility drum's 20-sided smooth profile at 0.6 x 1.6. Its hoops sit on
  drum-side's painted bead rows (0.330 and 0.725 up), the side is wrapped twice and the lid is
  mapped radially. It replaces an 8-sided can.
- **crate** (112 tris): broken edges, an overhanging lid slab, and the lid's two battens raised on
  the painted ones (columns 39-85 and 428-474).
- **container** (716 tris): castings, posts and rails round corrugated sides, back and roof. Each rib
  is one painted period of container-side (88 px), and the door end has two proud lock bars. Its
  432 open edges are the skins' borders, hidden by the frame.
- **water tank** (628 tris): a galvanised lathe with hoops, a coned lid and a manway, on four
  gunmetal legs with a pipe. It replaces the olive octagon.

**Mast:** tex 512 → 1024, and the pole now maps the paint cell twice (split at 2.95). That takes it
from 43 to 171 texels per world unit. The head readback is still -0.3542 against -0.354.

**Trap — roof glbs came out near black.** `FacilityWarm` vision-masks every extra glb it warms, and
a SOLID batch shares the template's material. The vision mask chains `IndoorMask`, so the roof
sandbags and the roof tank were lit by the indoor rig over their building's interior. The fix is
`MilitaryYard.unmasked`: each roof batch takes a material clone, which carries no `onBeforeCompile`.
The ground kit now gets `VisionMask.patchMesh` explicitly instead of by accident.

**Generator fix:** the Phase 2 entry yard took the depot's plot on 90x70 bases (0.22 depots a base
to 0). The first depot is now dealt before a second camp, and `GenCheck.quotaMet` caps a kind at
the larger `max` of its rows. 2000 seeds pass, at 0.76 depots and 1.45 camps a base.

**Verdict:** landed.

## Military base rooms: comms, supply and medical, and the existing kinds fuller

**Changed:** a new sheet, `mil-pack-o` (one packed gen), covers three new room kinds:
- **comms room:** radio rack fronts, and a console strip over each console cell with its radios at
  the wall end;
- **supply store:** shelf fronts;
- **medical bay:** white cabinet fronts, and cots whose pillows sit at the wall.

The bottom-right cell is two 2:1 bands, the console top and the cot. A square cot cell would have
stretched 2x over the one-cell cot, so the mil-pack-n cot moved here.

**Levels fitted:**
- radio rack raw 0.036 → lift 0.903 → 0.047; at raw it read as a hole in the wall;
- medical cabinet raw 0.395 → lift 1.846 → 0.194; raw was 2.7x the office wall's 0.146 and read as
  a lamp.

**Emitters in `MilitaryInterior`:**
- rack, shelf and cabinet are square `front()`s, one per cell even in a row;
- the console is a gunmetal desk with an `art()` strip per cell;
- the cot is an enamel frame with its strip;
- a supply or armory crate stack is the yard's crate glb, one or two per cell;
- a free-standing desk pair is a `table()`, and a free-standing cot lies along x.

`art()` maps an authored top with u along a given axis and v a quarter-turn from it, so nothing
reads mirrored from above.

**Fill:** office 23 → 32%, armory 18 → 24%, comms 27%, supply 35%, medical 21% (area-gen.md has
the stat).

**Verdict:** landed.

## Military base rooms: every piece of furniture hand-modelled, blinking machinery, standing props

**Changed:** the rooms were reported as "all very empty and emitted inside": a radio rack was a box
wearing a picture of radios, a console a slab with radios and a log PAINTED into its top, a shelf a
box wearing a picture of shelves. `models-src/military/roomkit_build.py` now builds 27 glbs on
MilitaryInterior's own footprints, one instanced batch each:
- comms: the rack (four units proud of its front, louvres), the operator desk, two radio sets;
- the rest: bunk (960 tris), cot, footlocker, office desk, filing cabinet, folding chair (stood
  render-side at every desk), shelf unit with cartons, medical cabinet, mess and briefing tables,
  bench, and the serving counter with pans sunk in its top (two variants);
- standing props in the bays a room's zones leave (`MilitaryRooms.slot`): rifle rack, ammo cans,
  jerrycans, flag stand, water cooler, IV stand, stretcher;
- the armory's lockers, gun cabinet and safe.

Only the latrine's cubicles, its trough and the map board stay quads.

**Blink:** the rack and radio art paints UNLIT lamp sockets; the script measures them off the sheet
and prints them in the normalized glb frame (`leds`), and `MilitaryInterior.lamps` hangs one
additive `quadRGB` speck on each into `FacilityDeco.lamps`' mesh, +1 call, the shared clock.
Measured on screen: every speck lands on its socket.

**Art:** three packed gens, $0.165: p (rack units, radio faces, plain lino desk top, radio case),
q (ticking, white enamel, ration carton, steam pans), r (jerrycan, ammo can, flag, bottle and IV
bag). Sheets packed from built labels; `console-top`, `radio-rack`, `shelf-front` and `cot-top`
retired. A 3x3 and a 3x2 model sheet work with `buildlib.cell(i, cols, rows)` unchanged.

**Traps:** a carton front wearing the square art whole was stretched 1.6x: each front takes a band
cut to its own aspect about the stencil. Rods of equal radius meeting at a post, end faces of
equal-width parts and flanks 0.01 apart all count as shared planes; staggered by 0.015+.

**Cost:** about +7 to +12 calls in a furnished room's view (58 → 65-70 in the comms room, unpinned).

**Verdict:** landed.

## Military base rooms: flat clutter, one pack16 per room kind

**Changed:** `render.military.MilitaryClutter` lays flat decals in the base's rooms, cut from
`textures/military/<role>-clutter`, a 4x4 pack16 per room kind (9 sheets). The sheet a room deals
from is its `generatorInfo` role, so a mess hall never gets a rifle. Reported as "empty fucking
table" and a console with its radios and log PAINTED into its top.
- **Lids:** `MilitaryInterior` records a `MilitaryLid` as it stands each desk, operator desk, mess
  or briefing table, footlocker, filing cabinet and medical cabinet. A comms desk's lid carries its
  radio set as a claim box, so nothing lands under the glb.
- **Counts:** desks take 1-3, tables 2-4, lockers and cabinets 0-2 / 0-1. Rejection-sampled in the
  lid's own frame (FacilityClutter's sampler and `ClutterSlotTools.hits`).
- **Floor:** 15% of a room's bare cells, from a per-role `FLOOR_PICK` list only. A telephone or a
  stapler on an office floor read as dropped; boots, a puddle, crumbs or cartridges read as litter.
- **Size:** 1.1 + 0.4 units on a lid, 1.4 + 0.4 on the floor. 0.9 read as crumbs on a 3.9 x 2.8
  table.

**Art:** 9 gens + 4 re-cuts, $0.75. **gpt-image-2.5 sunburst with `background:"transparent"` cut
only 5 of 9 drops:**
- hq and barracks came back UNCUT, with lane alpha p50 183 / 107;
- medical carried a wash to ~50;
- armory had a haze bridge of 85-180 between two subjects that `pack16.py` refused.

One `edit_image` pass each (sunburst, transparent, "keep the objects, remove everything else")
brought every lane p50 to 0. Then pack16 at `--valign center`. The built sheets are 0.076-0.099
linear against the tops they lie on (laminate 0.097, enamel 0.096), and corp/exec-clutter's sat 0.5
and cap 0.1 were used unchanged.

**Cost:** one merged mesh per room kind, at most 9 calls a base and 2-4 in a room's view.

**Verdict:** landed.

## Military base rooms: wall sockets and machine leads

**Changed:** the base's rooms get `FacilityCable`'s sockets, the same `strip` cables, and the
`military/electrical-pack` and `military/cable` art `MilitaryStyle.shell` already dealt. No gen.

**Why none showed:** the base's rooms had none for two reasons:
- `bare()` gates on `FacilityPlacard.hangs`, which accepts only `Surf.TILE`/`OFFICE`, and a base
  room is BARRACKS/MESS/BRIEFING/HQ;
- `feeds()` only read `m.deco`, which a base never fills.

**The fix:**
- `hangs(…, true)` (the electrical family's flag, and only theirs) also takes the four base room
  surfaces.
- `MilitaryStyle.fitOf` deals every room furniture tile into `m.fit`, so `bare()` can add
  `m.fit == 0` and stops hanging a plate behind a bunk or a desk.
- `FacilityCable.machine()` dispatches a drop's anchor: a lab fitting through `FacilityDeco.rectOf`,
  a base's radio rack, operator desk or water cooler through `MilitaryInterior.powered` (a
  `DecoRect` off `m.fit` and the walls, so no ordering between the passes).

**Trap:** the armory's lockers, gun cabinet and safe are OBJECTS and not tiles, so `fitOf` cannot see
them. A socket hung behind a barracks locker. `MilitaryStyle.objects` stamps `FIT_OBJECT` on their
cells before `FacilityCable.build`.

**Measured on one base:** 20 room sockets, 0 behind furniture or an object, both reachable machines
fed (comms console, radio rack). The water coolers stand between two windows and take no plate.

**Verdict:** landed.

## Military base rooms: barracks gear in 3D, bed and locker-top clutter, art fixes

> The gear's straight extrusion is SUPERSEDED by "Military base gear: lofted, not extruded; footlocker and gear shadows"

**Changed:** the barracks sheet's boots, rucksack and canteen stand as Blender glbs (`boots-hand`
360 tris, `rucksack-hand` 176, `canteen-hand` 160, one packed gen `mil-pack-s`, $0.055).
`MilitaryLid.min/max` became a `LidKind`, and bunks (both decks' blankets and the floor under),
cots (canvas and under) and every locker or gun cabinet top are lids.

**How the gear is made:** the boot and the canteen were drawn on flat grey #5a5d63. Their outlines
were traced off the art (mask at 40, opened 5 px, inset 3, row envelope, Douglas-Peucker 1.2-1.6
px) and extruded, so each flank wears its drawing exactly where it was drawn. `buildlib.turned`
wears a rect a quarter turn, which is what the mattress ticking needed.

**How the gear is dealt:** a roll landing on one of those three cells stands the glb instead
(`SOLID`). That alone is 3 cells in 16, and the first base came out with no rucksack at all. So a top
that takes gear (`kit`) also stands one piece half the time, before its decals roll.

**Traps, all hit live:**
- a locker stands in its wall cell's margin, so its lid's centre is not in the room; rooms now take
  any lid whose footprint reaches in;
- a bunk's two decks shared one seed and rolled the same bedding, so the lid height goes in it;
- a 1.21 rucksack under a 0.9 bottom deck stood through it, so only boots go under (`fits`);
- a locker's rucksack faced the wall half the time and showed its straps; it now faces out.

**Art fixes:**
- the locker leaf is cropped to its own top and bottom lines (rows 11-503);
- its arrises are gunmetal;
- the PVT. WILSON plate is smeared in `mil-pack-k`, with the raw drop in `Unused/`;
- the footlocker's window is centred on its stencil line, and its lid band sits on a plank with no
  lettering;
- the barracks lost its rifle rack.

**The hole:** a window run's top was `head` art sunk `HEAD_DROP` 0.02 under the roof. At every pier
that left a slit at z = the boundary, over the glazing band, with nothing in it. `ShellTex.capRoof`
(military only) roofs the run's top in the deck plane like solid wall, with no fading band. Measured:
0 of 136 window-head triangles left at 5.98.

**Cost:** +3 calls in a barracks view (84 against 81 with the three batches' layers off).

**Verdict:** landed.

## Military base gear: lofted, not extruded; footlocker and gear shadows

**Reported:**
- the boots: "top looks dumb, needs to be curved, not flat", "square???", "do you know how boots
  look?";
- the canteens: "flat middles... like someone cut out flask form from a piece of wood";
- a footlocker's arris through its stencil;
- "do these chests throw shadows? they should. and boots as well";
- the cards, the cigarette pack and the watch were half a metre across.

**Changed:**
- **Gear is lofted, not extruded.** The boots, canteen and rucksack are now `loft()`ed through
  their outlines: a superellipse ring at each height spans the outline there, with a heel taper and
  a sole lip on the boot and a lens across the canteen. The side art is PROJECTED onto faces whose
  |n.y| > 0.6, which caps the stretch at 1.7x round the curve, and the edge band takes the rim
  tile. Boots 360 → 1,016 tris, canteen 160 → 416, rucksack 176 → 512, all instanced.
- **The boot collar slants.** Taken level at the very top, the ring pinched to the tongue's tip
  and the shaft came to a point. The ring is now taken at the back's height, its front raised to the
  tongue's, and it stays open: a lip and a sunken floor.
- **Footlocker arris:** the body chamfer is on the plain plank. On the stencil window it was a 2 px
  strip through the letters.
- **Shadows:** the ceiling lamps are `noCast` and the indoor rig is 82% ambient, so the lever is
  `FacilityDetail`, not a shadow map.
  - A footlocker is past `GROUND_POOL_MAX`, so it got the field alone. It now gets a `pool` whose
    core is taken `FOOT_SHADOW` 0.2 past the box. At the box's own size the ramp's dark core sat
    under the box, and the visible rim measured 3-10/255; it now measures 15-21.
  - Gear grounds itself: `ground` on a floor, a round `deck` pool kept on the lid on a top.
- **Small decals:** the `SMALL` per-cell scale on the barracks sheet. Cards 0.35, cigarettes 0.3,
  watch 0.25, dog tags 0.45, socks 0.4; cards measured 0.45 across.

**Verdict:** landed.

## Military base: gear rims tiled, store shelving shaded and in rows, smaller boot pool

**Reported:**
- boots and canteen: "also need different texture mapping", "blank single color won't do", on the
  toe, heel, collar and the cover's rim; "make hole deeper";
- a floor pair of boots: "contact shadow too large, reduce 30%";
- the shelf unit: frame "replace with darker"; "boxes need contact shadow and lower boxes need to be
  darker like we do on all shelving units";
- the store: "looks way empty because a few crates are in the middle".

**Changed:**
- **Gear rims tile in world space.** Every face off the projected art was FITTED (`tag …, 5` with a
  scale), so each took the same few texels of the cell's middle and read as one flat colour. A
  per-piece `cut()` (`grid_cut` on that piece's faces only) and `buildlib.tile_uv` now lay boot
  leather (0.6 a tile), the canteen cover's plain middle (0.18) and canvas (1.0) continuous across
  faces. Boots 1,016 → 1,104 tris, canteen 416 → 552, rucksack 512 → 548. Boot pit 0.06 → 0.2.
- **Shelf shading is baked into COLOR_0**, the facility's own numbers (`DECO_BOX_AO_LOW` 0.78 →
  1.0 up the rows, `_FOOT` 0.70 at each carton's base), and each board's top is cut round every
  carton so a pool runs 0.45 → 1.0 over 0.1 out from it. `buildlib.export(colors=True)` writes the
  active colour attribute, `models.mjs` passes it through, `Models.toLambert` keeps `vertexColors`.
  One program permutation, no draw call. Cutting the whole board went 228 → 1,316 tris; tops only,
  772. Frame `enamel` (87) → `gunmetal` (57) in mil-s-sheet cell 0.
- **Store rows render back to back:** a `TILE_MIL_SHELF` with no wall stands two units in its cell,
  one facing each aisle, the row's axis off which neighbours are open floor.
- **`backing` prefers a wall with open floor in front.** A corner shelf tried the end wall first and
  faced into its neighbour's side. `powered` uses it too, so leads still find the same wall.
- **`FacilityGroundOpts.pool`** scales the floor pool; floor gear passes `GEAR_POOL` 0.7.

**Trap:** board pools barely read on gunmetal at 57; the cartons' darker feet carry the contact.

**Verdict:** landed.

## Military base: canteen cap off the drawn cap, shelf-top clutter, wall pieces stand on walkable cells

**Reported:**
- the canteen's neck and cap rim: "should be the same texture as" the front's drawn cap;
- a wall shelf and the jerrycans: "is near the wall and tile in front is unwalkable, tile 58,40";
- the store: "there's enough space for two rows here"; "shelving tops should have clutter spots".

**Changed:**
- **Canteen neck and cap tile a square of the drawn cap's ribbed plastic** (`bl.sub` 0.45-0.515 x
  0.07-0.135 of the cell), not gunmetal. That square is 33 px, so at the cover's 0.18 tile it came
  out at a fifth of the cover's texels (`texel_off` 24, worst 6.52). The neck is cut finer at its
  own `CAP_TILE` (0.034) and tiled in a first `tile_uv` pass, with the cover's faces held back from
  it: `texel_off` 0, worst 1.23. 552 → 716 tris.
- **Shelf tops are clutter lids** (`LidKind.SHELF`, 1-2 decals off the room's sheet) at the top
  board's face, `SHELF_W - 0.02`, inside the uprights, on wall shelving and on both units of a row.
  Same mesh per room kind: 0 calls.
- **Wall pieces' own cells are walkable** (`tiles.Default`, see area-gen.md). A 1.5 shelf against
  the slab covers half a unit of its own cell, the rest is bare boards. Store rows are a separate
  unwalkable `TILE_MIL_SHELF_ROW`, and stand two rows across a 7x6 store instead of one down it.

**Trap:** the front-cell rule of the last round answered the wrong cell. The player reads "the tile
in front" off what they see, and a piece in the wall's margin leaves its own cell looking empty.

**Verdict:** landed.

## Military base: every room piece shadowed, desk islands back to back, leads up to the radios, gear lying on its back

**Reported:**
- "tables and chairs do not throw shadows? cmon ALL 3d objects should throw shadows by default";
- a socket-to-socket cable "goes into the wall... and into the other wall socket";
- the operator desks' leads: "cable does not go up to actual radio";
- the folding chair's back and uprights "intersect so that back sticks out", and the back's slope;
- the office desk's back "very uniform for all polygons";
- "when tables are in the center, spawn two back to back"; "allow canteens and backpacks to also
  lie on their back"; clutter on the rack tops; the keypad set's lamps 30% smaller.

**Changed:**
- **`MilitaryInterior.shade`** is the one shadow call for a room piece: `FacilityDetail.ground`, plus
  a `FacilityDetail.pool` past `GROUND_POOL_MAX`, core `FOOT_SHADOW` past the footprint. Plate goes
  to the slab face at a wall and one cell further at open floor. Every run, the armory lockers and
  safe, and each chair (in its own cell) use it. Radios lay a `deck` pool on their desk.
- **`FacilityCable.joins`** rejects a run whose in-between cell is a wall or holds a base piece
  (`m.fit`). Rooms along one outer wall share an unbroken wall line, so two sockets either side of a
  partition were "joined" through it.
- **`DecoRect.lead`**: the operator desk's lead climbs to its radio, mid-height of the set, over the
  radio's own width. `RADIO_BACK` 0.25 → 0.08, so the lead meets its back.
- **Chair back** raked with its uprights (`CHAIR_RAKE` 0.15) on their front face. **Desk** body
  olive, tiled in world space (`DESK_TILE` 2.0). 212 tris.
- **`PropPlace.pitch`**: canteen and rucksack lie on their back half the time, lifted half their
  depth and moved back half their height.

**Trap:** a fitted per-face map gives every face the cell's SAME middle; on a near-flat swatch that
is one patch stamped on every polygon.

**Verdict:** landed. +1.4k tris on the comms view, 0 new meshes or programs.

## Military base: pools a fixed fade past the footprint, armory crate stacks, gun locker, briefing boards, flag fringe cut

**Reported:** table and bench contact shadows "way outside of the tables/benches"; the armory "pretty
empty", wanting crate stacks in the middle "stacked higher"; the rifle rack "looks like crap ... use
gun lockers"; bench planks "with dark holes. reduce scale"; bench and table legs darker; the flag's
lower end "dark black and straight, should be transparency"; the briefing room wanting "more 2d
decals"; a base door's reveal in the corridor's board on its room side.

**Changed:**
- **`FacilityPoolOpts.fade`**: `FacilityDetail.pool` lays nine quads, the ramp's opaque core over
  the footprint and a rim a FIXED world width past it. One quad's rim is `POOL_GROW` of the half
  extent: 1.8 past the end of a 3-cell table run, 0.66 across it. `MilitaryInterior.shade` passes
  `POOL_FADE` 0.4 with the core on the footprint, replacing the last entry's `FOOT_SHADOW` core.
- **Armory crate islands** run 3, then 2, cells down the room's long axis; each crate cell holds two
  stacks of 2-4. Over 2000 seeds, armory fill goes 10.69 → 11.54 cells; `zoneEmpty/crate-island` 0.01.
- **`TILE_MIL_GUN_LOCKER`** (the rifle rack's id) draws the gun cabinet glb through
  `MilitaryGeom.locker`, as furniture with no loot. The rifle-rack glb is gone.
- **Bench** tiled in world space at `BENCH_TILE` 1.3 from the seat's corner, five planks across;
  128 tris. **mil-t-sheet**'s fourth cell is gunmetal, not enamel, which is on eight sheets.
- **Flag** on its own `mil-p-cut` material, alphaMode MASK (`buildlib.material(clip)`, Alpha → Math
  Round). The fringe is hand-cut per column below its braid (`flag-cut.png`), and `modelsheet.py`
  keeps RGBA when a cell is cut.
- **Briefing boards**: one pack4 gen ($0.055), one 1024 label with `lift` 1.3, four measured boxes at
  `BOARD_PX` 170. Hung on every other plain-wall cell as one alpha-cut mesh: +1 call.
- **Base door reveals** are split on the leaf plane like a lift's: room half in the room's finish
  (military only). Verified off the merged shell's layer map: wall-office and wall-corridor halves.

**Trap:** the sheet's grid drifted (bottom pair at y 464, not 512), so the boxes are measured. A
rifle diagram in slot 4 was refused by moderation (illicit).

**Verdict:** landed. 0 new programs (the flag's compiles at load); +1 call where boards show.

## Military base: latrine basins and toilets, crate stacks apart, console desks off the wall, bench and desk edges, latrine wall on whole tiles

**Reported:** two armory crates intersecting; bench end faces wanting the uv "rotated 90 degs" and a
side "without hole"; a comms lead through the table ("more space between table and wall?"); an office
desk's top and its edge "should be the same"; `room-hq` "boring and almost the same as briefing"; the
latrine's emitted trough ("add sinks"), its wall "not seamless", its cubicles with no toilets.

**Changed:**
- **Sink and toilet glbs** (`roomkit_build.py`, mil-p's enamel-white and gunmetal, 484 / 584 tris,
  every `check` gate 0): a pedestal basin two to a sink cell (`TILE_MIL_SINKS`, the trough's id) and a
  toilet against the wall in each cubicle. Laid at `SAN_TILE` 1.5 with the grid moved (`laid`) so
  each sits in one cell: cut down its middle, `tile_uv` bookmatched the chips into mirrored pairs.
- **`CRATE_GAP` 0.08 → 0.24**: two 0.03 lid overhangs plus two crates turned 0.06 toward each other
  (2 × 1.13 × 0.06). Footprint test on the live save: 10 of 20 in-cell pairs overlap at 0.08, 0 at 0.24.
- **`CONSOLE_GAP` 0.24**: the lead is `MOUNT_PROUD + CABLE_EPS` (0.13) off the wall, so a flush desk
  top ran through it. `back(..., gap)`, and `powered` takes the same rect.
- **Bench**: end faces axes 8 (the five plank ends across), the grid dropped `BENCH_DROP` 0.3885 so
  the 0.12 sides take rows 240-270 of bench-wood (mid-plank) instead of 79-126, the gap at row 100.
- **Desk top**: every face of the top slab on the top's cell (it was the body's olive on the edges).
- **`military/wall-latrine` crop `[512, 1, 441, 441]`**: six whole 73.5 px grout pitches. The old
  504 quadrant ended mid-pitch, a double-width tile at every repeat.
- **`room-hq`, `desk-run`, `file-run`, `ROLE_HQ` removed**: the HQ's leftover rooms are barracks.

**Trap:** `buildlib.check` caught the wall-plate tap as a floating island and a handle bar 0.01 off
its stem's face; both fixed in the script, not waived.

**Verdict:** landed. Two new batches +2 calls (measured by layer-masking them, 59 → 57), the steel
trough buffer gone -1; 0 new programs (121). 2000 seeds OK.
