// tile effects engine entity

package entities;

import game.Game;

class EffectEntity extends Entity
{
  public var x: Int;
  public var y: Int;
  public var turns: Int; // turns to live

  public function new(g: Game, xx: Int, yy: Int, t: Int)
    {
      super(g, Const.LAYER_EFFECT);
      x = xx;
      y = yy;
      turns = t;
      type = 'effect';
    }
}
