// scenario location

package scenario;

import game.AreaGame;

class Location extends _SaveObject
{
  static var _ignoredFields = [ 'area' ];
  public var id: String; // unique location id
  public var name: String; // location name
  public var hasName: Bool; // does this location have name?
  public var area: AreaGame; // area link


  public function new(vid: String)
    {
      id = vid;
      init();
      loadPost();
    }

// init object before loading/post creation
  public function init()
    {
      hasName = false;
      name = '-';
    }

// called after load or creation
  public function loadPost()
    {
    }


  public function toString()
    {
      return 'id: ' + id + ', name: ' + name + ', hasName: ' + hasName +
        ', (' + area.x + ',' + area.y + ')';
    }
}
