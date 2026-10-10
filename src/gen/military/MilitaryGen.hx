// military base generation, the Game-free half
//
// build() is the real entry point and the one tools/genrun.mjs calls. Like gen.facility.FacilityGen
// it must never reach for a game.Game: it writes into a gen.GenCtx and records spawn intents, and
// game.MilitaryAreaGenerator is the adapter that drains them. See docs/area-gen.md.
//
// A base is a fenced rect inside a WILD MARGIN. The road runs past it along one edge of the area, and
// the gate is a mouth through the fence beside it, shaped exactly like the lab compound's so
// game.AreaGame.gate() and render.facility.FacilityEntry find the booth and the barrier with no
// edit. Inside the fence the ground is split and dealt like a compound's; outside it is grass and the
// terrain band's scatter, which is where the player arrives and from where they can leave.

package gen.military;

import Const;
import game.AreaGenerator._WildMix;
import game.AreaGenerator.drawBlock;
import gen.GenCtx;
import gen.GenTree;
import gen.blocks.FacilityBlocks;
import gen.blocks.MilitaryBlocks;
import gen.blocks.RoadBlock;
import gen.facility.FacilityConnect;
import gen.facility.FacilityGen;
import gen.facility.FacilityRooms;
import gen.facility.FacilityTemp.*;
import gen.facility._FacilityState;

class MilitaryGen
{
  // cells of wild margin between the fence and the area edge, on the three sides the road is not on
  public static inline var MARGIN = 16;
  // the verge between the road and the fence on the gate side. ONE row and not the compound's two:
  // the fence line itself is the mouth's second row, so the hole through verge and fence together is
  // the compound's 4x2 mouth and gate() reads it unchanged
  public static inline var VERGE = 1;
  // clear lot kept inside the fence before a plot starts: the compound's EDGE_MARGIN on three sides,
  // and one more on the gate side, so the booth's row stays open lot past a building's 2-cell apron
  static inline var EDGE = 2;
  static inline var GATE_EDGE = 3;
  // the corner watchtower, on a side. it fits the EDGE lot inside the ring, so it never meets a plot
  public static inline var TOWER = 2;
  // how far a torn fence panel stays from a corner
  static inline var BREACH_CORNER = 4;
  // the tent camp's tent on each axis, and the lane between tents
  static inline var TENT_W = 2;
  static inline var TENT_H = 3;
  static inline var TENT_LANE = 2;
  // how often a container slot in the depot actually holds one
  static inline var CONTAINER_PCT = 85;
  // how often a motor pool's next vehicle is another tank rather than a humvee, and how many it
  // parks at most: a plot full of them read as a vehicle lot, not a base's motor pool
  static inline var TANK_PCT = 30;
  static inline var VEHICLES_MAX = 5;
  // the margin's least scatter density: the plains' own 0.025 left the margin reading as bare grass
  static inline var MARGIN_DENSITY_MIN = 0.06;

// generate a whole base into a context. `mix` and `depth` are the terrain band's scatter and how
// deep into the band the area sits (game.AreaGenerator.wildMix, map.Terrain.depthAt), passed in
// because reading them needs the region and generation must not
  public static function build(ctx: GenCtx, mix: _WildMix, depth: Float): _FacilityState
    {
      var state: _FacilityState = {
        area: ctx,
        mainRoadNorth: ctx.chance(50),
        military: true,
        rooms: null,
        doors: null,
        allRooms: [],
        allDoors: [],
        nextRoomID: TEMP_BUILDING_ROOM_ID_START,
      }
      var cells = ctx.getCells();
      drawBlock(cells, 0, 0, ctx.width, ctx.height, TEMP_ALLEY);

      // the plots, split out of the ground inside the fence and walked like a compound's
      var f = fence(ctx.width, ctx.height, state.mainRoadNorth);
      var north = state.mainRoadNorth;
      for (b in MilitaryBlocks.plan(f.x1 + 1 + EDGE,
          f.y1 + 1 + (north ? GATE_EDGE : EDGE),
          f.x2 - 1 - EDGE,
          f.y2 - 1 - (north ? EDGE : GATE_EDGE), north, ctx.rng))
        ctx.root.children.push(b);
      GenTree.build(ctx.root, function(n) fill(state, n));
      FacilityGen.finalizeTiles(state);
      FacilityRooms.clearFittings(state);

      // everything from here on writes FINAL ids, past finalizeTiles: the wild tiles share their
      // numbers with the TEMP_* alphabet and would be rewritten by it
      perimeter(state, f);
      road(state, f);
      margin(state, f, mix, depth);
      gate(state, f);
      FacilityConnect.connectRooms(state);
      return state;
    }

// the fence ring's rect, on the cells the chain-link stands on
  public static function fence(w: Int, h: Int, gateNorth: Bool): _Rect
    {
      var band = FacilityBlocks.ROAD_W + VERGE;
      return {
        x1: MARGIN,
        y1: (gateNorth ? band : MARGIN),
        x2: w - 1 - MARGIN,
        y2: (gateNorth ? h - 1 - MARGIN : h - 1 - band),
      };
    }

// the fence ring's rect, RE-DERIVED from a finished grid: the bounding box of every fence, torn
// fence and tower cell, or null on a grid with none (a base generated before the fence existed).
// game.AreaGame reads the outside of the base off this, so a save carries nothing extra for it
  public static function fenceOf(cells: Array<Array<Int>>, w: Int, h: Int): _Rect
    {
      var r: _Rect = null;
      for (x in 0...w)
        for (y in 0...h)
          {
            var t = cells[x][y];
            if (t != Const.TILE_MIL_FENCE &&
                t != Const.TILE_MIL_FENCE_TORN &&
                t != Const.TILE_MIL_TOWER)
              continue;
            if (r == null)
              r = {
                x1: x,
                y1: y,
                x2: x,
                y2: y,
              };
            if (x < r.x1)
              r.x1 = x;
            if (x > r.x2)
              r.x2 = x;
            if (y < r.y1)
              r.y1 = y;
            if (y > r.y2)
              r.y2 = y;
          }
      return r;
    }

// build one node of the tree. the two structures a base shares with the lab compound go to its own
// filler; the rest are the base's
  static function fill(state: _FacilityState, node: _GenNode)
    {
      switch (node.kind)
        {
          case FacilityBlocks.BUILDING, FacilityBlocks.HANGAR:
            FacilityGen.fill(state, node);
          case MilitaryBlocks.CAMP:
            camp(state, node);
          case MilitaryBlocks.DEPOT:
            depot(state, node);
          case MilitaryBlocks.MOTORPOOL:
            motorpool(state, node);
          case MilitaryBlocks.HELIPAD:
            helipad(state, node);
          default:
        }
    }

// a grid of tents, a lane between each, one cell in from the plot's edge
  static function camp(state: _FacilityState, node: _GenNode)
    {
      var cells = state.area.getCells();
      var y = node.y1 + 1;
      while (y + TENT_H - 1 <= node.y2 - 1)
        {
          var x = node.x1 + 1;
          while (x + TENT_W - 1 <= node.x2 - 1)
            {
              drawBlock(cells, x, y, TENT_W, TENT_H, Const.TILE_MIL_TENT);
              x += TENT_W + TENT_LANE;
            }
          y += TENT_H + TENT_LANE;
        }
    }

// rows of shipping containers, two deep with a lane between each pair of rows and a cell between
// two containers end to end, so the depot can be walked through
  static function depot(state: _FacilityState, node: _GenNode)
    {
      var area = state.area;
      var cells = area.getCells();
      var len = Const.MIL_CONTAINER_LEN;
      var y = node.y1 + 1;
      while (y <= node.y2 - 1)
        {
          for (k in 0...2)
            {
              if (y + k > node.y2 - 1)
                break;
              var x = node.x1 + 1;
              while (x + len - 1 <= node.x2 - 1)
                {
                  if (area.chance(CONTAINER_PCT))
                    {
                      drawBlock(cells, x, y + k, len, 1, Const.TILE_MIL_CONTAINER);
                      cells[x][y + k] = Const.TILE_MIL_CONTAINER_ORIGIN;
                    }
                  x += len + 1;
                }
            }
          y += 4;
        }
    }

// a row of parked vehicles, a tank first and then mostly humvees, a cell between each, up to
// VEHICLES_MAX; a second row behind the first where the plot is deep enough
  static function motorpool(state: _FacilityState, node: _GenNode)
    {
      var area = state.area;
      var x = node.x1 + 1;
      var y = node.y1 + 1;
      var first = true;
      for (i in 0...VEHICLES_MAX)
        {
          var tank = (first || area.chance(TANK_PCT));
          var size = (tank ? Const.MIL_TANK_SIZE : Const.MIL_HUMVEE_SIZE);
          if (x + size[0] - 1 > node.x2 - 1)
            {
              // the row is full: start the next one behind it, two cells of lane further on
              x = node.x1 + 1;
              y += Const.MIL_TANK_SIZE[1] + 2;
            }
          if (y + size[1] - 1 > node.y2 - 1 ||
              x + size[0] - 1 > node.x2 - 1)
            break;
          vehicle(area, (tank ? Const.TILE_MIL_TANK : Const.TILE_MIL_HUMVEE), size, x, y);
          x += size[0] + 1;
          first = false;
        }
    }

// the helipad: a square of pad concrete, centred, with the helicopter on it
  static function helipad(state: _FacilityState, node: _GenNode)
    {
      var area = state.area;
      var cells = area.getCells();
      var w = GenTree.width(node);
      var h = GenTree.height(node);
      var side = Std.int(Math.min(8, Math.min(w, h) - 2));
      var px = node.x1 + Std.int((w - side) / 2);
      var py = node.y1 + Std.int((h - side) / 2);
      drawBlock(cells, px, py, side, side, Const.TILE_MIL_PAD);
      var size = Const.MIL_HELI_SIZE;
      vehicle(area, Const.TILE_MIL_HELI, size, px + Std.int((side - size[0]) / 2),
        py + Std.int((side - size[1]) / 2));
    }

// stamp one vehicle's footprint, its origin (top-left) cell naming the model
  public static function vehicle(area: GenCtx, origin: Int, size: Array<Int>, x: Int, y: Int)
    {
      drawBlock(area.getCells(), x, y, size[0], size[1], Const.TILE_MIL_VEHICLE);
      area.getCells()[x][y] = origin;
    }

// the chain-link ring, a watchtower inside each corner, and one or two torn panels on the three sides
// the gate is not on
  static function perimeter(state: _FacilityState, f: _Rect)
    {
      var area = state.area;
      var cells = area.getCells();
      for (x in f.x1...f.x2 + 1)
        {
          cells[x][f.y1] = Const.TILE_MIL_FENCE;
          cells[x][f.y2] = Const.TILE_MIL_FENCE;
        }
      for (y in f.y1...f.y2 + 1)
        {
          cells[f.x1][y] = Const.TILE_MIL_FENCE;
          cells[f.x2][y] = Const.TILE_MIL_FENCE;
        }
      // the towers stand just INSIDE each corner, on the clear lot EDGE keeps there, and the ring runs
      // unbroken round the corner behind them: a tower ON the corner left a gap either side of its
      // legs that read as a way through
      drawBlock(cells, f.x1 + 1, f.y1 + 1, TOWER, TOWER, Const.TILE_MIL_TOWER);
      drawBlock(cells, f.x2 - TOWER, f.y1 + 1, TOWER, TOWER, Const.TILE_MIL_TOWER);
      drawBlock(cells, f.x1 + 1, f.y2 - TOWER, TOWER, TOWER, Const.TILE_MIL_TOWER);
      drawBlock(cells, f.x2 - TOWER, f.y2 - TOWER, TOWER, TOWER, Const.TILE_MIL_TOWER);

      // the breaches. 0 west, 1 east, 2 the side away from the gate
      var sides = [ 0, 1, 2 ];
      var n = 1 + area.random(2);
      for (i in 0...n)
        {
          var side = sides.splice(area.random(sides.length), 1)[0];
          if (side == 2)
            {
              var x = f.x1 + BREACH_CORNER + area.random(f.x2 - f.x1 - BREACH_CORNER * 2);
              cells[x][(state.mainRoadNorth ? f.y2 : f.y1)] = Const.TILE_MIL_FENCE_TORN;
            }
          else
            {
              var y = f.y1 + BREACH_CORNER + area.random(f.y2 - f.y1 - BREACH_CORNER * 2);
              cells[(side == 0 ? f.x1 : f.x2)][y] = Const.TILE_MIL_FENCE_TORN;
            }
        }
    }

// the road past the base along the gate side's edge, and the verge between it and the fence
  static function road(state: _FacilityState, f: _Rect)
    {
      var area = state.area;
      var north = state.mainRoadNorth;
      drawBlock(area.getCells(), 0, (north ? 0 : area.height - FacilityBlocks.ROAD_W),
        area.width, FacilityBlocks.ROAD_W, Const.TILE_ROAD);
      drawBlock(area.getCells(), 0, vergeRow(state), area.width, VERGE, Const.TILE_WALKWAY);
    }

// the gate: the compound's 4x2 mouth, its outer row in the verge and its inner row the fence line,
// where the boom comes down. The cell past the boom's far end is the PEDESTRIAN gap, verge-paved,
// because a boom across a hole in a fence leaves nothing to walk round it by
  static function gate(state: _FacilityState, f: _Rect)
    {
      var area = state.area;
      var cells = area.getCells();
      var fenceY = (state.mainRoadNorth ? f.y1 : f.y2);
      // the mouth stays clear of the towers by BREACH_CORNER, booth and pedestrian gap included
      var span = f.x2 - f.x1 + 1 - BREACH_CORNER * 2 - RoadBlock.ENTRY_W - 2;
      var x0 = f.x1 + BREACH_CORNER + 1 + area.random(span);
      drawBlock(cells, x0, vergeRow(state), RoadBlock.ENTRY_W, 1, Const.TILE_ALLEY);
      drawBlock(cells, x0, fenceY, RoadBlock.ENTRY_W, 1, Const.TILE_ALLEY_UNWALKABLE);
      cells[x0 + RoadBlock.ENTRY_W][fenceY] = Const.TILE_WALKWAY;
      // jersey barriers on the pavement flanking the mouth, the pedestrian gap's own cell left open
      for (x in [ x0 - 2, x0 - 1, x0 + RoadBlock.ENTRY_W + 1, x0 + RoadBlock.ENTRY_W + 2 ])
        cells[x][vergeRow(state)] = Const.TILE_MIL_JERSEY;
    }

// the verge's row
  static inline function vergeRow(state: _FacilityState): Int
    {
      return (state.mainRoadNorth ? FacilityBlocks.ROAD_W :
        state.area.height - FacilityBlocks.ROAD_W - VERGE);
    }

// the wild margin outside the fence: grass, the band's large obstacles and its scatter. Nothing is
// planted on the road, the verge, the ring of cells along the fence (the patrol path, and the way to
// a breach) or within the highway's own two-cell verge of the road
  static function margin(state: _FacilityState, f: _Rect, mix: _WildMix, depth: Float)
    {
      var area = state.area;
      var cells = area.getCells();
      var spots = [];
      for (x in 0...area.width)
        for (y in 0...area.height)
          if (outside(f, x, y) &&
              cells[x][y] == Const.TILE_ALLEY)
            {
              cells[x][y] = Const.TILE_GRASS;
              spots.push(x * area.height + y);
            }
      var n = spots.length;
      var scale = 0.8 + 0.4 * depth;

      // the large obstacles first, while the margin is still bare grass
      if (mix.big >= 0)
        {
          var count = Math.round(mix.bigCount * scale * n / (area.width * area.height));
          for (i in 0...count)
            {
              var w = (mix.big == Const.TILE_ROCK_LARGE ? 2 : 2 + area.random(2));
              var h = (mix.big == Const.TILE_ROCK_LARGE ? 2 : 2 + area.random(2));
              for (t in 0...20)
                {
                  var x = 1 + area.random(area.width - w - 2);
                  var y = 1 + area.random(area.height - h - 2);
                  var ok = true;
                  for (dy in -1...h + 1)
                    for (dx in -1...w + 1)
                      if (!free(area, f, x + dx, y + dy))
                        ok = false;
                  if (!ok)
                    continue;
                  drawBlock(cells, x, y, w, h, mix.big);
                  break;
                }
            }
        }

      // then the single-cell scatter, one roll across tree / bush / rock as the wilderness does. Rolled
      // on the margin's own cells: a roll over the whole area lost every one that landed in the fence
      var stuff = Std.int(n * Math.max(mix.density, MARGIN_DENSITY_MIN) * scale);
      for (i in 0...stuff)
        {
          var spot = spots[area.random(n)];
          var x = Std.int(spot / area.height);
          var y = spot % area.height;
          if (!free(area, f, x, y))
            continue;
          var roll = area.random(100);
          var t = Const.TILE_BUSH;
          if (roll < mix.tree)
            t = Const.TILE_TREE1 + area.random(Const.TILE_BUSH - Const.TILE_TREE1);
          else if (roll >= mix.tree + mix.bush)
            t = Const.TILE_ROCK;
          cells[x][y] = t;
        }
    }

// is this cell outside the fence ring (the ring itself is not)?
  public static inline function outside(f: _Rect, x: Int, y: Int): Bool
    {
      return x < f.x1 ||
        x > f.x2 ||
        y < f.y1 ||
        y > f.y2;
    }

// may the margin plant something here: bare grass, off the ring of cells along the fence, and clear
// of the road by its verge
  static function free(area: GenCtx, f: _Rect, x: Int, y: Int): Bool
    {
      if (x < 0 ||
          y < 0 ||
          x >= area.width ||
          y >= area.height)
        return false;
      if (area.getCells()[x][y] != Const.TILE_GRASS)
        return false;
      if (x >= f.x1 - 1 &&
          x <= f.x2 + 1 &&
          y >= f.y1 - 1 &&
          y <= f.y2 + 1)
        return false;
      for (dy in -2...3)
        for (dx in -2...3)
          if (area.getCellType(x + dx, y + dy) == Const.TILE_ROAD)
            return false;
      return true;
    }
}

// a rect of cells, inclusive
typedef _Rect = {
  var x1: Int;
  var y1: Int;
  var x2: Int;
  var y2: Int;
}
