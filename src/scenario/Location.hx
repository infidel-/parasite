// scenario location

package scenario;

import game.AreaGame;

class Location
{
  public var id: String; // unique location id
  public var name: String; // location name
  public var hasName: Bool; // does this location have name?
  public var area: AreaGame; // area link


  public function new(vid: String)
    {
      id = vid;
      hasName = false;
      name = '-';
    }


  public function toString()
    {
      return 'id: ' + id + ', name: ' + name + ', hasName: ' + hasName +
        ', (' + area.x + ',' + area.y + ')';
    }
}
