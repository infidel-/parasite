// tile effects engine entity

package entities;

import game.Game;

import h2d.Bitmap;

class EffectEntity extends Entity
{
  public var x: Int;
  public var y: Int;
  public var turns: Int; // turns to live
  var _body: Bitmap; // body sprite map


  public function new(g: Game, xx: Int, yy: Int, t: Int, atlasRow: Int, atlasCol: Int)
    {
      super(g, Const.LAYER_EFFECT);
      x = xx;
      y = yy;
      turns = t;
      type = 'effect';

      _body = new Bitmap(
        game.scene.entityAtlas[atlasCol][atlasRow], _container);
    }
}
