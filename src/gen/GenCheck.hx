// structural assertions over a generated area
//
// THE ORACLE. Every one of these is a property the game reads back out of a generated area and
// crashes, or silently loses a feature, when it does not hold — and every one of them is cheap to
// check here and expensive to notice in the running game, where it means launching Electron,
// loading a save, walking to the far side of a compound and looking.
//
// run from tools/genrun.mjs over hundreds of seeds. A check names the invariant and the seed that
// broke it; it never repairs anything.

package gen;

class GenCheck
{
  // how wide a walkway run the park-path test will still cross. render.facility.FacilityModel
  // .PATH_MAX, and it has to stay the same number — this asserts the thing that file will find
  public static inline var PATH_MAX = 4;

  public var failures: Array<String>;
  var seed: Int;

  public function new(vseed: Int)
    {
      seed = vseed;
      failures = [];
    }

// record one failed invariant
  public function fail(what: String)
    failures.push('seed ' + seed + ': ' + what);

// assert, with the message only built when it actually failed
  public inline function ok(cond: Bool, what: String)
    {
      if (!cond)
        fail(what);
    }

// --- block-level checks: the tree a split and a deal produced ---

// no two blocks may share a cell. a filler writes its whole rect, so two overlapping blocks means
// whichever ran second silently ate part of the first
  public function noOverlap(blocks: Array<_GenNode>)
    {
      for (i in 0...blocks.length)
        for (j in i + 1...blocks.length)
          if (GenTree.overlaps(blocks[i], blocks[j]))
            fail('blocks overlap: ' + rect(blocks[i]) + ' (' + blocks[i].kind + ') and ' +
              rect(blocks[j]) + ' (' + blocks[j].kind + ')');
    }

// every block stays inside the area, and none of them is degenerate
  public function inBounds(blocks: Array<_GenNode>, w: Int, h: Int)
    {
      for (b in blocks)
        {
          ok(b.x1 >= 0 && b.y1 >= 0 && b.x2 < w && b.y2 < h,
            'block out of bounds: ' + rect(b));
          ok(b.x2 >= b.x1 && b.y2 >= b.y1, 'degenerate block: ' + rect(b));
        }
    }

// every demand's min is met and no demand's max is exceeded. the check the whole quota exists for
  public function quotaMet(blocks: Array<_GenNode>, demands: Array<_GenDemand>)
    {
      for (d in demands)
        {
          var n = Quota.count(blocks, d.kind);
          ok(n >= d.min, 'quota short: "' + d.kind + '" got ' + n + ', needs ' + d.min);
          ok(n <= d.max, 'quota over: "' + d.kind + '" got ' + n + ', max ' + d.max);
        }
    }

// a dealt block is big enough for what it was dealt. gen.Quota promises this, so a failure here is
// the dealer being wrong rather than the split being unlucky
  public function blocksFit(blocks: Array<_GenNode>, demands: Array<_GenDemand>)
    {
      for (d in demands)
        for (b in blocks)
          {
            if (b.kind != d.kind)
              continue;
            ok(GenTree.width(b) >= d.minW && GenTree.height(b) >= d.minH,
              '"' + d.kind + '" dealt an undersized block: ' + rect(b) +
              ' needs ' + d.minW + 'x' + d.minH);
            ok(d.must == null || d.must(b),
              '"' + d.kind + '" dealt a block its own `must` rejects: ' + rect(b));
          }
    }

// every leaf of a split clears the profile's own floor, and none exceeds its cap
  public function splitSane(blocks: Array<_GenNode>, p: _SplitProfile)
    {
      for (b in blocks)
        {
          var w = GenTree.width(b);
          var h = GenTree.height(b);
          ok(w >= p.minSide && h >= p.minSide,
            'split leaf under minSide ' + p.minSide + ': ' + rect(b));
          ok(w <= p.maxSide && h <= p.maxSide,
            'split leaf over maxSide ' + p.maxSide + ': ' + rect(b));
        }
    }

  // --- grid-level checks: a whole generated area ---

// every cell holds a tile the tileset actually has.
//
// THIS CANNOT BE A "NO TEMP IDS LEFT" CHECK, which is what it was first written as and why that
// version reported 790 bad cells on a perfectly good compound: the temp alphabet runs 0..28 and the
// real ids OVERLAP it — TILE_BUILDING is 2, TILE_WALL 4, TILE_BUSH 9, TILE_GRASS 10. A finalized
// facility is full of legitimate single-digit tiles and there is no numeric test that separates
// them from a missed temp id. What can be tested is the range: an id past the end of the
// walkability table indexes nothing, and tiles.Tileset hands the renderer whatever that returns
  public function tilesKnown(ctx: GenCtx)
    {
      var max = tiles.Default.TILE_WALKABLE.length;
      var bad = 0;
      var worst = -1;
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          {
            var t = ctx.cells[x][y];
            if (t >= 0 &&
                t < max)
              continue;
            bad++;
            if (t > worst)
              worst = t;
          }
      ok(bad == 0, bad + ' cells hold a tile id outside the tileset (highest ' + worst +
        ', table holds ' + max + ')');
    }

// rooms are inside the area, non-degenerate, uniquely numbered, and their w/h agree with their
// corners. `x2` is the LAST cell, which is the convention every consumer indexes with — an
// off-by-one here reaches the renderer as a ceiling light hanging through a wall
  public function roomsSane(ctx: GenCtx, rooms: Array<_Room>)
    {
      var seen = new Map<Int, Bool>();
      for (r in rooms)
        {
          ok(r.x1 >= 0 && r.y1 >= 0 && r.x2 < ctx.width && r.y2 < ctx.height,
            'room ' + r.id + ' out of bounds: ' + r.x1 + ',' + r.y1 + '..' + r.x2 + ',' + r.y2);
          ok(r.x2 >= r.x1 && r.y2 >= r.y1, 'room ' + r.id + ' degenerate');
          ok(r.w == r.x2 - r.x1 + 1 && r.h == r.y2 - r.y1 + 1,
            'room ' + r.id + ' w/h disagrees with its corners: ' + r.w + 'x' + r.h);
          // ids are keyed on by _Door.roomID1/2, by _GeneratorInfo.getRoom and by three cult
          // missions, and they are stamped into the cell grid as marks — a duplicate silently
          // merges two rooms for every one of those readers
          ok(!seen.exists(r.id), 'duplicate room id ' + r.id);
          seen.set(r.id, true);
        }
    }

// every door resolves to rooms that exist. scenario.AlienMissionCommon locks a room by walking
// generatorInfo.doors for `roomID1 == room.id`, so a door naming a room that was never recorded is
// a mission that silently locks nothing
  public function doorsSane(ctx: GenCtx, rooms: Array<_Room>, doors: Array<_Door>)
    {
      var ids = new Map<Int, Bool>();
      for (r in rooms)
        ids.set(r.id, true);
      var pairs = new Map<String, Bool>();
      for (d in doors)
        {
          ok(d.x >= 0 && d.y >= 0 && d.x < ctx.width && d.y < ctx.height,
            'door out of bounds: ' + d.x + ',' + d.y);
          // roomID 0 is the sentinel for "a corridor, or outdoors", not a room id
          ok(d.roomID1 == 0 || ids.exists(d.roomID1),
            'door at ' + d.x + ',' + d.y + ' names unknown room ' + d.roomID1);
          ok(d.roomID2 == 0 || ids.exists(d.roomID2),
            'door at ' + d.x + ',' + d.y + ' names unknown room ' + d.roomID2);
          if (d.skip)
            continue;
          // two live doors between the same pair of ROOMS is what fixDoors exists to remove — but
          // only between two rooms. A room with several doors onto corridors is intended and
          // common: fixDoors skips roomID2 == 0 explicitly, and makeDoorToCorridor adds a second
          // one on purpose when a room cluster has no way out
          if (d.roomID1 == 0 ||
              d.roomID2 == 0)
            continue;
          var lo = (d.roomID1 < d.roomID2 ? d.roomID1 : d.roomID2);
          var hi = (d.roomID1 < d.roomID2 ? d.roomID2 : d.roomID1);
          var key = lo + ':' + hi;
          ok(!pairs.exists(key), 'two doors between rooms ' + lo + ' and ' + hi);
          pairs.set(key, true);
        }
    }

// no two worktops touch ONLY at a corner.
//
// render.facility.FacilityTables grows every bench by BENCH_LIP on each side with no table
// orthogonally beside it, and it has no diagonal probe at all, so a pair like that draws two caps
// overlapping in a lip-squared square with their edge bands crossing — the reported "tables
// intersect each other diagonally". gen.facility.FacilityRooms.fixDiagonalTables closes each
// pair up; this is what says it closed every one
//
// THE PREDICATE IS ABOUT THE PAIR AND NOT ABOUT THE CELL, which is the whole of the second pass on
// this. The first cut asked whether a cell had NO orthogonal table beside it and a diagonal one —
// i.e. whether it was LOOSE — and two table RUNS whose ends meet corner to corner have an orthogonal
// neighbour each, so neither was ever looked at. 20000 seeds came back clean over a fault that was
// still on screen at 27,14. Two cells touch corner-only when they are diagonal AND both of the two
// cells they share are bare; that is the thing FacilityTables cannot see, stated directly
  public function tablesSane(ctx: GenCtx)
    {
      var bad = 0;
      var first = '';
      for (y in 1...ctx.height - 1)
        for (x in 1...ctx.width - 1)
          {
            if (!table(ctx, x, y))
              continue;
            // the two diagonals with a HIGHER y only: the other two are the same pairs seen from
            // their far cell, and counting both ends doubles every fault
            for (dx in [ -1, 1 ])
              if (corner(ctx, x, y, dx, 1))
                {
                  bad++;
                  if (first == '')
                    first = x + ',' + y;
                }
          }
      ok(bad == 0, bad + ' worktop pair(s) touch only at a corner, first at ' + first);
    }

// do (x,y) and its (dx,dy) diagonal touch ONLY at that corner?
  inline function corner(ctx: GenCtx, x: Int, y: Int, dx: Int, dy: Int): Bool
    {
      return (table(ctx, x + dx, y + dy) &&
        !table(ctx, x + dx, y) &&
        !table(ctx, x, y + dy));
    }

// the tile range gen.facility.FacilityRooms and render.facility.FacilityModel.tableOf both read a
// worktop out of
  inline function table(ctx: GenCtx, x: Int, y: Int): Bool
    {
      return Const.isTableTile(ctx.cells[x][y]);
    }

// a washroom hangs off a CORRIDOR, through exactly ONE door.
//
// asserted over the FINAL door list and not inside gen.facility.FacilityRooms, because the pick
// there runs three passes before the last door is cut: game.FacilityAreaGenerator.connectRooms walks
// the finished tile grid and cuts into anything the flood cannot reach, and nothing in it asks a
// room's role. So the filter states the intent and this states the outcome.
//
// gen.facility.FacilityToilet lays its T against the FIRST door of the room and models no second
// one, so a washroom with two of them comes back with a partition sealing half of itself
  public function washroomSane(rooms: Array<_Room>, doors: Array<_Door>)
    {
      for (r in rooms)
        {
          if (r.role != gen.facility.FacilityTemp.ROLE_TOILET)
            continue;
          // NOT FILTERED ON `skip`, which is bookkeeping and not a state: fixDoors deletes the
          // door it drops from the list outright and sets `skip` on the one it KEEPS, so a skipped
          // door is a live door. Filtering it out reported every washroom as having none
          // ITS OWN doors, which is the set gen.facility.FacilityRooms.washroomDoor picks on and
          // the set FacilityToilet lays its T against. A NEIGHBOUR'S door in a shared wall is that
          // room's business and is allowed here: asserting on every door in the washroom's walls
          // rejected 21.8% of lab structures as washroom-less for a door the washroom never cut,
          // and closing that gap is what makes a toilet guaranteed rather than a 60% roll
          var mine = [for (d in doors) if (d.roomID1 == r.id) d];
          ok(mine.length == 1, 'washroom at ' + r.x1 + ',' + r.y1 + ' cut ' + mine.length +
            ' doors of its own, not 1');
          // and NOBODY ELSE'S door opens into it: a room reached only through the toilets is the
          // fault gen.facility.FacilityConnect.sealWashroom exists to stop
          var theirs = [for (d in doors) if (d.roomID2 == r.id && d.roomID1 != r.id) d];
          ok(theirs.length == 0, 'washroom at ' + r.x1 + ',' + r.y1 + ' has ' + theirs.length +
            ' door(s) from a neighbouring room into it');
          // roomID 0 is the sentinel for "a corridor, or outdoors" — doorsSane's own note
          for (d in mine)
            ok(d.roomID2 == 0,
              'washroom at ' + r.x1 + ',' + r.y1 + ' has a door at ' + d.x + ',' + d.y +
              ' onto room ' + d.roomID2 + ' and not a corridor');
        }
    }

// NO CORP ROOM IS REACHED ONLY BY WALKING THROUGH A TOILET OR THE SERVER ROOM.
//
// THE FAULT IT IS FOR: gen.corp.CorpBuilding.makeDoors cuts each room exactly one door at a random
// valid wall spot and nothing in the pick asks what is on the far side, so a door can open into
// the room next door. fixDoors then used to repair CLUSTERS, accepting a group the moment any one
// of its rooms touched a corridor — which passed `servers -> toilet -> corridor`, reported from
// the game as a server room you could only enter through the WC.
//
// `reachable` cannot say this. It floods the walkable grid from the lift, and a room behind
// another room IS reached — the right question for a room that was sealed shut and the wrong one
// for a room whose only route runs through somebody's toilet.
//
// SO THE WALK IS OVER THE DOOR GRAPH AND NOT THE TILES, from the corridor (room 0 — doorsSane's
// own sentinel note), and a toilet or a server room is entered but never passed THROUGH. A suite
// whose inner office opens off an outer one is left alone: that is a building, not a bug. Not
// filtered on `skip`, for the reason washroomSane records — a skipped door is a live door
  public function corpRoutesSane(rooms: Array<_Room>, doors: Array<_Door>)
    {
      var dead = [gen.corp.CorpTemp.ROLE_TOILET, gen.corp.CorpTemp.ROLE_SERVERS];
      var roleOf = new Map<Int, String>();
      for (r in rooms)
        roleOf.set(r.id, r.role);
      var seen = new Map<Int, Bool>();
      var open = [0];
      seen.set(0, true);
      while (open.length > 0)
        {
          var id = open.pop();
          // a dead-end room is a destination and not a corridor: nothing is expanded through it
          if (id != 0 && Lambda.has(dead, roleOf.get(id)))
            continue;
          for (d in doors)
            {
              var far = (d.roomID1 == id ? d.roomID2 : (d.roomID2 == id ? d.roomID1 : -1));
              if (far < 0 || seen.exists(far))
                continue;
              seen.set(far, true);
              open.push(far);
            }
        }
      for (r in rooms)
        ok(seen.exists(r.id), 'corp room ' + r.id + ' at ' + r.x1 + ',' + r.y1 + ' (' + r.role +
          ') is reached only through a toilet or the server room');
    }

// a store can be walked all the way through, and its door opens onto floor.
//
// THE FAULT IT IS FOR IS THE ROOM'S OWN FURNITURE. A pallet rack is 4.2 tall and `standing` fills
// its bay bar one cell, so a store is the first room in the compound that can seal a pocket of its
// own floor off — gen.blocks.RoomZones reserves an AISLE bay against exactly that, and this is what
// says the reservation worked. `reachable` above cannot: it counts a room as reached if ANY of its
// cells was, which is the right question for a door that was never cut and the wrong one for a
// corner walled in by racking.
//
// IT READS `lastSeen`, i.e. the flood `reachable` has already run, so it must be called after it —
// re-flooding here would be a second implementation of the one thing this file exists not to have
  public function storageSane(ctx: GenCtx, rooms: Array<_Room>, doors: Array<_Door>)
    {
      var walk = tiles.Default.TILE_WALKABLE;
      for (r in rooms)
        {
          if (r.role != gen.facility.FacilityTemp.ROLE_STORAGE)
            continue;
          var at = r.x1 + ',' + r.y1;
          var free = 0;
          for (y in r.y1...r.y2 + 1)
            for (x in r.x1...r.x2 + 1)
              {
                var t = ctx.cells[x][y];
                if (t < 0 ||
                    t >= walk.length ||
                    walk[t] == 0)
                  continue;
                free++;
                ok(lastSeen[x][y], 'store at ' + at + ' has floor at ' + x + ',' + y +
                  ' that nothing can walk to');
              }
          ok(free > 0, 'store at ' + at + ' has no walkable floor left in it');
          // and every door of it — its own and a neighbour's in a shared wall — has floor on this
          // side. A rack dealt into the cell behind a doorway is a door that opens onto steel
          for (d in doors)
            {
              if (d.roomID1 != r.id &&
                  d.roomID2 != r.id)
                continue;
              var lane = 0;
              for (i in 0...Const.dir4x.length)
                {
                  var x = d.x + Const.dir4x[i];
                  var y = d.y + Const.dir4y[i];
                  if (x < r.x1 ||
                      x > r.x2 ||
                      y < r.y1 ||
                      y > r.y2)
                    continue;
                  var t = ctx.cells[x][y];
                  if (t >= 0 &&
                      t < walk.length &&
                      walk[t] == 1)
                    lane++;
                }
              ok(lane > 0, 'store at ' + at + ' has a door at ' + d.x + ',' + d.y +
                ' with nothing walkable inside the room beside it');
            }
        }
    }

// THE RECEPTION IS BY THE LIFT AND HAS A COUNTER IN IT.
//
// Both halves are a spec given against a floor that met neither: the room was dealt on `fit`
// alone with no reference to the elevator, and its "counter" was a borrowed copy of the
// executive's 3x2 slab standing in the middle of the floor. `gen.blocks.CorpBlocks.liftX/liftY`
// is the lift door's own cell and `gen.corp.CorpRooms.counter` lays the run over the room's front
// wall, `CorpBlocks.fronts`, so both are testable. RECEPTION_NEAR bounds the room's CENTRE, which the demand's
// `must` does not: that one bounds the nearest cell of its counter wall.
//
// THIS ASSERT WAS GREEN FOR A FLOOR THAT BROKE IT: `liftX/liftY` had all four `frontDir` cases
// mirrored, so it and the demand both measured against the far end of the main corridor and agreed
// with each other — a median 49.5 cells from the real car. An oracle that reads the generator's own
// idea of a landmark cannot catch that landmark being wrong
  public function receptionSane(ctx: GenCtx, rooms: Array<_Room>)
    {
      for (r in rooms)
        {
          if (r.role != gen.corp.CorpTemp.ROLE_RECEPTION)
            continue;
          var d = Std.int(Math.abs((r.x1 + r.x2) / 2 - gen.blocks.CorpBlocks.liftX)) +
            Std.int(Math.abs((r.y1 + r.y2) / 2 - gen.blocks.CorpBlocks.liftY));
          ok(d <= RECEPTION_NEAR, 'corp reception at ' + r.x1 + ',' + r.y1 +
            ' is ' + d + ' cells from the lift at ' + gen.blocks.CorpBlocks.liftX + ',' +
            gen.blocks.CorpBlocks.liftY + ' (max ' + RECEPTION_NEAR + ')');
          // and the counter is its WHOLE front wall, post to post — which also says no door is
          // left in it, since a door cell is floor and a door frame and not this id
          var front = gen.blocks.CorpBlocks.fronts.get(r.id);
          ok(front != null, 'corp reception at ' + r.x1 + ',' + r.y1 + ' has no front wall');
          if (front == null)
            continue;
          for (c in front)
            ok(ctx.cells[c.x][c.y] == Const.TILE_CORP_RECEPTION_COUNTER, 'corp reception at ' +
              r.x1 + ',' + r.y1 + ' has no counter at ' + c.x + ',' + c.y);
        }
    }

// a security room has its desk run, a walkable floor cell in front of it for the guard to stand
// on (game.AreaGame.initSpawnPoints posts him there), and at most one gun cabinet
  public function securitySane(ctx: GenCtx, rooms: Array<_Room>)
    {
      var walk = tiles.Default.TILE_WALKABLE;
      for (r in rooms)
        {
          if (r.role != gen.corp.CorpTemp.ROLE_SECURITY)
            continue;
          var at = 'corp security at ' + r.x1 + ',' + r.y1 + '..' + r.x2 + ',' + r.y2;
          var post = gen.corp.CorpRooms.securityPost(ctx.cells, r);
          ok(post != null, at + ' has no desk run');
          if (post != null)
            ok(post.y <= r.y2 &&
              walk[ctx.cells[post.x][post.y]] == 1, at + ' has no floor for its guard at ' +
              post.x + ',' + post.y);
          var cabs = 0;
          for (s in ctx.spawns)
            if (s.type == 'gunCabinet' &&
                s.x >= r.x1 &&
                s.x <= r.x2 &&
                s.y >= r.y1 &&
                s.y <= r.y2)
              cabs++;
          ok(cabs <= 1, at + ' holds ' + cabs + ' gun cabinets');
          // AND IT HAS ONE WAY IN, FROM THE CORRIDOR: a guard post is not a room you walk through
          // to reach another, nor one you enter through somebody's office
          var doors = 0;
          for (s in ctx.spawns)
            {
              if (s.type != 'door')
                continue;
              for (d in [ [ 0, -1 ], [ 0, 1 ], [ -1, 0 ], [ 1, 0 ] ])
                {
                  var ix = s.x + d[0], iy = s.y + d[1];
                  if (ix < r.x1 ||
                      ix > r.x2 ||
                      iy < r.y1 ||
                      iy > r.y2)
                    continue;
                  doors++;
                  var ox = s.x - d[0], oy = s.y - d[1];
                  var inRoom = null;
                  for (r2 in rooms)
                    if (ox >= r2.x1 &&
                        ox <= r2.x2 &&
                        oy >= r2.y1 &&
                        oy <= r2.y2)
                      inRoom = r2;
                  ok(inRoom == null, at + ' has a door at ' + s.x + ',' + s.y + ' into room ' +
                    (inRoom == null ? '' : inRoom.role + ' ' + inRoom.x1 + ',' + inRoom.y1));
                }
            }
          ok(doors == 1, at + ' has ' + doors + ' doors, want 1');
        }
    }

// AN ARCHIVE IS NOT A BARE FLOOR.
//
// The room whose whole point is its RANKS, and the one most able to roll itself empty: a rank is the
// interior cells x1+1 .. x2-1 minus one DEALT gap, `gen.corp.CorpRooms.rackRows` then skips each
// survivor at `chance` 25, and none of that is a fault the other oracles can see -- an empty room is
// perfectly reachable and seals no pocket, so `floorReachable` passes it. Reported from area 2067,
// whose archive held ONE cabinet.
//
// IT COUNTS ANY DRESSING AND NOT THE RANK, AND THAT IS NOT A WEAKER TEST BY CHOICE -- THE RANK IS
// NOT ASSERTABLE. gen.corp.CorpConnect.openPockets erodes an unwalkable cell (and the decoration
// standing on it) to reach a walkable cell the lift flood lost, and it is RIGHT to outrank a
// dressing: an unreachable room is worse than an undressed one. So a rank can be taken away after
// it is laid, and no placement rule in the template can promise otherwise -- the repo's own note is
// that a repair is not a placement rule, and this is that sentence from the other side. Two things
// were done about it rather than asserted: `rackRows` now guarantees ONE occupant per rank (a row
// that rolls itself empty is not a row) and the demand went to 5x5, which took the measured
// residual from 4 bare archives in 600 seeds to 2 in 3000 -- and both survivors are the repair
// working, not the template failing.
//
// What IS invariant is that the room was dressed at all: `decorateWalls` takes a CORNER
// unconditionally (`hasLeft || isCorner`), so every archive carries at least one cell of casework
// whatever every roll in it says, on the rank twin or on the small-table id it deals beside it
  public function archiveSane(ctx: GenCtx, rooms: Array<_Room>)
    {
      var shelf = Const.TILE_FLOOR_ARCHIVE + gen.corp.CorpTemp.UNWALKABLE_TILE_OFFSET;
      for (r in rooms)
        {
          if (r.role != gen.corp.CorpTemp.ROLE_ARCHIVE)
            continue;
          var n = 0;
          for (x in r.x1...r.x2 + 1)
            for (y in r.y1...r.y2 + 1)
              if (ctx.cells[x][y] == shelf ||
                  ctx.cells[x][y] == Const.TILE_ARCHIVE_HIGH ||
                  ctx.cells[x][y] == Const.TILE_DARK_TABLE_WOOD2_1X1)
                n++;
          ok(n > 0, 'corp archive at ' + r.x1 + ',' + r.y1 + ' (' + r.w + 'x' + r.h +
            ') is a bare floor: no casework on any cell');
        }
    }

// A CORP WASHROOM HAS A SINK: at least two fixture cells side by side along a row.
//
// render.corp.CorpFurniture.washroom tells a basin from a WC cubicle by contiguity alone, so a lone
// fixture is a cubicle whatever the template meant by it. The basin run used to be centred blind
// and skip the cell under a doorway, which split a three-basin run into two lone fixtures — a
// washroom of four stalls and no sink, reported from area 6475 at 44,16
//
// A BASIN IS A TAP ON THE WALKABLE FLOOR now (gen.corp.CorpRooms.toilet), the twin being for the
// stalls, which fill their cell; a save from before stands its basins on the twin, which still counts
  public function corpWashroomSane(ctx: GenCtx, rooms: Array<_Room>)
    {
      var fixture = Const.TILE_FLOOR_MARBLE2 + gen.corp.CorpTemp.UNWALKABLE_TILE_OFFSET;
      var taps = new Map<Int, Bool>();
      for (s in ctx.spawns)
        if (s.type == 'decoration' &&
            isTap(s.row, s.col))
          taps[s.x * 1000 + s.y] = true;
      var isBasin = function(x: Int, y: Int) return (ctx.cells[x][y] == fixture ||
        (ctx.cells[x][y] == Const.TILE_FLOOR_MARBLE2 && taps[x * 1000 + y]));
      for (r in rooms)
        {
          if (r.role != gen.corp.CorpTemp.ROLE_TOILET)
            continue;
          var basin = false;
          for (x in r.x1...r.x2)
            for (y in r.y1...r.y2 + 1)
              if (isBasin(x, y) &&
                  isBasin(x + 1, y))
                basin = true;
          ok(basin, 'corp washroom at ' + r.x1 + ',' + r.y1 + ' (' + r.w + 'x' + r.h +
            ') has no basin run: no two fixtures side by side');
        }
    }

// is this entities64 frame one of Const.CORP_TAP's?
  static function isTap(row: Int, col: Int): Bool
    {
      for (t in Const.CORP_TAP)
        if (t.row == row &&
            col >= t.col &&
            col < t.col + t.amount)
          return true;
      return false;
    }

// how far the reception's centre may be from the lift door, in cells. MEASURED over 3,000 seeds
// once the lift point was right and the demand had to front the corridor mouth: 7 to 12, worst 12
// in 12 towers. The plate's own diagonal is 88
  public static inline var RECEPTION_NEAR = 14;

// EVERY WALKABLE CELL OF EVERY ROOM CAN BE WALKED TO — the general form of `storageSane` above,
// and the check `reachable` is structurally incapable of being.
//
// `reachable` counts a room as reached when ANY of its cells was, and the comment defending that
// ("its furniture cannot cut that rect in two") is simply false — gen.corp.CorpConnect.roomReached
// carries the same sentence and the same fault. MEASURED before this existed, over 120 corp seeds
// and 3,500 rooms: 873 rooms (24.9%) held floor the lift flood never reached, 4,482 cells in all,
// 37.4 per floor, with a worst case of an 8x6 archive whose 33 walkable cells had ONE reachable —
// the cell behind its door, boxed in by a rack row and two wall dressings. The oracle was green on
// every one of them, and the evidence was in the stats block the whole time: walkableCells 1236.28
// against reachedCells 1197.98.
//
// IT READS `lastSeen` and so must be called after `reachable`, for that function's own reason
  public function floorReachable(ctx: GenCtx, rooms: Array<_Room>)
    {
      var walk = tiles.Default.TILE_WALKABLE;
      for (r in rooms)
        for (y in r.y1...r.y2 + 1)
          for (x in r.x1...r.x2 + 1)
            {
              var t = ctx.cells[x][y];
              if (t < 0 ||
                  t >= walk.length ||
                  walk[t] == 0)
                continue;
              ok(lastSeen[x][y], 'room ' + r.id + ' (' + r.role + ') at ' + r.x1 + ',' + r.y1 +
                '..' + r.x2 + ',' + r.y2 + ' has floor at ' + x + ',' + y +
                ' that nothing can walk to');
            }
    }

// the hangar's floor holds one study pad, centred, clear of its own walls and clear of its door.
//
// THE PAD IS CARVED AND NOT DEALT, which is why it gets a check of its own: gen.Quota reports
// nothing when a demand goes unplaced, and the pad never goes through gen.Quota at all. It is also
// the one zone whose position is load-bearing on the RENDER side — render.facility.FacilityHangar
// recovers the podium from this cluster of unwalkable concrete and from nothing else, the way the
// roof and the parked cars are recovered — so a pad that came out off-centre, clipped by a wall or
// split in two is a podium standing somewhere nobody put one.
//
// asserted over the finished GRID rather than over the tree, for the same reason decoBlocks is:
// three arms write unwalkable concrete into a hangar (the pad, the standing runs, the slot filler)
// and only one of them is the pad. The cluster this finds is the pad exactly when the annulus rule
// holds, and that is the thing worth holding
  public function hangarSane(ctx: GenCtx, rooms: Array<_Room>)
    {
      for (r in rooms)
        {
          // the hangar is the room floored in concrete — the same majority test
          // render.facility.FacilityModel uses to tell the shed from a lab building
          var concrete = 0;
          for (x in r.x1...r.x2 + 1)
            for (y in r.y1...r.y2 + 1)
              if (ctx.cells[x][y] == Const.TILE_FLOOR_CONCRETE ||
                  ctx.cells[x][y] == Const.TILE_FLOOR_CONCRETE_UNWALKABLE)
                concrete++;
          if (concrete * 2 <= r.w * r.h)
            continue;
          // a floor too small to carry the pad and still have a wall run gets none, which
          // gen.blocks.HangarBlock.zones decides and this has to allow
          if (r.w < gen.blocks.HangarBlock.PAD_SZ + 4 ||
              r.h < gen.blocks.HangarBlock.PAD_SZ + 4)
            continue;
          var px1 = r.x1 + Std.int((r.w - gen.blocks.HangarBlock.PAD_SZ) / 2);
          var py1 = r.y1 + Std.int((r.h - gen.blocks.HangarBlock.PAD_SZ) / 2);
          var bad = 0;
          for (x in px1...px1 + gen.blocks.HangarBlock.PAD_SZ)
            for (y in py1...py1 + gen.blocks.HangarBlock.PAD_SZ)
              if (ctx.cells[x][y] != Const.TILE_FLOOR_CONCRETE_UNWALKABLE)
                bad++;
          ok(bad == 0, 'the hangar at ' + r.x1 + ',' + r.y1 + ' has ' + bad +
            ' cell(s) of its study pad missing');
          // and the annulus: the pad never touches the wall ring, so the shed can be walked round
          ok(px1 > r.x1 && py1 > r.y1 &&
            px1 + gen.blocks.HangarBlock.PAD_SZ - 1 < r.x2 &&
            py1 + gen.blocks.HangarBlock.PAD_SZ - 1 < r.y2,
            'the hangar at ' + r.x1 + ',' + r.y1 + ' has its study pad against a wall');
        }
    }

// no decoration stands in a room its own table entry never allowed.
//
// THERE WAS NO DECORATION INVARIANT HERE AT ALL, which is the whole reason a bank of MACHINES came
// back standing next to the cubicles in a washroom and nothing said so. `washroomSane` above is
// about doors; `spawnsSane` below is about cells; nothing in this file had ever looked at what a
// decoration IS. `_DecoPlace.blocks` is the statement of where each one may stand, gen.Deco.places
// filters on it — and then three separate arms put fittings on the grid WITHOUT going through that
// filter, so the field was load-bearing in one code path and decorative in the others.
//
// THE CHECK IS OVER THE RESULT AND NOT OVER THE DEALER, which is the point. It reads the finished
// grid the way the renderer and a savegame do — frame -> Const.placeOf -> `blocks` -> the role of
// the room the cell falls in — so it holds however the decoration got there: the rolled arm, the
// outright placeFitting arm, and the raw CHEM_LABS_DECO_* row lists that consult no table at all.
// Checking the dealer instead would have passed every one of them.
//
// A frame on no entry (the table-top clutter rows) is not a fitting and has nothing to assert.
// A null role is a laboratory — gen.Deco.BLOCK_LAB, the same default gen.Deco.places is handed.
//
// AND `blocks` HOLDS TWO KINDS OF STRING, which the first cut of this check did not know and which
// is worth stating because the table does not say it anywhere else. 'lab', 'cabinet' and 'toilet'
// are room ROLES — what a _Room actually carries. 'lounge' is a ZONE, a corner of an office that
// gen.blocks.RoomBlock furnishes outright by kind; no room is ever a lounge, so a sofa is always
// standing in a 'cabinet' by this check's reckoning, and asserting on it reported 6,096 faults in
// 2000 seeds that were all correct furniture. An entry naming no room role at all is placed by a
// template and not rolled, so `blocks` is not a claim about rooms and there is nothing here to hold
  public static final ROLES = [ Deco.BLOCK_LAB, gen.facility.FacilityTemp.ROLE_CABINET,
    gen.facility.FacilityTemp.ROLE_TOILET, gen.facility.FacilityTemp.ROLE_STORAGE ];

  public function decoBlocks(ctx: GenCtx, rooms: Array<_Room>)
    {
      // role per cell, so this stays one pass over the spawns rather than rooms x spawns. corridors
      // and outdoors are not rooms and hold no role, and nothing deals a fitting onto them
      var role = new Map<Int, String>();
      for (r in rooms)
        for (x in r.x1...r.x2 + 1)
          for (y in r.y1...r.y2 + 1)
            role.set(y * ctx.width + x, r.role == null ? Deco.BLOCK_LAB : r.role);
      for (s in ctx.spawns)
        {
          if (s.type != 'decoration')
            continue;
          var p = Const.placeOf(s.row, s.col);
          var b = role.get(s.y * ctx.width + s.x);
          if (p == null ||
              b == null ||
              !named(p))
            continue;
          ok(p.blocks.indexOf(b) >= 0, 'a "' + p.id + '" stands at ' + s.x + ',' + s.y +
            ' in a "' + b + '", which is not one of its blocks (' + p.blocks.join(', ') + ')');
        }
    }

// does this entry name any room ROLE, i.e. is its `blocks` a claim about rooms at all?
  function named(p: _DecoPlace): Bool
    {
      for (b in p.blocks)
        if (ROLES.indexOf(b) >= 0)
          return true;
      return false;
    }

// no two objects on one cell, and every spawn inside the area. two on a cell is the failure mode
// every placement pass guards against with hasObjectAt, so one getting through means a pass forgot
  public function spawnsSane(ctx: GenCtx)
    {
      var at = new Map<Int, Bool>();
      for (s in ctx.spawns)
        {
          ok(s.x >= 0 && s.y >= 0 && s.x < ctx.width && s.y < ctx.height,
            'spawn "' + s.type + '" out of bounds: ' + s.x + ',' + s.y);
          var key = s.y * ctx.width + s.x;
          ok(!at.exists(key), 'two spawns on cell ' + s.x + ',' + s.y + ' (' + s.type + ')');
          at.set(key, true);
        }
    }

// every room can actually be walked into.
//
// THE ONE CHECK THAT CATCHES A ROOM WITH NO DOOR. game.FacilityAreaGenerator already traces "bug,
// no door spots in room" when makeDoors cannot find a wall midpoint to open, and "no
// corridor-adjacent walls in cluster" when fixDoors cannot connect a cluster — but a trace in a
// browser console during generation is not something anyone reads, and the result is a room that
// renders perfectly and simply cannot be entered. Clues, guards and mission anchors can all land
// in it.
//
// flood fills the WALKABLE tiles from the area's outdoor edge. Doors are walkable floor by this
// point (a door cell finalizes to TILE_FLOOR_LINO and the Door object is what blocks it), so this
// is reachability for a player who opens what is in the way, which is the right question
  public var lastSeen: Array<Array<Bool>>;

  public function reachable(ctx: GenCtx, rooms: Array<_Room>,
      ?from: Array<{ x: Int, y: Int }>): Array<_Room>
    {
      var walk = tiles.Default.TILE_WALKABLE;
      var seen = [for (x in 0...ctx.width) [for (y in 0...ctx.height) false]];
      lastSeen = seen;
      var stack = [];
      // `from` is where the player ARRIVES, and an area that is not entered over its own edge has
      // to say so: a corp floor is the 20th storey of a tower with unwalkable void all round it,
      // so a rim flood reaches nothing at all and every room reads as sealed. The compound passes
      // nothing and gets the rim, where the road and its pavement run the full width so whichever
      // edge they landed on is in there
      if (from != null)
        for (p in from)
          push(ctx, walk, seen, stack, p.x, p.y);
      else
        {
          for (x in 0...ctx.width)
            {
              push(ctx, walk, seen, stack, x, 0);
              push(ctx, walk, seen, stack, x, ctx.height - 1);
            }
          for (y in 0...ctx.height)
            {
              push(ctx, walk, seen, stack, 0, y);
              push(ctx, walk, seen, stack, ctx.width - 1, y);
            }
        }
      while (stack.length > 0)
        {
          var p = stack.pop();
          for (i in 0...Const.dir4x.length)
            push(ctx, walk, seen, stack, p.x + Const.dir4x[i], p.y + Const.dir4y[i]);
        }

      // a room counts as reached if ANY of its cells was: its floor is one connected rect, and the
      // furniture standing in it is unwalkable without cutting it in two
      var cut = [];
      for (r in rooms)
        {
          var hit = false;
          for (y in r.y1...r.y2 + 1)
            for (x in r.x1...r.x2 + 1)
              if (seen[x][y])
                hit = true;
          if (!hit)
            cut.push(r);
        }
      return cut;
    }

  static function push(ctx: GenCtx, walk: Array<Int>, seen: Array<Array<Bool>>,
      stack: Array<{ x: Int, y: Int }>, x: Int, y: Int)
    {
      if (x < 0 ||
          y < 0 ||
          x >= ctx.width ||
          y >= ctx.height ||
          seen[x][y])
        return;
      var t = ctx.cells[x][y];
      if (t < 0 ||
          t >= walk.length ||
          walk[t] == 0)
        return;
      seen[x][y] = true;
      stack.push({ x: x, y: y });
    }

// every room with benches keeps some of them bare.
//
// A CLUE SPOT IS A BENCH TILE WITH NO OBJECT ON IT (game.AreaGame.initSpawnPoints), and
// clearTableSpots exists solely to guarantee one. A facility with no legal spot does not crash or
// look wrong — it just silently stops handing out clues, which is the kind of bug that survives a
// hundred playtests
  public function clueSpots(ctx: GenCtx, rooms: Array<_Room>)
    {
      var free = 0;
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          {
            if (!Const.isTableTile(ctx.cells[x][y]))
              continue;
            if (!ctx.hasObjectAt(x, y))
              free++;
          }
      ok(free > 0, 'no bare bench cell in the whole area: nothing can spawn a clue');
    }

// the checkpoint, re-derived exactly the way game.AreaGame.gate() does it on every load.
//
// A REIMPLEMENTATION ON PURPOSE, and the one place in this file that is. gate() reads nothing the
// generator recorded — no block tree, no generatorInfo — only the SHAPE left in the cell grid: the
// bounding box of every open-lot cell lying within the pavement's depth of the carriageway. That
// makes it the invariant most easily broken by a layout change and the one least likely to be
// noticed, because a compound with no checkpoint still loads and still plays
  public function gate(ctx: GenCtx)
    {
      var x0 = ctx.width, x1 = -1, y0 = ctx.height, y1 = -1, dir = 0;
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          {
            if (!isMouth(ctx, x, y))
              continue;
            var d = roadSide(ctx, x, y);
            if (d == 0)
              continue;
            dir = d;
            if (x < x0)
              x0 = x;
            if (x > x1)
              x1 = x;
            if (y < y0)
              y0 = y;
            if (y > y1)
              y1 = y;
          }
      if (dir == 0)
        {
          fail('no gate: no open-lot cell lies within the pavement band, so the compound has no ' +
            'checkpoint at all');
          return;
        }
      // ONE mouth and not several. the box is taken over every qualifying cell in the area, so a
      // second hole anywhere along the frontage does not add a gate — it stretches this one across
      // the whole compound and gate() then tests two cells that are nowhere near each other
      ok(x1 - x0 + 1 == gen.blocks.RoadBlock.ENTRY_W,
        'the gate mouth is ' + (x1 - x0 + 1) + ' cells wide, not ' +
        gen.blocks.RoadBlock.ENTRY_W + ': something else broke the pavement band');
      ok(y1 - y0 + 1 == gen.blocks.FacilityBlocks.SIDEWALK_W,
        'the gate mouth is ' + (y1 - y0 + 1) + ' cells deep, not the pavement band');
      // the row of lot just past the mouth: the booth takes the bay before it and the barrier post
      // the bay after, and gate() draws nothing at all unless both are open lot
      var y = (dir < 0 ? y1 + 1 : y0 - 1);
      ok(isLot(ctx, x0 - 1, y) &&
         isLot(ctx, x1 + 1, y),
        'the gate mouth at ' + x0 + ',' + y0 + ' is not flanked by open lot on the row inside it, ' +
        'so no booth is drawn and no checkpoint exists');
      // and the boom lies across the mouth's own lot-side row, the whole width of it. it is the one
      // row of the hole the player cannot walk through, and render.facility.FacilityEntry stands the
      // arm and its cabinet on exactly this line — a row that came back walkable means the barrier
      // is decoration again
      var by = (dir < 0 ? y1 : y0);
      var n = 0;
      for (x in x0...x1 + 1)
        if (ctx.cells[x][by] == Const.TILE_ALLEY_UNWALKABLE)
          n++;
      ok(n == x1 - x0 + 1,
        'the barrier row at y ' + by + ' is ' + n + ' unwalkable cells of ' + (x1 - x0 + 1) +
        ': the boom across the gate mouth is walked through');
    }

// a cell of the gate MOUTH: the hole through the pavement band, either id. game.AreaGame.isMouth,
// verbatim — the row of the hole the boom lies across is Const.TILE_ALLEY_UNWALKABLE, and a box
// taken over the alley alone reads the mouth one row short and then fails its own depth test
  static function isMouth(ctx: GenCtx, x: Int, y: Int): Bool
    {
      var t = ctx.getCellType(x, y);
      return t == Const.TILE_ALLEY || t == Const.TILE_ALLEY_UNWALKABLE;
    }

// open asphalt, either id. game.AreaGame.isLot, verbatim — the mouth itself is Const.TILE_ALLEY and
// the rows inside it are Const.TILE_PARKING, so the flank test above spans both
  static function isLot(ctx: GenCtx, x: Int, y: Int): Bool
    {
      var t = ctx.getCellType(x, y);
      return t == Const.TILE_ALLEY || isParking(ctx, x, y);
    }

// is this cell the car park? all three of its marks — the plain asphalt and the two a parked car's
// footprint carries (Const.TILE_PARKING_CAR), which are the same lot with the walk taken off it
  static function isParking(ctx: GenCtx, x: Int, y: Int): Bool
    {
      var t = ctx.getCellType(x, y);
      return t == Const.TILE_PARKING ||
        t == Const.TILE_PARKING_CAR ||
        t == Const.TILE_PARKING_CAR_ORIGIN;
    }

// the car park is ONE solid rect, it reaches the pavement, and the gate opens into it.
//
// counted over all three of the plot's marks: gen.facility.FacilityBays stamps a parked car's
// footprint over cells that were TILE_PARKING a moment earlier, and a car does not punch a hole in
// the car park (see `isParking`).
//
// gen.facility.FacilityGen marks the parking plot with Const.TILE_PARKING and nothing else does, so
// this is cheap to state and the thing it protects is not: render.facility.FacilityPaint stripes its
// bays and FacilityCars parks its cars on this mark ALONE. A compound whose mark went missing loses
// both silently — an empty car park still loads and still plays — and a compound whose mark leaked
// onto a second region gets bays in the back yard, which is the bug it was added to fix.
//
// asserted over the finished GRID and not over the tree, like gate() beside it: the tree is not
// persisted and the renderer never sees it
  public function parkingSane(ctx: GenCtx)
    {
      var x0 = ctx.width, x1 = -1, y0 = ctx.height, y1 = -1, n = 0;
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          {
            if (!isParking(ctx, x, y))
              continue;
            n++;
            if (x < x0)
              x0 = x;
            if (x > x1)
              x1 = x;
            if (y < y0)
              y0 = y;
            if (y > y1)
              y1 = y;
          }
      if (n == 0)
        {
          fail('no car park: not one cell carries Const.TILE_PARKING, so the compound draws no ' +
            'bays and parks no cars');
          return;
        }
      // ONE REGION, stated as "the bounding box is solid". A second patch of the mark anywhere else
      // widens this box over the ground between them and the arithmetic catches it
      ok(n == (x1 - x0 + 1) * (y1 - y0 + 1),
        'the car park is ' + n + ' cells inside a ' + (x1 - x0 + 1) + 'x' + (y1 - y0 + 1) +
        ' box, so it is not one solid rect');
      // AND EVERY PARKED CAR IS A WHOLE BAY WITH PAVEMENT BESIDE IT. gen.facility.FacilityBays
      // stamps the footprint and render.facility.FacilityCars stands one model on each ORIGIN mark,
      // taking the bay's own axis off whichever neighbour is pavement — so an origin with no kerb is
      // a car that is silently not drawn, and a footprint that is not SPACING x DEPTH cells is a car
      // standing off its bay. Stated as a TOTAL rather than per footprint, which catches two bays
      // overlapping as well: that would leave fewer marked cells than the origins account for
      var cars = 0, marks = 0, kerbless = 0;
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          {
            var t = ctx.cells[x][y];
            if (t != Const.TILE_PARKING_CAR &&
                t != Const.TILE_PARKING_CAR_ORIGIN)
              continue;
            marks++;
            if (t != Const.TILE_PARKING_CAR_ORIGIN)
              continue;
            cars++;
            var kerb = false;
            for (i in 0...Const.dir4x.length)
              if (ctx.getCellType(x + Const.dir4x[i], y + Const.dir4y[i]) == Const.TILE_WALKWAY)
                kerb = true;
            if (!kerb)
              kerbless++;
          }
      ok(cars <= gen.facility.FacilityBays.CARS,
        'the lot holds ' + cars + ' parked cars against a cap of ' +
        gen.facility.FacilityBays.CARS);
      ok(marks == cars * gen.facility.FacilityBays.SPACING * gen.facility.FacilityBays.DEPTH,
        'the ' + cars + ' parked cars cover ' + marks + ' cells and a whole bay each is ' +
        (cars * gen.facility.FacilityBays.SPACING * gen.facility.FacilityBays.DEPTH));
      ok(kerbless == 0,
        kerbless + ' of ' + cars + ' parked cars have no pavement beside them, so nothing tells ' +
        'the renderer which way their bay runs');
      // and it is the plot the gate opens onto: the mouth's own row, one step further into the
      // compound, has to be inside that box or the booth stands on a yard
      var mx0 = ctx.width, mx1 = -1, my0 = ctx.height, my1 = -1, dir = 0;
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          {
            if (!isMouth(ctx, x, y))
              continue;
            var d = roadSide(ctx, x, y);
            if (d == 0)
              continue;
            dir = d;
            if (x < mx0)
              mx0 = x;
            if (x > mx1)
              mx1 = x;
            if (y < my0)
              my0 = y;
            if (y > my1)
              my1 = y;
          }
      if (dir == 0)
        return;
      var my = (dir < 0 ? my1 + 1 : my0 - 1);
      ok(mx0 >= x0 && mx1 <= x1 && my >= y0 && my <= y1,
        'the gate mouth at ' + mx0 + ',' + my + ' does not open into the car park at ' + x0 + ',' +
        y0 + '..' + x1 + ',' + y1);
    }

// which way the carriageway lies from this cell, or 0 if it is further off than the pavement is
// deep. game.AreaGame.roadSide, verbatim
  static function roadSide(ctx: GenCtx, x: Int, y: Int): Int
    {
      for (i in 1...gen.blocks.FacilityBlocks.SIDEWALK_W + 1)
        {
          if (ctx.getCellType(x, y - i) == Const.TILE_ROAD)
            return -1;
          if (ctx.getCellType(x, y + i) == Const.TILE_ROAD)
            return 1;
        }
      return 0;
    }

// the park's path, re-derived the way render.facility.FacilityModel.isParkPath does it: a pavement
// cell with lawn on both sides of the run it stands in. The park block writes it as plain WALKWAY
// and nothing records that it is a path, so a park laid without one loses its kerbs and its lamps
// with no error anywhere
  public function parkPath(ctx: GenCtx)
    {
      var n = 0;
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          if (ctx.cells[x][y] == Const.TILE_WALKWAY &&
              ((grassAcross(ctx, x, y, -1, 0) && grassAcross(ctx, x, y, 1, 0)) ||
               (grassAcross(ctx, x, y, 0, -1) && grassAcross(ctx, x, y, 0, 1))))
            n++;
      ok(n > 0, 'no cell in the area reads as a park path: the park has no walkway with lawn ' +
        'either side of it');
    }

// step off a cell one way over the walkway run it stands in: is the first cell past that run grass?
// FacilityModel.grassAcross, with its own PATH_MAX cap
  static function grassAcross(ctx: GenCtx, x: Int, y: Int, dx: Int, dy: Int): Bool
    {
      var cx = x + dx;
      var cy = y + dy;
      for (_ in 0...PATH_MAX)
        {
          var t = ctx.getCellType(cx, cy);
          if (t != Const.TILE_WALKWAY)
            // Surf.GRASS, spelled the way render.facility.FacilityModel.surfOf spells it
            return t == Const.TILE_GRASS ||
              t == Const.TILE_GRASS_UNWALKABLE ||
              (t >= Const.TILE_TREE1 && t <= Const.TILE_BUSH);
          cx += dx;
          cy += dy;
        }
      return false;
    }

  static function rect(b: _GenNode): String
    return b.x1 + ',' + b.y1 + '..' + b.x2 + ',' + b.y2;
}
