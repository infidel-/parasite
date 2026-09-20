package render.facility;

import game.AreaGame;
import render.particles.AtlasBox;

// what a facility cell IS to the renderer, derived from its Const.TILE_* id. NONE is a cell with no
// horizontal surface of its own: a wall, or a hangar door strip
enum abstract Surf(Int) from Int to Int
{
  var NONE = 0;
  var ROAD = 1;      // the 4-wide band at the north or south edge
  var WALKWAY = 2;   // pavement, ringing every building and running beside the road
  var LOT = 3;       // open asphalt: the car park, the yard and the gaps between plots alike
  var GRASS = 4;     // the park strip, including its trees and bushes
  var TILE = 5;      // room floor
  var LINO = 6;      // corridor floor, and every door cell
  var GRATE = 7;     // a drain cell: one cell of art that REPLACES the floor rather than overlaying it
  var CONCRETE = 8;  // hangar floor
  // the two ROOM TEMPLATES besides the laboratory. the generator writes one floor tile per template
  // (game.FacilityAreaGenerator.roomCabinet / roomToilet) and that tile is the whole record — these
  // two values are what every pass downstream reads a themed room off
  var OFFICE = 9;    // a researcher's office: desks, bookcases, office clutter
  var WASH = 10;     // a washroom: cubicles, basins, a mirror
}

// what a cell blocks. windows are their own value because they are the one wall that is
// see-through, both to the game (tiles.Default.TILE_SEETHROUGH) and to the camera
enum abstract Wall(Int) from Int to Int
{
  var OPEN = 0;
  var SOLID = 1;
  var WINDOW = 2;
  var SHUTTER = 3;   // the hangar's big door strip: solid, opaque, and not a Door object
  // the washroom's light well: glazed, but set so high in the wall that neither the player nor the
  // camera sees through it. it is its own value rather than a flag on WINDOW because EVERY predicate
  // that asks "is this see-through" has to answer NO for it — including render.world.VisionMask's
  // blocker test, which reads `wall != WINDOW` and so takes this one as solid with no edit at all
  var WINDOW_HIGH = 4;
}

// which of the three painted door pairs a cell's leaves draw with. the generator deals FOUR kinds
// (Const.FRAME_DOOR_DOUBLE / GLASS / CABINET / METAL) and they collapse to three looks, because the
// front double and the side door are both glazed and the art for them is the same pair
enum abstract Look(Int) from Int to Int
{
  var GLASS = 0;
  var CABINET = 1;
  var METAL = 2;
  // and the PRIVATE leaf, which the washroom and the researcher's office take. a fourth look and not
  // a repaint of CABINET because it is a different door: no vision panel in the art, and
  // objects.Door.canSeeThrough returns false while it is shut
  var PRIVATE = 3;
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
  // cut as the building's FRONT ENTRANCE, i.e. one of the two leaves flanking the mullion.
  //
  // the generator's own marker does NOT survive: finalTiles resolves TEMP_BUILDING_FRONT_DOOR to
  // plain Const.TILE_FLOOR_LINO, exactly what a side door and an inner door resolve to, and
  // generatorInfo.doors only ever records the INNER ones. it survives on the OBJECT alone —
  // Const.FRAME_DOOR_DOUBLE is dealt to the entrance and to nothing else — which is why `look`
  // cannot be asked instead: lookOf collapses DOUBLE and GLASS onto one painted pair
  front:Bool,
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
  len:Int,        // 2 or 3, and always 1 for a light well
  alongX:Bool,    // an H run goes along +x, a V run along +z
  inDir:Int,      // -1 or +1 on the PERPENDICULAR axis, pointing at the interior
  structure:Int,  // index into Facility.structures
  // a washroom LIGHT WELL rather than a ribbon: one cell, set high, opaque to sight, and — the part
  // that matters outdoors — it throws NO light rectangle on the ground and stands in for no shadow
  // source (render.facility.FacilityGlow skips these), because a slot under the eaves does not
  // spill a lit floor onto the pavement the way a full-height pane does
  high:Bool,
};

// one laboratory-bench decoration, as the contact pool under it needs it — and ALL THREE numbers are
// properties of the SPRITE and not of the cell, which is the whole reason they are carried here
// rather than derived at the emitter.
//
// a bench decoration is a 2D billboard, and render.particles.Sprites leans every upright quad back
// by TILT about world X. That rotation is about the quad's CENTRE, so everything below the centre
// swings toward +z: measured in game, a bench quad's bottom edge sits 0.69 world units in front of
// its own anchor. The pool sat at the anchor and the object was drawn in front of it, which is
// exactly how it was reported — "objects are moved from center but the contact shadow doesn't".
//
// THE ICON IS NOT CENTRED IN ITS CELL EITHER, and that one was reported twice before it was found.
// The quad is centred on the object's anchor, but the ART inside it is not centred on the quad: the
// 43 frames were drawn to a sheet, not to a plumb line, and measured live their opaque centres sit
// -0.49 to +0.15 world units off the anchor. So a pool on the anchor lands BESIDE the object — to
// the right of a flask, to the left of a microscope, which is exactly what "black splotches on both
// sides" was. `dz` alone could never fix it: that offset is on the OTHER axis.
//
// AND NO NUMBER HERE IS ONE NUMBER, which is what makes them per cell rather than constants. All
// three come off the icon's own alpha box (render.particles.Sprites.cellBox), and over the 43 frames
// that box moves a long way: `dz` spans 0.150 to 0.514 and the content width 0.76 to 1.82 world
// units — a 2.4x range. A single offset would be 0.25 out on the extremes, and a single radius
// would put the same puddle under a retort stand and under a distillation rig
typedef TableDeco = {
  // how far the icon's opaque CENTRE sits from the cell centre along world x. no tilt term: the
  // lean is about world X and moves nothing sideways, so this is the art's own offset and nothing else
  dx:Float,
  // how far the sprite's drawn base sits from the cell centre toward the camera, world +z.
  // SIZE * DECO_TABLE_SCALE * (0.5 - by) * sin(TILT), where `by` is the icon's bottom margin
  dz:Float,
  // and the pool's half extent, off the icon's own opaque WIDTH — see FacilityStyle.TABLE_POOL_FOOT
  // for why it is a fraction of that and not the whole of it
  r:Float,
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
  // which cells carry a laboratory BENCH. a grid and not a list of rects, because the emitter asks
  // "does the bench carry on through here" once per bench cell per side, exactly as the wall pass
  // asks it of the wall line — so a run, an island and an L all fall out of one predicate and no
  // rect finding is needed
  table:Array<Array<Bool>>,
  // which cells are THE CAR PARK, as opposed to the yard and the alley gaps between plots. Both
  // resolve to Surf.LOT — the asphalt is the same asphalt, and debris, lamps and every other
  // lot-gated pass wants all of it — so the surface grid cannot answer this and the raw tile is the
  // only thing that can (Const.TILE_PARKING). Two passes ask it per cell, render.facility
  // .FacilityPaint's bay striping and FacilityCars' spot search, which is why it is a grid and not
  // the rect it happens to be
  parking:Array<Array<Bool>>,
  // and where each PARKED CAR stands: the cell carrying Const.TILE_PARKING_CAR_ORIGIN, which is its
  // bay's low corner against the kerb. gen.facility.FacilityBays deals the bays and stamps the
  // footprint; render.facility.FacilityCars stands one model on each of these and needs no phase
  cars:Array<{ col:Int, row:Int }>,
  // which cells stand a piece of 3D FURNITURE, as the fitting kind PLUS ONE — 0 is "nothing here",
  // so the grid needs no second channel to say whether a cell is empty. a grid for the same reason
  // `table` is one: two passes ask it per cell (the emitter, and FacilityKit's own placement gate),
  // and a scan over the area's objects inside either loop is the wrong shape.
  //
  // the kind is derived from the decoration's ATLAS FRAME (Const.fittingOf) rather than persisted
  // on the object: the frames were already in every save, so this needs no migration
  deco:Array<Array<Int>>,
  // and which cells stand a decoration on the WORKTOP — the family `deco` above does not hold,
  // because those keep their 2D sprite and so have no fitting kind at all (Const.fittingOf is -1 for
  // every one of them). A grid and not a list for the third time: FacilityTables walks the bench
  // cells it is already emitting and asks this once per cell.
  //
  // null is "nothing here". The frames that LIE DOWN are excluded on the way in — a thing already
  // flat on the worktop is not standing on it
  tableDeco:Array<Array<TableDeco>>,
  // and which worktop cells are OCCUPIED at all, which is a different question from the one above and
  // not the same grid however much it looks like one. `tableDeco` carries the pool geometry a
  // STANDING sprite needs and is null for the three frames that lie down (Const.FACILITY_FLAT_DECO),
  // because nothing lying flat casts the shadow that grid exists to place. This one counts them: a
  // pair of gloves is still a thing on the worktop, and render.facility.FacilitySink has to know the
  // cell is spoken for before it lays a basin through them
  tableTaken:Array<Array<Bool>>,
  // and which worktop cells a SINK owns, filled by render.facility.FacilitySink as it emits. a THIRD
  // grid over the same cells, and it cannot be folded into either above it because the question
  // render.facility.FacilityClutter asks is three-way: an empty cell takes clutter anywhere, a
  // DECORATED cell takes it around the pool in `tableDeco`, and a SINK cell takes none at all —
  // SINK_BASIN_W is 2.5 of a 4.0 cell, so there is no usable worktop left beside one.
  //
  // written by a RENDER pass rather than by findDeco, unlike the two above: a sink is not an object
  // in the save, it is picked per bench block at build time
  tableSink:Array<Array<Bool>>,
  // which cells stand an objects.FloorDrain. the OBJECT and not `Surf.GRATE`: the generator lays a
  // grate TILE on one cell of every chemistry lab and then stands a drain on it only 30% of the
  // time, so the surface says where a drain COULD be and the object says where one is
  drain:Array<Array<Bool>>,
  // the generator's room rects, straight off area.generatorInfo. used for the ceiling-light pass
  rooms:Array<_Room>,
  // the centre cell of every hangar STUDY PAD — the square of unwalkable concrete
  // gen.blocks.HangarBlock carves in the middle of a shed for the podium to stand on.
  //
  // A LIST AND NOT A GRID, unlike `table` and `deco` beside it: there is at most one per hangar and
  // exactly one pass asks for it, so the question is "where are they" and never "is this cell one".
  // Found HERE rather than in that pass because it is the one thing in the shed the surface grid
  // cannot answer — Surf.CONCRETE covers the walkable floor and the unwalkable pad alike, and the
  // raw tile is only in scope while fromArea is reading it
  pads:Array<{ col:Int, row:Int }>,
};

class FacilityModel
{
  // how wide a walkway run isParkPath will still cross, in cells. the generator's path is
  // game.FacilityAreaGenerator.PARK_PATH_W wide; this is that with slack, and low enough that a
  // compound's own pavement never reads as one
  static inline var PATH_MAX = 4;

// build the model from an area's saved cells.
//
// `icon` looks one entities64 frame's ATLAS CONTENT BOX up, by (row, col), and is the one thing here
// not derived from the grid — a bench decoration's contact pool is sized and placed off the icon's
// own opaque box (see TableDeco), which is pixels and not tiles.
//
// A FUNCTION AND NOT A REACH, for two reasons. This file has no business knowing about the renderer,
// and — the one that bites — the SPRITE POOL DOES NOT EXIST YET: render.View builds the actor layer
// inside `buildFrom`, which runs on the model this call returns. An earlier cut asked `actors` here
// and every facility entry died on a null. render.View supplies it off the decoded atlas instead.
// omitted, or before that atlas decodes, every pool falls back to FacilityStyle's own averages
  public static function fromArea(area:AreaGame, ?icon:(Int, Int)->AtlasBox):Facility
    {
      var m = blank(area.width, area.height);
      // the unwalkable-concrete mask, local to this call: findPads is the only reader and a third
      // per-cell grid on the model for one pass is a grid nobody else would ever ask
      var solid = [for (_ in 0...area.height) [for (_ in 0...area.width) false]];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var t = area.getCellType(col, row);
            m.surf[row][col] = surfOf(t);
            m.wall[row][col] = wallOf(t);
            // a worktop's SHAPE is not read at all — the generator deals 3x1 and 1x3 runs, a 1x1
            // and a 2x3 or 3x2 island, and FacilityTables recovers every one of them from
            // neighbours. this used to carry its own copy of the tile test; see Const.isTableTile
            // for what the generator having a DIFFERENT copy of it cost
            m.table[row][col] = Const.isTableTile(t);
            m.parking[row][col] = (t == Const.TILE_PARKING ||
              t == Const.TILE_PARKING_CAR ||
              t == Const.TILE_PARKING_CAR_ORIGIN);
            // and where a car stands: a LIST and not a grid, because there are at most
            // gen.facility.FacilityBays.CARS of them and the one pass that wants them wants them all
            if (t == Const.TILE_PARKING_CAR_ORIGIN)
              m.cars.push({
                col: col,
                row: row,
              });
            if (t == Const.TILE_FLOOR_CONCRETE_UNWALKABLE)
              solid[row][col] = true;
          }
      findStructures(m);
      shedFloor(m);
      findPads(m, solid);
      findWindows(m);
      findDoors(m, area);
      findDeco(m, area, icon);
      m.rooms = (area.generatorInfo != null ? area.generatorInfo.rooms : []);
      themeRooms(m);
      return m;
    }

// find every hangar study pad, as the centre cell of its square.
//
// DERIVED FROM THE SHAPE AND NOT FROM A CONSTANT SHARED WITH THE GENERATOR. Three separate arms of
// gen.blocks.HangarBlock write unwalkable concrete into a shed — the pad, the standing runs against
// the walls, and the leftover slot filler — and only one of them is the pad. What tells them apart
// is that the pad is the only SQUARE of it: a rack bay is one cell wide and so is a machine bank, so
// the first cell whose whole PAD x PAD neighbourhood is solid is the pad's centre and nothing else
// can be. Re-deriving the generator's own centring arithmetic here instead would be a second copy of
// it that drifts the moment either side is retuned.
//
// FacilityStyle.PODIUM_PAD is a floor on the square and not an equality, so a shed that one day
// carves a bigger pad still resolves to one centre: the scan takes the first hit per structure
  static function findPads(m:Facility, solid:Array<Array<Bool>>):Void
    {
      var r = Std.int(FacilityStyle.PODIUM_PAD / 2);
      var seen = new Map<Int, Bool>();
      for (row in r...m.h - r)
        for (col in r...m.w - r)
          {
            var si = m.owner[row][col];
            if (si < 0 ||
                !m.structures[si].hangar ||
                seen.exists(si))
              continue;
            var full = true;
            for (dr in -r...r + 1)
              for (dc in -r...r + 1)
                if (!solid[row + dr][col + dc])
                  full = false;
            if (!full)
              continue;
            seen.set(si, true);
            m.pads.push({ col: col, row: row });
          }
    }

// AND EVERY FLOOR IN A SHED IS CONCRETE, whatever tile it happens to be laid in.
//
// gen.blocks.HangarBlock lays the hangar's console run in the LABORATORY's own worktop tiles —
// deliberately, so the workstation pass needs no second copy of itself — and its side door in a door
// tile, so surfOf reads those four cells back as Surf.TILE and the floor pass painted a square of lab
// tile behind every console in a concrete shed, which is what was reported from the game. surfOf
// cannot know better: it sees one tile id and no building. The structure's own hangar flag does, so
// this is a pass of its own and runs straight after findStructures — the flag is a MAJORITY over
// concrete cells, so flipping four of them can never change which structure is the shed
  static function shedFloor(m:Facility):Void
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          if (m.surf[row][col] == Surf.TILE &&
              inHangar(m, col, row))
            m.surf[row][col] = Surf.CONCRETE;
    }

// spread a themed room's surface over the WHOLE of its rect.
//
// a desk cell is a bench TILE and every bench tile resolves to Surf.TILE by the row-8 catch-all in
// surfOf, so without this the floor under an office's desks — and the wall face behind them, which
// FacilityGeom.look takes off the cell it looks INTO — stays laboratory. the rect comes from
// generatorInfo, so a save made before room templates existed holds no themed cell in any rect and
// this is a no-op on it
  static function themeRooms(m:Facility):Void
    {
      for (room in m.rooms)
        {
          var theme = Surf.NONE;
          for (row in room.y1...room.y2 + 1)
            for (col in room.x1...room.x2 + 1)
              if (inside(m, col, row) &&
                  isThemed(m.surf[row][col]))
                theme = m.surf[row][col];
          if (theme == Surf.NONE)
            continue;
          for (row in room.y1...room.y2 + 1)
            for (col in room.x1...room.x2 + 1)
              if (inside(m, col, row) &&
                  m.surf[row][col] == Surf.TILE)
                m.surf[row][col] = theme;
        }
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
        table: [for (_ in 0...h) [for (_ in 0...w) false]],
        parking: [for (_ in 0...h) [for (_ in 0...w) false]],
        cars: [],
        deco: [for (_ in 0...h) [for (_ in 0...w) 0]],
        tableDeco: [for (_ in 0...h) [for (_ in 0...w) (null : TableDeco)]],
        tableTaken: [for (_ in 0...h) [for (_ in 0...w) false]],
        tableSink: [for (_ in 0...h) [for (_ in 0...w) false]],
        drain: [for (_ in 0...h) [for (_ in 0...w) false]],
        rooms: [],
        pads: [],
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
      // open asphalt, all five ids. TILE_ALLEY_UNWALKABLE is the gate mouth's barrier row and the two
      // TILE_PARKING_CAR ids are a parked car's footprint — the
      // surface is the drive and only the walk was taken off it, so the ground pass, the lamps and
      // render.facility.FacilityEntry.isEntry all have to keep seeing a lot there
      if (t == Const.TILE_ALLEY ||
          t == Const.TILE_PARKING ||
          t == Const.TILE_ALLEY_UNWALKABLE ||
          t == Const.TILE_PARKING_CAR ||
          t == Const.TILE_PARKING_CAR_ORIGIN)
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
      // the two themed floors, each with the unwalkable twin one tileset row below it that the cells
      // under furniture take. BEFORE the row-8 catch-all below, which would swallow both
      if (t == Const.TILE_FLOOR_WOOD1 ||
          t == Const.TILE_FLOOR_WOOD1 + 16)
        return OFFICE;
      if (t == Const.TILE_FLOOR_MARBLE1 ||
          t == Const.TILE_FLOOR_MARBLE1 + 16)
        return WASH;
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
      if (t == Const.TILE_WINDOW_HIGH)
        return WINDOW_HIGH;
      return OPEN;
    }

// is this cell the car park — the one lot in the compound the gate opens onto? false off the grid.
// the yard and the gaps between plots are open asphalt too and answer Surf.LOT exactly the same, so
// every pass that means THE CAR PARK rather than OPEN LOT has to ask this instead
  public static inline function isParking(m:Facility, col:Int, row:Int):Bool
    {
      return inside(m, col, row) && m.parking[row][col];
    }

// is (col,row) inside the grid?
  public static inline function inside(m:Facility, col:Int, row:Int):Bool
    {
      return col >= 0 &&
        row >= 0 &&
        col < m.w &&
        row < m.h;
    }

// is this an INDOOR floor cell — the six surfaces that only ever exist inside a structure?
  public static inline function isIndoor(m:Facility, col:Int, row:Int):Bool
    {
      if (!inside(m, col, row))
        return false;
      var s = m.surf[row][col];
      return s == Surf.TILE ||
        s == Surf.LINO ||
        s == Surf.GRATE ||
        s == Surf.CONCRETE ||
        s == Surf.OFFICE ||
        s == Surf.WASH;
    }

// is this cell inside the HANGAR — the one structure floored in concrete?
//
// it is the structure's flag and not the cell's surface, because the shed's own console run is laid
// in the laboratory's worktop tiles. `shedFloor` above repaints the FLOOR those cells carry, so a
// surface test now calls them concrete rather than lab — but concrete is the whole shed, and what
// every caller here wants to know is whether a given cell is inside it
  public static inline function inHangar(m:Facility, col:Int, row:Int):Bool
    {
      if (!inside(m, col, row))
        return false;
      var si = m.owner[row][col];
      return si >= 0 && m.structures[si].hangar;
    }

// is this cell a themed ROOM floor — an office or a washroom? the passes that furnish a LABORATORY
// gate on Surf.TILE and so skip these for free; this is for the ones that have to tell the two
// themes apart rather than tell them from the lab
  public static inline function isThemed(s:Surf):Bool
    {
      return s == Surf.OFFICE ||
        s == Surf.WASH;
    }

// is this walkway cell the PARK PATH rather than perimeter pavement — the run of walkway it lies
// in, measured across one axis, has GRASS at both ends.
//
// there is nothing else to test. game.FacilityAreaGenerator writes the path as plain TEMP_WALKWAY
// (which is the whole reason it arrives kerbed and lit for free), so by the time it reaches here it
// is indistinguishable by id from the aprons ringing every structure and from the sidewalk along
// the road — and the park's own rect is not in generatorInfo either. what IS distinctive is that a
// path has lawn on BOTH sides of it and a perimeter pavement has lawn on one.
//
// the walk is capped at PATH_MAX: unbounded, a scan across a compound's pavement would eventually
// reach a lawn on the far side of the site and call the main sidewalk a park path
  public static function isParkPath(m:Facility, col:Int, row:Int):Bool
    {
      if (!inside(m, col, row) ||
          m.surf[row][col] != Surf.WALKWAY)
        return false;
      return (grassAcross(m, col, row, -1, 0) && grassAcross(m, col, row, 1, 0)) ||
        (grassAcross(m, col, row, 0, -1) && grassAcross(m, col, row, 0, 1));
    }

// step off (col,row) one way over the walkway run it stands in: is the first cell past that run
// grass? false once the run outlasts PATH_MAX cells, which is what stops a path test crossing a
// whole compound
  static function grassAcross(m:Facility, col:Int, row:Int, dc:Int, dr:Int):Bool
    {
      var c = col + dc;
      var r = row + dr;
      for (_ in 0...PATH_MAX)
        {
          if (!inside(m, c, r))
            return false;
          if (m.surf[r][c] != Surf.WALKWAY)
            return m.surf[r][c] == Surf.GRASS;
          c += dc;
          r += dr;
        }
      return false;
    }

// is this cell WELL INSIDE a building — floor or wall, with nothing but building on every side?
//
// what render.world.IndoorMask is painted from, and neither half of it is what a first guess
// reaches for. the mask GROWS its region past a cell boundary (IndoorMaskOpts.grow) to reach the
// inner face of the wall slab beside it, so the question here is not "is this indoors" but "is this
// far enough in that the grow cannot escape the building".
//
// THE FOUR-NEIGHBOUR TEST IS THE WHOLE PREDICATE, and it settles two cases at once that look
// unrelated:
//   A ROOM DIVIDER IS NOT FLOOR. isIndoor alone fails a partition, so a divider came back lit as
//     though it stood outdoors while the rooms either side of it were lit indoors — the grow covers
//     its two faces from either side but not the strip of mass between them. a partition has
//     building on all four sides and is included here.
//   AN EXTERIOR DOOR CELL IS FLOOR AND MUST STILL BE EXCLUDED. it finalises to plain corridor lino,
//     so isIndoor calls it indoors, and painting it whole put a grow's worth of interior light out
//     onto the PAVEMENT and onto the outward face of the shut leaves — measured at 6.8x the
//     surrounding pavement, and read as the building having no lid. one of its neighbours is the
//     lot, so this excludes it and the doorway is reached by grow from the room behind exactly as
//     the wall it interrupts is. the leaves sit on the cell centre plane, a sigma outside the grown
//     region, so a shut door reads as part of the exterior — which is what it is. the light that
//     SHOULD come out of an open door is an additive spill cone and belongs to the lighting pass,
//     not to this mask
  public static inline function isInterior(m:Facility, col:Int, row:Int):Bool
    {
      return (isIndoor(m, col, row) || isWall(m, col, row)) &&
        owned(m, col - 1, row) &&
        owned(m, col + 1, row) &&
        owned(m, col, row - 1) &&
        owned(m, col, row + 1);
    }

// does a structure claim this cell — its floor or its wall ring?
  static inline function owned(m:Facility, col:Int, row:Int):Bool
    {
      return inside(m, col, row) && m.owner[row][col] >= 0;
    }

// does this cell carry a wall of any kind? the predicate the vision mask's blocker channel and the
// wall emitter both read. a window counts: it is a wall with a hole you can SEE through, and the
// mask's green channel is about what the sweep hits, which is handled by canSeeThrough separately
  public static inline function isWall(m:Facility, col:Int, row:Int):Bool
    {
      return inside(m, col, row) && m.wall[row][col] != Wall.OPEN;
    }

// and is it a wall a FITTING may stand against? plain masonry only: a window's sill is exactly where
// a worktop would be, and the hangar's shutter is a door that slides
  public static inline function isSolidWall(m:Facility, col:Int, row:Int):Bool
    {
      return inside(m, col, row) && m.wall[row][col] == Wall.SOLID;
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
              high: false,
            });
          }
      findHighWindows(m);
    }

// and the washroom's light wells, which are one cell each and never a run — the generator writes them
// every OTHER cell, so there is nothing to group. their own pass rather than a branch in the one
// above, because the whole of that function is about recovering a run's length and its axis
  static function findHighWindows(m:Facility):Void
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.wall[row][col] != Wall.WINDOW_HIGH)
              continue;
            // the run axis is the wall line, i.e. whichever axis has wall on both hands
            var alongX = isWall(m, col - 1, row) && isWall(m, col + 1, row);
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
              len: 1,
              alongX: alongX,
              inDir: inDir,
              structure: m.owner[ir][ic],
              high: true,
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
          // A ROOM IS ANYTHING INDOORS THAT IS NOT THE CORRIDOR, and the test used to be
          // `== Surf.TILE` on both hands — which was the same thing until the room TEMPLATES arrived
          // and a room could be OFFICE or WASH. With those, neither hand of a themed room's door read
          // as a room, the tie fell through to +1, and half of them swung into the corridor instead:
          // the very doors that most need to swing inward, since they are the ones that shut
          else if (m.surf[o.y - dr][o.x - dc] != Surf.LINO &&
                   m.surf[o.y + dr][o.x + dc] == Surf.LINO)
            inDir = -1;
          var closed = cast(o, objects.Door).closedCol;
          m.doors.push({
            col: o.x,
            row: o.y,
            alongX: alongX,
            inDir: inDir,
            look: lookOf(closed),
            front: closed == Const.FRAME_DOOR_DOUBLE,
            structure: m.owner[o.y][o.x],
          });
          m.door[o.y][o.x] = true;
        }
    }

// stamp the cells standing a piece of 3D furniture, off the DECORATION OBJECTS the generator left —
// the same source findDoors above reads, and for the same reason: a decoration is an object standing
// on a plain unwalkable floor cell, so the tile grid can say THAT one is occupied but not by what.
//
// the kind comes out of the object's atlas frame (Const.fittingOf), which is why this works on a
// save made long before any of this existed: those decorations already carry the frames
  static function findDeco(m:Facility, area:AreaGame, icon:(Int, Int)->AtlasBox):Void
    {
      for (o in area.getObjects())
        {
          if (!inside(m, o.x, o.y))
            continue;
          // the drain rides this pass rather than earning its own: it is the same question asked of
          // the same objects, and it is an OBJECT and not a tile for the reason `drain` records
          if (o.type == 'floor_drain')
            {
              m.drain[o.y][o.x] = true;
              continue;
            }
          if (o.type != 'decoration')
            continue;
          // the BENCH family rides this pass rather than earning its own, exactly as the drain
          // above does: same question, same objects, one walk. it takes the other branch, because a
          // table decoration has no fitting kind — it keeps its sprite. the ones that LIE DOWN are
          // left out: nothing stands there to cast a shadow
          if (Const.isTableDeco(o.imageRow))
            {
              // OCCUPANCY FIRST and outside the flat test, which is the whole point of the second
              // grid: the pool below is for a thing that STANDS, and the cell is spoken for either way
              m.tableTaken[o.y][o.x] = true;
              if (!Const.isFlatDeco(o.imageRow, o.imageCol))
                m.tableDeco[o.y][o.x] = FacilityDeco.poolOf(
                  icon != null ? icon(o.imageRow, o.imageCol) : null);
              continue;
            }
          var kind = Const.fittingOf(o.imageRow, o.imageCol);
          if (kind < 0)
            continue;
          m.deco[o.y][o.x] = kind + 1;
        }
    }

// does this cell hold a door OPENING? the wall pass treats one as the wall line carrying on rather
// than ending, so the flanking slabs meet the cell boundary and the opening stays one cell wide
  public static inline function isDoor(m:Facility, col:Int, row:Int):Bool
    {
      return inside(m, col, row) && m.door[row][col];
    }

// does this cell carry a laboratory bench? the emitter's own "does it carry on" test, and the one
// render.world.WorldCtx.ground reads to stand a table decoration on the worktop instead of the floor
  public static inline function isTable(m:Facility, col:Int, row:Int):Bool
    {
      return inside(m, col, row) && m.table[row][col];
    }

// does this cell stand a piece of 3D furniture? the gate render.facility.FacilityKit takes to keep a
// gas rack out of a shelving unit — one fitting to a tile
  public static inline function isFitting(m:Facility, col:Int, row:Int):Bool
    {
      return inside(m, col, row) && m.deco[row][col] > 0;
    }

// is this cell a doorway or touching one? the clearance test every INDOOR fitting shares — a cabinet
// run or a bin standing in a doorway's swing reads as blocking a door the player then walks through,
// and the leaves themselves sweep a cell either side (see FacilityDoors). diagonal counts: a fitting
// on the corner cell of a doorway is still in the way of everything coming through it
  public static function nearDoor(m:Facility, col:Int, row:Int):Bool
    {
      for (dr in -1...2)
        for (dc in -1...2)
          if (isDoor(m, col + dc, row + dr))
            return true;
      return false;
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
      if (closedCol == Const.FRAME_DOOR_PRIVATE)
        return PRIVATE;
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
      // park along the south and east edges. it is here for the WARM and not for the look: the four
      // ground surfaces all compile ONE program between them, but the lawn's two dressing layers
      // (render.facility.FacilityLawn) are permutations of their own, and with no GRASS on this grid
      // neither would be built at all and both would compile on the first real facility entry.
      // 144 cells rather than a token strip because the patch roll is a per-cell chance — too few and
      // the coverage bake comes back null and warms nothing
      for (row in 0...m.h)
        for (col in 0...m.w)
          if (row >= 12
            || col >= 20)
            m.surf[row][col] = GRASS;
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
      // one bench run against the north room's window wall and one island in the south room, so the
      // warm pass compiles both of render.facility.FacilityTables' materials
      for (col in 4...7)
        m.table[3][col] = true;
      for (row in 9...11)
        for (col in 13...16)
          m.table[row][col] = true;
      // one of each EMITTED fitting against the north room's own wall, clear of the bench run beside
      // them. stamped by hand for the reason the doors below are: findDeco reads live
      // objects.Decoration objects and there is no area here. these three and not all of them,
      // because what a cell here buys is a MATERIAL: the rack is the only kind emitting into the
      // second (additive, shader-patched) buffer, FIT_RACK_LOW is that same rack at another height,
      // FIT_CABINET and both FIT_MACHINE kinds take the bookcase's material config exactly (a mapped
      // FrontSide lambert, no vertex colour) and so compile no program of their own, and the round
      // kinds are instanced glbs warmed off FacilityWarm's own prop list instead
      m.deco[3][7] = _FittingKind.FIT_SHELVING + 1;
      m.deco[3][8] = _FittingKind.FIT_BOOKCASE + 1;
      m.deco[3][9] = _FittingKind.FIT_RACK + 1;
      // and one room of each TEMPLATE, because each is its own material: two wall textures, two floor
      // textures, the desk pair, the cubicle laminate, the mirror and the office clutter sheet are all
      // programs that would otherwise compile on the first real facility entry.
      //
      // the OFFICE is the south-west room, with a desk run against the ring wall so
      // FacilityTables.computerAt finds a hand and the workstation batch warms too
      for (row in 8...11)
        for (col in 3...10)
          m.surf[row][col] = OFFICE;
      for (col in 4...7)
        m.table[10][col] = true;
      // and the WASHROOM is the north-east one: a rank of cubicles against the ring wall and a basin
      // beside them, which between them warm the laminate, the sink sheet and the mirror
      for (row in 3...6)
        for (col in 11...19)
          m.surf[row][col] = WASH;
      m.deco[3][12] = _FittingKind.FIT_STALL + 1;
      m.deco[3][13] = _FittingKind.FIT_STALL + 1;
      m.deco[3][16] = _FittingKind.FIT_BASIN + 1;
      // the dividing wall between its two halves, and two LIGHT WELLS in the ring wall over it. the
      // wells are a material of their own (their own art, their own pane buffer) and the partition
      // rides the cubicle laminate, but both still have to EXIST here or the washroom's geometry is
      // first built on a real entry
      m.deco[4][15] = _FittingKind.FIT_PARTITION + 1;
      m.wall[2][14] = WINDOW_HIGH;
      m.wall[2][16] = WINDOW_HIGH;
      findStructures(m);
      findWindows(m);
      m.doors.push({
        col: 10,
        row: 4,
        alongX: false,
        inDir: 1,
        look: CABINET,
        front: false,
        structure: 0,
      });
      // and the south one is the ENTRANCE, so the warm pass also compiles the lobby notice board's
      // material. it is a single leaf with no mullion, which is deliberate: that is the fallback
      // branch of render.facility.FacilityBoard, and a grid with a mullion would never warm it
      m.doors.push({
        col: 5,
        row: 11,
        alongX: true,
        inDir: -1,
        look: GLASS,
        front: true,
        structure: 0,
      });
      // and one PRIVATE leaf, the washroom's own: a fourth look is a fourth material and a fourth
      // instanced batch, so without one here it compiles on the first compound that has a washroom
      m.doors.push({
        col: 14,
        row: 6,
        alongX: true,
        inDir: -1,
        look: PRIVATE,
        front: false,
        structure: 0,
      });
      for (d in m.doors)
        m.door[d.row][d.col] = true;
      return m;
    }
}
