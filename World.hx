// game world - as in entire world subdivided into regions

class World
{
  var game: Game;

  var _list: Map<Int, WorldRegion>; // list of regions
//  public var region: WorldRegion; // current world region player is in

  public function new(g: Game)
    {
      game = g;
//      region = null;
    }


// generate a new world
  public function generate()
    {
      _list = new Map<Int, WorldRegion>();
      for (i in 0...1)
        {
          var region = new WorldRegion(ConstWorld.REGION_CITY, 30, 20);
          region.generate();
          _list.set(region.id, region);
        }

//      region = get(0);
    }


// get region by id
  public inline function get(id: Int): WorldRegion
    {
      return _list.get(id);
    }


// ==============================================================================

}
