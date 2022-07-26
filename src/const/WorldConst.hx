// world and area constants

package const;

import Sounds;

class WorldConst
{
  static var areas: Map<_AreaType, AreaInfo> =
    [
      // *** wilderness around city
      AREA_GROUND => {
        id: AREA_GROUND,
        ambient: AMBIENT_WILDERNESS,
        type: 'wilderness',
        name: 'Uninhabited area',
        width: 100,
        height: 100,
        canEnter: true,
        isInhabited: false,
        commonAI: 0,
        uncommonAI: 0,
        lawResponceTime: 0,
        lawResponceAmount: 0,
        lawResponceEnabled: false,
        isHighRisk: false,
        ai: [
          'dog' => 5
        ],
        objects: [
        ]
      },

      // *** low-class, low population - outskirts and suburbs
      AREA_CITY_LOW => {
        id: AREA_CITY_LOW,
        ambient: AMBIENT_CITY,
        type: 'city',
        name: 'Low-density city area',
        width: 100,
        height: 100,
        canEnter: true,
        isInhabited: true,
        commonAI: 8,
        uncommonAI: 5,
        buildingSize: 1,
        lawResponceTime: 10,
        lawResponceAmount: 2,
        lawResponceEnabled: true,
        isHighRisk: false,
        ai: [
          'dog' => 20,
          'civilian' => 75,
          'police' => 5
        ],
        objects: [
          { id: 'sewer_hatch', amount: 10 }
        ]
      },

      // *** mid-class, mid population - residential districts
      AREA_CITY_MEDIUM => {
        id: AREA_CITY_MEDIUM,
        ambient: AMBIENT_CITY,
        type: 'city',
        name: 'Medium-density city area',
        width: 100,
        height: 100,
        canEnter: true,
        isInhabited: true,
        commonAI: 12,
        uncommonAI: 8,
        buildingSize: 5,
        lawResponceTime: 5,
        lawResponceAmount: 2,
        lawResponceEnabled: true,
        isHighRisk: false,
        hasMainRoad: true,
        ai: [
          'dog' => 15,
          'civilian' => 75,
          'police' => 10
        ],
        objects: [
          { id: 'sewer_hatch', amount: 20 }
        ]
      },

      // *** high-class, high population - downtown and commercial district
      AREA_CITY_HIGH => {
        id: AREA_CITY_HIGH,
        ambient: AMBIENT_CITY,
        type: 'city',
        name: 'High-density city area',
        width: 100,
        height: 100,
        canEnter: true,
        isInhabited: true,
        commonAI: 28,
        uncommonAI: 12,
        buildingSize: 10,
        lawResponceTime: 5,
        lawResponceAmount: 3,
        lawResponceEnabled: true,
        isHighRisk: true,
        hasMainRoad: true,
        ai: [
          'dog' => 5,
          'civilian' => 70,
          'police' => 25
        ],
        objects: [
          { id: 'sewer_hatch', amount: 20 }
        ]
      },

      // *** military base
      AREA_MILITARY_BASE => {
        id: AREA_MILITARY_BASE,
        ambient: AMBIENT_MILITARY,
        type: 'militaryBase',
        name: 'Military base',
        width: 50,
        height: 50,
        canEnter: true,
        isInhabited: true,
        commonAI: 10,
        uncommonAI: 0,
        buildingChance: 0.006,
        lawResponceTime: 0,
        lawResponceAmount: 0,
        lawResponceEnabled: false,
        isHighRisk: true,
        ai: [
          'soldier' => 100,
        ],
        objects: [
          { id: 'sewer_hatch', amount: 5 }
        ]
      },

      // *** facility
      AREA_FACILITY => {
        id: AREA_FACILITY,
        ambient: AMBIENT_FACILITY,
        type: 'facility',
        name: 'Facility',
        width: 75,
        height: 60,
        canEnter: true,
        isInhabited: true,
        commonAI: 5,
        uncommonAI: 0,
        buildingChance: 0.006,
        lawResponceTime: 5,
        lawResponceAmount: 2,
        lawResponceEnabled: true,
        isHighRisk: true,
        ai: [
          'civilian' => 90,
          'security' => 10
        ],
        objects: [
          { id: 'sewer_hatch', amount: 5 }
        ]
      },

      // *** habitat
      AREA_HABITAT => {
        id: AREA_HABITAT,
        ambient: AMBIENT_HABITAT,
        type: 'habitat',
        name: 'Habitat area',
        width: 20,
        height: 20,
        canEnter: true,
        isInhabited: false,
        commonAI: 0,
        uncommonAI: 0,
        buildingChance: 0,
        lawResponceTime: 10,
        lawResponceAmount: 4,
        lawResponceEnabled: true,
        isHighRisk: false,
        ai: new Map(),
        objects: []
      },
    ];


  static var regions: Array<RegionInfo> =
    [
      { // ***
        id: 'city',
      }
    ];


// get area info by id
  public inline static function getAreaInfo(id: _AreaType): AreaInfo
    {
      return areas[id];
    }


// get region info by id
  public static function getRegionInfo(id: String): RegionInfo
    {
      for (r in regions)
        if (r.id == id)
          return r;

      return null;
    }


// region types
  public static var REGION_CITY = 'city';

// amount of screen cells the AI amount is based for
  public static var AREA_AI_CELLS = 650;
}


// area info class

typedef AreaInfo = {
  var id: _AreaType; // area type id
  var ambient: _SoundAmbientLocation; // ambient sound
  var type: String; // area generator type
  var name: String; // area type name
  var width: Int; // area base width
  var height: Int; // area base height
  var canEnter: Bool; // player can enter this area?
  var isInhabited: Bool; // is this area inhabited?
  var commonAI: Int; // common ai amount spawned at any time
  var uncommonAI: Int; // uncommon ai amount spawned at any time (by area alertness)
  @:optional var buildingChance: Float; // chance to spawn building (building gen)
  @:optional var buildingSize: Int; // building size x2 (city gen)
  @:optional var hasMainRoad: Bool; // has main road (city gen)
  var lawResponceTime: Int; // number of turns until backup shows up
  var lawResponceAmount: Int; // amount of backup ai that shows up
  var lawResponceEnabled: Bool; // law responce enabled?
  var isHighRisk: Bool; // is this area type considered high risk?
  var ai: Map<String, Int>; // ai spawn probability
  var objects: Array<{ id: String, amount: Int }>; // objects spawn info
};

// region info class

typedef RegionInfo = {
  var id: String; // region type id
};

