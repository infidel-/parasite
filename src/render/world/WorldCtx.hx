package render.world;

import citygen.CityModel.Building;
import citygen.CityModel.Tile;

// shared state for one city build, set by World.build() and read by every world
// sub-builder. buildings/tiles are read by nearly every pass; the *Seen maps are
// written by one pass each (bands/doors/windows) and read only by the checklist.
class WorldCtx {
  // all buildings in the current city
  public static var buildings:Array<Building>;
  // the tile grid of the current city (row-major)
  public static var tiles:Array<Array<Tile>>;
  // citygen seed of the current city (-1 = seedless reconstruction) — for check traces
  public static var seed:Int = -1;

  // post-gen checklist: presence of each feature per building, recorded AT the render
  // chokepoints (so the check verifies what actually rendered, not a re-derivation)
  public static var winSeen:haxe.ds.ObjectMap<Building, Bool>;
  public static var doorSeen:haxe.ds.ObjectMap<Building, Bool>;
  public static var bandSeen:haxe.ds.ObjectMap<Building, Bool>;
  public static var noBackDoor:Array<Building>; // had an open back wall but no side door fit (clearance)

// ground surface height at grid cell (col,row): walkway tops sit a curb above road/alley, so
// actors/decals/the ring rest on this instead of sinking through the raised pavement
  public static function floorY(col:Int, row:Int):Float
    {
      if (row < 0 ||
          col < 0 ||
          row >= tiles.length ||
          col >= tiles[row].length)
        return 0.0;
      return (tiles[row][col] == Tile.Walkway || beveled(col, row)) ? render.RenderConfig.CURB_H : 0.0;
    }

// is (col,row) a walkway-corner bevel: a Road cell with exactly one convex walkway corner
// (two adjacent walkway edge-neighbours), which render.world.Ground paves with a raised
// half-tile of walkway. mirrors Ground.bevelAt — keep the rule in sync
  static function beveled(col:Int, row:Int):Bool
    {
      if (tiles[row][col] != Tile.Road)
        return false;
      var n = 0;
      if (isWk(col + 1, row) && isWk(col, row + 1)) n++; // SE
      if (isWk(col - 1, row) && isWk(col, row + 1)) n++; // SW
      if (isWk(col + 1, row) && isWk(col, row - 1)) n++; // NE
      if (isWk(col - 1, row) && isWk(col, row - 1)) n++; // NW
      return n == 1;
    }

// walkway tile at (col,row), bounds-safe
  static inline function isWk(col:Int, row:Int):Bool
    return row >= 0 &&
      col >= 0 &&
      row < tiles.length &&
      col < tiles[row].length &&
      tiles[row][col] == Tile.Walkway;
}
