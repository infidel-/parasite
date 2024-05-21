// objects engine entity

package entities;

import js.html.CanvasRenderingContext2D;
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

  public override function draw(ctx: CanvasRenderingContext2D)
    {
      super.draw(ctx);
      if (object.type == 'door')
        {
          var door: objects.Door = cast object;
          if (door.isLocked)
            drawImage(ctx,
              game.scene.images.entities,
              Const.FRAME_LOCKED_ICON,
              Const.ROW_OBJECT);
        }

    }
}
