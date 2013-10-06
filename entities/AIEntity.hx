// AI engine entity

package entities;

import com.haxepunk.graphics.Spritemap;

class AIEntity extends PawnEntity
{
  var ai: AI; // AI link

  var _spriteAlert: Spritemap; // alerted state icon


  public function new(vai: AI, g: Game, xx: Int, yy: Int, frameIndex: Int)
    {
      super(g, xx, yy, frameIndex);

      _spriteAlert = new Spritemap(game.scene.entityAtlas, 32, 32);
      _spriteAlert.frame = Const.FRAME_EMPTY;
      _list.add(_spriteAlert);
      _spriteAlert.frame = Const.FRAME_EMPTY;

      ai = vai;
      type = "ai";
    }


// set alert image index
  public inline function setAlert(index: Int)
    {
      _spriteAlert.frame = index;
    }
}
