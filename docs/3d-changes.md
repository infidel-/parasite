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
