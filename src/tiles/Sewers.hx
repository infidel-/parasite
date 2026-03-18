// sewer tileset wrapper with sewer-specific floor and wall mapping

package tiles;

import Const;
import haxe.ds.StringMap;

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
  public static var FLOOR_DECOR_LAYER_ID = 0;
  public static var FLOOR_DECOR_EXTRA_LAYER_ID = 1;
  public static var DEBRIS_LAYER_ID = 2;
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

  public static var FLOOR_DECOR_META: Array<_FloorDecorMeta> = [
    { icon: { row: 3, col: 1 }, motifs: ['green-puddle', 'spill', 'grime'], roles: ['vat', 'workshop', 'storage'], baseWeight: 98 },
    { icon: { row: 3, col: 3 }, motifs: ['scratches', 'grime'], roles: ['entrance', 'storage', 'workshop'], baseWeight: 86 },
    { icon: { row: 3, col: 4 }, motifs: ['scratches', 'grime'], roles: ['entrance', 'storage', 'workshop'], baseWeight: 85 },
    { icon: { row: 3, col: 5 }, motifs: ['scratches', 'grime'], roles: ['entrance', 'storage', 'workshop'], baseWeight: 84 },
    { icon: { row: 4, col: 1 }, motifs: ['crack', 'grime'], roles: ['entrance', 'storage', 'workshop'], baseWeight: 88 },
    { icon: { row: 4, col: 2 }, motifs: ['brown-puddle', 'spill', 'grime'], roles: ['vat', 'workshop', 'storage'], baseWeight: 97 },
    { icon: { row: 4, col: 3 }, motifs: ['floor-grate', 'machinery'], roles: ['workshop', 'vat', 'research'], baseWeight: 102 },
    { icon: { row: 4, col: 4 }, motifs: ['purple-puddle', 'spill', 'grime'], roles: ['vat', 'workshop', 'storage'], baseWeight: 96 },
    { icon: { row: 4, col: 5 }, motifs: ['scratches', 'grime'], roles: ['entrance', 'storage', 'workshop'], baseWeight: 83 },
    { icon: { row: 4, col: 6 }, motifs: ['scratches', 'grime'], roles: ['entrance', 'storage', 'workshop'], baseWeight: 82 },
    { icon: { row: 5, col: 0 }, motifs: ['floor-grate', 'machinery'], roles: ['workshop', 'vat', 'research'], baseWeight: 101 },
    { icon: { row: 5, col: 1 }, motifs: ['floor-grate', 'machinery'], roles: ['workshop', 'vat', 'research'], baseWeight: 100 },
    { icon: { row: 5, col: 2 }, motifs: ['floor-hatch', 'machinery'], roles: ['workshop', 'vat', 'research'], baseWeight: 104 },
    { icon: { row: 5, col: 3 }, motifs: ['black-puddle', 'spill', 'grime'], roles: ['vat', 'workshop', 'storage'], baseWeight: 98 },
    { icon: { row: 5, col: 4 }, motifs: ['puddle', 'spill', 'grime'], roles: ['vat', 'workshop', 'storage'], baseWeight: 95 },
    { icon: { row: 5, col: 5 }, motifs: ['puddle', 'spill', 'grime'], roles: ['vat', 'workshop', 'storage'], baseWeight: 94 },
    { icon: { row: 5, col: 6 }, motifs: ['floor-grate', 'machinery'], roles: ['workshop', 'vat', 'research'], baseWeight: 99 },
  ];

  public static var FLOOR_DECOR_EXTRA_ICONS(get, never): Array<_Icon>;
  static var floorDecorExtraIconsCache: Array<_Icon>;

  public var floor: StringMap<_Icon>;
  public var walls: _WallMap;
  public var wallID: _WallMapID;
  var iconByTileID: Map<Int, _Icon>;

// load sewer tileset image and minimal sewer decoration layers
  public function new()
    {
      super('img/sewers.png');
      voidTile = {
        col: 1,
        row: 1,
      };
      floor = new StringMap<_Icon>();
      iconByTileID = new Map<Int, _Icon>();
      initFloor();
      initWalls();
      addFloorDecorationLayer('img/sewers-deco-floor1.png', []);
      addFloorDecorationLayer('img/sewers.png', FLOOR_DECOR_EXTRA_ICONS);
      addFloorDecorationLayer('img/entities64.png', []);
      splatLayerID = DEBRIS_LAYER_ID;
    }

// build sewer floor decoration icon list from sewer base tileset rows
  static function get_FLOOR_DECOR_EXTRA_ICONS(): Array<_Icon>
    {
      if (floorDecorExtraIconsCache == null)
        floorDecorExtraIconsCache = buildFloorDecorExtraIcons();
      return floorDecorExtraIconsCache;
    }

// collect extra sewer floor decoration icons from sewer base image rows
  static function buildFloorDecorExtraIcons(): Array<_Icon>
    {
      var icons = [];
      for (row in 3...6)
        for (col in 0...8)
          icons.push({
            row: row,
            col: col,
          });
      for (col in 0...7)
        icons.push({
          row: 6,
          col: col,
        });
      return icons;
    }

// initialize sewer floor icon map
  function initFloor()
    {
      floor.set('base', {
        col: 3,
        row: 0,
      });
      iconByTileID[TILE_FLOOR] = floor.get('base');
      iconByTileID[TILE_FLOOR_ALT] = floor.get('base');
    }

// initialize sewer wall icon and tile id maps
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

// map sewer tile id to icon coordinates
  public override function getIcon(tileID: Int): _Icon
    {
      if (tileID == Const.TILE_HIDDEN)
        return voidTile;
      var icon = iconByTileID[tileID];
      if (icon != null)
        return icon;
      return voidTile;
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

// check if sewer wall tile is horizontal
  public override function isHorizontalWallTile(tileID: Int): Bool
    {
      return (tileID == TILE_WALL_UPPER ||
        tileID == TILE_WALL_LOWER);
    }

// check if sewer wall tile is vertical
  public override function isVerticalWallTile(tileID: Int): Bool
    {
      return (tileID == TILE_WALL_LEFT ||
        tileID == TILE_WALL_RIGHT);
    }

// sewer floor decorations and debris never block movement
  public override function isBlockingDecoration(tileID: Int, decoration: tiles.Decoration): Bool
    {
      return false;
    }
}
