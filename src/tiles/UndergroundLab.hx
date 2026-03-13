// underground lab tileset wrapper with custom tile mapping

package tiles;

import Const;
import haxe.ds.StringMap;

typedef _DecorPadding = {
  var up: Int;
  var right: Int;
  var down: Int;
  var left: Int;
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
  public static var NEAR_TOP_WALL_IMAGE_KEY_1 = 'near-top-1';
  public static var NEAR_TOP_WALL_IMAGE_PATH_2 = 'img/underground-lab-deco-near-top2.png';
  public static var NEAR_TOP_WALL_IMAGE_KEY_2 = 'near-top-2';
  public static var DECORATION_OBJ_IMAGE_KEY_1 = 'decor-obj-1';
  public static var DECORATION_OBJ_IMAGE_PATH_1 = 'img/underground-lab-deco-obj1.png';
  public static var DECORATION_OBJ_IMAGE_KEY_2 = 'decor-obj-2';
  public static var DECORATION_OBJ_IMAGE_PATH_2 = 'img/underground-lab-deco-obj2.png';
  public static var DECORATION_OBJ_IMAGE_KEY_3 = 'decor-obj-3';
  public static var DECORATION_OBJ_IMAGE_PATH_3 = 'img/underground-lab-deco-obj3.png';
  public static var DECORATION_OBJ_IMAGE_KEY_4 = 'decor-obj-4';
  public static var DECORATION_OBJ_IMAGE_PATH_4 = 'img/underground-lab-deco-obj4.png';
  public static var DECORATION_OBJ_IMAGE_KEY_5 = 'decor-obj-5';
  public static var DECORATION_OBJ_IMAGE_PATH_5 = 'img/underground-lab-deco-obj5.png';
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
  public static var ATMOS_LIGHT_LARGE_RED: _AtmosphereLightMeta = {
    radiusTiles: ATMOS_LIGHT_RADIUS_LARGE,
    intensity: 0.88,
    tintR: 255,
    tintG: 48,
    tintB: 48,
  };
  public static var ATMOS_LIGHT_LARGE_WHITE: _AtmosphereLightMeta = {
    radiusTiles: ATMOS_LIGHT_RADIUS_LARGE,
    intensity: 0.88,
    tintR: 255,
    tintG: 255,
    tintB: 255,
  };
  public static var ATMOS_LIGHT_LARGE_BLUE: _AtmosphereLightMeta = {
    radiusTiles: ATMOS_LIGHT_RADIUS_LARGE,
    intensity: 0.88,
    tintR: 0,
    tintG: 120,
    tintB: 255,
  };

  public static var NEAR_TOP_WALL_META(get, never): Array<_DecorBlock>;
  static var nearTopWallMetaCache: Array<_DecorBlock>;
  static var NEAR_TOP_WALL_BASE_META: Array<_DecorBlock> = [
    {
      block: { row: 0, col: 0, width: 1, height: 2 },
      meta: {
        id: 'near-top-bookcase-1',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance'],
        baseWeight: 100,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 0, col: 1, width: 1, height: 2 },
      meta: {
        id: 'near-top-bookcase-2',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance'],
        baseWeight: 102,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 0, col: 2, width: 1, height: 2 },
      meta: {
        id: 'near-top-bookcase-3',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance'],
        baseWeight: 98,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 0, col: 3, width: 1, height: 2 },
      meta: {
        id: 'near-top-bookcase-4',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance'],
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
    {
      block: { row: 2, col: 0, width: 2, height: 2 },
      meta: {
        id: 'near-top-locker-wide-1',
        tags: ['wall', 'locker', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'workshop', 'entrance'],
        baseWeight: 103,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 2, col: 2, width: 2, height: 2 },
      meta: {
        id: 'near-top-locker-wide-2',
        tags: ['wall', 'locker', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'workshop', 'entrance'],
        baseWeight: 101,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 2, col: 4, width: 2, height: 2 },
      meta: {
        id: 'near-top-locker-wide-3',
        tags: ['wall', 'locker', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'workshop', 'entrance'],
        baseWeight: 99,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 2, col: 6, width: 2, height: 2 },
      meta: {
        id: 'near-top-locker-wide-4',
        tags: ['wall', 'locker', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'workshop', 'entrance'],
        baseWeight: 99,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 4, col: 0, width: 1, height: 2 },
      meta: {
        id: 'near-top-bookcase-5',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance'],
        baseWeight: 100,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 4, col: 2, width: 1, height: 2 },
      meta: {
        id: 'near-top-bookcase-6',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance'],
        baseWeight: 83,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 4, col: 3, width: 1, height: 2 },
      meta: {
        id: 'near-top-plant-6',
        tags: ['wall', 'plant'],
        motifs: ['furniture'],
        roles: ['entrance', 'research', 'storage'],
        baseWeight: 82,
        minZoneWeight: 0,
        maxZoneWeight: 200,
      },
    },
    {
      block: { row: 4, col: 4, width: 1, height: 2 },
      meta: {
        id: 'near-top-plant-7',
        tags: ['wall', 'plant'],
        motifs: ['furniture'],
        roles: ['entrance', 'research', 'storage'],
        baseWeight: 81,
        minZoneWeight: 0,
        maxZoneWeight: 200,
      },
    },
    {
      block: { row: 4, col: 5, width: 1, height: 2 },
      meta: {
        id: 'near-top-machinery-1',
        tags: ['wall', 'machinery'],
        motifs: ['machinery', 'storage'],
        roles: ['storage', 'workshop'],
        light: ATMOS_LIGHT_LARGE_ORANGE,
        baseWeight: 94,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 4, col: 6, width: 1, height: 2 },
      meta: {
        id: 'near-top-machinery-2',
        tags: ['wall', 'machinery'],
        motifs: ['machinery', 'research'],
        roles: ['workshop', 'research'],
        baseWeight: 92,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 4, col: 7, width: 1, height: 2 },
      meta: {
        id: 'near-top-entrance-machinery-1',
        tags: ['wall', 'machinery'],
        motifs: ['machinery'],
        roles: ['entrance'],
        baseWeight: 106,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 6, col: 0, width: 2, height: 2 },
      meta: {
        id: 'near-top-entrance-hazmat-rack-1',
        tags: ['wall', 'rack', 'hazmat'],
        motifs: ['storage'],
        roles: ['entrance'],
        baseWeight: 104,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 6, col: 2, width: 2, height: 2 },
      meta: {
        id: 'near-top-entrance-hazmat-rack-2',
        tags: ['wall', 'rack', 'hazmat'],
        motifs: ['storage'],
        roles: ['entrance'],
        baseWeight: 102,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 6, col: 4, width: 2, height: 2 },
      meta: {
        id: 'near-top-entrance-hazmat-rack-3',
        tags: ['wall', 'rack', 'hazmat'],
        motifs: ['storage'],
        roles: ['entrance'],
        baseWeight: 100,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 6, col: 6, width: 2, height: 2 },
      meta: {
        id: 'near-top-entrance-hazmat-rack-4',
        tags: ['wall', 'rack', 'hazmat'],
        motifs: ['storage'],
        roles: ['entrance'],
        baseWeight: 98,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 8, col: 0, width: 2, height: 2 },
      meta: {
        id: 'near-top-entrance-seats-1',
        tags: ['wall', 'seats', 'furniture'],
        motifs: ['furniture'],
        roles: ['entrance'],
        baseWeight: 94,
        minZoneWeight: 0,
        maxZoneWeight: 210,
      },
    },
    {
      block: { row: 8, col: 2, width: 2, height: 2 },
      meta: {
        id: 'near-top-entrance-seats-2',
        tags: ['wall', 'seats', 'furniture'],
        motifs: ['furniture'],
        roles: ['entrance'],
        baseWeight: 92,
        minZoneWeight: 0,
        maxZoneWeight: 210,
      },
    },
    {
      block: { row: 8, col: 4, width: 2, height: 2 },
      meta: {
        id: 'near-top-entrance-seats-3',
        tags: ['wall', 'seats', 'furniture'],
        motifs: ['furniture'],
        roles: ['entrance'],
        baseWeight: 90,
        minZoneWeight: 0,
        maxZoneWeight: 210,
      },
    },
    {
      block: { row: 0, col: 2, width: 1, height: 2 },
      meta: {
        id: 'near-top-small-bookcase-1',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance', 'workshop', 'vat'],
        imageKey: NEAR_TOP_WALL_IMAGE_KEY_2,
        baseWeight: 96,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 0, col: 3, width: 1, height: 2 },
      meta: {
        id: 'near-top-small-bookcase-2',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance', 'workshop', 'vat'],
        imageKey: NEAR_TOP_WALL_IMAGE_KEY_2,
        baseWeight: 95,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 0, col: 4, width: 1, height: 2 },
      meta: {
        id: 'near-top-small-bookcase-3',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance', 'workshop', 'vat'],
        imageKey: NEAR_TOP_WALL_IMAGE_KEY_2,
        baseWeight: 94,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 0, col: 5, width: 1, height: 2 },
      meta: {
        id: 'near-top-small-bookcase-4',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance', 'workshop', 'vat'],
        imageKey: NEAR_TOP_WALL_IMAGE_KEY_2,
        baseWeight: 93,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 0, col: 6, width: 1, height: 2 },
      meta: {
        id: 'near-top-small-bookcase-5',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance', 'workshop', 'vat'],
        imageKey: NEAR_TOP_WALL_IMAGE_KEY_2,
        baseWeight: 92,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 0, col: 7, width: 1, height: 2 },
      meta: {
        id: 'near-top-small-bookcase-6',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance', 'workshop', 'vat'],
        imageKey: NEAR_TOP_WALL_IMAGE_KEY_2,
        baseWeight: 91,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 2, col: 0, width: 1, height: 2 },
      meta: {
        id: 'near-top-small-bookcase-7',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance', 'workshop', 'vat'],
        imageKey: NEAR_TOP_WALL_IMAGE_KEY_2,
        baseWeight: 98,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 2, col: 1, width: 1, height: 2 },
      meta: {
        id: 'near-top-small-bookcase-8',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance', 'workshop', 'vat'],
        imageKey: NEAR_TOP_WALL_IMAGE_KEY_2,
        baseWeight: 97,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 2, col: 2, width: 1, height: 2 },
      meta: {
        id: 'near-top-small-bookcase-9',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance', 'workshop', 'vat'],
        imageKey: NEAR_TOP_WALL_IMAGE_KEY_2,
        baseWeight: 96,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 2, col: 3, width: 1, height: 2 },
      meta: {
        id: 'near-top-small-bookcase-10',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance', 'workshop', 'vat'],
        imageKey: NEAR_TOP_WALL_IMAGE_KEY_2,
        baseWeight: 95,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 2, col: 4, width: 1, height: 2 },
      meta: {
        id: 'near-top-small-bookcase-11',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance', 'workshop', 'vat'],
        imageKey: NEAR_TOP_WALL_IMAGE_KEY_2,
        baseWeight: 94,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 8, col: 6, width: 1, height: 2 },
      meta: {
        id: 'near-top-bookcase-7',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance'],
        imageKey: NEAR_TOP_WALL_IMAGE_KEY_2,
        baseWeight: 92,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
    {
      block: { row: 8, col: 7, width: 1, height: 2 },
      meta: {
        id: 'near-top-bookcase-8',
        tags: ['wall', 'bookcase', 'storage'],
        motifs: ['storage'],
        roles: ['storage', 'research', 'entrance'],
        imageKey: NEAR_TOP_WALL_IMAGE_KEY_2,
        baseWeight: 91,
        minZoneWeight: 0,
        maxZoneWeight: 220,
      },
    },
  ];

  public static var DECORATION_OBJ_META: Array<_DecorBlock> = [
    {
      block: { row: 2, col: 0, width: 2, height: 1 },
      meta: {
        id: 'object-near-wall-table-1',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 122,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 2, col: 2, width: 2, height: 1 },
      meta: {
        id: 'object-near-wall-table-2',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 120,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 9, col: 2, width: 2, height: 1 },
      meta: {
        id: 'object-near-wall-table-3',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 118,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 9, col: 4, width: 2, height: 1 },
      meta: {
        id: 'object-near-wall-table-4',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 116,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 0, col: 7, width: 1, height: 1 },
      meta: {
        id: 'object-crate-1',
        tags: ['object', 'crate'],
        motifs: ['storage'],
        roles: ['storage', 'workshop', 'entrance'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        baseWeight: 106,
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
        roles: ['storage', 'workshop', 'entrance'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        baseWeight: 105,
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
        roles: ['storage', 'workshop', 'entrance'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        baseWeight: 107,
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
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        light: ATMOS_LIGHT_SMALL_CYAN,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
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
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        light: ATMOS_LIGHT_SMALL_CYAN,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
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
    {
      block: { row: 8, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-workshop-1',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage'],
        roles: ['storage', 'workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        light: ATMOS_LIGHT_LARGE_BLUE,
        baseWeight: 126,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 8, col: 6, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-workshop-2',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage'],
        roles: ['storage', 'workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        light: ATMOS_LIGHT_LARGE_GREEN,
        baseWeight: 125,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 5, col: 7, width: 1, height: 1 },
      meta: {
        id: 'object-machinery-workshop-1',
        tags: ['object', 'machinery'],
        motifs: ['machinery', 'storage'],
        roles: ['storage', 'workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_1,
        baseWeight: 116,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 0, col: 6, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-workshop-3',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage'],
        roles: ['storage', 'workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        light: ATMOS_LIGHT_SMALL_CYAN,
        baseWeight: 124,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 2, col: 6, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-workshop-4',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage'],
        roles: ['storage', 'workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        light: ATMOS_LIGHT_SMALL_CYAN,
        baseWeight: 123,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 3, col: 0, width: 1, height: 2 },
      meta: {
        id: 'object-large-machinery-workshop-5',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage'],
        roles: ['storage', 'workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 118,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 3, col: 1, width: 1, height: 2 },
      meta: {
        id: 'object-large-machinery-workshop-6',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage'],
        roles: ['storage', 'workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 117,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 3, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-workshop-7',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'storage'],
        roles: ['storage', 'workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 122,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 3, col: 4, width: 2, height: 1 },
      meta: {
        id: 'object-large-machinery-research-obj2-1',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 122,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 4, col: 4, width: 1, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj2-2',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 121,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 4, col: 5, width: 2, height: 1 },
      meta: {
        id: 'object-large-machinery-research-obj2-3',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 120,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 4, col: 7, width: 1, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj2-4',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 119,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 5, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj2-5',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 127,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 5, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj2-6',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 126,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 5, col: 5, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj2-7',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 125,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 7, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj2-8',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 124,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 7, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj2-9',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 123,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 7, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj2-10',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 122,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 7, col: 6, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj2-11',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_2,
        baseWeight: 121,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 0, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-1',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        light: ATMOS_LIGHT_LARGE_GREEN,
        baseWeight: 128,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 0, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-2',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 127,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 0, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-3',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 126,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 0, col: 6, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-4',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 125,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 2, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-5',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 124,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 2, col: 2, width: 1, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-6',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        light: ATMOS_LIGHT_SMALL_CYAN,
        baseWeight: 123,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 2, col: 3, width: 1, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-7',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        light: ATMOS_LIGHT_SMALL_CYAN,
        baseWeight: 122,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 2, col: 4, width: 1, height: 1 },
      meta: {
        id: 'object-machinery-research-obj3-8',
        tags: ['object', 'machinery'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 114,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 2, col: 5, width: 2, height: 1 },
      meta: {
        id: 'object-large-machinery-research-obj3-9',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 121,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 2, col: 7, width: 1, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-10',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 120,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 3, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-11',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        light: ATMOS_LIGHT_LARGE_GREEN,
        baseWeight: 126,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 3, col: 6, width: 1, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-12',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 119,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 4, col: 0, width: 2, height: 1 },
      meta: {
        id: 'object-large-machinery-research-obj3-13',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 118,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 4, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-14',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        light: ATMOS_LIGHT_LARGE_BLUE,
        baseWeight: 125,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 4, col: 7, width: 1, height: 1 },
      meta: {
        id: 'object-machinery-research-obj3-15',
        tags: ['object', 'machinery'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 113,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 5, col: 0, width: 2, height: 1 },
      meta: {
        id: 'object-large-machinery-research-obj3-16',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 117,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 5, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-17',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        light: ATMOS_LIGHT_LARGE_BLUE,
        baseWeight: 124,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 5, col: 6, width: 2, height: 1 },
      meta: {
        id: 'object-large-machinery-research-obj3-18',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 116,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 6, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-19',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 123,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 6, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-20',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 122,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 6, col: 6, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-21',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 121,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 7, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-22',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        light: ATMOS_LIGHT_SMALL_CYAN,
        baseWeight: 120,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 8, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-23',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        light: ATMOS_LIGHT_LARGE_GREEN,
        baseWeight: 119,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 8, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-large-machinery-research-obj3-24',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        light: ATMOS_LIGHT_SMALL_CYAN,
        baseWeight: 118,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 8, col: 6, width: 1, height: 1 },
      meta: {
        id: 'object-machinery-research-obj3-25',
        tags: ['object', 'machinery'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 112,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 9, col: 4, width: 2, height: 1 },
      meta: {
        id: 'object-large-machinery-research-obj3-26',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_3,
        baseWeight: 117,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 0, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-large-entrance-obj4-machinery-1',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery'],
        roles: ['entrance'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        baseWeight: 124,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 0, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-large-entrance-obj4-machinery-2',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery'],
        roles: ['entrance'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        baseWeight: 122,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 0, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-large-entrance-obj4-gurney-1',
        tags: ['object', 'gurney', 'large'],
        motifs: ['furniture'],
        roles: ['entrance'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        baseWeight: 127,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 0, col: 6, width: 2, height: 2 },
      meta: {
        id: 'object-large-entrance-obj4-crate-1',
        tags: ['object', 'crate', 'large'],
        motifs: ['storage'],
        roles: ['entrance'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        baseWeight: 126,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 2, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-large-entrance-obj4-machinery-3',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery'],
        roles: ['entrance'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        baseWeight: 123,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 2, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-large-entrance-obj4-gurney-2',
        tags: ['object', 'gurney', 'large'],
        motifs: ['furniture'],
        roles: ['entrance'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        baseWeight: 125,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 2, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-large-entrance-obj4-crate-2',
        tags: ['object', 'crate', 'large'],
        motifs: ['storage'],
        roles: ['entrance'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        baseWeight: 124,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 2, col: 6, width: 1, height: 1 },
      meta: {
        id: 'object-entrance-obj4-machinery-4',
        tags: ['object', 'machinery'],
        motifs: ['machinery'],
        roles: ['entrance'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        baseWeight: 112,
        minZoneWeight: 0,
        maxZoneWeight: 240,
      },
    },
    {
      block: { row: 4, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-large-entrance-obj4-machinery-5',
        tags: ['object', 'machinery', 'large'],
        motifs: ['machinery'],
        roles: ['entrance'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        baseWeight: 117,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 3, col: 6, width: 2, height: 1 },
      meta: {
        id: 'object-obj4-near-wall-table-1',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 121,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 4, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-obj4-table-2',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 126,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 4, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-obj4-table-3',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 124,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 4, col: 6, width: 2, height: 2 },
      meta: {
        id: 'object-obj4-table-4',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        light: ATMOS_LIGHT_LARGE_GREEN,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 123,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 6, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-obj4-table-5',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 122,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 6, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-obj4-table-6',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        light: ATMOS_LIGHT_LARGE_GREEN,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 121,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 6, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-obj4-table-7',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        light: ATMOS_LIGHT_LARGE_ORANGE,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 120,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 6, col: 6, width: 2, height: 2 },
      meta: {
        id: 'object-obj4-table-8',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 119,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 8, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-obj4-table-9',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 118,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 8, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-obj4-table-10',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 117,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 8, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-obj4-table-11',
        tags: ['object', 'computer', 'table', 'large'],
        motifs: ['machinery', 'research'],
        roles: ['research', 'vat'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        light: ATMOS_LIGHT_SMALL_CYAN,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 116,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 8, col: 6, width: 2, height: 1 },
      meta: {
        id: 'object-obj4-workshop-near-wall-table-1',
        tags: ['object', 'table', 'large'],
        motifs: ['machinery'],
        roles: ['workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_4,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 118,
        minZoneWeight: 0,
        maxZoneWeight: 300,
      },
    },
    {
      block: { row: 0, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-obj5-workshop-table-1',
        tags: ['object', 'table', 'large'],
        motifs: ['machinery'],
        roles: ['workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_5,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 126,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 0, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-obj5-workshop-table-2',
        tags: ['object', 'table', 'large'],
        motifs: ['machinery'],
        roles: ['workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_5,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 125,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 0, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-obj5-workshop-table-3',
        tags: ['object', 'table', 'large'],
        motifs: ['machinery'],
        roles: ['workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_5,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 124,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 0, col: 6, width: 2, height: 2 },
      meta: {
        id: 'object-obj5-workshop-table-4',
        tags: ['object', 'table', 'large'],
        motifs: ['machinery'],
        roles: ['workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_5,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 123,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 2, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-obj5-workshop-table-5',
        tags: ['object', 'table', 'large'],
        motifs: ['machinery'],
        roles: ['workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_5,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 122,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 2, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-obj5-workshop-table-6',
        tags: ['object', 'table', 'large'],
        motifs: ['machinery'],
        roles: ['workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_5,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 121,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 2, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-obj5-workshop-table-7',
        tags: ['object', 'table', 'large'],
        motifs: ['machinery'],
        roles: ['workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_5,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 120,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 2, col: 6, width: 2, height: 2 },
      meta: {
        id: 'object-obj5-workshop-table-8',
        tags: ['object', 'table', 'large'],
        motifs: ['machinery'],
        roles: ['workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_5,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 119,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 4, col: 0, width: 2, height: 2 },
      meta: {
        id: 'object-obj5-workshop-table-9',
        tags: ['object', 'table', 'large'],
        motifs: ['machinery'],
        roles: ['workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_5,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 118,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 4, col: 2, width: 2, height: 2 },
      meta: {
        id: 'object-obj5-workshop-table-10',
        tags: ['object', 'table', 'large'],
        motifs: ['machinery'],
        roles: ['workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_5,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 117,
        minZoneWeight: 0,
        maxZoneWeight: 320,
      },
    },
    {
      block: { row: 4, col: 4, width: 2, height: 2 },
      meta: {
        id: 'object-obj5-workshop-table-11',
        tags: ['object', 'table', 'large'],
        motifs: ['machinery'],
        roles: ['workshop'],
        imageKey: DECORATION_OBJ_IMAGE_KEY_5,
        padding: {
          up: 0,
          right: 0,
          down: 1,
          left: 0,
        },
        baseWeight: 116,
        minZoneWeight: 0,
        maxZoneWeight: 320,
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
  var nearTopWallFloorLayerByImageKey: StringMap<Int>;
  var nearTopWallFloorLayerIDs: Array<Int>;
  public var decorationObjFloorLayerID: Int;
  var decorationObjFloorLayerByImageKey: StringMap<Int>;
  var decorationObjFloorLayerIDs: Array<Int>;
  var decorationObjWallLayerByImageKey: StringMap<Int>;
  var decorationObjWallLayerIDs: Array<Int>;
  public var nearTopWallWallLayerID: Int;
  var nearTopWallWallLayerByImageKey: StringMap<Int>;
  var nearTopWallWallLayerIDs: Array<Int>;
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
      nearTopWallFloorLayerByImageKey = new StringMap<Int>();
      nearTopWallFloorLayerIDs = [];
      decorationObjFloorLayerByImageKey = new StringMap<Int>();
      decorationObjFloorLayerIDs = [];
      decorationObjWallLayerByImageKey = new StringMap<Int>();
      decorationObjWallLayerIDs = [];
      nearTopWallWallLayerByImageKey = new StringMap<Int>();
      nearTopWallWallLayerIDs = [];
      iconByTileID = new Map<Int, _Icon>();
      initFloor();
      initWalls();
      addFloorDecorationLayer('img/underground-lab-decoration-tiles1.png',
        [], [3, 4, 5]);
      addFloorDecorationLayer('img/entities64.png', []);
      splatLayerID = floorDecorationLayers.length - 1;
      nearTopWallFloorLayerID = registerNearTopFloorLayer(
        NEAR_TOP_WALL_IMAGE_KEY_1,
        NEAR_TOP_WALL_IMAGE_PATH);
      registerNearTopFloorLayer(
        NEAR_TOP_WALL_IMAGE_KEY_2,
        NEAR_TOP_WALL_IMAGE_PATH_2);
      registerDecorationObjLayer(DECORATION_OBJ_IMAGE_KEY_1,
        DECORATION_OBJ_IMAGE_PATH_1);
      decorationObjFloorLayerID = getDecorationObjLayerID(DECORATION_OBJ_IMAGE_KEY_1);
      registerDecorationObjLayer(DECORATION_OBJ_IMAGE_KEY_2,
        DECORATION_OBJ_IMAGE_PATH_2);
      registerDecorationObjLayer(DECORATION_OBJ_IMAGE_KEY_3,
        DECORATION_OBJ_IMAGE_PATH_3);
      registerDecorationObjLayer(DECORATION_OBJ_IMAGE_KEY_4,
        DECORATION_OBJ_IMAGE_PATH_4);
      registerDecorationObjLayer(DECORATION_OBJ_IMAGE_KEY_5,
        DECORATION_OBJ_IMAGE_PATH_5);
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
      registerNearTopWallLayer(
        NEAR_TOP_WALL_IMAGE_KEY_1,
        NEAR_TOP_WALL_IMAGE_PATH);
      registerNearTopWallLayer(
        NEAR_TOP_WALL_IMAGE_KEY_2,
        NEAR_TOP_WALL_IMAGE_PATH_2);
      nearTopWallWallLayerID = getNearTopWallLayerID(NEAR_TOP_WALL_IMAGE_KEY_1);
    }

// register one near-top image as a floor decoration layer
  function registerNearTopFloorLayer(imageKey: String, path: String): Int
    {
      var floorLayerID = floorDecorationLayers.length;
      addFloorDecorationLayer(path, []);
      nearTopWallFloorLayerByImageKey.set(imageKey, floorLayerID);
      nearTopWallFloorLayerIDs.push(floorLayerID);
      return floorLayerID;
    }

// register one near-top image as a wall decoration layer
  function registerNearTopWallLayer(imageKey: String, path: String)
    {
      var layerID = wallDecorationLayers.length;
      addWallDecorationLayerRepeat({
        path: path,
        repeatEvery: -1,
      });
      nearTopWallWallLayerByImageKey.set(imageKey, layerID);
      nearTopWallWallLayerIDs.push(layerID);
    }

// get near-top floor layer id by image key
  public function getNearTopFloorLayerID(imageKey: String): Int
    {
      return nearTopWallFloorLayerByImageKey.get(imageKey);
    }

// get near-top wall layer id by image key
  public function getNearTopWallLayerID(imageKey: String): Int
    {
      return nearTopWallWallLayerByImageKey.get(imageKey);
    }

// check whether floor layer id is a near-top decoration layer
  public function isNearTopFloorDecorationLayerID(layerID: Int): Bool
    {
      return (nearTopWallFloorLayerIDs.indexOf(layerID) >= 0);
    }

// register one object-decoration image layer and map it by key
  function registerDecorationObjLayer(imageKey: String, path: String)
    {
      var layerID = floorDecorationLayers.length;
      addFloorDecorationLayer(path, []);
      decorationObjFloorLayerByImageKey.set(imageKey, layerID);
      decorationObjFloorLayerIDs.push(layerID);
      registerDecorationObjWallLayer(imageKey, path);
    }

// get object-decoration floor layer id by image key
  public function getDecorationObjLayerID(imageKey: String): Int
    {
      return decorationObjFloorLayerByImageKey.get(imageKey);
    }

// get object-decoration wall layer id by image key
  public function getDecorationObjWallLayerID(imageKey: String): Int
    {
      return decorationObjWallLayerByImageKey.get(imageKey);
    }

// check whether floor layer id is an object-decoration layer
  public function isDecorationObjLayerID(layerID: Int): Bool
    {
      return (decorationObjFloorLayerIDs.indexOf(layerID) >= 0);
    }

// check whether wall layer id is a copied near-top object layer
  public function isDecorationObjWallLayerID(layerID: Int): Bool
    {
      return (decorationObjWallLayerIDs.indexOf(layerID) >= 0);
    }

// get wall/floor layer id for one near-top decor row
  public function getNearTopDecorationLayerID(blockInfo: _DecorBlock, dy: Int): Int
    {
      if (blockInfo.meta.imageKey != null &&
          nearTopWallFloorLayerByImageKey.exists(blockInfo.meta.imageKey))
        {
          if (dy == 0)
            return getNearTopWallLayerID(blockInfo.meta.imageKey);
          return getNearTopFloorLayerID(blockInfo.meta.imageKey);
        }
      if (blockInfo.meta.imageKey != null)
        {
          if (dy == 0)
            return getDecorationObjWallLayerID(blockInfo.meta.imageKey);
          return getDecorationObjLayerID(blockInfo.meta.imageKey);
        }
      if (dy == 0)
        return nearTopWallWallLayerID;
      return nearTopWallFloorLayerID;
    }

// check whether one wall layer id belongs to near-top wall decoration
  public function isNearTopWallDecorationWallLayerID(layerID: Int): Bool
    {
      return (nearTopWallWallLayerIDs.indexOf(layerID) >= 0 ||
        isDecorationObjWallLayerID(layerID));
    }

// build cached near-top metadata including copied 2x2 object tables
  static function get_NEAR_TOP_WALL_META(): Array<_DecorBlock>
    {
      if (nearTopWallMetaCache == null)
        nearTopWallMetaCache = buildNearTopWallMeta();
      return nearTopWallMetaCache;
    }

// build near-top metadata by appending copied 2x2 table variants
  static function buildNearTopWallMeta(): Array<_DecorBlock>
    {
      var meta = [];
      for (blockInfo in NEAR_TOP_WALL_BASE_META)
        meta.push(blockInfo);
      for (blockInfo in DECORATION_OBJ_META)
        {
          if (!isNearTopWallTableCopySource(blockInfo))
            continue;
          var tags = blockInfo.meta.tags.copy();
          if (tags.indexOf('wall') < 0)
            tags.unshift('wall');
          meta.push({
            block: {
              row: blockInfo.block.row,
              col: blockInfo.block.col,
              width: blockInfo.block.width,
              height: blockInfo.block.height,
            },
            meta: {
              id: 'near-top-copy-' + blockInfo.meta.id,
              tags: tags,
              motifs: blockInfo.meta.motifs.copy(),
              roles: blockInfo.meta.roles.copy(),
              imageKey: blockInfo.meta.imageKey,
              light: blockInfo.meta.light,
              nearTopOffsetY: 13,
              baseWeight: blockInfo.meta.baseWeight,
              minZoneWeight: blockInfo.meta.minZoneWeight,
              maxZoneWeight: blockInfo.meta.maxZoneWeight,
            },
          });
        }
      return meta;
    }

// check whether one object block should be copied into near-top metadata
  static function isNearTopWallTableCopySource(blockInfo: _DecorBlock): Bool
    {
      return (blockInfo.block.width == 2 &&
        blockInfo.block.height == 2 &&
        blockInfo.meta.tags.indexOf('table') >= 0);
    }

// register one object image as a wall decoration layer for near-top copies
  function registerDecorationObjWallLayer(imageKey: String, path: String)
    {
      var layer = new js.html.Image();
      layer.src = path;
      var layerID = wallDecorationLayers.length;
      wallDecorationLayers.push(layer);
      wallDecorationLayerRepeatEvery.push(-1);
      wallDecorationLayerChance.push(-1);
      wallDecorationLayerMeta.push({
        path: path,
        repeatEvery: -1,
        chance: -1,
      });
      decorationObjWallLayerByImageKey.set(imageKey, layerID);
      decorationObjWallLayerIDs.push(layerID);
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
      if (!isWalkable(tileID))
        return false;
      return (isNearTopFloorDecorationLayerID(decoration.layerID) ||
        isDecorationObjLayerID(decoration.layerID));
    }
}
