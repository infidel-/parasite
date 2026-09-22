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

> SUPERSEDED by The outside had a real moon in the scene all along and opted out of it (fourth
> defect pass, phase 1) — the heightfield march and its `col` channel are deleted.

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

> SUPERSEDED by A blur needs a pass, and the composer was already there (fourth defect pass,
> phase 2) — the bias is deleted. `TILE_VARY 0.3` and the `glsl()` formatter stand.

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

## The outside had a real moon in the scene all along and opted out of it (fourth defect pass, phase 1)

Reported: "omg, building shadows are shit, do a normal shadowing thing", "fake street ai looks too
bright", "can you reduce overall fake street lighting?".

`renderer.shadowMap.enabled` has been true since `SceneSetup.hx:66` and the corp rig has carried a
casting `DirectionalLight(0x8294c0, 1.6)` the whole time. Every street and facade mesh set
`castShadow = false; receiveShadow = false` and was `MeshBasicMaterial`, which ignores lights
outright — so the previous pass wrote a 300 x 300 heightfield horizon march to fake what the scene
already had. All of it comes out: `heights`, `shadowAt`, `shadowMul`, `shade`, `ndl`, `ndlDir`,
`CorpStyle.SUN`, fifteen call sites and the `col` channel they fed.

**The plan's layer split was impossible and the reason is worth keeping.** three tests a light's
layers against the CAMERA's in `WebGLRenderer.projectObject`, at the point it COLLECTS lights — so
a light is in the whole render or out of it, and `render/world/IndoorMask.hx`'s header already
carries that obituary. What removes the conflict with the office moon's player-following 90-unit
box instead is the shadow camera's NEAR PLANE: `near = distance + STREET_Y / dir.y + clear` clips
the tower out of the street light's depth pass geometrically. `STREET_SUN` is its own
`DirectionalLight`, `halfExtent 250`, `mapSize 2048` = **0.24 world units per texel**, centred on
the plate and frozen — `autoUpdate = false` after one render, so zero per-frame shadow cost.

**Freezing it cost two failed attempts and one control test.** `settle()` drops every caster once
the map is rendered; keyed on a tick counter it ran too early at 2 and still too early at 90, which
proved it was not timing at all. three allocates the render target INSIDE the shadow pass and
AFTER its own `autoUpdate === false && needsUpdate === false` early-out, so **`sun.shadow.map != null`
is the proof the pass ran** and is the condition. A 4% pixel diff against a re-render then looked
like an incomplete map and was not — the re-render re-enabled the 15 street meshes and not the
FACADE casters, so the diff was the tower's own shadow; an 80 x 80 slab dropped in with
`castShadow` on changed 0.95% of the frame.

Draw calls went **82 → 96** the moment the street cast: the office moon's box reaches 353 units of
light travel and the street sits at 353, so every merged street mesh entered the office depth pass
every frame. Tightening `MOON_SHADOW.far` culls nothing (a city-wide merged mesh has a huge
bounding sphere). The caster register plus `settle()` is what fixes it — **79 calls** at the pinned
pose against an 82 baseline.

Dims refitted under real light, by sampling and not by eye: `STREET_DIM` 0.62 → **0.45**,
`FACADE_DIM` 0.74 → **0.62**, `CAR_DIM` 0.78 → **0.60**, `WALK_DIM` 0.92 → **0.55**. The walkers
were the brightest thing outside and are what "too bright" named.

Verdict: **KEEP. Check what the scene already has before building a substitute for it.**

## A blur needs a pass, and the composer was already there (fourth defect pass, phase 2)

Reported: "screw the mip thing, want a simple quad with blur shader or something".

The previous pass argued that a fragment shader cannot blur what is behind it — true, and it then
settled for a distance-driven mip bias that measured **−1%**. Both halves were wrong about the
cost: `EffectComposer` is already in the frame (`RenderPass → GTAOPass → Shockwave →
UnrealBloomPass → OutputPass`, one `composer.render()` per frame) and `Shockwave` is a hand-written
`ShaderPass` in this repo to copy from. A blur was one pass away the whole time.

`render/StreetBlur.hx` is that pass, inserted after the render and before bloom so the softened
city does not get sharp bloom re-added on top of it. `RADIUS_PX 5.0`, a 12-tap two-ring kernel, and
**the mask rides the alpha channel**: `CorpStreet.blur` keeps its name and its `onBeforeCompile`
but now writes `gl_FragColor.a = 1.0 - smoothstep(BLUR.near, BLUR.far, -mvPosition.z)` after
`<dithering_fragment>`, so far street fragments arrive with low alpha and the pass reads
`m = 1.0 - c.a`. No depth texture, no camera near/far linearisation, no second binding — and each
tap is weighted by its OWN alpha, so the near city does not bleed into the far one. Early-out at
`m <= 0.002` leaves the office and the near street untouched by construction.

`BLUR` loses its `max` field and keeps `{ near: 110.0, far: 230.0 }`.

Measured on far-region high-frequency energy, the same statistic that convicted the bias:
**−15.8%** against the bias's −1%. `calls` +1 (the fullscreen quad), and the pinned pose lands at
79-81 against an 85 budget.

Verdict: **KEEP — and the mip bias is deleted, not kept alongside.**

## A strip texture has an axis, and a glazed slab opens a ledge under every window run (fourth defect pass, phase 3)

Reported: "coping u,v should be turned 90", with probes; and "still a hole for polygon (no quad at
all) 90 deg to these ones near window", with two more.

**The coping.** `FacilityGeom.cap` hard-wires `u = x/t, v = z/t`, and `art/textures.json` calls
`city/coping` a "straight-on strip … seamless horizontal tile" — a directional texture. On the two
z-running parapet hands the probes read **Δu 0.15 against Δv 8.7**: the strip ran across the 0.6
width instead of along the rim. `cap` gains an optional `swap` flag emitting `u = z/t, v = x/t`,
and `CorpStreet.roof` passes `i >= 2`. One new argument with a false default, so every other caller
is untouched.

**The hole.** Both probed faces are correct and present. A glazed cell's slab insets 1.5 where a
solid one insets 1.0, so the wall above steps **0.5** in from the `PARAPET_INSET` ring plane — and
nothing capped the horizontal slot that step opens at `y = WALL_BASE`, running the whole length of
every window run. Corp runs no `FacilityGround` pass, so there was no surface out there at all.
`FacilityGeom.band` already solves the identical step at the parapet with a soffit capDown;
`CorpFacade.drop` takes the same cap, per direction, inside the loop that already knows both rects.

**And the same four lines fixed a second thing visible from the same spot.** `FacilityGeom`'s
window pass asserts that "two runs can never abut and the cell past each end is never glazing",
which `FacilityModel` makes false on corp — it splits a corp run into abutting 2/3-cell sub-runs.
So `jamb` fired mid-glazing and stood two coplanar inward-facing `cap-alu` quads where there is no
masonry. `jamb` gains `loEnd`/`hiEnd`, and the caller asks the real question: is the cell past this
end actually a WINDOW.

`calls` unchanged — one extra quad per glazed run, merged into a buffer that already exists.

Verdict: **KEEP. A tiling strip has an axis and `cap` had no way to say so.**

## `dir ^ 1` skipped the face you look at, and the tactical lattice hatched the void (fourth defect pass, phase 4)

Reported: "desk missing polygons" with a probe, and "do not paint giant 'unwalkable' hashing over
outside street".

**The box.** `CorpDeco.box` skipped face `dir ^ 1`. `dir` points TOWARD the masonry and the box
grows away from it, so `dir ^ 1` is the EXPOSED front and `dir` is the buried back — every casework
piece in the tower (cabinet, fridge, vending machine) was missing the one face the player looks at,
and `isEnd = (f != dir)` then painted the drawer-course `desk-front.png` on the buried one.
`CorpDeco.board` five lines below and `FacilityDetail.halo` both already had it the right way
round. The fix is two characters plus the `isEnd` term, and the value of the entry is that a
bounding box cannot tell you which way it is facing — only the code that chose `dir` can.

**The hatch.** `TacticalGrid` is shipped-on and its only exclusion was `isCity() && TILE_BUILDING`.
A corp area is not a city and its void is `TILE_ALLEY_UNWALKABLE`, so every cell outside the plate
out to the 16-cell radius took the dashed perimeter and seven diagonal stripes, at `y = 0.06` and
114 units above the street — painted on the sky. The exclusion now covers the three outdoor void
ids (alley / road / walkway unwalkable), which is general rather than corp-special: an interior
wall, a desk and a rack are all still hatched.

Verdict: **KEEP both.**

## A corp partition is a stud wall, and its doorway is an opening and not a tunnel (fourth defect pass, phase 5)

Reported: "door frame walls are too large", with a probe reading a jamb 2.0 deep and 4.2 tall.

The depth is `FacilityStyle.WALL_T = CityConfig.CELL * 0.5` — the compound's masonry thickness,
reused verbatim by the tower. Nothing narrows the door: the opening is already the full 4.0 cell
and the leaves already fill it. What reads as "too large" is a **1-real-metre reveal on each
side**, which is right for a bunker and wrong for an office partition.

Corp takes its own interior thickness. The value rides the shell descriptor `CorpStyle.shell()`
already passes — `wallIn` on `ShellOpts` and on `Facility`, defaulting to `FacilityStyle.WALL_T`,
so the compound is untouched BY CONSTRUCTION and not by a matched pair of numbers. `CorpStyle`
passes **1.2**.

**And it is the INTERIOR only, which is the whole of the work.** `FacilityGeom.thick` stops being
`inline` and splits: a glazed cell keeps `GLASS_T`, an exterior wall keeps `WALL_T`, and only a
cell whose four neighbours are all indoor-or-carrying takes `wallIn`. That test (`inner`) is what
keeps the curtain wall, the window runs and the parapet on their own numbers — they key off
`GLASS_T` and the outer ring, neither of which moved.

This is the one phase of the pass that edits shared geometry, so the facility digest was the gate
and not a nicety: `git show HEAD:src/tiles/Default.hx` swapped in, gen rebuilt, digest taken,
file restored — **`3854efd064d2cf018536c8a884dfdaf8` both sides**, identical. Facility oracle green
at 3,000 seeds.

Verdict: **KEEP. A shared constant with two callers wanting different values is a field on the
descriptor, not a second constant.**

## Every exec and reception desk in the tower drew nothing at all (fourth defect pass, phase 6)

Reported: "remaining quad based desks still look like shit", with two probes.

**The biggest single defect of the pass was found while implementing it and is not what was
reported.** `Const.isCorpTableTile` covers tileset rows 8-11 only. `DARK_TABLE_MARBLE1_3X2` — the
executive's and the reception's desk — is on rows **14 and 16**, so it failed the test that decides
whether a cell is a worktop: `isCorpTableTile(224) = false`, `surfOf(224) = Surf.TILE`. Every exec
and reception desk in the tower emitted **no geometry at all** while still writing six unwalkable
cells. `Const.isCorpDeskBlock` is the missing predicate and `CorpStyle.shell`'s `tableOf` is now
the OR of the two.

**The modular END + MIDDLE glb pair asked for was deliberately not built, and the reason is in the
repo.** `models-src/corp/desk_build.py`'s own header records it: `render.Models.instanced` scales
by HEIGHT ALONE, so a per-cell module would cut a 6 m boardroom table into six 2 m desks. No new
art was generated in this phase and no new glb shipped.

What the complaint actually was, once measured, is four things in the branch being rewritten:
the **`MEETING` branch is dead** (a boardroom table is laid as `DARK_TABLE_CARPET_3X3`, whose floor
is carpet — 0 of 245 worktop cells on a plate come back `Surf.MEETING` and 109 come back `CARPET`,
so every boardroom table fell to `default:` and wore the desk laminate); **`slabTop` required both
axes**, so a 1-deep table run was a solid cuboid to the floor instead of a top on a fascia; the
lone 1 x 1 worktop was a closed box; and the **interior-face cull tested `m.table`** rather than
"does the neighbour emit anything at the same height and base", so a worktop abutting a glb-desk
cell dropped the face toward an empty cell and opened the box. `meets()` asks the real question and
takes `h` and `y0` with it.

Verdict: **KEEP — and the glb pair is REJECTED on `Models.instanced`'s height-only scale, which is
the same reason the bench went to a glb in the first place.**

## The glow was already in the tree and nothing referenced it (fifth defect pass, phase 1)

Reported: "cars became way too dark - we want glow from car lights", and then, asked how: *"before
we had car/citizen art, there were white/yellow glows, idk what they were... we can probably use
these, put two on top of the car front"*. They are still there. `render.Textures.makeGlowGradient`
is a 64 px centred radial white→grey→black falloff, written for the first 3D pass's crowd and
**referenced by nothing at all** since the civilian sheets replaced it.

**The multiplier was not what fixed "too dark", and the measurement says so.** Under the street's
own moon the car body reads **0.0027 linear** against a road at 0.0010 and a walker at 0.1109.
`CAR_DIM` went 0.60 → 0.85 (+42%), and that is as far as it is worth going: the art is a matte
unlit car panel at night, so reaching the icons would need ~40x and would arrive as grey mush.
What makes a car read as traffic is the pair of lamps at its nose — and `art/textures.json`'s own
prompt for `corp/traffic` painted them *"clearly the brightest thing on the whole image"* two
passes ago.

One extra instanced batch, `CorpStyle.CARS * 2` glow quads laid flat on the road, additive, driven
from the same closed form the cars are. **+1 draw call exactly, A/B/A/B at the pinned pose: 84 off
/ 85 on, three times identical.**

And a trap worth the entry on its own: the first build measured **+2**. A `transparent` material
with `side: DoubleSide` is rendered by three in TWO passes — back faces, then front — unless
`forceSinglePass` is set. `render.decals.DecalBatch` already carries that flag and records 513 →
458 calls citywide for it. Here the quad lies face-up under a camera that never goes below the
street, so `FrontSide` is the answer and the flag is not needed.

Verdict: **KEEP. Before generating art for a defect, grep the tree for what the last pass deleted
the CALLER of and not the code.**

## A ficus lit like a lamp (fifth defect pass, phase 2)

Reported: "plant needs to be darker".

`corp/plant` carried `lift: 0.83` and no `baseColor`, fitted when the bake's own self-occlusion
between forty leaves took it to 58.7 srgb. Measured on the BUILT glb now: sampled albedo
**82/111/26, luma 99 srgb** — above `corp/cooler`'s 92 and well above the indoor ~78 band. The
gamma had overshot.

The lift STAYS — it is what keeps the leaf occlusion off the floor — and a flat linear
`baseColor` 0.64 takes the whole thing down with it: **99 → 79.8 srgb**, chroma 70.8 held (a flat
scalar cannot move hue, which is the entire reason it is not per-channel). `propstat`'s own
suggestion of 0.42 is fitted to the OUTDOOR 46-52 family and is a different room.

Verdict: **KEEP — a gamma says how the darks sit, a flat scalar says how bright the thing is, and
a prop that is wrong on both wants both.**

## A closed-form crowd blinks at the modulo (fifth defect pass, phase 3)

Reported: "citizens outside should not blink in/out of existence. do a gradual fall in/fall out,
plus when a citizen appears, it should have random art."

`CorpCrowd` stores nothing: an agent's position is `(phase * len + clock * v) % len`. **The modulo
IS the blink** — the wrap teleports a walker from one end of its lane to the other in one frame —
and because the icon was hashed off the index alone it teleported wearing the same face.

Both halves cost one extra term. Take `raw` once, and `lap = Std.int(raw / len)` is which time
round this is while `raw % len` is where: still closed form in `t`, still nothing stored, still
exact after any pause. The icon re-rolls on `h ^ lap * 374761393`, so the lane, the direction and
the speed stay the walker's for ever and only the civilian changes — measured live, 3+ of the 64
walkers change icon in any 1.1 s.

The fade is `render.decals.DecalBatch`'s `instanceAlpha`, cloned the way `instanceUV` already was,
and the anchor matters: `gl_FragColor.a *= vCrowdFade` after `<opaque_fragment>` is AFTER
alphaTest, so the cut-out silhouette stays exactly as crisp at 5% opacity as at 100%. Live buffer:
18 of 64 walkers and 4 of 28 cars mid-fade, min 0.01. The cars take the same two lines because
they wrap on the same modulo, and the headlights dim with their car through `instanceColor` —
allocated at build time on purpose, since `instanceColor` existing is what compiles
`USE_INSTANCING_COLOR` and a warm scene that never dimmed anything would cache a different program.

**Zero draw calls**, once `forceSinglePass` went on both batches with the transparency: without it
the two-pass DoubleSide split measured 85 → 87.

Verdict: **KEEP. A closed-form agent can be given a lifecycle without being given state — the lap
index is free and it is the hook everything else hangs off.**

## Every mesh has a name, and a sliding leaf clears the reveal (fifth defect pass, phase 4)

Reported: "front of the elevator door has some unnamed meshes... firstly there should be zero
unnamed meshes, secondly remove them", and "z-fighting when elevator door is open. let the door
stick out a little".

**Both were identified from the probe text alone, before any code was read.** The unnamed thing is
`CorpLamps.calls`: two additive quads at `CALL_Y 3.0` ± `CALL_H/2 0.4` standing `SIGN_PROUD` in
front of the lift door, in a mesh whose material has an `alphaMap` and no `map` — which is exactly
`base: (no map)` — and the triangle centroid of a 2.6..3.4 quad is **2.867**, the probe's y to
three places. Deleted with its constants and its `ratio()` helper.

The z-fight's partner is the doorway REVEAL: `uv v -0.033..0.667` against `WALL_TILE 6.0` is
y **-0.2..4.0**, i.e. `WALL_BASE` to `DOOR_H`, and `du 0.2` is **1.2** wide — the corp `wallIn`.
A lift leaf slides exactly one `LEAF_W`, which parks its hinge-edge quad (0.16 x 4.2) in the cell
boundary plane the reveal is emitted in. `DOOR_SLIDE_CLEAR` 0.2 sends it that much further into
the pocket, where it is buried in masonry at least 1.0 thick: verified live, the two open leaves
sit at z **-110.20 / -101.80** against boundaries at -108 / -104.

The naming sweep is ~15 edits, most of them one line inside a shared helper (`FacilityGeom.add` /
`addFloor` / `addPane` / `addDeck` take the texture path, `Models.instanced` the model path,
`FacilityDoors.batch` its look), so other area kinds get names wherever they share one. Counted off
the live scene: **115 meshes, 0 unnamed.** The last three took finding — a `FacilityDetail` contact
shadow (black, opacity 0.5, a 4x64 alpha ramp), a `FacilityDeco` LED glow and an empty `Ribbon`.

Verdict: **KEEP. A probe that cannot name what it hit costs more than the one line per mesh that
fixes it.**

## One predicate in two files, and the copy did not follow (fifth defect pass, phase 5)

Reported: "elevator walls dont merge with static ones", with three probed faces — all of them
coping tops, `ROOF_Y 6.0 + PARAPET_H 1.10 + COPING_H 0.25 = 7.35`.

`CorpFacade` hangs the tower's 114-unit cladding drop off the same perimeter `FacilityGeom.parapet`
bands, and its own comment said it re-derived `outward`'s three lines *"cheaper than widening that
file's surface"*. Then a `roofed` was grown in `FacilityGeom` — indoor AND not a `Surf.LIFT` car —
and the copy did not follow. Round the lift core the two then disagreed in both directions at once:
a parapet and a coping ran across the tower's car-facing hand with no cladding under them, and the
facade skipped exactly the reentrant corners the parapet emitted.

**The exception itself is what the complaint is.** Banding the tower's wall behind the car is the
tower drawing a roofline between itself and the lift, which is precisely "the elevator's walls do
not merge with the static ones". A lift car is part of the building: `roofed` goes back to plain
`isIndoor`, the two files share one public `outward`, and the ring turns round the car's flanks
instead of cutting behind it — the corner squares that turn leaves are the `notches()` loop's,
which has handled a reentrant corner since it was written.

Measured on one plate: `paraCells` **175 → 172** (the three car-facing wall cells stop banding),
`paraQuads` **1341 → 1212**. The facade is byte-identical by construction — it was already using
`isIndoor`, so what moved is the shell, not the drop. Calls unchanged at the pinned pose. The
compound cannot be touched: no kind but the tower deals `Surf.LIFT`.

Verdict: **KEEP. This is the third time a re-derived `outward` has cost this port something. A
predicate with two callers is public or it is a bug waiting for the next edit.**

## A pane grows at both ends, so a split run grows into itself (fifth defect pass, phase 6)

Reported: two overlapping window faces, and separately "window and door cannot be directly
adjacent. and we cannot have a half-wall sized window too".

**The z-fight is arithmetic and the two probes are enough to close it.** `WINDOW_OVERLAP` 0.025
grows every pane by `wide * 0.025 / 2` at BOTH ends so alphaTest eating the art's outermost texel
row cannot open a slit against the masonry. On corp there IS no masonry at an internal split: the
3-bay on x **-160.0..-148.0** draws **-160.15..-147.85** and the 2-bay abutting it on
**-148.0..-140.0** draws **-148.10..-139.90** — **0.25 units of coplanar glass**, in two different
meshes, since `panes` and `panes2` are one material each. The end test the jambs already computed
says which ends are seams; hoisted, it holds the growth to zero there and the two meet edge to
edge where the art's own mullion is. The compound is unaffected by construction — it never splits
a run, so no end of one ever abuts another.

The other two are one pass each in `CorpModel`, beside `washroomWindows` and for its stated reason
— the shell is derived from the saved grid every load, so a correction here reaches every corp save
that exists where a generator change reaches none of them. `CorpBuilding.makeWindows` deliberately
glazes the cell before a doorway (`windowTiles[2]`, the closing frame), so `doorWindows` demotes
any pane with a door next to it ALONG THE WALL LINE; and `runsOfThree` trims a maximal run to
`floor(len / 3) * 3`, centred, so the splitter only ever sees a multiple of three.

Measured on one plate: **204 glazed cells → 165**, **78 runs → 55**, and **len-2 runs 30 → 0** —
so `pane2` and the `panes2` buffer go unused on a tower (they stay for the compound and the warm),
which is also worth **-1 draw call**: an empty buffer emits no mesh. Panes adjacent to a doorway:
**0**. 21 abutting run pairs on the plate, every one of them now a clean joint.

Verdict: **KEEP. An epsilon that exists to hide a seam against masonry has to ask whether there is
masonry.**

## Propaganda on the walls, and a boardroom with something to point at (fifth defect pass, phase 7)

Reported: "let's add more wall decals - corpo style propaganda" and "add more decoration to meeting
room - charts, projector screen on the wall". Asked which art route, the answer was ONE PACKED
SHEET, and "vaguely threatening propaganda btw".

One 1k gen, **$0.055**: `corp/posters`, four panels in a 2x2 — an eye in a ring, a rank of
silhouettes marching in step with one amber straggler, a falling performance chart, and a
pulled-down projector screen. A SECOND sheet rather than a re-roll of `corp/signs`, because those
four are already fitted and cropped and a second atlas costs exactly one draw call — **A/B/A/B at
the pinned pose, 83 off / 84 on**.

Same shape as `corp/signs` and the same trap — each quadrant is the PANEL and not the wall around
it — so each panel was cropped to its measured bbox and pasted back filling its quadrant, its own
aspect travelling with it into `CorpSigns.ASPECT` (**0.5952 / 1.7437 / 1.3905 / 1.4263**, eight
entries now). Two things that crop taught, both measured off this drop and both general:

- **the model does not honour the stated 2x2 split.** The landscape poster's frame starts at
  x **501** where the centre line is 512, so a quadrant crop cut its neighbour in half. The seams
  were found as the widest EMPTY column run in each band — row seam at **537**, top band's column
  seam at **434**, bottom band's at **496** — and not assumed at half.
- **the wall's own film grain defeats a plain threshold.** A column counts as content only at 12+
  marked pixels; without that, cell 0's bbox ran to the quadrant edge on grain alone.

`CorpSigns` then grows from four slots to eight, one panel per `SIGN_SPACING` 6 cells of a run
rather than exactly one at its middle, and the boardroom gets the one room-level rule in the file:
**one projector screen per room** on a wall long enough to hang it (`SCREEN_MAX` 3.0, which at the
art's aspect stands 3.55..5.65 and clears `CEIL_Y`), charts on whatever is left. Live on one plate:
26 eyes, 20 marches, 4 charts, 1 screen, 112 panels in all. Built value **60.8 srgb** against
`wall-office` 121.5 and `wall-meeting` 98.9 — a panel darker than its wall is a panel you can see.

Verdict: **KEEP.**

## A negative blur weight, one NaN texel, and half the frame goes black

Reported live after the fifth defect pass: "giant black quads appear for a tiny amount on the
screen", inside the corp tower, at least half the screen, most often while holding RMB with the
camera near vertical.

It is not a quad. **The whole frame goes black for exactly one frame**, and the frame is a
COMPLETE, NORMAL frame: 121 draws, 146 calls, 16 passes, exposure 1.5, viewport, scissor, pass
enables `110011`, swap parity, target sizes — every one of them identical to its neighbours. The
scene drew. The picture is black anyway.

Found by reading the framebuffer after EVERY pass, then classifying each target's texels as
NaN / Inf / brightest-finite:

| target | census on the black frame |
|---|---|
| raw scene render | `r=0 g=0 b=0 A=0` — clean on all four channels, max value < 4 |
| `renderTargetBright` (bloom high-pass) | **nan=3, box 1x1** — one texel |
| bloom mips `v0..v4` | 363 → 1728 → 4446 → 6837 → 3744, boxes 11x11 → 24x24 → 38x39 → 53x43 → full |
| bloom composite → read buffer | **entirely NaN** → OutputPass tone-maps NaN to 0 |

So ONE NaN texel, born in `StreetBlur`, and bloom's blur is what spreads it over half the screen.
`Inf` would have gone white; NaN is what goes black.

**The cause is that alpha is not a 0..1 mask.** `CorpStreet.blur` writes `1 - smoothstep(...)`,
which is in range, and the pass's header reasons that an opaque material's alpha is dead data. It
is — for draws that leave it at 1. An **ADDITIVE** draw accumulates it (`src ONE + dst ONE`), so a
stack of glow quads reads back 2 or 3. Measured on the bad frame: **alpha max 3.0, 114k–140k
pixels above 1**. `float w = 1.0 - s.a` is then **−2**, `wsum = 1.0 + Σw` can pass through zero,
and `sum / wsum` is the NaN. The fifth pass put a new additive batch over the street — the car
headlights, two overlapping quads per car — which is why it started now.

Fix: `float w = max(0.0, 1.0 - s.a)`, making `wsum >= 1` by construction. Not a tolerance, an
invariant. Verified with the out-of-range alpha still present (max 3.0, 114,148 pixels over 1) so
the trigger survives and only the divide is guarded: **6,481 frames over eight repro runs, zero
NaN**, where before it fired in every run within 78–1,410 frames. `calls` 84, unchanged.

Two traps worth keeping. A synthetic DOM `MouseEvent` does NOT reproduce it — only a real CDP
`Input.dispatchMouseEvent` right-drag does. And each detector generation that wraps
`renderer.render` STAYS wrapped: nine of them stacked took the game from 59 fps to 0.6, at which
point the bug stops happening at all. Reload between detectors.

Verdict: **FIXED.** And the general one: **a screen-space pass that reads a channel nobody owns
must sanitise it.** Alpha in an HDR target is shared scratch — any additive draw, present or
future, can put anything in it.

---

## The sixth corp defect pass: the cubicle farm relaid, the LOS bug, and four decals promoted

Twenty reports off face dumps, in three groups. Four of them turned out to be ONE bug and it is the
entry worth reading: **`gen.corp.CorpConnect.openPockets` orphans what it removes.** That pass runs
last and deletes furniture cells until every walkable cell of a room can be reached; it rewrote a
desk cell to `Const.TILE_FLOOR_CARPET` and left every decoration that had been placed on it. So the
same removal produced, from the game, four separate-looking complaints: a chair pulled up to empty
floor, clutter floating at the desk's own top height, **square patches of carpet cut into a cubicle
floor** (`FacilityModel.themeRooms` only re-themes `Surf.TILE`, so a `CARPET` cell is never healed
back), and a desk run with a hole in it. It clears to the ROOM'S own floor now — read off the grid
rather than tabled, since every corp floor id is in tileset row 12 and a room is mostly its own
floor — and drops the cell's decorations with it. A chair whose four neighbours hold no table tile
comes away in a pass of its own afterwards, because a template stands the chair in the AISLE and
clearing the desk cell cannot reach it.

**The second shared cause, and it is a predicate that drifted.** `CorpFurniture.worktop` bailed on
`deskCell` alone while `CorpProps.tables` stands its bench on `deskCell && !slabTop` — so a cell
that was both emitted no quads AND took no glb, while `CorpClutter` (which asks `m.table` alone)
went on laying decals at `topH + CLUTTER_Y` = 1.53 over nothing. Same predicate on both sides now.

**THE LOS BUG IS THE BIGGEST THING HERE AND IT WAS INVISIBLE TO EVERY EXISTING NUMBER.**
`CorpModel` runs four passes that promote `Wall.WINDOW -> Wall.SOLID` in the render model, each
with a header explaining that the TILE is deliberately left alone so the correction reaches saves
that already exist. It does — and `tiles/Default` marks **every id in tileset rows 12 and 13**
see-through, which is every corp window id. So a cell drawn as solid curtain wall blocked no
sightline at all: `AreaGame.isVisible` walks the tile grid, and `VisionMask.polygon` casts against
`area.canSeeThrough` rather than against the `solid` predicate it is handed. Reported as a room
visible in full through its own wall. Measured on one freshly generated plate: **104 cells** render
solid while the tile lets sight through; after `CorpModel.sealWindows` (a repair, run once where
the model is built for a live area, the same shape as `AreaGame.repairGeneratorInfo`) it is **0**,
with all 195 genuinely glazed cells still see-through.

**The farm itself was a five-row band and is now blocks of pods.** `aisle/desk/spine/desk/aisle`
with a 3-cell desk RUN per pod is three people sharing one unbroken worktop with no divider
anywhere along it. A block is `bw` pods wide and two deep now (3 where the interior holds two
blocks of three plus their passages, 2 otherwise), centred with the remainder split — the old run
started at `x1+1` and marched until it ran out, so the whole leftover landed on the `x2` side and
the last pod could sit flush against the dressed wall column. **The side divider between two
neighbours in one block costs NO CELL**: `CorpFurniture.divider` emits a panel on the boundary
between two adjacent `Surf.CUBICLE` desk cells, on the + hands only so each boundary is drawn once.
A grid column per divider would have doubled the farm's footprint.

**And the farm's wall dressing was standing DESKS in its own aisle.** `decorateWalls`' small branch
writes `Const.TILE_DARK_TABLE_WOOD2_1X1`, a corp TABLE id — so `CorpModel` gave the cell `m.table`,
`themeRooms` gave it `Surf.CUBICLE`, `deskCell` answered true and a whole `desk-bench` module stood
against the wall. Worse, the three small items it dealt there (a printer, a coffee machine, a
router) draw **nothing at all**: `CorpDeco.kindOf` answers `K_NONE` for rows 28 and 29 while
`CorpDeco.draws` suppresses their sprites. So the branch was laying an invisible object on an
unwalkable table cell. The farm dresses its walls from things that have geometry or a glb now.

`make gen seeds=3000 --type corp`: green, `orphanCells 0`, `walkableCells == reachedCells 1256.29`.

Verdict: **LANDED.** The general one: **a repair that deliberately leaves the tile alone has to
check what else reads the tile.** Four passes said so in their headers, for four years of saves,
and none of them noticed that see-through is a property of the id.

## corp: the lift core's edge, one label at two periods

`CorpStyle.shell()` gives `head` and `roof` the same label (`textures/corp/cap-alu`), and
`FacilityGeom.capTop` picks `HEAD_TILE 3.0` on a glazed cell against `ROOF_TILE 9.0` on a solid
one. That is right where the capping is its OWN art — the compound's head is a different label —
and the lift core alternates exactly those two: `ElevatorBlock` puts three-cell glazed runs on
three sides between four solid corner posts, so the same brushed aluminium jumped **3x in course,
cell to cell, all the way round the core.** Reported twice as the elevator edge not lining up with
the roof; the probes decode straight to it (coping uv x9 -> x 14.4-19.8 z -97.2, deck uv x9 ->
x 13.5 z -99.0, curtain uv x6 -> y 6.00-7.10, exactly `ROOF_Y`..`+PARAPET_H`).

One line: take `HEAD_TILE` only when the two labels differ. Measured after, by sampling du/dx over
every cap-alu mesh in the scene: `shell` **3 -> 9**, both `deck` meshes 9, all three now one
period. The facility is untouched, because its two labels are two images.

**And the lift DOORWAY had no read of its own.** The jambs and the -0.2..0 threshold strip both
already existed and were both painted from `wIn[m.tex.circ]` — a doorway's reveal is painted
circulation whichever way it faces, which is right for an office door and left the car's opening
as a hole in the corridor board. `ShellTex` takes `pocket` and `sill` now (null for the compound):
a near-black door-pocket strip down each jamb, 0.3 wide and standing 0.02 proud so it draws over
the reveal rather than z-fighting it, and the threshold drawn in a brushed sill plate. 8 tris and
4 tris, two meshes, off `corp/fit-pack`.

**Both of those were then wrong in the same way, and it is a mapping rule.** Reported as *"lift
pocket is all wrong u,v. it's three black parts and normal wall seen in the center"*.

`face` and `threshold` tile off the WORLD, at `WALL_TILE` 6.0, which is right for a wall course and
a lie for a strip whose art is its own CROSS-SECTION. The pocket cell is a metal highlight, a band
of shadow, a highlight, running the full height; a 0.3 x 4.2 strip world-tiled sampled **0.05 x
0.70** of the sheet at whatever phase the doorway's world position landed on. The sill was worse —
**0.20 x 0.033**, a flat smear with the brush lines and both grooves off the edge. New `slot`
(u 0..1 across the strip, v still on `WALL_TILE`, which the art is uniform along) and `plate`
(0..1 both ways, `cap`'s own `swap` for the z axis).

**And the count was wrong twice over.** The pocket put a strip at BOTH edges of the reveal on BOTH
jambs — four of them — and a corp reveal is `WALL_INNER` 1.2 deep, wide enough to show the
corridor's own board between: three black bands and wall in the middle, exactly as reported. One
slot per jamb now, CENTRED on the leaf plane (`FacilityDoors` puts every leaf on the cell's centre
line), so `DOOR_T` 0.16 sits inside `LIFT_POCKET_W` 0.3 and the slot is the gap the leaf slides
into. **4 quads -> 2.**

The sill was not a mapping problem at all. `threshold` stands its riser in the two JAMB planes, so
on a wall that carries on either side it is inside the neighbouring masonry and under that cell's
own floor cap — it reads at the compound's dropped kerb and at nothing else. The ask was *"a thin
gray sliver to the bottom of the elevator door where the floor textures meet"*, which is a plate in
the FLOOR: `liftSill` lays one saddle across the opening, `LIFT_SILL_D` 0.6 deep (30 cm, half the
reveal) centred on the leaf plane at y 0.02. `threshold` keeps its riser and is untouched, so no
compound doorway changes. **1 quad.**

**And half of the reveal is not the lobby's.** A doorway is painted in `wIn[m.tex.circ]` whichever
way it faces, on the rule that it belongs to neither space it joins — right for an office door, and
for a lift it carried the corridor's board straight through the opening and into the car, which has
a panel of its own in `wallInto[Surf.LIFT]`. Reported as *"inner part of this and opposite walls
should be wall-lift texture"*. Each jamb is emitted in two halves now, split on the LEAF PLANE,
which the pocket slot stands 0.02 proud of and hides; `liftSide` finds the car by `m.surf`, so a
doorway with no car either side falls back to the single whole-depth jamb and no compound door
changes. Measured at the tower's lift: both jambs read **wall-office z -178.0..-177.4, wall-lift
z -178.6..-178.0**, the car being the low-z neighbour.

Verdict: **LANDED.** The rule worth keeping: a strip whose art states a CROSS-SECTION maps 0..1
across itself. World tiling is for a surface that repeats, and a slot does not repeat sideways.

## corp: six desk-clutter cells that were never decals

`corp/desk-clutter` is a PACK64 and passed every number on `docs/3d-textures.md` — grid lanes,
solidity, value, density. It was still wrong on four cells, reported one at a time from the game:
3 the ceramic mug, 4 the steel flask, 25 the potted succulent, 58 the tripod webcam. **The rule
the sheet was missing is per-CELL and is now in the doc:** a pack cell is a flat cut-out seen from
overhead, which is not a compromise for a sheet of paper or a folder — those really are flat — and
is a lie for anything carried by a ROUND or UPRIGHT silhouette, because no top-down art can give an
object a side.

**Four glbs for six cells**, paired so one shape serves two: a mug and a glass tumbler are one
lathe (the handle swept, since `tube` turns about the vertical), a flask and a water bottle are one
shouldered cylinder. 220/184/280/120 tris off `corp/clutter-pack`, `tex: 256` because
texels-per-WORLD-UNIT is what decides an atlas and these are 10-25 cm objects. Cells 24 (the amber
pen pot) and 48 (the takeaway cup) stay decals deliberately — at 51 degrees a pen pot is a disc of
pen ends.

**The cost is the argument and it was measured, not assumed:** visible-toggle A/B at a pinned pose,
median over 7 interleaved frames, **126 calls on / 122 off — +4, one per path**, dead stable across
all 7 pairs. A PACK64 is 64 kinds for one call; every promotion buys a shape and spends a call.

Verdict: **LANDED**, with the rule written into `3d-textures.md`'s PACK-N head and
`3d-models.md`'s four-route triage, which said nothing about 2D clutter atlases at all.

## corp: the cooler, the printer and the WC pan

The last two TRELLIS props in the corp set went hand-modelled, and the WC's sheet was repainted.

**The cooler's entry was one number fighting the art.** `baseColor 0.17` existed because the
reference clause names MATTE WHITE LACQUER and a white object photographs white — the bake came
back at sampled 212 srgb. A flat multiply is per PROP, so crushing the cabinet to 95 crushed the
bottle with it and the water shipped grey: *"wtf is water bin gray??? should be the color of water
- blue/cyan"*. No factor can fix that, because the two tones have to move APART and a scalar moves
them together. Hand-modelled, each part takes its own cell: **184 tris** against 1,200, a lacquer
cabinet, an anodised plinth/collar/dispense recess, and an inverted carboy lathed in a blue water
cell. Its value is fitted once on the built glb (sampled 48/121/159, luma 108 over the indoor ~78
band) with a flat 0.59, which holds the hue: **luma 84, chroma 88.5.**

**The printer** was called "the best-conditioned bake of the three" and was still 1,200 triangles
rounding the corners off a stack of slabs — the workstation's own history one prop over. **132
tris**: a drawer pedestal with two fronts, a body inset off it, an output slot let into that face,
a scanner lid set BACK, and the control fascia lying FLAT on the deck the setback leaves (flat and
not raked, because this camera reads the top face).

**The WC pan wore a tiled wall.** `toilet-sheet.png`'s porcelain band was pasted from
`textures/corp/wall-washroom`, **grout lines and all**, so a lathed pan came back covered in tile
joints — *"a ton of seams everywhere, why, looks like a wall/floor tile"*. It takes a plain glaze
now, and two things about the paste are worth keeping: it is cropped **2 px off the quadrant edge**
(columns 508..511 of cell 0 are the antialiased boundary into the stainless cell, and taken whole
they landed an **11.2 step** down the pan), and it is scaled **LINEARLY** onto the band's own 114.6
luma rather than gamma'd. Gamma took **7.12** to reach the same level and turned a near-white glaze
into a noise field: **std 2.13 -> 6.62** against the old band's 2.79. Linear: std **1.09**, worst
column step 1.27 against a median of 0.85.

**The bin had no inside** — the profile stopped at the rim and took a flat disc over the opening,
i.e. a lid cast into it. It runs `buildlib`'s vessel cycle now (out to the rim, over it, back DOWN
the inside, `tube`'s own end cap being the floor), 140 -> 188 tris.

**And the desk's front was -y while both files said +y.** The top's overhang, the modesty setback
and the whole drawer pedestal were measured off `yb = -TOP_D/2`, and `CorpProps.tables` turns the
module by the desk's BACK hand on the stated premise that its front is +y — so the drawers faced
the wall and the seat was pulled up to the back of the pedestal. **The convention is settled by the
chair**, whose backrest sits at +y and which is turned by the desk's own back hand so that it faces
the desk: every yaw in `CorpProps` is `atan2(DC[d], DR[d])` and what it turns to face `d` is the
model's **-y**. So a floor prop (turned by `dir ^ 1`) has its front at -y and the bench desk
(turned by `dir`) has its front at +y. Fixed in the model.

Verdict: **LANDED.**

## corp: the posters, which said "no text of any kind" three times

`corp/posters` shipped at built_linear 0.0893 / srgb 60.8 with a prompt that forbade letters, words,
numbers and script in three separate clauses — so the panels were abstract smudges in the dark.
Reported as *"when i said threatening i didnt mean dark as fuck. they should still read. plus add
motivational readable words"*.

Re-rolled with the three slogans named verbatim and asked for LARGE and legible, keeping the eye,
the marching silhouettes and the falling chart as the ground the words sit on. **NO LIFT, and that
is a decision:** a lift is a gamma, so it raises the poster's charcoal GROUND harder than its pale
text and would cut the very contrast the complaint was about. The PACKING is what fixed the level —
panels cropped to their measured bbox and pasted filling their quadrants took the sheet from
**0.0893 to 0.1876 linear (srgb 90.5)**, just under the `corp/wall-office` it hangs on at 0.219,
with the lettering at p95 srgb 191.

**The split moved again and that is why it is measured and not assumed**: the row seam landed at
510 and the TOP band's column seam at **428** against a nominal 512 (the previous drop put it at
501). `tools/posterpack.py` is that pass and prints the four aspects `CorpSigns.ASPECT` takes:
**0.6987 / 1.8139 / 1.4000 / 1.2632**, against the previous 0.5952 / 1.7437 / 1.3905 / 1.4263.

Verdict: **LANDED.**

## corp: the lift core's roof corner met neither parapet

Reported twice, and the second time with two `corp/coping.png` faces at y 7.35 — the coping's top —
a cell apart and 0.4 out of line: *"elevator edge corner wall still doesnt fit with elevator wall
and building wall"*.

**The parapet ring is drawn on a CONSTANT inset and its reentrant corners were not.** Every band
the main loop emits takes its plane from `ringRect`, which forces `FacilityStyle.PARAPET_INSET`
1.0 whatever the cell's masonry is — that is the whole of why a glazed run and a solid one leave a
dead straight roofline, and `ringRect`'s own header says so. The corner case at the inside of an L
is emitted from `notches()` instead, and `notches` is the MASONRY helper: its square is
`(CELL - thick(m, col, row)) / 2` on a side.

At the lift core the corner cell is `inner` — all four of its orthogonal neighbours are indoor or
carry, only the DIAGONAL is outdoors — so `thick` handed it `CorpStyle.WALL_INNER` **1.2**, the
office stud wall, and `e` came out **1.4** against the ring's **1.0**. Measured off the built
buffer at the tower's north-west re-entrant (col 36, row 5, diagonal 37,4 outdoors):

| band | before | after | the band it had to join |
|---|---|---|---|
| the notch's z-run | cap x **-54.12..-53.28** | x **-53.72..-52.88** | the core's east ring, p = x -53.0 |
| the notch's x-run | cap z **-178.72..-177.88** | z **-179.12..-178.28** | the block's north ring, p = z -179.0 |

Both stood **0.4 proud** of the band they existed to carry the perimeter into, in x and in z at
once, which is why it read as fitting neither wall. `notches` takes an optional `inset` and the
parapet loop is the ONE caller that passes it; every other caller (floor strips, grime, corner
detail, the facade ring) wants the square the masonry really leaves and is untouched. The compound
never showed it — its `wallIn` IS `WALL_T`, so `e` was already 1.0 on every solid cell; a glazed
corner there was off by 0.5 and is now right too.

**Two more causes behind the same corner, both found by re-probing after that fix.**

*The coping was 0.12 short of a run that carried straight on.* `endCase` had three states and only
two questions: a neighbour that carries but does not face `dir` was always CONCAVE. It is concave
when that neighbour's own `dir` hand is INDOORS — the perimeter really steps in — but when that
hand CARRIES, what sits between the two bands is that cell's notch, a band on this very line. Taken
as a step, cell (37,5)'s cap retracted 0.12 for a corner that was not there (gap at x -52.00..-51.88)
while its inner fascia grew 0.72 the other way and lay over the notch's. Both gone: the caps now run
**-53.72 → -52.88 → -52.00 → -48.00** with no break.

*And the corner cell was classed as INTERIOR.* `inner()` asked about four hands, so a cell whose
four neighbours are all indoors or all masonry counted as a partition even with an outdoor DIAGONAL
— which is exactly the cell on the inside of an L. `thick` then gave it `CorpStyle.WALL_INNER` 1.2
and its notch face, which IS the exterior cladding turning the corner, stood at z **-178.6** against
the run it had to merge into at **-179.0**. Reported as two `wall-curtain` faces that "should merge
into one another". Counting the diagonals promotes it to `WALL_T`: the cladding now runs
**x -53 → -52 → -48 → -44 all at z -179**, one plane, with the 0.5 shoulder against the recessed
curtain wall capped at z -180 as it always was. **2 cells on a 689-wall-cell plate change**, and
the compound cannot see it at all — its `wallIn` IS `WALL_T`, so `thick`'s guard never reaches
`inner`.

Verdict: **LANDED.** An optional argument, a third branch in `endCase`, and four hands to eight.

## corp: the street's traffic ran on a stopwatch, and two of its lanes were stubs

Two reports off one `corp cars` face dump: *"very short car run, don't do such short ones"* and
*"it repeats without any jitter in timing, too. needs to have random jitter"*.

**The runs.** `CorpCrowd.lanes` took one `LANE_MIN` 6 for both families, and a car covers seven
times the ground a walker does: at `CAR_SPEED` 20 a 6-cell lane is 24 units and **1.2 seconds** end
to end, and with `CAR_FADE` 10 at each end it never reaches full opacity at all — the constant's own
header said so and drew the wrong conclusion from it. Traffic takes `CAR_LANE_MIN` **16** now.
Measured on the tower's plate the road-run lengths are **6, 33, 37, 49, 77, 84, 108 and 156 cells**,
so the split is not a judgement call: it drops exactly the two stubs and keeps all 44 real runs
(46 -> 44, shortest now 33 cells = **6.4 s**). A plate with nothing longer falls back to `LANE_MIN`,
because an empty street reads worse than a short run.

**The beat.** Position was `(phase * len + clock * v) % len` — exact, so a car passed any given
point every `len / v` seconds for ever. **The lap is the unit of variation now**, and it costs
nothing: the lap index falls out of the same arithmetic, so the crowd is still closed form in `t`
and still stores nothing. Each lap hashes its own two: the car sits it out entirely (`CAR_SKIP` 30%)
or enters late by up to `CAR_WAIT` 0.5 of one slot. Car 0's re-entry gaps over 400 s went from a
flat 14.0 to **14.3, 14.0, 27.6, 14.3, 27.7, 14.3, 13.6, 28.0, 14.25, 27.9, 13.85**.

**BOTH BOUNDS ARE THE SLOT, and that is what protects the invariant the file was built on** — the
LANE holds the speed so nothing ever overtakes. Half a slot of delay cannot close a gap of a whole
one, and a skipped lap removes a car from the stream rather than moving it. Measured over 300 s,
1200 samples: minimum SAME-LANE separation **0.66** units, and that is an improvement — two cars
that draw the same slot (`(h >>> 19) % slots` has always been able to collide) used to sit exactly
on top of each other for ever, and the wait jitter is now the only thing holding them apart. The
0.27 minimum across DIFFERENT lanes is a crossroads, which the design has carried since both axes
were scanned.

**Then the speed itself, which the same report asked for next.** A car ran at its LANE's speed for
ever, so a pass never varied — and that number was on the lane for a good reason: per-CAR speed is
what once let two of them on one line converge and drive through each other. **Giving a car its own
lane is what pays for it.** With 44 road lanes and at most 44 cars there is no second car on the
line to converge with, the invariant costs nothing, and the traffic spreads — 30 of the 44 lanes
used to draw no car at all.

The lap became a FIXED WINDOW of wall clock, one lane at the lane's base speed, and each pass hashes
three things off the lap index: whether it runs (`CAR_SKIP` 15), how fast (`CAR_SPEED_JIT` 0.6,
always at or ABOVE the base so the pass always fits inside its window), and where in the leftover
slack it starts. Still closed form in `t`, still storing nothing. Car 0's measured pass speeds:
**12.23, 11.84, 17.62, 15.25, 16.88, 16.12** against a lane base of 11.8; its entry gaps
**52.7, 65.5, 42.3, 56.5, 51.1** s.

**And then a lane may not END anywhere you can see.** Reported as cars spawning *"going straight
into/out of the main building wall"*. `lanes` walked a run until `ok` went false, and `ok` folds
three different things into one `false`: past the reach, the tower stands here, and this cell is
pavement rather than road. To a lane END they are not the same — run off the reach and the car has
left down a dark street, stop against the tower or a kerb and it has faded out in the middle of the
scene, pointed at a wall. **Both ends of a traffic lane must now leave the plate**, which is the
second half of `CorpStreet.ring` deliberately without the first. Measured as the distance from every
lane endpoint to the tower's own XZ box: **0 -> 17.3** rejecting only the ends the plate covered,
and **-> 134.2** once a kerb counted too. Road lanes 46 -> 16, and every survivor is 108 or 156
cells.

**Which is why the cars ride in a CONVOY.** Sixteen long lanes at one car each is a car every 700
units of road, so `k = ceil(CARS / lanes)` of them share a lane — same pass, same speed, one
`gap = len / k` apart, so the distance between two of them never changes and nothing overtakes.
That is the invariant `Lane.v` was introduced to keep, and hanging the speed on the PASS instead of
the LANE is what keeps it while letting the number move. Measured over 1200 samples: minimum
same-lane separation **85.6** units, which is the convoy gap exactly. The one thing still the car's
own is sitting a pass out, which takes it OUT of the convoy rather than moving it.

`CARS` 28 -> 80 to pay for all of it: mean drawn **29.8** (min 15, max 46) against the 28 drawn
every single frame before. Same batch, 147 calls.

Verdict: **LANDED.**

## corp: the street's citizens were rendered as light sources

Reported as *"how are street citizens lit? they look too bright, albedo again?"* — and yes, albedo,
measured off the built sheets as mean linear luminance over opaque pixels times each material's own
colour multiplier, all three under the same three lights and all three Lambert:

| | sheet | x colour | effective |
|---|---|---|---|
| road, `city/ground-asphalt` | 0.0329 | 0.45 | **0.0148** |
| car body, `corp/traffic` | 0.0255 | 0.85 | **0.0217** |
| walker, the civilian icons | **0.4326** | 0.55 | **0.2379** |

**16x the road and 11x a car.** `WALK_DIM`'s own note claimed the Lambert was the fix and the
multiplier was not the lever — that is exactly backwards. The quad and the road take the SAME
lights, so going Lambert scales both and leaves the ratio where it was; the multiplier is the only
thing that touches it.

The cause is the source and nothing else. A civilian icon is a HUD portrait, authored flat and
high-value (**0.43 linear, srgb 175**) so it reads on the game's dark interface; a street texture is
night asphalt at 0.033. Thirteen times the albedo, and the crowd had a multiplier ABOVE
`STREET_DIM` on top of it.

`WALK_DIM` **0.55 -> 0.13**, fitted to cancel that 13x and leave the icon where a person's clothing
actually sits against tarmac: effective **0.0562**, **3.8x the road and 2.6x a car body**. Still the
brightest thing on the street, which is what the value ladder wanted — it was reaching it by being
a hundred times the road instead of four.

Verdict: **LANDED.**
