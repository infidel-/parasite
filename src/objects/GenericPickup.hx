// generic pickup

package objects;

import game.Game;

class GenericPickup extends Pickup
{
  public function new(g: Game, vx: Int, vy: Int, imgID: Int)
    {
      super(g, vx, vy);

      createEntity(game.scene.entityAtlas
        [imgID][Const.ROW_OBJECT]);
    }
}

