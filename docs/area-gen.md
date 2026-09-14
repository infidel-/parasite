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
  ├ parking
  │ └ entryway               the 4x2 hole through the sidewalk
  ├ park
  └ yard                     the filler kind: whatever nothing claimed
```

**Breadth-first is load-bearing.** Depth-first would finish a whole building before the neighbouring
park existed, so a filler could not ask what is next to it. Same reason the wilderness lays its
highway before its trees.

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
| `gen/GenRun.hx` | headless entry point of `bin/genrun.js` |
| `gen/blocks/*Block.hx` | one filler per block kind. Suffix is `Block`, always |
| `gen/blocks/FacilityBlocks.hx` | the compound's profile, quota and `plan()` |

### The facility, after the split

`game/FacilityAreaGenerator.hx` was 2432 lines in one class. Two measurements made the split a move
rather than a redesign: **`game` was used once** in the whole file, and **`gen: AreaGenerator` was
used zero times** — so every pass was already effectively static.

| file | what it is |
|---|---|
| `game/FacilityAreaGenerator.hx` | the LIVE adapter, and all that still needs a `Game`: `generate()` wraps the grid in a ctx and drains the spawns, `repairRooms()` re-derives rooms from a SAVED grid and so takes an `AreaGame` |
| `gen/facility/FacilityGen.hx` | `build()` — the real entry point, the one the oracle calls — and `finalizeTiles` |
| `gen/facility/FacilityTemp.hx` | the `TEMP_*` alphabet, the temp→final map, and the four constants more than one pass reads |
| `gen/facility/_FacilityState.hx` | what a compound looks like mid-build. Not persisted |
| `gen/facility/FacilityBuilding.hx` | one lab building: wall ring, corridors, room subdivision, glazing and bench runs |
| `gen/facility/FacilityConnect.hx` | every door, and both reachability passes — `fixDoors` on the room graph, `connectRooms` on the tile grid |
| `gen/facility/FacilityRooms.hx` | the room templates and the shared placement helpers |
| `gen/facility/FacilityToilet.hx` | the washroom and its T-partition |
| `gen/blocks/ParkBlock.hx`, `HangarBlock.hx` | already at their Phase 4 home; only the signature changes when the tree starts driving them |

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

**Quotas, not dice, for anything mandatory.** `FacilityRooms.assignRoomThemes` rolls a 60 for the
washroom, which is why 40% of compounds have no washroom — not a decision, just a roll standing in
for "usually". `_GenDemand` says the thing that was meant: at least `min`, at most `max`, and a `fit`
function for which rect suits it.

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
rooms          18.81   spawns/TOTAL      198.24   blocks/TOTAL  6.52
doors          18.02   spawns/decoration 157.49   blocks/yard   1.52
cells/rooms   841.26   spawns/door        25.57   planTries     1.05
cells/building 1243    spawns/vent         7.00   planRetried   0.05
cells/yard      554    spawns/floorDrain   4.23
                       spawns/sewerHatch   3.95
unreachableRooms 0        reachedCells 3052 / walkableCells 3060
```

**Read those to ±0.15, not ±0.01.** Three disjoint 4000-seed ranges give `rooms` 18.81 / 18.96 /
18.92, so one range's mean carries about that much sampling error and a 1% move between two runs says
nothing. What is exact here is the block half — `blocks/*`, `cells/building` and `cells/yard` come off
`FacilityBlocks.plan`'s own stream and do not move at all unless the split or the quota changed.
For anything finer than the means, use `--digest`.

`planTries 1.05` is the margin between the split profile and the quota: the first split houses
everything 95% of the time. A mean creeping up is the warning that comes before the retry cap is hit
and a compound ships without its second building.

Yard at ~17% of the area is not waste — it is the open ground `FacilityDebris`, `FacilityCars` and
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

**Now zero across 6000 seeds, and asserted rather than counted.** The `reachedCells` /
`walkableCells` stats exist to validate the check itself — they sit at 3052/3060, so the flood really
does cover the grid and a zero is a zero.

## Invariants downstream re-derives from the grid

These break **silently, with no compile error**, because the consumer reverse-engineers them out of
tiles rather than being handed them:

- `AreaGame.gate()` re-derives the checkpoint from "a plain 4x2 hole of alley through the sidewalk
  band beside the road" — `ParkingBlock`'s entryway child must keep producing exactly that
- `FacilityModel.isParkPath` needs the park's 2-cell walkway path (slack `PATH_MAX = 4`)
- `Surf.LOT` is just "the alley fill" — parking must still finalize to `TILE_ALLEY`
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
