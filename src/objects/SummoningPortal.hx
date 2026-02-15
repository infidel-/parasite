// summoning portal object used by ritual combat mission
// NOTE: we assume this does not need to be saved/loaded!

package objects;

import cult.missions.Combat;
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
      // get mission
      var mission = game.cults[0].ordeals.getMissionByID(missionID);
      if (mission == null ||
          mission.isCompleted ||
          mission.type != MISSION_COMBAT)
        return;
      var combat: Combat = cast mission;
      if (combat.template != SUMMONING_RITUAL)
        return;

      // check player proximity
      if (Const.distanceSquared(game.playerArea.x, game.playerArea.y, x, y) > 10 * 10)
        return;

      combat.onPortalProximity(this);
    }

  public override function known(): Bool
    { return true; }
}
