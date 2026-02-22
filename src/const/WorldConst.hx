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
        pediaArticle: 'areaUninhabited',
        exit: '-',
        alertnessMod: 0.50,
        width: 100,
        height: 100,
        canEnter: true,
        isInhabited: false,
        commonAI: 0,
        uncommonAI: 0,
        lawType: 'police',
        lawResponseTime: 0,
        lawResponseAmount: 0,
        lawResponseMax: 0,
        lawResponseEnabled: false,
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
        pediaArticle: 'areaCity',
        exit: 'sewer_hatch',
        alertnessMod: 0.75,
        width: 100,
        height: 100,
        canEnter: true,
        isInhabited: true,
        commonAI: 8,
        uncommonAI: 5,
        buildingSize: 1,
        lawType: 'police',
        lawResponseTime: 10,
        lawResponseAmount: 2,
        lawResponseMax: 4,
        lawResponseEnabled: true,
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
        pediaArticle: 'areaCity',
        exit: 'sewer_hatch',
        alertnessMod: 1.0,
        width: 100,
        height: 100,
        canEnter: true,
        isInhabited: true,
        commonAI: 12,
        uncommonAI: 8,
        buildingSize: 5,
        lawType: 'police',
        lawResponseTime: 5,
        lawResponseAmount: 2,
        lawResponseMax: 6,
        lawResponseEnabled: true,
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
        pediaArticle: 'areaCity',
        exit: 'sewer_hatch',
        alertnessMod: 1.25,
        width: 100,
        height: 100,
        canEnter: true,
        isInhabited: true,
        commonAI: 28,
        uncommonAI: 12,
        buildingSize: 10,
        lawType: 'police',
        lawResponseTime: 5,
        lawResponseAmount: 3,
        lawResponseMax: 8,
        lawResponseEnabled: true,
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
        pediaArticle: 'areaMilitary',
        exit: 'sewer_hatch',
        alertnessMod: 1.5,
        width: 50,
        height: 50,
        canEnter: true,
        isInhabited: true,
        commonAI: 10,
        uncommonAI: 0,
        buildingChance: 0.006,
        lawType: 'police',
        lawResponseTime: 0,
        lawResponseAmount: 0,
        lawResponseMax: 0,
        lawResponseEnabled: false,
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
        pediaArticle: 'areaLab',
        exit: 'sewer_hatch',
        alertnessMod: 2.0,
        width: 75,
        height: 60,
        canEnter: true,
        isInhabited: true,
        commonAI: 5,
        uncommonAI: 0,
        buildingChance: 0.006,
        lawType: 'security',
        lawResponseTime: 5,
        lawResponseAmount: 2,
        lawResponseMax: 4,
        lawResponseEnabled: true,
        isHighRisk: true,
        ai: [
          'scientist' => 90,
          'security' => 10
        ],
        objects: [] // moved to facility generator
      },

      // *** mission sewers
      AREA_SEWERS => {
        id: AREA_SEWERS,
        ambient: AMBIENT_HABITAT,
        type: 'sewers',
        name: 'Sewers',
        pediaArticle: 'areaHabitat', // unused
        exit: 'sewer_exit',
        alertnessMod: 1.0,
        width: 75,
        height: 60,
        canEnter: true,
        isInhabited: true,
        commonAI: 0,
        uncommonAI: 0,
        buildingChance: 0,
        lawType: 'police',
        lawResponseTime: 0,
        lawResponseAmount: 0,
        lawResponseMax: 0,
        lawResponseEnabled: false,
        isHighRisk: false,
        ai: new Map(),
        objects: []
      },

      // *** mission underground laboratory
      AREA_UNDERGROUND_LAB => {
        id: AREA_UNDERGROUND_LAB,
        ambient: AMBIENT_FACILITY,
        type: 'undergroundLab',
        name: 'Underground Laboratory',
        pediaArticle: 'areaLab',
        exit: 'elevator',
        alertnessMod: 1.0,
        width: 45,
        height: 35,
        canEnter: true,
        isInhabited: true,
        commonAI: 0,
        uncommonAI: 0,
        buildingChance: 0,
        lawType: 'security',
        lawResponseTime: 0,
        lawResponseAmount: 0,
        lawResponseMax: 0,
        lawResponseEnabled: false,
        isHighRisk: true,
        ai: new Map(),
        objects: []
      },

      // *** habitat
      AREA_HABITAT => {
        id: AREA_HABITAT,
        ambient: AMBIENT_HABITAT,
        type: 'habitat',
        name: 'Habitat area',
        pediaArticle: 'areaHabitat', // unused
        exit: '-',
        alertnessMod: 1.0,
        width: 20,
        height: 20,
        canEnter: true,
        isInhabited: false,
        commonAI: 0,
        uncommonAI: 0,
        buildingChance: 0,
        lawType: 'police',
        lawResponseTime: 10,
        lawResponseAmount: 4,
        lawResponseMax: 4,
        lawResponseEnabled: true,
        isHighRisk: false,
        ai: new Map(),
        objects: []
      },

      // *** corpo building floor
      AREA_CORP => {
        id: AREA_CORP,
        ambient: AMBIENT_CORP,
        type: 'corp',
        name: 'Corporate HQ',
        pediaArticle: 'areaCorp',
        exit: 'elevator',
        alertnessMod: 1.5,
        width: 75,
        height: 60,
        canEnter: true,
        isInhabited: true,
        commonAI: 10,
        uncommonAI: 5,
        buildingChance: 0.006,
        lawType: 'security',
        lawResponseTime: 5,
        lawResponseAmount: 2,
        lawResponseMax: 4,
        lawResponseEnabled: true,
        isHighRisk: true,
        ai: [
          'corpo' => 70,
          'smiler' => 20,
          'security' => 10
        ],
        objects: [] // moved to facility generator
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
  var lawType: String; // police, security
  var lawResponseTime: Int; // number of turns until backup shows up
  var lawResponseAmount: Int; // amount of backup ai that shows up
  var lawResponseMax: Int; // maximum amount of law ai on screen during response
  var lawResponseEnabled: Bool; // law responce enabled?
  var isHighRisk: Bool; // is this area type considered high risk?
  var ai: Map<String, Int>; // ai spawn probability
  var objects: Array<{ id: String, amount: Int }>; // objects spawn info
  // area alertness modifier on alertness propagation and increase/decrease
  // < 1.0 - slow 
  // > 1.0 - fast
  var alertnessMod: Float;
  var pediaArticle: String; // pedia article
  var exit: String; // exit object
};

// region info class

typedef RegionInfo = {
  var id: String; // region type id
};
