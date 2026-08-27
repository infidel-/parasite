package render.facility;

import game.AreaGame;

// what a facility cell IS to the renderer, derived from its Const.TILE_* id. NONE is a cell with no
// horizontal surface of its own: a wall, or a hangar door strip
enum abstract Surf(Int) from Int to Int
{
  var NONE = 0;
  var ROAD = 1;      // the 4-wide band at the north or south edge
  var WALKWAY = 2;   // pavement, ringing every building and running beside the road
  var LOT = 3;       // the alley fill, i.e. the parking lot and the yard
  var GRASS = 4;     // the park strip, including its trees and bushes
  var TILE = 5;      // room floor
  var LINO = 6;      // corridor floor, and every door cell
  var GRATE = 7;     // a drain cell: one cell of art that REPLACES the floor rather than overlaying it
  var CONCRETE = 8;  // hangar floor
}

// what a cell blocks. windows are their own value because they are the one wall that is
// see-through, both to the game (tiles.Default.TILE_SEETHROUGH) and to the camera
enum abstract Wall(Int) from Int to Int
{
  var OPEN = 0;
  var SOLID = 1;
  var WINDOW = 2;
  var SHUTTER = 3;   // the hangar's big door strip: solid, opaque, and not a Door object
}

// which of the three painted door pairs a cell's leaves draw with. the generator deals FOUR kinds
// (Const.FRAME_DOOR_DOUBLE / GLASS / CABINET / METAL) and they collapse to three looks, because the
// front double and the side door are both glazed and the art for them is the same pair
enum abstract Look(Int) from Int to Int
{
  var GLASS = 0;
  var CABINET = 1;
  var METAL = 2;
}

// one door OPENING: a single cell holding a pair of leaves that swing apart.
//
// every facility door is exactly one cell wide — the front entrance looks like a double because the
// generator cuts a 3-cell chunk and puts a mullion back in the middle of it (FacilityAreaGenerator
// draws TEMP_BUILDING_FRONT_DOOR over `corridorWidth` and then restores the centre cell to wall), so
// what it really deals is two one-cell doors flanking a pier. a cell is 4 world units, which is a
// 2 m opening, and that is a DOUBLE door in anyone's building — hence two leaves of 2 units each
typedef DoorCell = {
  col:Int,
  row:Int,
  // the wall line the shut leaves lie in runs along +x. derived from which neighbours are wall, not
  // from the generator's own DIR_*, so it works on a saved grid with no generatorInfo at all
  alongX:Bool,
  // -1 or +1 on the PERPENDICULAR axis: the side the pair swings into
  inDir:Int,
  look:Look,
  structure:Int,
};

// one enclosed structure: a connected component of indoor floor, plus the wall ring around it.
// the facility generator makes exactly three — two lab buildings and a hangar — but nothing here
// counts on that, because the number falls out of the grid
typedef Structure = {
  // interior bounding box, inclusive, in cells
  x1:Int,
  y1:Int,
  x2:Int,
  y2:Int,
  // the same box grown by the wall ring: what the roof spans
  ox1:Int,
  oy1:Int,
  ox2:Int,
  oy2:Int,
  // floored in concrete rather than lab tile, which is the only thing that distinguishes the hangar
  // from a lab building in the saved grid. it takes different walls and has no windows at all
  hangar:Bool,
  // how many interior floor cells it holds (the hangar test is a majority over these)
  cells:Int,
};

// one window OPENING, which is a RUN of 2 or 3 cells and never a single one: the generator writes
// TILE_WINDOWH1..3 / V1..3 in runs, and its single-window path is dead (TEMP_BUILDING_WINDOW and
// TEMP_BUILDING_VENT are both 18, so finalTiles resolves that cell to plain wall plus a Vent).
// the quad is emitted per RUN, so the art's 3 panes span the whole opening once
typedef Window = {
  col:Int,        // first cell of the run
  row:Int,
  len:Int,        // 2 or 3
  alongX:Bool,    // an H run goes along +x, a V run along +z
  inDir:Int,      // -1 or +1 on the PERPENDICULAR axis, pointing at the interior
  structure:Int,  // index into Facility.structures
};

// everything the 3D facility builder needs, derived from the area's SAVED cell grid the way
// render.sewer.SewerModel and render.wild.WildModel derive theirs. no seed and nothing new
// persisted, so this works on every existing save.
//
// grids are [row][col] — the render convention, transposed from the game's [x][y]
typedef Facility = {
  w:Int,
  h:Int,
  surf:Array<Array<Surf>>,
  wall:Array<Array<Wall>>,
  // index into structures for a cell inside one (its floor OR its wall ring), -1 outdoors
  owner:Array<Array<Int>>,
  structures:Array<Structure>,
  windows:Array<Window>,
  // every door opening. NOT derived from the tile grid — a door cell finalises to plain
  // Const.TILE_FLOOR_LINO and is indistinguishable from the corridor it stands in, so the objects.Door
  // objects themselves are what locate one
  doors:Array<DoorCell>,
  // the same thing as a grid. a parallel channel and not a search over `doors`, because the shell
  // asks "does the wall line carry on through here" once per wall cell per side while it emits, and
  // a linear scan of a few dozen doors inside that loop is the wrong shape
  door:Array<Array<Bool>>,
  // the generator's room rects, straight off area.generatorInfo. used for the ceiling-light pass
  rooms:Array<_Room>,
};

class FacilityModel
{
// build the model from an area's saved cells
  public static function fromArea(area:AreaGame):Facility
    {
      var m = blank(area.width, area.height);
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var t = area.getCellType(col, row);
            m.surf[row][col] = surfOf(t);
            m.wall[row][col] = wallOf(t);
          }
      findStructures(m);
      findWindows(m);
      findDoors(m, area);
      m.rooms = (area.generatorInfo != null ? area.generatorInfo.rooms : []);
      return m;
    }

// an empty model of the given size (also the base for demo())
  static function blank(w:Int, h:Int):Facility
    {
      return {
        w: w,
        h: h,
        surf: [for (_ in 0...h) [for (_ in 0...w) Surf.NONE]],
        wall: [for (_ in 0...h) [for (_ in 0...w) Wall.OPEN]],
        owner: [for (_ in 0...h) [for (_ in 0...w) -1]],
        structures: [],
        windows: [],
        doors: [],
        door: [for (_ in 0...h) [for (_ in 0...w) false]],
        rooms: [],
      };
    }

// the horizontal surface a tile id paints. the table tiles resolve to plain room floor: a table is
// a prop standing ON the floor, so the cell still needs a floor under it
  static function surfOf(t:Int):Surf
    {
      if (t == Const.TILE_ROAD)
        return ROAD;
      if (t == Const.TILE_WALKWAY)
        return WALKWAY;
      if (t == Const.TILE_ALLEY)
        return LOT;
      if (t == Const.TILE_GRASS ||
          t == Const.TILE_GRASS_UNWALKABLE ||
          (t >= Const.TILE_TREE1 && t <= Const.TILE_BUSH))
        return GRASS;
      if (t >= Const.TILE_FLOOR_TILE_GRATE1 && t <= Const.TILE_FLOOR_TILE_GRATE3)
        return GRATE;
      if (t == Const.TILE_FLOOR_LINO)
        return LINO;
      if (t == Const.TILE_FLOOR_CONCRETE ||
          t == Const.TILE_FLOOR_CONCRETE_UNWALKABLE)
        return CONCRETE;
      if (t == Const.TILE_FLOOR_TILE ||
          t == Const.TILE_FLOOR_TILE_UNWALKABLE ||
          t == Const.TILE_FLOOR_TILE_CANNOTSEE)
        return TILE;
      // every table tile, and anything else the chem-lab block adds later, stands on room floor
      if (t >= Const.OFFSET_ROW8)
        return TILE;
      return NONE;
    }

// what a tile id blocks
  static function wallOf(t:Int):Wall
    {
      if (t == Const.TILE_BUILDING)
        return SOLID;
      if (t == Const.TILE_HANGAR_DOOR)
        return SHUTTER;
      if (t >= Const.TILE_WINDOWH1 && t <= Const.TILE_WINDOWV3)
        return WINDOW;
      return OPEN;
    }

// is (col,row) inside the grid?
  public static inline function inside(m:Facility, col:Int, row:Int):Bool
    {
      return col >= 0 &&
        row >= 0 &&
        col < m.w &&
        row < m.h;
    }

// is this an INDOOR floor cell — the four surfaces that only ever exist inside a structure?
  public static inline function isIndoor(m:Facility, col:Int, row:Int):Bool
    {
      if (!inside(m, col, row))
        return false;
      var s = m.surf[row][col];
      return s == Surf.TILE ||
        s == Surf.LINO ||
        s == Surf.GRATE ||
        s == Surf.CONCRETE;
    }

// does this cell carry a wall of any kind? the predicate the vision mask's blocker channel and the
// wall emitter both read. a window counts: it is a wall with a hole you can SEE through, and the
// mask's green channel is about what the sweep hits, which is handled by canSeeThrough separately
  public static inline function isWall(m:Facility, col:Int, row:Int):Bool
    {
      return inside(m, col, row) && m.wall[row][col] != Wall.OPEN;
    }

// flood-fill the indoor floor into connected components, then grow each by its wall ring.
// 4-connected, and a door cell is ordinary LINO floor, so one lab building comes back as ONE
// component however many rooms and corridors it holds — which is exactly the granularity the roof
// fade wants, since a roof is per building and not per room
  static function findStructures(m:Facility):Void
    {
      var stack = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!isIndoor(m, col, row) ||
                m.owner[row][col] >= 0)
              continue;
            var idx = m.structures.length;
            var st:Structure = {
              x1: col,
              y1: row,
              x2: col,
              y2: row,
              ox1: col,
              oy1: row,
              ox2: col,
              oy2: row,
              hangar: false,
              cells: 0,
            };
            var concrete = 0;
            stack.push({ col: col, row: row });
            m.owner[row][col] = idx;
            while (stack.length > 0)
              {
                var c = stack.pop();
                st.cells++;
                if (m.surf[c.row][c.col] == Surf.CONCRETE)
                  concrete++;
                if (c.col < st.x1)
                  st.x1 = c.col;
                if (c.col > st.x2)
                  st.x2 = c.col;
                if (c.row < st.y1)
                  st.y1 = c.row;
                if (c.row > st.y2)
                  st.y2 = c.row;
                for (i in 0...Const.dir4x.length)
                  {
                    var nc = c.col + Const.dir4x[i];
                    var nr = c.row + Const.dir4y[i];
                    if (!isIndoor(m, nc, nr) ||
                        m.owner[nr][nc] >= 0)
                      continue;
                    m.owner[nr][nc] = idx;
                    stack.push({ col: nc, row: nr });
                  }
              }
            // the hangar is the component the generator floored in concrete. a majority rather than
            // a single cell, because the side door's own cell is lab tile (TILE_FLOOR_TILE_CANNOTSEE)
            st.hangar = (concrete * 2 > st.cells);
            st.ox1 = st.x1 - 1;
            st.oy1 = st.y1 - 1;
            st.ox2 = st.x2 + 1;
            st.oy2 = st.y2 + 1;
            m.structures.push(st);
          }
      // the wall ring belongs to the structure it encloses, so the roof and the wall pass can both
      // ask one question. a wall between two structures cannot happen here — the generator leaves at
      // least a walkway between buildings — so first claim wins and there is nothing to arbitrate
      for (i in 0...m.structures.length)
        {
          var st = m.structures[i];
          for (row in st.oy1...st.oy2 + 1)
            for (col in st.ox1...st.ox2 + 1)
              if (isWall(m, col, row) &&
                  m.owner[row][col] < 0)
                m.owner[row][col] = i;
        }
    }

// group window cells into runs. a run starts where the previous cell along its own axis is not
// also a window, which recovers the generator's 2- and 3-cell openings without reading the H1/H2/H3
// ordering back out of the tile ids
  static function findWindows(m:Facility):Void
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.wall[row][col] != Wall.WINDOW)
              continue;
            // which axis this run travels: the one whose neighbour is also a window. an opening is
            // never 1 cell, so exactly one of the two answers is true
            var alongX = (isWindow(m, col - 1, row) || isWindow(m, col + 1, row));
            if (alongX && isWindow(m, col - 1, row))
              continue;
            if (!alongX && isWindow(m, col, row - 1))
              continue;
            var len = 1;
            while (isWindow(m, col + (alongX ? len : 0), row + (alongX ? 0 : len)))
              len++;
            // the interior is whichever perpendicular side holds indoor floor
            var dc = alongX ? 0 : 1;
            var dr = alongX ? 1 : 0;
            var inDir = isIndoor(m, col + dc, row + dr) ? 1 : -1;
            var ic = col + dc * inDir;
            var ir = row + dr * inDir;
            if (!isIndoor(m, ic, ir))
              continue;
            m.windows.push({
              col: col,
              row: row,
              len: len,
              alongX: alongX,
              inDir: inDir,
              structure: m.owner[ir][ic],
            });
          }
    }

// window lookup, bounds-safe
  static inline function isWindow(m:Facility, col:Int, row:Int):Bool
    {
      return inside(m, col, row) && m.wall[row][col] == Wall.WINDOW;
    }

// locate every door opening from the area's own objects.Door objects.
//
// off the OBJECTS and not off the tiles, because there is no door tile to find: every one of the
// generator's four door kinds finalises to Const.TILE_FLOOR_LINO or TILE_FLOOR_TILE_CANNOTSEE, so a
// shut door is, to the saved grid, a piece of corridor. what the grid DOES answer is the geometry —
// which way the wall runs, and which side to swing into
  static function findDoors(m:Facility, area:AreaGame):Void
    {
      for (o in area.getObjects())
        {
          if (o.type != 'door' ||
              !inside(m, o.x, o.y))
            continue;
          // the wall line is whichever axis has wall on both sides of the cell. a front door's pier
          // counts as that wall, which is why this reads the grid rather than the door's own dir
          var alongX = isWall(m, o.x - 1, o.y) && isWall(m, o.x + 1, o.y);
          var dc = alongX ? 0 : 1;
          var dr = alongX ? 1 : 0;
          var a = isIndoor(m, o.x - dc, o.y - dr);
          var b = isIndoor(m, o.x + dc, o.y + dr);
          if (!a && !b)
            continue;
          // leaves swing INTO the building, and between two indoor sides into the ROOM rather than
          // into the corridor — which is both what a real door does and what keeps a 3-cell corridor
          // clear. a tie falls to +1, so the choice is always deterministic
          var inDir = 1;
          if (a != b)
            inDir = (b ? 1 : -1);
          else if (m.surf[o.y - dr][o.x - dc] == Surf.TILE &&
                   m.surf[o.y + dr][o.x + dc] != Surf.TILE)
            inDir = -1;
          m.doors.push({
            col: o.x,
            row: o.y,
            alongX: alongX,
            inDir: inDir,
            look: lookOf(cast(o, objects.Door).closedCol),
            structure: m.owner[o.y][o.x],
          });
          m.door[o.y][o.x] = true;
        }
    }

// does this cell hold a door OPENING? the wall pass treats one as the wall line carrying on rather
// than ending, so the flanking slabs meet the cell boundary and the opening stays one cell wide
  public static inline function isDoor(m:Facility, col:Int, row:Int):Bool
    {
      return inside(m, col, row) && m.door[row][col];
    }

// the painted pair a door's shut icon asks for. the front double and the side door are both glazed,
// so four generator kinds land on three looks
  static function lookOf(closedCol:Int):Look
    {
      if (closedCol == Const.FRAME_DOOR_DOUBLE ||
          closedCol == Const.FRAME_DOOR_GLASS)
        return GLASS;
      if (closedCol == Const.FRAME_DOOR_METAL)
        return METAL;
      return CABINET;
    }

// xorshift32 avalanche over a cell hash, for every deterministic placement decision in here. the
// same function render.sewer.SewerModel.mix is, and called through it rather than copied: its header
// carries the measurement that justifies it (the bare `(col * A) ^ (row * B)` hash collapses to an
// arithmetic sequence on row 0 and column 0, where one term is zero, and deals runs of eight)
  public static inline function mix(h:Int):Int
    {
      return render.sewer.SewerModel.mix(h);
    }

// a throwaway two-room block for the boot shader pre-warm (see render.View.warmup): the real
// builders over fake data, so the compiled programs match what a real facility entry needs
  public static function demo():Facility
    {
      var m = blank(24, 16);
      for (row in 0...m.h)
        for (col in 0...m.w)
          m.surf[row][col] = LOT;
      // one building: a wall ring, rooms either side of a corridor, and a window run on the south
      // face. a wall cell carries NO surface, which is the invariant every builder here relies on
      for (row in 2...12)
        for (col in 2...20)
          m.surf[row][col] = (row >= 6 && row <= 7 ? Surf.LINO : Surf.TILE);
      for (row in 2...12)
        for (col in 2...20)
          {
            var ring = (row == 2 || row == 11 || col == 2 || col == 19);
            var spine = (col == 10 && (row < 6 || row > 7));
            if (!ring && !spine)
              continue;
            m.surf[row][col] = NONE;
            m.wall[row][col] = SOLID;
          }
      for (col in 8...11)
        m.wall[11][col] = WINDOW;
      // two doors: one through the spine, one through the south face. pushed by hand rather than
      // found, because findDoors reads live objects.Door objects and there is no area here — but the
      // CELLS are opened up first, so the shell builder sees the same hole a real door leaves
      m.surf[4][10] = LINO;
      m.wall[4][10] = OPEN;
      m.surf[11][5] = LINO;
      m.wall[11][5] = OPEN;
      findStructures(m);
      findWindows(m);
      m.doors.push({
        col: 10,
        row: 4,
        alongX: false,
        inDir: 1,
        look: CABINET,
        structure: 0,
      });
      m.doors.push({
        col: 5,
        row: 11,
        alongX: true,
        inDir: -1,
        look: GLASS,
        structure: 0,
      });
      for (d in m.doors)
        m.door[d.row][d.col] = true;
      return m;
    }
}
