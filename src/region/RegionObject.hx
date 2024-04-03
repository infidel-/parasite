// object in a region
// no need for entity, goes into area icons

package region;

import game.Game;

class RegionObject extends _SaveObject
{
  static var _ignoredFields = [ 'icon' ];
  var game: Game; // game state link

  public var type: String; // object type
  public var name: String; // object name
  public var icon: _Icon; // object icon

  public var id: Int; // unique object id
//  public var areaID: Int;
  public static var _maxID: Int = 1; // current max ID
  public var x: Int; // grid x,y
  public var y: Int;

  public function new(g: Game, vx: Int, vy: Int)
    {
      game = g;
      id = (_maxID++);
      x = vx;
      y = vy;
      icon = null;

// will be called by sub-classes
//      init();
//      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      type = 'undefined';
      name = 'undefined';
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {}

// object action
  public function action(a: _PlayerAction)
    {
      return onAction(a); // child callback
    }

// dynamic: current list of object actions
  public dynamic function updateActionList()
    {}

// dynamic: object action callback
// returns true on successful action
  public dynamic function onAction(action: _PlayerAction): Bool
    { return false; }

// dynamic: when moved onto
  public dynamic function onMoveTo()
    {}

  public function toString(): String
    {
      return id + ' (' + x + ',' + y + ') t:' + type + ' n:' + name;
    }
}
