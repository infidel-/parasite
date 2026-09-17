# Area generation: the block tree

The index for `src/gen/`. Read it before changing how any area is laid out, and run `make gen`
before claiming the change works.

## Why this exists

Before it, `game.FacilityAreaGenerator.generate()` laid the whole compound by arithmetic on
`area.width/height` — main building at `0.5 x 0.5`, side building at `0.4` width, hangar at `0.2`,
park in whatever was left on the left, and everything not written stayed `TEMP_ALLEY` and became the
car park by accident. One coin flip mirrored it north/south. So a facility had exactly one layout,
none of it was reusable by another area type, and nothing could be checked without launching the
game and walking across it.

## The shape

Everything is a `_GenNode`: a rect, a `kind`, and the children it divided into. One
breadth-first walk (`GenTree.build`) hands each node to the filler registered for its kind; the
filler writes cells and pushes children; the walk continues into whatever it pushed. An area
dividing into plots and a room dividing into furniture runs are the same operation at different
scales, which is the entire reason for the shape.

```
area
├ road                       reserved BEFORE the split
│ └ sidewalk
└ <what is left> → Subdivide.split() → Quota.deal()
  ├ building ×2
  ├ hangar
  ├ parking                  one tile (TILE_PARKING) over ground that is already open lot, plus
  │                          two more on each bay a car is parked in (TILE_PARKING_CAR)
  │ └ entryway               the 4x2 hole through the sidewalk — stays TILE_ALLEY, gate() reads it,
  │                          except its lot-side row, which is the BOOM's and is unwalkable
  ├ park ×1..2               one required; a second takes the plot that would have been yard
  ├ hangar
  │ └ hangar-floor           the shed's interior, walked by HangarBlock itself
  │   │                      → Quota.deal() over its WALL RUNS, same dealer again
  │   ├ study-pad            the centre set piece. CARVED first, never dealt
  │   ├ hangar-machine       a bank on the pad's annulus — the cable fan's far ends, also carved
  │   │                      50/50 per BANK: the cube (FIT_MACHINE) or the tall analyser console
  │   ├ hangar-rack-bay      a corner run of server racks
  │   ├ hangar-console       a run of worktop the workstation pass stands computers on
  │   └ hangar-slot          the filler: floor clutter, and mostly nothing
  └ yard                     the filler kind: whatever nothing claimed

building
└ room-lab | room-office | room-washroom      one per room the corridors cut out
  │                         → Quota.deal() over its bays, same dealer as the plots
  ├ bench | workplace        a run of worktop; `workplace` is the office's name for it
  ├ machinery | server-rack-bay   a run of ONE fitting against masonry
  ├ lounge                   a two-seater with a low table in front — the only depth-2 zone
  ├ stall-run | basin-run | lobby  the washroom's three
  ├ slot                     the filler: a bay no demand's `must` accepted
  └ vent-cap                 the lone window a run ended on, pushed LAST
```

**Breadth-first is load-bearing.** Depth-first would finish a whole building before the neighbouring
park existed, so a filler could not ask what is next to it. Same reason the wilderness lays its
highway before its trees.

It is also what the ENTRYWAY rides on. The mouth is a child of `parking`, one level below the plots,
so it is punched *after* every plot has thrown its 2-cell pavement apron onto the road band — a
sibling of `road` would be paved back over by whichever building happened to border it.

**`yard` has no filler at all.** Open lot is what the grid was blanked to before the walk started, so
`FacilityGen.fill` has no case for it. A kind with no case is a leaf that writes nothing; that is the
design, not an omission.

**The ENTRYWAY writes a SECOND tile, and it is the boom's.** The row of the mouth nearest the lot
finalises to `Const.TILE_ALLEY_UNWALKABLE` (`TEMP_BARRIER`) — the same asphalt with the walk taken
off it, because `render.facility.FacilityEntry` lies a boom barrier and its cabinet across exactly
that line and a bar the player strolls through is decoration. `FacilityModel.surfOf` answers
`Surf.LOT` for it like the other two asphalt ids, so the renderer is untouched; what had to widen is
the MOUTH SCAN, which bounds its box over alley cells inside the pavement band — `AreaGame.isMouth`
and `GenCheck.isMouth` now take both ids, and without that the mouth reads one row short and fails
its own depth test. The pavement either side is still walkable, so nothing is sealed: a compound is
entered over the kerb, a car park is not driven into.

**`park` is `min: 1, max: 2` and the second one eats the yard.** `Quota.deal` satisfies every min
before any max, so a second park can never cost a building or the hangar — it can only spend a plot
that would have been dealt the filler kind. Measured over 1500 seeds: **nodes/park 1.99,
nodes/yard 0.05** (was 1.0 and 1.03), `cells/park` 818 against `cells/yard` 16. It doubles the park's
planting, which is the cost: a park-filling view measured 54 fps against the compound's usual 60, and
286k triangles.

**`parking` was the same leaf and is not any more, for ONE tile.** Its plot is the same open lot, but
a compound holds three pieces of asphalt — the car park, the yard and every gap between plots — and
they finalised to one id, so `render.facility.FacilityPaint` struck bay dividers on any of them that
touched a pavement and `FacilityCars` parked in one (measured: **68% of kerbside lot cells were
outside the car park**). The arm writes `TEMP_PARKING` -> `Const.TILE_PARKING` and nothing else.
`FacilityModel.surfOf` still answers `Surf.LOT` for it, so debris, lamps and the gate are untouched;
only the two passes that mean THE CAR PARK ask `FacilityModel.isParking`. The ENTRYWAY child paints
its mouth back to `TEMP_ALLEY`, because that hole is what `AreaGame.gate()` finds the checkpoint by.

**A PARKED CAR IS TWO MORE TILES, and the second of them is what keeps the renderer dumb.** The cars
used to be dealt render-side and stamped nothing, so the boom got a tile and the cars beside it were
still walked through. `gen.facility.FacilityBays` runs after the whole tree is down — it needs the
pavement the ROAD block laid, the plot the PARKING block named and the boom's row to rank the bays
from — and marks each chosen bay `TEMP_CAR` -> `Const.TILE_PARKING_CAR` with its low corner against
the kerb `TEMP_CAR_ORIGIN` -> `TILE_PARKING_CAR_ORIGIN`. Two ids because two bays side by side along
one kerb are a single 2x4 block of marks with no seam in it: one id alone cannot say where a car
BEGINS, and the renderer would have to re-derive the bay phase to find out. The origin says it, and
the car's axis comes off whichever neighbour is pavement.

Both alias to the alley's icon (`tiles.Default.getIcon`) so there is no new art, both are 0 in
`TILE_WALKABLE` and 1 in `TILE_SEETHROUGH` — a car park you cannot see across is a change to line of
sight nobody asked for. `FacilityModel.isParking` answers true for them, so the paint still strikes
the bay the car stands in. The bay rhythm is `FacilityPaint.runStart` COPIED against the temp alphabet
(the paint is render-side and the generator cannot reach it); a divergence would only stand a car
across a painted divider, and `GenCheck.parkingSane` asserts what is checkable instead — cars under
the cap, marked cells exactly `cars x SPACING x DEPTH`, every origin with a kerb beside it. That
total caught the one real bug: a cell claims the FIRST kerb it finds, so a two-deep lot with pavement
on both sides dealt the same rect twice (**18 marked cells where five whole bays are 20**), fixed by
re-asking `whole` at stamp time so the first bay dealt keeps the ground.

**The room level is walked by its own `GenTree.build`, not by the area walk** — the one place the
breadth-first ordering had to be overridden. `generateBuilding`'s last pass is
`generateRoomContents`, and `roomChemistryLab`'s island only takes a spot that is still bare floor,
so the benches have to be standing two lines earlier; deferring them a level would put every room's
furniture after every building's last pass. The room nodes stay attached to the building all the
same, so the finished tree is still a record of the whole area — the area walk meets them again a
level later and `FacilityGen.fill` has no case for them, which is what makes the second visit a
no-op. A room kind added to that switch would silently double-fill.

`FacilityGen.build()` in full:

```
ctx.chance(50)                          which edge the road is on
drawBlock(… TEMP_ALLEY)                 the ground everything is cut out of
root.children += RoadBlock.node()       the band, reserved before anything is cut
root.children += FacilityBlocks.plan()  Subdivide.split → Quota.deal
GenTree.build(root, fill)               the walk
finalizeTiles()                         TEMP_* → Const.TILE_*
FacilityConnect.connectRooms()          every room is walk-in-able
```

## Files

| file | what it is |
|---|---|
| `gen/Rng.hx` | the seeded stream. `mulberry32`, moved verbatim out of `citygen.CityGen`, which now delegates to it so no city layout moved |
| `gen/GenCtx.hx` | the area as generation sees it: grid, rng, spawn list. `random(n)`/`chance(pct)` live here |
| `gen/_GenNode.hx` | a node: rect + kind + children. **Not persisted** — see below |
| `gen/GenTree.hx` | the walker: `build`, `leaves`, `all`, `find`, `overlaps` |
| `gen/Subdivide.hx` | recursive rect splitting, `_SplitProfile` for knobs |
| `gen/Quota.hx` | deals kinds onto split rects, `_GenDemand` for "must have one of these" |
| `gen/GenSpawner.hx` | the ONLY file under `gen/` that touches a `Game`: drains spawn intents into real objects |
| `gen/GenCheck.hx` | the structural assertions |
| `gen/Deco.hx` | deals decorations by PLACE — `pick(ctx, mount, block)` — plus `selfCheck()` |
| `gen/GenRun.hx` | headless entry point of `bin/genrun.js` |
| `gen/blocks/*Block.hx` | one filler per block kind. Suffix is `Block`, always |
| `gen/blocks/FacilityBlocks.hx` | the compound's profile, quota and `plan()` |
| `gen/blocks/RoadBlock.hx` | the carriageway, the pavement, the sewer hatches and the gate mouth |
| `gen/blocks/RoomBlock.hx` | the ROOM level: the glazing pass, and every zone filler under it |
| `gen/blocks/RoomZones.hx` | what a room of each kind must contain — the room level's `demands()` |
| `gen/blocks/HangarBlock.hx` | the shed, its size cap, and the HANGAR level: the study pad, the machine banks and every zone filler under them |
| `gen/blocks/HangarZones.hx` | what a hangar's wall runs must carry — the hangar level's `demands()` |

### The facility, after the split

`game/FacilityAreaGenerator.hx` was 2432 lines in one class. Two measurements made the split a move
rather than a redesign: **`game` was used once** in the whole file, and **`gen: AreaGenerator` was
used zero times** — so every pass was already effectively static.

| file | what it is |
|---|---|
| `game/FacilityAreaGenerator.hx` | the LIVE adapter, and all that still needs a `Game`: `generate()` wraps the grid in a ctx and drains the spawns, `repairRooms()` re-derives rooms from a SAVED grid and so takes an `AreaGame` |
| `gen/facility/FacilityGen.hx` | `build()` — the real entry point, the one the oracle calls — and `finalizeTiles` |
| `gen/facility/FacilityBays.hx` | which bays of the car park hold a car, and the two marks that say so |
| `gen/facility/FacilityTemp.hx` | the `TEMP_*` alphabet, the temp→final map, and the four constants more than one pass reads |
| `gen/facility/_FacilityState.hx` | what a compound looks like mid-build. Not persisted |
| `gen/facility/FacilityBuilding.hx` | one lab building: wall ring, corridors, room subdivision. What goes INSIDE a room is `gen/blocks/RoomBlock.hx` |
| `gen/facility/FacilityConnect.hx` | every door, and both reachability passes — `fixDoors` on the room graph, `connectRooms` on the tile grid |
| `gen/facility/FacilityRooms.hx` | the room templates and the shared placement helpers |
| `gen/facility/FacilityToilet.hx` | the washroom and its T-partition |
| `gen/blocks/ParkBlock.hx`, `HangarBlock.hx` | driven by the tree; they still take `(state, x, y, w, h)` because a filler that only needs a rect does not need a node |

**`FacilityConnect` and not `FacilityDoors`**: `render.facility.FacilityDoors` already exists, and two
modules of one name in different packages is a trap for no gain.

### The one permitted `gen/` → `game/` edge

`gen/facility/` imports `game.AreaGenerator`'s pure static grid helpers — `drawBlock`, `drawChunk`,
`drawLine`, `replaceTiles`, `getRoom`, `markRoom`, `getRoomDoorSpots`, `getRoomWallSpots`,
`getRoomWallCorners`, `nextTo`, `deltaMap`, `DIR_*` — plus its `_Spot` typedef. **Every one is
`public static` over a plain `Array<Array<Int>>` or `_Room` and none touches a `Game`**, so the rule
above holds and `make gen` keeps working.

Moving those 13 helpers into a `gen/Grid.hx` is the obvious follow-up and is deliberately not done:
`AreaGenerator` still serves the wilderness, city, sewers and underground lab, so it is four more
generators' blast radius for no benefit yet.

### Decorations are dealt by PLACE, not by a hardcoded list

`Const.FACILITY_DECO` (was `FACILITY_FITTINGS`) is a table of `_DecoPlace`, and every entry says where
it may appear:

- **`mount`** — the surface. `'floor-high'` is standing furniture with plain masonry behind it;
  `'floor-low'` is knee-high and may stand under glazing; `'table'` is a bench worktop (reserved).
- **`blocks`** — the room. `'lab'`, `'cabinet'` (a researcher's office), `'toilet'`. These are
  `_Room.role` VERBATIM (`FacilityTemp.ROLE_*`) with `'lab'` standing in for the null role, so a room
  deals its own furniture by handing its own role to `Deco.pick` — no branch at the call site.

This replaced `Const.highFittings()` / `Const.officeFittings()`, which were the `high` and `themed`
booleans plus a literal `kind == FIT_BOOKCASE || kind == FIT_CABINET || kind == FIT_RACK`. A boolean
could only say "not low" and "not in the random roll"; a place tag says where a thing belongs, so a
new room kind is a word in a list rather than a fourth filter function.

**`frames` is still the persisted identity and must stay unique across the table.** An
`objects.Decoration` saves only `imageRow`/`imageCol`, and `Const.fittingOf(row, col)` reads the kind
back out of it — that is what lets saves made before any of this existed light up as 3D geometry with
nothing migrated. `Deco.selfCheck()` asserts the uniqueness and that every place the facility asks
for deals something; `GenRun` runs it before the first seed, so `make gen` is the check.

`pick` rolls an ENTRY and then one of that entry's frames — two rolls, not one flat roll over every
matching frame — because a kind is what the player reads: the machine casing carrying five atlas
icons must not turn up two and a half times as often as the shelving carrying two.

Bench decoration (`Const.CHEM_LABS_DECO_TABLE`) is still an atlas ROW RUN dealt by
`FacilityRooms.addDecoration`, not a place entry. It has no per-frame identity, and `game
.CorpAreaGenerator` reads the same runs.

### `fit` is a preference, `must` is a requirement

`_GenDemand.fit` scores the rects a demand could take; `_GenDemand.must` decides which rects it is
allowed to take at all, and `Quota.homes` counts only the ones that pass. **The difference is not
stylistic.** A preference loses to whatever was dealt first, and `Quota` deals most-constrained-first:
the facility's parking lot said "nearest the road" with `fit`, the two lab buildings were dealt ahead
of it because they had fewer legal homes, they took both frontage plots, and **1 compound in 1000**
came out with its gate mouth opening onto a building wall. Expressed as a `must`, parking becomes the
constrained demand, is dealt first, and a split that cannot house it is re-rolled by `plan`'s existing
retry loop like any other unsatisfiable quota.

A `must` narrows what `best` may choose from, so give the demand a `fit` as well or it falls through
to `best`'s runner-up rule — roomiest-first. Parking did, and a car park taking the biggest plot on
the street cost the lab buildings 100 cells of floor and the compound two rooms.

### A room divides into bays

`FacilityBuilding.makeWindows` was 235 lines walking each wall of each room once and deciding the
glazing, the worktops and the floor clutter off one set of running counters. It is `RoomBlock` now,
and the walk happens twice on purpose:

- **glaze** paints the ribbon along the wall in bays of 3 (2 in a room under 7 cells on that axis),
  one blank cell between bays, and stops permanently at the first cell that is not exterior masonry.
  As it goes it pushes one child per bay over the line of floor immediately inside it — `bench` where
  a worktop fits, `slot` where the bay runs off the end of the room or stands in a doorway's swing.
- **bench** lays the worktop tiles and puts glassware on ~70% of them. A room CORNER always gets one,
  because a clue's activation range is a cross and would reach through the wall.
- **slot** deals a standing fitting against plain masonry, something on the floor where the wall is
  glass, or nothing.
- **vent-cap** is pushed after every bench and slot of the room, so it can ask the finished grid
  whether the floor inside the run's last window was left bare.

**That last one is what the split bought.** `hasVentSpace` used to be a flag the one big loop carried
along the run, set in the clutter branch and read by the glazing branch forty lines later — the exact
coupling that meant a pass could not be moved without moving the other two. It is a question about
cells now. The same goes for `nextToWindow`, which used to see only the glazing painted *so far* and
now sees all of it; that is the only measurable difference the split made (`spawns/decoration`
129.10 → 127.35, more slots correctly reading as beside-glass and so being left bare).

**`FacilityRooms.clearTableSpots` still runs.** The plan said the corrective pass existed because the
three jobs were interleaved, and half of that is true — but it also takes back cells that
`render.facility.FacilitySink` and `FacilityWork` consume on the render side, which the generator
cannot see. It stays until a check proves it is idle.

Sub-block data rides on `_GenNode.tags` (`h3`/`v2`/… for the tile family, `drawer`, `door`, `end`)
and `_GenNode.roomID`, both of which the node typedef already carried for exactly this.

#### The `end` tag was one cell early on the vertical walls, and it cost a wall of worktop per room

Reported from the game as "some labs are pretty empty now", with a cell. The room it named was a 4x7
lab with three doors and **2 bench cells in 28**: both horizontal bays stood in a doorway's swing and
both vertical bays were marked `TAG_END`, so `RoomZones`' core demand could accept nothing at all and
every bay in the room fell through to the `slot` filler. A room lined with cabinets and no worktop.

`glazeWall` tests the blank cell between two bays against the far wall, and the two axes disagreed:

```haxe
if (spot.dir == DIR_DOWN && y >= room.y2 - windowSize)      // one cell early
else if (spot.dir == DIR_RIGHT && x > room.x2 - windowSize) // correct
```

`x`/`y` is the BLANK cell, so the next bay spans `it + 1 .. it + windowSize` and fits exactly when the
last of those is `room.y2`. `>=` called that running off the end. Every room whose height divided
evenly into the rhythm lost its whole second vertical bay — and the `noTable` latch, which is correct
(once a run has passed the far wall the rest of it has too), then carried the mistake to the end of
the run. Both tests are `>` now.

**Measured, 4000 seeds:** `nodes/bench` 33.31 → **38.39**, `nodes/workplace` 8.62 → **10.25**,
`nodes/slot` 50.68 → **43.68**, `spawns/decoration` 126.19 → 129.51. Rooms, doors and cells/rooms
unmoved — the bays moved out of the filler and into the zones that wanted them, which is what a
redistribution looks like. Live: no lab in a fresh compound comes back with zero worktop.

**It also fired a latent door bug, and that is the entry worth keeping.** One seed in 4000 then failed
`GenCheck.doorsSane` with *two doors between rooms 101 and 102*. `connectRooms` tries three things in
order, and the middle one was `cutDoorToReached(..., allowDuplicate = true)` — which its own comment
acknowledges breaks `scenario.AlienMissionCommon` (it locks a room by taking the FIRST door it finds
and stopping, so a duplicate pair leaves the other way in unlocked). It had simply never fired in
4000 seeds; the extra bench run moved enough furniture to seal a room the other way. The duplicate is
now the LAST of the three, after `clearWayToReached`: taking one fitting away is invisible, a
duplicate pair is a mission that silently locks nothing, and a room nothing can enter at all is worse
than either. **20000 seeds clean.**

### A room is DEALT, not typed as it is walked

The glazing pass pushes every bay as kind `bay` and says nothing about what goes in it; `Quota.deal`
then assigns the kinds, with the same dealer, the same `min`/`max`/`must`/`fit` and the same
most-constrained-first rule the compound's plots use. `RoomZones.demands` is the table.

**Core zones are `min >= 1`; optional ones roll their `min` before the deal.** That ordering is the
whole point: a demand with a min is in pass 1, so a machine bank that rolled in picks its wall before
the core zone takes the room. Rolled inside the filler instead, it would be picking over whatever the
core had already left — which is how the arithmetic era placed everything.

**`min: 0, max: 1` does not mean "maybe one".** `Quota.deal`'s second pass spends every demand up to
its max whatever its min was — that is what turns a leftover plot into a second lab building one
level up — so an optional zone must roll BOTH. Measured before the fix: a machine bank and a server
bay in every room of every compound, 11.6 of each against the 4.7 the odds ask for.

**A node's rect may only hold cells the node owns.** A washroom wall run arrives from
`roomWallRuns` with cells already dropped out of the middle of it — one beside a doorway, one under
an object — and `FacilityToilet.zones` splices out the T's two passages as well, so a node built from
the list's first and last cell claims the gaps too. Both cost a compound on seed 2993: a cubicle went
up on the cell dropped next to the *neighbouring* room's only door, and then another went up in the
passage itself. `FacilityToilet.spans` cuts a holey list into contiguous runs, which is what they
really are — the old pass ranked a holey run by its total length and stood fittings on non-adjacent
cells.

**A run of one kind always leaves one cell.** Everything else on a perimeter leaves holes by
construction (a bench skips a cell a neighbour took, a slot rolls 70%), so a room has always had a
lane round its own walls by accident. `standing` was the first pass that filled every cell it was
dealt, and two such runs can ring a small room: 2 seeds in 4000 against 0 in 10000 before the zones.

**And `connectRooms` can now take a fitting away.** Its cut needs three things at once — masonry, a
reached cell on the far side, and a cell you can stand on on the *room* side — and it is the third
that runs out when a room is ringed by its own furniture. `clearWayToReached` is the last resort
before giving up, because a room that renders perfectly and cannot be entered still spawns clues,
guards and mission anchors inside it. With it, 20000 seeds are clean.

**A zone's fittings need a `blocks` tag nobody rolls.** The lounge's sofa was tagged `cabinet`, which
is a `_Room.role`, and the office *does* call `addFitting` with its own role — so `Deco.pick` started
dealing sofas as ordinary wall furniture (measured live: three sofas and one table in one compound,
two of them standing where a bookcase was asked for). They are tagged `lounge` now. The washroom's
three never had the problem because nothing ever asks `Deco` for a `toilet` fitting.

**THE SUITE IS A RUN ALONG THE WALL, NOT A DEPTH-2 PAIR.** The lounge's low table went on the cell
one step into the room — the plan's "depth 2" shape — and that cell is the MIDDLE of an office, which
is the one strip everything has to walk through and the one a room this size has to spare. Reported
from the game as a small table dumped in the middle of the floor. The sofa and the table stand on two
ADJACENT cells of the bay now, so a lounge is a depth-1 run like every other zone here, and
`loungeRun` counts PAIRS rather than cells — a bay with two usable cells at opposite ends houses no
lounge. `nodes/lounge` 1.90 → 1.63, which is what a pair costs over a single spot.

**A DOORWAY IS NOT ONLY ITS OWN CELL.** Every wall-hugging pass in this tree made one test about
openings — `nextTo(..., TEMP_BUILDING_INNER_DOOR)`, which reaches exactly one cell — and that is
enough for a run one cell deep and not enough for anything standing further in. The rule for the rest
was already here, hand-written inside `isBigTableSpotValid` as a march of three cells from each door;
it is `FacilityRooms.inDoorLane` now, asked of a CELL rather than of a rect so every zone can ask it,
and `RoomBlock.solid` does. The depth is the room's own half-span, which is what "clear to the middle"
means and is never deeper than the fixed 3 it replaces. It bites where a door sits in the corner of
its wall, which puts the strip you walk in on along the bay line of the NEXT wall — the one place
orthogonal adjacency cannot see it. `spawns/decoration` 127.13 → 126.19, `doors` 18.71 → 18.63.

**A TEMP tile test after the floor paint tests nothing, and the washroom drain had been dead for as
long as it existed.** `paintRoomFloor` is what turns `TEMP_BUILDING_ROOM` into a final id, so
`roomToilet`'s `cells[cx][cy] == TEMP_BUILDING_ROOM && area.chance(50)` was false at the first
operand every time — the roll never even fired, because `&&` short-circuits, which is also why the
RNG stream showed nothing. Moving the drain ABOVE the paint fixes it and costs nothing: a drain tile
is already a final id, so the paint steps over it exactly as it steps over a fitting. `spawns/floorDrain`
4.02 → 4.28, against the 0.59 that 1.18 washrooms at 50% would suggest — the remainder is the test
doing its job, since a washroom is dense with cubicles and basins and the drain will not land on one.

#### A count of BAYS where a test of CELLS belonged, and both top corners of every room went bare

Reported as empty corners in three separate rooms — "2x2 of nothing" in one, "empty cabinet corner
again" in two more. `glazeWall` opens each vertical run with

```haxe
if (spot.dir == DIR_DOWN && cnt == 0)
  continue;                       // "the horizontal wall has already had that corner"
```

and `cnt` counts CLOSED BAYS, not cells. So it dropped the whole first bay of both vertical walls —
`windowSize` cells, 3 or 2 — where the comment justifies dropping the ONE cell the horizontal run
took. Traced on a 7-tall room walking the left wall: `(x1, y1)` really was claimed by the top run,
`(x1, y1+1)` and `(x1, y1+2)` belonged to NO bay node at all, `(x1, y1+3)` is the inter-bay blank,
and the first real bay starts at `y1+4`. Cells no node owns never reach `Quota.deal`, so no filler
ever sees them and they stay bare floor.

**The overlap is exactly one cell per end and it is nameable**: a horizontal run's table line is the
room's first and last ROW, so a vertical run meets it at `ty == room.y1` and `ty == room.y2`. Testing
those two keeps every run contiguous (the walk breaks at `y2`, so the second is always the last cell
pushed) and hands the rest back to the dealer.

Measured, 4000 seeds: `nodes/bench` **38.34 → 57.16**, `nodes/workplace` **10.26 → 15.44**,
`spawns/decoration` 129.8 → 152.45, `nodes/slot` 43.66 → **43.62** — the recovered cells extend the
first bay of each vertical wall, and the core zone is what `max: MANY` gives them to. `rooms` 19.30 →
19.31, `doors` 18.57 → 18.57, `unreachableRooms` 0, and 20000 seeds clean — which is the number that
mattered, since every recovered cell is new floor for `standing` to ring a room with.

#### The washroom dealt the LABORATORY's furniture

"48,25 — should be no machinery in the toilet lol!" It is not `RoomZones.demands` — a washroom never
reaches it (`RoomBlock.kindOf` sends it to the `WASHROOM` arm). `FacilityToilet.zones` deals its bays
with `RoomBlock.SLOT` as the FILLER, so every bay that is not the one stall run or the one basin run
becomes a `slot` node; and `slot()` branches on `room.role`, where a washroom is neither
`ROLE_CABINET` nor anything special. It fell through to `FacilityRooms.addFitting(state, x, y)` with
no role — which defaults to `Deco.BLOCK_LAB` and deals shelving, bookcases, racks and machines.

A `ROLE_TOILET` arm that places nothing. The room does not go bare: its clutter is the bin, the broom
and the bucket, all three render-only passes that need no tile (`render.facility.FacilityJanitor`,
`FacilityGround.indoorBins`).

**The general shape, and the third time this exact thing has bitten:** a filler with a `role` switch
and no `default` arm is a filler that deals the laboratory's list to whatever room nobody named.

## Rules

**Nothing in `gen/` may touch `game.Game`.** This is the rule the headless oracle rests on.
Constructing a `Game` reaches `ui.UI` → `MainMenu` → `MainMenuGL.initTextures` → `new Image()` and
WebGL inside the constructor, and no amount of stubbing makes that a thing worth maintaining. The
generator writes into a `_GenCtx` and records object **spawn intents** instead of constructing
`AreaObject`s; `gen.GenSpawner` turns those into real objects on the live path only. The moment
something under `gen/` reaches for a `Game`, `make gen` stops working.

**The tree is not persisted.** Nothing downstream reads blocks: the renderer, the lighting and the
missions all re-derive what they need from the saved cell grid (`FacilityModel.fromArea`,
`WildModel`, `AreaGame.gate`), and `_Room` already carries the per-room intent that has to survive a
save. A persisted tree would be a second source of truth that every existing save lacks, for no
reader. `generatorInfo` keeps taking `rooms`/`doors` exactly as it always has.

**Every roll comes off `ctx.rng`, spelled `area.random(n)` / `area.chance(pct)`.** Those two names
are `Std.random(n)` and `Std.random(100) < pct` with a seeded stream behind them, and they are named
that way on purpose: the swap was 45 call sites and a drop-in spelling is what let them move without
also re-deriving what each expression meant. `Rng`'s statics are for code holding a bare stream
(`Subdivide`, `Quota`); a generation pass holds a ctx and should use the ctx. **A `Std.random` left
anywhere under generation silently breaks `--digest`**, which is the only gate that can check a
refactor.

**Quotas, not dice, for anything mandatory.** `FacilityRooms.assignRoomThemes` used to roll a 60 for
the washroom, which is why 40% of compounds had none — not a decision, just a roll standing in for
"usually". `_GenDemand` says the thing that was meant: at least `min`, at most `max`, and a `fit`
function for which rect suits it. That roll is gone (see "A lab building always has a toilet" below);
`_GenDemand`'s header still names it, because it is the clearest example this repo has of the fault.

**An unsatisfiable split is re-rolled, not repaired.** `FacilityBlocks.plan()` splits, deals, and
starts over with a fresh split if any `min` went unmet, up to `MAX_PLAN_TRIES`. Same shape as
`UndergroundLabAreaGenerator.buildLabLayout`'s 30 attempts. `Quota.deal` is silent on failure for
this reason — ask `Quota.satisfied` instead.

**`Subdivide` is not shared with `citygen.CityGen`, on purpose.** CityGen's `leaf()` draws floors,
roof and facade from the same rng as the split, so cutting and dressing are interleaved in one
stream. Pulling the split out would reorder those draws and move every city layout in every existing
save. The duplication is deliberate.

## The oracle

```
make gen                              # 3000 seeds, structural checks
make gen seeds=200 args="--print"     # dump each layout
make gen seeds=3000 args="--stats"    # aggregate block/cell means
make gen seeds=200 args="--digest"    # one hash per compound - see below
node tools/genrun.mjs --seed 4210 --count 1 --print            # one specific seed
node tools/genrun.mjs --seed 4210 --count 1 --size 65x50 --print   # at one specific size
```

**The live counterpart is the console command `area regen`** (debug build only): it walks the player
out to the region, throws the area's cells, objects, AI and `generatorInfo` away and walks them back
in, so a fresh layout costs one line instead of a reload and a teleport. The oracle proves 4000
layouts; that is how one of them gets looked at. See [`debug-surface.md`](debug-surface.md).

`--size` exists because the live game traces `facility <w>x<h> seed <n>` on every generate, and both
halves of that are needed to replay it: the seed drives every roll inside generation, but
`AreaGame.initPost` rolled the dimensions before generation was reached.

### `--digest`, and why a refactor is diffed rather than reviewed

`--digest` prints one FNV-1a line per seed over the whole result — every cell, then every spawn, room
and door in the order they were recorded.

```
make gen seeds=200 args="--digest" > before.txt     # then change something
make gen seeds=200 args="--digest" > after.txt
diff before.txt after.txt                            # a pure code move prints nothing
```

Run the *same* command twice and diff instead, and it asserts something else: that the generator is
deterministic at all. An unseeded roll left behind, or a `Map` walked in hash order, moves a digest
between two runs of one binary.

This is what the seeding in Phase 2 was for. Moving 2400 lines of generation code between files
cannot be reviewed by eye and cannot be gated on `--stats` — distribution means agree to within
sampling noise whether or not a rare branch lost an off-by-one. `--digest` answers it exactly.

`tools/genrun.mjs` stubs the browser globals the bundle's **class-static initializers** touch on
import — `render_Gizmo.fwd = new THREE.Vector3()` fires on load even under `-dce full`, because
`Const` transitively references the render tree. None of that code is called; it only has to survive
being defined, so a bottomless proxy is the whole shim.

**Use it between changes instead of the game.** A layout bug costs a second here and costs a build,
a reload, a save load and a walk across a compound there.

### What it checks

- split leaves clear `minSide` and stay under `maxSide`
- blocks stay in bounds, none degenerate, no two overlap
- every demand's `min` is met and no `max` exceeded
- a dealt block is actually big enough for what it was dealt
- every cell holds a tile id the tileset actually has
- rooms are in bounds, non-degenerate, uniquely numbered, w/h agreeing with their corners
- every door resolves to rooms that exist, and no two doors join the same pair of rooms
- no two objects share a cell, and every spawn is in bounds
- **every room can be walked into** — flood fill from the rim over walkable tiles
- at least one bare bench cell exists, or the facility stops handing out clues
- **the checkpoint re-derives**: exactly one `ENTRY_W`-wide mouth of open lot through the pavement
  band, flanked by open lot on the row inside it — `AreaGame.gate()`'s own derivation, reimplemented
  on purpose because it reads nothing but the shape of the grid
- **the park has a path**: at least one walkway cell with lawn on both sides of its run, which is
  what `FacilityModel.isParkPath` looks for and what the kerbs and the lamps hang off
- `_DecoPlace` frames are unique across the table and every place the facility asks for deals
  something (`Deco.selfCheck`, run once before the first seed)

### What `--stats` is for

A phase gate. Capture the means before a change and after it: a "cosmetic" edit that moved the
room-count or decoration-mix distribution shows up here and nowhere else.

**A facility is not 75x60.** `AreaGame.initPost` rolls each axis separately as
`info.width - 10 + 10 * Std.random(2)`, so a facility is 65 **or** 75 wide by 50 **or** 60 tall —
four sizes, and the `WorldConst` numbers are the largest of them, not the size. The oracle rolls the
same two dice. Checking only 75x60 tests a quarter of the game and hides the case that actually
binds the block profile.

Baseline, 4000 seeds across all four sizes — **the numbers a later phase diffs against**:

```
rooms          19.35   spawns/TOTAL      169.03   blocks/TOTAL  6.03
doors          18.63   spawns/decoration 126.19   blocks/yard   1.03
cells/rooms   823.50   spawns/door        25.91   planTries     1.22
cells/building 1192    spawns/vent         8.16   planRetried   0.17
cells/yard      392    spawns/floorDrain   4.28
cells/parking   359    spawns/sewerHatch   4.52
unreachableRooms 0        reachedCells 3085 / walkableCells 3098

nodes/bench       33.31   nodes/machinery        4.35   nodes/room-lab      13.39
nodes/workplace    8.62   nodes/server-rack-bay  3.80   nodes/room-office    3.78
nodes/slot        50.68   nodes/lounge           1.63   nodes/room-washroom  1.19
nodes/vent-cap     6.83   nodes/stall-run        2.38   nodes/lobby          1.19
                          nodes/basin-run        2.38
```

**`nodes/*` counts every node of the finished tree at any depth**, which is the furniture gate a
spawn count could never be: `spawns/decoration` cannot tell a bench that was never laid from one that
was laid and left bare. `nodes/room-*` summing one short of `rooms` is right — the hangar is a room
and not a room node. `bench + workplace + slot` plus the zone kinds is the bay total, so a zone
arriving always costs `bench` and `slot` exactly what it takes.

**Read those to ±0.15, not ±0.01.** Three disjoint 4000-seed ranges of the arithmetic-era generator
gave `rooms` 18.81 / 18.96 / 18.92, so one range's mean carries about that much sampling error and a
1% move between two runs says nothing. For anything finer than the means, use `--digest`.

Against the arithmetic era these are close where it matters and deliberately not identical: `rooms`
19.36 against 18.81, `doors` 18.60 against 18.02. **`spawns/decoration` is the one that genuinely
moved** — 127 against 157, because bench runs are dealt under ribbon glazing and a site divided into
six fair plots has about 20% less exterior wall on its buildings than one where two hand-placed
buildings ate 66% of the ground. (Of that, 1.75 is the room-level split rather than the plot
division — see "A room divides into bays".)

`rooms` only landed there because `FacilityBuilding.SUBDIVIDE_OVER` was cut from 1.5 to 1.2 in the
same phase. Plots are capped by `splitProfile().maxSide` and bounded in aspect, so the buildings are
squarer than the old hand-placed ones and their rooms came out at 60 cells against the 45 they used
to average — 14.2 rooms per compound instead of 18.8, with the same total room AREA. The constant is
the knob for that and nothing else.

`planTries 1.22` is the margin between the split profile and the quota: the first split houses
everything ~83% of the time. A mean creeping up is the warning that comes before the retry cap is hit
and a compound ships without its second building.

Yard at ~12% of the area is not waste — it is the open ground `FacilityDebris`, `FacilityCars` and
`FacilityEntry`'s guard booth stand on, and the distance the buildings are seen across.

### Sealed rooms, and why the repair is a separate pass

The oracle's first real catch: **8% of compounds contained a room that could not be entered.** It
rendered perfectly, and clues, guards and mission anchors could all spawn inside it. The generator
had always traced this itself — `bug, no door spots in room`, 189 times per 2000 seeds, and `no
corridor-adjacent walls in cluster`, 47 — but a trace during generation is not something anyone
reads.

Three separate faults fed it, each fixed:

1. **`getRoomDoorSpots` offers four candidates** — one midpoint per wall, out of a perimeter of
   `2(w+h)`. A room whose four midpoints were all exterior masonry got no door at all.
   `getRoomWallSpots` now supplies the whole ring, centre-outwards, as a *fallback* so doors still
   land mid-wall wherever they legally can. Took `no door spots` from 189 to 0.
2. **`fixDoors` grouped rooms with a single pass that could not merge.** If A-B formed one cluster
   and C-D another, a later door joining B to C pushed C into A's cluster and left D in the second
   one. Which group a room landed in — and whether it appeared to reach a corridor — came down to
   door creation order. Replaced with union-find.
3. **The room graph is not the tile grid, and the graph is the optimistic one.** A room can hold a
   door `fixDoors` counts as a connection while the cells behind it are furniture or another sealed
   room — and furniture is not placed until *after* `fixDoors` runs, so half the obstacles do not
   exist when the graph is checked.

Fault 3 is why `connectRooms` is a **separate pass at the very end of generation**, after
`finalizeTiles`. It floods the finished grid from the rim exactly as `AreaGame.isWalkable` will, and
cuts a door into whatever the flood did not reach — preferring an indoor neighbour over cutting
through the outside wall, and preferring a wall that does not duplicate a door the room already has
(`AlienMissionCommon` locks a room by taking the *first* door it finds and stopping, so a duplicate
pair would leave the other way in unlocked).

**Now zero across 10000 seeds of block-tree layouts, and asserted rather than counted.** The
`reachedCells` / `walkableCells` stats exist to validate the check itself — they sit at 3081/3093, so
the flood really does cover the grid and a zero is a zero.

### The grid edge is a real boundary now

Until the block tree, nothing ever put a structure near the map border — the arithmetic kept every
building a dozen cells inside — so `FacilityBuilding`'s probes indexed `cells[x][y]` raw and were
safe by accident. Three of them read OUTSIDE the building they are working on: `drawSideCorridor` and
the main corridor loop read the cell past the wall they are about to stop at, and `isBlockNearDoor`
reads the ring around a bench block. The split hands out whatever plot it produced, so they go
through `FacilityBuilding.at()` now, which returns -1 off the grid. `FacilityBlocks.EDGE_MARGIN`
keeps a plot two cells off the border on top of that, which is the same clearance
`splitProfile().gap` gives it against a neighbour — a building's wall flush with the world's edge has
nowhere to put its pavement apron.

## The washroom was picked for its WALL and never asked about its DOOR

Reported as a toilet that is not adjacent to a corridor and has two doors, both into a lab — and
measured on `HEAD` over 2000 seeds, that was the common case, not a corner: a `washroomSane`
assertion fired **2420 times against 1.19 washrooms per compound.**

Nothing in `FacilityConnect` knows what a room is FOR, and it cannot: roles are dealt by
`FacilityRooms.assignRoomThemes` **two passes after the doors are cut**, and the inner-wall pass in
`generateBuilding` has by then turned every corridor-facing room cell into the same
`TEMP_BUILDING_INNER_WALL` as a lab-facing one, so `doorSpots` rolls uniformly over a room's whole
ring. A room's door COUNT is then accretion — one of its own, plus one for every neighbour whose own
roll landed on the shared wall — and `GenCheck.doorsSane` permits that explicitly (two doors to two
DIFFERENT rooms are two distinct pairs). The washroom pick then asked for an exterior wall and
nothing else, which actively selects a PERIMETER room, the one least likely to have a corridor on any
remaining face.

**The ordering that makes the cut blind is what makes the fix trivial: by `assignRoomThemes` the
doors are real objects, so ask them.** A candidate now also needs `getRoomDoors` to return exactly
one door, cut BY this room (`roomID1 == room.id` — a neighbour's door into our shared wall is in our
list too, and its delta names US), whose far cell is `TEMP_BUILDING_CORRIDOR`. **No candidate passes
means no washroom**, which a compound already has to survive — the roll is 60% — rather than relaxing
onto the fault. Measured: 1.19 → **0.89 washrooms per compound**, and that is the whole cost.

> The `length == 1` half of that test is **superseded by "A lab building always has a toilet"** at the
> end of this file: counting every door in the room's walls rejected 21.8% of lab structures for a
> door the washroom never cut. It counts the room's OWN doors now, and the 60% roll is gone.

`FacilityToilet.toiletPartition` has assumed both since it was written: it takes the FIRST door of
the room and lays the T's bar, lobby and stem against that wall, so a second door on another wall
opens into a sealed half. The assumption is true by construction now instead of by luck.

**A LATE DOOR IS A SEPARATE PASS AND NEEDED ITS OWN GUARD.** With the filter in, 20000 seeds still
failed 4 times: `connectRooms` runs after `finalizeTiles`, floods the grid and cuts into anything
unreached, and the washroom is the far side of that cut, not the near one. `cutDoorToReached` now
refuses a far cell in a `ROLE_TOILET` room on its first, non-duplicate-allowing pass — and takes it
on the last one, where the alternative is a room nothing can walk into. `isRole` walks `allRooms`
and not `roomByID`, which holds only the building being generated and answers `null` at the end.

New invariant `GenCheck.washroomSane` over the FINAL door list. **Do not filter it on `_Door.skip`**:
`fixDoors` deletes the door it drops and sets `skip` on the one it KEEPS, so a skipped door is a live
door — filtering reported every washroom as having none.

## A bay rhythm out of phase with the room corners, and two benches crossing

Reported as tables intersecting diagonally in a small room, and they really do intersect. Every test
in `render.facility.FacilityTables` is one of the four axis steps — there is no diagonal probe in the
file — so two cells meeting only at a corner each grow their `BENCH_LIP 0.2` INTO the other: the caps
overlap in a lip-squared square, the edge bands cross, and both cells emit full casework right up to
the shared point.

It is the rhythm and not a placement bug. In a room narrower than `NARROW_ROOM` the runs take
two-cell bays, and on a 3x3 the top run's bay ends one cell short of the corner while the right run's
first row is the one `glazeWall` skips — leaving a table at `(x1+1, y1)` and another at `(x2, y1+1)`
with both cells between them bare. **Measured: 1387 of 2000 seeds carried at least one such pair.**

`FacilityRooms.cullDiagonalTables`, called per room right before `clearTableSpots`, drops a table
cell with **no orthogonal table neighbour and at least one diagonal one**, writing the cell back to
`TEMP_BUILDING_ROOM` and removing any decoration `bench()` had stood on it. Runs are safe by
construction — a cell with any orthogonal neighbour is part of one and is never touched — so what
goes is always the loose one. The row-major scan picks which of a loose PAIR goes and is stable for a
seed; once it is gone the other has no diagonal neighbour left and stays, which is what the report
asked for.

**It has to be the generator and not a render pass.** `m.table` is derived from the persisted tile id
(`FacilityModel.tableOf`), the 2D view reads those ids directly and `GenCheck.clueSpots` counts bare
bench cells — a render-side drop desyncs all three. New invariant `GenCheck.tablesSane`, 0 failures
over 20000 seeds; `spawns/decoration` 151.4 → 150.3 is the whole cost.

### …and it asked the wrong question, so 20000 clean seeds meant nothing

> SUPERSEDES the two paragraphs above from `cullDiagonalTables` onward.

Reported again at `27,14`: still two worktops crossing at a corner. The cull above tests a CELL — no
orthogonal table beside it, at least one diagonally, i.e. **is this cell LOOSE** — on the reasoning
that a cell with a neighbour is part of a run and should be left alone. Two table RUNS whose ends
meet corner to corner have an orthogonal neighbour EACH, so neither was ever a candidate. And
`tablesSane` carried the identical `continue`, so the oracle asked the same wrong question and
reported 20000 clean seeds over a fault that was on screen.

**The fault is a property of the PAIR, not of either cell.** Two worktops touch corner-only when they
are diagonal neighbours and BOTH of the two cells they share are bare:

```haxe
table(x, y) && table(x + dx, y + dy) && !table(x + dx, y) && !table(x, y + dy)
```

That is exactly what `FacilityTables` cannot see, stated directly. Both the check and the cull now
run it, over the two diagonals with a HIGHER y only — the other two are the same pairs seen from
their far cell, and testing both ends does the work twice.

**Measured with the corrected check: 1503 of 2000 seeds**, against 1387 for the loose case alone —
so the blind spot was real but not the bulk of it. The bulk was there all along and the old cull did
catch it; what it could not catch was the last ~8% of seeds, which is enough for a player to hit one.

The cull now loops the row-major scan until a whole pass finds no pair (dropping a cell can expose
one that was hidden behind it; removal only shrinks the set, so it terminates) and drops the cell
with FEWER orthogonal table neighbours — the loose end of the shorter run, so a long bench keeps its
length and the stub beside it goes. A tie takes the diagonal partner, which is the later cell in scan
order and so stable for a seed.

**0 failures over 20000 seeds; `spawns/decoration` 150.3 → 149.0.**

> The lesson is not about tables. An invariant written from the same mental model as the fix it
> guards will agree with the fix and prove nothing. `washroomSane` was written the other way round —
> over the FINAL state, asking the outcome rather than restating the filter — and caught a real
> late-door fault four seeds in 20000. This one restated the filter.

## An optional argument whose default is a real answer, and an oracle with no opinion on furniture

A washroom came back with a bank of MACHINES standing next to its cubicles.

The mechanism is one line. `RoomBlock.slot` dresses every room's leftover bays, and a washroom has
plenty: `FacilityToilet.zones` demands only the stall run and the basin run, so everything else falls
through to that shared filler. The filler called `FacilityRooms.addFitting(state, x, y)` — and the
signature was `?role: String`, defaulting to `Deco.BLOCK_LAB`. **A caller that simply did not think
about the room was handed the laboratory's own furniture list, silently, compiling correctly.** An
optional argument whose default is one of the real answers cannot be told apart from a deliberate
choice; the role is required now, so the compiler asks.

**The interesting half is why nothing caught it.** `grep 'deco\|fitting' src/gen/GenCheck.hx`
returned nothing at all. `washroomSane` is about door topology, `spawnsSane` is about two objects on
a cell, and no check in the oracle had ever asked what a decoration IS. There was no wrong question
here, as there had been with the diagonal tables — there was no question.

`GenCheck.decoBlocks` is written **against the finished grid and not against the dealer**, and that
is the load-bearing choice. Three separate arms put fittings down:

  * rolled through `Deco.pick`, which is the only one that consults `_DecoPlace.blocks`;
  * outright by kind through `FacilityRooms.placeFitting` (the lounge, the washroom's own T, the
    machinery zone), which never looks at `blocks`;
  * raw row lists — `Const.CHEM_LABS_DECO_FLOOR_HIGH` — which consult no table whatsoever, and whose
    row 8 cols 4-8 **is** the machine.

A check written against the dealer would have passed all three. Reading the grid (frame ->
`Const.placeOf` -> `blocks` -> the role of the room the cell falls in) holds however the decoration
arrived, including out of a savegame.

### `blocks` holds two kinds of string, and the table never says which

The first cut of the check reported **6,096 failures over 2000 seeds** and every one of them was
correct furniture. `'lab'`, `'cabinet'` and `'toilet'` are room ROLES — what a `_Room` actually
carries. **`'lounge'` is a ZONE**: a corner of an office that `RoomBlock` furnishes outright, and no
room is ever a lounge, so by the check's reckoning every sofa was standing in a `'cabinet'`.

So the predicate skips any entry that names no room role at all — such an entry is template-placed
and its `blocks` is not a claim about rooms. Worth knowing before adding a table entry: put a room
role in `blocks` and the oracle will hold you to it; put a zone name there and it cannot.

Measured after: **0 failures at 2000 and at 20000 seeds.** The fault on screen had been generated
before the fix — a decoration is persisted game state (`imageRow`/`imageCol` on the object), not
something the renderer recomputes, so a washroom built by the old code keeps its machine forever and
only a regenerate clears it.

## Invariants downstream re-derives from the grid

These break **silently, with no compile error**, because the consumer reverse-engineers them out of
tiles rather than being handed them:

- `AreaGame.gate()` re-derives the checkpoint from "a plain 4x2 hole of alley through the sidewalk
  band beside the road" — the `entryway` child of `parking` must keep producing exactly that, the
  pavement band must run the FULL width so nothing else qualifies, and the parking plot must be ON
  the frontage so the row inside the mouth is open lot. The mouth stays `TILE_ALLEY` while the plot
  behind it is `TILE_PARKING`, which narrows that scan to the mouth alone. Asserted by
  `GenCheck.gate`
- `FacilityModel.isParkPath` needs the park's 2-cell walkway path (slack `PATH_MAX = 4`). Asserted by
  `GenCheck.parkPath`
- `Surf.LOT` is "any open asphalt" and covers `TILE_ALLEY` and `TILE_PARKING` alike. The CAR PARK is
  the second of those and nothing else — `FacilityPaint.bays` and `FacilityCars` gate on
  `FacilityModel.isParking`, so a parking plot that stopped carrying the mark loses its bays and its
  cars silently. Asserted by `GenCheck.parkingSane`
- `AreaGame.isLot` and `GenCheck.gate`'s flank test must keep accepting BOTH ids: the mouth is alley
  and the two rows inside it are car park, so a test on one id alone draws no booth at all
- the mouth's lot-side row is `TILE_ALLEY_UNWALKABLE` across its whole width — the boom's own line.
  Both mouth scans (`AreaGame.isMouth`, `GenCheck.isMouth`) must count it as mouth or the hole reads
  one row short. Asserted by `GenCheck.gate`
- room ids are unique across the whole area and never restart per structure
- `FacilityAreaGenerator.repairRooms` guards on a room **count** — it must not start firing on
  freshly generated areas
- `TEMP_BUILDING_VENT == TEMP_BUILDING_WINDOW == 18`; do not renumber the temp alphabet
- bench tiles are clue spawn points (`AreaGame.initSpawnPoints`), and `TABLE_CLEAR_MIN` of them must
  stay bare or the facility stops handing out clues
- `_Room.role` is **not** the theme record — the floor tile is, read back by `FacilityModel.surfOf`
- pass order matters: `FacilityRooms.assignRoomThemes` before `FacilityBuilding.makeWindows`;
  `ParkBlock`'s clumps last in the park; `generateRoomContents` writes final ids that
  `FacilityGen.finalizeTiles` must skip

## Known, not fixed

`CorpAreaGenerator` is a near line-for-line fork of the facility's building pipeline
(`subdivideLargeRooms`, `makeDoors`, `fixDoors`, `makeDoorToCorridor`, `drawSideCorridor`,
`makeWindows`), and it writes `state.rooms` where the facility writes `allRooms` — so a corp area
records its **last building's** rooms only. That is the bug `repairRooms` was written to fix for the
facility, and corp has no equivalent. Left alone deliberately; it is the obvious second caller for
these primitives.

**`Const.FACILITY_FITTING_PCT` is now a coin flip between two distributions over the SAME frames.**
It reads as "how often a high floor decoration comes out as a 3D fitting rather than a plain sprite",
and that was true when it was written. It is not true now: every frame of
`CHEM_LABS_DECO_FLOOR_HIGH` (row 8 cols 0-11, row 13 cols 0-6) and of `CHEM_LABS_DECO_FLOOR_LOW`
(row 12 cols 0-10) is in `FACILITY_DECO`, so both arms of that 60% deal a fitting — the only thing it
still chooses is UNIFORM-PER-KIND against UNIFORM-PER-ATLAS-ROW. Collapsing it to one `Deco.pick` is
a one-line deletion, and it moves the furniture mix (five machine icons stop outweighing two shelving
icons on the row-uniform arm), so it wants a look in the game rather than a digest.

## A lab building always has a toilet, and the door test was counting the wrong doors

"lab building has to have at least one toilet". Two things stood between that and the code, and only
one of them was the dice.

**THE DICE.** `assignRoomThemes` ran `state.area.chance(60) && wash >= 0`, so two lab buildings in
five came out with no washroom. Gone outright — the roll is exactly the fault `_GenDemand`'s own
header is written about.

**AND THE DOOR TEST WAS ASKING ABOUT DOORS THE ROOM DID NOT CUT.** `washroomDoor` required
`getRoomDoors(room).length == 1`, and that list is accretion — a room's own door plus one for every
neighbour whose roll landed on the shared wall (see the section above). So a room with exactly one
corridor door of its own was rejected for a door belonging to the lab next to it. **Measured over 795
lab structures on 400 seeds: 21.8% had no candidate at all, and every single one of those failures
was the door test** — `exteriorWall` passed somewhere in all 795. Counting only the room's OWN doors
(`roomID1 == room.id`) takes that to **1.6%**.

A door the room did not cut is not a way in to the washroom in any sense `FacilityToilet` cares
about; what that file needs is the one wall to lay its T against, and that is the room's own. So
`toiletPartition` skips a door whose `roomID1` is not this room — it took the FIRST door in the list
before, which on such a room laid the lobby against an opening the washroom does not own — and
`GenCheck.washroomSane` asserts the same set: exactly one door cut BY the washroom, onto a corridor,
with a neighbour's door in a shared wall allowed. **Net: `nodes/room-washroom` 0.93 → 1.93 per
compound** at 2 lab buildings each, i.e. 96.5% of them, over 3000 seeds with `unreachableRooms` still
0. The residual is the 1.6% with no candidate, and it is left there rather than relaxed: the next tier
down is a room whose only door opens into a LABORATORY, which is the thing this test was added to
stop.

**AND IT UNCOVERED A LATENT FAULT IN THE LATE DOOR CUT.** 3000 seeds failed twice —
`two spawns on cell 71,29 (door)` — and the collision was a **VENT** and a door. `cutDoorToReached`
tested only the TILE (`cells[x][y] != Const.TILE_BUILDING`), and a vent is an object standing ON a
`TILE_BUILDING` cell (see `render.facility.FacilityGeom.wallMounts`), so the repair cut a doorway
through the grille. It asks `ctx.hasObjectAt` now. Pre-existing; guaranteeing the washroom is only
what made the pass fire on those two seeds.

## The tree is not persisted, and what `go block` can offer because of it

`gen._GenNode`'s own header is the decision: the tree is in-memory only, because "the renderer, the
lighting and the missions all re-derive what they need from the saved cell grid" and `_Room` already
carries the one piece of per-room intent that has to survive a save. That still holds — and it is
what shapes the `go block [kind]` console command, which came out of wanting to look at a named
block quickly.

Nothing can read the tree from a loaded save, so `go block` derives its list from
`render.facility.FacilityModel.fromArea` (the grid) plus `area.generatorInfo.rooms`. What that
recovers exactly: **`building` / `hangar`** (structures), **`room-lab` / `room-office` /
`room-washroom`** (rooms, named through `RoomBlock.kindOf` so the command and the tree above agree),
**`study-pad`** (from the SHAPE of the unwalkable concrete, `FacilityModel.findPads`), and
**`park` / `road`** (surface classes). What it cannot: every ROOM ZONE and every HANGAR ZONE —
`bay`, `slot`, `lounge`, `stall-run`, `hangar-machine` and the rest write furniture and floor, not a
mark that says which zone laid them. **`parking` and `yard` DO come back separately now** — they were
one block called `lot` until `Const.TILE_PARKING` gave the car park a mark of its own.

Full detail, and the two traps it cost to find, in [`debug-surface.md`](debug-surface.md).
