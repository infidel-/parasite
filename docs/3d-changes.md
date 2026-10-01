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
