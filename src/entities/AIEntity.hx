// AI engine entity

package entities;

import h2d.Bitmap;

import ai.AI;
import game.Game;

class AIEntity extends PawnEntity
{
  var ai: AI; // AI link

  var _alert: Bitmap; // alerted state icon
  var _npc: Bitmap; // npc icon


  public function new(vai: AI, g: Game, xx: Int, yy: Int, atlasRow: Int)
    {
      super(g, xx, yy, atlasRow);

      _alert = null;
      _npc = null;
      ai = vai;
      type = "ai";
    }


// set alert image index
  public function setAlert(index: Int)
    {
      // no alert, remove image
      if (index == 0)
        {
          if (_alert == null)
            return;

          _alert.remove();
          _alert = null;
          return;
        }

      // skip same image
      var tile = game.scene.entityAtlas[index][Const.ROW_ALERT];
      if (_alert != null && _alert.tile == tile)
        return;

      if (_alert != null)
        _alert.remove();
      _alert = new Bitmap(tile, _container);
    }


// set alert image index
  public function setNPC()
    {
      if (_npc != null)
        return;

      _npc = new Bitmap(
        game.scene.entityAtlas[Const.FRAME_EVENT_NPC][Const.ROW_REGION_ICON],
        _container);
    }
}
