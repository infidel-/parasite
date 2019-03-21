// objects engine entity

package entities;

import h2d.Bitmap;
import h2d.Tile;
import objects.AreaObject;
import game.Game;


class ObjectEntity extends Entity
{
  var object: AreaObject; // object link
  var _body: Bitmap; // body sprite


  public function new(o: AreaObject, g: Game, xx: Int, yy: Int, t: Tile)
    {
      super(g, Const.LAYER_OBJECT);
      type = 'object';
      object = o;

      _body = new Bitmap(t, _container);
    }


// set image
  public function setImage(tile: Tile)
    {
      _body.remove();
      _body = new Bitmap(tile, _container);
    }
}
