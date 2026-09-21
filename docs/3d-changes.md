# 3D render changes — running log

Append-only. One entry per experiment, ~25 lines: what changed, the measured numbers, the trap, the
verdict. Settled outcomes only. Every entry needs a matching row in
[`3d-render.md`](3d-render.md)'s verdict table, or it is invisible. Earlier entries are in
`3d-changes-2026-09d.md` and its predecessors.

## The corp street goes AROUND the tower, in downtown's own art (defect pass, phase 1)

Reported: "the street below is generated to overlap with the actual area, so it's right under the
playing field — noone will see it AND it's inside the outer walls", and "let's reuse wall textures
from the actual downtown, it's too jarring to see new art while we're supposedly in the same zone".

Both were one filter. `CorpStreet.build` kept a cell when `cx² + cz² > r²` against `STREET_RADIUS`
160 from the plate centre, and the plate's own footprint is 224 x 180 with a half-diagonal of ~143
— **entirely inside that disc**. Replaced by a RING: the plate bbox grown by one cell is the hole,
the bbox grown by half an area each side is the reach (`CorpStreet.ring`, `PlateBox`).

**AND THE CITY HAD TO BE RECENTRED ON THE PLATE, which cost a build.** The citygen grid is 100 x 100
about the world origin while the plate sits in the −x/−z quadrant (the trap phase 8 of the port
already recorded, from the other end): with the ring cut out of an origin-centred city there was
**20 units of margin on the west and 4 on the north**. `cellX`/`cellZ` now offset every cell by the
plate's own centre, and the crowd's lane finder uses the same three functions so an agent can never
walk where nothing was built.

Art: the four `corp/street-*` labels are **deleted** and `DowntownStyle.get()` is read instead —
`st.asphalt`, `st.walkway`, `st.alley`, `st.walls[b.facade]` at `CELL` for a glass slot and
`WALL_TILE` otherwise, `st.glassPodium` over the bottom two rows, `st.roofBases`. The LIT BAYS use
`Windows.addGlassAccents`' own hash verbatim `(col·92837111)^(row·689287499)^(dir·283923481)^…`
against `glassLitRatio` 0.06, so the street's lit windows and the plate's are one population.
`Windows.addGlassAccents` itself cannot be called: it walks `WorldCtx.buildings`, which corp leaves
empty on purpose so `Occlusion` never runs.

Live census: **2,815 road + 1,137 walkway cells, 74 of 112 generated buildings, 296 wall quads, 829
lit panes**; crowd 64 walkers / 28 cars over 76 walk and 39 road lanes. A/B at a pose leaning over
the parapet: **66 → 47 calls** with the street group hidden (19 of them the street, crowd included),
163,762 → 153,012 tris.

Verdict: **KEEP.**

## The reentrant corner was a 1 x 1 slot 114 UNITS TALL (defect pass, phase 2)

Reported as two probed facade faces with "a hole between them". The probes were the diagnosis:
face #23 stands at x −91 on the −x hand of the cell x −92..−88 / z −180..−176, face #69 at z −175 on
the −z hand of x −96..−92 / z −176..−172 — **diagonal neighbours**, so what is open is the 1 x 1
square at their shared corner, running the whole drop.

`FacilityGeom.parapet` has carried a `notches()` loop for exactly this since it was written; the
drop under it did not. It is not a rare case either: the plate ring is rectangular, but
`ElevatorBlock` stands a 3 x 3 lift car OUTSIDE it, which is four reentrant corners on every floor.
`CorpFacade` re-derives the loop rather than calling `FacilityGeom.notches`, because that one
measures the square off the cell's own `thick()` where the drop forces `PARAPET_INSET` — on a glazed
corner the two halves of the repair would land half a unit apart.

Two more faults in the same 131-line file. The drop ran to y = 0 while the plate's exterior wall is
emitted from `WALL_BASE` −0.2 on the same plane for a SOLID cell: **0.2 of coplanar z-fight all the
way round**, which showed as a flicker on some elevations and not others because a glazed cell's
slab is half a unit further in and hides it. And the soffit was `capDown` over the full cell rect
against cladding a unit inside it — **a lip of ceiling oversailing by 1.0** right where the player
leans over. Fixed by insetting the soffit, and the first fix was WRONG in a way only the frame
showed: insetting by `ring()` insets on the INWARD hand too, opening a unit-wide slot against the
next room. The test is `outward(m, col, row, dir)` per hand.

Art: `corp/facade` is gone; the drop wears `st.walls[3]` (downtown's full-glass slot) with
`CorpStreet.addLit` bays over it, and `FACADE_TILE` went **20.0 → 4.0** — the downtown glass is
cell-locked at `CELL / winPerCell` = 4 units per storey, so at 20 the bays drifted against the
plate's own window grid. Live: **clad 198, soffit 2,180, lit 317**.

Verdict: **KEEP.**

## A window run with no cap is a pane TALLER THAN ITS WALL (defect pass, phase 3)

Reported: "why are windows twice as high as the other walls? they also have holes underneath where
we can see fake street", with a probe at y ≈ 9.59 — on a plate whose storey is `WALL_H` 6.0.

`FacilityGeom.paneTall` is `len · CELL / aspect` and stretches nothing, which is correct; what was
missing is a CAP on `len`. `CorpBuilding.makeWindows` glazes a room wall corner to corner and
`FacilityModel.findWindows` ran the run to the end of the contiguous strip. With
`WINDOW_ASPECT` 512/183 = 2.798:

| `len` | wide | tall | `lo` | pane y |
|---|---|---|---|---|
| 3 | 12 | 4.29 | 0.855 | 0.80 … 5.20 |
| 5 | 20 | 7.15 | **0** | −0.09 … 7.24 |
| 6 | 24 | 8.58 | 0 | −0.11 … 8.69 |
| 13 | 52 | 18.59 | 0 | −0.23 … 18.82 |

**And the hole underneath is the same bug.** With the sill clamped to 0 and the head to `WALL_H`,
both wall faces early out on the `y1 - y0 < 0.01` guard and the sill cap is skipped outright by
`if (lo >= 0.05)` — so the cell is glass from the floor down past it and the street shows through.

Fixed by splitting a run into the units the art EXISTS for: greedy 3s with a 2 taking the remainder,
so a 7 becomes 3+2+2. One loop in `findWindows`, gated on `m.kind == 'corp'` and provably a no-op
otherwise (the compound's runs are already ≤ 3). Live: **102 runs, 71 of len 3 and 31 of len 2**,
every one 4.29 tall with a spandrel over and under it.

Second half: **a washroom is not glazed.** `makeWindows` runs before `CorpBlocks.assign` deals the
room kinds, so it cannot know what a room is. Fixed in `CorpModel.washroomWindows` — demote
`Wall.WINDOW` to `Wall.SOLID` on any cell with an adjacent indoor `Surf.WASHROOM` — which makes it
**retroactive to every save that already exists**, where a generator fix would only reach new ones.
Live: 63 washroom cells, **0** glazed adjacent. Both passes rewrite `m.wall`, so `m.windows` is
cleared and re-derived after them rather than patched.

Verdict: **KEEP.**

## The packed floor sheets WERE the seam, and it was predicted in writing (defect pass, phase 4)

Reported: "floor is not seamless" and "desk-top.png also has seams". Both surfaces tile world-
aligned (`cap` writes `x/t, z/t`; floors at `FLOOR_TILE_SZ` 7.0, desk tops at `DESK_TILE` 4.0), and
eight of the nine corp floors came off two packed 2x2 sheets with the desk faces off a third —
against `docs/3d-textures.md`'s own line: *"wrap error roughly doubles — do NOT pack a texture that
tiles across a whole floor or wall."*

Re-rolled SOLO at `gpt-image-2.5` high, one label per generation, each with its `lift` solved so the
built mean lands where it already was — so the A/B tests the TILING and not the exposure. Wrap edge
error against an interior-neighbour baseline, same script before and after:

| label | packed | solo | baseline |
|---|---|---|---|
| `corp/desk-top` | **35.39** | **3.65** | 1.5 |
| `corp/floor-carpet` | 9.80 | 8.03 | 7.5 |
| `corp/floor-cubicle` | 11.61 | 6.91 | — |
| `corp/floor-meeting` | 11.25 | 7.52 | — |

Ten labels re-rolled plus one new: **`corp/rack-top`**, because the rack's lid wore `RACK_SIDE` —
the one-texture-per-face mistake `docs/3d-geometry.md` opens with, and every cabinet in the room was
wearing its perforated flank across its top. 11 generations, ~$0.58.

Verdict: **KEEP — and the entry that matters is that this was written down before it shipped.**

## Two hand-modelled desks, and the chairs were INSIDE them (defect pass, phase 5)

Reported: "new tables look very boring - it's just a cuboid. can we have more stylish blender
handmade models?" and "new ones spawn right inside the new tables for some reason".

Three Blender builds off `models-src/corp/desk_build.py`, all wearing a new 1024 2x2 `desk-wrap`
(the solo `desk-top` / `desk-front` / `desk-side` plus the chair sheet's anodised band, cropped
square): **`corp/desk-bench` 96 tris** (3.76 x 3.30 x 1.50), **`corp/table-leg` 36 tris**,
**`corp/bin` 140 tris** (a 12-sided lathe). `CorpFurniture.worktop` returns early for OPEN and
CUBICLE and `CorpProps.tables` places one bench per cell instead, yawed off `backHand`.

**`slabTop` had to be keyed on SHAPE and not on the surface, which cost a build.** A boardroom table
is laid as `DARK_TABLE_CARPET_3X3` — a table tile whose FLOOR is carpet — so its cells come back
`Surf.CARPET` and an `s == MEETING` test matched **0 of 245 worktop cells** while 109 were CARPET.
Two-dimensional IS the distinction: a cell with table neighbours in BOTH axes keeps only a
`TABLE_FASCIA` and takes a blade leg under it. That gave 114 legs, thinned to **56** on a
checkerboard.

**The chair.** `CHAIR_OUT` 1.35 is measured from the desk CELL'S CENTRE while the carcass reaches
`CELL/2 − FIT_INSET` = 1.88, so with `CHAIR_W` 1.3 the seat occupied 0.70 … 2.00 — **1.18 of its
1.3 buried in the desk**, and it never reached the seat cell at all. Written as the sum it has to
be, `CELL/2 + CHAIR_W/2 − CHAIR_TUCK`, so it cannot be edited back into a bare number.

Live: 121 desks, 56 legs, 13 bins, 105 chairs.

Verdict: **KEEP.**

## Every corp object was still drawing its 64px 2D sprite (defect pass, phase 6)

Reported: "i see you're re-using old entity art hard (was that fucking ponytail?)", and separately
"all server racks have 2d objects inside for some reason".

`ObjModels.MODELS` has no corp row, so `modelFor` returns null for every corp object and
`Actors.drawActor` paints the atlas billboard at full `Sprites.SIZE` 3.0, upright and at full
chroma. All three suppression hooks are gated on `AREA_FACILITY`. That is ~30 `Const.CORP_*`
families over atlas rows 23-39.

`render/corp/CorpDeco.hx` is the facility's own pattern: `draws(area, o)` joins the `iconOff`
disjunction in `Actors`, and the casework a silenced decoration stood for is emitted **into
`CorpFurniture`'s own buffers** — a cabinet, a fridge, a vending machine and a noticeboard, at
**zero extra draw calls**. Chairs and workstations are now placed AT the old objects' cells, which
is what "put new computers on their places" asks for literally: the generator's own density drives
the plate and the two cannot disagree.

Live: **242 sprites silenced**, 2 cabinets, 1 fridge, 1 board. Carries a `ponytail:` note naming
the three families deliberately silenced with nothing put back (the vending machine's lit front,
the washroom tap, the server machinery).

Verdict: **KEEP.**

## The corp doors: four of their own — AND EVERY LEAF WAS AT THE WORLD ORIGIN (defect pass, phase 7)

Reported as "what's up with doors? we need new ones obviously", which turned out to be two faults
and the second is the one that mattered.

**`CorpArea.tick` never ticked the doors.** `FacilityDoors.pose` writes into the prop's own matrix
array and `Models.cull` is what uploads it to the `InstancedMesh`; corp built the batches and never
called either, so every leaf sat at an identity matrix — **all 30 of them stacked at the world
origin, and a hole at every doorway**. Measured before the fix: `instanceMatrix.array` was 192
floats of identity with `count` 12. One line in `tick`.

**And the art.** `FacilityDoors.TEX` was a hardcoded array of four `textures/facility/door-*.png` —
the last facility texture the tower still wore. Moved onto the model as `ShellTex.door`, indexed by
`FacilityModel.Look`, filled by both styles' `shell()`.

The plan said a packed sheet was **the only route** because a leaf is 2.0 x 4.0, aspect 0.5, under
the ~0.64 floor a 1k generation can produce. That is wrong and worth recording: a door IMAGE is
square, because it holds BOTH leaves — `leafGeom` maps u 0..0.5 onto one leaf and the MIRROR of the
same half onto the other. So the sheet is ordinary economy (four doors for one $0.053 generation)
and it costs nothing, since a leaf maps 0..1 and never tiles.

Four quadrants of one 1024: oak office pair, boardroom glass, solid walnut private, steel service.
Against `corp/wall-office` at 0.219 linear — office **95.8 srgb / 0.63**, steel **93.7 / 0.52**,
private **92.6 / 0.51** after `lift` 0.614 (it dropped at 49.8, a ratio of 0.145, the same "door too
dark against a repainted wall" this file already records for the compound), glass **48.7 / 0.15**,
which is exactly `facility/door-glass`' own ratio and correct for glazing.

**`CorpModel.doorLooks` deals the look off the SURFACE either side**, because `gen.corp` deals only
two door frames (`FRAME_DOOR_CORP` and `FRAME_DOOR_ELEVATOR`) and both fall through `lookOf` to
CABINET — one door for the whole tower. Washroom → PRIVATE, server and lift → METAL, meeting and
exec → GLASS, everything else the office leaf. Derived and not generated, so it is retroactive.
Live: **6 glass / 6 office / 1 steel / 2 private**.

Verdict: **KEEP.**

## A CLUSTER IS NOT A CORRIDOR — the server room behind the toilet (defect pass, phase 8)

Reported: "server room is only accessible through toilet. add sanity check".

Door placement is purely geometric — the four wall midpoints, "is it an inner wall", "fewer than 3
wall neighbours" — and **nothing asks what is on the far side**. `fixDoors` then accepted a CLUSTER:
`if (Lambda.has(c, 0)) continue` is satisfied the moment ANY room in a door-joined group touches a
corridor, so `servers → toilet → corridor` passed.

The repair took four measured attempts and each one is worth the line:

1. **Per-room corridor door** in place of the cluster pass. Necessary, not sufficient: **129 rooms
   in 300 seeds** still owned none, because their walls face the plate's edge and
   `makeDoorToCorridor` has nothing to cut into.
2. **The real invariant, and it is not "every room owns a corridor door"** — a suite whose inner
   office opens off an outer one is a building, not a bug. It is *nothing is reached only by
   walking THROUGH a toilet or the server room*, walked over the DOOR GRAPH from room 0 with a
   dead end entered but never expanded (`GenCheck.corpRoutesSane`). `reachable` cannot say this:
   it floods the tiles and a room behind another room IS reached. **7 of 300 seeds failed.**
3. **Don't repair it — don't DEAL it.** `CorpBuilding.passThrough` marks every room whose removal
   strands another, and `CorpBlocks.demands` hands that to the toilet's and the server room's
   `must`, which `Quota.deal` and `GenCheck.blocksFit` both honour. **3 of 3000 left**: two dead
   ends in PARALLEL, where neither is an articulation point alone.
4. Asking the question of PAIRS instead is far too strong — it rules out a room in any two-room cut
   whatever the other turns out to be, and left **997 of 3000 towers with nowhere to put a server
   room at all**. So the pair is not predicted: `assign` DEALS, walks the routes, and re-deals with
   whatever was in the way added to `blocked`. **3000/3000 green, facility 3000/3000 green, 200
   digests byte-identical twice.**

**The rack in the corner with something under it** is the same tile being three things at once.
`decorateWalls` dresses a room's long walls by writing the ROOM'S OWN unwalkable floor twin — and in
the server room and the cubicle farm that twin is the id `fitOf` reads as a rack and as a spine. The
shape tells them apart: rack rows run `x1+1 … x2-1` while the wall dressing writes at `x1` and `x2`
exactly, so `CorpModel.wallFits` drops a RACK or SPINE fitting standing in its room's edge column.
Done in the renderer, so it reaches saves that already exist. The washroom is left alone — its basin
run IS the `y1` row and passes through the corners, so there the two are not separable by shape.

**Blinking lights and cable, both the compound's own machinery.** `FacilityDeco.lights` grew a
`LedOpts` (it was at ten positional args and the corp art needs five more numbers), and the field is
READ OFF THE ART rather than laid on a grid: `corp/rack-front` holds three cabinets of eight units
and every unit's dots sit at **0.242 / 0.566 / 0.891** of the image width, over a band **0.42 … 3.74**
of a 4.0 cabinet (the art's own frame leaves a margin, and a field over the whole height puts its
first and last row on steel). **480 specks in ONE additive mesh** with the blink folded into the
material and the clock shared by identity — one draw call, no per-frame work but `FacilityDeco.tick`.
Verified blinking by diffing two frames 2 s apart: **5,425 pixels changed**.

Cable is `FacilityCable.strip` on the cabinet LIDS — a raised-access computer room runs its cable
under the floor by definition, so what it shows is the patch bundle over the top. **`sag` had to go**:
the ribbon lies flat so the camera sees its width, and sag is taken out of world DOWN, so on a flat
ribbon it does not hang the run, it sinks its middle into the lid. Three strands per gap at
descending bow. 450 quads, one draw call, `FacilityStyle.CABLE_TEX`.

Draw calls at the pinned pose: **74**, against a budget of 85.

Verdict: **KEEP.**

## A toilet stall with no back and no door (defect pass, phase 9)

Reported: "toilet stall walls aren't up to the wall, have holes. there's no door to the cabin".

Both exact. The panel rect is the fixture cell inset by `FIT_INSET` 0.12, and the masonry face is a
further unit inside the WALL cell — `FacilityGeom.slab` leaves `(CELL − WALL_T)/2` = 1.0 of the wall
cell to each room beside it. Measured live on the plate: fixture cell (18,20) spans z −120 … −116 and
its wall neighbour's slab is z −123 … **−121**, so a panel run to the cell boundary stops **1.12
units — about 56 cm — short of the wall**. And the `alongX != (dir >= 2)` filter emits only the two
dividers: the header said "two dividers and a back" and neither the back nor a leaf existed at all.

`wallFaceAt(m, col, row, dir)` answers where the masonry actually is (the neighbour's slab plane),
the divider rect is widened onto it, the back panel closes that hand and the leaf closes the aisle —
`STALL_DOOR_GAP` 0.6 off the floor, `STALL_DOOR_REVEAL` 0.14 at each jamb, so it reads as a door and
not as a wall. All of it in the existing `STALL_PANEL` buffer: **zero new draw calls.**

`ponytail:` every leaf is shut. One standing ajar wants a box turned off the axes, which is the one
thing `FacilityGeom.face` cannot emit — it would take the door leaves' own instanced batch, and a
row of cubicles reads perfectly well closed.

**OPEN LEAD found while measuring, NOT fixed here: the washroom MIRROR floats 0.94 off the wall.**
It hangs at `plane(slab(fixtureCell), dir, 0.06)`, and `slab` does not inset the hand where the
neighbour carries the wall line — so the quad lands on the CELL BOUNDARY, z −120.06, while the
masonry face measured above is at −121.00. Same arithmetic as the stall's, one `wallFaceAt` call
away; it is out of this pass's scope and is written here so the next one has the number.

Verdict: **KEEP.**

## The street's edge is the CITY's edge, not the reach (second defect pass, phase 1)

Reported: "grow half-tile outside 30%".

**Raising the reach alone does nothing, and measuring that first is what saved the phase.** The
citygen model is `GRID` 100 x `CELL` 4 = **400 units square**; the ring round a 224 x 180 plate at
`STREET_REACH_FRAC` 0.5 already reaches 262 x 210 from the plate centre, i.e. it **overran the model
by 62 units in x and 10 in z** before anything was touched. The loops only visit cells the model
has, so what the player saw stopping was the CITY.

So the model is mirror-tiled. `CorpStreet.fold(i)` folds a world cell index back into the 100 x 100
by REFLECTING at each edge, and the ground loop runs `-GRID … 2*GRID` through it; a building is
emitted once per tile `(tx, tz) ∈ {-1,0,1}²` with its footprint reflected on an odd tile
(`CorpStreet.span`), which is still a rect, so nothing downstream learns it happened.
`CorpCrowd.lanes` folds with the same function.

**MIRRORING AND NOT A MODULO.** A plain wrap butts the model's west edge against its east one and
cuts every road, block and kerb line that does not happen to line up; a reflection matches its
neighbour by construction whatever the pattern. The cost is a far city symmetrical about each seam,
which at 114 units down through fog nothing can read.

**AND 0.65 IS THE FOG WALL, not a taste.** The camera sits ~26 over a plate at y 0 with the street
114 below, so a cell at horizontal distance d is at range `sqrt(d² + 140²)` and `FOG_FAR` 240 puts
it fully in haze at **d = sqrt(240² − 140²) = 195**. On a 75 x 60 area 0.65 gives 195 / 156 —
exactly as far as anything can be seen. Past that the geometry is built into the fog colour.

Census: road **2,815 → 7,979** cells, walkway 1,137 → 2,382, buildings 74 → **215** of 123
generated, lit panes 829 → 2,409; crowd lanes 76/39 → 126/48. Pinned pose `lookFrom(-152, 26, -150,
-172, 0, -172)`: **74 → 76 calls** (two more facade families survive into the frame), 147,164 tris,
seven identical samples.

Verdict: **KEEP.**

## A lane with no lateral term is a head-on collision (second defect pass, phase 2)

Reported: "car yellow ovals need to be replaced. generate car top view + add two yellow dots for
lights in front", and "all cars use left lane and go into one another".

Three separate faults in one 250-line file.

**There was no car art at all.** `CorpCrowd.batch` was a unit plane wearing
`Textures.makeGlowGradient()` — a procedural 64 px radial gradient — tinted `0xffc070 x 1.5`,
additive, and scaled 8 x 3.6. A circle stretched 8:3.6 is an ellipse; that is the whole of the
"yellow oval". Now `corp/traffic.png`, ONE 1k gen holding four top-down cars, cropped per cell at
draw time with a per-instance `instanceUV` vec4 cloned from `render.decals.DecalBatch` — **still one
draw call**, and a fifth car would be a fifth rect and no new material. The material stops being
additive (a picture blended additively over asphalt is a stain) and the headlights are painted the
brightest thing on the sheet so they clear `BLOOM_THRESHOLD` 0.72 on their own.

**Cells are MEASURED, not quadrants**: at alpha > 220, padded 3 px, saloon 174x372, hatchback
171x303, van 180x421, estate 170x365 — aspects 0.468 / 0.564 / 0.428 / 0.466. Each car's world
length is its own pixel height against the family median 368.5 and its width falls out of its own
aspect, so nothing is stretched and the van really is longer. `background:"transparent"` cut it
first time — **78.6% transparent, ZERO opaque pixels in either centre lane** — the reward for saying
the VIEW and never the surface.

**And the collisions were arithmetic.** `back` mirrored only the parameter ALONG the run; `px/pz`
came off the lane centreline unchanged, so both directions were written onto the same line of the
same cell. A road is `ROAD_W` 2 cells and yields two parallel lanes, but a car picked one by an
unbiased hash over the GLOBAL lane list, so the pair was never opposed. Now `Lane` carries `dir` off
its own lateral cell index parity and ONE speed hashed per lane, and a car's phase is quantised to
`max(2, len / 2·CAR_LEN)` slots. Nothing overtakes, nothing starts on top of anything, and the two
cells of a road run opposite ways. Measured over three samples 2 s apart: closest pair **4.72
units**, and it is two cars abreast on the two lanes of one road, 4 units apart across and 2.5 along.

Verdict: **KEEP.**

## A bare box with a lid is not a building seen from above (second defect pass, phase 3)

Reported: "add some decoration on flat roofs" and "can we have simplified parapets?".

The street emitted 4 wall faces (+4 podium) and one roof cap per building and nothing else — its own
header said so. Three pieces now, and the order they are worth anything in is the order of the cost.

**The rim's skins wear the BUILDING'S OWN WALL and only its cap takes the coping label**, which is
what keeps 215 roofs of parapet to ONE new draw call: a face in a buffer that already exists costs
nothing. Four thin rects, each contributing its outer hand, its inner hand and a top cap — taking
the inner skin off the SAME thin rect rather than off an inset one is what gets the winding right
without a second rect and without a flipped face, and the caps are cut so no two are coplanar at a
corner. `render.world.roofs.Parapets` is the other way of doing it: **eight `BoxGeometry` blocks and
up to six texture clones per roof**, affordable 40 times and not 215.

Massing is `FlatRoofs.penthouseRect` verbatim — a pure function of the `Building`, already
deterministic — emitted into the wall and roof-base buffers, so **zero new draw calls**. The plant is
the city's own `RenderConfig.DETAIL_TYPES`, one merged mesh per type; `RoofDetails.addRoofDetails`
itself cannot be called because it walks `WorldCtx.buildings`, which corp leaves empty.

**The coping period had to be re-fitted and the first number was wrong**: tiled at the rim's own
1.0 the art repeated every world unit and the roofline read as a dashed hazard stripe from the
plate. 4.0 — one repeat per city cell, the pitch everything else down there uses.

Census: **43 penthouses, 945 rooftop units** over 215 buildings. Pinned pose 76 → **83 calls**.

**AND THE BUDGET IS WHAT CUT IT TO THREE TYPES.** Six decal types plus the coping took the pose to
85 against a ceiling of 85 once the lift door's own batch landed, so `ROOF_DECO_TYPES` deals 0 / 2 /
5 — the boxy unit, the round vent and the tank, the three that read as a SHAPE at this range. 85 →
**82**. The fallback was named in the plan before the first one was emitted.

Verdict: **KEEP, at half the type list.**

## `isIndoor` is true for a lift car, so the parapet skipped four corners (second defect pass, phase 4)

Reported: four probed faces and three complaints round the lift core — "light lamp mesh is painted
under ai", "center elevator lamp", "coping near the elevator has a hole in them", and a
`wall-office` face that "should be wall-lift".

**The coping hole.** `FacilityGeom.parapet`'s notch loop skips a notch whose diagonal cell
`isIndoor`, and `outward()` refuses to band a hand whose neighbour `isIndoor` — and `Surf.LIFT` 18
sits inside `isIndoor`'s TILE(5)..OPEN(19) range while `ElevatorBlock` stands its 3 x 3 car OUTSIDE
the wall ring on four wall posts of its own. So the ring was never banded on the car-facing hands
and all four of the car's reentrant corners were skipped. One predicate, `roofed()` = indoor and not
LIFT. A/B on the same plate: **204 cells / 1,451 quads → 207 / 1,580**, zero new draw calls. No kind
but the tower deals LIFT, so the compound cannot move.

**The lamp under the actors.** The probed face (no map, uv 0,0/1,0/1,1, y **5.75** = `CEIL_Y` 5.8 −
`PANEL_DROP` 0.05) is `CorpLamps`' recessed ceiling panel, and the whole glow layer was ONE additive
mesh at `Sprites.ORD_FIXTURE` 4.5 — below the actors. That order is right for a FLOOR POOL and
`add()`'s own comment says why: nothing in the sprite pool writes depth, so a pool drawn after the
actors paints through anyone standing in it. **A ceiling panel is the opposite case**, which
`Sprites.hx`'s own header already names (`render.LightCone` sits at `ORD_ACTOR + 1`). The panels get
their own buffer and their own mesh above the actors; the pools stay. **+1 draw call**, and measured
by flipping the order live at a near-top-down pose: **18,019 pixels changed, max delta 213**.

**The lift lamp off-centre.** `corridors()` is row-major greedy and LIFT opts into it, so the panel
landed on the car's lowest-row, lowest-col cell and `near()` (spacing 5) blocked the other eight —
one cell, 4 world units, off the middle of a 3 x 3 car. A named `carLamp` pass deals it on the
centre cell first and pushes it into `seen`; the pool goes over the whole car, one per space.

**The lift-side wall.** `surfOf` mapped the lift DOOR cell to `Surf.CARPET` on the grounds that it is
circulation — but `ShellTex.wallInto` is indexed by the surface a face LOOKS INTO, so every face
looking at it took CorpStyle's catch-all office board. Returns LIFT now: **9 → 10 LIFT cells**, 501 →
500 CARPET, derived at load and so retroactive to every save. The doorway's reveal is still
circulation, which comes from `m.tex.circ` and not from this.

Verdict: **KEEP.**

## A door that slides is a LOOK, not a flag (second defect pass, phase 5)

Reported: "elevator doors are incorrect. need another texture and they should slide into the walls
on open and back on close".

`FacilityDoors.pose` was a pure Y rotation about a constant hinge — `setFromAxisAngle(_up, shut +
swing · open)`, translation never moved — and the lift's leaves came out of `lookOf` as the same
`Look.METAL` steel the server room gets.

`Look` gains **LIFT = 4**, a fifth entry in both shells' `door` arrays (`FacilityStyle` reuses its
existing metal leaf, so the compound cannot move), and `DoorBatch` gains a per-leaf `slide` vector.
**The data decides and `pose` has no branch**: a leaf either turns or slides, so which of `swing` and
`slide` is non-zero is what says which kind of door it is. The travel is `-s · u · LEAF_W` because
leaf 0's jamb is already at `-u · LEAF_W` and it has to go the same way again.

Measured on the live batch: shut jamb origins at x **−64 / −60** about a 4-unit opening centred at
−62, open at **−66 / −58** — 2.0 = `LEAF_W` each, z unchanged, no rotation in either.

Art: `corp/door-lift.png`, solo because the 2x2 door pack was already spent and a sliding pair is a
different drawing anyway — two blank panels on one seam, where a hinged pair shows its stiles and a
lever. **LIFT 0.642, solved against `corp/door-steel`'s own built 0.114 linear** rather than chosen;
the drop came back at 0.0381 / 57.7 srgb, far under the family. `CorpModel.demo` pushes five doors
now so the warm decodes all five sheets. Live distribution 5 glass / 8 office / 2 steel / 1 private /
**1 lift**. **+1 draw call** — a fifth look is a fifth batch.

Verdict: **KEEP.**

## The 2D door icons, and a glint on a plant (second defect pass, phase 6)

Reported: "2d doors need to be hidden" and "remove glisten from corp plant".

`FacilityDoors.draws` was `typeID == AREA_FACILITY && o.type == 'door'`, and its own header explained
the scoping: *"the corporate and underground-lab generators deal objects.Door too and nothing draws
leaves for those"*. That went stale the moment the tower got its four pairs — every corp doorway had
real leaves standing in it AND the old tile image lying across its threshold. One condition:
**17 of 17 corp doors** now answer true. The underground lab still draws none and is still excluded.

**The plant's glisten is not in its art, and measuring first is what found that.** Built albedo p50
**108**, p99 **139**, max **162**, `frac > 184 = 0.0000` — no specular speck anywhere; the MR map is
a rough dielectric (mean 0/253/0, metal max 0) and `Models.toLambert` drops it regardless. The glint
is `render.world.PropEnv`, applied to every corp prop batch — a fake environment plus a `sheen`
specular lobe, and its own header says twice that **it works on Lambert** and is for "the handful of
materials that are supposed to be METAL". A ficus is not one. `FloorProp` gains `env`, declared
false where the prop is declared rather than tested by path, so the next organic prop says so in the
same place. Verified live: the plant's material carries no `propEnv` mark, the printer's still does.

Verdict: **KEEP.**

## The rooms were never a regression, and four things had to move to shrink them (second defect pass, phase 7)

Reported: "something broke in our room generator: 37,12 room is empty, toilets and server rooms are
giant. and all rooms are too large in general".

**Nothing broke.** `CorpBuilding`'s `ROOM_SIZE * 1.5` is copied verbatim from
`game.CorpAreaGenerator:434-436` and has not changed since before the 3D port; the `blocked`/`must`
pair the previous pass added moves the toilet's pick in **1 seed in 300, by 3 cells**. What changed
is that a 110-cell washroom became legible.

Measured at HEAD over 300 seeds / 3,629 rooms: area p10 63, **median 105**, p90 165, **max 384**;
toilet mean 70.3 (a 7 x 10 washroom), servers 82.3, cubicle 165.1; 12.10 rooms a floor. Width
histogram carried a bimodal tail at **20-26 cells, 235 rooms** — that is the LEAK: `subdivideLargeRooms`
stamped the FIRST product of a split `BLDG_ROOM_MARKED` without re-testing it, and only the far half
stayed `BLDG_ROOM` for the scan to find again. Cut once, done, at whatever size one cut left it.

Four changes: `CorpTemp.SUBDIVIDE_OVER = 1.2` (the compound's own constant, same name, same reason);
the split becomes a **cut-until-it-fits loop** re-measuring at (x, y), which stays the room's
top-left because the scan is row-major and `getRoom` never walks back; `SPLIT_MIN` 4 → 6; and the
fixture runs get caps — **3 basins, 3 stalls, 4 rack rows**, centred on their wall instead of
filling it, because `toilet()` ran a counter across the whole top wall and `servers()` a rack row
every 2 cells for the full height, so both scaled linearly with a room nothing said should be big.

After: area p10 42, **median 64**, p90 99, **max 144**, widths 5..12 with the tail **gone (0 over
12)**; toilet 41.4, servers 45.3, cubicle 103.6; **18.53 rooms a floor**. Live on a regenerated
plate: basins 10 → **4**, stalls 5 → 4, racks 33 → 6.

**FOUR ORACLE ROUNDS, and three of them were the deal and not the carve.** (a) 11/3000 "quota short:
room-toilet got 0" — more rooms means longer chains off the corridor, so `deadEnds`' blunt "block
every WC on the floor" could empty the board by the fourth attempt; the loop now adds only what
still leaves two legal homes, and relaxes entirely if it cannot. (b) Narrowing `deadEnds` to the
rooms that individually fail `blocksRoute` went **1 → 30+ failures**: the case it exists for is TWO
dead ends in parallel, where neither alone disconnects anything. (c) `blocksRoute` asked whether
every room in `state.rooms` was still seen, so ONE room the corridor cannot reach over the DOOR
graph — `CorpConnect` guarantees the LIFT reaches every room over TILES, a different graph — made it
true for every roomID: **all 18 rooms of seed 777 blocked**, and the protection turned itself off.
It compares against the baseline reach now. (d) `blocked` was being grown AFTER the deal that
stands, which `GenCheck.blocksFit` then rejects; the additions moved to the top of the next round.
Plus `ROOM_CUBICLE` minW/minH 9x7 → **8x6**, refitted because the carve moved under it — 2/3000 had
no room left that cleared 9x7.

**And the honest consequence, not asked for and not hidden: open plan went 21% → 46% of rooms**
(771/3,629 → 2,560/5,560). The quota's maxes were fitted to a 12-room floor and the filler takes
everything they do not claim. Left alone deliberately — "open plan is the filler" is the design.

3000/3000 corp and 3000/3000 facility green; 200 corp digests identical twice; the facility digest
byte-identical to before the change.

Verdict: **KEEP.**

## No room too narrow or too doored to furnish (second defect pass, phase 8)

Reported: "37,12 room is empty".

Two independent paths, both reproduced before either was touched.

**A narrow open-plan room laid no desks.** `open()` centres a single column at `sx = x1 + w/2 - 1`
and then tests `sx + tableW >= room.x2`, which for `cols == 1` is true at **every width under 7** —
so the loop spun to its `cnt > 100` guard and the room came out bare. 64 of 771 open rooms before
phase 7; far worse after it, because a capped carve mints many more 6-wide rooms (1,250 of 5,560 at
width 6 alone). A centred column is already clear of both edges and does not want the walkway margin
a multi-column run needs, so the test is `sx + tableW - 1 > room.x2` there — and a BREAK, not a
continue, because the width does not change between rows.

**An exec office with a door in both end walls got marble and nothing else.** `hasTable` was set
true whenever the room cleared 6 x 6, whether or not `execDesk` had actually placed anything — and
`execDesk` returns silently when both end walls carry a door, because it only ever put the desk
against one of them. With `hasTable` lying, the `!hasTable` escape to `decorateCorners` was closed,
and at exactly `w == 6` the `w >= 7` arm was closed too.

`execDesk` returns a Bool now; the guard drops to 5 x 5, which is what the demand itself asks for (a
3-wide desk centred in a 5-wide room lands x1+1..x1+3 with a clear column each side); and when both
ends have a door the desk goes **free-standing in the middle of the room**, which is what an
executive's desk is anyway. Nothing about it requires a wall behind it.

Measured with a throwaway trace counting rooms whose tree node ends with no zone: **382 in 600 seeds
before, every one of them an exec office — 0 after.** `nodes/table` 4.34 → **5.00**, i.e. 3 exec +
2 meeting, every exec room laying its desk. 3000/3000 corp and facility green; 200 corp digests
identical twice; facility digest unchanged.

Verdict: **KEEP.**

## The outside and the inside were lit by the same nothing (third defect pass, phase 1)

Reported: "outside lighting is the same as indoor".

`CorpStreet` and `CorpFacade` are `MeshBasicMaterial` — the authored albedo IS the rendered pixel,
so the world outside the glass had no directional term, no lit side and no shade side. The interior
is a lambert flooded by `IndoorMask`. Both landed near full value and read the same.

And the largest surface in the frame **was not even dimmed**: `STREET_DIM 0.62` is applied to the
road and `CAR_DIM 0.78` to the cars, but `CorpFacade`'s material was built with no `color:` field
at all, so the nineteen storeys immediately outside the window rendered at **1.0 albedo, brighter
than the office**.

Three pieces. `CorpStyle.FACADE_DIM 0.74`, fitted between the street's 0.62 and 1.0 because the
facade is nearer. A `CorpStyle.SUN` record and `CorpStreet.shade(b, ndl, mul)`, which pads
`MeshBuf.col` up to `b.pos.length` after each emit: `FacilityGeom.geom` uploads that channel when
the lengths match and `add()` derives `vertexColors` from the same test, so a Lambert term against
the scene's own moon `(-1, 2, 1.5)` costs **no draw call, no material and no signature churn** on
`face`/`cap`, which are already at the arg count the style guide says to convert at. `gain 0.606`
is fitted so a roof lands at exactly 1.0. And `CorpStyle.INDOOR`, a corp preset of
`IndoorMaskOpts` — `CorpArea` and `CorpWarm` were passing `FacilityStyle.INDOOR` verbatim and the
office now reads fluorescent against the street's moonlight instead of sharing the compound's
numbers.

**The first A/B was worthless and is the lesson.** The "before" shot carried the user's probe
overlay and the "after" was the main menu; mean luma "rose" 17.33 → 29.43 and meant nothing. Redone
in place, flipping `vertexColors` and the facade colour on the 23 meshes that carry a `color`
attribute with the camera pinned.

`calls` **81 → 81** at the pinned pose, triangle counts identical.

Verdict: **KEEP.**

## A flat shadow projection is not a shadow, it is a stain (third defect pass, phase 2)

Reported: "no shadows from buildings outside".

The intended build was the obvious one: project each street building's footprint along the moon by
its own height, `offset = h * dir.xz / dir.y`, and mark the ground cells it lands on. Built, and
**it marked 6,021 of 7,115 cells — 85% of the street**. A tower at `STREET_MAX_H 90` throws a
45-cell smear, every building overlaps every neighbour, and the result is a uniformly darker city.

Two screenshots then killed the feature as specified: **from the 20th floor the ground is barely
visible at all.** What the window actually shows is ROOFS. So the shadow is a HORIZON test on a
heightfield, not a projection onto the floor: `heights()` builds the folded height grid once,
`shadowAt(hgt, col, row, y)` walks back along the moon direction and asks whether anything upwind
stands high enough to occlude that point at that height, and `shadowMul` turns the answer into
`1 - v * (1 - SUN.shadow)` with `shadow 0.18`. Roof caps are emitted per cell instead of one cap
per building so a roof can be half in shade.

Same `col` channel phase 1 opened, so **zero draw calls and zero per-frame work** — the sun does
not move in this area and the buildings are boxes on a grid, so the whole thing is static. Cost is
one array at build.

`CorpStreet`'s "what is deliberately not down there" paragraph still says *no roof shadows*: that
is the parapet contact shadow and a different thing.

`__corp().street` gained a `shadow` count. `calls` unchanged.

Verdict: **KEEP — but as a horizon test. The projection it was specified as is a stain.**

## A fragment shader cannot blur what is behind it, and a mip bias barely can (third defect pass, phase 3)

Reported: "plus some kind of blur layer so that it does not look too samey", and asked directly:
*"can we put a large quad with a fragment shader on it?"*

**No — not for a blur, and the reason is worth keeping.** A fragment shader can only read what is
bound to it, and the frame is not a texture until something copies it, which is a pass by
definition. A world-space quad hung outside the parapet can only ADD haze, and `scene.fog` (linear,
`90 … 240`, `SKY 0x0a0e16`) already does that per-fragment for free.

So: a distance-driven texture LOD bias folded into the street and facade materials by
`onBeforeCompile`, `<map_fragment>` replaced (not edited — the chunk is not resolved yet at that
point) with `texture2D(map, vMapUv, smoothstep(BLUR.near, BLUR.far, vStreetDist) * BLUR.max)`. Own
`customProgramCacheKey` per material or three materials share one patched program.

**THE WHOLE STREET WENT BLACK, and the diagnosis route is the entry.**
`renderer.info.programs.filter(p => p.diagnostics)[0].diagnostics.fragmentShader.log` said
`ERROR: 0:345: 'smoothstep' : no matching overloaded function found`. Haxe prints `110.0` as
`"110"`, GLSL read `smoothstep(int, int, float)`, and the material compiled to black. A `glsl()`
literal formatter fixes it and anything else that interpolates a Float into a shader needs one.

**And then the honest measurement: the bias does almost nothing at this range.** Bias 2.5 moved
far-roof high-frequency energy **6.109 → 6.060, −1%**. Forced to 8 everywhere it moved a NEAR roof
deck's interior 3.401 → 2.332, −31% — i.e. it works, on things close enough to have texels left.
At 110-230 units the mips are already exhausted.

What actually answered "samey" is `CorpStyle.TILE_VARY 0.3`: the city is mirror-tiled 3 x 3, so
what repeats is the same skyline four times, and breaking the mirror breaks the read. The bias
stays because it is free.

Verdict: **KEEP both; the bias is nearly worthless alone and the mirror break is the fix.**

## "ai art" NEVER MEANT GENERATED ART (third defect pass, phase 4)

Reported, for the third time and angrily: "i fucking told you twice already to use ai icon art for
fake ai, again you defy me."

**The misreading is the entry.** In this project `AI` is the NPC class — `src/ai/AI.hx`,
`AI.hx:219` *"select AI icon data before entity creation"*, `Images.getRandomCivilianAI`. The 2D
corp view drew its background crowd from those very sheets: `AreaView.paintFakeHost`, commit
`ab37666`, `ix: Std.random(10), iy: Std.random(isMale ? 8 : 6)` off `images.male`/`images.female` at
`globalAlpha 0.5`. `CorpCrowd.hx:36-40` still described itself as *"the direct 3D successor to the
2D `_FakeHost` / `paintFakeHost` code"*, and `CorpCrowd.hx:61-64` carried a `ponytail:` note naming
the exact fix before this pass began. So "replace white dots with random ai art" meant **draw the
fake crowd from the civilian icon atlas**, and "Cars only" on the earlier generate-or-not question
was correct and complete. Reading it as withdrawing the pedestrians was the error, and no image was
generated in this pass.

The walkers stop being `Textures.makeGlowGradient()` quads laid flat and become upright civilian
icons leaned back by `Sprites.TILT` (0.6 rad), which is both "random ai art" and "slanted so we can
see it better". `Images.male` and `female` are both 640 x 1024 (10 x 16 cells of
`Const.TILE_SIZE_CLEAN` 64), drawn into ONE canvas at build, so both sexes ride **one instanced
batch**. The cell is dealt from `Images.civiliansMale` (74) / `civiliansFemale` (60) — the same
tables `AI.createIcon` uses, so a walker is literally a random civilian. The per-instance
`instanceUV` vec4 and the `<uv_vertex>` rewrite were already there for the cars. `WALK_H 3.2`, and
the quad centre lifts by `h2*cos(TILT)` and back by `h2*sin(TILT)` so the drawn feet land on
`CROWD_Y`. The material stops being additive: `alphaTest`, `WALK_DIM 0.92`.

`calls` unchanged — one batch in, one batch out.

Verdict: **KEEP.**

## A BOUNDING BOX IS NOT A SILHOUETTE (third defect pass, phase 5)

Reported: "28,43 — when the elevator is on the south side we can clearly see blackness instead of
the city streets adjacent to our building".

`plateBox()` keyed the street's hole to `model.structures[0]`'s **rect**, and that rect comes from
`FacilityModel.findStructures`, a flood fill — which swallows the lift car, because `Surf.LIFT` is
inside `isIndoor`'s range and the car is 4-connected to the plate through its door. `ElevatorBlock`
stands that car OUTSIDE the wall ring, so the bbox grows 4 cells across the WHOLE of whichever wall
the lift landed on. Measured on a 75 x 60 area: the empty band is **4 units west, 4 east, 6 north
and 22 on the lift side**, running the full 224-unit width. What shows through is `CorpStyle.SKY` —
there is no backdrop under the city.

`PlateBox` gained a `covers(x0, x1, z0, z1)` closure, set in `plateBox()` over the model, mapping a
street cell's world rect to plate cells and asking the same pair `CorpFacade` asks —
`FacilityModel.isIndoor(m, c, r) || FacilityGeom.carries(m, c, r)`. That is the tower's REAL
silhouette, so the lift core keeps its own hole wherever the generator put it and the reentrant
corners resolve. A closure on the typedef rather than handing `CorpStreet` the whole `Facility`:
the street builder deliberately knows nothing about the plate beyond its box.

The uniform `- CELL` margin drops to `CELL * 0.25` — it exists so a ground quad does not z-fight
the facade's drop, the drop is a vertical plane, and a quarter cell clears it.

`CorpCrowd.lanes` reads the same `ring()`, so walkers and cars fill the recovered band for free.

Verdict: **KEEP.**

## One wrong tile id gave a boardroom two walls, two floors and a repainted table (third defect pass, phase 6)

Reported as two separate defects: "meeting rooms have two wall textures" with two probes 4 world
units apart (`wall-office.png` / `wall-meeting.png`), and "two floor textures" with two probes at
`y 0.04`.

`CorpRooms.hx:284` handed `decorateWalls` a `bigFloorID` of `TILE_FLOOR_CARPET + 16` where every
sibling template hands **its own floor's unwalkable twin** (exec MARBLE1, kitchen WOOD1, cubicle
CUBICLE, servers SERVER, toilet MARBLE2, open WOOD2). `meeting` was the only one wrong, and that one
id produced four faults that looked unrelated:

- `decorateWalls` stamps it on alternating cells of the room's `x1`/`x2` columns, `CorpModel.surfOf`
  reads them back as `Surf.CARPET`, and `wallInto[CARPET]` is the catch-all `WALL_OFFICE` — so the
  wall run alternated. **The two probed faces are one `CityConfig.CELL` apart: adjacent cells of
  one run**, which is the mechanism exactly.
- `FacilityModel.themeRooms` takes the LAST themed cell in row-major order — the `(x2,y2)` corner —
  and `decorateWalls` always dresses a corner, so at `smallChance 20` that corner carried the bad id
  **80% of the time** and the whole boardroom table slab finalised as CARPET.
- `CorpLamps.corridors()` is gated on `Surf.CARPET`, so it believed those cells were circulation,
  hung a ceiling panel over them and stamped a FULL-CELL light pool on them, overlapping the room's
  own `POOL_INSET 1.6` pool additively. **That is the "two floor textures":** both probes sit at
  `GLOW_Y 0.04` with uv `0,0/1,0/1,1` = `CorpLamps.quad`'s literal, one material, no map. Nothing at
  y 0.04 is a floor at all.

The fix is one id. Verified with 0 stray carpet cells inside boardrooms across the oracle, and the
other five templates audited against their own twins in the same pass.

Verdict: **KEEP — and the lesson is that four unrelated-looking symptoms can be one argument.**
