// game world - as in entire world subdivided into regions

package game;

import const.WorldConst;
import ai.AIData;
import objects.AreaObject;
import region.RegionObject;

class World extends _SaveObject
{
  var game: Game;

  var _list: Map<Int, RegionGame>; // list of regions
//  public var region: RegionGame; // current world region player is in

  public function new(g: Game)
    {
      game = g;
      _list = new Map();
//      region = null;
    }

// post load
  public function loadPost()
    {
      AIData._maxID = 0;
      AreaGame._maxID = 0;
      AreaObject._maxID = 0;
      RegionGame._maxID = 0;
      RegionObject._maxID = 0;
      for (r in _list)
        {
          if (r.id > RegionGame._maxID)
            RegionGame._maxID = r.id;
          for (o in @:privateAccess r._objects)
            {
              if (o.id > RegionObject._maxID)
                RegionObject._maxID = r.id;
            }
          for (a in @:privateAccess r._list)
            {
              a.loadPost();
              if (a.hasHabitat)
                {
                  var habarea = r.get(a.habitatAreaID);
                  habarea.loadPost();
                }
            }
        }
      AreaGame._maxID++;
      AreaObject._maxID++;
      RegionGame._maxID++;
      AIData._maxID++;
    }

// generate a new world
  public function generate()
    {
      _list = new Map();
      for (i in 0...1)
        {
          var region = new RegionGame(game, WorldConst.REGION_CITY, 32, 24);
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
