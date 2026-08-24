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
  // continuous ground relief under a WORLD point, for an area whose floor is not a tile grid. null in
  // the city (the tiles below answer, and a city floor steps per tile rather than rolling) and null in
  // the tunnels, which are flat; render.wild.WildArea points it at its own height field. this is the
  // ONE thing an area kind has to set to put every actor, decal, particle, shadow and cursor pick onto
  // a surface that is not y = 0, and it MUST be cleared by the area kinds that have no relief
  public static var ground:(Float, Float)->Float = null;
  // per-area render style (textures + facade behavior) for this build; DEFAULT = residential
  public static var style:AreaStyle;

  // post-gen checklist: presence of each feature per building, recorded AT the render
  // chokepoints (so the check verifies what actually rendered, not a re-derivation)
  public static var winSeen:haxe.ds.ObjectMap<Building, Bool>;
  public static var doorSeen:haxe.ds.ObjectMap<Building, Bool>;
  public static var bandSeen:haxe.ds.ObjectMap<Building, Bool>;
  public static var noBackDoor:Array<Building>; // had an open back wall but no side door fit (clearance)
  // placed door along-face spans (offset-from-face-center interval), so WallDecals skips graffiti
  // overlapping a door. same center + axis convention as buildingFaces `off` (see Entrances.place)
  public static var doorSpans:Array<{ b:Building, dir:Int, lo:Float, hi:Float }>;

// ground surface height at grid cell (col,row): walkway tops sit a curb above road/alley, so
// actors/decals/the ring rest on this instead of sinking through the raised pavement.
// this is the ONE ground-height entry point for the whole render layer (actors, choreo,
// particles, decals, PathLine, TacticalGrid) — a non-city area sets no tile grid and is flat,
// so the null case here is what lets all of that run unmodified in e.g. a sewer
  public static function floorY(col:Int, row:Int):Float
    {
      if (tiles == null)
        {
          if (ground == null)
            return 0.0;
          // the cell CENTRE, because a (col,row) says nothing finer. that is the granularity of this
          // whole entry point and it is why the relief out there is kept shallow: an actor's y is
          // exact at the middle of its cell and off by up to half a cell of slope at the edge, so it
          // steps as it crosses — the same step the city already takes over a curb. anything holding
          // a real world position (a decal, the slime trail) should call floorYAt instead
          var w = citygen.CityConfig.cellToWorld(col, row);
          return ground(w.x, w.z);
        }
      if (row < 0 ||
          col < 0 ||
          row >= tiles.length ||
          col >= tiles[row].length)
        return 0.0;
      return (tiles[row][col] == Tile.Walkway || beveled(col, row)) ? render.RenderConfig.CURB_H : 0.0;
    }

// ground surface height under a WORLD point. only ever differs from floorY where an area has
// CONTINUOUS relief — a city floor steps per tile, so there the cell answer already is the world
// answer and this just routes to it. for anything laid at a real world position rather than on a
// cell: a decal, a trail spine, a scatter
  public static function floorYAt(x:Float, z:Float):Float
    {
      if (ground != null)
        return ground(x, z);
      var c = citygen.CityConfig.worldToCell(x, z);
      return floorY(c.col, c.row);
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
