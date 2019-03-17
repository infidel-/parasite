// objects engine entity

package entities;

import objects.AreaObject;
import game.Game;

import h2d.Bitmap;

class ObjectEntity extends Entity
{
  var object: AreaObject; // object link
  var _body: Bitmap; // body sprite
  public var atlasRow: Int; // tile atlas row


  public function new(o: AreaObject, g: Game, xx: Int, yy: Int,
      row: Int, atlasCol: Int)
    {
      super(g, Const.LAYER_OBJECT);
      type = 'object';
      object = o;
      atlasRow = row;

      _body = new Bitmap(
        game.scene.entityAtlas[atlasCol][atlasRow], _container);
    }


// set image index
  public function setImage(col: Int)
    {
      _body.remove();
      _body = new Bitmap(
        game.scene.entityAtlas[col][atlasRow],
        _container);
    }
}
