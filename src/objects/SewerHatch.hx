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

      createEntity(game.scene.entityAtlas
        [Const.FRAME_SEWER_HATCH][Const.ROW_OBJECT]);
    }


// update actions
  override function updateActionList()
    {
      if (game.player.state != PLR_STATE_ATTACHED)
        game.ui.hud.addAction({
          id: 'enterSewers',
          type: ACTION_OBJECT,
          name: 'Enter Sewers',
          energy: 10,
          obj: this
        });
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
      game.goals.complete(GOAL_ENTER_SEWERS);

      return true;
    }
}
