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
      if (!game.playerArea.cultLeavePre(action))
        return false;

      // the underground lab's freight lift has its own departure, and in 3D the car carries the
      // player up the shaft first: the leave and the action's energy and turn then run at the top,
      // and the action reports itself interrupted so PlayerArea spends nothing now
      var lab = (game.area.typeID == AREA_UNDERGROUND_LAB);
      game.scene.sounds.play(lab ? 'lab/depart' : 'object-elevator');
      if (lab &&
          game.scene.view3d.liftDepart(function()
            {
              leave();
              game.player.actionEnergy(action);
              game.playerArea.actionPost();
            }))
        return false;
      leave();
      return true;
    }

// leave the area for the region
  function leave()
    {
      var leavingAreaID = game.area.id;
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
    }

  public override function known() :Bool
    { return true; }
}
