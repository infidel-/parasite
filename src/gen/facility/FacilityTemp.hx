// the compound's vocabulary: the temp tile alphabet, the map out of it, and the handful of
// constants more than one pass reads
//
// GENERATION DOES NOT WRITE FINAL TILE IDS. It writes these TEMP_* marks, which are small dense
// integers a pass can compare and switch on, and FacilityGen.finalizeTiles rewrites them into
// Const.TILE_* at the very end. That indirection is what lets makeDoors ask "is this an inner wall"
// with one comparison rather than against six autotiled masonry ids.
//
// TEMP_BUILDING_VENT == TEMP_BUILDING_WINDOW == 18 DELIBERATELY, and the alphabet must not be
// renumbered: a vent IS a window opening until finalizeTiles decides which it became.
//
// imported with `import gen.facility.FacilityTemp.*;` everywhere under gen/facility and gen/blocks.
// No collision with `import game.AreaGenerator.*;`, which is always beside it: AreaGenerator's only
// class-level statics are DIR_*, deltaMap and ROAD_W.

package gen.facility;

import Const;

class FacilityTemp
{
  public static inline var TEMP_ROAD = 0;
  public static inline var TEMP_WALKWAY = 1;
  public static inline var TEMP_ALLEY = 2;
  public static inline var TEMP_GRASS = 3;
  public static inline var TEMP_CONCRETE = 4;
  public static inline var TEMP_GRASS_TREE = 5;
  public static inline var TEMP_GRASS_BUSH = 6;
  public static inline var TEMP_GRASS_BENCH = 7;
  // first building tile!
  public static inline var TEMP_BUILDING_WALL = 10;
  public static inline var TEMP_BUILDING_ROOM = 11;
  public static inline var TEMP_BUILDING_CORRIDOR = 12;
  public static inline var TEMP_BUILDING_FRONT_DOOR = 13;
  public static inline var TEMP_BUILDING_SIDE_DOOR = 14;
  public static inline var TEMP_BUILDING_INNER_WALL = 15;
  public static inline var TEMP_BUILDING_ROOM_MARKED = 16;
  public static inline var TEMP_BUILDING_INNER_DOOR = 17;
  public static inline var TEMP_BUILDING_WINDOW = 18;
  public static inline var TEMP_BUILDING_WINDOWH1 = 19;
  public static inline var TEMP_BUILDING_WINDOWH2 = 20;
  public static inline var TEMP_BUILDING_WINDOWH3 = 21;
  public static inline var TEMP_BUILDING_WINDOWV1 = 22;
  public static inline var TEMP_BUILDING_WINDOWV2 = 23;
  public static inline var TEMP_BUILDING_WINDOWV3 = 24;
  public static inline var TEMP_BUILDING_TABLE = 25;
  public static inline var TEMP_HANGAR_DOOR = 26;
  public static inline var TEMP_HANGAR_SIDE_DOOR = 27;
  public static inline var TEMP_BUILDING_VENT = 18;
  // the washroom's light well. its own temp id and not one of the six window ones, because it is not
  // part of a RUN: each cell is a separate opening and the renderer maps one image across each
  public static inline var TEMP_BUILDING_WINDOW_HIGH = 28;

  // the car park's own mark. it is written over a plot that is already TEMP_ALLEY and differs from it
  // in nothing but name — the compound is blanked to open lot before anything is cut, so the yard,
  // the gaps between plots and the lot you drive into were one tile and the renderer painted bays on
  // all three. See Const.TILE_PARKING. The ENTRYWAY child stays TEMP_ALLEY: the mouth through the
  // pavement is what game.AreaGame.gate() finds the checkpoint by, and it looks for alley
  public static inline var TEMP_PARKING = 29;

  // the boom barrier's own row, across the gate mouth: the same asphalt with the walkable bit taken
  // off it (Const.TILE_ALLEY_UNWALKABLE, which game.CorpAreaGenerator already writes and tiles.Default
  // already has an icon and a 0 for). render.facility.FacilityEntry stands the arm and its cabinet on
  // the mouth row nearest the lot and both used to be pure decoration — a bar the player walked
  // through. It is one row of the ENTRYWAY rect and nothing else, so the mouth is still exactly
  // RoadBlock.ENTRY_W by SIDEWALK_W and the pavement either side of it is still walkable: a compound
  // is not sealed by this, a car park is
  public static inline var TEMP_BARRIER = 30;

  // and a PARKED CAR's footprint: TEMP_CAR over the whole bay, TEMP_CAR_ORIGIN on the one cell of it
  // that is the bay's low corner against the kerb. See Const.TILE_PARKING_CAR for why the origin is
  // a mark of its own rather than something the renderer walks out of the run
  public static inline var TEMP_CAR = 31;
  public static inline var TEMP_CAR_ORIGIN = 32;

  // room ids are stamped into the grid as marks, above every temp id so the two never collide
  public static inline var TEMP_BUILDING_ROOM_ID_START = 100;

  // --- the constants more than one pass reads. everything else lives with its owner: PARK_* on
  // gen.blocks.ParkBlock, HANGAR_GAP on HangarBlock, TOILET_STALL_MAX on FacilityToilet, the office
  // and bench numbers on FacilityRooms

  public static inline var ROOM_SIZE = 7; // 6 + 1 wall
  // the two room templates besides the laboratory, written into _Room.role. a null role is a lab
  public static inline var ROLE_CABINET = 'cabinet';
  public static inline var ROLE_TOILET = 'toilet';
  // a floor tile's unwalkable twin sits exactly one tileset row below it (Const.OFFSET_ROW12 ->
  // OFFSET_ROW13), which is how game.CorpAreaGenerator addresses the pair too
  public static inline var UNWALKABLE_TILE_OFFSET = 16;

// does this doorway open onto a themed room — a washroom or a researcher's office? the floor tile is
// the theme record (see FacilityRooms.assignRoomThemes), so this is a four-neighbour test on the
// FINAL ids the templates painted, walkable cell or the unwalkable twin one tileset row below.
//
// it lives here rather than with either caller because BOTH sides want it: FacilityGen.finalizeTiles
// picks a door leaf with it, and FacilityConnect.cutDoorToReached picks one for the door it cuts
// after finalize has already run
  public static function opensOnPrivateRoom(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      for (i in 0...Const.dir4x.length)
        {
          var tile = cells[x + Const.dir4x[i]][y + Const.dir4y[i]];
          if (tile == Const.TILE_FLOOR_WOOD1 ||
              tile == Const.TILE_FLOOR_WOOD1 + UNWALKABLE_TILE_OFFSET ||
              tile == Const.TILE_FLOOR_MARBLE1 ||
              tile == Const.TILE_FLOOR_MARBLE1 + UNWALKABLE_TILE_OFFSET)
            return true;
        }
      return false;
    }

// the temp id -> final tile id map, used by FacilityGen.finalizeTiles.
//
// A STATIC INITIALIZER AND NOT A CONSTRUCTOR. This used to be a static populated by
// game.FacilityAreaGenerator's INSTANCE constructor, which meant every static pass silently required
// somebody to have built one first — the headless oracle had to write
// `new FacilityAreaGenerator(null, null)` purely to fill this table. Same latent bug as
// game.AreaGenerator.deltaMap had, fixed the same way
  public static var finalTiles: Map<Int, Int> = [
    TEMP_ROAD => Const.TILE_ROAD,
    TEMP_WALKWAY => Const.TILE_WALKWAY,
    TEMP_ALLEY => Const.TILE_ALLEY,
    TEMP_PARKING => Const.TILE_PARKING,
    TEMP_BARRIER => Const.TILE_ALLEY_UNWALKABLE,
    TEMP_CAR => Const.TILE_PARKING_CAR,
    TEMP_CAR_ORIGIN => Const.TILE_PARKING_CAR_ORIGIN,
    TEMP_GRASS => Const.TILE_GRASS,
    TEMP_GRASS_BUSH => Const.TILE_BUSH,
    TEMP_GRASS_BENCH => Const.TILE_GRASS_UNWALKABLE,
    TEMP_CONCRETE => Const.TILE_FLOOR_CONCRETE,
    TEMP_BUILDING_WALL => Const.TILE_BUILDING,
    TEMP_BUILDING_ROOM => Const.TILE_FLOOR_TILE,
    TEMP_BUILDING_CORRIDOR => Const.TILE_FLOOR_LINO,
    TEMP_BUILDING_FRONT_DOOR => Const.TILE_FLOOR_LINO,
    TEMP_BUILDING_SIDE_DOOR => Const.TILE_FLOOR_LINO,
    TEMP_BUILDING_WINDOWH1 => Const.TILE_WINDOWH1,
    TEMP_BUILDING_WINDOWH2 => Const.TILE_WINDOWH2,
    TEMP_BUILDING_WINDOWH3 => Const.TILE_WINDOWH3,
    TEMP_BUILDING_WINDOWV1 => Const.TILE_WINDOWV1,
    TEMP_BUILDING_WINDOWV2 => Const.TILE_WINDOWV2,
    TEMP_BUILDING_WINDOWV3 => Const.TILE_WINDOWV3,
    TEMP_BUILDING_INNER_WALL => Const.TILE_BUILDING,
    TEMP_BUILDING_INNER_DOOR => Const.TILE_FLOOR_LINO,
    TEMP_HANGAR_DOOR => Const.TILE_HANGAR_DOOR,
    TEMP_HANGAR_SIDE_DOOR => Const.TILE_FLOOR_TILE_CANNOTSEE,
    // this row is TEMP_BUILDING_WINDOW's too — the two ids ARE 18, and every cell carrying it ends
    // up masonry with a vent object standing on it. There used to be a
    // `TEMP_BUILDING_WINDOW => TILE_WINDOW1` row above as well; it was dead, because a map literal
    // keeps the LAST value written for a key and this one is it
    TEMP_BUILDING_VENT => Const.TILE_BUILDING,
    TEMP_BUILDING_WINDOW_HIGH => Const.TILE_WINDOW_HIGH,
  ];

  // one character per temp id, for game.AreaGenerator.printArea
  public static var mapTempTiles = [
    '0', '1', '2', '%', '%', 't', 'b', 'B', '%', '%',
    '#', 'r', '.', 'x', '+', '*', '8', 'X', 'w',
    '<', '-', '>', '^', '|', 'v', '_', 'Y', 'Z', '=',
    'P', '!', 'c', 'C',
  ];
}
