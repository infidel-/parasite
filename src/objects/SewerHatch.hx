// sewer hatch - leads to sewers when activated

package objects;

import game.Game;

class SewerHatch extends AreaObject
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);

      type = 'sewer_hatch';
      name = 'sewer hatch';
      isStatic = true;

      createEntity(Const.ROW_OBJECT, Const.FRAME_SEWER_HATCH);
    }


// update actions
  override function updateActionsList()
    {
      if (game.player.state != PLR_STATE_ATTACHED)
        addAction('enterSewers', 'Enter Sewers', 10);
    }


// activate sewers - leave area
  override function onAction(id: String): Bool
    {
      if (game.player.state == PLR_STATE_HOST && !game.player.host.isHuman)
        {
          game.log("This host cannot open the sewer hatch.", COLOR_HINT);
          return false;
        }

      game.log("You enter the damp fetid sewers, escaping the prying eyes.");
      game.turns++; // manually increase number of turns
      game.setLocation(LOCATION_REGION);

      return true;
    }
}
