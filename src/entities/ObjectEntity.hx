// objects engine entity

package entities;

import objects.AreaObject;
import game.Game;


class ObjectEntity extends Entity
{
  var object: AreaObject; // object link


  public function new(o: AreaObject, g: Game, xx: Int, yy: Int)
    {
      super(g, Const.LAYER_OBJECT);
      type = 'object';
      object = o;
      mx = xx;
      my = yy;
    }
}
