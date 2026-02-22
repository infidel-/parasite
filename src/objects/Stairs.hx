// exit stairs - leads to sewers

package objects;

import game.Game;

class Stairs extends AreaObject
{
  public var missionID: Int;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, ?vmissionID: Int = -1)
    {
      super(g, vaid, vx, vy);
      missionID = vmissionID;
      init();
      missionID = vmissionID;
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      missionID = -1;
      imageCol = Const.FRAME_STAIRS;
      type = 'stairs';
      name = 'stairs';
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
      // we allow using stairs without a host
      game.ui.hud.addAction({
        id: 'leaveArea',
        type: ACTION_OBJECT,
        name: 'Leave area',
        energy: 10,
        isAgreeable: true,
        obj: this
      });
    }


// activate sewers - leave area
  override function onAction(action: _PlayerAction): Bool
    {
      if (!game.area.canLeave())
        return false;

      var leavingAreaID = game.area.id;
      game.scene.sounds.play('object-stairs');
      if (missionID >= 0)
        game.log("You leave the mission site.");
      else
        game.log("You leave the corporate building entering the sewers.");
      game.turns++; // manually increase number of turns
      game.setLocation(LOCATION_REGION);

      if (missionID < 0)
        game.goals.complete(GOAL_ENTER_SEWERS);
      else
        game.region.removeArea(leavingAreaID);

      return true;
    }

  public override function known() :Bool
    { return true; }
}
