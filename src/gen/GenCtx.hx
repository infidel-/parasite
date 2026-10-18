// the area, as generation sees it
//
// a cell grid, a seeded rng and a list of objects to spawn — and deliberately nothing else. This is
// the whole surface game.FacilityAreaGenerator was using game.AreaGame for, which turned out to be
// `getCells`, `width`, `height`, `id` and four object calls, and swapping the type underneath is
// what lets the same generator run under tools/genrun.mjs with no Game, no renderer and no DOM.
//
// THE MEMBER NAMES MATCH AreaGame's ON PURPOSE — getCells(), width, height, hasObjectAt,
// getObjectsAt, removeObject. That is not laziness about the diff: those names are what generation
// code has always called them, they are correct for what this holds, and keeping them meant the
// decoupling changed the object-construction sites and nothing else. A reader of a generator pass
// does not have to know which of the two they are looking at, because for that pass there is no
// difference.
//
// what is NOT here is the other half of AreaGame — AI, pathing, lighting, saving, visibility. None
// of it is reachable during generation, and none of it can be accidentally reached now.

package gen;

class GenCtx
{
  public var width: Int;
  public var height: Int;
  // the tile grid, [x][y], holding TEMP_* ids during generation and Const.TILE_* after finalize.
  // handed out raw by getCells() because every pass indexes it directly and a bounds-checked
  // accessor in that inner loop is not free
  public var cells: Array<Array<Int>>;
  // the seeded stream. every roll in generation comes from here so a layout can be replayed
  public var rng: Void -> Float;
  // and what it was seeded from, for the trace that makes a bad layout reproducible
  public var seed: Int;
  // the block tree, from the root node down. in-memory only, never persisted
  public var root: _GenNode;
  // objects to build once generation is done. see _GenSpawn for why these are intents
  public var spawns: Array<_GenSpawn>;

  public function new(w: Int, h: Int, vseed: Int, ?vcells: Array<Array<Int>>)
    {
      width = w;
      height = h;
      seed = vseed;
      rng = Rng.mulberry32(vseed);
      // the live path hands in game.AreaGame's own grid so the generator writes straight into it;
      // the headless path has none and gets a fresh one
      cells = (vcells != null ? vcells : [for (x in 0...w) [for (y in 0...h) 0]]);
      spawns = [];
      root = GenTree.root('area', 0, 0, w - 1, h - 1);
    }

  public inline function getCells(): Array<Array<Int>>
    return cells;

// read a cell, or -1 outside the grid. matches AreaGame.getCellType, for the passes that probe
// past an edge rather than checking first
  public inline function getCellType(x: Int, y: Int): Int
    {
      if (x < 0 ||
          y < 0 ||
          x >= width ||
          y >= height)
        return -1;
      return cells[x][y];
    }

  public inline function setCellType(x: Int, y: Int, t: Int)
    {
      if (x >= 0 &&
          y >= 0 &&
          x < width &&
          y < height)
        cells[x][y] = t;
    }

// --- rolls ---

// 0...n-1, off the seeded stream. NAMED AFTER Std.random AND NOT rng() ON PURPOSE: every roll in
// generation used to be a Std.random call, and a drop-in spelling is what let them be swapped
// without also re-deriving what each expression meant. A pass holds a ctx already, so
// `area.random(100) < 50` is the same line it always was with a stream behind it
  public inline function random(n: Int): Int
    return Std.int(rng() * n);

// a percentage roll, for the `Std.random(100) < pct` this file is full of
  public inline function chance(pct: Int): Bool
    return Std.int(rng() * 100) < pct;

// --- spawns ---

// record one plain object: a vent, a sewer hatch, a floor drain. nothing about it varies but where
// it stands
  public function add(type: String, x: Int, y: Int): _GenSpawn
    {
      if (hasObjectAt(x, y))
        return null;
      var s: _GenSpawn = {
        type: type,
        x: x,
        y: y,
      };
      spawns.push(s);
      return s;
    }

// record a decoration drawing one entities64 cell. the frame is its identity — see _GenSpawn
  public function addDecoration(x: Int, y: Int, row: Int, col: Int): _GenSpawn
    {
      if (hasObjectAt(x, y))
        return null;
      var s: _GenSpawn = {
        type: 'decoration',
        x: x,
        y: y,
        row: row,
        col: col,
      };
      spawns.push(s);
      return s;
    }

// record a door and the frame it draws when open. both are on Const.ROW_DOORS, so only the columns
// differ and the row is not carried
  public function addDoor(x: Int, y: Int, col: Int, colOpen: Int): _GenSpawn
    {
      var s: _GenSpawn = {
        type: 'door',
        x: x,
        y: y,
        row: Const.ROW_DOORS,
        col: col,
        col2: colOpen,
      };
      spawns.push(s);
      return s;
    }

// ONE OBJECT PER CELL, refused here rather than trusted to the callers.
//
// every placement pass already asks hasObjectAt before taking a cell, and that was not enough:
// roomWallRuns builds one run per WALL and a room's corner cell belongs to two of them, so
// roomCabinet dealing its first fitting to the longest run and its second to the next could put
// both on the same corner. The runs are built before either is placed, so neither pass could see
// the other coming. Measured by the oracle at roughly one stacked decoration per compound, on
// every seed, for as long as this file has existed — two props in one cell, one of them drawn
// inside the other.
//
// the invariant belongs here because every consumer already assumes it: AreaGame.initSpawnPoints
// calls a bench cell free when nothing stands on it, and FacilityModel.deco holds ONE fitting kind
// per cell. A caller that wanted the cell gets null back and carries on to the next one
  public function hasObjectAt(x: Int, y: Int): Bool
    {
      for (s in spawns)
        if (s.x == x &&
            s.y == y)
          return true;
      return false;
    }

  public function getObjectsAt(x: Int, y: Int): Array<_GenSpawn>
    {
      return [for (s in spawns) if (s.x == x && s.y == y) s];
    }

// take one back off. game.FacilityAreaGenerator.clearTableSpots is the only caller: it un-decorates
// bench cells until the room has enough bare ones left for a clue to spawn on
  public function removeObject(s: _GenSpawn)
    spawns.remove(s);

  public function countSpawns(type: String): Int
    {
      var n = 0;
      for (s in spawns)
        if (s.type == type)
          n++;
      return n;
    }
}
