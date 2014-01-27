// game world - as in entire world subdivided into areas

class World
{
  var game: Game;

  var _list: Map<Int, WorldArea>; // list of areas
  public var area: WorldArea; // current world area player is in
  static var maxAreaID: Int = 0; // area id counter

  public function new(g: Game)
    {
      game = g;
      area = null;
    }


// generate a new world
  public function generate()
    {
      _list = new Map<Int, WorldArea>();
      for (i in 0...10)
        {
          var area = {
            id: (maxAreaID++),
            type: TYPE_CITY_BLOCK,
            alertness: 0,
            interest: 0
            };
          _list.set(area.id, area);
        }

      area = get(0); 
    }


// get area by id
  public inline function get(id: Int): WorldArea
    {
      return _list.get(id);
    }


// ==============================================================================

// area types
  public static var TYPE_CITY_BLOCK = 'cityBlock';
}


// basic world area info

typedef WorldArea =
{
  var id: Int; // area id
  var type: String; // area type - city block, university, military base, etc
  var alertness: Int; // area alertness (authorities)
  var interest: Int; // area interest for secret groups
};
