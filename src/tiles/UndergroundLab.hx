// underground lab tileset wrapper with custom tile mapping

package tiles;

import Const;
import _AtmosphereLightMeta;
import _IconBlock;
import haxe.ds.StringMap;

typedef _DecorMeta = {
  var id: String;
  var tags: Array<String>;
  var motifs: Array<String>;
  var roles: Array<String>;
  @:optional var imageKey: String;
  @:optional var light: _AtmosphereLightMeta;
  var baseWeight: Int;
  var minZoneWeight: Int;
  var maxZoneWeight: Int;
}

typedef _DecorBlock = {
  var block: _IconBlock;
  var meta: _DecorMeta;
}

typedef _FloorDecorMeta = {
  var icon: _Icon;
  var motifs: Array<String>;
  var roles: Array<String>;
  @:optional var light: _AtmosphereLightMeta;
  var baseWeight: Int;
}

class UndergroundLab extends Tileset
{
  public static var OBJECTS_IMAGE = 'undergroundLabObjects1';
  public static var OBJECTS_IMAGE_PATH = 'img/underground-lab-objects1.png';
  public static var NEAR_TOP_WALL_IMAGE_PATH = 'img/underground-lab-deco-near-top.png';
  public static var DECORATION_OBJ_IMAGE_KEY_1 = 'decor-obj-1';
  public static var DECORATION_OBJ_IMAGE_PATH_1 = 'img/underground-lab-deco-obj1.png';
  public static var DECORATION_OBJ_IMAGE_KEY_2 = 'decor-obj-2';
  public static var DECORATION_OBJ_IMAGE_PATH_2 = 'img/underground-lab-deco-obj2.png';
  public static var DOOR_HORIZONTAL_CLOSED_LEFT: _Icon = { row: 6, col: 0 };
  public static var DOOR_HORIZONTAL_CLOSED_RIGHT: _Icon = { row: 6, col: 1 };
  public static var DOOR_HORIZONTAL_OPEN_LEFT: _Icon = { row: 7, col: 0 };
  public static var DOOR_HORIZONTAL_OPEN_RIGHT: _Icon = { row: 7, col: 1 };
  public static var DOOR_VERTICAL_CLOSED_UPPER: _Icon = { row: 6, col: 2 };
  public static var DOOR_VERTICAL_CLOSED_LOWER: _Icon = { row: 7, col: 2 };
  public static var DOOR_VERTICAL_OPEN_UPPER: _Icon = { row: 6, col: 3 };
  public static var DOOR_VERTICAL_OPEN_LOWER: _Icon = { row: 7, col: 3 };
  // NOTE: flushed cloning vat is +2 col from regular vat
  public static var CLONING_VAT: _IconBlock =
    { row: 6, col: 4, width: 2, height: 3 };
  public static var ELEVATOR: _IconBlock =
    { row: 8, col: 0, width: 2, height: 2 };
  // base darkness alpha applied before light cutouts (higher = darker)
  public static var ATMOS_BASE_ALPHA = 0.50;
  // edge darkening alpha used by radial vignette (higher = darker)
  public static var ATMOS_VIGNETTE_ALPHA = 0.10;
  public static var ATMOS_LIGHT_RADIUS_SMALL = 1.1;
  public static var ATMOS_LIGHT_RADIUS_LARGE = 2.4;
  public static var ATMOS_LIGHT_SMALL_GREEN: _AtmosphereLightMeta = {
    radiusTiles: ATMOS_LIGHT_RADIUS_SMALL,
    intensity: 0.72,
    tintR: 0,
    tintG: 255,
    tintB: 24,
  };
  public static var ATMOS_LIGHT_SMALL_CYAN: _AtmosphereLightMeta = {
    radiusTiles: ATMOS_LIGHT_RADIUS_SMALL,
    intensity: 0.72,
    tintR: 0,
    tintG: 255,
    tintB: 255,
  };
  public static var ATMOS_LIGHT_SMALL_BLUE: _AtmosphereLightMeta = {
    radiusTiles: ATMOS_LIGHT_RADIUS_SMALL,
    intensity: 0.72,
    tintR: 0,
    tintG: 96,
    tintB: 255,
  };
  public static var ATMOS_LIGHT_LARGE_GREEN: _AtmosphereLightMeta = {
    radiusTiles: ATMOS_LIGHT_RADIUS_LARGE,
    intensity: 0.88,
    tintR: 0,
    tintG: 255,
    tintB: 36,
  };
  public static var ATMOS_LIGHT_LARGE_ORANGE: _AtmosphereLightMeta = {
    radiusTiles: ATMOS_LIGHT_RADIUS_LARGE,
    intensity: 0.88,
    tintR: 255,
    tintG: 140,
    tintB: 0,
  };
  public static var ATMOS_LIGHT_LARGE_BLUE: _AtmosphereLightMeta = {
    radiusTiles: ATMOS_LIGHT_RADIUS_LARGE,
    intensity: 0.88,
    tintR: 0,
    tintG: 120,
    tintB: 255,
  };

  public static var NEAR_TOP_WALL_META: Array<_DecorBlock> = [
    {
      block: { row: 0, col: 0, width: 1, height: 2 },
      meta: {
        id: 'near-top-closet-1',
        tags: ['wall', 'closet', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'workshop', 'entrance'],
        baseWeight: 100,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 0, col: 1, width: 1, height: 2 },
      meta: {
        id: 'near-top-closet-2',
        tags: ['wall', 'closet', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'workshop', 'entrance'],
        baseWeight: 102,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 0, col: 2, width: 1, height: 2 },
      meta: {
        id: 'near-top-closet-3',
        tags: ['wall', 'closet', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'workshop', 'entrance'],
        baseWeight: 98,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 0, col: 3, width: 1, height: 2 },
      meta: {
        id: 'near-top-closet-4',
        tags: ['wall', 'closet', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'workshop', 'entrance'],
        baseWeight: 96,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 0, col: 4, width: 1, height: 2 },
      meta: {
        id: 'near-top-plant-1',
        tags: ['wall', 'plant'],
        motifs: ['furniture'],
        roles: ['entrance', 'research', 'storage'],
        light: ATMOS_LIGHT_SMALL_BLUE,
        baseWeight: 90,
        minZoneWeight: 0,
        maxZoneWeight: 200,
      },
    },
    {
      block: { row: 0, col: 5, width: 1, height: 2 },
      meta: {
        id: 'near-top-plant-2',
        tags: ['wall', 'plant'],
        motifs: ['furniture'],
        roles: ['entrance', 'research', 'storage'],
        baseWeight: 88,
        minZoneWeight: 0,
        maxZoneWeight: 200,
      },
    },
    {
      block: { row: 0, col: 6, width: 1, height: 2 },
      meta: {
        id: 'near-top-plant-3',
        tags: ['wall', 'plant'],
        motifs: ['furniture'],
        roles: ['entrance', 'research', 'storage'],
        baseWeight: 86,
        minZoneWeight: 0,
        maxZoneWeight: 200,
      },
    },
    {
      block: { row: 0, col: 7, width: 1, height: 2 },
      meta: {
        id: 'near-top-plant-4',
        tags: ['wall', 'plant'],
        motifs: ['furniture'],
        roles: ['entrance', 'research', 'storage'],
        baseWeight: 84,
        minZoneWeight: 0,
        maxZoneWeight: 200,
      },
    },
  ];

  public static var DECORATION_OBJ_META: Array<_DecorBlock> = [
    {
      block: { row: 2, col: 0, width: 1, height: 1 },
      meta: {
        id: 'object-terminal-1',
        tags: ['object', 'computer', 'terminal'],
        motifs: ['machinery', 'research'],
        roles: ['workshop', 'research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        light: ATMOS_LIGHT_SMALL_GREEN,
        baseWeight: 110,
        minZoneWeight: 0,
        maxZoneWeight: 260,
      },
    },
    {
      block: { row: 2, col: 1, width: 1, height: 1 },
      meta: {
        id: 'object-terminal-2',
        tags: ['object', 'computer', 'terminal'],
        motifs: ['machinery', 'research'],
        roles: ['workshop', 'research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        light: ATMOS_LIGHT_SMALL_BLUE,
        baseWeight: 108,
        minZoneWeight: 0,
        maxZoneWeight: 260,
      },
    },
    {
      block: { row: 2, col: 2, width: 1, height: 1 },
      meta: {
        id: 'object-terminal-3',
        tags: ['object', 'computer', 'terminal'],
        motifs: ['machinery', 'research'],
        roles: ['workshop', 'research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        light: ATMOS_LIGHT_SMALL_GREEN,
        baseWeight: 106,
        minZoneWeight: 0,
        maxZoneWeight: 260,
      },
    },
    {
      block: { row: 2, col: 3, width: 1, height: 1 },
      meta: {
        id: 'object-terminal-4',
        tags: ['object', 'computer', 'terminal'],
        motifs: ['machinery', 'research'],
        roles: ['workshop', 'research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        light: ATMOS_LIGHT_SMALL_GREEN,
        baseWeight: 104,
        minZoneWeight: 0,
        maxZoneWeight: 260,
      },
    },
    {
      block: { row: 0, col: 7, width: 1, height: 1 },
      meta: {
        id: 'object-crate-1',
        tags: ['object', 'crate'],
        motifs: ['storage'],
        roles: ['storage', 'workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        baseWeight: 98,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 1, col: 7, width: 1, height: 1 },
      meta: {
        id: 'object-crate-2',
        tags: ['object', 'crate'],
        motifs: ['storage'],
        roles: ['storage', 'workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        baseWeight: 97,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 4, col: 7, width: 1, height: 1 },
      meta: {
        id: 'object-crate-3',
        tags: ['object', 'crate'],
        motifs: ['storage'],
        roles: ['storage', 'workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        baseWeight: 99,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 3, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-computer-table-1',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['workshop', 'vat', 'research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        light: ATMOS_LIGHT_SMALL_CYAN,
        baseWeight: 150,
        minZoneWeight: 0,
        maxZoneWeight: 340,
      },
    },
    {
      block: { row: 3, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-computer-table-2',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['workshop', 'vat', 'research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        light: ATMOS_LIGHT_SMALL_CYAN,
        baseWeight: 148,
        minZoneWeight: 0,
        maxZoneWeight: 340,
      },
    },
    {
      block: { row: 0, col: 0, width: 3, height: 2 },
      meta: {
        id: 'object-large-machinery-storage-1',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage', 'research'],
        roles: ['storage', 'research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        baseWeight: 126,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 0, col: 3, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-1',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research', 'storage'],
        roles: ['storage', 'research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        light: ATMOS_LIGHT_LARGE_ORANGE,
        baseWeight: 124,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 0, col: 5, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-storage-2',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage', 'research'],
        roles: ['storage', 'research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        baseWeight: 122,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 2, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-2',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research', 'storage'],
        roles: ['storage', 'research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        light: ATMOS_LIGHT_LARGE_GREEN,
        baseWeight: 123,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 2, col: 6, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-storage-3',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage', 'research'],
        roles: ['storage', 'research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        light: ATMOS_LIGHT_LARGE_BLUE,
        baseWeight: 121,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 4, col: 4, width: 3, height: 2 },
      meta: {
        id: 'object-large-machinery-research-3',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research', 'storage'],
        roles: ['storage', 'research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        baseWeight: 127,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 5, col: 0, width: 3, height: 3 },
      meta: {
        id: 'object-large-machinery-storage-4',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage', 'research'],
        roles: ['storage', 'research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        baseWeight: 132,
        minZoneWeight: 0,
        maxZoneWeight: 340,
      },
    },
    {
      block: { row: 6, col: 3, width: 3, height: 3 },
      meta: {
        id: 'object-large-machinery-research-4',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research', 'storage'],
        roles: ['storage', 'research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        baseWeight: 130,
        minZoneWeight: 0,
        maxZoneWeight: 340,
      },
    },
    {
      block: { row: 6, col: 6, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-storage-6',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage', 'research'],
        roles: ['storage', 'research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        baseWeight: 125,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 0, col: 0, width: 3, height: 3 },
      meta: {
        id: 'object-large-machinery-storage-5',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage', 'research'],
        roles: ['storage', 'research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 129,
        minZoneWeight: 0,
        maxZoneWeight: 340,
      },
    },
    {
      block: { row: 0, col: 3, width: 3, height: 3 },
      meta: {
        id: 'object-large-machinery-storage-7',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage', 'research'],
        roles: ['storage', 'research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        light: ATMOS_LIGHT_LARGE_BLUE,
        baseWeight: 128,
        minZoneWeight: 0,
        maxZoneWeight: 340,
      },
    },
  ];

  public static var FLOOR_DECOR_META: Array<_FloorDecorMeta> = [
    { icon: { row: 3, col: 0 }, motifs: ['glowing-green-grate', 'machinery'], roles: ['workshop', 'vat', 'research'], light: ATMOS_LIGHT_SMALL_GREEN, baseWeight: 106 },
    { icon: { row: 3, col: 1 }, motifs: ['green-puddle', 'spill', 'grime'], roles: ['vat', 'workshop', 'storage'], baseWeight: 98 },
    { icon: { row: 3, col: 2 }, motifs: ['lab-number-marking', 'hazard-marking'], roles: ['vat', 'workshop', 'research', 'entrance'], baseWeight: 108 },
    { icon: { row: 3, col: 3 }, motifs: ['scratches', 'grime'], roles: ['entrance', 'storage', 'workshop'], baseWeight: 86 },
    { icon: { row: 3, col: 4 }, motifs: ['scratches', 'grime'], roles: ['entrance', 'storage', 'workshop'], baseWeight: 85 },
    { icon: { row: 3, col: 5 }, motifs: ['scratches', 'grime'], roles: ['entrance', 'storage', 'workshop'], baseWeight: 84 },
    { icon: { row: 3, col: 6 }, motifs: ['section-number-marking', 'hazard-marking'], roles: ['vat', 'workshop', 'research', 'entrance'], baseWeight: 107 },
    { icon: { row: 3, col: 7 }, motifs: ['lab-number-marking', 'hazard-marking'], roles: ['vat', 'workshop', 'research', 'entrance'], baseWeight: 106 },
    { icon: { row: 4, col: 0 }, motifs: ['lab-number-marking', 'hazard-marking'], roles: ['vat', 'workshop', 'research', 'entrance'], baseWeight: 105 },
    { icon: { row: 4, col: 1 }, motifs: ['crack', 'grime'], roles: ['entrance', 'storage', 'workshop'], baseWeight: 88 },
    { icon: { row: 4, col: 2 }, motifs: ['brown-puddle', 'spill', 'grime'], roles: ['vat', 'workshop', 'storage'], baseWeight: 97 },
    { icon: { row: 4, col: 3 }, motifs: ['floor-grate', 'machinery'], roles: ['workshop', 'vat', 'research'], baseWeight: 102 },
    { icon: { row: 4, col: 4 }, motifs: ['purple-puddle', 'spill', 'grime'], roles: ['vat', 'workshop', 'storage'], baseWeight: 96 },
    { icon: { row: 4, col: 5 }, motifs: ['scratches', 'grime'], roles: ['entrance', 'storage', 'workshop'], baseWeight: 83 },
    { icon: { row: 4, col: 6 }, motifs: ['scratches', 'grime'], roles: ['entrance', 'storage', 'workshop'], baseWeight: 82 },
    { icon: { row: 4, col: 7 }, motifs: ['biohazard-sign', 'hazard-marking'], roles: ['vat', 'workshop', 'research'], baseWeight: 112 },
    { icon: { row: 5, col: 0 }, motifs: ['floor-grate', 'machinery'], roles: ['workshop', 'vat', 'research'], baseWeight: 101 },
    { icon: { row: 5, col: 1 }, motifs: ['floor-grate', 'machinery'], roles: ['workshop', 'vat', 'research'], baseWeight: 100 },
    { icon: { row: 5, col: 2 }, motifs: ['floor-hatch', 'machinery'], roles: ['workshop', 'vat', 'research'], baseWeight: 104 },
    { icon: { row: 5, col: 3 }, motifs: ['black-puddle', 'spill', 'grime'], roles: ['vat', 'workshop', 'storage'], baseWeight: 98 },
    { icon: { row: 5, col: 4 }, motifs: ['puddle', 'spill', 'grime'], roles: ['vat', 'workshop', 'storage'], baseWeight: 95 },
    { icon: { row: 5, col: 5 }, motifs: ['puddle', 'spill', 'grime'], roles: ['vat', 'workshop', 'storage'], baseWeight: 94 },
    { icon: { row: 5, col: 6 }, motifs: ['floor-grate', 'machinery'], roles: ['workshop', 'vat', 'research'], baseWeight: 99 },
  ];

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
  public var nearTopWallFloorLayerID: Int;
  public var decorationObjFloorLayerID: Int;
  var decorationObjFloorLayerByImageKey: StringMap<Int>;
  var decorationObjFloorLayerIDs: Array<Int>;
  public var nearTopWallWallLayerID: Int;
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
      decorationObjFloorLayerByImageKey = new StringMap<Int>();
      decorationObjFloorLayerIDs = [];
      iconByTileID = new Map<Int, _Icon>();
      initFloor();
      initWalls();
      addFloorDecorationLayer('img/underground-lab-decoration-tiles1.png',
        [], [3, 4, 5]);
      addFloorDecorationLayer('img/entities64.png', []);
      splatLayerID = floorDecorationLayers.length - 1;
      nearTopWallFloorLayerID = floorDecorationLayers.length;
      addFloorDecorationLayer(NEAR_TOP_WALL_IMAGE_PATH, []);
      registerDecorationObjLayer(DECORATION_OBJ_IMAGE_KEY_1,
        DECORATION_OBJ_IMAGE_PATH_1);
      decorationObjFloorLayerID = getDecorationObjLayerID(DECORATION_OBJ_IMAGE_KEY_1);
      registerDecorationObjLayer(DECORATION_OBJ_IMAGE_KEY_2,
        DECORATION_OBJ_IMAGE_PATH_2);
      addWallDecorationLayerRepeat({
        path: 'img/underground-lab-decoration1.png',
        repeatEvery: 4,
      });
      addWallDecorationLayerChance({
        path: 'img/underground-lab-decoration2.png',
        chance: 80,
      });
      addWallDecorationLayerChance({
        path: 'img/underground-lab-decoration3.png',
        chance: 10,
        light: ATMOS_LIGHT_SMALL_CYAN,
      });
      addWallDecorationLayerChance({
        path: 'img/underground-lab-decoration4.png',
        chance: 20,
        light: ATMOS_LIGHT_SMALL_CYAN,
        noCorners: true,
      });
      addWallDecorationLayerRepeat({
        path: 'img/underground-lab-decoration5.png',
        repeatEvery: 2,
      });
      nearTopWallWallLayerID = wallDecorationLayers.length;
      addWallDecorationLayerRepeat({
        path: NEAR_TOP_WALL_IMAGE_PATH,
        repeatEvery: -1,
      });
    }

// register one object-decoration image layer and map it by key
  function registerDecorationObjLayer(imageKey: String, path: String)
    {
      var layerID = floorDecorationLayers.length;
      addFloorDecorationLayer(path, []);
      decorationObjFloorLayerByImageKey.set(imageKey, layerID);
      decorationObjFloorLayerIDs.push(layerID);
    }

// get object-decoration floor layer id by image key
  public function getDecorationObjLayerID(imageKey: String): Int
    {
      return decorationObjFloorLayerByImageKey.get(imageKey);
    }

// check whether floor layer id is an object-decoration layer
  public function isDecorationObjLayerID(layerID: Int): Bool
    {
      return (decorationObjFloorLayerIDs.indexOf(layerID) >= 0);
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

// check if a decoration entry should block movement
  public override function isBlockingDecoration(tileID: Int, decoration: tiles.Decoration): Bool
    {
      return (decoration.layerID == nearTopWallFloorLayerID ||
        decoration.layerID == nearTopWallWallLayerID ||
        isDecorationObjLayerID(decoration.layerID));
    }
}
