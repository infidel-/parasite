// sewer exit object used in mission sewer areas

package objects;

import game.Game;

class SewerExit extends AreaObject
{
  public var missionID: Int;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, ?vmissionID: Int = -1)
    {
      super(g, vaid, vx, vy);
      missionID = vmissionID;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      missionID = -1;
      imageCol = Const.FRAME_SEWER_HATCH;
      type = 'sewer_exit';
      name = 'sewer exit';
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
        id: 'leaveArea',
        type: ACTION_OBJECT,
        name: 'Leave area',
        energy: 10,
        isAgreeable: true,
        obj: this
      });
    }

// activate sewer exit and clean completed mission area if needed
  override function onAction(action: _PlayerAction): Bool
    {
      if (!game.area.canLeave())
        return false;

      var leavingAreaID = game.area.id;
      game.scene.sounds.play('object-sewers');
      game.log("You leave the mission site through the sewers.");
      game.turns++; // manually increase number of turns
      game.setLocation(LOCATION_REGION);

      // remove the mission area from the region
      if (missionID >= 0)
        game.region.removeArea(leavingAreaID);

      return true;
    }

  public override function known(): Bool
    { return true; }
}
