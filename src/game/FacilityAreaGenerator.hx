// facility area generation

package game;

import const.WorldConst;
import Const;
import objects.*;
import game.AreaGame;
import game.AreaGenerator;
import game.AreaGenerator.*;
// imported by name rather than written as `gen.GenCtx`: this class has an instance field called
// `gen` (the shared AreaGenerator), which shadows the package of the same name
import gen.GenCtx;
import gen.GenSpawner;
import gen.Rng;

import haxe.Timer;

class FacilityAreaGenerator
{
  var game: Game;
  var gen: AreaGenerator;

  public function new(g: Game, gn: AreaGenerator)
    {
      game = g;
      gen = gn;
      finalTiles = [
        TEMP_ROAD => Const.TILE_ROAD,
        TEMP_WALKWAY => Const.TILE_WALKWAY,
        TEMP_ALLEY => Const.TILE_ALLEY,
        TEMP_GRASS => Const.TILE_GRASS,
        TEMP_GRASS_BUSH => Const.TILE_BUSH,
        TEMP_GRASS_BENCH => Const.TILE_GRASS_UNWALKABLE,
        TEMP_CONCRETE => Const.TILE_FLOOR_CONCRETE,
        TEMP_BUILDING_WALL => Const.TILE_BUILDING,
        TEMP_BUILDING_ROOM => Const.TILE_FLOOR_TILE,
        TEMP_BUILDING_CORRIDOR => Const.TILE_FLOOR_LINO,
        TEMP_BUILDING_FRONT_DOOR => Const.TILE_FLOOR_LINO,
        TEMP_BUILDING_SIDE_DOOR => Const.TILE_FLOOR_LINO,
        TEMP_BUILDING_WINDOW => Const.TILE_WINDOW1,
        TEMP_BUILDING_WINDOWH1 => Const.TILE_WINDOWH1,
        TEMP_BUILDING_WINDOWH2 => Const.TILE_WINDOWH2,
        TEMP_BUILDING_WINDOWH3 => Const.TILE_WINDOWH3,
        TEMP_BUILDING_WINDOWV1 => Const.TILE_WINDOWV1,
        TEMP_BUILDING_WINDOWV2 => Const.TILE_WINDOWV2,
        TEMP_BUILDING_WINDOWV3 => Const.TILE_WINDOWV3,
        TEMP_BUILDING_INNER_WALL => Const.TILE_BUILDING,
        TEMP_BUILDING_INNER_DOOR => Const.TILE_FLOOR_LINO,
        TEMP_HANGAR_DOOR => Const.TILE_HANGAR_DOOR,
        TEMP_HANGAR_SIDE_DOOR => Const.TILE_FLOOR_TILE_CANNOTSEE,
        TEMP_BUILDING_VENT => Const.TILE_BUILDING,
        TEMP_BUILDING_WINDOW_HIGH => Const.TILE_WINDOW_HIGH,
      ];
    }

// entry-point for facility generation.
//
// the LIVE adapter and nothing more: wrap the area's grid in a gen.GenCtx, run the generator, then
// hand the results back to the area — the rooms and doors it recorded, and the objects it asked
// for. Everything between those two lines runs just as happily with no Game at all, which is what
// tools/genrun.mjs does. `info` is unused and has been since this file was written; it stays in the
// signature because game.AreaGenerator.generate dispatches every area type through the same one
  public function generate(area: AreaGame, info: AreaInfo)
    {
      var ctx = new GenCtx(area.width, area.height, Rng.seed(), area.getCells());
      var state = build(ctx);
      area.generatorInfo = {
        rooms: state.allRooms,
        doors: state.allDoors,
      };
      GenSpawner.drain(game, area, ctx);
    }

// generate a whole compound into a context. the real entry point, and the one the headless oracle
// calls — it must never reach for `game`
  public function build(ctx: GenCtx): _FacilityState
    {
      var area = ctx;
      var state: _FacilityState = {
        area: ctx,
        mainRoadNorth: (Std.random(100) < 50 ? true : false),
        rooms: null,
        doors: null,
        allRooms: [],
        allDoors: [],
        nextRoomID: TEMP_BUILDING_ROOM_ID_START,
      }
      // fill with blank
      var cells = area.getCells();
      drawBlock(cells, 0, 0, area.width, area.height, TEMP_ALLEY);

      // main road
      var rw = 4;
      var ry = (state.mainRoadNorth ? 0 : area.height - rw);
      drawBlock(cells, 0, ry, area.width, rw, TEMP_ROAD);

      // sidewalk near main road
      var sidewalkw = 2;
      var sidewalky = (state.mainRoadNorth ? ry + rw : ry - sidewalkw);
      drawBlock(cells, 0, sidewalky, area.width, sidewalkw, TEMP_WALKWAY);

      // main building
      var t1 = Timer.stamp();
      var mainw = Std.int(area.width * 0.5),
        mainh = Std.int(area.height * 0.5);
      var mainx = Std.int(mainw / 2),
        mainy = (state.mainRoadNorth ? rw + 2 : area.height - mainh - 2 - rw);
      generateBuilding(state, mainx, mainy, mainw, mainh);

      // hole in sidewalk for entry to parking lot
      var hx = mainx + mainw + 10, hy = sidewalky;
      drawBlock(cells, hx, hy, 4, 2, TEMP_ALLEY);
      // sewer hatches
      var cnt = 0;
      var sewersDist = 10 + Std.random(10);
      for (x in 0...hx)
        {
          cnt++;
          if (cnt < sewersDist)
            continue;
          area.add('sewerHatch', x, sidewalky + (state.mainRoadNorth ? 0 : 1));
          cnt = 0;
        }

      // grass
      var gx = 2, gy = mainy, gw = mainx - 4, gh = mainh;
      drawBlock(cells, gx, gy, gw, gh, TEMP_GRASS);
      drawBlock(cells, 0, gy, 2, gh, TEMP_WALKWAY);
      generatePark(state, gx, gy, gw, gh);

      // side building
      var sidex = 2,
        sidey = (state.mainRoadNorth ? mainy + mainh + 2 : 2),
        sidew = Std.int(area.width * 0.4),
        sideh = (state.mainRoadNorth ? area.height - sidey - 2 : mainy - 4);
      generateBuilding(state, sidex, sidey, sidew, sideh);

      // hangar. it is pushed off the main building's apron by HANGAR_GAP and SHORTENED by the same,
      // so the far end stays where it was — the yard it faces is the compound's own, and moving that
      // end would take the gap out of the lot on the other side instead
      var hangarx = sidex + sidew + 16,
        hangary = (state.mainRoadNorth ? mainy + mainh + 2 + HANGAR_GAP : 4),
        hangarw = Std.int(area.width * 0.2),
        hangarh = (state.mainRoadNorth ? area.height - sidey - 4 - HANGAR_GAP
          : mainy - 6 - HANGAR_GAP);
//      trace(hangarx + ',' + hangary + ' : ' + hangarw + ',' + hangarh);
      generateHangar(state, hangarx, hangary, hangarw, hangarh);

      // trace area
//      AreaGenerator.printArea(game, state.area, mapTempTiles);

      // convert temp tiles to ingame ones
      finalizeTiles(state);
      // and last, once every wall, door and piece of furniture is on the grid in its final form,
      // make sure every room can actually be walked into
      connectRooms(state);
      trace(Std.int((Timer.stamp() - t1) * 1000) + 'ms');
      return state;
    }

// cut a door into any room that cannot be reached on foot.
//
// WHY THIS IS A SEPARATE PASS AT THE VERY END, rather than more logic inside fixDoors: fixDoors
// reasons about the ROOM GRAPH — which rooms have doors to which — and reachability is a property of
// the TILE GRID. The two disagree, and the graph is the optimistic one. A room can hold a door that
// fixDoors counts as a connection while the cells behind it are furniture, a partition, or another
// room that is itself sealed; and furniture is not even placed until after fixDoors has run, so at
// the point the graph is checked half the obstacles do not exist yet.
//
// so this asks the only question that matters, on the finished grid, the same way
// game.AreaGame.isWalkable will: flood the walkable cells from outside, and cut a door into whatever
// the flood did not reach. Measured before it existed: 8% of compounds carried at least one room
// that rendered perfectly and could not be entered, with clues, guards and mission anchors all able
// to spawn inside it.
  function connectRooms(state: _FacilityState)
    {
      // bounded rather than `while (true)`: each round opens at least one room or stops, so the
      // room count is the ceiling, and a cap means a bug here cannot hang generation
      for (round in 0...state.allRooms.length + 1)
        {
          var seen = floodWalkable(state);
          var stuck = [for (r in state.allRooms) if (!roomReached(r, seen)) r];
          if (stuck.length == 0)
            return;
          var opened = false;
          for (r in stuck)
            {
              // a wall that does not duplicate an existing door first. The room being sealed means
              // any door it already has is unusable, so a second one between the same pair would be
              // correct — but scenario.AlienMissionCommon locks a room by taking the FIRST door it
              // finds for it and stopping, so a duplicate pair leaves the other way in unlocked
              if (cutDoorToReached(state, r, seen, false) ||
                  cutDoorToReached(state, r, seen, true))
                opened = true;
            }
          // nothing could be opened this round, so nothing will be next round either
          if (!opened)
            {
              trace('connectRooms(): ' + stuck.length + ' room(s) still sealed, first is ' +
                stuck[0].x1 + ',' + stuck[0].y1 + '..' + stuck[0].x2 + ',' + stuck[0].y2);
              return;
            }
        }
    }

// every walkable cell reachable from outside the area, flooded from the rim. the road and its
// pavement span the full width, so whichever edge they landed on seeds the fill
  function floodWalkable(state: _FacilityState): Array<Array<Bool>>
    {
      var ctx = state.area;
      var cells = ctx.getCells();
      var walk = tiles.Default.TILE_WALKABLE;
      var seen = [for (x in 0...ctx.width) [for (y in 0...ctx.height) false]];
      var stack = [];
      inline function open(x: Int, y: Int)
        {
          if (x < 0 ||
              y < 0 ||
              x >= ctx.width ||
              y >= ctx.height ||
              seen[x][y])
            return;
          var t = cells[x][y];
          if (t < 0 ||
              t >= walk.length ||
              walk[t] == 0)
            return;
          seen[x][y] = true;
          stack.push({ x: x, y: y });
        }
      for (x in 0...ctx.width)
        {
          open(x, 0);
          open(x, ctx.height - 1);
        }
      for (y in 0...ctx.height)
        {
          open(0, y);
          open(ctx.width - 1, y);
        }
      while (stack.length > 0)
        {
          var p = stack.pop();
          for (i in 0...Const.dir4x.length)
            open(p.x + Const.dir4x[i], p.y + Const.dir4y[i]);
        }
      return seen;
    }

// did the flood reach any cell of this room? any one will do — a room's floor is a single rect, and
// the furniture standing in it cannot cut that rect in two without also blocking the door
  function roomReached(room: _Room, seen: Array<Array<Bool>>): Bool
    {
      for (y in room.y1...room.y2 + 1)
        for (x in room.x1...room.x2 + 1)
          if (seen[x][y])
            return true;
      return false;
    }

// open one wall cell of this room onto somewhere the flood already got to.
//
// candidates come centre-of-wall first, and an INDOOR neighbour is taken over an outdoor one in the
// same position — a door onto the corridor is what a room wants, and a hole cut straight through the
// compound's outside wall is a last resort rather than a choice
  function cutDoorToReached(state: _FacilityState, room: _Room,
      seen: Array<Array<Bool>>, allowDuplicate: Bool): Bool
    {
      var ctx = state.area;
      var cells = ctx.getCells();
      var walk = tiles.Default.TILE_WALKABLE;
      var best = null;
      var bestIndoor = false;
      for (s in getRoomWallSpots(room))
        {
          // the cell being opened has to be masonry: everything else is either already a way in or
          // something that must not be cut through
          if (cells[s.x][s.y] != Const.TILE_BUILDING)
            continue;
          var d = deltaMap[s.dir];
          var fx = s.x + d.x;
          var fy = s.y + d.y;
          if (fx < 0 ||
              fy < 0 ||
              fx >= ctx.width ||
              fy >= ctx.height)
            continue;
          // the far side must be somewhere you can already stand...
          var ft = cells[fx][fy];
          if (ft < 0 ||
              ft >= walk.length ||
              walk[ft] == 0 ||
              !seen[fx][fy])
            continue;
          // ...and the room side must be floor, or the new door opens into a cabinet
          var nt = cells[s.x - d.x][s.y - d.y];
          if (nt < 0 ||
              nt >= walk.length ||
              walk[nt] == 0)
            continue;
          // would this repeat a door the room already has? see the caller for why that matters
          if (!allowDuplicate &&
              hasDoorBetween(state, room.id, roomAtCell(state, fx, fy)))
            continue;
          // every indoor floor id sits at or above the chem-lab band; the road, pavement, alley and
          // grass the compound is built on are all well below it
          var indoor = (ft >= Const.OFFSET_CHEM_LAB);
          if (best != null &&
              (bestIndoor || !indoor))
            continue;
          best = s;
          bestIndoor = indoor;
          // nothing beats an indoor neighbour at the middle of the first wall that offers one
          if (indoor)
            break;
        }
      if (best == null)
        return false;

      cells[best.x][best.y] = Const.TILE_FLOOR_LINO;
      var priv = opensOnPrivateRoom(cells, best.x, best.y);
      ctx.addDoor(best.x, best.y,
        (priv ? Const.FRAME_DOOR_PRIVATE : Const.FRAME_DOOR_CABINET),
        (priv ? Const.FRAME_DOOR_PRIVATE_OPEN : Const.FRAME_DOOR_CABINET_OPEN));
      var d = deltaMap[best.dir];
      state.allDoors.push({
        x: best.x,
        y: best.y,
        dir: best.dir,
        roomID1: room.id,
        roomID2: roomAtCell(state, best.x + d.x, best.y + d.y),
        skip: false,
      });
      return true;
    }

// is there already a door recorded between these two rooms?
  function hasDoorBetween(state: _FacilityState, a: Int, b: Int): Bool
    {
      for (d in state.allDoors)
        if ((d.roomID1 == a && d.roomID2 == b) ||
            (d.roomID1 == b && d.roomID2 == a))
          return true;
      return false;
    }

// which recorded room holds this cell, or 0 for a corridor or the outdoors. by rect and not by the
// grid marks: those are gone by the time this runs, finalizeTiles having written real tiles over them
  function roomAtCell(state: _FacilityState, x: Int, y: Int): Int
    {
      for (r in state.allRooms)
        if (x >= r.x1 &&
            x <= r.x2 &&
            y >= r.y1 &&
            y <= r.y2)
          return r.id;
      return 0;
    }

// lay the park out inside its own rect: a path through it, benches down that path, and greenery in
// CLUMPS rather than the flat per-cell roll this used to be (10% tree / 30% bush everywhere, which
// gave an even scrub with no shape and left 40% of the lawn unwalkable).
//
// the path is written as plain WALKWAY and that is the whole trick: it costs nothing here and the
// render layer already knows what to do with it. render.facility.FacilityGround kerbs any pavement
// edge that steps down, and render.facility.FacilityLamps' lit-line table already has a row for
// grass bordering a walkway, so the path arrives edged and lit with no code on either side
  function generatePark(state: _FacilityState, gx: Int, gy: Int, gw: Int, gh: Int)
    {
      var cells = state.area.getCells();
      // down the park's LONG axis, and two cells wide so it reads as a path and not as a seam
      var vertical = (gh >= gw);
      var px = (vertical ? gx + Std.int((gw - PARK_PATH_W) / 2) : gx);
      var py = (vertical ? gy : gy + Std.int((gh - PARK_PATH_W) / 2));
      drawBlock(cells, px, py, (vertical ? PARK_PATH_W : gw), (vertical ? gh : PARK_PATH_W),
        TEMP_WALKWAY);

      // benches, alternating sides on the way down, each on the grass cell against the path's kerb.
      // they finalize to Const.TILE_GRASS_UNWALKABLE, which the renderer MUST draw something for —
      // a green cell with no prop on it is a wall the player cannot see
      var len = (vertical ? gh : gw);
      var i = PARK_BENCH_SPACING;
      while (i < len - 1)
        {
          var side = (Std.int(i / PARK_BENCH_SPACING) % 2 == 0 ? -1 : PARK_PATH_W);
          var bx = (vertical ? px + side : gx + i);
          var by = (vertical ? gy + i : py + side);
          if (cells[bx][by] == TEMP_GRASS)
            cells[bx][by] = TEMP_GRASS_BENCH;
          i += PARK_BENCH_SPACING;
        }

      // an even line of shrubs round the OUTSIDE of the lawn, which is what the railing reads
      // against: render.facility.FacilityGround.fence stands one segment per rim edge, and a bare
      // strip of turf behind a railing looks like a fence in a field. the gate is on (x + y), which
      // on a rim run has one coordinate fixed and so steps evenly along it — the diagonal it would
      // step on elsewhere never arises here. only lawn is overwritten, so the two cells where the
      // path crosses the rim stay open
      for (y in gy...gy + gh)
        for (x in gx...gx + gw)
          {
            if (x != gx &&
                y != gy &&
                x != gx + gw - 1 &&
                y != gy + gh - 1)
              continue;
            if ((x + y) % PARK_EDGE_BUSH_SPACING != 0 ||
                cells[x][y] != TEMP_GRASS)
              continue;
            cells[x][y] = TEMP_GRASS_BUSH;
          }

      // and the planting: a centre TREE every PARK_CLUMP_STEP cells on a lattice, jittered a cell
      // off its node, with a clump grown around each one.
      //
      // the lattice is the whole point and it replaces four centres drawn UNIFORM over the rect.
      // uniform is what left whole bands of the lawn bare, and not by bad luck: measured over 2000
      // runs of the old code on a real 12x25 park, 29% of park ROWS came back with nothing on them
      // at all and the average longest unbroken bare band was 5.8 rows out of 25, with a tail out
      // to 19. four samples cannot cover a rect, however far each one reaches
      var y = gy + Std.int(PARK_CLUMP_STEP / 2);
      while (y < gy + gh)
        {
          var x = gx + Std.int(PARK_CLUMP_STEP / 2);
          while (x < gx + gw)
            {
              plantClump(cells, x + Std.random(3) - 1, y + Std.random(3) - 1, gx, gy, gw, gh);
              x += PARK_CLUMP_STEP;
            }
          y += PARK_CLUMP_STEP;
        }
    }

// grow one clump of planting around a centre: a tree ON the centre, trees or bushes through its
// core, bushes thinning out to PARK_CLUMP_R, open lawn past that. distance is Manhattan, so a clump
// is a diamond and no two of them tile into a hedge.
//
// only TEMP_GRASS is ever overwritten, which is what keeps the path, the benches and any clump
// already grown beside this one intact — the passes are ordered and this one runs last
  function plantClump(cells: Array<Array<Int>>, cx: Int, cy: Int,
      gx: Int, gy: Int, gw: Int, gh: Int)
    {
      for (y in cy - PARK_CLUMP_R...cy + PARK_CLUMP_R + 1)
        for (x in cx - PARK_CLUMP_R...cx + PARK_CLUMP_R + 1)
          {
            if (x < gx ||
                y < gy ||
                x >= gx + gw ||
                y >= gy + gh ||
                cells[x][y] != TEMP_GRASS)
              continue;
            var d = Std.int(Math.abs(x - cx) + Math.abs(y - cy));
            var rnd = Std.random(100);
            // the tree zone is d < R and not the d * 2 <= R it started as, which is what doubled the
            // trees without touching the bushes. a Manhattan diamond of radius 3 holds 1 / 4 / 8 / 12
            // cells at d = 0..3, so the old core was 5 cells and the new one is 13 — trees go from
            // 1 + 4 * 0.55 = 3.2 per clump to 1 + 12 * 0.55 = 7.6, while the bush count is unmoved at
            // 10.8 either way (12 * 0.45 in the core plus 12 * 0.45 in the skirt, against 4 * 0.45
            // plus 20 * 0.45 before). the skirt is now the single outermost ring
            if (d == 0)
              cells[x][y] = TEMP_GRASS_TREE;
            else if (d < PARK_CLUMP_R)
              cells[x][y] = (rnd < 55 ? TEMP_GRASS_TREE : TEMP_GRASS_BUSH);
            else if (d == PARK_CLUMP_R && rnd < 45)
              cells[x][y] = TEMP_GRASS_BUSH;
          }
    }

// generate a hangar of a given size at given coordinates
  function generateHangar(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      // draw outer walls
      for (y in by - 2...by + bh + 2)
        for (x in bx - 2...bx + bw + 2)
          {
            if (x < 0 || y < 0 || x >= area.width || y >= area.height)
              continue;
            if (x > bx && x < bx + bw - 1 && y > by && y < by + bh - 1)
              {
                cells[x][y] = TEMP_CONCRETE;
                continue;
              }
            if (x < bx || x >= bx + bw || y < by || y >= by + bh)
              {
//                cells[x][y] = TEMP_WALKWAY;
                continue;
              }
            if (x == bx || x == bx + bw - 1 || y == by || y == by + bh - 1)
              cells[x][y] = TEMP_BUILDING_WALL;
          }

      // draw fake doors
      var len = 0;
      var y = (state.mainRoadNorth ? (by + bh - 1) : by);
      for (x in bx + 1...bx + bw - 1)
        {
          if (len < 0)
            {
              len++;
              continue;
            }
          cells[x][y] = TEMP_HANGAR_DOOR;
          len++;
          if (len == 3)
            len = -1;
        }

      // draw side door
      cells[bx][by + Std.int(bh / 2)] = TEMP_HANGAR_SIDE_DOOR;

      // the hangar is ONE open space, so it is one room. it has no inner walls and therefore never
      // went through makeDoors, which is why it used to contribute nothing to generatorInfo at all —
      // and a room-less structure gets no ceiling light and no room reveal
      state.allRooms.push({
        id: state.nextRoomID,
        x1: bx + 1,
        y1: by + 1,
        x2: bx + bw - 2,
        y2: by + bh - 2,
        w: bw - 2,
        h: bh - 2,
      });
      state.nextRoomID++;
    }

// generate a single building of a given size at given coordinates
  function generateBuilding(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
//      trace('b: ' + bx + ',' + by + ' sz:' + bw + ',' + bh);
      // draw outer walls and walkways
      var area = state.area;
      var cells = area.getCells();
      for (y in by - 2...by + bh + 2)
        for (x in bx - 2...bx + bw + 2)
          {
            if (x < 0 || y < 0 || x >= area.width || y >= area.height)
              continue;
            if (x > bx && x < bx + bw - 1 && y > by && y < by + bh - 1)
              {
                cells[x][y] = TEMP_BUILDING_ROOM;
                continue;
              }
            if (x < bx || x >= bx + bw || y < by || y >= by + bh)
              {
                cells[x][y] = TEMP_WALKWAY;
                continue;
              }
            if (x == bx || x == bx + bw - 1 || y == by || y == by + bh - 1)
              cells[x][y] = TEMP_BUILDING_WALL;
          }

      // pick a wall for a front door
      var outerWalls = [
        { x1: bx, y1: by, x2: bx + bw - 1, y2: by, dir: DIR_DOWN }, // top
        { x1: bx, y1: by, x2: bx, y2: by + bh - 1, dir: DIR_RIGHT }, // left
        { x1: bx, y1: by + bh - 1, x2: bx + bw - 1,
          y2: by + bh - 1, dir: DIR_UP }, // bottom
        { x1: bx + bw - 1, y1: by, x2: bx + bw - 1, y2: by + bh - 1, dir: DIR_LEFT }, // right
      ];
      var frontWall = outerWalls[Std.random(outerWalls.length)];

      // pick a main corridor starting spot
      var frontDoor = null;
      if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
        frontDoor = {
          x: Std.int((frontWall.x2 - frontWall.x1) / 2) + frontWall.x1,
          y: frontWall.y1,
        };
      else frontDoor = {
        x: frontWall.x1,
        y: Std.int((frontWall.y2 - frontWall.y1) / 2) + frontWall.y1,
      };

      // main doors and wall between them
      var corridorWidth = 3;
      drawChunk(cells, frontDoor.x, frontDoor.y, corridorWidth,
        frontWall.dir, TEMP_BUILDING_FRONT_DOOR);
      if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
        cells[frontDoor.x + 1][frontDoor.y] = TEMP_BUILDING_WALL;
      else cells[frontDoor.x][frontDoor.y + 1] = TEMP_BUILDING_WALL;

      // draw main corridor
      var len = 0, x = frontDoor.x, y = frontDoor.y;
      var delta = deltaMap[frontWall.dir];
      var sideCorridorCount1 = 0, sideCorridorCount2 = 0;
      var sideCorridorAmount1 = 0, sideCorridorAmount2 = 0;
      while (true)
        {
          len++;
          if (len > 100)
            {
              trace('long corridor?');
              break;
            }
          x += delta.x;
          y += delta.y;
          if (cells[x][y] < TEMP_BUILDING_WALL)
            {
              x -= delta.x;
              y -= delta.y;
              // fix the hole :)
              drawChunk(cells, x, y, corridorWidth,
                frontWall.dir, TEMP_BUILDING_WALL);
              break;
            }
          drawChunk(cells, x, y, corridorWidth,
            frontWall.dir, TEMP_BUILDING_CORRIDOR);

          // check for side corridors
          sideCorridorCount1++;
          if (sideCorridorCount1 > ROOM_SIZE && Std.random(100) > 70)
            {
              var dir = 0; 
              if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
                dir = DIR_LEFT;
              else dir = DIR_UP;
              var toFinish = distanceToFinish(cells, x, y, frontWall.dir);
              if (toFinish > ROOM_SIZE)
                drawSideCorridor(cells, x, y, dir);
              sideCorridorCount1 = 0;
            }
          sideCorridorCount2++;
          if (sideCorridorCount2 > ROOM_SIZE && Std.random(100) > 70)
            {
              var dir = 0; 
              if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
                dir = DIR_RIGHT;
              else dir = DIR_DOWN;
              var toFinish = distanceToFinish(cells, x, y, frontWall.dir);
              if (toFinish > ROOM_SIZE)
                drawSideCorridor(cells, x, y, dir);
              sideCorridorCount2 = 0;
            }
        }

      // side door/window
      if (Std.random(100) < 50)
        {
          if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
            {
              cells[x][y] = TEMP_BUILDING_WINDOWH1;
              cells[x + 1][y] = TEMP_BUILDING_WINDOWH2;
              cells[x + 2][y] = TEMP_BUILDING_WINDOWH3;
            }
          else
            {
              cells[x][y] = TEMP_BUILDING_WINDOWV1;
              cells[x][y + 1] = TEMP_BUILDING_WINDOWV2;
              cells[x][y + 2] = TEMP_BUILDING_WINDOWV3;
            }
//        drawChunk(cells, x, y, corridorWidth,
//          frontWall.dir, TEMP_BUILDING_WINDOW);
        }
      else
        {
          if (frontWall.dir == DIR_UP || frontWall.dir == DIR_DOWN)
            cells[x + 1][y] = TEMP_BUILDING_SIDE_DOOR;
          else cells[x][y + 1] = TEMP_BUILDING_SIDE_DOOR;

        }

      // draw inner walls
      for (y in by + 1...by + bh + 1)
        for (x in bx + 1...bx + bw + 1)
          if (cells[x][y] == TEMP_BUILDING_ROOM &&
              nextTo(cells, x, y, TEMP_BUILDING_CORRIDOR))
            cells[x][y] = TEMP_BUILDING_INNER_WALL;

      // sub-divide larger rooms
      for (i in 0...2)
        {
          subdivideLargeRooms(state, bx, by, bw, bh);
          replaceTiles(cells, bx, by, bw, bh,
            TEMP_BUILDING_ROOM_MARKED, TEMP_BUILDING_ROOM);
        }

      // make doors
      makeDoors(state, bx, by, bw, bh);

      // various door fixes
      fixDoors(state, bx, by, bw, bh);

      // hand each room its template. BEFORE makeWindows, which is where the bench runs are laid: a
      // washroom must never get one, and a researcher's office wants desks and not laboratory glassware
      assignRoomThemes(state);

      // make windows
      makeWindows(state, bx, by, bw, bh);

      // work on individual rooms
      generateRoomContents(state);

      // fold this building into the area-wide lists. done LAST, because every pass above reads
      // state.rooms/doors and must only ever see this building's own
      for (r in state.rooms)
        state.allRooms.push(r);
      for (d in state.doors)
        state.allDoors.push(d);

//      replaceTiles(cells, bx, by, bw, bh,
//        TEMP_BUILDING_ROOM_MARKED, TEMP_BUILDING_ROOM);
    }
  
// sub-divide larger rooms
// if isFinal is true, mark with room ids
// if it is false, mark with TEMP_BUILDING_ROOM_MARKED
  function subdivideLargeRooms(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      var rooms = 0;
      for (y in by + 1...by + bh)
        for (x in bx + 1...bx + bw)
          {
            // find next room start spot
            if (cells[x][y] != TEMP_BUILDING_ROOM)
              continue;

            // get room dimensions and wall division direction
            var room = getRoom(cells, x, y);
//            trace(room);
            var dir = 0;
            if (room.w > ROOM_SIZE * 1.5)
              dir = DIR_DOWN;
            if (room.h > ROOM_SIZE * 1.5)
              dir = DIR_RIGHT;
            if (dir == 0)
              {
                markRoom(cells, room, TEMP_BUILDING_ROOM_MARKED);
                continue;
              }
/*
            if (Std.random(100) < 10)
              {
                markRoom(cells, room);
                continue;
              }*/

            // find starting wall division spot
            var sx = 0, sy = 0;
            if (dir == DIR_DOWN)
              {
                var neww = Std.int(room.w / 2);
                if (Std.random(100) < 30)
                  neww = Std.int(room.w / 3);
                neww += Std.random(4) - 2;
                if (neww < 4)
                  neww = 4;
                sx = room.x1 + neww;
                sy = room.y1;
              }
            else if (dir == DIR_RIGHT)
              {
                var newh = Std.int(room.h / 2);
                if (Std.random(100) < 30)
                  newh = Std.int(room.h / 3);
                newh += Std.random(4) - 2;
                if (newh < 4)
                  newh = 4;
                sx = room.x1;
                sy = room.y1 + newh;
              }
//            trace(sx + ',' + sy);
            var len = drawLine(cells, sx, sy, dir, TEMP_BUILDING_INNER_WALL);
//            trace('len:' + len);
            var newRoom = getRoom(cells, x, y);
//            trace(newRoom);
            markRoom(cells, newRoom, TEMP_BUILDING_ROOM_MARKED);
            rooms++;
//            if (rooms >= 2)
//            return;
          }
    }
  
// make inner wall doors
  function makeDoors(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      var roomID = state.nextRoomID - 1;
      var doors = [];
      var rooms = [];
      for (y in (by + 1)...(by + bh))
        for (x in (bx + 1)...(bx + bw))
          {
            // find next room start spot
            if (cells[x][y] != TEMP_BUILDING_ROOM)
              continue;

            // get room dimensions and door direction
            var room = getRoom(cells, x, y);
            roomID++;
            room.id = roomID;
            rooms.push(room);
/*
            if (roomID < 104)
              trace(room);*/
//            trace(room);
/*
            if (Std.random(100) < 30)
              {
                markRoom(cells, room);
                continue;
              }*/

            // the four wall midpoints first, so a door lands in the middle of its wall wherever one
            // legally can and the compound looks exactly as it always has
            var spots = doorSpots(cells, getRoomDoorSpots(room));
            var spot = null;
            if (spots.length > 0)
              spot = spots[Std.random(spots.length)];
            else
              {
                // and every other cell of the wall ring when none of the four works, most central
                // first. WITHOUT THIS the room simply never gets a door — it used to trace "bug, no
                // door spots in room" and carry on, leaving a room nothing can walk into
                spots = doorSpots(cells, getRoomWallSpots(room));
                if (spots.length == 0)
                  {
                    trace('bug, no door spots anywhere on the wall of room ' + room);
                    continue;
                  }
                spot = spots[0];
              }
//            trace(spot + ' old: ' + cells[spot.x][spot.y]);
            cells[spot.x][spot.y] = TEMP_BUILDING_INNER_DOOR;
            doors.push({
              x: spot.x,
              y: spot.y,
              dir: spot.dir,
              roomID1: roomID,
              roomID2: -1, // unknown yet
              skip: false,
            });
            markRoom(cells, room, roomID);
          }
      state.doors = doors;
      state.rooms = rooms;
      state.nextRoomID = roomID + 1;
    }

// which of these candidate spots a door may actually be cut into: an inner wall, and not a cell with
// walls on three sides of it (the "triangle", where an opening would face into masonry)
  function doorSpots(cells: Array<Array<Int>>, cand: Array<_Spot>): Array<_Spot>
    {
      var out = [];
      for (s in cand)
        {
          if (cells[s.x][s.y] != TEMP_BUILDING_INNER_WALL)
            continue;
          var cnt = 0;
          for (i in 0...Const.dir4x.length)
            {
              var t = cells[s.x + Const.dir4x[i]][s.y + Const.dir4y[i]];
              if (t == TEMP_BUILDING_INNER_WALL ||
                  t == TEMP_BUILDING_WALL)
                cnt++;
            }
          if (cnt > 2)
            continue;
          out.push(s);
        }
      return out;
    }

// remove double doors into the same rooms
// fix room clusters that have no exit into any corridors
  function fixDoors(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var doors = state.doors;
      // find rooms that the doors lead to
      var area = state.area;
      var cells = area.getCells();
      for (door in doors)
        {
          var delta = deltaMap[door.dir];
          door.roomID2 =
            cells[door.x + delta.x][door.y + delta.y];
          if (door.roomID2 < TEMP_BUILDING_ROOM_ID_START)
            door.roomID2 = 0;
        }
//      trace(doors);

      // remove doors between same rooms
      var toRemove = [];
      for (door in doors)
        {
          if (door.skip || door.roomID2 == 0)
            continue;
          for (door2 in doors)
            {
              if (door2.skip || door2.roomID2 == 0 || door2 == door)
                continue;
              if (door2.roomID1 == door.roomID2 &&
                  door.roomID1 == door2.roomID2)
                {
//                  trace('to remove ' + door + ' door2:' + door2);
                  toRemove.push(door);
                  door2.skip = true;
                }
            }
        }
      for (door in toRemove)
        {
          cells[door.x][door.y] = TEMP_BUILDING_INNER_WALL;
          doors.remove(door);
//          trace('removed ' + door);
        }
//      trace(doors);

      // group the rooms into everything-can-reach-everything sets
      var clusters = roomClusters(state);

      // every room that can already be walked to, which is whichever set ended up holding 0
      var reachable = new Map<Int, Bool>();
      var pending = [];
      for (c in clusters)
        {
          if (Lambda.has(c, 0))
            {
              for (id in c)
                reachable.set(id, true);
            }
          else pending.push(c);
        }

      // and let every other set in.
      //
      // REPEATED UNTIL NOTHING MOVES, because connecting one pocket can be what makes the next one
      // connectable: a pocket buried behind another pocket has no reachable neighbour on the first
      // pass and a perfectly good one on the second. A pass that changes nothing means the rest
      // genuinely cannot be reached and the loop stops rather than spinning
      var progress = true;
      while (pending.length > 0 &&
             progress)
        {
          progress = false;
          for (c in pending.copy())
            {
              var done = false;
              // a corridor is the good outcome: it puts the rooms on the building's circulation
              // rather than making somebody walk through a laboratory to reach them
              for (roomID in c)
                if (makeDoorToCorridor(state, roomID))
                  {
                    done = true;
                    break;
                  }
              // and failing that, any room that can already be reached. a pocket of rooms in the
              // middle of a structure has no corridor wall at all — that is what being in the
              // middle means — so without this it stays sealed however hard the corridor pass looks
              if (!done)
                for (roomID in c)
                  if (makeDoorToRoom(state, roomID, reachable))
                    {
                      done = true;
                      break;
                    }
              if (!done)
                continue;
              for (id in c)
                reachable.set(id, true);
              pending.remove(c);
              progress = true;
            }
        }
      for (c in pending)
        trace('bug, cluster ' + c + ' cannot reach a corridor or any reachable room');
    }

// group this structure's rooms into sets that can reach each other, with room id 0 standing for
// "a corridor, or outdoors".
//
// REPLACES A SINGLE-PASS GROUPING THAT COULD NOT MERGE. The old loop walked the doors once and, for
// each, looked for an existing cluster already holding one of its two rooms — so if rooms A-B had
// formed one cluster and C-D another, a later door joining B to C pushed C into A's cluster and left
// D sitting in the second one, still recorded as a separate group. Which group a room ended up in,
// and whether that group appeared to contain a corridor at all, came down to the order the doors
// happened to be created in.
//
// that is what left 8% of compounds with a room nothing could walk into: a set of rooms joined only
// to each other got merged into a record that DID contain 0, so the "no corridor exit" branch below
// skipped it and never cut the door that would have let anyone in. The rooms had doors, the doors
// were walkable, and every one of them led to another room in the same sealed pocket.
//
// union-find, so merging is the operation it is built on rather than the case it misses
  function roomClusters(state: _FacilityState): Array<Array<Int>>
    {
      var parent = new Map<Int, Int>();
      // 0 is a node like any other: whichever set ends up holding it is the reachable one
      parent.set(0, 0);
      for (r in state.rooms)
        parent.set(r.id, r.id);
      for (d in state.doors)
        {
          if (!parent.exists(d.roomID1) ||
              !parent.exists(d.roomID2))
            continue;
          unite(parent, d.roomID1, d.roomID2);
        }

      var byRoot = new Map<Int, Array<Int>>();
      // 0 goes in first so the set holding it always carries the marker the caller tests for
      var zero = root(parent, 0);
      byRoot.set(zero, [0]);
      for (r in state.rooms)
        {
          var k = root(parent, r.id);
          if (!byRoot.exists(k))
            byRoot.set(k, []);
          byRoot.get(k).push(r.id);
        }
      return [for (k in byRoot.keys()) byRoot.get(k)];
    }

// the representative of a node's set, flattening the path it walked on the way
  static function root(parent: Map<Int, Int>, a: Int): Int
    {
      while (parent.get(a) != a)
        {
          parent.set(a, parent.get(parent.get(a)));
          a = parent.get(a);
        }
      return a;
    }

// put two nodes in the same set
  static function unite(parent: Map<Int, Int>, a: Int, b: Int)
    {
      var ra = root(parent, a);
      var rb = root(parent, b);
      if (ra != rb)
        parent.set(ra, rb);
    }

// cut a door from this room into whichever neighbouring room can already be walked to.
//
// the last resort for a pocket of rooms with no corridor wall between them and the rest of the
// building. A door into a neighbour is a worse answer than a door onto a corridor — it means
// reaching these rooms by walking through another one — but it is the difference between a room
// that is awkward to get to and a room that cannot be entered at all.
//
// the far side of a wall cell is read straight off the grid: makeDoors has already stamped every
// room's id into its own cells, so the neighbour identifies itself
  function makeDoorToRoom(state: _FacilityState, roomID: Int,
      reachable: Map<Int, Bool>): Bool
    {
      var cells = state.area.getCells();
      var room = roomByID(state, roomID);
      if (room == null)
        return false;
      // wall midpoints first, then the rest of the ring, exactly as the corridor pass does
      var hit = pickRoomSpot(cells, doorSpots(cells, getRoomDoorSpots(room)), reachable);
      if (hit == null)
        hit = pickRoomSpot(cells, doorSpots(cells, getRoomWallSpots(room)), reachable);
      if (hit == null)
        return false;
      cells[hit.spot.x][hit.spot.y] = TEMP_BUILDING_INNER_DOOR;
      state.doors.push({
        x: hit.spot.x,
        y: hit.spot.y,
        dir: hit.spot.dir,
        roomID1: roomID,
        roomID2: hit.target,
        skip: false,
      });
      return true;
    }

// the first of these spots whose far side is a room that can already be reached, with that room's id
  function pickRoomSpot(cells: Array<Array<Int>>, cand: Array<_Spot>,
      reachable: Map<Int, Bool>): { spot: _Spot, target: Int }
    {
      for (s in cand)
        {
          var delta = deltaMap[s.dir];
          var t = cells[s.x + delta.x][s.y + delta.y];
          if (t < TEMP_BUILDING_ROOM_ID_START ||
              !reachable.exists(t))
            continue;
          return {
            spot: s,
            target: t,
          };
        }
      return null;
    }

// this structure's room with that id, or null
  function roomByID(state: _FacilityState, roomID: Int): _Room
    {
      for (r in state.rooms)
        if (r.id == roomID)
          return r;
      return null;
    }

// which of these candidate spots open straight onto a corridor
  function corridorSpots(cells: Array<Array<Int>>, cand: Array<_Spot>): Array<_Spot>
    {
      var out = [];
      for (s in cand)
        {
          var delta = deltaMap[s.dir];
          if (cells[s.x + delta.x][s.y + delta.y] == TEMP_BUILDING_CORRIDOR)
            out.push(s);
        }
      return out;
    }

// find a wall adjacent to a corridor and make a hole in it
  function makeDoorToCorridor(state: _FacilityState, roomID: Int): Bool
    {
      // find room
      var area = state.area;
      var cells = area.getCells();
      var room = null;
      for (r in state.rooms)
        if (r.id == roomID)
          {
            room = r;
            break;
          }
//      trace('adding door to room ' + roomID + ' '+ room);

      // get door spots and check which will go into the corridor. the four wall midpoints first,
      // then the whole wall ring most-central-first — a room can easily have a corridor along one
      // wall and a midpoint that is not the cell facing it, which used to come back as "this room
      // cannot reach a corridor" and strand its whole cluster
      var spots = corridorSpots(cells, getRoomDoorSpots(room));
      if (spots.length == 0)
        spots = corridorSpots(cells, getRoomWallSpots(room));
      if (spots.length == 0)
        return false;
      var spot = spots[0];
      cells[spot.x][spot.y] = TEMP_BUILDING_INNER_DOOR;
      state.doors.push({
        x: spot.x,
        y: spot.y,
        dir: spot.dir,
        roomID1: roomID,
        roomID2: 0,
        skip: false,
      });
//      trace(spot);
      return true;
    }

// make windows
  function makeWindows(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      var windowTilesList = [
        [ TEMP_BUILDING_WINDOWH1, TEMP_BUILDING_WINDOWH2, TEMP_BUILDING_WINDOWH3 ],
        [ TEMP_BUILDING_WINDOWV1, TEMP_BUILDING_WINDOWV2, TEMP_BUILDING_WINDOWV3 ],
        [ TEMP_BUILDING_WINDOWH1, TEMP_BUILDING_WINDOWH3 ],
        [ TEMP_BUILDING_WINDOWV1, TEMP_BUILDING_WINDOWV3 ],
      ];
      var table1TilesList = [
        [ Const.TILE_LABS_TABLE_3X1_1, Const.TILE_LABS_TABLE_3X1_2, Const.TILE_LABS_TABLE_3X1_3, ],
        [ Const.TILE_LABS_TABLE_1X3_1, Const.TILE_LABS_TABLE_1X3_2, Const.TILE_LABS_TABLE_1X3_3, ],
        [ Const.TILE_LABS_TABLE_3X1_1, Const.TILE_LABS_TABLE_3X1_3, ],
        [ Const.TILE_LABS_TABLE_1X3_1, Const.TILE_LABS_TABLE_1X3_3, ],
      ];
      var table2TilesList = [
        [ Const.TILE_LABS_TABLE2_3X1_1, Const.TILE_LABS_TABLE2_3X1_2, Const.TILE_LABS_TABLE2_3X1_3, ],
        [ Const.TILE_LABS_TABLE2_1X3_1, Const.TILE_LABS_TABLE2_1X3_2, Const.TILE_LABS_TABLE2_1X3_3, ],
        [ Const.TILE_LABS_TABLE2_3X1_1, Const.TILE_LABS_TABLE2_3X1_3, ],
        [ Const.TILE_LABS_TABLE2_1X3_1, Const.TILE_LABS_TABLE2_1X3_3, ],
      ];
      for (room in state.rooms)
        {
          // clear room to default tile
          drawBlock(cells, room.x1, room.y1, room.w, room.h, TEMP_BUILDING_ROOM);
          // a washroom takes NONE of what follows: not the ribbon glazing, not the bench runs, not
          // the floor decoration. it gets light wells up one wall and is otherwise dressed entirely
          // by its own template
          if (room.role == ROLE_TOILET)
            {
              toiletWindows(cells, room);
              continue;
            }
          var corners = getRoomWallCorners(room);
//          trace(room + ' ' + corners);
          for (spot in corners)
            {
              var noWindow = false;
              if (cells[spot.x][spot.y] != TEMP_BUILDING_WALL)
                noWindow = true;

              // pick correct window tiles list
              var windowSize = 3;
              var windowTiles = null;
              var tableTilesList = table1TilesList;
              // only upper horizontal tables can have drawers
              if (spot.dir == DIR_RIGHT &&
                  spot.dir90 == DIR_DOWN &&
                  Std.random(100) < 50)
                tableTilesList = table2TilesList;
              var tableTiles = null;
              if (spot.dir == DIR_RIGHT && room.w < 7)
                {
                  windowSize = 2;
                  windowTiles = windowTilesList[2];
                  tableTiles = tableTilesList[2];
                }
              else if (spot.dir == DIR_RIGHT)
                {
                  windowTiles = windowTilesList[0];
                  tableTiles = tableTilesList[0];
                }
              else if (spot.dir == DIR_DOWN && room.h < 7)
                {
                  windowSize = 2;
                  windowTiles = windowTilesList[3];
                  tableTiles = tableTilesList[3];
                }
              else if (spot.dir == DIR_DOWN)
                {
                  windowTiles = windowTilesList[1];
                  tableTiles = tableTilesList[1];
                }

              // paint window and table near it
              var len = 0;
              var tablelen = 0;
              var cnt = 0;
              var delta = deltaMap[spot.dir];
              var delta90 = deltaMap[spot.dir90];
              var x = spot.x, y = spot.y;
              var tx = 0, ty = 0; // table x,y
              var noTable = false;
              // the door-clearance box one BLOCK of tables needs: its length along the run and its
              // one cell across it
              var tw = (spot.dir == DIR_DOWN ? 1 : windowSize);
              var th = (spot.dir == DIR_RIGHT ? 1 : windowSize);
              // does THIS block of tables stand beside a doorway? two things differ from the test it
              // replaces. It is taken on the TABLE line and not the window line, because a doorway
              // one row PAST the tables is still a doorway a bench stands in the swing of and a box
              // centred on the glazing does not reach it. And it is evaluated HERE as well as at
              // each block boundary, because that branch only fires once windowSize cells have gone
              // by — a run's OPENING block was never tested at all, which is the block the bench
              // reported as clipping an open door was in.
              //
              // per block and not latched like noTable above: a run that passes a door in the middle
              // carries on tabling afterwards
              var doorBlock = isBlockNearDoor(cells, spot.x + delta.x + delta90.x,
                spot.y + delta.y + delta90.y, tw, th);
              var hasVentSpace = false; // space near window corner
              while (true)
                {
                  x += delta.x;
                  y += delta.y;
                  tx = x + delta90.x;
                  ty = y + delta90.y;
                  if (cells[x][y] != TEMP_BUILDING_WALL)
                    noWindow = true;
                  if (len >= windowSize)
                    {
                      len = 0;
                      tablelen = 0;
                      cnt++;
                      if (spot.dir == DIR_DOWN &&
                          y >= room.y2 - windowSize)
                        noTable = true;
                      else if (spot.dir == DIR_RIGHT &&
                          x > room.x2 - windowSize)
                        noTable = true;
                      doorBlock = isBlockNearDoor(cells, tx, ty, tw, th);
                      continue;
                    }
                  if (spot.dir == DIR_RIGHT && x >= room.x2 + 1)
                    break;
                  else if (spot.dir == DIR_DOWN && y >= room.y2 + 1)
                    break;
                  if (!noWindow)
                    cells[x][y] = windowTiles[len];
                  len++;
                  // skip first vertical table
                  if (spot.dir == DIR_DOWN && (cnt == 0))// || !noWindow))
                    continue;
                  // already table or decoration there
                  if (cells[tx][ty] != TEMP_BUILDING_ROOM)
                    continue;
                  if (noTable || doorBlock)
                    {
                      // no table - add floor decoration
                      if (!nextTo(cells, tx, ty, TEMP_BUILDING_INNER_DOOR) &&
                          !area.hasObjectAt(tx, ty))
                        {
                          if (Std.random(100) < 70)
                            {
                              var high = Std.random(100) < 50;
                              var nextToWindow = nextToWindow(cells, tx, ty);
                              // a decoration beside glazing has to be a LOW one or it stands in
                              // the window
                              if (nextToWindow)
                                high = false;
                              // and so does the one standing in for a bench beside a DOORWAY: a
                              // 2.8-tall fitting there reads as blocking the opening, where a bin or
                              // a drum reads as something somebody left by the door. the cell
                              // orthogonally next to the opening still gets nothing at all — the
                              // nextTo test above keeps the doorway itself walkable
                              if (doorBlock)
                                high = false;
                              // leave space for
                              if (nextToWindow && Std.random(100) < 70)
                                hasVentSpace = true;
                              else
                                {
                                  // a HIGH decoration has plain masonry behind it, which is what a
                                  // piece of standing furniture needs, so it may come out as real
                                  // 3D geometry instead of an upright sprite — see
                                  // Const.FACILITY_FITTINGS and render.facility.FacilityDeco
                                  // an office takes STANDING furniture and nothing else: a crate of
                                  // flasks or a waste drum on the floor is the laboratory's clutter,
                                  // and the low list is all laboratory
                                  if (room.role == ROLE_CABINET)
                                    {
                                      if (high)
                                        addFitting(state, tx, ty, room.role);
                                    }
                                  else if (high &&
                                      Std.random(100) < Const.FACILITY_FITTING_PCT)
                                    addFitting(state, tx, ty);
                                  else
                                    addDecoration(state, tx, ty, high ?
                                      Const.CHEM_LABS_DECO_FLOOR_HIGH :
                                      Const.CHEM_LABS_DECO_FLOOR_LOW);
                                  // change to unwalkable tile
                                  if (area.hasObjectAt(tx, ty))
                                    cells[tx][ty] =
                                      Const.TILE_FLOOR_TILE_UNWALKABLE;
                                }
                            }
                        }
                    }
                  else
                    {
                      // add next table tile
                      if (cells[tx][ty] == TEMP_BUILDING_ROOM)
                        {
                          cells[tx][ty] = tableTiles[tablelen];
                          tablelen++;
                        }
                      // add table decoration
                      // NOTE: corner tile always has decoration
                      // so that we cannot spawn clues there
                      // because of the clue activation range cross
                      if (Std.random(100) < 70 ||
                          (tx == room.x1 && ty == room.y1) ||
                          (tx == room.x2 && ty == room.y1) ||
                          (tx == room.x1 && ty == room.y2) ||
                          (tx == room.x2 && ty == room.y2))
                        addDecoration(state, tx, ty,
                          Const.CHEM_LABS_DECO_TABLE);
                    }
                }
              // fix last cell if necessary
              x -= delta.x;
              y -= delta.y;
              if (cells[x][y] == TEMP_BUILDING_WINDOWH2)
                cells[x][y] = TEMP_BUILDING_WINDOWH3;
              else if (cells[x][y] == TEMP_BUILDING_WINDOWH1)
                {
                  cells[x][y] = TEMP_BUILDING_WINDOW;
                  if (Std.random(100) < 30 || hasVentSpace)
                    cells[x][y] = TEMP_BUILDING_VENT;
                }
              else if (cells[x][y] == TEMP_BUILDING_WINDOWV2)
                cells[x][y] = TEMP_BUILDING_WINDOWV3;
              else if (cells[x][y] == TEMP_BUILDING_WINDOWV1)
                {
                  cells[x][y] = TEMP_BUILDING_WINDOW;
                  if (Std.random(100) < 30 || hasVentSpace)
                    cells[x][y] = TEMP_BUILDING_VENT;
                }
            }
          // and with the room's benches dealt, make sure a clue still has somewhere to land on them
          clearTableSpots(state, room);
        }
    }

// leave at least TABLE_CLEAR_MIN of this room's bench cells bare, by taking decorations back off.
//
// A CLUE SPOT IS A BENCH TILE WITH NO OBJECT ON IT (game.AreaGame.initSpawnPoints) and this pass is
// the only thing that can promise one exists. The walk above decorates about 70% of bench cells and
// FORCES one on all four room corners, and two render-only families then cover more of what is left —
// render.facility.FacilitySink takes a free edge cell of every bench block for its basin and
// render.facility.FacilityWork stands a workstation on the office desks (render.facility
// .FacilityClues prunes both out of the list). On a small room the three together reached zero, and a
// facility with no legal spot simply stops handing out clues.
//
// THE CORNERS ARE NEVER FREED and that is the one hard rule here: the walk forces a decoration onto
// them precisely so a clue cannot spawn there, because the activation range cross would reach through
// the wall. So the reserve is taken out of the middle of a run, where a bare metre of worktop is what
// a bench looks like anyway
  function clearTableSpots(state: _FacilityState, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      var free = 0;
      var taken = [];
      for (y in room.y1...room.y2 + 1)
        for (x in room.x1...room.x2 + 1)
          {
            if (cells[x][y] < Const.TILE_LABS_TABLE_3X3_7 ||
                cells[x][y] > Const.TILE_LABS_TABLE2_1X1)
              continue;
            if (!area.hasObjectAt(x, y))
              {
                free++;
                continue;
              }
            // a corner cell is spoken for, and so is anything that is not a plain decoration — a
            // fitting or a generated object on a bench cell is somebody else's placement
            if ((x == room.x1 || x == room.x2) &&
                (y == room.y1 || y == room.y2))
              continue;
            for (o in area.getObjectsAt(x, y))
              if (o.type == 'decoration')
                taken.push(o);
          }
      var i = 0;
      while (free < TABLE_CLEAR_MIN &&
             i < taken.length)
        {
          area.removeObject(taken[i]);
          free++;
          i++;
        }
    }

// a washroom's glazing: small light wells up ONE wall and nothing on the other three.
//
// one wall because that is what a washroom has — a room you are not seen into gets its light from a
// single external face — and because every cell of the other three is then free for cubicles and
// basins, which is what roomToilet wants and what roomWallRuns measures.
//
// EVERY OTHER CELL and not a run: these are separate openings, not a ribbon, so the renderer maps one
// image across each rather than one across the whole length. the first and last cell of the wall are
// left as masonry so an opening never lands in a corner
  function toiletWindows(cells: Array<Array<Int>>, room: _Room)
    {
      var spot = exteriorWall(cells, room);
      if (spot == null)
        return;
      var delta = deltaMap[spot.dir];
      var len = (spot.dir == DIR_RIGHT ? room.w : room.h);
      for (i in 1...len - 1)
        if (i % 2 == 1)
          cells[spot.x + delta.x * (i + 1)][spot.y + delta.y * (i + 1)] =
            TEMP_BUILDING_WINDOW_HIGH;
    }

// the first wall of this room that is EXTERIOR masonry for its whole length, or null for a room in
// the middle of a building. an inner wall faces another room or a corridor and has nothing to be a
// light well onto, so this is both what toiletWindows paints and what assignRoomThemes prefers a
// washroom to have — asked before the roles are dealt, which is why it is its own function
  function exteriorWall(cells: Array<Array<Int>>, room: _Room): _Spot
    {
      for (spot in getRoomWallCorners(room))
        {
          var delta = deltaMap[spot.dir];
          var len = (spot.dir == DIR_RIGHT ? room.w : room.h);
          var solid = true;
          for (i in 0...len)
            if (cells[spot.x + delta.x * (i + 1)][spot.y + delta.y * (i + 1)] != TEMP_BUILDING_WALL)
              solid = false;
          if (solid)
            return spot;
        }
      return null;
    }

// hand each room of this structure a template.
//
// the same shape game.CorpAreaGenerator uses for its four office themes: size, a quota and dice, with
// no persisted tag — the room's FLOOR TILE is what carries the theme out of here, and the 3D layer
// reads the theme back off that tile alone (render.facility.FacilityModel.surfOf)
  function assignRoomThemes(state: _FacilityState)
    {
      // a big room is a laboratory: the bench runs, the island and the aisle markings all want the
      // space, and a compound of nothing but small offices reads as an office block
      var cells = state.area.getCells();
      var cand = [for (room in state.rooms)
        if (room.w <= ROOM_SIZE && room.h <= ROOM_SIZE) room];
      if (cand.length == 0)
        return;
      // THE WASHROOM IS PICKED FIRST AND PICKED FOR ITS WALL. Its light wells need one wall that is
      // exterior masonry end to end, and a room in the middle of a building has none — so a plain
      // first-come roll put the compound's only washroom in an interior core about half the time and
      // it came out with no glazing at all. The lab and the office are indifferent to this, so the
      // toilet gets first refusal on a perimeter room and they take what is left
      var wash = -1;
      for (i in 0...cand.length)
        if (exteriorWall(cells, cand[i]) != null)
          {
            wash = i;
            break;
          }
      if (wash < 0)
        wash = 0;
      if (Std.random(100) < 60)
        cand[wash].role = ROLE_TOILET;
      var cabinets = 0;
      for (i in 0...cand.length)
        {
          if (cand[i].role != null ||
              cabinets >= 2)
            continue;
          if (Std.random(100) < 85)
            {
              cabinets++;
              cand[i].role = ROLE_CABINET;
            }
        }
    }

// fill rooms with content
  function generateRoomContents(state: _FacilityState)
    {
      for (room in state.rooms)
        {
          if (room.role == ROLE_CABINET)
            roomCabinet(state, room);
          else if (room.role == ROLE_TOILET)
            roomToilet(state, room);
          else roomChemistryLab(state, room);
        }
    }

// make this room a researcher's office: the desks are already standing (makeWindows lays them as
// bench runs, which is the same furniture one texture family apart), so all this owes is the floor.
//
// the tiles are written FINAL and not TEMP, exactly as roomChemistryLab writes its drain and its
// unwalkable cells — finalizeTiles only rewrites ids it has a row for and leaves these alone
  function roomCabinet(state: _FacilityState, room: _Room)
    {
      // the bookcases, document cabinets and server racks, placed OUTRIGHT on the free wall cells the
      // washroom's own machinery finds. they used to arrive only through makeWindows' leftover-cell
      // roll, which fires where a desk could not go and on a small office is often nowhere
      var edges = roomWallRuns(state, room);
      edges.sort(function(a, b) return b.length - a.length);
      var want = OFFICE_FITTING_MIN +
        Std.random(OFFICE_FITTING_MAX - OFFICE_FITTING_MIN + 1);
      // one per wall before a second goes on any wall, so a small office does not get its whole set
      // stacked down one side
      for (i in 0...want)
        {
          var run = edges[i % edges.length];
          var k = Std.int(i / edges.length);
          if (k >= run.length)
            continue;
          addFitting(state, run[k].x, run[k].y, ROLE_CABINET);
          if (state.area.hasObjectAt(run[k].x, run[k].y))
            state.area.getCells()[run[k].x][run[k].y] = Const.TILE_FLOOR_TILE_UNWALKABLE;
        }
      paintRoomFloor(state, room, Const.TILE_FLOOR_WOOD1);
    }

// make this room a washroom: a run of cubicles against the best wall, a basin counter against the
// next best, and no benches at all (makeWindows skipped it)
  function roomToilet(state: _FacilityState, room: _Room)
    {
      var cells = state.area.getCells();
      // the dividing wall goes in FIRST: it takes cells out of the wall runs below, and the two it
      // deliberately leaves bare are passages that nothing else may stand in
      var split = toiletPartition(state, room);
      var edges = roomWallRuns(state, room);
      for (run in edges)
        for (p in split.pass)
          {
            for (i in 0...run.length)
              if (run[i].x == p.x && run[i].y == p.y)
                {
                  run.splice(i, 1);
                  break;
                }
          }
      // AND EACH HALF IS FURNISHED ON ITS OWN, which the one-room pass could not do. Sorting all four
      // walls together and giving the longest two cubicles put every cubicle on one side of the T and
      // every basin on the other — two rooms, one of them with nowhere to wash and the other with
      // nothing to use. Split by which side of the stem a cell is on and the same rule runs twice:
      // the half's longest wall takes cubicles, its next takes basins.
      //
      // the LOBBY comes out of every run first. It is the strip you stand in with the door at your
      // back, one cell deep, and a cubicle in it is a cubicle across the entrance
      var stalls = 0;
      for (half in 0...2)
        {
          var runs = [];
          for (run in edges)
            {
              var keep = [];
              for (c in run)
                {
                  var o = (split.vertical ? c.x : c.y);
                  if (split.lobby >= 0 &&
                      o == split.lobby)
                    continue;
                  // a room with no stem has no halves, so the whole of it is dealt on the first pass
                  if (split.stem >= 0)
                    {
                      var s = (split.vertical ? c.y : c.x);
                      if (s == split.stem ||
                          (s < split.stem) != (half == 0))
                        continue;
                    }
                  else if (half > 0)
                    continue;
                  keep.push(c);
                }
              runs.push(keep);
            }
          // longest first: cubicles want the long wall, the basin counter takes the next, and
          // whatever is shortest is left bare — a half ranked out on every wall is a corridor with
          // nowhere to turn round
          runs.sort(function(a, b) return b.length - a.length);
          // TWO walls of the four, never more: the rest of the half is floor
          for (e in 0...2)
            {
              if (e >= runs.length)
                break;
              var run = runs[e];
              if (run.length < 2)
                continue;
              // the first wall of the half is cubicles, the next is basins
              var kind: _FittingKind = (e < 1 ? FIT_STALL : FIT_BASIN);
              var n = (kind == FIT_STALL ? 2 + Std.random(2) : 1 + Std.random(2));
              if (n > run.length)
                n = run.length;
              if (kind == FIT_STALL && stalls + n > TOILET_STALL_MAX)
                n = TOILET_STALL_MAX - stalls;
              for (i in 0...n)
                placeFitting(state, run[i].x, run[i].y, kind);
              if (kind == FIT_STALL)
                stalls += n;
            }
        }
      paintRoomFloor(state, room, Const.TILE_FLOOR_MARBLE1);

      // a washroom keeps the floor drain the laboratory rolls
      var cx = room.x1 + 1 + Std.random(room.w - 2),
        cy = room.y1 + 1 + Std.random(room.h - 2);
      if (cells[cx][cy] == TEMP_BUILDING_ROOM &&
          Std.random(100) < 50)
        {
          cells[cx][cy] = Const.TILE_FLOOR_TILE + 1 + Std.random(3);
          state.area.add('floorDrain', cx, cy);
        }
    }

// split the washroom into its two halves and say where the split went.
//
// A LINE OF FITTINGS AND NOT A WALL. state.rooms is frozen at makeDoors and the room ids are already
// written into the cell grid, so masonry stamped here would leave two halves sharing one _Room, one
// id, one ceiling light and one stale mark. A fitting line costs none of that: placeFitting stamps
// each cell unwalkable exactly as a cubicle does, and render.facility.FacilityDeco stands a
// full-height slab on it (FacilityStyle.PART_T).
//
// AND IT IS A T, WHICH IS THE WHOLE POINT AND WAS A SINGLE LINE FOR ONE BUILD. That line ran down the
// middle with the cell at EACH end left open, and two halves joined at both ends are not two rooms —
// you walked in and could see and reach the whole place, which is the one thing a washroom may not
// do. A T fixes it with the same fittings:
//
//   * the BAR runs parallel to the entrance wall, ONE CELL IN FROM IT. The strip it leaves against
//     that wall is the lobby, i.e. the bit you stand in with the door behind you, and the cell at
//     each END of the bar is left open — those two are the passages, one into each half.
//   * the STEM runs from the middle of the bar to the opposite wall, so everything past the bar is
//     split in two and there is NO path from one half to the other.
//
// so the walk is door -> lobby -> the men's gap or the women's, and each half is closed. The bar's
// own middle cell is where the two lines meet, and render.facility.FacilityDeco.rectOf emits a CROSS
// there rather than one slab (see its FIT_PARTITION branch) — without that the stem stops
// (CELL - PART_T) / 2 short of the bar and the T has a hole in it.
//
// A ROOM TOO SMALL FOR A T FALLS BACK to the old single line: the bar needs three cells to have a
// middle that is not one of its own passages, and the stem needs a cell to stand in past it
  function toiletPartition(state: _FacilityState, room: _Room): _ToiletSplit
    {
      // which wall the door is in, as the hand pointing INTO the room off it. the door cell itself is
      // in the wall ring, i.e. outside the room's own rect, which is what makes this a comparison
      var side = -1;
      for (d in getRoomDoors(state, room))
        {
          if (d.x < room.x1)
            side = 3;
          else if (d.x > room.x2)
            side = 2;
          else if (d.y < room.y1)
            side = 1;
          else if (d.y > room.y2)
            side = 0;
          if (side >= 0)
            break;
        }
      // the BAR is parallel to that wall, so it runs on the axis the hand is NOT on
      var vertical = (side >= 2);
      var barLen = (vertical ? room.h : room.w);
      var deep = (vertical ? room.w : room.h);
      if (side < 0 ||
          barLen < 3 ||
          deep < 3)
        return toiletLine(state, room);
      // one cell in from the entrance wall, which leaves exactly one cell of lobby against it
      var bar = (vertical ?
        (side == 3 ? room.x1 + 1 : room.x2 - 1) :
        (side == 1 ? room.y1 + 1 : room.y2 - 1));
      var lobby = (vertical ?
        (side == 3 ? room.x1 : room.x2) :
        (side == 1 ? room.y1 : room.y2));
      // and the stem leaves the bar at its middle, on the same even-span rule the old line took
      var stem = (vertical ?
        room.y1 + Std.int(room.h / 2) :
        room.x1 + Std.int(room.w / 2));
      var pass = [];
      for (i in 0...barLen)
        {
          var x = (vertical ? bar : room.x1 + i);
          var y = (vertical ? room.y1 + i : bar);
          // the two ends of the bar are the passages
          if (i == 0 ||
              i == barLen - 1)
            {
              pass.push({ x: x, y: y });
              continue;
            }
          partitionCell(state, x, y);
        }
      // the stem, from the cell past the bar to the far wall
      for (i in 0...deep)
        {
          var o = (vertical ? room.x1 + i : room.y1 + i);
          // past the bar only: the lobby side of it is the entrance and must stay open. which way
          // "past" is depends on which wall the door was in, and sides 1 and 3 are the two the hand
          // runs with the axis on
          var beyond = (side == 3 || side == 1 ? o > bar : o < bar);
          if (!beyond)
            continue;
          if (vertical)
            partitionCell(state, o, stem);
          else partitionCell(state, stem, o);
        }
      return {
        pass: pass,
        vertical: vertical,
        bar: bar,
        lobby: lobby,
        stem: stem,
      };
    }

// the single centre line the T falls back to on a room with no room for one. the shape this family
// shipped with, kept whole rather than special-cased inside the T: both ends open, no stem, and so no
// halves — `stem` comes back -1 and roomToilet furnishes the room as one space
  function toiletLine(state: _FacilityState, room: _Room): _ToiletSplit
    {
      var vertical = (room.w >= room.h);
      var bar = (vertical ?
        room.x1 + Std.int(room.w / 2) :
        room.y1 + Std.int(room.h / 2));
      var len = (vertical ? room.h : room.w);
      var pass = [];
      for (i in 0...len)
        {
          var x = (vertical ? bar : room.x1 + i);
          var y = (vertical ? room.y1 + i : bar);
          if (i == 0 ||
              i == len - 1)
            {
              pass.push({ x: x, y: y });
              continue;
            }
          partitionCell(state, x, y);
        }
      return {
        pass: pass,
        vertical: vertical,
        bar: bar,
        lobby: -1,
        stem: -1,
      };
    }

// one cell of either line. a cell already taken — a doorway's clearance, an object — is simply
// skipped: a wider gap in the middle of a partition is still a washroom, where a slab standing in a
// doorway is not
  function partitionCell(state: _FacilityState, x: Int, y: Int)
    {
      var cells = state.area.getCells();
      if (cells[x][y] != TEMP_BUILDING_ROOM ||
          nextTo(cells, x, y, TEMP_BUILDING_INNER_DOOR) ||
          state.area.hasObjectAt(x, y))
        return;
      placeFitting(state, x, y, FIT_PARTITION);
    }

// repaint a themed room's floor, walkable cells in `tile` and the cells furniture stands on in its
// unwalkable twin one tileset row below. the bench tiles are left alone: a desk is a prop standing ON
// the floor, and the renderer takes a table cell's surface off the ROOM it sits in
  function paintRoomFloor(state: _FacilityState, room: _Room, tile: Int)
    {
      var cells = state.area.getCells();
      for (y in room.y1...room.y2 + 1)
        for (x in room.x1...room.x2 + 1)
          {
            if (cells[x][y] == TEMP_BUILDING_ROOM)
              cells[x][y] = tile;
            else if (cells[x][y] == Const.TILE_FLOOR_TILE_UNWALKABLE)
              cells[x][y] = tile + UNWALKABLE_TILE_OFFSET;
          }
    }

// the cells of each wall of this room a piece of standing furniture may take: on the room's edge,
// backed by SOLID masonry (a high fitting against glazing is dropped by the renderer), clear of every
// doorway and of whatever is standing there already. one array per wall, longest run wins
  function roomWallRuns(state: _FacilityState, room: _Room): Array<Array<{ x: Int, y: Int }>>
    {
      var area = state.area;
      var cells = area.getCells();
      var out = [];
      var walls = [
        { x: room.x1, y: room.y1, dx: 1, dy: 0, len: room.w, nx: 0, ny: -1 }, // top
        { x: room.x1, y: room.y2, dx: 1, dy: 0, len: room.w, nx: 0, ny: 1 },  // bottom
        { x: room.x1, y: room.y1, dx: 0, dy: 1, len: room.h, nx: -1, ny: 0 }, // left
        { x: room.x2, y: room.y1, dx: 0, dy: 1, len: room.h, nx: 1, ny: 0 },  // right
      ];
      for (w in walls)
        {
          var run = [];
          for (i in 0...w.len)
            {
              var x = w.x + w.dx * i, y = w.y + w.dy * i;
              var back = cells[x + w.nx][y + w.ny];
              if (cells[x][y] != TEMP_BUILDING_ROOM ||
                  (back != TEMP_BUILDING_WALL && back != TEMP_BUILDING_INNER_WALL) ||
                  nextTo(cells, x, y, TEMP_BUILDING_INNER_DOOR) ||
                  area.hasObjectAt(x, y))
                continue;
              run.push({ x: x, y: y });
            }
          out.push(run);
        }
      return out;
    }

// make this room a chem lab
  function roomChemistryLab(state: _FacilityState, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      var roomDoors = getRoomDoors(state, room);

      // put a drain
      var cx = room.x1 + 1 + Std.random(room.w - 2),
        cy = room.y1 + 1 + Std.random(room.h - 2);
      cells[cx][cy] = Const.TILE_FLOOR_TILE + 1 + Std.random(3);
      if (Std.random(100) < 30)
        {
          state.area.add('floorDrain', cx, cy);
        }

      // make a big table near the center
      if (room.w < 7 || room.h < 7)
        return;

      var block = Std.random(100) < 50 ? Const.LABS_TABLE_3X2 :
        Const.LABS_TABLE_2X3;
      var tableW = block[0].length, tableH = block.length;
      var sx = -1, sy = -1;
      var xOffsets = [ 2, 3 ];
      var yOffsets = [ 2, 3 ];
      if (Std.random(100) < 50)
        xOffsets = [ 3, 2 ];
      if (Std.random(100) < 50)
        yOffsets = [ 3, 2 ];
      var foundSpot = false;
      for (xOffset in xOffsets)
        {
          var candidateX = room.x1 + xOffset;
          if (candidateX + tableW >= room.x2 - 2)
            candidateX = room.x1 + 2;
          for (yOffset in yOffsets)
            {
              var candidateY = room.y1 + yOffset;
              if (candidateY + tableH >= room.y2 - 2)
                candidateY = room.y1 + 2;
              if (!isBigTableSpotValid(state, room, roomDoors,
                  candidateX, candidateY, tableW, tableH))
                continue;
              sx = candidateX;
              sy = candidateY;
              foundSpot = true;
              break;
            }
          if (foundSpot)
            break;
        }
      if (!foundSpot)
        return;
      for (i in 0...tableH)
        for (j in 0...tableW)
          {
            cells[sx + j][sy + i] = block[i][j];
            if (Std.random(100) < 70)
              addDecoration(state, sx + j, sy + i,
                Const.CHEM_LABS_DECO_TABLE);
          }
    }

// get all doors that lead into this room
  function getRoomDoors(state: _FacilityState, room: _Room): Array<_Door>
    {
      var doors = [];
      for (door in state.doors)
        if (door.roomID1 == room.id ||
            door.roomID2 == room.id)
          doors.push(door);
      return doors;
    }

// check if a big table spot keeps room door ingress clear
  function isBigTableSpotValid(state: _FacilityState, room: _Room,
      doors: Array<_Door>, x: Int, y: Int, w: Int, h: Int): Bool
    {
      var cells = state.area.getCells();
      for (i in 0...h)
        for (j in 0...w)
          if (cells[x + j][y + i] != TEMP_BUILDING_ROOM)
            return false;

      for (door in doors)
        {
          var sx = 0, sy = 0;
          var dx = 0, dy = 0;
          var hasIngress = false;
          if (door.x == room.x1 - 1)
            {
              sx = room.x1;
              sy = door.y;
              dx = 1;
              hasIngress = true;
            }
          else if (door.x == room.x2 + 1)
            {
              sx = room.x2;
              sy = door.y;
              dx = -1;
              hasIngress = true;
            }
          else if (door.y == room.y1 - 1)
            {
              sx = door.x;
              sy = room.y1;
              dy = 1;
              hasIngress = true;
            }
          else if (door.y == room.y2 + 1)
            {
              sx = door.x;
              sy = room.y2;
              dy = -1;
              hasIngress = true;
            }
          if (!hasIngress)
            continue;

          for (i in 0...BIG_TABLE_DOOR_CLEARANCE)
            {
              var px = sx + dx * i;
              var py = sy + dy * i;
              if (px >= x &&
                  px < x + w &&
                  py >= y &&
                  py < y + h)
                return false;
            }
        }
      return true;
    }

// add a decoration that the 3D view draws as real furniture: a KIND off Const.FACILITY_FITTINGS,
// carrying one of that kind's own atlas frames.
//
// the frame is what the 2D view keeps drawing and what render.facility.FacilityModel reads the kind
// back out of, so nothing new is written to the object and every save made before this existed
// still resolves — see Const.fittingOf
  function addFitting(state: _FacilityState, x: Int, y: Int, ?role: String)
    {
      // the HIGH kinds only: the table also holds the low list's drums, bins and short server
      // stacks, and none of those is a piece of standing furniture. an office takes the narrower
      // list — a bench lathe against the wall of a researcher's room is the laboratory's furniture
      var kinds = (role == ROLE_CABINET ? Const.officeFittings() : Const.highFittings());
      var f = kinds[Std.random(kinds.length)];
      var fr = f.frames[Std.random(f.frames.length)];
      state.area.addDecoration(x, y, fr.row, fr.col);
    }

// stand one fitting of a NAMED kind, for a room template placing its own furniture instead of rolling
// it. the cell goes unwalkable here and the template's own floor pass repaints it in its finish
  function placeFitting(state: _FacilityState, x: Int, y: Int, kind: _FittingKind)
    {
      var frames = Const.framesOf(kind);
      var fr = frames[Std.random(frames.length)];
      state.area.addDecoration(x, y, fr.row, fr.col);
      state.area.getCells()[x][y] = Const.TILE_FLOOR_TILE_UNWALKABLE;
    }

// add decoration from a list
  function addDecoration(state: _FacilityState, x: Int, y: Int, infos: Array<_TileRow>)
    {
      var info = infos[Std.random(infos.length)];
      var col = Std.random(info.amount);
      state.area.addDecoration(x, y, info.row, col);
    }

// check a w,h block at x,y if it is near a door
  function isBlockNearDoor(cells: Array<Array<Int>>, x: Int, y: Int,
      w: Int, h: Int): Bool
    {
      for (i in -1...w + 1)
        for (j in -1...h + 1)
          if (cells[x + i][y + j] == TEMP_BUILDING_INNER_DOOR)
            return true;
      return false;
    }

// check if this cell is next to a window
  function nextToWindow(cells: Array<Array<Int>>,
      x: Int, y: Int): Bool
    {
      var tile = 0;
      for (i in 0...Const.dir4x.length)
        {
          tile = cells[x + Const.dir4x[i]][y + Const.dir4y[i]];
          if (tile >= TEMP_BUILDING_WINDOW &&
              tile <= TEMP_BUILDING_WINDOWV3)
            return true;
        }
      return false;
    }

// does this doorway open onto a themed room — a washroom or a researcher's office? the floor tile is
// the theme record (see assignRoomThemes), so this is a four-neighbour test on the FINAL ids the
// templates painted, walkable cell or the unwalkable twin one tileset row below
  function opensOnPrivateRoom(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      for (i in 0...Const.dir4x.length)
        {
          var tile = cells[x + Const.dir4x[i]][y + Const.dir4y[i]];
          if (tile == Const.TILE_FLOOR_WOOD1 ||
              tile == Const.TILE_FLOOR_WOOD1 + UNWALKABLE_TILE_OFFSET ||
              tile == Const.TILE_FLOOR_MARBLE1 ||
              tile == Const.TILE_FLOOR_MARBLE1 + UNWALKABLE_TILE_OFFSET)
            return true;
        }
      return false;
    }

// calc distance from this point to end of the main corridor
  function distanceToFinish(cells: Array<Array<Int>>,
      sx: Int, sy: Int, dir: Int): Int
    {
      var len = 0, x = sx, y = sy;
      var delta = deltaMap[dir];
      while (true)
        {
          len++;
          if (len > 100)
            {
              trace('long corridor?');
              break;
            }
          x += delta.x;
          y += delta.y;
          if (cells[x][y] < TEMP_BUILDING_WALL)
            break;
        }
      return len - 1;
    }

// draw a narrow side corridor
  function drawSideCorridor(cells: Array<Array<Int>>,
      sx: Int, sy: Int, dir: Int)
    {
      var len = 0, x = sx, y = sy;
      var delta = deltaMap[dir];
      while (true)
        {
          len++;
          if (len > 100)
            {
              trace('long corridor?');
              break;
            }
          x += delta.x;
          y += delta.y;
          if (cells[x][y] < TEMP_BUILDING_WALL)
            {
              x -= delta.x;
              y -= delta.y;
              drawChunk(cells, x, y, 2, dir, TEMP_BUILDING_WALL);
              var rnd = Std.random(100);
              if (rnd < 30)
                cells[x][y] = TEMP_BUILDING_SIDE_DOOR;
              else if (rnd < 60)
                cells[x][y] = TEMP_BUILDING_WINDOW;
              break;
            }
          drawChunk(cells, x, y, 2, dir, TEMP_BUILDING_CORRIDOR);
        }
    }

// does this tile belong to a ROOM rather than to a corridor? lino is the corridor floor AND the
// floor under every door, which is exactly what separates one room from the next
  static function isRoomFloor(t: Int): Bool
    {
      if (t == Const.TILE_FLOOR_LINO)
        return false;
      if (t == Const.TILE_FLOOR_TILE ||
          t == Const.TILE_FLOOR_TILE_UNWALKABLE ||
          t == Const.TILE_FLOOR_TILE_CANNOTSEE ||
          t == Const.TILE_FLOOR_CONCRETE ||
          t == Const.TILE_FLOOR_CONCRETE_UNWALKABLE)
        return true;
      if (t >= Const.TILE_FLOOR_TILE_GRATE1 &&
          t <= Const.TILE_FLOOR_TILE_GRATE3)
        return true;
      // every table tile stands on room floor
      return (t >= Const.OFFSET_ROW8);
    }

// room id at a cell, or -1
  static inline function roomAt(mark: Array<Array<Int>>, x: Int, y: Int): Int
    {
      if (x < 0 ||
          y < 0 ||
          x >= mark.length ||
          y >= mark[0].length)
        return -1;
      return mark[x][y];
    }

// re-derive rooms and doors from the saved tile grid, for an area generated before this file
// recorded every structure's.
//
// generate() used to null state.rooms/doors after the main building and makeDoors reassigned rather
// than appended, so a saved facility describes its SIDE building only and the hangar contributes
// nothing. that record is persisted, and the cell grid is persisted verbatim and never regenerated,
// so a fixed generator alone would leave every already-visited facility partial forever. rooms are
// read by the 3D ceiling-light pass, by AreaView's room reveal and by three cult missions, so the
// repair is worth more than the renderer.
//
// it does NOT touch a single tile and it keeps missionHints: the rects are recovered from the grid
// the generator already wrote, which is the same trick render.sewer.SewerModel and
// render.wild.WildModel use to avoid persisting anything at all
  public static function repairRooms(area: AreaGame)
    {
      var cells = area.getCells();
      var mark = [for (x in 0...area.width) [for (y in 0...area.height) -1]];
      var rooms: Array<_Room> = [];
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            if (!isRoomFloor(cells[x][y]) ||
                mark[x][y] >= 0)
              continue;
            var id = TEMP_BUILDING_ROOM_ID_START + rooms.length;
            var room: _Room = {
              id: id,
              x1: x,
              y1: y,
              x2: x,
              y2: y,
              w: 1,
              h: 1,
            };
            var stack = [ { x: x, y: y } ];
            mark[x][y] = id;
            while (stack.length > 0)
              {
                var c = stack.pop();
                if (c.x < room.x1)
                  room.x1 = c.x;
                if (c.x > room.x2)
                  room.x2 = c.x;
                if (c.y < room.y1)
                  room.y1 = c.y;
                if (c.y > room.y2)
                  room.y2 = c.y;
                for (i in 0...Const.dir4x.length)
                  {
                    var nx = c.x + Const.dir4x[i];
                    var ny = c.y + Const.dir4y[i];
                    if (roomAt(mark, nx, ny) != -1 ||
                        !isRoomFloor(cells[nx][ny]))
                      continue;
                    mark[nx][ny] = id;
                    stack.push({ x: nx, y: ny });
                  }
              }
            room.w = room.x2 - room.x1 + 1;
            room.h = room.y2 - room.y1 + 1;
            rooms.push(room);
          }
      // a complete record already describes at least as many rooms as the grid holds. comparing
      // COUNTS rather than coverage is what makes this cheap and safe to run on every entry: a
      // record written by the fixed generator can only ever match or exceed the derivation, and the
      // partial ones it exists for are short by a whole building
      if (area.generatorInfo != null &&
          area.generatorInfo.rooms != null &&
          area.generatorInfo.rooms.length >= rooms.length)
        return;

      // doors link the rooms either side of them. a front or side door has a room on one side only
      // and the outdoors on the other, which is roomID2 0 — the same value the generator writes for
      // a door opening onto a corridor
      var doors: Array<_Door> = [];
      for (o in area.getObjects())
        {
          if (o.type != 'door')
            continue;
          var a = roomAt(mark, o.x - 1, o.y);
          var b = roomAt(mark, o.x + 1, o.y);
          var dir = DIR_RIGHT;
          if (a < 0 &&
              b < 0)
            {
              a = roomAt(mark, o.x, o.y - 1);
              b = roomAt(mark, o.x, o.y + 1);
              dir = DIR_DOWN;
            }
          if (a < 0 &&
              b < 0)
            continue;
          doors.push({
            x: o.x,
            y: o.y,
            dir: dir,
            roomID1: (a >= 0 ? a : b),
            roomID2: (a >= 0 && b >= 0 ? b : 0),
            skip: false,
          });
        }
      trace('repaired facility generatorInfo: ' + rooms.length + ' rooms, ' +
        doors.length + ' doors');
      area.generatorInfo = {
        rooms: rooms,
        doors: doors,
        missionHints: (area.generatorInfo != null ? area.generatorInfo.missionHints : null),
      };
    }

// replace all temp tiles into final ones
  function finalizeTiles(state: _FacilityState)
    {
      var area = state.area;
      var cells = area.getCells();
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tileID = cells[x][y];
            // spawn doors
            if (tileID == TEMP_BUILDING_FRONT_DOOR)
              {
                area.addDoor(x, y, Const.FRAME_DOOR_DOUBLE,
                  Const.FRAME_DOOR_DOUBLE_OPEN);
              }
            else if (tileID == TEMP_BUILDING_SIDE_DOOR)
              {
                area.addDoor(x, y, Const.FRAME_DOOR_GLASS,
                  Const.FRAME_DOOR_GLASS_OPEN);
              }
            else if (tileID == TEMP_BUILDING_INNER_DOOR)
              {
                // a door into a PRIVATE room takes the solid leaf that blocks sight. read off the
                // floor on the far side of the opening and off nothing else, the same way the whole
                // theme travels: generateRoomContents has already painted those tiles final by here
                var priv = opensOnPrivateRoom(cells, x, y);
                area.addDoor(x, y,
                  (priv ? Const.FRAME_DOOR_PRIVATE : Const.FRAME_DOOR_CABINET),
                  (priv ? Const.FRAME_DOOR_PRIVATE_OPEN : Const.FRAME_DOOR_CABINET_OPEN));
              }
            else if (tileID == TEMP_HANGAR_SIDE_DOOR)
              {
                area.addDoor(x, y, Const.FRAME_DOOR_METAL,
                  Const.FRAME_DOOR_METAL_OPEN);
              }
            // spawn vent object
            else if (tileID == TEMP_BUILDING_VENT)
              {
                area.add('vent', x, y);
              }
            // pick which tree this one is. WHICH cells are planted was decided by generatePark, so
            // all that is left here is the image — the bushes and the benches take one tile each
            // and go through finalTiles like everything else.
            //
            // TWO of the four, and they are +0 and +2: the other two are dead wood and a maintained
            // institutional park has none. +3 is the dead snag outright, and +1 draws
            // wild/tree-broadleaf, a BARE broadleaf with thick limbs and no foliage, which reads as
            // a dead tree whatever the wilderness files it under. Std.random(2) * 2 deals the two
            // that are in leaf. render.facility.FacilityGround folds the other two on the render
            // side as well, which is what covers areas generated before this line
            else if (tileID == TEMP_GRASS_TREE)
              {
                cells[x][y] = Const.TILE_TREE1 + Std.random(2) * 2;
                continue;
              }

            //if (tileID >= Const.OFFSET_ROW8)
            if (tileID >= Const.OFFSET_CHEM_LAB)
              continue;
/*
            if (tileID >= TEMP_BUILDING_ROOM_ID_START)
              tileID = Const.TILE_FLOOR_TILE;*/
            else tileID = finalTiles[tileID];

            cells[x][y] = tileID;
          }
    }

  static var finalTiles: Map<Int, Int>;

  static var ROOM_SIZE = 7; // 6 + 1 wall
  static var BIG_TABLE_DOOR_CLEARANCE = 3;
  // the two room templates besides the laboratory, written into _Room.role. a null role is a lab
  static var ROLE_CABINET = 'cabinet';
  static var ROLE_TOILET = 'toilet';
  // a floor tile's unwalkable twin sits exactly one tileset row below it (Const.OFFSET_ROW12 ->
  // OFFSET_ROW13), which is how game.CorpAreaGenerator addresses the pair too
  static var UNWALKABLE_TILE_OFFSET = 16;
  // how many cubicles one washroom may rank out in total, across every wall it builds on. a room is
  // at most 7x7 here, so two full walls would deal 14 and the place would read as a cell block
  static var TOILET_STALL_MAX = 8;
  // and how many wall fittings a researcher's office gets, placed outright rather than rolled: the
  // leftover-cell route in makeWindows only fires where a desk could not go, which on a small office
  // is often nowhere at all
  static var OFFICE_FITTING_MIN = 1;
  static var OFFICE_FITTING_MAX = 3;
  // how many of a room's bench cells clearTableSpots keeps bare, so a clue always has a legal spot.
  // THREE and not one: render.facility.FacilitySink takes a free edge cell of every bench block in the
  // room for its basin, and the clue's own activation range then wants the remaining two not to be the
  // same corner of the same run
  static var TABLE_CLEAR_MIN = 3;
  // the park: how wide its path is, how far apart the benches down it sit, how far apart the clump
  // centres are laid, and how far one clump reaches (both in cells, the second Manhattan). the step
  // is what sets DENSITY — clump count goes as its inverse square, so 6 -> 4 is 2.25x the centres
  static var PARK_PATH_W = 2;
  static var PARK_BENCH_SPACING = 5;
  static var PARK_CLUMP_STEP = 4;
  static var PARK_CLUMP_R = 3;
  // one shrub every this many cells along the park's outer edge, under the railing
  static var PARK_EDGE_BUSH_SPACING = 3;
  // cells of open lot left between the hangar and the nearest building's pavement apron. the hangar
  // is the one structure with no apron of its own, and its wall is a blank storey-and-a-half face:
  // at the game's camera pitch that face SILHOUETTES the cell in front of it, so a gap of two read
  // as one on screen and the yard between the lab and the hangar looked like a slot
  static var HANGAR_GAP = 3;
  static var TEMP_ROAD = 0;
  static var TEMP_WALKWAY = 1;
  static var TEMP_ALLEY = 2;
  static var TEMP_GRASS = 3;
  static var TEMP_CONCRETE = 4;
  static var TEMP_GRASS_TREE = 5;
  static var TEMP_GRASS_BUSH = 6;
  static var TEMP_GRASS_BENCH = 7;
  // first building tile!
  static var TEMP_BUILDING_WALL = 10;
  static var TEMP_BUILDING_ROOM = 11;
  static var TEMP_BUILDING_CORRIDOR = 12;
  static var TEMP_BUILDING_FRONT_DOOR = 13;
  static var TEMP_BUILDING_SIDE_DOOR = 14;
  static var TEMP_BUILDING_INNER_WALL = 15;
  static var TEMP_BUILDING_ROOM_MARKED = 16;
  static var TEMP_BUILDING_INNER_DOOR = 17;
  static var TEMP_BUILDING_WINDOW = 18;
  static var TEMP_BUILDING_WINDOWH1 = 19;
  static var TEMP_BUILDING_WINDOWH2 = 20;
  static var TEMP_BUILDING_WINDOWH3 = 21;
  static var TEMP_BUILDING_WINDOWV1 = 22;
  static var TEMP_BUILDING_WINDOWV2 = 23;
  static var TEMP_BUILDING_WINDOWV3 = 24;
  static var TEMP_BUILDING_TABLE = 25;
  static var TEMP_HANGAR_DOOR = 26;
  static var TEMP_HANGAR_SIDE_DOOR = 27;
  static var TEMP_BUILDING_VENT = 18;
  // the washroom's light well. its own temp id and not one of the six window ones, because it is not
  // part of a RUN: each cell is a separate opening and the renderer maps one image across each
  static var TEMP_BUILDING_WINDOW_HIGH = 28;

  static var TEMP_BUILDING_ROOM_ID_START = 100;
  static var mapTempTiles = [
    '0', '1', '2', '%', '%', 't', 'b', 'B', '%', '%',
    '#', 'r', '.', 'x', '+', '*', '8', 'X', 'w',
    '<', '-', '>', '^', '|', 'v', '_', 'Y', 'Z', '=',
  ];
}

typedef _FacilityState = {
  // the grid being written, the seeded rng and the spawn list — NOT a game.AreaGame. Generation
  // reaches nothing else, which is what lets tools/genrun.mjs run this file with no Game behind it;
  // gen.GenSpawner turns the spawns into real objects afterwards. See docs/area-gen.md.
  var area: GenCtx;
  var mainRoadNorth: Bool;

  // temp state: the CURRENT structure's rooms and doors. every pass inside generateBuilding
  // (fixDoors, makeDoorToCorridor, makeWindows, generateRoomContents) works on these and must not
  // see a previous structure's, so they are reset per structure and folded into the two lists below
  var rooms: Array<_Room>;
  var doors: Array<_Door>;

  // every structure's rooms and doors, in generation order. this is what lands in
  // area.generatorInfo: the 3D layer places a ceiling light per room and fades a roof per structure,
  // and the missions and AreaView's room-reveal read the same record, so it has to describe the
  // WHOLE area rather than whichever building happened to be generated last
  var allRooms: Array<_Room>;
  var allDoors: Array<_Door>;
  // room ids are unique across the whole area, never restarted per structure: _Door.roomID1/2 and
  // _GeneratorInfo.getRoom() key on them, and they are also written into the cell grid as marks
  var nextRoomID: Int;
}
