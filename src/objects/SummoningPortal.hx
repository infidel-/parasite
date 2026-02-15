// summoning portal object used by ritual combat mission
// NOTE: we assume this does not need to be saved/loaded!

package objects;

import cult.missions.CombatSummoningRitual;
import game.Game;

class SummoningPortal extends AreaObject
{
  public var missionID: Int;

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
      type = 'summoning_portal';
      name = 'summoning portal';
      imageRow = Const.ROW_OBJECT;
      imageCol = Const.FRAME_EVENT_OBJECT;
      isStatic = true;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// monitor player proximity to trigger ritual start
  public override function turn()
    {
      var mission = game.cults[0].ordeals.getMissionByID(missionID);
      if (mission == null ||
          mission.isCompleted ||
          mission.type != MISSION_COMBAT)
        return;
      var ritual: CombatSummoningRitual = cast mission;

      if (Const.distanceSquared(game.playerArea.x, game.playerArea.y, x, y) > 10 * 10)
        return;

      ritual.onPortalProximity(this);
    }

  public override function known(): Bool
    { return true; }
}
