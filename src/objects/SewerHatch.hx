// sewer hatch - leads to sewers when activated

package objects;

import game.Game;

class SewerHatch extends AreaObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int)
    {
      super(g, vaid, vx, vy);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      imageCol = Const.FRAME_SEWER_HATCH;
      type = 'sewer_hatch';
      name = 'sewer hatch';
      isStatic = true;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }


// update actions
  override function updateActionList()
    {
      if (game.player.state != PLR_STATE_ATTACHED)
        game.ui.hud.addAction({
          id: 'enterSewers',
          type: ACTION_OBJECT,
          name: 'Enter sewers',
          energy: 10,
          isAgreeable: true,
          obj: this
        });
    }


// activate sewers - leave area
  override function onAction(action: _PlayerAction): Bool
    {
      if (game.player.state == PLR_STATE_HOST &&
          !game.player.host.isHuman)
        {
          game.actionFailed("This host cannot open the sewer hatch.");
          return false;
        }
      // scenario-specific checks
      if (!game.goals.leaveAreaPre())
        return false;

      game.scene.sounds.play('object-sewers');
      game.log("You enter the damp fetid sewers escaping the prying eyes.");
      game.turns++; // manually increase number of turns
      game.setLocation(LOCATION_REGION);
      game.goals.complete(GOAL_ENTER_SEWERS);

      return true;
    }

  public override function sensable(): Bool
    { return true; }
}
