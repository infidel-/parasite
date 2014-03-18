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

  public function new(g: Game, vx: Int, vy: Int)
    {
      game = g;
      type = 'undefined';
      id = (_maxID++);
      creationTime = game.turns;

      x = vx;
      y = vy;

      // add to area
      game.area.addObject(this);
    }


// set object decay in X turns
  public inline function setDecay(turns: Int)
    {
      game.areaManager.addObject(this, AreaManager.EVENT_OBJECT_DECAY, turns);
    }


// create entity for this AI
  public function createEntity(parentType: String)
    {
      var atlasRow: Dynamic = Reflect.field(Const, 'ROW_' + parentType.toUpperCase());
      if (atlasRow == null)
        {
          trace('No such entity type: ' + parentType);
          return;
        }
      var atlasCol: Dynamic = Reflect.field(Const, 'FRAME_' + type.toUpperCase());
      if (atlasCol == null)
        {
          trace('No such entity frame: ' + type);
          return;
        }
//      trace(atlasRow + ' ' + atlasCol);
      entity = new ObjectEntity(this, game, x, y, atlasRow, atlasCol);
      game.scene.add(entity);
    }


// dynamic: object events and stuff
  public dynamic function turn()
    {}


  public function toString(): String
    {
      return id + ' (' + x + ',' + y + ') t:' + type;
    }
}
