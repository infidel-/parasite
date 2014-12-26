// world and area constants

class ConstWorld
{
  static var areas: Array<AreaInfo> =
    [
      { // ***
        id: 'ground',
        type: 'wilderness',
        name: 'Uninhabited area',
        canEnter: true,
        isInhabited: false,
        commonAI: 0,
        uncommonAI: 0,
        buildingChance: 0.0,
        policeResponceTime: 0,
        policeResponceAmount: 0,
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
        canEnter: true,
        isInhabited: true,
        commonAI: 10,
        uncommonAI: 10,
        buildingChance: 0.05,
        policeResponceTime: 9,
        policeResponceAmount: 2,
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
        canEnter: true,
        isInhabited: true,
        commonAI: 20,
        uncommonAI: 20,
        buildingChance: 0.15,
        policeResponceTime: 5,
        policeResponceAmount: 2,
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
        canEnter: true,
        isInhabited: true,
        commonAI: 30,
        uncommonAI: 30,
        buildingChance: 0.30,
        policeResponceTime: 3,
        policeResponceAmount: 3,
        ai: [
          'dog' => 5,
          'civilian' => 70,
          'police' => 25
          ],
        objects: [
          { id: 'sewer_hatch', amount: 20 }
          ]
      },

      { // *** military base (TODO)
        id: 'militaryBase',
        type: 'city',
        name: 'Military base',
        canEnter: true,
        isInhabited: true,
        commonAI: 10,
        uncommonAI: 10,
        buildingChance: 0.05,
        policeResponceTime: 9,
        policeResponceAmount: 2,
        ai: [
          'dog' => 20,
          'civilian' => 75,
          'police' => 5
          ],
        objects: [
          { id: 'sewer_hatch', amount: 10 }
          ]
      },

      { // *** facility (TODO) 
        id: 'facility',
        type: 'city',
        name: 'Facility',
        canEnter: true,
        isInhabited: true,
        commonAI: 10,
        uncommonAI: 10,
        buildingChance: 0.05,
        policeResponceTime: 9,
        policeResponceAmount: 2,
        ai: [
          'dog' => 20,
          'civilian' => 75,
          'police' => 5
          ],
        objects: [
          { id: 'sewer_hatch', amount: 10 }
          ]
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

// region types
  public static var REGION_CITY = 'city';
}


// area info class

typedef AreaInfo = {
  var id: String; // area type id
  var type: String; // area generator type 
  var name: String; // area type name
  var canEnter: Bool; // player can enter this area?
  var isInhabited: Bool; // is this area inhabited?
  var commonAI: Int; // common ai amount spawned at any time
  var uncommonAI: Int; // uncommon ai amount spawned at any time (by area alertness)
  var buildingChance: Float; // chance to spawn building
  var policeResponceTime: Int; // number of turns until called police shows up
  var policeResponceAmount: Int; // actual amount of cops that show up
  var ai: Map<String, Int>; // ai spawn probability
  var objects: Array<{ id: String, amount: Int }>; // objects spawn info 
};

// region info class

typedef RegionInfo = {
  var id: String; // region type id
};

