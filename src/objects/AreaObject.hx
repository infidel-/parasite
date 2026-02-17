// object in a map area

package objects;

import entities.ObjectEntity;
import game.Game;
import game._Item;

class AreaObject extends _SaveObject
{
  static var _ignoredFields = [ 'entity' ];
  var game: Game; // game state link

  public var entity(default, null): ObjectEntity; // gui entity
  public var type: String; // object type
  public var name: String; // object name
  public var item: _Item; // linked item

  public var id: Int; // unique object id
  public var areaID: Int;
  public static var _maxID: Int = 0; // current max ID
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
      imageCol = -1;

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
      imageRow = Const.ROW_OBJECT;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
      // add to current area
      if (!onLoad)
        {
          var area = game.region.get(areaID);
          area.addObject(this);
          createEntity();
        }
    }

// update entity image
  public function updateImage()
    {
      entity.setIcon('entities', imageCol, imageRow);
    }

// create entity for this object
  function createEntity()
    {
      if (entity != null)
        return;
      entity = new ObjectEntity(this, game, x, y);
      entity.setIcon('entities', imageCol, imageRow);
      if (type == 'decorationExt')
        {
          var o: DecorationExt = cast this;
          entity.scale = o.scale;
          entity.angle = o.angle;
          entity.dx = o.dx;
          entity.dy = o.dy;
        }
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
      entity = null;
    }

// is this object known to player?
  public function known(): Bool
    {
      return game.playerArea.knowsObject(type);
    }

// is this object visible to player?
  public function visible(): Bool
    { return true; }

// is this object sensable to player when in parasite mode?
  public function sensable(): Bool
    { return false; }

// can be activated when player is next to it?
  public function canActivateNear(): Bool
    { return false; }

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

// object action
  public function action(a: _PlayerAction)
    {
      return onAction(a); // child callback
    }

// dynamic: frob object
// 0 - return false
// 1 - ok, continue
  public dynamic function frob(isPlayer: Bool, ai: ai.AI): Int
    { return 1; }


// dynamic: object events and stuff
  public dynamic function turn()
    {}


// dynamic: current list of object actions
  public dynamic function updateActionList()
    {}

// dynamic: called when the object decays by timer
  public dynamic function onDecay()
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
