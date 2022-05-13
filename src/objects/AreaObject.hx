// object in a map area

package objects;

import h2d.Tile;
import entities.ObjectEntity;
import game.Game;
import game._Item;
import game.AreaManager;

class AreaObject extends _SaveObject
{
  static var _ignoredFields = [ 'tile', 'entity' ];
  var game: Game; // game state link

  public var entity: ObjectEntity; // gui entity
  public var type: String; // object type
  public var name: String; // object name
  public var item: _Item; // linked item
  var tile: Tile; // object image

  public var id: Int; // unique object id
  public var areaID: Int;
  static var _maxID: Int = 0; // current max ID
  public var x: Int; // grid x,y
  public var y: Int;
  public var isStatic: Bool; // is this object static?
  public var creationTime: Int; // when was this object created (turns since game start)
  public var imageRow: Int;
  public var imageCol: Int;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int)
    {
      game = g;
      id = (_maxID++);
      areaID = vaid;
      creationTime = game.turns;
      x = vx;
      y = vy;

// will be called by sub-classes
//      init();
//      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      type = 'undefined';
      name = 'undefined';
      isStatic = false;
      tile = null;
      imageRow = Const.ROW_OBJECT;
      imageCol = -1;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
      tile = game.scene.entityAtlas[imageCol][imageRow];
      // add to current area
      if (!onLoad)
        {
          var area = game.region.get(areaID);
          area.addObject(this);
//          trace('create entity ' + type + ' ' + x + ',' + y + ' (' + areaID + ')');
          createEntity();
        }
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
  function createEntity()
    {
//      Const.traceStack();
//      trace('new object ' + type + ' ' + x + ',' + y + ' (' + areaID + ')');
      entity = new ObjectEntity(this, game, x, y, tile);
    }


// show object on screen
  public inline function show()
    {
//      trace('object ' + type + ' ' + x + ',' + y + ' show' + ' (' + areaID + ')');
      createEntity();
    }


// hide object on screen
  public inline function hide()
    {
 //     trace('object ' + type + ' ' + x + ',' + y + ' hide' + ' (' + areaID + ')');
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
