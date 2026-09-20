// the corp tower's vocabulary: the temp tile alphabet, the map out of it, and the constants more
// than one pass reads
//
// GENERATION DOES NOT WRITE FINAL TILE IDS, it writes these TEMP_* marks and CorpGen.finalizeTiles
// rewrites them at the end — the same indirection gen.facility.FacilityTemp exists for, and for the
// same reason: a pass asks "is this an inner wall" with one comparison instead of against six
// autotiled masonry ids. A room TEMPLATE is the exception and writes final ids outright (a themed
// floor, a table tile), which finalize leaves alone by the OFFSET_CHEM_LAB test.
//
// THE NUMBERS 0..39 ARE game.CorpAreaGenerator'S, UNCHANGED. They were a block of loose static vars
// on that class; they are the same values here so a diff of the port is a diff of the structure and
// not of the alphabet. 40 and 41 are new.
//
// imported with `import gen.corp.CorpTemp.*;` everywhere under gen/corp and in the corp blocks.

package gen.corp;

import Const;

class CorpTemp
{
  public static inline var ROAD = 0;
  public static inline var WALKWAY = 1;
  public static inline var ALLEY = 2;
  public static inline var GRASS = 3;
  public static inline var CONCRETE = 4;
  // first building tile!
  public static inline var BLDG_WALL = 10;
  public static inline var BLDG_ROOM = 11;
  public static inline var BLDG_CORRIDOR = 12;
  public static inline var BLDG_ELEVATOR_DOOR = 13;
  public static inline var BLDG_INNER_WALL = 15;
  public static inline var BLDG_ROOM_MARKED = 16;
  public static inline var BLDG_INNER_DOOR = 17;
  public static inline var BLDG_WINDOW = 18;
  public static inline var BLDG_WINDOWH1 = 19;
  public static inline var BLDG_WINDOWH2 = 20;
  public static inline var BLDG_WINDOWH3 = 21;
  public static inline var BLDG_WINDOWV1 = 22;
  public static inline var BLDG_WINDOWV2 = 23;
  public static inline var BLDG_WINDOWV3 = 24;
  public static inline var BLDG_TABLE = 25;
  public static inline var BLDG_VENT = 26;
  public static inline var INNER_WINDOW = 27;
  public static inline var INNER_WINDOWH1 = 28;
  public static inline var INNER_WINDOWH2 = 29;
  public static inline var INNER_WINDOWH3 = 30;
  public static inline var INNER_WINDOWV1 = 31;
  public static inline var INNER_WINDOWV2 = 32;
  public static inline var INNER_WINDOWV3 = 33;
  public static inline var CARPET = 34;
  public static inline var WOOD1 = 35;
  public static inline var WOOD2 = 36;
  public static inline var MARBLE1 = 37;
  public static inline var MARBLE2 = 38;
  public static inline var CARPET_MEETING = 39;
  // the two floors the block tree added. MARBLE2 was already in the alphabet and in the map below
  // and no room had ever laid it, so the washroom took it and only these two are new
  public static inline var CUBICLE = 40;
  public static inline var SERVER = 41;

  // room ids are stamped into the grid as marks, above every temp id so the two never collide
  public static inline var BLDG_ROOM_ID_START = 100;

  // --- the constants more than one pass reads

  // how far apart the corridor branches, and the size a room is subdivided above. 9 + 1 wall
  public static inline var ROOM_SIZE = 10;
  // the main corridor's width in cells, and a side corridor's
  public static inline var CORRIDOR_W = 3;
  public static inline var SIDE_CORRIDOR_W = 2;
  // the tower floor plate, as a fraction of the area. it is one building and there is no split at
  // the area level: what the quota deals is ROOMS, not plots
  public static inline var PLATE_FRAC = 0.75;
  public static inline var PLATE_ORIGIN_FRAC = 0.1;

  // _Room.role, written per room by gen.blocks.CorpBlocks.assign and persisted through
  // generatorInfo. THE FLOOR TILE CARRIES THE SAME FACT and is what a reader of an old save gets —
  // these strings are the refinement, not the record
  public static inline var ROLE_OPEN = 'open';
  public static inline var ROLE_CUBICLE = 'cubicle';
  public static inline var ROLE_MEETING = 'meeting';
  public static inline var ROLE_KITCHEN = 'kitchen';
  public static inline var ROLE_EXEC = 'exec';
  public static inline var ROLE_TOILET = 'toilet';
  public static inline var ROLE_SERVERS = 'servers';

  // a corp floor tile's unwalkable twin sits exactly one tileset row below it (OFFSET_ROW12 ->
  // OFFSET_ROW13), which is how the furniture cells are addressed
  public static inline var UNWALKABLE_TILE_OFFSET = 16;

// the temp id -> final tile id map, used by CorpGen.finalizeTiles
  public static var finalTiles: Map<Int, Int> = [
    ROAD => Const.TILE_ROAD_UNWALKABLE,
    WALKWAY => Const.TILE_WALKWAY_UNWALKABLE,
    ALLEY => Const.TILE_ALLEY_UNWALKABLE,
    GRASS => Const.TILE_GRASS,
    CONCRETE => Const.TILE_FLOOR_CONCRETE,
    CARPET => Const.TILE_FLOOR_CARPET,
    CARPET_MEETING => Const.TILE_FLOOR_CARPET_MEETING,
    WOOD1 => Const.TILE_FLOOR_WOOD1,
    WOOD2 => Const.TILE_FLOOR_WOOD2,
    MARBLE1 => Const.TILE_FLOOR_MARBLE1,
    MARBLE2 => Const.TILE_FLOOR_MARBLE2,
    CUBICLE => Const.TILE_FLOOR_CUBICLE,
    SERVER => Const.TILE_FLOOR_SERVER,
    BLDG_WALL => Const.TILE_BUILDING,
    BLDG_ROOM => Const.TILE_FLOOR_CARPET,
    BLDG_CORRIDOR => Const.TILE_FLOOR_CARPET,
    BLDG_ELEVATOR_DOOR => Const.TILE_FLOOR_TILE_CANNOTSEE,
    BLDG_WINDOW => Const.TILE_CORP_WINDOW1,
    BLDG_WINDOWH1 => Const.TILE_CORP_WINDOWH1,
    BLDG_WINDOWH2 => Const.TILE_CORP_WINDOWH2,
    BLDG_WINDOWH3 => Const.TILE_CORP_WINDOWH3,
    BLDG_WINDOWV1 => Const.TILE_CORP_WINDOWV1,
    BLDG_WINDOWV2 => Const.TILE_CORP_WINDOWV2,
    BLDG_WINDOWV3 => Const.TILE_CORP_WINDOWV3,
    BLDG_INNER_WALL => Const.TILE_BUILDING,
    BLDG_INNER_DOOR => Const.TILE_FLOOR_CARPET,
    BLDG_VENT => Const.TILE_BUILDING,
    INNER_WINDOW => Const.TILE_CORP_INNER_WINDOW1,
    INNER_WINDOWH1 => Const.TILE_CORP_INNER_WINDOWH1,
    INNER_WINDOWH2 => Const.TILE_CORP_INNER_WINDOWH2,
    INNER_WINDOWH3 => Const.TILE_CORP_INNER_WINDOWH3,
    INNER_WINDOWV1 => Const.TILE_CORP_INNER_WINDOWV1,
    INNER_WINDOWV2 => Const.TILE_CORP_INNER_WINDOWV2,
    INNER_WINDOWV3 => Const.TILE_CORP_INNER_WINDOWV3,
  ];

  // one character per temp id, for game.AreaGenerator.printArea
  public static var mapTempTiles = [
    '0', '1', '2', '%', '%', '%', '%', '%', '%', '%',
    '#', 'r', '.', 'x', '+', '*', '8', 'X', 'w',
    '<', '-', '>', '^', '|', 'v', '_', 'Y', 'W',
    'a', 'b', 'c', 'A', 'B', 'C', 'k', 'd', 'o',
    'm', 'n', 'M', 'p', 's',
  ];
}
