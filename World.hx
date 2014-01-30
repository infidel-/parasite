// game world - as in entire world subdivided into areas

class World
{
  var game: Game;

  var _list: Map<Int, WorldArea>; // list of areas
  public var area: WorldArea; // current world area player is in

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
          var area = new WorldArea(ConstWorld.AREA_CITY_BLOCK);
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

}


