// clone vat object used by underground lab mission

package objects.mission;

import cult.missions.CombatUndergroundLabPurge;
import game.Game;
import objects.AreaObject;

class CloneVat extends AreaObject
{
  public var missionID: Int;
  public var isFlushed: Bool;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, vmissionID: Int)
    {
      super(g, vaid, vx, vy);
      init();
      missionID = vmissionID;
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      missionID = -1;
      isFlushed = false;
      type = 'clone_vat';
      name = 'cloning vat';
      imageRow = Const.ROW_OBJECT2;
      imageCol = Const.FRAME_CLONE_VAT;
      isStatic = true;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// allow using the vat from adjacent tiles
  public override function canActivateNear(): Bool
    {
      return true;
    }

// expose mission action for vat flushing
  override function updateActionList()
    {
      if (isFlushed)
        return;

      game.ui.hud.addAction({
        id: 'flushCloneVat',
        type: ACTION_OBJECT,
        name: 'Purge growth medium',
        energy: 10,
        obj: this,
      });
    }

// handle clone vat action
  override function onAction(action: _PlayerAction): Bool
    {
      if (action.id != 'flushCloneVat')
        return false;

      if (isFlushed)
        {
          game.actionFailed('This vat is already draining.');
          return true;
        }

      isFlushed = true;
      imageCol = Const.FRAME_CLONE_VAT_FLUSHED;
      updateImage();
      game.scene.draw();

      game.log('You trigger a purge cycle. Green slurry hisses into the drains.');

      var mission = game.cults[0].ordeals.getMissionByID(missionID);
      if (mission == null ||
          mission.isCompleted ||
          mission.type != MISSION_COMBAT)
        return true;

      var labMission: CombatUndergroundLabPurge = cast mission;
      labMission.onVatFlushed(id);
      return true;
    }

  public override function known(): Bool
    {
      return true;
    }
}
