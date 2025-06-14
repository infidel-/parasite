// floor drain - leads to sewers when activated

package objects;

import game.Game;

class FloorDrain extends AreaObject
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
      imageRow = Const.ROW_OBJECT_INDOOR;
      imageCol = Const.FRAME_FLOOR_DRAIN;
      type = 'floor_drain';
      name = 'floor drain';
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
      game.ui.hud.addAction({
        id: 'enterDrain',
        type: ACTION_OBJECT,
        name: 'Enter drain',
        energy: 10,
        obj: this
      });
    }

// activate - leave area
  override function onAction(action: _PlayerAction): Bool
    {
      if (game.player.state != PLR_STATE_PARASITE)
        {
          game.actionFailed("You can only enter the drain without a host.");
          return false;
        }
      // scenario-specific checks
      if (!game.goals.leaveAreaPre())
        return false;

      game.log("You slither through the drain escaping the prying eyes.");
      game.turns++; // manually increase number of turns
      game.setLocation(LOCATION_REGION);
      game.goals.complete(GOAL_ENTER_SEWERS);

      return true;
    }

  public override function sensable(): Bool
    { return true; }
}
