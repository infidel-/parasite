// game world - as in entire world subdivided into regions

package game;

import const.WorldConst;

class World
{
  var game: Game;

  var _list: Map<Int, RegionGame>; // list of regions
//  public var region: RegionGame; // current world region player is in

  public function new(g: Game)
    {
      game = g;
//      region = null;
    }


// generate a new world
  public function generate()
    {
      _list = new Map<Int, RegionGame>();
      for (i in 0...1)
        {
          var region = new RegionGame(WorldConst.REGION_CITY, 30, 20);
          region.generate();
          _list.set(region.id, region);
        }

//      region = get(0);
    }


// get region by id
  public inline function get(id: Int): RegionGame
    {
      return _list.get(id);
    }


// ==============================================================================

}
