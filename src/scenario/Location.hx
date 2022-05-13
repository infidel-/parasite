// scenario location

package scenario;

import game.Game;
import game.AreaGame;

class Location extends _SaveObject
{
  var game: Game;
  static var _ignoredFields = [ 'area' ];
  public var id: String; // unique location id
  public var name: String; // location name
  public var hasName: Bool; // does this location have name?
  public var areaID: Int; // area id
  public var area(get, null): AreaGame; // area link


  public function new(g: Game, vid: String)
    {
      game = g;
      id = vid;
      areaID = - 1;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      hasName = false;
      name = '-';
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }

  function get_area()
    {
      return game.world.get(0).get(areaID);
    }

  public function toString()
    {
      return 'id: ' + id + ', name: ' + name + ', hasName: ' + hasName +
        ', (' + area.x + ',' + area.y + ')';
    }
}
