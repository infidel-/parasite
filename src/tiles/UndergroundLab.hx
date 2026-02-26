// underground lab tileset wrapper with custom tile mapping

package tiles;

import Const;
import haxe.ds.StringMap;

class UndergroundLab extends Tileset
{
  public static var TILE_FLOOR_LIGHT = 900;
  public static var TILE_FLOOR_DARK = 901;
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

  public var floor: StringMap<_Icon>;
  public var floorID: StringMap<Int>;
  public var walls: _WallMap;
  public var wallID: _WallMapID;
  var iconByTileID: Map<Int, _Icon>;

// load underground tileset image and tile mapping
  public function new()
    {
      super('img/underground-lab.png');
      voidTile = {
        col: 1,
        row: 1,
      };
      floor = new StringMap<_Icon>();
      floorID = new StringMap<Int>();
      iconByTileID = new Map<Int, _Icon>();
      initFloor();
      initWalls();
      addFloorDecorationLayer('img/underground-lab-decoration-tiles1.png',
        [], [3, 4, 5]);
      addWallDecorationLayerRepeat('img/underground-lab-decoration1.png', 4);
      addWallDecorationLayerChance('img/underground-lab-decoration2.png', 80);
      addWallDecorationLayerChance('img/underground-lab-decoration3.png', 10);
      addWallDecorationLayerChance('img/underground-lab-decoration4.png', 20);
      addWallDecorationLayerRepeat('img/underground-lab-decoration5.png', 2);
    }

// initialize floor icon and tile id maps
  function initFloor()
    {
      floor.set('light', {
        col: 4,
        row: 0,
      });
      floor.set('dark', {
        col: 3,
        row: 0,
      });
      floorID.set('light', TILE_FLOOR_LIGHT);
      floorID.set('dark', TILE_FLOOR_DARK);
      iconByTileID[TILE_FLOOR_LIGHT] = floor.get('light');
      iconByTileID[TILE_FLOOR_DARK] = floor.get('dark');
    }

// initialize wall icon and tile id maps
  function initWalls()
    {
      walls = {
        upper: { col: 1, row: 2 },
        lower: { col: 1, row: 0 },
        left: { col: 2, row: 1 },
        right: { col: 0, row: 1 },
        innerTopLeft: { col: 2, row: 2 },
        innerTopRight: { col: 0, row: 2 },
        innerBottomLeft: { col: 2, row: 0 },
        innerBottomRight: { col: 0, row: 0 },
        outerTopLeft: { col: 4, row: 2 }, 
        outerTopRight: { col: 3, row: 2 }, 
        outerBottomLeft: { col: 4, row: 1 },
        outerBottomRight: { col: 3, row: 1 },
      };
      wallID = {
        upper: TILE_WALL_UPPER,
        lower: TILE_WALL_LOWER,
        left: TILE_WALL_LEFT,
        right: TILE_WALL_RIGHT,
        innerTopLeft: TILE_WALL_INNER_TOP_LEFT,
        innerTopRight: TILE_WALL_INNER_TOP_RIGHT,
        innerBottomLeft: TILE_WALL_INNER_BOTTOM_LEFT,
        innerBottomRight: TILE_WALL_INNER_BOTTOM_RIGHT,
        outerTopLeft: TILE_WALL_OUTER_TOP_LEFT,
        outerTopRight: TILE_WALL_OUTER_TOP_RIGHT,
        outerBottomLeft: TILE_WALL_OUTER_BOTTOM_LEFT,
        outerBottomRight: TILE_WALL_OUTER_BOTTOM_RIGHT,
      };

      iconByTileID[wallID.upper] = walls.upper;
      iconByTileID[wallID.lower] = walls.lower;
      iconByTileID[wallID.left] = walls.left;
      iconByTileID[wallID.right] = walls.right;
      iconByTileID[wallID.innerTopLeft] = walls.innerTopLeft;
      iconByTileID[wallID.innerTopRight] = walls.innerTopRight;
      iconByTileID[wallID.innerBottomLeft] = walls.innerBottomLeft;
      iconByTileID[wallID.innerBottomRight] = walls.innerBottomRight;
      iconByTileID[wallID.outerTopLeft] = walls.outerTopLeft;
      iconByTileID[wallID.outerTopRight] = walls.outerTopRight;
      iconByTileID[wallID.outerBottomLeft] = walls.outerBottomLeft;
      iconByTileID[wallID.outerBottomRight] = walls.outerBottomRight;
    }

// map tile id to underground icon coordinates
  public override function getIcon(tileID: Int): _Icon
    {
      if (tileID == Const.TILE_HIDDEN)
        return voidTile;
      var icon = iconByTileID[tileID];
      if (icon != null)
        return icon;
      return voidTile;
    }

// check if underground tile is walkable
  public override function isWalkable(tileID: Int): Bool
    {
      return (tileID == TILE_FLOOR_LIGHT ||
        tileID == TILE_FLOOR_DARK);
    }

// check if underground tile can be seen through
  public override function canSeeThrough(tileID: Int): Bool
    {
      return (tileID == TILE_FLOOR_LIGHT ||
        tileID == TILE_FLOOR_DARK);
    }

// check if underground tile id is a wall tile
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

// check if underground wall tile is horizontal
  public override function isHorizontalWallTile(tileID: Int): Bool
    {
      return (tileID == TILE_WALL_UPPER ||
        tileID == TILE_WALL_LOWER);
    }

// check if underground wall tile is vertical
  public override function isVerticalWallTile(tileID: Int): Bool
    {
      return (tileID == TILE_WALL_LEFT ||
        tileID == TILE_WALL_RIGHT);
    }
}
