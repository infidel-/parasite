// AI engine entity

package entities;

import h2d.Bitmap;

import ai.AI;
import game.Game;

class AIEntity extends PawnEntity
{
  var ai: AI; // AI link

  var _spriteAlert: Bitmap; // alerted state icon
  var _spriteNPC: Bitmap; // npc icon


  public function new(vai: AI, g: Game, xx: Int, yy: Int, atlasRow: Int)
    {
      super(g, xx, yy, atlasRow);

      _spriteAlert = null;
      _spriteNPC = null;
      ai = vai;
      type = "ai";
    }


// set alert image index
  public function setAlert(index: Int)
    {
      // no alert, remove image
      if (index == 0)
        {
          if (_spriteAlert == null)
            return;

          _spriteAlert.remove();
          _spriteAlert = null;
          return;
        }

      // skip same image
      var tile = game.scene.entityAtlas[index][Const.ROW_ALERT];
      if (_spriteAlert != null && _spriteAlert.tile == tile)
        return;

      if (_spriteAlert != null)
        _spriteAlert.remove();
      _spriteAlert = new Bitmap(tile, _container);
    }


// set alert image index
  public function setNPC()
    {
      if (_spriteNPC != null)
        return;

      _spriteNPC = new Bitmap(
        game.scene.entityAtlas[Const.FRAME_EVENT_NPC][Const.ROW_REGION_ICON],
        _container);
    }
}
