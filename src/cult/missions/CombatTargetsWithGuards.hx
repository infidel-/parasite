// combat mission with clustered targets guarding a location
package cult.missions;

import game.Game;
import cult.missions.Combat.CombatSpawnTarget;

class CombatTargetsWithGuards extends Combat
{
// create a combat mission with targets guarding a location
  public function new(g: Game, combatInfo: _CombatMissionInfo)
    {
      super(g, combatInfo);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'Eliminate Targets';
      note = 'Multiple targets guard a single location.';
    }

// template-specific initialization
  override function initTemplate(combatInfo: _CombatMissionInfo, targetList: Array<CombatSpawnTarget>)
    {
      var area = game.region.getMissionArea(targetList[0].target);
      if (area != null)
        {
          x = area.x;
          y = area.y;
        }
    }

// template-specific turn processing
  override function turnTemplate()
    {
      var missing = getMissingTargets();
      if (missing.length == 0)
        return;

      if (clusterX < 0 ||
          clusterY < 0)
        {
          var center = game.area.findUnseenEmptyLocation();
          if (center.x < 0)
            center = game.area.findEmptyLocationNear(
              game.playerArea.x, game.playerArea.y, 5);
          if (center == null)
            return;
          clusterX = center.x;
          clusterY = center.y;
        }

      for (t in missing)
        {
          var loc = game.area.findEmptyLocationNear(clusterX, clusterY, 2);
          if (loc == null)
            return;
          spawnMissionTarget(t, loc.x, loc.y);
        }
    }
}
