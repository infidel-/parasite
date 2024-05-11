// elevator spot - leads to sewers

package objects;

import game.Game;

class Elevator extends AreaObject
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
      // empty tile
      imageRow = 0;
      imageCol = 0;
      type = 'elevator';
      name = 'elevator';
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
          id: 'leaveArea',
          type: ACTION_OBJECT,
          name: 'Leave area',
          energy: 5,
          isAgreeable: true,
          obj: this
        });
    }


// activate sewers - leave area
  override function onAction(action: _PlayerAction): Bool
    {
      // scenario-specific checks
      if (!game.goals.leaveAreaPre())
        return false;

      game.scene.sounds.play('object-elevator');
      game.log("You leave the corporate building entering the sewers.");
      game.turns++; // manually increase number of turns
      game.setLocation(LOCATION_REGION);
      game.goals.complete(GOAL_ENTER_SEWERS);

      return true;
    }

  public override function known() :Bool
    { return true; }
}
