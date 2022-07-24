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
        name: 'Enter Drain',
        energy: 10,
        obj: this
      });
    }


// activate sewers - leave area
  override function onAction(id: String): Bool
    {
      if (game.player.state != PLR_STATE_PARASITE)
        {

          game.log("You can only enter the drain without a host.", COLOR_HINT);
          return false;
        }
      game.log("You slither through the drain escaping the prying eyes.");
      game.turns++; // manually increase number of turns
      game.setLocation(LOCATION_REGION);
      game.goals.complete(GOAL_ENTER_SEWERS);

      return true;
    }

  public override function sensable(): Bool
    { return true; }
}
