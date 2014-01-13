// object in a map area

import entities.ObjectEntity;

class AreaObject
{
  var game: Game; // game state link

  public var entity: ObjectEntity; // gui entity
  public var type: String; // object type

  public var isHumanBody: Bool; // is this a human body?

  public var id: Int; // unique object id
  static var _maxID: Int = 0; // current max ID
  public var x: Int; // grid x,y
  public var y: Int;

  public function new(g: Game, vx: Int, vy: Int)
    {
      game = g;
      type = 'undefined';
      id = (_maxID++);
      isHumanBody = false;

      x = vx;
      y = vy;
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
}
