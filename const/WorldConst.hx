// world and area constants

package const;

class WorldConst
{
  static var areas: Array<AreaInfo> =
    [
      { // ***
        id: 'ground',
        type: 'wilderness',
        name: 'Uninhabited area',
        width: 50,
        height: 50,
        canEnter: true,
        isInhabited: false,
        commonAI: 0,
        uncommonAI: 0,
        buildingChance: 0.0,
        lawResponceTime: 0,
        lawResponceAmount: 0,
        lawResponceEnabled: false,
        ai: [
          'dog' => 5
          ],
        objects: [
          ]
      },

      { // *** low-class, low population - outskirts and suburbs
        id: 'cityLow',
        type: 'city',
        name: 'Low-density city area',
        width: 50,
        height: 50,
        canEnter: true,
        isInhabited: true,
        commonAI: 10,
        uncommonAI: 10,
        buildingChance: 0.05,
        lawResponceTime: 9,
        lawResponceAmount: 2,
        lawResponceEnabled: true,
        ai: [
          'dog' => 20,
          'civilian' => 75,
          'police' => 5
          ],
        objects: [
          { id: 'sewer_hatch', amount: 10 }
          ]
      },

      { // *** mid-class, mid population - residential districts
        id: 'cityMedium', 
        type: 'city',
        name: 'Medium-density city area',
        width: 50,
        height: 50,
        canEnter: true,
        isInhabited: true,
        commonAI: 20,
        uncommonAI: 20,
        buildingChance: 0.15,
        lawResponceTime: 5,
        lawResponceAmount: 2,
        lawResponceEnabled: true,
        ai: [
          'dog' => 15,
          'civilian' => 75,
          'police' => 10
          ],
        objects: [
          { id: 'sewer_hatch', amount: 20 }
          ]
      },

      { // *** high-class, high population - downtown and commercial district
        id: 'cityHigh', 
        type: 'city',
        name: 'High-density city area',
        width: 50,
        height: 50,
        canEnter: true,
        isInhabited: true,
        commonAI: 30,
        uncommonAI: 30,
        buildingChance: 0.30,
        lawResponceTime: 3,
        lawResponceAmount: 3,
        lawResponceEnabled: true,
        ai: [
          'dog' => 5,
          'civilian' => 70,
          'police' => 25
          ],
        objects: [
          { id: 'sewer_hatch', amount: 20 }
          ]
      },

      { // *** military base
        id: 'militaryBase',
        type: 'militaryBase',
        name: 'Military base',
        width: 50,
        height: 50,
        canEnter: true,
        isInhabited: true,
        commonAI: 10,
        uncommonAI: 0,
        buildingChance: 0.005,
        lawResponceTime: 0,
        lawResponceAmount: 0,
        lawResponceEnabled: false,
        ai: [
          'soldier' => 100,
          ],
        objects: [
          { id: 'sewer_hatch', amount: 5 }
          ]
      },

      { // *** facility
        id: 'facility',
        type: 'facility',
        name: 'Facility',
        width: 50,
        height: 50,
        canEnter: true,
        isInhabited: true,
        commonAI: 10,
        uncommonAI: 0,
        buildingChance: 0.005,
        lawResponceTime: 5,
        lawResponceAmount: 2,
        lawResponceEnabled: true,
        ai: [
          'civilian' => 90,
          'security' => 10
          ],
        objects: [
          { id: 'sewer_hatch', amount: 5 }
          ]
      },

      { // *** habitat
        id: 'habitat',
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
  public static function getAreaInfo(id: String): AreaInfo
    {
      for (a in areas)
        if (a.id == id)
          return a;

      return null;
    }


// get region info by id
  public static function getRegionInfo(id: String): RegionInfo
    {
      for (r in regions)
        if (r.id == id)
          return r;

      return null;
    }


// area types
  public static var AREA_GROUND = 'ground';
  public static var AREA_CITY_LOW = 'cityLow';
  public static var AREA_CITY_MEDIUM = 'cityMedium';
  public static var AREA_CITY_HIGH = 'cityHigh';
  public static var AREA_MILITARY_BASE = 'militaryBase';
  public static var AREA_FACILITY = 'facility';
  public static var AREA_HABITAT = 'habitat';

// region types
  public static var REGION_CITY = 'city';
}


// area info class

typedef AreaInfo = {
  var id: String; // area type id
  var type: String; // area generator type 
  var name: String; // area type name
  var width: Int; // area base width
  var height: Int; // area base height
  var canEnter: Bool; // player can enter this area?
  var isInhabited: Bool; // is this area inhabited?
  var commonAI: Int; // common ai amount spawned at any time
  var uncommonAI: Int; // uncommon ai amount spawned at any time (by area alertness)
  var buildingChance: Float; // chance to spawn building
  var lawResponceTime: Int; // number of turns until backup shows up
  var lawResponceAmount: Int; // amount of backup ai that shows up
  var lawResponceEnabled: Bool; // law responce enabled?
  var ai: Map<String, Int>; // ai spawn probability
  var objects: Array<{ id: String, amount: Int }>; // objects spawn info 
};

// region info class

typedef RegionInfo = {
  var id: String; // region type id
};

