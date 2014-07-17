// tile effects engine entity

package entities;

import com.haxepunk.Entity;
import com.haxepunk.graphics.Spritemap;

class EffectEntity extends Entity
{
  var game: Game;

  public var turns: Int; // turns to live
  var _spriteBody: Spritemap; // body sprite map


  public function new(g: Game, xx: Int, yy: Int, t: Int, atlasRow: Int, atlasCol: Int)
    {
      super(xx * Const.TILE_WIDTH, yy * Const.TILE_HEIGHT);
      game = g;
      turns = t;

      _spriteBody = new Spritemap(game.scene.entityAtlas, 32, 32);
      _spriteBody.setFrame(atlasCol, atlasRow);

      type = "undefined";
      layer = Const.LAYER_EFFECT;
      graphic = _spriteBody;
    }


// set position on map
  public inline function setPosition(vx: Int, vy: Int)
    {
      x = vx * Const.TILE_WIDTH;
      y = vy * Const.TILE_HEIGHT;
    }


// set image index
  public inline function setImage(index: Int)
    {
      _spriteBody.frame = index;
    }


// get image index
  public inline function getImage(): Int
    {
      return _spriteBody.frame;
    }
}
