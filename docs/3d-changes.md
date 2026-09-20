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
