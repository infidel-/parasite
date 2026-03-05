// elevator spot - leads to sewers

package objects;

import game.Game;
import tiles.UndergroundLab;

class Elevator extends AreaObject
{
  public var missionID: Int;
  public var elevatorPartIndex: Int;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, ?vmissionID: Int = -1,
      ?velevatorPartIndex: Int = 0, ?vimageName: String = null)
    {
      super(g, vaid, vx, vy);
      init();
      elevatorPartIndex = velevatorPartIndex;
      missionID = vmissionID;
      if (vimageName != null)
        imageName = vimageName;
      updateElevatorIcon();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      missionID = -1;
      elevatorPartIndex = 0;
      type = 'elevator';
      name = 'elevator';
      isStatic = true;
      updateElevatorIcon();
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
      updateElevatorIcon();
    }

// update icon for default or underground elevator art
  function updateElevatorIcon()
    {
      if (imageName == UndergroundLab.OBJECTS_IMAGE)
        {
          var block = UndergroundLab.ELEVATOR;
          imageRow = block.row + Std.int(elevatorPartIndex / block.width);
          imageCol = block.col + elevatorPartIndex % block.width;
        }
      else
        {
          imageRow = 0;
          imageCol = 0;
        }
      if (entity != null)
        updateImage();
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
      if (!game.area.canLeave())
        return false;

      var leavingAreaID = game.area.id;
      game.scene.sounds.play('object-elevator');
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
