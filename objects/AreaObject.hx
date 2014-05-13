// object in a map area

package objects;

import entities.ObjectEntity;

class AreaObject
{
  var game: Game; // game state link

  public var entity: ObjectEntity; // gui entity
  public var type: String; // object type

  public var id: Int; // unique object id
  static var _maxID: Int = 0; // current max ID
  public var x: Int; // grid x,y
  public var y: Int;
  public var creationTime: Int; // when was this object created (turns since game start)
  var _listActions: List<_PlayerAction>; // actions storage

  public function new(g: Game, vx: Int, vy: Int)
    {
      game = g;
      type = 'undefined';
      id = (_maxID++);
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
      game.area.manager.addObject(this, AreaManager.EVENT_OBJECT_DECAY, turns);
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
      game.scene.add(entity);
    }


// check if player has enough energy and add action to list
  inline function addAction(id: String, name: String, energy: Int)
    {
      if (game.player.energy >= energy)
        _listActions.add({ id: id, name: name, energy: energy });
    }


// get actions for this object
  public function addActions(tmp: List<_PlayerAction>)
    {
      _listActions.clear();
      updateActionsList(); // overridden by children

      for (a in _listActions)
        tmp.add({ id: 'o:' + a.id, name: a.name, energy: a.energy });
    }


// object action
  public function action(id: String): _PlayerAction
    {
      onAction(id); // child callback
      for (a in _listActions)
        if (a.id == id)
          return a;

      return null;
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
