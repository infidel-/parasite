// world and area constants

class ConstWorld
{
  static var areas: Array<AreaInfo> =
    [
      { // ***
        id: 'cityBlock', 
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


// get area info by id
  public static function getAreaInfo(id: String): AreaInfo
    {
      for (a in areas)
        if (a.id == id)
          return a;

      return null;
    }


// area types
  public static var AREA_CITY_BLOCK = 'cityBlock';
}


// area info class

typedef AreaInfo = {
  var id: String; // area type id
  var commonAI: Int; // common ai amount spawned at any time
  var uncommonAI: Int; // uncommon ai amount spawned at any time
  var ai: Map<String, Int>; // ai spawn probability
  var objects: Array<{ id: String, amount: Int }>; // objects spawn info 
};
