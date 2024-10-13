// tile effects engine entity

package entities;

import game.Game;

class EffectEntity extends Entity
{
  public var turns: Int; // turns to live
  public var createdOn: Int; // what turn it was created on

  public function new(g: Game, xx: Int, yy: Int, t: Int)
    {
      super(g, Const.LAYER_EFFECT);
      turns = t;
      type = 'effect';
      mx = xx;
      my = yy;
      createdOn = game.turns;
    }
}
