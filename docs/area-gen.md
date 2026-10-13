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
  │   ├ hangar-slot          the filler: floor clutter, and mostly nothing
  │   └ hangar-generator     2-3 power generators on the OPEN FLOOR, two cells in off a corner.
  │                          CARVED after the deal (racked corners first, a clear cell all round
  │                          and off the pad/banks), mean 2.49 per shed over 3000 seeds
  └ yard                     the filler kind: whatever nothing claimed

building
└ room-lab | room-office | room-washroom | room-storage   one per room the corridors cut out
  │                         → Quota.deal() over its bays, same dealer as the plots
  ├ bench | workplace        a run of worktop; `workplace` is the office's name for it
  ├ machinery | server-rack-bay   a run of ONE fitting against masonry
  ├ lounge                   a two-seater with a low table in front — the only depth-2 zone
  ├ stall-run | basin-run | lobby  the washroom's three
  ├ shelf-run | pallet-bay | aisle  the store's three — racking, pallets, and a bay kept BARE
  ├ slot                     the filler: a bay no demand's `must` accepted
  └ vent-cap                 the lone window a run ended on, pushed LAST
```

The CORP OFFICE is the same machine at a different shape, and the difference is worth stating up
front: **a compound is open ground that gets CUT into plots, a tower floor is one plate whose rooms
are already carved by its corridors.** So there is no `Subdivide` at the corp area level at all —
the root has exactly one child — and what `Quota.deal` is handed is the ROOMS.

```
area
└ plate                     the tower floor: wall ring, pavement apron, lift, corridors, rooms
  ├ elevator                the lift car. A BLOCK, not a room: 3x3 car, 9 objects.Elevator cells,
  │                         concrete floor, four posts, glazing on three sides, one door in the
  │                         fourth. Nothing in it is dealt, so nothing is dealt under it. It stands
  │                         OUTSIDE the wall ring, in the pavement band
  └ room-cubicle | room-meeting | room-kitchen | room-exec | room-toilet | room-servers
    | room-archive | room-reception | room-security
    ├ desk-run              open plan: one 3x1 desk, a computer and a chair
    ├ pod-row               the cubicle farm: two rows of desks BACK TO BACK, three rows to a
    │                         band (desk, desk, aisle) and no cell spent on the partition -
    │                         render.corp.CorpFurniture panels every boundary a pod owns
    ├ rack-row              the server room: a rank of cabinets with an aisle beside it
    ├ table                 the boardroom table, or the executive's own desk
    ├ counter-run           the kitchen's 2x2 tables
    └ stall-run | basin-run the washroom's two
```

**The STAIRS are not a block and the lift is.** The test is whether anything about the thing is
laid out: a lift is a fixed 3x3 assembly with a determined door, floor and glazing, and stairs are
one object with a model on it. A spawn intent is the right size for the second. The model takes FOUR
sealed cells (`CorpTemp.stairsCells`: the one against the end wall, its twin on the right facing
the wall, the cell toward the corridor and that one's twin), and the object stands on the third, off
the wall, used from beside it (`Stairs.canActivateNear`). They are written as the temp `BLDG_WELL`
AFTER the inner-wall pass (or the room behind is never walled off) and BEFORE `makeDoors` (or a room
opens onto the well). Not the final carpet twin: 215 is inside the room-id range and reads as a room.
`AreaGame.migrateCorpStairs` seals them on older saves and steps the object off the wall.

**A zone writes no cells of its own.** The template that pushed it has already laid them; the node
is there so the finished tree records WHERE the furniture went, which is what `--stats` counts.

**Corp is entered by LIFT, so both flood fills start there.** `GenCheck.reachable` takes an optional
seed list and `CorpConnect.floodWalkable` uses the lift cells — a rim flood reaches exactly zero
cells on a tower floor, because the plate is ringed by unwalkable void, and reports every room as
sealed.

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
| `gen/blocks/CorpBlocks.hx` | the corp floor's node kinds, its room quota, and `assign()` |
| `gen/blocks/ElevatorBlock.hx` | the lift core — car, posts, glazing, door |
| `gen/blocks/OfficeBlock.hx` | the corp ROOM level: which template fills a dealt room |
| `gen/blocks/LabBlocks.hx` | the underground lab's node kinds and room roles |

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

### The corp office, after its own port

`game/CorpAreaGenerator.hx` was 1626 lines in one class and a near line-for-line fork of the
facility's pre-block-tree pipeline. Same two measurements, same move.

| file | what it is |
|---|---|
| `game/CorpAreaGenerator.hx` | the LIVE adapter and nothing else: wrap the grid in a ctx, trace `corp WxH seed N`, drain the spawns |
| `gen/corp/CorpGen.hx` | `build()` — the real entry, the one the oracle calls — and `finalizeTiles` |
| `gen/corp/CorpTemp.hx` | the `TEMP_*` alphabet, the temp→final map, the `ROLE_*` strings |
| `gen/corp/_CorpState.hx` | what a floor looks like mid-build. Not persisted |
| `gen/corp/CorpBuilding.hx` | the plate: wall ring, lift wall, corridors, subdivision, doors, glazing |
| `gen/corp/CorpConnect.hx` | the grid-half repair — cut a door into any room the LIFT cannot reach |
| `gen/corp/CorpRooms.hx` | the seven room templates and the two wall-dressing passes |

**The dice ladder is gone.** `if small { kitchen 85% else meeting 85% else solo 85% else a flat
33/33/33 } else work` is the fault `_GenDemand`'s header is written about, and it meant a floor
could come out with three kitchens and no meeting room, or with no small room and therefore nothing
but open plan. Expressed as a quota, measured over 1000 seeds: **cubicle 1.99, exec 2.59, meeting
1.95, open 2.73, kitchen 1, servers 1, toilet 1** over 12.26 rooms — every floor has one of
everything, and open plan is the FILLER rather than a demand, so a floor carved into exactly the six
rooms the mins want correctly has no open-plan space at all.

**THE CUBICLE FARM DRESSES NO WALL, and that is deliberate.** Every other template hands
`decorateWalls` its two long walls; `cubicle` hands it nothing, because `decorateWalls` forces a
dressing at every CORNER whatever the roll says and each one is an unwalkable cell — reported from
the game as *"all corners are unwalkable, but they're empty"*. Reserving x1/x2 for it also held the
pod run at `w - 2`, which is one desk column per side. The farm's furniture is its desks, and what
dresses it is what `render.corp.CorpClutter` pins to the panels.

**Two new floor tile ids, and they are ALIASES.** `Const.TILE_FLOOR_CUBICLE` and
`TILE_FLOOR_SERVER` are `OFFSET_ROW12 + 13/14`, appended and never inserted because the grid
persists raw ints, and `tiles.Default.getIcon` draws them as carpet and concrete — the same trick
`TILE_PARKING` uses. They exist so a reader of the SAVED GRID can tell a cubicle farm from the
corridor it opens off and a server room from the lift lobby it shares its concrete with. The
washroom needed no new id: `TILE_FLOOR_MARBLE2` was already in the alphabet and no room had ever
laid it.

#### A blocked door the repair could never replace, and eight fittings deleted trying

`CorpConnect` is `FacilityConnect.connectRooms` with the flood moved to the lift, and it went from
**190 sealed rooms in 1000 floors to 0 in 3000** in four steps, three of which were real bugs:

- **the flood must start at the LIFT.** From the rim it reaches nothing: 190/1000 → all of them.
- **glass is cuttable.** `cutDoorToReached` tested `== TILE_BUILDING`, and a corp room is walled in
  curtain wall and office glazing as often as in blockwork, so most of the ring was skipped and a
  room with a corridor down one whole side reported "nothing to cut". 190 → 33. Including the OUTER
  glazing took it to 7 and cannot put a door into the void, because the far side of a cut has to be
  a cell the flood already reached and nothing outside the tower is walkable.
- **room id 0 is not a room, and the duplicate test must exempt it.** `doorsSane` says in as many
  words that several doors onto corridors are intended. Without the exemption a room already
  holding one BLOCKED corridor door could never be given a working one: `cut(false)` refused it as
  a duplicate forever, `clearWayToReached` succeeded every round on the room's own furniture, and
  the `||` chain therefore never reached the `allowDuplicate` pass at all. Seed 219 deleted **eight
  fittings** over eight rounds and stayed sealed. 7 → 1.
- **and the loop's other exit was silent.** `for (round in 0...rooms.length + 1)` reports when
  nothing could be opened; it said nothing at all when every round DID open something and the room
  was still sealed, which is exactly the shape the bug above had. It reports both now.
- the last resort, **1 floor in 3000**, is a second door between two rooms — and it RETIRES the
  first one (`skip: true`). Reaching there means the pair is joined by a door the player cannot
  use, so the old record is not a live connection, and two live doors is what `doorsSane` rejects
  and what a mission's "lock the first door of this room" silently misses.

### The military base, after the 2D one went

The old base was 40-50² of walkway with solid building rects and five sewer hatches. It is now a
fenced block tree inside a wild margin, entered and left on foot. `make gen --type military`.

| file | what it is |
|---|---|
| `game/MilitaryAreaGenerator.hx` | the LIVE adapter: the band's `AreaGenerator.wildMix`, a ctx, `MilitaryGen.build`, the drain |
| `gen/military/MilitaryGen.hx` | `build()` and the public grid helpers (`fence`, `fenceOf`, `outside`, `vehicle`) |
| `gen/blocks/MilitaryBlocks.hx` | the split profile (12/26/32) and the quota inside the fence |
| `gen/military/MilitaryZones.hx` | the room kinds (one per role), the bays a room divides into, and each kind's zone quota |
| `gen/military/MilitaryRooms.hx` | each zone's furniture, as `Const` row-20/21 tiles (and the armory's objects) |

**The order of `build()` is load-bearing**:
1. Blank the grid to `TEMP_ALLEY`.
2. Plan and walk the tree inside the fence rect. BUILDING and HANGAR delegate to `FacilityGen.fill`.
3. `finalizeTiles`. **Everything after it writes FINAL ids**, because the finalize remaps every id
   under 112 and the wild tiles live there.
4. `perimeter`: the closed ring, a 2x2 tower one cell INSIDE each corner (on the EDGE lot, so it
   never meets a plot), and 1-2 `TILE_MIL_FENCE_TORN` breaches off the gate side.
5. `road`.
6. `margin`: 16 cells (`MARGIN`) on the three non-road sides, so the area is 90-100 x 70-80. Scatter is
   rolled on the margin's own cells (a whole-area roll lost about half of them inside the fence) at the
   band's density, floored at `MARGIN_DENSITY_MIN` 0.06, because the plains' 0.025 read as bare grass.
7. `gate`: the 4-wide mouth, which `AreaGame.gate()` and `FacilityEntry.find` derive exactly as on a
   compound. Two `TILE_MIL_JERSEY` barriers stand on the pavement each side of it, leaving the
   pedestrian gap's own cell open. They read as pavement (`Surf.WALKWAY`), so the mouth
   derivation does not see them.
8. `connectRooms`.

The quota is two buildings (HQ and barracks, `fit` deep), a hangar (deep, `fit` away from the gate),
a square helipad, a motor pool near the gate, 1-2 tent camps, 1-2 container depots, and an ENTRY yard.
The rest is yard.
- **The hangar holds the plane and fuel drums** (`HangarBlock.zones`' military branch). The plane is
  stamped by its OUTLINE (`MilitaryGen.plane`, `Const.MIL_PLANE_MASK`: 22 of the 8x7 footprint's 56
  cells for the Meshy jet at 28.0 x 27.0, its nose in the first row, its wing row the whole 8 and its
  tail in the last), nose to the
  door; the full rect was "too much is unwalkable ... a TON of empty tiles".
  Its origin corner is walkable and `MilitaryVehicles.planeNorth` reads the nose back off the stamp.
  `GenCheck` asserts the outline in one of the two turns.
- **A military shed has ONE roll-up door, the plane's footprint wide** (8 cells, cladding either side),
  cut off the same column the plane is stamped from (`HangarBlock.planeCol`). The compound's 3-cell bays
  between posts opened 12 units against the jet's span ("too small for the plane to pass through").
  The compound keeps its bays.
- **Drums** (`TILE_MIL_DRUMS`) take 60% of the wall run's cells off the door wall and out of the side
  door's bay. They are WALKABLE: the cluster stands in the wall's margin and the cell's floor is the
  hangar's (`MilitaryStyle.surfOf` maps them to CONCRETE; the row-19 catch-all had painted yard
  apron). The old `split` guard, which kept a drum only while the floor stayed one piece, went with the
  walkability. No generators: with the footprint solid none ever fitted. Hangar fill 56 → 35%.
- **The helicopter's hull is 1x5 inside its 3x7** ("a whole 1 tile can be removed from all sides"):
  `helipad` stamps `TILE_MIL_VEHICLE` inside a `Const.MIL_HELI_RING` of pad, and the origin corner,
  like the plane's, is walkable. 21 → 5 solid cells a base; `GenCheck` asserts hull and ring.
- **A camp's tents have stores against their long sides** (`TILE_MIL_STORES`, unwalkable,
  see-through): east of a tent 70% of the time and west of it 45%, never in the plot's edge cells and
  never on both sides of one lane. A pair a row apart on the two sides pinched a lane shut on the
  diagonal in the first build's live base. 8.5 cells a base.
- **ENTRY** is a `must` on the gate side's edge, smallest first, filled as yard. `gate()` puts the
  mouth, booth and pedestrian gap inside its span, so the drive opens onto open ground; a building
  straight behind the boom read as a wall at the end of it.
- `GenCheck.militarySane` asserts the boom's columns are walkable for 9 rows in.
- The `must` failed 3 seeds in 2000 at 30 splits, so `MAX_PLAN_TRIES` is 60 (mean 3.5 splits).
- The entry yard took the depot's plot on 90x70 bases (0.22 depots a base to 0). So DEPOT has two
  rows: max 1 before CAMP and max 2 after. The rows share one count, and `GenCheck.quotaMet` caps a
  kind at its rows' largest `max`. The first row is a `min 1` ("make more containers": 0.76 depots a
  base → 1.05, mean plan splits 3.5 → 6.5, none unmet over 2000), and a depot slot holds a container
  95% of the time. The render stacks each 2-3 high (`MilitaryGeom.container`).

**Nothing downstream reads the tree.** The fence is re-derived from the grid by `fenceOf` (the bbox
of fence/torn/tower cells). `AreaGame.isOutsideBase` is that bbox, and the RING COUNTS AS OUTSIDE.
That one helper answers the leave rule, the spawn point and the margin bed. A base saved with no
fence tile is the 2D format and regenerates on load.

**Yard piles are tiles, not scatter.** The crate stacks and drum clusters on the lot's edge were
render-only (`FacilityDebris.spots` drawn by `MilitaryYard.clutter`) over walkable asphalt, and the
player walked through them. `MilitaryGen.piles` now stamps `Const.TILE_MIL_PILE` (unwalkable,
see-through) LAST, after `connectRooms`. A pile goes on a `TILE_ALLEY` cell inside the fence that backs
onto anything not asphalt (a kerb, a wall, a container, a tent row). It keeps the old diagonal stride
and cap (`PILE_STEP` 3, `PILE_MAX` 14) and stays `PILE_GATE_CLEAR` 4 off the boom row. It is skipped
unless its walkable 8-neighbours stay one 4-linked run round it (`keepsLinked`), which is what keeps a
door or a one-cell lane open. The render draws the tile and nothing else, so a base saved before has
no yard piles until it is regenerated. 1000 seeds pass, 14 piles a base.

**Vehicles are footprints.** `MilitaryGen.vehicle` stamps `TILE_MIL_VEHICLE` (solid) over
`Const.MIL_*_SIZE` and names the model by its ORIGIN tile, so the renderer derives only a pose.

**Rooms are the base's own kinds, not the lab's.** `FacilityRooms.militaryThemes` deals them on the
washroom's own tests:
- the latrine first;
- then the biggest room left is the briefing room (HQ) or the mess hall (barracks block);
- then the HQ's armory;
- then one specialist each, only while a plain room is left over: the HQ's COMMS room, and the
  barracks block's MEDICAL bay and SUPPLY store;
- the rest are barracks, in the HQ as well as the block.

The HQ is the building dealt while no safe stands. Its leftover rooms were offices (`room-hq`: desk
runs, filing, desk pairs), reported as "boring and almost the same as briefing", and the kind, its
`desk-run`/`file-run` zones and `ROLE_HQ` are gone: 3.91 barracks a base now. `Surf.HQ`, the office
floor tile and the filing cabinet's render branch stay, since saves made before still hold them.

**A role is a room KIND and a room is ZONES, as in a laboratory.** All nine roles used to be one
node kind, `room-military`, furnished by loops off `room.role`: the tree could not say what a room
held and nothing asserted it. Now `RoomBlock.kindOf` returns `MilitaryZones.kindOf(role)`
(`room-armory`, `room-comms`, `room-supply`, `room-medical`, `room-briefing`, `room-mess`,
`room-barracks`, `room-latrine`), and `glaze` hands the room to `MilitaryZones.deal` in place of the
laboratory's deal. That:
- takes the glazing's window bays back off the node;
- pushes one BAY per straight span of each wall run (`roomWallRuns`, cut by `FacilityToilet.spans`),
  tagged with its wall, `long`/`short`, and `best` (the longest usable wall) or `face` (the one facing
  it), plus one `floor` bay for the middle less a cell all round;
- deals the kind's quota with `Quota.deal`, leftovers to `mil-slot`, and tags the room `unmet` when a
  min fell short;
- pushes `mil-floor` LAST of its zones. It paints the floor once they have stood their furniture,
  while `roomWallRuns` can still tell bare floor from furniture, and before the vent caps `glaze`
  pushes next.

| kind | zones (core first) |
|---|---|
| armory | gun-cabinet, safe-spot (the base's one), crate-island (ONE block down the long axis, 2 deep where it fits and as long as its ring lets it, else 1 deep), locker-run ×2 |
| comms | rack-run (longest wall), console-run ×2 (facing it), desk-island (up to two, 3 cells back to back where the ring fits, else 2; two share the aisle between them) |
| supply | shelving (crate stacks on each bay's two ends), shelf-row, shelving ×2 |
| medical | cot-run ×3 (top and bottom walls first, a cot to a cell there, every other cell on a side wall), doc-desk (an office desk and its chair on a side wall, the rest of the bay cabinets), cabinet-run (a side wall), cot-island (two side by side, else one) |
| mess / briefing | counter-run / map-board (an end wall), table-rows (a mess's run on to the end wall away from the doorway, else away from the counter: `runOn`; along whichever axis seats more, `messRows`; four deep, one bench along the table) |
| barracks | bunk-row (out from a long wall, glass included; both when 7+ deep), bunk-along (the facing wall at 5-6 deep, or the first wall that takes three when too shallow for rows) |
| latrine | cubicles ×6 (a toilet in each), sink-run ×4 (two basins a cell, a mirror over each), urinal-run ×4 and shower-run ×3 (the end walls first, a tiled separator wall each side of a shower), bench-island (3 cells where the ring fits, else 2) |

A min is only asked when the room can hold it: a barracks falls back to the other long wall and then
the end walls. 2000 seeds, 0 `unmet`.

**A WALL BAY NEVER TOUCHES GLASS.** `roomWallRuns` only tests the cell straight behind each cell, so a
corner cell with the next wall's first pane beside it passed. The comms room stood a radio rack there,
and `MilitaryInterior` then backed it ONTO the glass, because `isWall` counts a window and the window
was the first side it tried. The bays drop any cell with a window or a doorway of any kind beside it,
and the render picks the backing wall with `isSolidWall`. `GenCheck.militaryRooms` asserts no piece
of a base room has a window beside it, no room met its quota short, and every room cell is floor or
the base's own furniture (no lab tile or decoration through a filler). It cost 2.3 cells of a
barracks (16.2 → 13.9), the corner bunks beside a window, and the mil-slot bays left over are where
the room props stand.

**Except a medical bay's cots, which lie under the sill** ("they're allowed in front of the windows and
they can be on adjacent tiles - but vertically for better readability"). For a medical room `deal`
asks `roomWallRuns(state, room, true)`, which also takes a cell with a window BEHIND it, and keeps the
cells with one beside them. `MilitaryRooms.glass` keeps every piece but the `low` ones (cot,
stretcher) off those cells in `line` and `slot`, and `GenCheck.militaryRooms` exempts the same two.
The cots go on the top and bottom walls first, where `MilitaryInterior` lies them down the screen,
and stand on every cell there; on a side wall they lie across it and keep every other cell. The
island cots stand two side by side, also down the screen. `MilitaryInterior` backs a low piece onto
glass (`backing(..., glass)`) and stands it on the masonry's face line, (WALL_T - GLASS_T) / 2 out
from the glazing (`sill`). Medical fill 9.5 → 15.7 cells a room. A `mil-slot` whose first prop finds
no cell now tries the next (the IV stand will not go in front of glass; the stretcher went without).

**And a barracks' bunks and a mess hall's rows stand BESIDE glass** ("has one more slot for bed near
the window", "can be in front of the windows"). **A barracks takes the glass-backed cells as well, as a
medical bay does** (`roomWallRuns(state, room, true)`): a 6x4 barracks whose bunk wall was windows but
for two masonry cells stood ONE bunk, with "clearly room for two more" either side of it. A bunk row now
stands against the glass and a bunk laid along it with its footlocker after it ("allow bed+chest along
the windows as well"); the `g<wall>` glass bays that alone took the latter are gone, the wall bays hold
both. Its wall lockers stay off the glass, and `MilitaryInterior` puts a bunk's head at a window as at
masonry (`isWall`). 1000 seeds: barracks fill **33.9 → 42.2** cells a base, `zoneEmpty/bunk-row`
**0.3 → 0**, lockers 9.9 → 10.9. A mess's table rows run on from their end cell to the end wall with no doorway
in it (`MilitaryRooms.runOn`), a whole cross-section at a time while every cell is `free`, taken back
if the floor seals; the near end keeps its two cells. `MilitaryRooms.besideGlass` is the set
`GenCheck` exempts: the `low` pieces, a bunk, a footlocker, a mess table and a bench.

**A latrine takes no ribbon: it gets the washroom's light wells** ("latrines should not have normal
windows"). `RoomBlock`'s military branch runs `FacilityToilet.toiletWindows` (a well on every other
cell of one exterior wall, `TEMP_BUILDING_WINDOW_HIGH`) and glazes with `glass` false, as a store
does. A well is outside `nextToWindow`'s range, so every wall cell is a bay, and the render backs a
piece onto one (`MilitaryInterior.backing` accepts `Wall.WINDOW_HIGH`). `GenCheck.militaryRooms`
stopped counting `TILE_WINDOW_HIGH` as a window it had never met. Latrine fill 10.4 → 12.3 cells.
With the urinals, showers (row 21 +14/+15, both walkable, stood in the wall's margin) and the bench
it is 23.0 ("pretty empty for such a large room"). The bench is the one that rarely lands: 1.48 of a
base's 1.98 latrines are too small for it and its ring once the four walls are taken.

**The bays no zone wanted (`mil-slot`) take the room's STANDING PROPS**, one of each at most, on
the free cell nearest the bay's middle (`MilitaryRooms.slot`, row 21 +6..+12): a gun locker (armory
only, `TILE_MIL_GUN_LOCKER`: furniture wearing the gun cabinet's glb, no loot. It was a rifle rack,
reported from the barracks as not belonging there and then from the armory as "looks like crap"), ammo cans (armory, store), jerrycans (store), a flag stand (briefing), a water cooler
(mess, comms), an IV stand and a stretcher (medical). Two traps, both caught by `floorReachable`:
- the slots are walked in wall order like every bay, so a rifle rack on the top wall stood BEFORE the
  bunk row off the left wall, which then boxed two cells in behind it. `MilitaryZones.deal` moves the
  slot bays to the end of the room's children;
- a prop is a piece no zone planned round, so `free`'s local pocket test is not enough: one stood in
  a barracks' aisle (3208 cells cut off over 500 seeds). It stays only if the room's bare floor is
  still ONE piece (`sealsOff`). "Reachable from some doorway" was tried first and failed on seed 10:
  two adjacent barracks each split by a prop left pockets that only opened onto each other.

Fill after the props (2000 seeds): armory 11.5, barracks 29.7 a base, briefing 12.3, comms 7.8,
latrine 10.4, medical 15.7, mess 15.5, supply 9.4 cells a room. With the armory's one deep block (its
ring may hold a locker or the safe: each stands in its wall's margin on a walkable cell, and the safe
in a ring corner kept the run two cells short), the bunks beside glass and the mess rows run on:
armory 18.1, barracks 34.6, mess 21.3. The comms desk island stands three
cells long where its ring still fits ("one more doubled table can be spawned in the center" of a 5x5
room), two where it does not, and a room with the floor for it takes a second, the two sharing the
aisle between them (an 8x6 room "has enough room for second row of doubled tables"): `islands`
already lets two rings overlap, since a ring cell stays bare. Comms fill 7.8 → 8.1.

`--stats` also prints `nodes/<zone>` and `zoneEmpty/<zone>`. A desk-island is empty in a room too
narrow for one, 0.08 a base.

**A store is shelving ROWS, not crates in the middle** ("looks way empty because a few crates are in
the middle"). `shelf-row` is the store's floor zone: a row on every other line across the room from
the second in off each side wall, so each has an aisle either side, from the second cell in off each
end wall, so a cross aisle stays at both. `MilitaryRooms.lines` lays them out both ways and
`shelfRows` takes the way that stands MORE shelving, the more rows on a tie: a 7x6 store along its
long axis has room for one row of 3, across it for two of 2 ("there's enough space for two rows
here"). A row is `Const.TILE_MIL_SHELF_ROW` with a crate stack on its far end when it is 3 or longer,
and `MilitaryInterior` stands TWO units back to back in each of its cells, one facing each aisle.
It goes back to bare floor if it would split the room (`sealsOff`), and a room too narrow for one
takes crate islands instead (`zoneEmpty/shelf-row` 0.07 a base). Wall shelving puts a crate stack on
each end of its bay. Supply fill 8.9 → 9.3 cells a room; the rest of the base moved by under 0.9.

**A piece reached from its front keeps a bare cell there** (shelf, filing cabinet, medical cabinet,
radio rack and the standing props, `MilitaryRooms.facing`). Jerrycans stood with a crate stack in
front of them and ammo cans in front of a corner shelf. `walled` (line, slot, wall shelving) wants a
bare cell on the far side from some wall the piece backs onto, and `free` refuses a cell that would
take a facing neighbour's LAST one, so every filler respects it. The corner shelf was half the bug:
the render tried the end wall first and stood it facing into the shelf beside it, so
`MilitaryInterior.backing` now prefers a wall with open floor in front. `GenCheck.militaryRooms`
asserts every such piece against a wall has bare walkable floor in front, not another piece.

**And its OWN cell is walkable** — the corp's `WALL_HUGGERS` lesson, reported here as "is near the
wall and tile in front is unwalkable, tile 58,40": the front rule above answered the wrong cell. A
wall shelf is 1.5 deep and stands against the slab's face, which is a unit into the WALL's cell, so
it covers half a unit of its own and the player sees a whole tile of bare boards before it they
cannot step on. `tiles.Default.TILE_WALKABLE` now passes every piece one cell deep at a wall: the
radio rack, wall shelf, filing and medical cabinets, the basins, the six standing props and the mess
counter (2.36 deep, so 65% of its cell read as bare tiles: "counter has unwalkable tile in front of
it"; `facing` keeps its front clear). Not the
console (its chair fills the cell), a crate stack, a cot, a stretcher, a bunk, a table or a store's
shelf row, which is a separate tile for exactly this reason. `roomUsed` counts a walkable piece as
used. A save from before has its rows as wall-shelf tiles, which now walk through.

**Rooms open onto corridors, not into each other.** `makeDoors` rolls each room's door over its whole
ring, so one landed in the wall a barracks shares with the store ("supply room <-> barracks door
should not be there"). `FacilityConnect.sealRooms`, the base's first theming step, walls up every
room-to-room door and runs `linkClusters`, which cuts a corridor door for whatever that strands and a
room door only for a room with no corridor wall at all (`roomDoors`, 0.33 a base).

**Every room of a base but its barracks is entered from a corridor and through nothing else**
(`FacilityConnect.passedBy`; "should have a single door into corridor", "should only have a corridor
door", "supply, armory, mess, briefing also need the same"). The latrine keeps the washroom's own
test. The rest take the first room left (the hall a 5-deep one first) with a corridor door of its own
whose other doors can be walled up stranding nobody (`FacilityConnect.strands`, a door-graph walk
from the corridor without the room; `FacilityRooms.bay`), and `FacilityConnect.oneDoor` walls up the
rest. Neither `linkClusters` nor `connectRooms` cuts a door into any of them, and
`GenCheck.washroomSane` holds them all to the lab washroom's terms.

**With no such room the building goes without** — measured over 3000 bases, buildings with no room
for the kind: supply 90 of 2238, comms 76 of 2224, medical 11 of 2995, briefing 8, mess 5 of ~3000.
Per base: supply 0.75 → 0.72, comms 0.74 → 0.72, the rest unchanged. **Except the armory**, which
holds the base's one safe (passed over, 3 bases in 3000 had none and the next building dealt itself a
second HQ): with no room left it takes the hall's, and the hall looks again (8 HQs in 3000).

The comms room was dealt the biggest room left with no door test at all, and `washroomSane` only ran in
the FACILITY runner, so nothing saw it: asserted on the base, 173 bases in 3000 failed (a comms room
entered only from the barracks behind it, or walked through to reach one). The strand test is what
the "corridor door" test alone missed: walling up a comms room's link stranded the barracks behind it,
and `connectRooms`' duplicate pass then cut it a way back in through the comms room or the latrine.

**The briefing room or the mess hall is the biggest room left that is 5 deep both ways**
(`FacilityRooms.HALL_DEEP`), else the biggest. The first regenerated base dealt a 16x4 hall, and four
deep `tableRows` stood a line of tables with no bench. Four deep now gets one bench along the table,
with an aisle either side. Mess hall use 21.1 → 21.5%.

**No room is 4x4 or smaller** ("they can't contain anything useful"). Before doors are cut,
`FacilityBuilding.mergeSmallRooms` knocks each one through into the smallest neighbour that matches it
edge to edge. One walled in by corridors (7 seeds in 2000) opens onto the corridor that runs the length
of one of its walls, as an alcove (`alcove`). 12.49 → 11.89 rooms a base, all of the drop barracks;
`GenCheck.militaryRooms` asserts it.

**Furniture never seals a cell.** `MilitaryRooms.free` refuses a cell beside a doorway, and a cell
that would leave a bare neighbour with no OTHER bare neighbour. Counting the doorway as an exit is
what sealed seed 455's whole office: a desk and a cabinet boxed in the cell inside the door. The
military run now calls `GenCheck.floorReachable`, which it lacked, and 24 of 400 seeds failed on it
before the guard went in. The oracle also asserts at least 1 safe and lockers + cabinets >= 2.

**Rooms were reported empty, and the stat now says how full.** `--stats` prints `roomCells/<role>`
and `roomUsed/<role>` (cells holding an unwalkable tile or an object) and `roomEmpty/<role>`.

| room | before | after | what changed |
|---|---|---|---|
| office | 23% | 32% | wall runs no longer stop at the first blocked cell, FILES_MAX 2 → 4, plus centre desk pairs |
| armory | 18% | 24% | crate stacks in the middle |
| comms | — | 27% | racks on the longest wall, two-cell consoles facing them (side walls when that is windows) |
| supply | — | 35% | shelves on the walls, crate stacks in the middle (now shelving rows, above) |
| medical | — | 21% | cots on two walls and in the middle, cabinets on a side wall |

- `MilitaryRooms.islands` is the free-standing pass: a block nearest the room's centre, with a whole
  ring of bare floor round it.
- A 5-6 deep barracks also lays bunks along the wall facing its row.
- The new pieces are `Const` row 21; `tiles.Default` gives them see-through, and unwalkable unless
  they stand at a wall (above).
- Comms and medical take the HQ floor and the store takes barracks boards. WASH would hang the
  latrine's men/women signs on the door (`FacilityPlacard`), and CONCRETE counts toward
  `FacilityModel`'s hangar majority.
- 2000 seeds pass `floorReachable`.

**Clues lie on the furniture, so nothing here reserves them.** The base deals no bare spots at
generation; a clue spot is DERIVED on every entry (`AreaGame.isMilitaryClueSpot`). It is a desk, a
table, a cabinet, a footlocker, a bunk, a cot or a bench seat, reachable from its own room's floor in
any of 8 directions, and only a stable 40% hash share of those. `render.military.MilitaryClutter` reads
the same list and keeps its decals off each spot. Mess and brief tables are mostly boxed in by
benches, so on base1 the 25 spots are bunks, cots and seats more than desks. Spawning (shared with
the lab) keeps at most 2 about, lays one on 25% of the turns short of them, and fills a room only
to 1, or to 2 on a 30% roll, so a barracks of bunks no longer draws most of them. A floor clue is the
rare extra (10% of those spawns, one at a time, inside a room).

### The underground lab, after the 2D one went

`make gen args="--type lab"`. The 2D level was four rooms on spurs, laid by arithmetic with
`Std.random`, and its furniture was ~170 TILE DECORATIONS that nothing could assert. It is now the
corp's shape cut into bedrock: one plate, no `Subdivide`, the rooms carved off a corridor.

```
area                       bedrock (TILE_LAB_ROCK), generated at exactly 56x32
└ plate                    LabPlan: lobby W, 2-high corridor, vat chamber E, three service rooms on
  │                        the corridor (two on one side, one on the other), every bedrock cell
  │                        8-adjacent to floor walled
  ├ lift                   2x2 TILE_LAB_LIFT in the lobby's NW corner, 4 'labLift' spawns; its
  │                        neighbours are KEPT bare
  ├ corridor               leaf; dressed render-side
  ├ door x5                linked two-cell pairs, 'labDoor' spawns (part 0/1, vertical)
  └ room-entrance | room-vat | room-workshop | room-storage | room-research   one of each
    └ zones over the bays (LabZones): hazmat-rack, kiosk, seat-row, locker-run, gurney-bay ·
      vat-pad x4 (CARVED first), console-run, machine-bank, specimen-run, vat-island ·
      workbench-run, machine-wall, crate-stack, machine-island · container, cold-bank, shelving,
      shelf-row · bench-run, bookcase-run, fridge-run, analyser · lab-slot
```

| file | what it is |
|---|---|
| `gen/lab/LabGen.hx` | `build()`, the walk, the lift and doorway fills. Writes FINAL ids: every lab id already says what it is, so there is no temp alphabet and no finalize |
| `gen/lab/LabPlan.hx` | the plate, ≤30 draws |
| `gen/lab/LabZones.hx` | bays, the vat pads, each room kind's quota |
| `gen/lab/LabRooms.hx` | each zone's furniture and machines, `free`/`walled`/`sealsOff` ported from the base |
| `gen/lab/LabKinds.hx` | the 66 machine kinds (APPEND ONLY: an index is a saved tile id), `alongX`, `selfCheck` |

- **The mission's contract is unchanged**: `missionHints` carries the vat room, its doorway's upper
  cell and the four 2x3 anchors at the 2D formula's cells, and the guards' post (`vatDoorX-1`) is
  corridor. `GenCheck.labSane` asserts all of it.
- **A machine is a footprint named by its ORIGIN** (`Const.TILE_LAB_MACHINE0 + index`, the vehicle
  pattern) at its 3D size, not the 2D sprite's: a sprite draws its height over the row above, so a
  2x2 cabinet sprite is a cabinet 2 long and 1 deep. Its TURN is not saved: `LabKinds.alongX` reads it
  off the cell `depth` along from the origin, which is inside an along-x rect and is exactly the RING
  cell beside an along-y one. Every machine keeps a ring of bare floor or masonry
  (`LabRooms.machine`), so that cell is never another machine. **The first probe, `len - 1` along,
  was wrong**: on a 3x1 it reached past the ring into the next machine (516 failures in 3000).
- **Zones fill in their quota's order, not wall order.** Walked bay by bay, a store's cold bank on
  the top wall took the corners its container on the side wall needed, and 10% of stores stood none.
- **Rarest kind first.** Each zone deals the kind the level has stood least (`_LabState.used`, a
  seeded roll breaking ties), so a level shows ~32 of the 66 kinds.
- **A wall zone with no fit of its own avoids the south wall** (the camera sees its pieces' backs).

3000 seeds: 34.7 machines and 31.7 kinds a level, rooms used entrance 17 / research 24 / storage 31 /
vat 29 (of 224, the pads' kept ring being most of it) / workshop 21 cells.

### The one permitted `gen/` → `game/` edge

`gen/facility/` imports `game.AreaGenerator`'s pure static grid helpers — `drawBlock`, `drawChunk`,
`drawLine`, `replaceTiles`, `getRoom`, `markRoom`, `getRoomDoorSpots`, `getRoomWallSpots`,
`getRoomWallCorners`, `nextTo`, `deltaMap`, `DIR_*` — plus its `_Spot` typedef. **Every one is
`public static` over a plain `Array<Array<Int>>` or `_Room` and none touches a `Game`**, so the rule
above holds and `make gen` keeps working.

Moving those 13 helpers into a `gen/Grid.hx` is the obvious follow-up and is deliberately not done:
`AreaGenerator` still serves the wilderness, city and sewers, so it is three more generators' blast
radius for no benefit yet.

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
`gen.lab.LabPlan`'s 30 draws. `Quota.deal` is silent on failure for
this reason — ask `Quota.satisfied` instead.

**The south wall rarely carries wall decoration.** The tactical camera looks NORTH, so anything
backed onto a room's south wall faces away from the player, with the masonry between them. The
player only sees it under a heavy camera turn. A template choosing a wall for a run that is read by
its front (a counter, cabinets, a fridge, a bookcase, a notice) picks another side first, and takes
the south only when the piece would be wasted anywhere else. The kitchen's prep counter and its
snack corner never take it (`CorpKitchen.zones`).

**The unwalkable twin is for things that FILL their cell, not things standing against a wall.** A
corp cell is 2 m, and a waste bin (0.66), a plant (1.35), a water cooler (0.58) or a whiteboard (no
footprint, it hangs) stands flat against the wall in 3D. Put one on `<floor> + UNWALKABLE_TILE_OFFSET`
and the player sees a whole tile of bare carpet they cannot step on. **Reported four times, each
fixed in its own room, and so the next one was always missed**: the bin (`addDecorationExt`'s
old special case), the exec corner plants (`cornerPlants`), the meeting room's `decorateWalls`
edges, then the boardroom cooler that the fix for those edges wrote itself. The reason it keeps coming back: every dressing
helper writes the twin BEFORE it picks the group, so a new group is sealed by default and nothing
downstream complains — the oracle only checks reachability, and a walled cell is not a pocket.
**The rule now lives in ONE list, `CorpRooms.WALL_HUGGERS`**: `addDecorationExt` gives any of them
its floor back, in every template at once. A new wall-standing decoration goes in that list. A
template that deals one directly (`addDecoration`) must not write the twin at all.
- **The fifth report was the washroom BASIN RUN** ("tiles in front of sink are unwalkable"): the
  vanity is a shallow unit against the wall, and `toilet` sealed its whole cell. A basin is now a
  `CORP_TAP` on the walkable marble, which `render.corp.CorpModel.basins` reads back into
  `FIT_FIXTURE` (a save from before keeps the twin, which `fitOf` still answers), and
  `GenCheck.corpWashroomSane` takes either form. The WC STALLS keep the twin: a stall fills its cell.
  `decorateCorners` now also skips a corner something already stands on, since a run's end can be one.
- **The one exception is a boxed-in CORNER.** `decorateWalls` forces a corner even straight after
  a dressed cell, and on a wall with a counter or a rack along the corner's row, that corner has
  walls on two hands, the counter on the third and the dressed cell on the fourth. Walkable, it is
  a pocket, and `CorpConnect.openPockets` opens pockets by CLEARING FURNITURE — it took a
  reception's one-cell counter on seeds 8, 52, 96, 110, 282, 312, 318, 366 and 494 of 500. Skipping
  the corner does not help (bare floor is a pocket too). So a corner after a SEALED cell keeps the
  twin, whatever it was dealt: nobody could reach it anyway. Traced with a one-off print in
  `openPockets` of every counter cell it clears and the 5x5 around it. Trace a pocket like that
  before guessing at one: the first guess here (skip the corner) was wrong and cost a run.

**`Subdivide` is not shared with `citygen.CityGen`, on purpose.** CityGen's `leaf()` draws floors,
roof and facade from the same rng as the split, so cutting and dressing are interleaved in one
stream. Pulling the split out would reorder those draws and move every city layout in every existing
save. The duplication is deliberate.

## The oracle

```
make gen                              # 3000 seeds, structural checks (facility)
make gen args="--type corp"           # the corp tower floor
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
- **a store can be walked all the way through**: every walkable cell of a `room-storage` is inside
  the rim flood, and every door of it has floor on the room side. `reachable` above cannot say this —
  it counts a room as reached if ANY of its cells was, which is right for a door that was never cut
  and wrong for a corner walled in by its own racking

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

### …and then a CONSTANT lied, so the corrected question was asked of the wrong cells

> SUPERSEDES the "0 failures over 20000 seeds" above. `cullDiagonalTables` is now
> `FacilityRooms.fixDiagonalTables` and closes the pair into an L instead of dropping half of it.

Reported a third time, at **26,3 / 27,4** with the player standing at 26,4 — and the two worktops
really were crossing, in a compound generated by the code the paragraphs above describe.

**The pair predicate was right and the TABLE predicate was wrong.** Two different tests for "is this
tile a worktop" had grown up either side of the render boundary:

  * `render.facility.FacilityModel.tableOf` read the tileset's SHAPE — rows 8..11 are 16 wide and
    only their first 8 columns are labs worktops, the back half being the corp office's wood, carpet
    and marble furniture that only `game.CorpAreaGenerator` lays;
  * `GenCheck`, `FacilityRooms` (twice) and `AreaGame.initSpawnPoints` read the flat RANGE
    `TILE_LABS_TABLE_3X3_7 .. TILE_LABS_TABLE2_1X1`.

And `TILE_LABS_TABLE2_1X1` was `OFFSET_ROW11 + 3` — **the same id as `TILE_LABS_TABLE_1X1` two lines
above it**, under a comment calling it the last table tile. It is never laid, only read as the top of
that range, so the duplicate never showed. What it cost is row 11 columns 4-6:
`TILE_LABS_TABLE2_3X1_1..3`, the DRAWER RUN `gen.blocks.RoomBlock` lays along every top wall. A
drawer run was a full bench on screen and **nothing at all** to the cull, to `tablesSane`, to
`clearTableSpots` and to the clue spawn. The cell at 26,3 was `182`.

Measured with the shipped generator and the corrected oracle: **2006 of 3000 seeds fail**, i.e. two
compounds in three carried at least one crossing pair while the check reported 20000 clean.

`Const.isTableTile(t)` is now the only copy of the test, the stride one, and all six sites call it.
`TILE_LABS_TABLE2_1X1` moved to `OFFSET_ROW11 + 7`, which is where the family's other three cells
say it belongs.

### The repair is an L, not a cull

Asked for directly: *"it should be promoted to L-shape"*. And it is the better half of the answer —
the two runs of a corner-touching pair are almost always the two arms of an L that stopped one cell
short of its own corner, which is exactly what the bay rhythm above produces.

`fixDiagonalTables` fills one of the two cells the pair shares, and **only a DEAD-END nook**: bare
`TEMP_BUILDING_ROOM` with MASONRY on both of the hands that are not the pair (wall, inner wall or
glazing — *not* a doorway, which is not `TEMP_BUILDING_ROOM` either, so a plain "unwalkable" test
would brick up the cell beside one). All four of its orthogonal neighbours are then solid: two walls
and the two worktops. Movement is 8-way (`Const.dirx`) and nothing stops a player cutting the corner
into such a cell, but a route THROUGH it would have to cut a blocked corner at both ends with the
open room lying alongside — so filling it can disconnect nothing, and no reachability pass is needed
behind it. That nook is also the cell the L actually wants: the room's own corner.

The tile written is the plain `TILE_LABS_TABLE_1X1`, deliberately. Nothing downstream reads a
worktop's FAMILY — `FacilityModel` keeps only the boolean and the bench-or-desk finish comes off the
room's surface — so the only thing the choice decides is the 2D sprite, and a 1x1 is the only art in
either family that is a whole worktop on its own cell.

**TWO PASSES AND NOT ONE INTERLEAVED LOOP.** Promotion turns floor into worktop and the cull turns
worktop into floor; a single loop could fill a nook, drop it again and come round for ever. Fill
first until a whole scan finds nothing, then cull whatever is left. Each pass strictly grows or
strictly shrinks the worktop set, so each terminates.

**Measured.** 0 failures at 3000 seeds. Over 500 seeds the repair fired **1893 times and every one
of them was a promotion — zero culls**: ~3.8 pairs per compound, all of them a room corner. The drop
path is kept as the fallback and is, so far, dead weight. `walkableCells` 2893.96 → **2886.41** and
`spawns/decoration` 182.44 → **187.01**, both exactly what the swap predicts: ~3.8 nooks stop being
standable and ~3.8 benches stop being dropped with their decoration.

Confirmed on screen after `area regen`: 0 corner-only pairs in the area, and the one promoted cell
(14,21, between the run at 12-13,21 and the one at 14,20) draws as a single unbroken worktop turning
the corner.

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

~~`CorpAreaGenerator` is a near line-for-line fork of the facility's building pipeline~~ — **fixed**
by the port above. The fork is gone and the `allRooms` half of it never applied: a corp area is one
plate with one set of rooms, where a compound is two lab buildings plus a shed and had to fold three
structures' records together. `_CorpState` therefore has no `all*` pair and needs no `repairRooms`.

**`Const.FACILITY_FITTING_PCT` is now a coin flip between two distributions over the SAME frames.**
It reads as "how often a high floor decoration comes out as a 3D fitting rather than a plain sprite",
and that was true when it was written. It is not true now: every frame of
`CHEM_LABS_DECO_FLOOR_HIGH` (row 8 cols 0-11, row 13 cols 0-6) and of `CHEM_LABS_DECO_FLOOR_LOW`
(row 12 cols 0-10) is in `FACILITY_DECO`, so both arms of that 60% deal a fitting — the only thing it
still chooses is UNIFORM-PER-KIND against UNIFORM-PER-ATLAS-ROW. Collapsing it to one `Deco.pick` is
a one-line deletion, and it moves the furniture mix (five machine icons stop outweighing two shelving
icons on the row-uniform arm), so it wants a look in the game rather than a digest.

## A CLUSTER IS NOT A CORRIDOR: nothing may be reached only through a toilet

"server room is only accessible through toilet. add sanity check" — and it was not one bug but a
missing invariant.

`CorpBuilding.makeDoors` cuts each room exactly ONE door, at a random wall spot that passes two
geometric tests ("is it an inner wall", "fewer than 3 wall neighbours"). **Nothing in the pick asks
what is on the far side**, so a room's one door can open into the room next door. `fixDoors` then
repaired CLUSTERS — `if (Lambda.has(c, 0)) continue` is satisfied the moment ANY room in a
door-joined group touches a corridor — so `servers -> toilet -> corridor` passed it.

**The invariant is NOT "every room owns a corridor door".** A suite whose inner office opens off an
outer one is a building, not a bug, and the plate's edge rooms often have no corridor to open onto
at all: replacing the cluster pass with a per-room corridor door still left **129 rooms over 300
seeds** owning none, because `makeDoorToCorridor` has nothing to cut into for them. What is actually
wrong is walking THROUGH a lavatory to get somewhere, so the invariant is:

> nothing is reached only by passing THROUGH a toilet or the server room.

`GenCheck.corpRoutesSane` walks the DOOR GRAPH from room 0 (the corridor sentinel) and enters a
dead-end room without expanding through it. `reachable` cannot answer this — it floods the walkable
tiles from the lift, and a room behind another room IS reached.

**And the repair is not to cut another door, it is not to DEAL one.** `CorpBuilding.passThrough`
marks every room whose removal strands another, and `CorpBlocks.demands` hands that set to the
toilet's and the server room's `must`, which `Quota.deal` and `GenCheck.blocksFit` both honour.
That leaves **3 seeds in 3000**: two dead ends in PARALLEL, where neither is an articulation point
on its own. Asking the question of PAIRS instead is far too strong — it rules out a room in any
two-room cut whatever the other turns out to be, and left **997 of 3000 towers with nowhere to put a
server room at all**. So the pair is not predicted: `assign` deals, walks the routes, and re-deals
with whatever was in the way added to `blocked`. Three towers in 3000 take the second attempt and
none has taken a third. 3000/3000 corp green, 3000/3000 facility green, 200 digests identical twice.

**The WC, the server room and the archive are entered from a corridor and through nothing else**
("corpo - toilet, archive, servers"): the archive is a dead end too (`CorpBuilding.deadEnd`), a room
with no door of its own onto a corridor goes into `blocked`, so the three `must`s deal none of them
one, and after the deal `CorpBuilding.sealDeadEnds` walls up every door of theirs but the first of
their own onto a corridor wherever that strands nobody. `CorpConnect`'s repair cuts no door into
them, as it cuts none into the security room, and `corpRoutesSane` asserts no door joins one to
another room. Before: 72% of toilets, 71% of server rooms and 77% of archives had one, and 9% / 7% /
8% had no corridor door at all. Measured over 3000 towers the deal never had to give way (`relaxed`
0): every floor has its toilet and server room on those terms. The archive, min 0, pays: 1.79 → 1.67 a
floor. 2.45 doors a floor walled up.

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

## A store room, and the three ways its own furniture fought it

The fourth room template (`ROLE_STORAGE`, `RoomBlock.STORAGE`), dealt one per lab building on the
washroom's shape: a pre-condition on the pick, no dice, and a room that fails it is simply not made
one. Its quota is `core(SHELF_RUN)` + an `aisle()` held at `min: 1` + `optional(PALLET_BAY, 85)`, and
`nodes/room-storage` comes out at **1.97 per compound** with 6.34 shelf runs, 1.63 pallet bays and
1.95 aisles. Three faults, all found by the oracle and none by eye — and a fourth found by walking
into one, below:

**The pick ran two passes too early to ask `roomWallRuns`.** `storeWall` wanted "a wall run long
enough for racking" and the obvious call returns four EMPTY runs at theme time, because that helper
tests the floor cell against `TEMP_BUILDING_ROOM` and a room's floor still carries its own id mark
there (measured 102 and 112 on the first two rooms of seed 1). Every seed came out storeless. It asks
the WALL instead now — a consecutive run of cells backed by masonry and clear of an inner doorway —
which is both earlier-safe and a stronger test.

**`paintRoomFloor`'s +16 rule is not a rule.** A store is floored in concrete, and the twin-one-row-
below convention holds for the themed floors of row 12 and not for `TILE_FLOOR_CONCRETE`, which lives
at `OFFSET_CHEM_LAB + 6`: +16 lands on **134 = a lab worktop tile**. 5 seeds in 3000 came back with a
store whose racking cells were worktops, reported twice over by `tablesSane` (a corner-touching pair)
and `storageSane` (floor nothing could walk to). The unwalkable twin is an argument now.

**A rack is 4.2 tall and fills its bay, so a store can wall a corner of itself off.** 5 seeds in 3000.
The obvious fix — keep the room's corners clear of racking — made it **144**, because a bare corner
with a rack on each of its two neighbours is the same pocket drawn the other way round. It is a
REACHABILITY REPAIR instead (`FacilityRooms.openPockets`, the shape `connectRooms` and
`cullDiagonalTables` already use): flood what the door reaches, drop the one fitting standing between
the flood and what it could not, repeat.

**And the room glazes like the WASHROOM, not like a laboratory.** `solid` refuses a cell next to a
ribbon window, so a store glazed like a lab has almost no wall to stand anything against: measured on
the first build, **one pallet rack in a whole compound**. High light wells (`FacilityToilet
.toiletWindows`) are outside the range `nextToWindow` tests, so the cell under one is solid — 5 racks
in the same compound afterwards.

**AND THE ZONE TREE ONLY EVER REACHES A ROOM'S WALLS, which left half of every store bare.** A bay
IS a wall run (`RoomBlock.node` cuts the room's perimeter into them), so all four faults above are
about racking against masonry and none of them is about the middle of the room — which on a 5x6 store
is a 3x4 floor with nothing on it. Reported off the game as the room being wrong and wanting much
more in it, and it was: **5 pallet racks in a whole compound**.

**So a store gets ONE MORE BLOCK THAN ANY OTHER ROOM, and it is its whole floor.** `RoomBlock.glaze`
pushes it tagged `TAG_FLOOR` and `RoomZones.shelfBlock()` pins `SHELF_RUN` to it with a `must`;
`aisle()` and `optional()` carry the matching `!TAG_FLOOR` guard so nothing else can claim it, and
`Quota`'s own filler reclaims the leftover wall bays with the store's list (which is why the store
has no `core(… max: MANY)` where every other room does). It is pushed FIRST, so the breadth-first
walk fills it BEFORE the wall bays it overlaps — the vent caps are pushed LAST for the mirror image
of the same reason, and overlapping nodes are not new here.

`RoomBlock.rows` then lays it: rows **across the room's SHORT axis, stepped along its long one** —
bays across the width with the gangway down the length, a warehouse's own layout. Taken the other way
round the stepping axis is the one with no room in it, and measured over 60 seeds that placed nothing
at all in every store 4 cells deep, which is 30% of them. **Lines 1, 3, 5 … and never the room's own
perimeter line**: `FacilityConnect.connectRooms` repairs a room nothing can walk into by CUTTING A
DOOR, and a cut needs a walkable cell on the room side as well as the far one, so a store racked to
its wall can never be repaired — **20 unreachable stores in 3000 seeds with line 0 in, 0 with it
out**. Every other line is a clear aisle and the GANGWAY is the one line across them all, taken from
the door and clamped off the row's two end cells; unclamped it lands on the perimeter, where it is a
lane with the far wall on one side — seed 2235, which sealed a 3x2 pocket that way. Measured after:
racks **5 → 32** in one compound, `nodes/shelf-run` 1.96 (one block, not six wall runs),
`spawns/decoration` 171.1 → 181.8 per area over 600 seeds.

**`openPockets` could only ever open a ONE-CELL pocket, and this is the density that showed it.** It
took the pocket in scan order and called `freeOne` on that cell, which walks the four neighbours for
a fitting to remove — and a 3x2 pocket's top-left corner has two bare-floor neighbours and no fitting
on any hand, so the repair gave up and returned with the pocket intact (seed 2235, six cells reported
by `storageSane`). It now walks the pocket's cells until one has a fitting beside it. The same pass
learned a second case it used to return on: a fitting standing in a DOORWAY's own lane leaves the
flood nowhere to start, every cell in the room then reads as a pocket, and the answer is to open the
doorway first rather than to give up — distinguished from the genuinely doorless room (reached only
through a neighbour's door, which is `GenCheck.reachable`'s business) by `doors.length`.

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

## A corp room is 12 cells, and four things had to move to make it so

"toilets and server rooms are giant. and all rooms are too large in general", and the first thing
worth writing down is that **nothing had broken**. `CorpBuilding`'s `ROOM_SIZE * 1.5` is copied
verbatim from `game.CorpAreaGenerator:434-436` and predates the 3D port; the previous pass's
`blocked`/`must` pair moves the toilet's pick in **one seed in three hundred, by three cells**. The
carve had always been this coarse — the port is what made a 110-cell washroom legible.

Measured over 300 seeds / 3,629 rooms: area p10 63, **median 105**, p90 165, **max 384**; toilet
mean 70.3 (a 7 x 10 washroom), servers 82.3, cubicle 165.1; 12.10 rooms a floor. And the width
histogram was **bimodal**, with 235 rooms out at 20-26 cells.

**THAT TAIL IS A LEAK AND NOT A SETTING.** `subdivideLargeRooms` cut a room and then stamped
`markRoom(getRoom(cells, x, y), BLDG_ROOM_MARKED)` — but a cut makes TWO rooms and only the far one
stays `BLDG_ROOM` for the row-major scan to find again. The near one was marked finished at whatever
size a single cut left it. It is a `while` loop now, re-measuring at `(x, y)`, which stays the near
product's top-left because the scan is row-major and `getRoom` measures right and down from where it
is given and never walks back.

The other three: `CorpTemp.SUBDIVIDE_OVER = 1.2` (the compound answered the same complaint with the
same constant under the same name, `FacilityBuilding.SUBDIVIDE_OVER`); `SPLIT_MIN` 4 → 6, because a
4-wide slot is one nothing can be put in; and **caps on the fixture RUNS** — 3 basins, 3 stalls, 4
rack rows, centred on their wall. `toilet()` ran a counter the whole width of the top wall and
`servers()` a rack row every 2 cells for the full height, so a big room read as a swimming pool
rather than as a big room with a washroom in it. A real washroom has three basins whatever the
building.

After: area p10 42, **median 64**, p90 99, **max 144**, widths 5..12, tail **gone**; toilet 41.4,
servers 45.3; **18.53 rooms a floor**.

### Retuning the carve moves the DEAL, and that is where the work was

Four oracle rounds, three of them nothing to do with room size:

- **11 towers in 3000: "quota short: room-toilet got 0".** More rooms means longer chains off the
  corridor, so more rooms are the only way through to another — and `deadEnds` is blunt on purpose
  (one stranded room names EVERY toilet and server room on the floor). Four rounds of that can rule
  out every 5 x 5 room there is. `CorpBlocks.assign` now adds only what still leaves two legal
  homes, and where even that fails it drops the pre-deal test entirely and takes the deal: **a tower
  with its washroom behind another room is a defect, a tower with no washroom is a broken area.**
- **Narrowing `deadEnds` to the rooms that individually fail `blocksRoute` went 1 → 30+ failures.**
  The case it exists for is TWO dead ends in parallel, where neither on its own disconnects
  anything. The bluntness is the point; what has to be bounded is how much of it one round may act on.
- **`blocksRoute` was asking the wrong question.** It walked from room 0 with one room shut off and
  then required every room in `state.rooms` to have been seen — so ONE room the corridor cannot
  reach over the DOOR graph made it true for every roomID. `CorpConnect` guarantees the LIFT reaches
  every room over TILES, which is a different graph. On seed 777 that blocked **all 18 rooms**,
  `assign` had nowhere legal for either 5 x 5 demand, and the whole protection turned itself off —
  producing exactly the server-room-behind-the-toilet it exists to prevent. It compares against the
  baseline reach now.
- **`blocked` must not grow after the deal that stands.** `GenCheck.blocksFit` re-reads the static
  once the area is built and asserts the deal honours it, so a ruling-out added at the end of the
  last round is a self-inflicted "room-servers dealt a block its own `must` rejects". The additions
  happen at the top of the next round instead.

And `ROOM_CUBICLE`'s minW/minH went 9x7 → **8x6**: the mins were fitted when a floor carried 12 rooms
averaging 110 cells, and 2 towers in 3000 had nothing left that cleared 9x7 at all.

**The stated consequence: open plan went from 21% of rooms to 46%** (771/3,629 → 2,560/5,560). The
quota's maxes were fitted to a 12-room floor and the filler takes whatever they do not claim. Left
alone — open plan being the filler is the design, and changing the maxes is a separate decision.

## Two ways a corp room came out with no furniture in it

"37,12 room is empty" was two independent paths, and a throwaway trace counting tree nodes that end
with no zone is what separated them: **382 in 600 seeds, every single one an exec office.**

- **`hasTable` lied.** `exec` set it true whenever the room cleared 6 x 6, whether or not `execDesk`
  had placed anything — and `execDesk` returns silently when both end walls carry a door, because it
  only ever put the desk against one of them. With the flag lying, the `!hasTable` escape to
  `decorateCorners` was closed, and at exactly `w == 6` the `w >= 7` arm was closed too: marble and
  nothing else. It returns a Bool now, its guard drops to the 5 x 5 the demand itself asks for, and
  a desk with a door in both ends goes **free-standing in the middle of the room** — nothing about an
  executive's desk requires a wall behind it. 382 → **0**, `nodes/table` 4.34 → 5.00.
- **A centred desk column was refused at every width under 7.** `open()` tests
  `sx + tableW >= room.x2`, which is the walkway margin a MULTI-column run needs; a centred single
  column is already clear of both edges, so the test was true for every row and the loop spun to its
  `cnt > 100` guard laying nothing. 64 of 771 open rooms before the carve was retuned, and far more
  after — a capped carve mints 1,250 six-wide rooms out of 5,560. It is also a `break` and not a
  `continue`: the width does not change between rows.

## The lever on room count is `2 * SPLIT_MIN + 1`, not the cap

"12 rooms is nothing, double that amount."

`SUBDIVIDE_OVER` looks like the knob and is not. `subdivideLargeRooms` refuses to cut a room that
cannot leave `SPLIT_MIN` on BOTH sides, so the real floor on a room's short axis is
`2 * SPLIT_MIN + 1` whatever the cap says — bring the cap down alone and the count saturates.
`ROOM_SIZE` 10 → **6** with `SPLIT_MIN` 6 → **5**, and a floor goes **18.53 → 29.12 rooms** (doors
25.16 → 40.81). Room widths: **29.12 of 29.12 rooms clear 3 x 3, 20.51 clear 4 x 4, only 14.39
clear 5 x 5** — which is the number every demand's minW/minH has to be read against from here on.

The corridor branch roll went 30% → **50%** in the same change: more rooms means more of them sit
off the trunk, and the branch spacing has to densify with the carve or the far corners have no
reached boundary to open onto.

**Five oracle rounds, and four of them were the door graph, not the carve:**

- **1,456 towers in 3,000 "cannot be walked into".** The split computed the far product's size from
  an unfloored subtraction, so a cut could leave a 4-cell slot that then failed its own guard and
  was sealed. Both products are floored now (`room2 = SPLIT_MIN * 2 + 1`, and `neww` clamped
  against `room.w - 1 - SPLIT_MIN`).
- **`getRoomDoorSpots` is four wall MIDPOINTS.** At 8 x 8 that is plenty; at 5 x 5 with a corridor
  on one hand and neighbours on three, the four midpoints can all be illegal. `makeDoors` and
  `makeDoorToCorridor` fall back to `getRoomWallSpots` — the whole ring, centre-outwards — which
  `game.AreaGenerator` documents as the fallback and which the facility has always used.
- **`decorateWalls`' corner rule dressed the cell INSIDE a threshold.** The old test looked only
  straight through the wall the run was walking, which cannot see a door in the top or bottom wall,
  and a corner cell has one of each — and the corner took its dressing unconditionally. Invisible
  at 8 x 8 because the flood found another way in; **61 rooms over 200 towers** at the halved size,
  52 of them open plan. `atDoor` is a four-neighbour test now.
- **Far-side dressing hid reached space from the repair.** `clearWayToReached` only cleared the near
  side; `clearedTo` (the row-12 twin, or `TILE_FLOOR_CARPET` for a table tile) plus a far-side clear
  guarded by a four-neighbour `touches` test took 76 → 26 → **5** once tables were included.
- **The last 5 were corner clusters with no reached boundary at all.** `carveToReached` is the
  last resort before `report(stuck)`: a BFS over the plate from the room to the nearest seen cell,
  clearing the path and adding a door where it crosses the ring.

The fixture caps grew one more in the same pass. `meetingTable` was the last run in `CorpRooms`
still written `tw = room.w - 4` with no cap: measured over 800 meeting rooms, **min 12 cells,
median 32, max 64, and 783 of 800 had an axis of five or more.** At `CityConfig.CELL 4` and a 3 m
storey a cell is 2 m, so the MEDIAN boardroom table was **16 m x 8 m**. `TABLE_W_MAX 4` /
`TABLE_H_MAX 3`, centred, long axis matched to the room's.

## Every room is dealt a kind, and the filler bucket is empty

"NO EMPTY ROOMS" — and, on being asked: "all rooms should get a kind, wtf?"

Nothing was literally bare (`exec` and `open` had been fixed the pass before, 382 → 0). The
complaint is the FILLER: a floor carved 29 rooms, the quota named ten of them, and the other 19
were `room-open` — one template, one floor, a median 16% of its cells furnished. Half the tower was
a sparse duplicate of one room.

**Six new kinds, and each borrows an EXISTING floor surface.** `CorpModel.surfOf` knows eight and
there are no more, so a kind that reuses one costs no tile id, no texture, no material and no draw
call — what makes it a different room is its furniture list and its fixture, which is what a reader
in the room actually sees. Solo office → `CUBICLE`, break room → `KITCHEN`, copy room → `OPEN`,
archive and security → `SERVER`, reception → `EXEC`. The canteen is the break room where the carve
gave it space for a second run of tables, not a kind of its own.

**Never plain `CARPET`.** That surface is what `CorpLamps.corridors()` reads as circulation, and a
room wearing it gets ceiling panels hung inside it — which is the boardroom's whole bug, one
section up.

A kind is four edits and the shape `OfficeBlock` already dictates: a `ROOM_*`/`ROLE_*` pair, a
`case` in `fill`'s dispatch, an entry in `isRoom` (miss it and `--stats` and `quotaMet` cannot see
the kind), and a `CorpRooms` template.

**Then the order, because `Quota.deal`'s second pass spends what the mins left over in
DECLARATION order, each demand to its max.** That order is the mix. The six new demands are
**min 0 on purpose** except the break room the user asked for by name: seven demands above already
hold mins against a supply of 14.4 rooms a floor at 5 x 5, and the eighth cost two towers in 2,000
a "quota short" (the break room dropped to 4 x 4 instead). A min is for the thing a floor MUST
have, and a floor does not have to have an archive on it. What puts one there is the max.

`ROOM_OPEN` stops being the leftover bucket and becomes a dealt kind with `max: 3` and `fit:
biggest` — an open-plan floor is a real corporate thing and three of them is one; 19 is what
happens when a quota runs out of names. `ROOM_SOLO` is declared LAST with `max: MANY` at 3 x 3, so
it takes everything else, and since every room the carve produces clears 3 x 3 the filler branch is
**unreachable**.

Measured over 300 seeds: solo 8.74, copy 3, exec 2.99, cubicle 2, meeting 1.99, break 1.88, open
1.79, archive 1.77, kitchen/toilet/servers 1, reception 0.99, security 0.96 — **13 kinds summing to
the 29.12 rooms a floor**. Proved by dealing under a distinct filler name: **0 filler rooms in
2,000 seeds.** And replayed for the bare-room check that found the 382 exec offices last pass:
**0 rooms with no furniture in them, in any of the 13 kinds, over 400 seeds.**

**Later compacted to 10 kinds.** The break room folded into the KITCHEN (`min 1, max 2`, 4 x 4, the
island at 5 x 5 and a galley `deskRun` below it), and the solo office folded into EXEC, which is now
the LAST demand with `max: MANY` at 3 x 3 and no min: every leftover room is a marble exec office, with
a `deskRun` where the 3x2 slab does not fit. Measured over 1,000 seeds: exec 15.11, open 2.36,
kitchen/cubicle 2, meeting 1.99, archive 1.91, reception/security/toilet/servers 1; furniture per
office unchanged (22.3 vs 22 for solo + exec). `room-break` / `room-solo` and their roles are gone.

**Then `room-open` removed, 9 kinds.** It had nothing another room lacked but its WOOD2 floor: the
wall list was all items other rooms already stand, and the desk bank is what the cubicle farm does
better. Its ~2.36 rooms a floor go to EXEC, which is now also `Quota.deal`'s filler and the
`roleOf`/`kindOf`/`OfficeBlock.fill` default. The render side (`WOOD2` -> `Surf.OPEN`) STAYS: tiles
are persisted, so an old save's open-plan floor still has to draw. The corp mission target falls
back marble -> meeting -> CUBICLE.

**Then made lavish, and reception split off it.** Reception lays its own `TILE_FLOOR_RECEPTION`
(row 17, 2D art aliased to MARBLE1) and renders as `Surf.RECEPTION`, so the exec office's floor and
wall could change without touching it. `CorpRooms.exec` now lays, in order:
- **the suite** (`execSuite`), in a room at least `SUITE_SPAN` 4 across and `SUITE_LEN_X/Y` 7 long:
  the 3x2 desk at one end, and at the other a lounge — armchairs, `CORP_TABLE_LOW`, `CORP_SOFA` against
  the end wall, each two cells across — over a rug. Every flip / lounge offset / desk offset is
  tried nearest the centre first and rejected unless `roomOpen` still floods every walkable cell from
  the doors with the candidate's cells blocked. Pushes `ZONE_LOUNGE`. ~3.25 per floor;
- **otherwise the desk**: `execDesk` (3x2, owner chair `CORP_EXEC_CHAIR`, two `CORP_ARMCHAIR`
  visitors in front) at w, h >= 4, else `execRun` (1 x 2..3 along the long axis, owner beside it);
- **the rug** (`execRug`): the biggest free all-marble rect 2x2..`RUG_MAX` 4 nearest the centre, as
  `TILE_FLOOR_EXEC_RUG` (walkable), and its +16 twin under the lounge furniture. Laid BEFORE the
  plants — plants first took the corners and rugs landed in 3 of 9 rooms; now 9 of 12;
- **plants in every free corner** (`cornerPlants`), marble or rug, not at a door, and WALKABLE: the
  cell keeps its floor id and only takes the decoration, like the exec chair's. A blocking plant made
  every corner a dead cell under a glb that stands pushed into the corner and reads as free floor.
The four new seat and lounge decorations sit on the four atlas cells rows 23-39 had left empty,
hidden in 3D and read back by `render.corp.CorpDeco.kindOf` as `K_EXEC_CHAIR / K_ARMCHAIR / K_SOFA /
K_TABLE_LOW`. Measured over 3,000 seeds: 0 failures, 0 unreachable, `furn/exec` 451.

## The kitchen is three real sub-blocks

`CorpRooms.kitchen` lays the WOOD1 floor and nothing else; `gen.corp.CorpKitchen.zones` pushes three
child nodes (with `roomID` set) that `CorpGen.fill` dispatches a level down, so each filler sees the
ones pushed before it on the grid. The only corp zones that are fillers rather than records.

- **`prep`**: the longest stretch of the wall ring no door opens onto and **no window backs** (temp
  ids 18-24 / 27-33) and **not on the south wall** (see Rules: the camera would see its back), 2..`PREP_MAX` 5
  cells, anchored in a corner where it has one. Fridge at the
  corner end, sink (`CORP_TAP`) next, then microwave / kettle / coffee, or `CORP_COUNTER` on a bare
  cell. **Every run cell stays walkable WOOD1**, named by its decoration: the render stands a
  counter (1.32 deep), a fridge or a vending machine almost wholly on the WALL cell's strip of floor
  in front of the masonry, so a counter tile or an unwalkable twin under it left a whole cell of
  visible floor impassable.
- **`vending`**: the 2..3-cell window of wall nearest a door that the counter did not take, not on
  the south wall: vending machine, cooler, bin, all walkable.
- **`dining`**: the whole room; a table or chair takes any bare WOOD1 cell with no object on it, so
  it may stand right in front of the counter. `LIGHT_TABLE_WOOD1_2X2` at pitch 3,
  each table kept only if `roomOpen` still floods the room. **Every offset the spare cells allow is
  tried**, scored as `tables * 10 + seats`: when tables were centred inside an inset rect, an 8x6
  kitchen left a spare row on each side where a second row of two tables fits. A chair
  (`CORP_CHAIR`, walkable) goes on every free cell of the two sides the table row does not run
  along. A table left with fewer than two chairs also takes its other two sides.
- The demand **aims at 6 x 6** (`fit` = `-(|w-6| + |h-6|)`, min still 4 x 4), since `smallest` dealt
  it 4 x 4 nearly every time.

Round 6 (no prep and no snack corner on the south wall): 0 failures, 0 unreachable, `orphanCells` 0
over 3,000 seeds. `nodes/prep` 1.84 -> 1.66 a floor (about 92% -> 83% of kitchens), `nodes/vending`
1.74 -> 1.44 (about 87% -> 72%), `nodes/table` 15.13 -> 15.48. A kitchen whose only clear wall is
the south one goes without the piece.

Round 3 (walkable run cells, the lane dropped): 0 failures, 0 unreachable, `orphanCells` 0 over
3,000 seeds; `nodes/table` 13.21 -> 15.13 a floor, about one more table per kitchen. `furn/kitchen`
fell 79.22 -> 68.92 because the run cells no longer count as furniture. **Trap:**
`CorpConnect.dropOrphanChairs` drops any row-30 decoration with no table tile beside it, and
`CORP_TAP` deals from row 30 cols 9-10. Once the counter was floor, those taps went as stray
chairs; the pass now skips the tap frames.

Round 2 (offset search, every seat): 0 failures, 0 unreachable, `orphanCells` 0 over 3,000 seeds;
the `--stats` `furn/kitchen` figure rose 59.68 -> 79.22, with +1.83 tables and +7.3 decorations a
floor. A 5x5 kitchen now fits a corner table where the inset rect fitted none.

First pass, over 3,000 seeds: 0 failures, 0 unreachable, `orphanCells` 0. **`furn/kitchen` 21.7% ->
29.8%**, prep in 92% of kitchens and vending in 85% (glazed walls take the rest), dining in 96%.
Sizes now centre on 6x6 / 6x5 / 5x6. The deal moved a little with it: open plan 2.41 -> 2.04 a
floor and archive 1.93 -> 1.79, with the exec filler taking the difference.

## ANY ONE REACHED CELL IS THE WRONG QUESTION

Reported from the game as "this room's tables in the center breaking the movement, plus corners are
impassable even if empty". It is one sentence, written twice, in two files.

`GenCheck.reachable` and `CorpConnect.roomReached` both said *"any one cell will do … a room's
floor is a single rect and its furniture cannot cut that rect in two"*. It can, and it does.
**Measured over 120 corp seeds / 3,500 rooms: 873 rooms (24.9%) held walkable floor the lift flood
never reached — 4,482 cells, 37.4 per floor.** Worst case, seed 7's `archive 19,16..26,21`: 33
walkable cells, **one** reachable, and `check.reachable` returned `[]`. The evidence had been in
the committed `--stats` block the whole time (`walkableCells 1236.28` against `reachedCells
1197.98`) and nothing asserted on it. The reported room, a 5 x 3 solo office, came back

```
# . . . #
. # # # .
# . . . #
```

three disconnected strips with the door on one of them.

**`GenCheck.floorReachable` is the assert** — every walkable cell of every room must be in
`lastSeen`, generalised from `storageSane`, which describes this exact defect in its own header and
was filtered to `ROLE_STORAGE` and never called on the corp path. `--stats` gained `orphanCells`
so the number stays visible now that it is zero.

What it then named:

- **`tiles/Default.hx` row 13 index 12 was a `1`.** `CARPET_MEETING + 16` is the only unwalkable
  twin in the table marked walkable — indices 13 and 14 were patched in when the cubicle and server
  floors were added and 12 kept its inherited value. So 80% of a boardroom's wall furniture was
  walk-through AND invisible, which is why the meeting room was simultaneously the emptiest kind
  and the only one with a 0.0% pocket rate.
- **A desk that spans the room is a wall.** `soloDesk`'s three-cell run had no width guard and a
  solo office is dealt at `minW 3`, so it crossed the midline. Clamped to `w - 2`.
- **A rack row with a per-cell `chance` skip is solid half the time.** At 5 wide that is three
  rolls; 51% of `servers` rows and 42% of `archive` rows came out with no gap at all. The gap is
  dealt now, one per row, positioned.
- **`CorpConnect.openPockets`** is the repair: flood, find lost walkable cells, and open the
  thinnest blockage of every pocket at once, up to `POCKET_ROUNDS 12`. Two traps. A **two-cell-thick
  blockage has no cell touching both sides**, so the thin-wall rule finds no candidate and the loop
  stops with the pocket sealed — 34 in 300 seeds, every one a reception whose 3 x 2 desk stood two
  deep; the fallback round ERODES instead, taking any clearable cell that touches the pocket. And
  `clearedTo` knew two id bands and the exec/reception desk is in neither — `DARK_TABLE_MARBLE1_3X2`
  is on tileset rows 14 and 16, so it was the one piece of furniture in the tower no repair could
  remove. `Const.isCorpDeskBlock` → `TILE_FLOOR_MARBLE1`.

Cost of the whole repair, measured: decorations per floor **232.87 → 229.53**.

## A ROOM KIND IS A PROMISE OF CONTENT, AND THE FILL NUMBER IS NOT THE ZONE COUNT

Reported as "many rooms are pretty empty now: 8,38" and, mid-pass, "either something broken or
reception and security are mostly empty".

**There was no measurement of it at all.** `--stats` counts zone NODES, which is why "mostly empty"
was invisible: a template that lays four dressed corners and a template that furnishes half the
rect both report one node. `furn/<role>` (unwalkable cells inside the rect / rect area, summed per
area and divided by `furnN/<role>`) is the acceptance number and lands with the fixes.

Baseline, and after. `security` gained a monitor bench plus a short rack rank, `breakRoom` a
counter run for the 4-wide case `kitchenTables` cannot serve (it needs 5 x 5 and the demand deals
at 4 x 4), `meeting` a table sized off the room — `TABLE_W_MAX` 4 → **6**, `TABLE_H_MAX` 3 → **4**,
which was putting a 1 x 3 table in a 5 x 10 boardroom.

| role | before | after |
|---|---|---|
| meeting | 25.6% | **29.8%** |
| reception | 22.9% | **25.4%** |
| security | 19.9% | **22.2%** |
| archive | 23.6% | 24.6% |
| servers | 26.8% | 27.8% |
| break | 21.2% | 21.6% |
| everything else | — | within 0.5 points |

**The meeting room later went the other way on DEPTH, and dropped `decorateWalls`.** Reported from
the game as a giant empty top: `TABLE_H_MAX` 4 is an 8 m slab, and nobody seated on one side reaches
its middle. It is `TABLE_D_MAX` **2** now (length keeps 6), and chairs down both long sides come
from `render.corp.CorpProps.boardChairs` on walkable carpet — the generator deals none. The wall
dressing is `cornerPlants(state, room, CARPET_MEETING)` plus `meetingWalls`: every
`MEETING_WALL_PITCH` 2nd cell of each wall line that is bare and not beside a door takes a plant (or
a bin at `MEETING_WALL_BIN` 20%), one masonry cell takes the whiteboard and one more the cooler.
**Nothing writes the unwalkable twin** (see the WALL_HUGGERS rule above; the cooler did at first
and was reported), so the ring of dead cells
`decorateWalls` left (forced corners, half of x1/x2, 80% of it twin, half of that drawing nothing
on the floor) is gone, and so are its 1x1 wall tables — a lone table tile renders as a desk and
nothing in this room seats one. Oracle: 200 seeds, `unreachableRooms 0`, `orphanCells 0`,
`room-meeting` 1.97 per floor.

**Two of the planned fixes were built, measured and WITHDRAWN, and that is the entry.** A copier
bank down the middle of the copy room took its fill **29.4% → 23.4%** centred and **27.6%** flush;
dressing the exec office's corners at every size took exec **26.9% → 20.7%**. Neither is a
placement accident: both rooms are dealt narrow and dressed heavily (`copy` runs the highest
`chance` in the file at 70/50), so a centre run leaves the two cells joining the room's halves
exactly where a cabinet is most likely to stand, `openPockets` finds the seal, and what it erodes
to reach it is more than the run added. **More furniture placed can mean less furniture standing,
and only the fill number says which.**

## THE RECEPTION IS SMALL, IT IS BY THE LIFT, AND ITS COUNTER IS THE FRONT WALL

> SUPERSEDED by "THE RECEPTION FRONTS THE CORRIDOR MOUTH, AND ITS COUNTER IS IN THE WALL LINE" —
> every "by the lift" number below was measured against a MIRRORED lift point

Spec given mid-pass. The room was dealt on `fit: smallest` with no reference to the elevator, and
its "counter" was a borrowed `execDesk` — a 3 x 2 slab in the MIDDLE of the floor, which is also
why reception measured the highest pocket rate in the tower at 75.4%.

- **By the lift is a `must`**, distance only: taxicab from the rect's centre to `CorpBlocks.liftX/liftY`
  (the car's own cell, taken off `state.px1..py2` and `frontDir`) within `GenCheck.RECEPTION_NEAR`
  **36**, against a plate diagonal of 88. A floor with nothing near the car gets no reception, which
  is correct — a reception 64 cells from the lift is not a reception.
- **Small is a `fit` penalty, not a `must`.** The size cap was a `must` first and cost a third of
  the towers their reception outright (0.99 dealt per floor → **0.66**), because `min` is 0: a floor
  whose free rects are all 7 wide simply does not get one. As a penalty it loses to any rect both
  nearer and within the cap, and wins when there is nothing else.
- **And the demand is DECLARED FIRST.** `Quota.deal` fills minima most-constrained-first and then
  walks the maxima in DECLARATION ORDER — with `min: 0`, wherever this sat in the list every room
  with a min had already chosen and the near-lift rects were gone. Measured with the assert forced
  over 3,000 seeds: **82 towers over 36 cells, worst 64 → 6 towers**, and the `must` closes those.
  Dealt rate 1.00 per floor.
- **The counter is laid on the room's y1 or y2 EDGE ROW**, whichever faces the lift, x1+1 .. x2-1,
  skipping any cell beside a doorway. One cell in from the edge was tried first and is a pocket
  factory: the strip behind it exits only through the two corners, and `decorateWalls` dresses a
  corner unconditionally. It is always horizontal for the same kind of reason — `decorateWalls`
  dresses columns x1 and x2 and nothing else, so a run held inside those columns can never be
  overwritten by the dressing that follows it.
- **`GenCheck.receptionSane`** asserts both halves: the distance, and that the room actually
  carries `TILE_DARK_TABLE_MARBLE1_1X1` on one of its two edge rows.

Corp oracle green at 3,000 seeds with both new asserts on, `orphanCells 0.00`, facility green at
3,000, corp digest stable across two runs.

## THE RECEPTION FRONTS THE CORRIDOR MOUTH, AND ITS COUNTER IS IN THE WALL LINE

Spec: "it has to be near the elevator", and its front wall replaced by a marble counter set between
the wall corners like a window.

- **`liftX/liftY` WAS MIRRORED on all four `frontDir` cases.** `frontDir` is the way the corridor runs
  INWARD, so DOWN means the TOP wall — and `assign` put the point on the opposite edge, at the far
  end of the main corridor by the stairs. `receptionSane` read the same point and stayed green:
  measured against the real car over 300 seeds the reception was a **median 49.5 cells** away (max
  68), none within 12. **An oracle that reads the generator's own idea of a landmark cannot catch
  the landmark being wrong.**
- **"Near" is now a SHAPE, not a radius: `CorpBlocks.fronts`**, filled in `assign` before the deal
  (the `blocked` route). A room qualifies when one wall faces a corridor along its WHOLE length within
  `RECEPTION_MOUTH` 8 of the lift door (`CorpBuilding.frontWall`), that wall is at most
  `RECEPTION_MAX + 1` long, and shutting every door in it still leaves the corridor reaching
  everything it did (`frontShuts`) — the counter takes the whole wall, so the room is entered by a
  door on another wall.
- **`min` is 1 wherever `fronts` is non-empty**, else 0. At `min: 0` the demand dealt only in the
  maxima pass, after the five `min: 1` kinds had picked, and they took the room fronting the lift on
  15% of floors (0.82 dealt). As a min it is the most constrained demand (1.5 candidates) and picks
  first. **0.93 dealt a floor**; the 7% without are floors with no qualifying room. Uncapped it was
  0.97 but 136 towers in 3,000 laid an 8-10 cell counter — a 20 m front desk.
- **The counter is `TILE_CORP_RECEPTION_COUNTER`** (row 17, unwalkable + see-through already) over the
  ring cells post to post; the doors in that wall are removed from the grid and from `state.doors`.
  `deadEnds` walks the reception's front as SHUT, so a WC that is its only other way in re-deals.
  The corridor straight out from it, across its width, takes `RECEPTION` floor: the lobby patch.
  The row behind it is cleared of wall dressing (the receptionist's lane) and the chair goes there.
- **Measured over 3,000 seeds:** 0 failures, 0 unreachable, `orphanCells` 0; centre-to-lift distance
  **7-12, worst 12** (`RECEPTION_NEAR` 36 → 14); counter 4-7 cells, mean 5.1.
- **The renderer reads the counter as FLOOR with a fitting on it**, not as a wall — see the
  `3d-changes.md` entry "corp reception counter in the wall line".
- **Reported as feeling empty, and a long counter as short of computers.** A receptionist per
  `RECEPTION_STATION_PITCH` 3 cells (`Const.receptionStations`, read by the generator's chairs and
  `CorpReception`'s workstations alike, so they cannot drift): 1 up to 3 cells, 2 up to 6, 3 at 7.
  `backOffice` lays up to `BACK_OFFICE_BANKS` 2 back-to-back desk banks along x, a chair each side,
  clear of the dressed columns, their aisles and the lane, each kept only if `roomOpen` still floods
  the room from its doors: **3.6 desks a reception** at a mean 32-cell room. Wall dressing 40% → 80%
  with `CORP_COMPUTERS` among the wall tables, and a `CORP_PLANT` in the corridor against each corner
  post (a wall-hugger, the cell stays corridor). 3,000 seeds: 0 failures, 0 unreachable, 0 orphans.
- **`CORP_CABINET` is a WALL_HUGGER** (1.20 deep in a 4.0 cell): the reception's dressing wrote the
  twin under it and it was reported as an unwalkable tile in front of the cabinet.

## THE WINDOW RULE LIVES IN THE RENDERER, AND `makeWindows` WAS LEFT ALONE

Two complaints about corp glazing — a pane butted straight onto a doorway, and a 2-cell opening in
a 4- or 5-cell wall reading as "half a wall" — and neither was fixed here, in
`CorpBuilding.makeWindows`, although it is what writes them.

`makeWindows` genuinely causes the first: it breaks its run at a `BLDG_INNER_DOOR` and then
deliberately glazes the cell immediately before it (`cells[x - delta.x][y - delta.y] =
windowTiles[2]`, the closing frame), so every opening on a glazed wall has curtain wall bolted to
its jamb.

**It was still the wrong place to fix it**, and the reason is the one `render.corp.CorpModel`'s
header has carried since the port: the renderer derives the whole shell — `m.wall`, the runs, the
surfaces — from the SAVED CELL GRID on every load. A correction there reaches every corp save that
already exists; a correction in the generator reaches none of them, and a tower is not a thing a
player regenerates. `washroomWindows` and `loneWindows` were already there for exactly this. So
the pass added two more beside them:

- **`doorWindows`** — a `Wall.WINDOW` cell with a door next to it ALONG THE WALL LINE becomes
  `SOLID`. Along the line and not on all four hands: a door in the perpendicular wall of the room
  behind is not adjacent to this pane in any sense a player can see.
- **`runsOfThree`** — a maximal run keeps `floor(len / 3) * 3` cells, CENTRED, and the remainder
  goes solid. `FacilityModel.findWindows`' corp splitter (greedy 3s with 2s to finish) then only
  ever sees a multiple of three, so the two-bay art goes unused on a tower. The runs are collected
  before any is applied: demoting a cell mid-scan makes the next cell of the same run look like the
  head of a new one, and it would be trimmed twice.

Measured on one plate: **204 glazed cells → 165, 78 runs → 55, len-2 runs 30 → 0**, and zero panes
adjacent to a doorway. The tile ids the generator writes are untouched, so no oracle run and no
digest moved — there is no generator change in this pass at all.

**The general rule this is the fourth instance of: if a defect can be derived from the saved grid,
derive it.** Four passes have now put a corp shell correction in `CorpModel` rather than in
`gen.corp` — the washroom's glazing, the lone one-cell opening, the wall-dressing fittings
(`wallFits`), and these two.

## A BIN DOES NOT TAKE A TILE

Reported as "bins should NOT make the full tile impassable, that's dumb (happens in all rooms)".
`decorateWalls` / `decorateCorners` write the room's unwalkable twin into the cell BEFORE
`addDecorationExt` picks which group stands on it, so a waste bin sealed a whole cell exactly as a
vending machine does. In the archive it was worse: the twin there IS `FIT_ARCHIVE`, so the bin also
stood inside a shelving unit.

`addDecorationExt` now takes `UNWALKABLE_TILE_OFFSET` back off the cell when the picked group is
`Const.CORP_TRASH`. Every one of the eleven callers hands in a twin (checked), so that is the room's
own floor. The renderer side is `render.corp.CorpDeco.bins`, which now pushes the bin onto every
masonry hand at the real face (`FacilityGeom.wallFace`, a unit past the cell edge) — so the actor
on the cell centre never meets it and a corner bin stands in its corner.

Measured over 300 corp seeds: OK, **orphanCells 0** (no bin opened a pocket), and the fill numbers
drop by exactly the bins they no longer count — archive 39.04 → 35.10, copy 89.24 → 74.18, meeting
58.51 → 53.28, toilet 27.59 → 23.07, servers 27.30 → 23.34.

## THE ARCHIVE IS A RING AND ITS RANKS, AND THE AISLE BETWEEN THEM IS WHAT KEEPS IT WALKABLE

> SUPERSEDED by THE ARCHIVE'S WALL RING IS WALKABLE FLOOR

Reported as "should be WAY more packed. lots of cabinets near most walls, and the center split
between sections of shelving units and arch-shelfs". `archive` was the server room's `rackRows` at a
25% skip plus `decorateWalls` on its two side walls at 40% — ranks with holes in them and a wall
dressed one cell in three.

It is its own template now, and `rackRows` is left to the server room and security:

- **the ring** — every cell of all four edges, bar `ARCHIVE_RING_BARE` 15%, takes the archive twin +
  a CORP_CABINET decoration. A cell a doorway opens onto is never dressed, and nor are the two ring
  cells either side of a CORNER approach cell: a corner touches nothing but the ring, so dressing
  them would make the door open into a closet. ONE bin per room, on a non-corner ring cell (a bin's
  cell is walkable, and a walkable corner between two cabinets is a pocket).
- **the ranks** — rows `y1+2 .. y2-2` at `RACK_PITCH`, columns `x1+2 .. x2-2`, SOLID, with one cross
  aisle mid-rank once the span reaches `ARCHIVE_GAP_SPAN` 5.

**The aisle is the invariant, not a repair.** Columns x1+1 / x2-1 and rows y1+1 / y2-1 are never
dressed, so every ring cell and every rank cell touches one loop of floor, and every door opens onto
it. No dealt gap is needed to keep a rank from sealing the floor any more — the rank never touches
the ring.

What each run of cells BECOMES is the renderer's (`render.corp.CorpFurniture.archives`): a wall run
is file cabinets (one in three arch-shelves), a rank is racking or a back-to-back pair of arch-shelves
by which half of the room's ranks it is in.

Measured over 300 corp seeds: OK, orphanCells 0, **furn/archive 35.10 → 65.06**; 3000 seeds OK.

## THE ARCHIVE'S WALL RING IS WALKABLE FLOOR

Reported as "you blocked movement on almost all wall-adjacent tiles for zero reasons. and probably
because of that you could not grow the center shelving units", with "shelves should never block the
windows" and a bin standing mid-tile. All three were one design mistake and one rule missing.

- **The ring cabinet is a decoration on walkable floor, not the twin.** A 1.2-deep cabinet sealing a
  4.0 cell cost the whole ring, and the ring being solid then forced a second ring of aisle inside it,
  so a 5x7 room held ONE column of shelving. Now the ring is the room's walkway and the ranks fill
  everything inside it: rows `y1+1 .. y2-1` at `RACK_PITCH`, columns `x1+1 .. x2-1`. That same 5x7
  room holds three ranks of three. `render.corp.CorpModel.archiveWalls` turns a cabinet decoration
  on walkable `TILE_FLOOR_ARCHIVE` with a masonry hand into `FIT_ARCHIVE`.
- **Masonry only, and the RENDER decides it.** `CorpModel.runsOfThree` / `loneWindows` demote short
  glass runs to masonry after generation, so the generator's masonry test left bare whole walls that
  draw as masonry. The generator deals a cabinet onto every ring cell with ANY wall on a hand
  (`walled`); the renderer keeps the ones backed by `isSolidWall` (`CorpFurniture.wallHand` too). A
  corp decoration never draws its sprite, so the rest are nothing.
- **The archive deals its bin only onto a `walled` cell, and `CorpDeco.bins` stands it against glazing as well
  as masonry** (`isWall`). The mid-tile bin was on a ring cell whose only wall was a window.

Measured over 500 corp seeds: OK, orphanCells 0, unreachableRooms 0. `furn/archive` reads 35.91; it
counts sealed cells, and the ring is not sealed any more, so it is not comparable with 65.06.

Then asked for as "back to back shelving units as well" and "do them vertically along area y-axis
(they look better this way)": the ranks are COLUMNS now, `x1+1 .. x2-1` at `RACK_PITCH` running
`y1+1 .. y2-1`, the cross aisle mid-column, and `CorpFurniture.archives` lays EVERY rank as a
back-to-back pair fronting ±x — racking too, which used to stand single facing the camera. The two
families split the room by column (`rankFamily`). 500 corp seeds OK, orphanCells 0.

More bins, asked for "in other corners + near the shelves in the center": each walled corner of the
ring takes one at `ARCHIVE_CORNER_BIN` 40%, and one or two go in the BIN SLOTS: the cell just
SOUTH of a rank section (the cross aisle, or the ring cell under the rank's last cell, which the ring
dressing then leaves to the bin), asked for as "put the bin slots on the south side of the shelves".
The ranks are laid BEFORE the ring for that. `CorpDeco.bins` stands a bin with a rank to its north
against the rank's south end (`CorpFurniture.rankSouth`, `lay`'s own centring walked back from the
cell) whatever walls the cell has.
500 corp seeds OK, orphanCells 0 (a bin never seals its cell).

## THE COPY ROOM IS GONE; ITS COPIERS AND TABLES ARE THE ARCHIVE'S

Asked for off a look at what `room-copy` drew, which was nothing of its own: its copiers were dealt
onto TABLE tiles, and `render.corp.CorpProps` stands the printer glb on bare floor only (a glb on a
worktop cell would stand inside the bench), so a copy room was a row of empty wooden benches.
`ROOM_COPY` / `ROLE_COPY` / `copyRoom` are removed; its 0..3 `smallest` slots go to solo offices
(nodes/room-solo 9.28 -> 12.42 per floor, 500 seeds).

The archive takes both halves:
- **one or two COPIERS** (`Const.CORP_TABLE_PRINTER`) on ring cells with MASONRY behind them, on bare
  walkable floor — where `CorpProps` does stand the glb, off `backHandOf`;
- **a TABLE under the GLAZING** (`ARCHIVE_TABLE` 70%), where a cabinet may not stand:
  `TILE_DARK_TABLE_WOOD2_1X1` with a stationery or misc decoration. The only thing on the ring that
  BLOCKS, so each one is kept only if `reachable` — a flood over the room's floor id from its door
  cells — still reaches every floor cell. It takes the room's `Surf.SERVER`, so a lone one draws the
  desk bench and a run a worktop, and `CorpClutter.deskish` now counts SERVER so it carries the
  office sheet rather than the kitchen one.

Measured over 500 corp seeds: OK, orphanCells 0, unreachableRooms 0, furn/archive 35.5 -> 52.6 (the
tables are the sealed cells it counts).

Then: "always spawn a bin near copier" — every copier takes a bin on a ring cell beside it with a wall
to stand against; and "let's not spawn quad tables there" — a table is never dealt beside another
(`besideTable`), because two touching table cells are a RUN that `CorpFurniture.worktop` emits as a
slab of quads, where a lone one draws the `corp/desk-bench` glb. 500 seeds OK, orphanCells 0,
furn/archive 45.67.

Then, asked "you think this room is correct?" of a 7x6 archive, and it was not — three faults:
- **four bins in a seven-cell row** (`c b c P b b b`): the ring bin, a corner roll, the rank slots and
  the copier's bin all dealt independently. Now in order, SPACED: the copiers' bins always, then the
  rank slots, then a corner roll, each skipped if `crowded` (within 2 cells, Manhattan, of a bin or a
  copier). The lone ring bin is gone — the other three cover it.
- **a copier dealt into a rank slot**, jammed behind the racking's south end. Copiers now skip ring
  cells beside a rank (`besideShelf`), and are dealt BEFORE the bins.
- **a bare masonry wall**: it was GLASS when generated and `CorpModel.runsOfThree` demoted it, so it
  took tables or nothing, and tables may not touch. A glazed ring cell that takes no table is dealt a
  cabinet again; `archiveWalls` keeps it only if it ends up backed by masonry.

500 corp seeds OK, orphanCells 0, furn/archive 46.4.

## FULL-HEIGHT ARCHIVE SHELVING BLOCKS LINE OF SIGHT

Asked for as "high archive shelves should break los". Line of sight is `AreaGame.isVisible` over the
per-id `tiles.Default.TILE_SEETHROUGH` table, and every archive rank was one id — the archive twin,
see-through like every corp furniture cell — while WHICH family stood on it (racking 2.6 of open
steel, arch-shelf 4.8 = 2.4 m) was a hash in the renderer. So the choice moved to the generator:

- `archive` splits its rank COLUMNS in two, which half is which on a roll, and lays the arch-shelf
  half on `Const.TILE_ARCHIVE_HIGH` = 14 — row 0's spare slot, ALREADY unwalkable and not
  see-through, so the gameplay half was naming it. The racking keeps the see-through twin.
- **TRAP: a final id under the chem-lab band cannot be written straight into the grid.**
  `CorpGen.finalizeTiles` remaps every id below `OFFSET_CHEM_LAB` through `CorpTemp.finalTiles`, and
  14 is inside the temp alphabet — it came out -1 ("6 cells hold a tile id outside the tileset").
  It goes in as temp `CorpTemp.ARCHIVE_HIGH` 43 and finalizes to 14.
- The renderer reads it back: `CorpModel.fitOf` -> `FIT_ARCHIVE_HIGH` 5, `surfOf` -> SERVER,
  `tiles.Default.getIcon` -> concrete; `CorpFurniture.rankFamily(m, col, row)` is the tile's answer
  now (SHELF on HIGH, RACK on the twin), and `archiveAt` accepts both codes.

Measured in game on a 5x10 archive: arch-shelf ranks carry only fam 1 units and racking only fam 2,
`canSeeThrough` false/true on the two, `isVisible` across the ranks false and down the aisle true,
and the 3D vision mask shades everything behind the shelving. 500 corp seeds OK, orphanCells 0.

### corp archive: no table beside a doorway's cell

Reported at 22,14: a sorting table on the ring cell next to the one a door opens onto. `atDoor` only
guards the threshold cell itself (and the ring skips it), so the cell beside it was fair game, and a
table is the one BLOCKING thing on the archive ring. `CorpRooms.besideDoor` (any 4-hand is `atDoor`)
now keeps tables off it; cabinets there are walkable dressing and stay. Archive-only so far.
300 corp seeds OK, orphanCells 0.

## THE SECURITY ROOM: CONSOLE NORTH, RACKS EAST, LOCKERS WEST

Reported as bland, with a rack mid-room and a laminate box for a desk. The room was `rackRows` at
y1+1 plus a `deskRun`, so the rank was never on a wall and in a 4x4 it shared the desk's row.
`CorpRooms.security` now gives every wall an owner, and nothing stands mid-room:

- **the console** (`consoleRun`): up to `SECURITY_CONSOLE_MAX` 4 cells of `CORP_TABLE_3X1` centred on
  row y1, `CORP_COMPUTERS` on each, a chair at y1+1 on every cell but the MIDDLE one, which is the
  guard post (`securityPost`, read by `AreaGame.corpSpawnPoints` into
  `importantGuardSpawnPoints`). A door in the north wall SPLITS the run: the desks stand either
  side of it and the door's own cell stays floor (see below). The old mid-room `deskRun` is the
  fallback only when the door leaves no cell.
- **the racks**: `wallColumn(x2)`, i.e. SERVER cells on the east wall that are not a door cell, not
  beside one, and hold no object, laid as `RACK_HIGH` + `CORP_MACHINERY`.
- **the lockers**: `wallColumn(x1)` capped at `SECURITY_LOCKERS_MAX` 4, as `Const.TILE_CORP_LOCKER`.
  One of them goes to `state.area.add('gunCabinet', x, y)` instead: the one nearest the run's
  middle that is not a room corner and has free SERVER floor at x+1. The cabinet is a WALKABLE tile
  under a BLOCKING object, so a cabinet walled in by lockers and the desk read as a sealed pocket,
  and `openPockets` tore the console out (199 rooms in 3000 seeds with no desk run).
- **`columnsOpen` validates the set with `roomOpen(..., joined = true)`**: a flood from ONE door that
  must reach every floor cell. Plain `roomOpen` passed a rack column that split the room between
  two doors, since each half had its own door. While it fails, lockers go first, then the rack tail.

**Opaque ids.** `rackRows` takes its tile from the caller now: the server room and security both lay
`Const.TILE_RACK_HIGH` 15 (row 0's last spare slot, already walkable 0 and see-through 0), written
as temp `CorpTemp.RACK_HIGH` 46 for `ARCHIVE_HIGH`'s reason. `TILE_CORP_LOCKER` is `OFFSET_ROW17 + 3`,
and row 17 past index 1 is already unwalkable. The wall-dressing `CORP_MACHINERY` stays on the
see-through 222 twin. New areas only, with no repair of old saves. The renderer reads the room
through `CorpModel.securityRoom`, the ONE place it reads a generatorInfo role, since a SERVER
floor alone cannot tell the security room from the server room.

`GenCheck.securitySane` asserts a desk run, a walkable post, and at most one `gunCabinet` per room.
3000 corp seeds OK. furn/security 22.2% -> **32.97%**, spawns/gunCabinet **0.71** per floor (the
other ~29% of floors have no security room, or no cabinet cell passed the checks).

### Security lockers are walkable; the cabinet picks before the racks

Asked for as "allow movement in front of the lockers". A locker is `LOCKER_D` 1.3 deep and stands
off the slab's room face, entirely in the wall's own 1.4 margin and clear of its cell. So
`TILE_CORP_LOCKER` is walkable and see-through now (`tiles.Default` row 17). The table is static and
not persisted, so old towers pick it up on load.

That changes what can seal the room: only the cabinet and the racks. `security` picks the cabinet
FIRST, as the room's feature: the best locker cell that leaves the floor open with the cabinet
alone. The rack tail then pops until `columnsOpen(racks + cabinet)` holds. Racks first measured 0.40
cabinets per floor, cabinet first **0.61**.

The 0.71 quoted above was measured BEFORE the corner guard went in. 0.61 is the rate with it, and
it is candidate-bound: a trace over 3000 seeds had the cabinet chosen in 1826 of 2998 security
rooms, and never lost afterwards. The misses are small rooms (5x4, 4x5) whose only west-wall cells
are corners or have no free floor beside them. 3000 corp seeds OK, furn/security 23.18 (lockers no
longer count as sealed cells).

Then "cells in front of server racks are still unwalkable": the security room's column was
`TILE_RACK_HIGH`, the server room's opaque rank id, while the render had just moved the rack flush to
the wall. The column is `Const.TILE_CORP_WALL_RACK` (`OFFSET_ROW17 + 4`) now: walkable and
see-through, the locker's case. `CorpFurniture.rack` builds a wall-backed rack `RACK_WALL_D` 1.3 deep,
which is the locker's depth and inside the wall's margin. So nothing in a security room seals the
floor but the cabinet, and the rack pop loop is gone. The server room's mid-room ranks keep the
opaque id, so they still block sight. 3000 corp seeds OK, spawns/gunCabinet 0.61, furn/security 11.87.

### The security room has no windows; the gun cabinet is walkable

Reported as "everything is in front of the window": a room on the tower's edge kept its curtain wall,
and one beside an office kept its partition glass, so the racks and lockers stood against panes.
`security` now bricks its whole wall ring first: every `BLDG_WINDOW*` back to `BLDG_WALL`, every
`INNER_WINDOW*` back to `BLDG_INNER_WALL` (the render ignores the H1/H2/H3 frames, so a neighbour's
run cut short is not closed off). The old north-row brick-up in `consoleRun` is a subset of it.

The cabinet is walkable too (`GunCabinet.isWalkable`): it stands in the wall's margin like the
lockers, and its door swings through whoever stands in front of it. Nothing in the room can seal the
floor any more, so `columnsOpen` is gone; the cabinet still wants free SERVER floor at x+1 for its door.
3000 corp seeds OK.

### The console stands around a north-wall door

"make them around the door": a door opening onto the console row used to fail `consoleRun`, and the
fallback mid-room `deskRun` drew as bare tables (the render seats only the console). Now every cell
of the centred window that is not `atDoor` takes a desk, each stretch between doors its own 3x1 run
(end pieces on the stretch's ends, a lone cell the middle piece) and its own `ZONE_DESK_RUN`. The
post is the middle of the desk LIST, which is `securityPost`'s own pick off the finished row, and
takes no chair. The north-row brick-up went with it, the ring's unglazing covers it.
3000 corp seeds OK.

## SHORTER CORRIDORS PARALLEL TO THE MAIN ONE, AND A CORRIDOR ENDS ON A CORRIDOR

("a couple shorter corridors parallel to the main, including sometimes directly adjacent to outer
wall, but at least a room away from main".) `CorpBuilding.parallelCorridors` runs after the main
corridor and its side corridors are carved and before the inner-wall pass. It makes
`PARALLEL_CORRIDORS_MIN`..`_MAX` (3-4) tries. Each try:
- takes the next hand of the main corridor, alternating from a random first one, so both sides get
  theirs ("3-4, so that we have them on both sides"; measured: no floor of 3000 one-sided);
- picks a bay on that hand that no earlier try took. A bay is the bare floor between two side
  corridors, or between one and the outer wall;
- at `PARALLEL_LONG_PCT` (30), takes the next bay as well, across the side corridor between them.

Every new corridor is `SIDE_CORRIDOR_W` wide.

- **It ends on a corridor or on the ring, never mid-floor.**
  - `AreaGenerator.getRoom` reads a room as the rectangle off its top-left cell. A stub that
    stopped mid-bay would leave an L, which comes out as two rooms with open floor between them.
  - A bay always ends on a corridor or the ring, because every side corridor runs from the main
    corridor to the outer wall. That is also why the bays can be read off the cells beside the main
    corridor: they are the same at any distance from it.
- **The offset `o`** counts bare-floor cells from the main corridor's edge.
  - `o >= ROOM_SIZE + 2`, so the room between keeps ROOM_SIZE of floor inside its two inner walls.
  - The outer side is either flush (`o = len - 2`) or keeps ROOM_SIZE as well
    (`o <= len - ROOM_SIZE - 3`).
  - Flush at `PARALLEL_FLUSH_PCT` (35), and always when that range is empty. A 50-tall floor with
    the lift on a short wall has 16-cell hands, and flush is all that fits.
- **A flush corridor's ring is glazed** as one frame run, carried straight on across the
  side-corridor caps it meets. `CorpModel.runsOfThree` then trims it to whole panes like any room
  wall.
- **No window where a corridor ends on the ring.**
  - A corridor end is 2 cells across. `runsOfThree` turns any run shorter than 3 to masonry, and
    `CorpModel.sealWindows` writes that back into the grid on entry.
  - A 2-cell end window was tried, for these corridors and for the side corridors' 60% roll (which
    writes ONE cell, `loneWindows`' case). Both passed the oracle and both were wall again once the
    floor was entered, so both were dropped.

**Measured over 3000 floors, at 3-4 tries:** rooms 27.62 and doors 33.08; the quota kinds hold and
the exec filler takes the loss (16.85 → 16.14). 3000/3000 green.

**At the first cut, 2 tries on a random hand:**
- 2.0 placed per floor: 48% flush (the 35% roll plus the forced ones), 22% spanning two bays.
- Rooms 29.36 → 28.32 and doors 36.57 → 34.55.
- Rooms with no door of their own onto a corridor: 1.09 → 0.89 per floor. Exec rooms 3.0% → 2.4%,
  reception 34% → 31%.
- 3000/3000 green. The digests change.
- 0 tries gave the old stream back (rooms 29.36, doors 36.57).

**Where a bay is only 5 cells**, the parallel corridor is a short rung between two adjacent side
corridors. The floor then reads as a grid rather than a comb.
