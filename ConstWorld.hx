// world and area constants

class ConstWorld
{
  static var areas: Array<AreaInfo> =
    [
      { // ***
        id: 'ground', 
        commonAI: 0,
        uncommonAI: 0,
        ai: [
          'dog' => 0
          ],
        objects: [
          ]
      },

      { // ***
        id: 'cityLow', 
        commonAI: 20,
        uncommonAI: 20,
        ai: [
          'dog' => 15,
          'civilian' => 75,
          'police' => 10
          ],
        objects: [
          { id: 'sewer_hatch', amount: 20 }
          ]
      },

      { // ***
        id: 'cityMedium', 
        commonAI: 20,
        uncommonAI: 20,
        ai: [
          'dog' => 15,
          'civilian' => 75,
          'police' => 10
          ],
        objects: [
          { id: 'sewer_hatch', amount: 20 }
          ]
      },

      { // ***
        id: 'cityHigh', 
        commonAI: 20,
        uncommonAI: 20,
        ai: [
          'dog' => 15,
          'civilian' => 75,
          'police' => 10
          ],
        objects: [
          { id: 'sewer_hatch', amount: 20 }
          ]
      }
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

// region types
  public static var REGION_CITY = 'city';
}


// area info class

typedef AreaInfo = {
  var id: String; // area type id
  var commonAI: Int; // common ai amount spawned at any time
  var uncommonAI: Int; // uncommon ai amount spawned at any time
  var ai: Map<String, Int>; // ai spawn probability
  var objects: Array<{ id: String, amount: Int }>; // objects spawn info 
};

// region info class

typedef RegionInfo = {
  var id: String; // region type id
};

