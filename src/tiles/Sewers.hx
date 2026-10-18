// sewer tileset wrapper: sewer-specific walkability and wall ids

package tiles;

import Const;

class Sewers extends Tileset
{
  public static var OBJECTS_IMAGE = 'sewersObjects1';
  public static var OBJECTS_IMAGE_PATH = 'img/sewers-objects1.png';
  public static var SUMMONING_PORTAL: _IconBlock = {
    row: 0,
    col: 0,
    width: 2,
    height: 2,
  };
  public static var BROKEN_PORTAL: _IconBlock = {
    row: 0,
    col: 2,
    width: 2,
    height: 2,
  };
  public static var DEBRIS_LAYER_ID = 2; // splat layer id persisted in sewer saves
  public static var TILE_FLOOR = 901;
  public static var TILE_FLOOR_ALT = 900;
  public static var TILE_WALL_UPPER = 910;
  public static var TILE_WALL_LOWER = 911;
  public static var TILE_WALL_LEFT = 912;
  public static var TILE_WALL_RIGHT = 913;
  public static var TILE_WALL_INNER_TOP_LEFT = 914;
  public static var TILE_WALL_INNER_TOP_RIGHT = 915;
  public static var TILE_WALL_INNER_BOTTOM_LEFT = 916;
  public static var TILE_WALL_INNER_BOTTOM_RIGHT = 917;
  public static var TILE_WALL_OUTER_TOP_LEFT = 918;
  public static var TILE_WALL_OUTER_TOP_RIGHT = 919;
  public static var TILE_WALL_OUTER_BOTTOM_LEFT = 920;
  public static var TILE_WALL_OUTER_BOTTOM_RIGHT = 921;

// check whether tile id belongs to sewer tiles
  public static function isSewerTileID(tileID: Int): Bool
    {
      return (tileID == TILE_FLOOR ||
        tileID == TILE_FLOOR_ALT ||
        tileID == TILE_WALL_UPPER ||
        tileID == TILE_WALL_LOWER ||
        tileID == TILE_WALL_LEFT ||
        tileID == TILE_WALL_RIGHT ||
        tileID == TILE_WALL_INNER_TOP_LEFT ||
        tileID == TILE_WALL_INNER_TOP_RIGHT ||
        tileID == TILE_WALL_INNER_BOTTOM_LEFT ||
        tileID == TILE_WALL_INNER_BOTTOM_RIGHT ||
        tileID == TILE_WALL_OUTER_TOP_LEFT ||
        tileID == TILE_WALL_OUTER_TOP_RIGHT ||
        tileID == TILE_WALL_OUTER_BOTTOM_LEFT ||
        tileID == TILE_WALL_OUTER_BOTTOM_RIGHT);
    }

// sewer tile rules (no image: the tunnels only ever draw in 3D)
  public function new()
    {
      super();
      splatLayerID = DEBRIS_LAYER_ID;
    }

// check if sewer tile is walkable
  public override function isWalkable(tileID: Int): Bool
    {
      return (tileID == TILE_FLOOR ||
        tileID == TILE_FLOOR_ALT);
    }

// check if sewer tile can be seen through
  public override function canSeeThrough(tileID: Int): Bool
    {
      return (tileID == TILE_FLOOR ||
        tileID == TILE_FLOOR_ALT);
    }

// check if sewer tile id is a wall tile
  public override function isWallTile(tileID: Int): Bool
    {
      return (tileID == TILE_WALL_UPPER ||
        tileID == TILE_WALL_LOWER ||
        tileID == TILE_WALL_LEFT ||
        tileID == TILE_WALL_RIGHT ||
        tileID == TILE_WALL_INNER_TOP_LEFT ||
        tileID == TILE_WALL_INNER_TOP_RIGHT ||
        tileID == TILE_WALL_INNER_BOTTOM_LEFT ||
        tileID == TILE_WALL_INNER_BOTTOM_RIGHT ||
        tileID == TILE_WALL_OUTER_TOP_LEFT ||
        tileID == TILE_WALL_OUTER_TOP_RIGHT ||
        tileID == TILE_WALL_OUTER_BOTTOM_LEFT ||
        tileID == TILE_WALL_OUTER_BOTTOM_RIGHT);
    }
}
