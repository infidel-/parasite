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
  override function onAction(id: String)
    {
      game.log("You enter the damp fetid sewers, escaping the prying eyes.");
      game.turns++; // manually increase number of turns
      game.setLocation(LOCATION_REGION);
    }
}
