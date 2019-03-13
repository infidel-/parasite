// player entity (used both in area and region modes)

package entities;

import game.Game;

class PlayerEntity extends PawnEntity
{
  public function new(g: Game, xx: Int, yy: Int)
    {
      super(g, xx, yy, Const.ROW_PARASITE);

      type = "player";
    }
}
