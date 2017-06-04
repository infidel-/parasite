// AI engine entity

package entities;

import com.haxepunk.graphics.Spritemap;
import ai.AI;

import game.Game;

class AIEntity extends PawnEntity
{
  var ai: AI; // AI link

  var _spriteAlert: Spritemap; // alerted state icon
  var _spriteNPC: Spritemap; // npc icon


  public function new(vai: AI, g: Game, xx: Int, yy: Int, atlasRow: Int)
    {
      super(g, xx, yy, atlasRow);

      _spriteAlert = new Spritemap(game.scene.entityAtlas,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      _spriteAlert.frame = Const.FRAME_EMPTY;
      _list.add(_spriteAlert);

      _spriteNPC = new Spritemap(game.scene.entityAtlas,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      _spriteNPC.frame = Const.FRAME_EMPTY;
      _list.add(_spriteNPC);

      ai = vai;
      type = "ai";
    }


// set alert image index
  public inline function setAlert(index)
    {
      _spriteAlert.setFrame(index, Const.ROW_ALERT);
    }


// set alert image index
  public inline function setNPC()
    {
      _spriteNPC.setFrame(Const.FRAME_EVENT_NPC, Const.ROW_REGION_ICON);
    }
}
