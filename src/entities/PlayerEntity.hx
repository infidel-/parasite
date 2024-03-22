// player entity (used both in area and region modes)

package entities;

import game.Game;

class PlayerEntity extends PawnEntity
{
  public function new(g: Game, xx: Int, yy: Int)
    {
      super(g, xx, yy);
      setIcon('entities', 0, Const.ROW_PARASITE);

      // re-add to correct layer
      _container.remove();
      game.scene.add(_container, Const.LAYER_PLAYER);

      type = "player";
    }
}
