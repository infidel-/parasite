package citygen;

import citygen.CityModel.Tile;

// grid + procedural-generation constants and world<->grid mapping; pure, no three
class CityConfig {
  public static inline var GRID = 100;   // grid is GRID x GRID cells (game city size)
  public static inline var CELL = 4;     // world units per cell

  // --- procedural city knobs (see CityGen for the algorithm) ----------------
  public static inline var ROAD_W = 2;                  // normal road width
  public static inline var MAIN_ROAD_W = 4;             // main road width (one per axis, random spot)
  public static inline var DEADEND_CHANCE = 0.7;       // chance a non-main interior vertical road dead-ends (drops its terminal block-band)
  public static inline var TURN_CHANCE = 0.55;         // chance a non-main interior vertical road makes an L-turn mid-block into a neighbour road (tried before dead-end)
  public static inline var SETBACK = 1;                 // pavement gap between buildings and roads
  public static inline var MIN_BLOCK = 8;               // block size varies in [MIN_BLOCK, MAX_BLOCK] cells (road pitch = ROAD_W + this)
  public static inline var MAX_BLOCK = 20;              // upper bound of that block-size range
  public static inline var SUBDIV_DEPTH = 5;            // recursion depth (enough for force-split to resolve big blocks)
  public static inline var EARLY_LEAF_CHANCE = 0.3;     // chance a mid-size splittable block stops subdividing (big leaves feed the shaped-building rolls)
  public static inline var SPLIT_OVER = 12;             // blocks wider/deeper than this MUST split (no full-block giants)
  public static inline var MAX_BUILDING = 8;            // hard cap: no building/shape piece bigger than this on either axis
  public static inline var COURTYARD_CHANCE = 0.3;      // chance a big-enough leaf becomes a U-shaped courtyard
  public static inline var COURTYARD_WALL = 2;          // courtyard wall-strip thickness (cells)
  public static inline var L_CHANCE = 0.35;             // chance a big non-full-block leaf becomes an L (back courtyard)
  public static inline var T_CHANCE = 0.6;             // chance a big leaf becomes a T (crossbar + shorter centred stem)
  public static inline var PLUS_CHANCE = 0.85;         // chance a big leaf becomes a + (crossing bars, optional taller centre; rolled last, so high)
  public static inline var COURTYARD_BLOCK_CHANCE = 0.35; // chance to try carving a central courtyard out of a finished block
  public static inline var COURT_RING = 3;             // min cells kept between the courtyard and the block edge
  public static inline var COURT_MIN = 3;              // min courtyard side
  public static inline var CARVE_TRIES = 16;           // attempts to find a carve that leaves no size-1 buildings
  public static inline var MAX_LAMPS = 16;             // cap on placed street lamps

  // floors: a storefront ground band + stacked window floors on a shared vertical
  // grid (so neighbours line up); height is quantized to whole floors. GROUND_H ==
  // CELL so the square storefront bay divides every wall into a whole number of bays
  public static inline var GROUND_H = CELL;   // storefront band height = bay width = one cell (4)
  public static inline var FLOOR_H = 3.6;     // floor-to-floor height for window floors above
  public static inline var TOP_MARGIN = 1.2;  // bare wall strip above the top window so it clears the parapet
  public static inline var MIN_FLOORS = 2;    // fewest window floors a building can have
  public static inline var MAX_FLOORS = 7;    // most window floors a building can have (global draw pool)
  public static inline var MAX_FLOORS_BRICK = 5; // brick buildings cap at 6 storeys incl ground (5 window floors)
  // per-facade window-floor cap by Building.facade [concrete, brick, stone, metal]:
  // concrete tall, brick+stone masonry shorter, metal squat (corrugated steel =
  // low industrial warehouse/workshop, never a mid-rise)
  public static final MAX_FLOORS_VARIANT = [7, 5, 5, 2];

  // single-story shop downgrade: small footprints (fit within 3×2) may drop to a
  // one-story commercial structure (diner/corner store/garage/laundromat)
  public static inline var DOWNGRADE_CHANCE = 0.35; // chance a small footprint becomes a single-story shop
  public static inline var SHOP_OPEN_CHANCE = 0.6;  // chance a downgraded shop is "open" (lit at night)
  public static inline var SHOP_TYPES = 4;          // diner, corner, garage, laundromat
  // shop height: raised so a 16:9 storefront bay fills the face width edge-to-edge.
  // one storefront bay = 2 cells wide (2*CELL), 16:9 → height = 2*CELL * 9/16 = 4.5 at CELL=4.
  public static inline var SHOP_H = 2 * CELL * 9 / 16;

  // a plain rectangle wider than BIG_W on one side and deeper than BIG_D on both is
  // reshaped into an L or a central-courtyard (P) ring — no oversized blank boxes
  public static inline var BIG_W = 8;
  public static inline var BIG_D = 6;

  // world <-> grid mapping (grid centered on origin)
  public static inline function cellToWorld(col:Float, row:Float):{x:Float, z:Float} {
    return { x: (col - GRID / 2 + 0.5) * CELL, z: (row - GRID / 2 + 0.5) * CELL };
  }

  // inverse of cellToWorld: nearest grid cell for a world x/z (unclamped)
  public static inline function worldToCell(x:Float, z:Float):{col:Int, row:Int} {
    return { col: Std.int(Math.round(x / CELL + GRID / 2 - 0.5)),
             row: Std.int(Math.round(z / CELL + GRID / 2 - 0.5)) };
  }

  // walkability grid: true = walkable (road/walkway/alley, not building)
  public static function buildWalkable(tiles:Array<Array<Tile>>):Array<Array<Bool>> {
    return [for (row in tiles) [for (t in row) t != Tile.Building]];
  }
}
