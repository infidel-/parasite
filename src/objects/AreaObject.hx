// object in a map area

package objects;

import h2d.Tile;
import entities.ObjectEntity;
import game.Game;
import game._Item;
import game.AreaManager;


class AreaObject
{
  var game: Game; // game state link

  public var entity: ObjectEntity; // gui entity
  public var type: String; // object type
  public var name: String; // object name
  public var item: _Item; // linked item
  var tile: Tile; // object image

  public var id: Int; // unique object id
  static var _maxID: Int = 0; // current max ID
  public var x: Int; // grid x,y
  public var y: Int;
  public var isStatic: Bool; // is this object static?
  public var creationTime: Int; // when was this object created (turns since game start)
  var _listActions: List<_PlayerAction>; // actions storage

  public function new(g: Game, vx: Int, vy: Int, ?addToCurrent: Bool = true)
    {
      game = g;
      type = 'undefined';
      name = 'undefined';
      id = (_maxID++);
      isStatic = false;
      creationTime = game.turns;
      _listActions = new List<_PlayerAction>();
      x = vx;
      y = vy;
      tile = null;

      // add to current area
      if (addToCurrent)
        game.area.addObject(this);
    }


// is this object known to player?
// atm all event objects are considered known, may be changed later
  public inline function known(): Bool
    {
      return (type == 'event_object' || game.playerArea.knowsObject(type));
    }


// get object name considering whether it's known or not
// can be overridden
  public dynamic function getName(): String
    {
      // habitat objects return level
      if (known())
        return name;
      else return 'unknown object';
    }


// set object decay in X turns
  public inline function setDecay(turns: Int)
    {
      game.managerArea.addObject(this, AREAEVENT_OBJECT_DECAY, turns);
    }


// create entity for this object
  public function createEntity(t: Tile)
    {
      if (tile == null)
        tile = t;
      entity = new ObjectEntity(this, game, x, y, tile);
    }


// show object on screen
  public inline function show()
    {
      createEntity(tile);
    }


// hide object on screen
  public inline function hide()
    {
      entity.remove();
    }


// object action
  public function action(a: _PlayerAction)
    {
      return onAction(a.id); // child callback
    }


// dynamic: object events and stuff
  public dynamic function turn()
    {}


// dynamic: current list of object actions
  public dynamic function updateActionList()
    {}

// dynamic: object action callback
// returns true on successful action
  public dynamic function onAction(id: String): Bool
    { return false; }

// dynamic: when moved onto
  public dynamic function onMoveTo()
    {}

  public function toString(): String
    {
      return id + ' (' + x + ',' + y + ') t:' + type + ' n:' + name;
    }
}
