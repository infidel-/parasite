// combat mission with clustered targets guarding a location
package cult.missions;

import ai.AIData;
import game.Game;
import cult.missions.Combat.CombatSpawnTarget;

class CombatTargetsWithGuards extends Combat
{
  // rival members a strike mission marks
  public static inline var RIVAL_TARGETS = 3;
  // the rival whose roster members are the targets (-1: generated targets)
  public var rivalCultID: Int;

// create a combat mission with targets guarding a location. a rival ID makes the targets real roster
// members of that rival (combatInfo then only places the mission: its targets are replaced)
  public function new(g: Game, combatInfo: _CombatMissionInfo, ?rivalCultID: Int = -1)
    {
      super(g, combatInfo);
      if (rivalCultID >= 0)
        initRival(rivalCultID);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = N('Eliminate Targets');
      note = N('Multiple targets guard a single location.');
      rivalCultID = -1;
    }

// combat info for a rival strike: one placeholder target that only places the mission in a city area
// ponytail: Combat's ctor needs a valid target list, so this stub is built and then replaced by roster members
  public static function rivalInfo(): _CombatMissionInfo
    {
      return {
        template: TARGET_WITH_GUARDS,
        targets: [
          {
            target: {
              job: N('cultist'),
              type: 'civilian',
              icon: 'formalCivilian',
              location: AREA_CITY_MEDIUM,
            },
            amount: [1, 1, 1],
            loadout: null,
          },
        ],
      };
    }

// replaces the generated targets with up to RIVAL_TARGETS random roster members of the rival, never its leader
  function initRival(rivalCultID: Int)
    {
      this.rivalCultID = rivalCultID;
      name = N('Rival Strike');
      note = N('Kill the marked cultists of the rival.');
      var pool = game.getRivalCultByID(rivalCultID).members.slice(1);
      pool.sort(function(a, b) return Std.random(3) - 1);
      if (pool.length > RIVAL_TARGETS)
        pool.resize(RIVAL_TARGETS);
      targets = pool;
      targetIDs = [for (t in pool) t.id];
      primaryTarget = pool[0];
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

// spawns a target, a rival member as a member of its cult
  override function spawnMissionTarget(data: AIData, x: Int, y: Int)
    {
      super.spawnMissionTarget(data, x, y);
      if (rivalCultID >= 0)
        game.area.getAIByID(data.id).setCult(game.getRivalCultByID(rivalCultID));
    }

// template-specific turn processing
  override function turnTemplate()
    {
      // a marked member that left the roster elsewhere (a raid killed it, the rival fell) is no target now
      if (rivalCultID >= 0)
        {
          var rival = game.getRivalCultByID(rivalCultID);
          for (id in targetIDs.copy())
            if (rival.getMemberByID(id) == null)
              targetIDs.remove(id);
          if (targetIDs.length == 0)
            {
              success();
              return;
            }
        }

      var missing = getMissingTargets();
      if (missing.length == 0)
        return;

      if (clusterX < 0 ||
          clusterY < 0)
        {
          // muster around a chosen object type (e.g. burning barrels) when the ordeal asks for it
          var center: _Point = { x: -1, y: -1 };
          if (spawnNearType != null)
            center = game.area.findLocationNearObject(spawnNearType);
          if (center.x < 0)
            center = game.area.findUnseenEmptyLocation();
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
