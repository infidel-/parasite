package render.sewer;

import citygen.CityModel.Lamp;
import game.AreaGame;
import tiles.Sewers;

// what the 3D tunnel builder needs, derived from an area's SAVED cell grid. there is no seeded
// sewer generator: `Sewers.TILE_FLOOR` in game.AreaGame's persisted cells IS the layout, so this
// works on every existing save and costs nothing to store. grids are [row][col] (the render
// convention, transposed from the game's [x][y]) so they index like citygen's tile grid
typedef Sewer = {
  // area width in cells
  w:Int,
  // area height in cells
  h:Int,
  // [row][col]: true where the cell is walkable sewer floor
  floor:Array<Array<Bool>>,
  // [row][col]: inside a generator room rect (rooms are drier and less littered than the tunnels)
  room:Array<Array<Bool>>,
  // corridor-node and exit light positions (dir is unused underground, always 0)
  lamps:Array<Lamp>,
};

class SewerModel
{
// build the model from an area's saved cells + generator rooms
  public static function fromArea(area:AreaGame):Sewer
    {
      var m = blank(area.width, area.height);
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var t = area.getCellType(x, y);
            m.floor[y][x] = (t == Sewers.TILE_FLOOR ||
              t == Sewers.TILE_FLOOR_ALT);
          }
      // room cells are excluded from the corridor-node light scan
      var room = m.room;
      if (area.generatorInfo != null &&
          area.generatorInfo.rooms != null)
        for (r in area.generatorInfo.rooms)
          for (y in r.y1...r.y2 + 1)
            for (x in r.x1...r.x2 + 1)
              if (inside(m, x, y))
                room[y][x] = true;
      // doors break a corridor run, same as the 2D lighting pass treats them
      var door = [for (_ in 0...area.height) [for (_ in 0...area.width) false]];
      for (o in area.getObjects())
        if (o.type == 'door' &&
            inside(m, o.x, o.y))
          door[o.y][o.x] = true;

      addNodeLamps(m, room, door);
      addExitLamps(m, area);
      return m;
    }

// an empty model of the given size (also the base for demo())
  static function blank(w:Int, h:Int):Sewer
    {
      return {
        w: w,
        h: h,
        floor: [for (_ in 0...h) [for (_ in 0...w) false]],
        room: [for (_ in 0...h) [for (_ in 0...w) false]],
        lamps: [],
      };
    }

// is (col,row) inside the grid?
  static inline function inside(m:Sewer, col:Int, row:Int):Bool
    {
      return col >= 0 &&
        row >= 0 &&
        col < m.w &&
        row < m.h;
    }

// xorshift32 avalanche over a cell hash, for every deterministic placement decision down here.
// NOT optional dressing: the bare `(col * A) ^ (row * B)` footprint hash DEGENERATES on the grid's
// first row and column, where one term is zero and the whole thing collapses to an arithmetic
// sequence. at row 0 the ledge hash is exactly col * 40503, and 40503 % 100 == 3, so a "22% of
// cells" test placed a prop on cols 0-7, then 34-40, then 67-73 — measured runs of EIGHT, repeating
// every 33 cells. row 0 and col 0 are the always-solid area border, i.e. the ledge band across the
// top of the screen, so the worst case sat exactly where the player looks. mixing scatters it
// (cols 1,3,5,12,16,18,23,31 for the same line).
//
// shifts and xors only, so it is exact in Haxe/JS Int arithmetic with no Math.imul; the golden-ratio
// xor removes the h == 0 fixed point that would otherwise make cell (0,0) always place
  public static inline function mix(h:Int):Int
    {
      var x = h ^ 0x9E3779B9;
      x ^= x << 13;
      x ^= x >>> 17;
      x ^= x << 5;
      return x & 0x7fffffff;
    }

// floor lookup, bounds-safe
  public static inline function isFloor(m:Sewer, col:Int, row:Int):Bool
    {
      return inside(m, col, row) && m.floor[row][col];
    }

// NO sludge channel. a `channel` grid used to mark the centre line of every 3-wide tunnel and
// SewerGeom laid a muck tile there instead of walkway; the gutter is off, so the grid, the per-build
// O(w*h*9) pass that filled it and the two rules that read it are gone with it. if it comes back,
// note what the pass had to learn: a full floor 8-neighbourhood alone floods a hall with sludge
// (true of every interior cell of any open space), so it also required the run to be exactly 3 cells
// wide across one axis, and room cells were excluded because a room floor stays dry

// lights at 3x3 corridor corners and intersections — the same placement rule the 2D atmosphere
// lighting uses (lighting.SewerAreaLighting.addSewerCorridorLayoutSources), so a tunnel lights up
// in the same places it always did
  static function addNodeLamps(m:Sewer, room:Array<Array<Bool>>, door:Array<Array<Bool>>):Void
    {
      inline function corridor(col:Int, row:Int):Bool
        {
          return isFloor(m, col, row) &&
            !room[row][col] &&
            !door[row][col];
        }
      // a 3x3 block of pure corridor floor
      function block(col:Int, row:Int):Bool
        {
          for (dr in 0...3)
            for (dc in 0...3)
              if (!inside(m, col + dc, row + dr) ||
                  !corridor(col + dc, row + dr))
                return false;
          return true;
        }
      // does a 3-tile branch continue past the node, horizontally / vertically?
      function hBranch(col:Int, row:Int):Bool
        {
          return inside(m, col, row) &&
            corridor(col, row) &&
            corridor(col + 1, row) &&
            corridor(col + 2, row);
        }
      function vBranch(col:Int, row:Int):Bool
        {
          return inside(m, col, row) &&
            corridor(col, row) &&
            corridor(col, row + 1) &&
            corridor(col, row + 2);
        }
      for (row in 0...m.h - 2)
        for (col in 0...m.w - 2)
          {
            if (!block(col, row))
              continue;
            var north = hBranch(col, row - 1);
            var south = hBranch(col, row + 3);
            var west = vBranch(col - 1, row);
            var east = vBranch(col + 3, row);
            var n = 0;
            if (north) n++;
            if (south) n++;
            if (west) n++;
            if (east) n++;
            var corner = (n == 2 &&
              (north || south) &&
              (west || east));
            if (!corner &&
                n < 3)
              continue;
            m.lamps.push({ col: col + 1, row: row + 1, dir: 0 });
          }
    }

// one light over every sewer/habitat exit, as the 2D pass does
  static function addExitLamps(m:Sewer, area:AreaGame):Void
    {
      for (o in area.getObjects())
        if ((o.type == 'sewer_exit' ||
             o.type == 'habitat_exit') &&
            isFloor(m, o.x, o.y))
          m.lamps.push({ col: o.x, row: o.y, dir: 0 });
    }

// a throwaway tunnel cross for the boot shader pre-warm (see render.View.warmup): the real
// builders on fake data, so the compiled programs match what a real sewer entry needs
  public static function demo():Sewer
    {
      var m = blank(21, 21);
      for (i in 0...21)
        for (d in -1...2)
          {
            m.floor[10 + d][i] = true;
            m.floor[i][10 + d] = true;
          }
      m.lamps.push({ col: 10, row: 10, dir: 0 });
      return m;
    }
}
