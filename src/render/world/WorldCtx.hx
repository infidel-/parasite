package render.world;

import citygen.CityModel.Building;
import citygen.CityModel.Tile;

// one exposed face of a wall cell that carries a wall-mounted object, and the pose render.Actors
// paints that object's icon and its through-wall mark at. see WorldCtx.wallMounts
typedef WallMount = {
  x:Float,    // world X of the quad centre, already nudged proud of the face
  y:Float,    // world Y: the height up the wall the object hangs at
  z:Float,    // world Z of the quad centre
  rotY:Float, // outward normal yaw of the face, i.e. the quad's own rotation.y
  scale:Float,// billboard scale of the quad — the area kind owns it, so the actor layer needs to
              // know nothing about how thick or how tall that kind builds its walls
};

// one upper-floor window column as render.world.Windows emitted it: where it stands, on which face
typedef WinCol = {
  dir:Int,    // the face (Geom.buildingFaces' dir)
  x:Float,    // world X of the column, on the face plane
  z:Float,    // world Z of the column, on the face plane
  rotY:Float, // outward normal yaw of the face
};

// shared state for one city build, set by World.build() and read by every world
// sub-builder. buildings/tiles are read by nearly every pass; the *Seen maps are
// written by one pass each (bands/doors/windows) and read only by the checklist.
class WorldCtx {
  // all buildings in the current city (a warm pass: its representatives only)
  public static var buildings:Array<Building>;
  // what the current build is for (render.World.build)
  public static var pass:WorldPass = REAL;
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
  // the arc height, in world units, an actor's billboard takes on a one-cell move from (fromCol,
  // fromRow) to (toCol,toRow) that climbs over something the area DRAWS but does not BLOCK — 0 for
  // an ordinary step. null in every area kind with nothing to climb, which is the city and the
  // tunnels; render.wild.WildArea points it at its highway guard rails.
  // same contract as `ground` above and cleared in the same two places: the area kind that sets it
  // owns clearing it, or the next area inherits a barrier that is not there
  public static var climbArc:(Int, Int, Int, Int)->Float = null;
  // the faces of the wall an object standing at (col,row) is mounted IN — null when the cell is not
  // a wall of this area kind's own making, which is every cell in most areas. an object here is a
  // grille cut into masonry (objects.Vent) and not a thing lying on the floor: painted on its cell
  // like anything else it sinks INSIDE two units of wall and only its through-wall mark ever shows.
  // one pose per EXPOSED face, because a wall has an inside and an outside and the player meets it
  // from either; the two look opposite ways, so exactly one of them is ever seen.
  // same contract as `ground` above — the area kind that sets it owns clearing it, or the next area
  // inherits walls that are not there
  public static var wallMounts:(Int, Int)->Array<WallMount> = null;
  // the world offset from a cell's CENTRE to where the area kind actually DRAWS the thing standing on
  // it — null on a cell that stands its thing in the middle, which is every cell in most area kinds.
  // a facility fitting is pushed off the WALL FACE, which is a whole unit inside the cell boundary,
  // so a 1.2-wide drum ends up 2.28 of a 4-unit cell from where its object sits. the pose is what
  // render.actors.LampShadows projects a fake cast shadow from, and without this the shadow lands in
  // the middle of the tile while the drum stands against the wall — reported from the game as exactly
  // that. same contract as `ground` above — the area kind that sets it owns clearing it
  public static var standOff:(Int, Int)->{ x:Float, z:Float } = null;
  // how far from a wall cell's CENTRE the area kind actually DRAWS that cell's face, or -1 on a cell
  // that is not a wall of its own making. null in every area kind whose masonry fills its cell,
  // which is the city and the tunnels; render.facility.FacilityArea points it at its own slabs.
  // a decal that stands on a wall is placed from the cell the drop or the shot DIED in, and the cell
  // boundary is where it dies — true in the city, where a wall cell is solid to its edges, and half
  // a cell wrong in a compound, where FacilityGeom centres a slab of WALL_T 2.0 in a 4.0 cell. Blood
  // sprayed onto an office wall stood 1.12 units clear of it, reported as decals hanging in the air.
  // same contract as `ground` above — the area kind that sets it owns clearing it
  public static var wallFace:(Int, Int, Int)->Float = null;
  // is (col,row) a cell a door must not open onto, because the area keeps something solid standing
  // there (objects.Dumpster)? null = none. render.CityArea sets it for its own build alone and clears
  // it right after, so a warm city or the next area never reads a stale one
  public static var doorBlocked:(Int, Int)->Bool = null;
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
  // every windowed building's window columns, written by Windows.add, read by StreetProps to hang a
  // fire escape over two of them and a downpipe beside the last
  public static var winCols:haxe.ds.ObjectMap<Building, Array<WinCol>>;

// how far out from a wall cell's centre a decal standing on face `dir` has to sit, INCLUDING the
// proud nudge that keeps it off the surface. `dir` is render.world.Geom's numbering (0 +z, 1 -z,
// 2 +x, 3 -x) — it matters because a washroom divider spans its cell along its OWN run and is only
// PART_T across. Half a cell wherever the area kind draws its masonry to the cell boundary, which is
// the default and every area but the compound
  public static function faceOff(col:Int, row:Int, dir:Int, proud:Float):Float
    {
      var d = (wallFace != null ? wallFace(col, row, dir) : -1.0);
      return (d > 0 ? d : citygen.CityConfig.CELL / 2) + proud;
    }

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
