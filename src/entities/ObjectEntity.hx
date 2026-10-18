// objects engine entity

package entities;

import game.Game;

class ObjectEntity extends Entity
{
  public function new(g: Game, xx: Int, yy: Int)
    {
      super(g);
      mx = xx;
      my = yy;
    }
}
