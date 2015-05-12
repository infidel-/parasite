// object in a map area

package objects;

import entities.ObjectEntity;

import game.Game;
import game.Item;
import game.AreaManager;


class AreaObject
{
  var game: Game; // game state link

  public var entity: ObjectEntity; // gui entity
  public var type: String; // object type
  public var name: String; // object name 
  public var item: Item; // linked item

  public var id: Int; // unique object id
  static var _maxID: Int = 0; // current max ID
  public var x: Int; // grid x,y
  public var y: Int;
  public var isStatic: Bool; // is this object static?
  public var creationTime: Int; // when was this object created (turns since game start)
  var _listActions: List<_PlayerAction>; // actions storage

  public function new(g: Game, vx: Int, vy: Int)
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

      // add to area
      game.area.addObject(this);
    }


// set object decay in X turns
  public inline function setDecay(turns: Int)
    {
      game.managerArea.addObject(this, AREAEVENT_OBJECT_DECAY, turns);
    }


// create entity for this AI (using parent type as a row)
  public function createEntityByType(parentType: String)
    {
      var atlasRow: Int = Reflect.field(Const, 'ROW_' + parentType.toUpperCase());
      if (atlasRow == null)
        {
          trace('No such entity type: ' + parentType);
          return;
        }
      var atlasCol: Int = Reflect.field(Const, 'FRAME_' + type.toUpperCase());
      if (atlasCol == null)
        {
          trace('No such entity frame: ' + type);
          return;
        }
//      trace(atlasRow + ' ' + atlasCol);
      createEntity(atlasRow, atlasCol);
    }


// create entity for this AI
  public inline function createEntity(atlasRow: Int, atlasCol: Int)
    {
      entity = new ObjectEntity(this, game, x, y, atlasRow, atlasCol);
      show();
    }


// show object on screen
  public inline function show()
    {
      game.scene.add(entity); 
    }


// hide object on screen
  public inline function hide()
    {
      game.scene.remove(entity); 
    }


// check if player has enough energy and add action to list
  inline function addAction(id: String, name: String, energy: Int)
    {
      if (game.player.energy >= energy)
        _listActions.add({ 
          id: id, 
          type: ACTION_OBJECT, 
          name: name, 
          energy: energy,
          obj: this });
    }


// get actions for this object
  public function addActions(tmp: List<_PlayerAction>)
    {
      _listActions.clear(); // clear old list
      updateActionsList(); // overridden by children

      // add to external list
      for (a in _listActions)
        tmp.add(a);
    }


// object action
  public function action(a: _PlayerAction)
    {
      onAction(a.id); // child callback
    }


// dynamic: object events and stuff
  public dynamic function turn()
    {}


// dynamic: current list of object actions
  dynamic function updateActionsList()
    {}

// dynamic: object action callback
  public dynamic function onAction(id: String)
    {}


  public function toString(): String
    {
      return id + ' (' + x + ',' + y + ') t:' + type;
    }
}
