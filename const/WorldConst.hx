// world and area constants

package const;

class WorldConst
{
  static var areas: Map<_AreaType, AreaInfo> =
    [
      // *** wilderness around city
      AREA_GROUND => {
        id: AREA_GROUND,
        type: 'wilderness',
        name: 'Uninhabited area',
        width: 100,
        height: 100,
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

      // *** low-class, low population - outskirts and suburbs
      AREA_CITY_LOW => { 
        id: AREA_CITY_LOW,
        type: 'city',
        name: 'Low-density city area',
        width: 100,
        height: 100,
        canEnter: true,
        isInhabited: true,
        commonAI: 10,
        uncommonAI: 10,
        buildingChance: 0.05,
        lawResponceTime: 10,
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

      // *** mid-class, mid population - residential districts
      AREA_CITY_MEDIUM => { 
        id: AREA_CITY_MEDIUM, 
        type: 'city',
        name: 'Medium-density city area',
        width: 100,
        height: 100,
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

      // *** high-class, high population - downtown and commercial district
      AREA_CITY_HIGH => {
        id: AREA_CITY_HIGH, 
        type: 'city',
        name: 'High-density city area',
        width: 100,
        height: 100,
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

      // *** military base
      AREA_MILITARY_BASE => { 
        id: AREA_MILITARY_BASE,
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

      // *** facility
      AREA_FACILITY => { 
        id: AREA_FACILITY,
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

      // *** habitat
      AREA_HABITAT => {
        id: AREA_HABITAT,
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
}


// area info class

typedef AreaInfo = {
  var id: _AreaType; // area type id
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

