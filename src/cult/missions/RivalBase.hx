// mission to destroy a simplified rival cult base
package cult.missions;

import ai.AI;
import ai.AIData;
import const.CultConst;
import cult.Mission;
import game.Game;
import objects.RivalSanctum;
import objects.mission.SewerExit;

class RivalBase extends Mission
{
  public var rivalCultID: Int;
  public var spawned: Bool;

  public function new(g: Game, rivalCultID: Int, markerAreaID: Int)
    {
      super(g);
      init();
      initPost(false);
      this.rivalCultID = rivalCultID;
      setMarkerAreaID(markerAreaID);
      var missionArea = game.region.createArea(AREA_SEWERS);
      missionArea.parentID = markerAreaID;
      missionArea.width = 29;
      missionArea.height = 29;
      areaID = missionArea.id;
    }

// init mission fields
  public override function init()
    {
      super.init();
      type = MISSION_COMBAT;
      name = 'Rival Base';
      note = 'Destroy the rival sanctum.';
      rivalCultID = -1;
      spawned = false;
    }

// spawn sanctum and update defender hostility
  public override function turn()
    {
      if (game.location != LOCATION_AREA ||
          game.area == null ||
          game.area.id != areaID)
        return;

      if (!spawned)
        {
          setupSewerExits();
          var loc = findSanctumRoomLocation();
          if (loc == null)
            loc = findSanctumLocationNear(game.playerArea.x,
            game.playerArea.y, 6);
          if (loc == null)
            loc = findSanctumLocation();
          if (loc == null)
            return;
          spawned = true;
          spawnSanctumGroup(loc.x, loc.y);
          var guardX = loc.x + 1;
          var guardY = loc.y + 1;
          var defenders = rivalDefenders();
          for (data in defenders)
            {
              var spawn = game.area.findEmptyLocationNear(guardX, guardY, 5);
              if (spawn == null)
                continue;
              spawnRivalDefender(data, spawn.x, spawn.y, guardX, guardY);
            }
        }

      updateDefenderEnemies();
    }

// returns rival cultists available to guard this base
  function rivalDefenders(): Array<AIData>
    {
      var rival = game.getCultByID(rivalCultID);
      var members = [];
      for (i in 0...rival.members.length)
        if (i > 0 ||
            rival.members.length == 1)
          members.push(rival.members[i]);
      members.sort(function(a, b) return Std.random(3) - 1);
      if (members.length > 4)
        members.resize(4);
      return members;
    }

// spawns one cultist defender near the sanctum
  function spawnRivalDefender(data: AIData, x: Int, y: Int,
      guardX: Int, guardY: Int): AI
    {
      var rival = game.getCultByID(rivalCultID);
      var ai = game.area.spawnAI(data.type, x, y, false);
      ai.updateData(data, 'on rival base spawn');
      ai.setCult(rival);
      ai.isAggressive = true;
      ai.isRelentless = true;
/*
      ai.isGuard = true;
      ai.guardTargetX = guardX;
      ai.guardTargetY = guardY;*/
      game.area.addAI(ai);
      return ai;
    }

// updates rival defenders with all attackers in the mission area
  function updateDefenderEnemies()
    {
      var attackers = rivalBaseAttackers();
      if (attackers.length == 0)
        return;

      for (defender in rivalBaseDefenders())
        {
          for (attacker in attackers)
            defender.addEnemy(attacker);
          if (defender.state != AI_STATE_ALERT)
            defender.setState(AI_STATE_ALERT);
        }
    }

// returns live rival cultists defending this base
  function rivalBaseDefenders(): Array<AI>
    {
      var defenders = [];
      for (ai in game.area.getAllAI())
        if (ai.state != AI_STATE_DEAD &&
            ai.state != AI_STATE_PRESERVED &&
            ai.isCultist &&
            ai.cultID == rivalCultID)
          defenders.push(ai);
      return defenders;
    }

// returns live player-side attackers in this mission area
  function rivalBaseAttackers(): Array<AI>
    {
      var attackers = [];
      for (ai in game.area.getAllAI())
        if (isRivalBaseAttacker(ai))
          attackers.push(ai);

      if (game.player.state == PLR_STATE_HOST &&
          isRivalBaseHostAttacker(game.player.host) &&
          attackers.indexOf(game.player.host) < 0)
        attackers.push(game.player.host);
      return attackers;
    }

// checks whether an AI is a player cult attacker
  function isRivalBaseAttacker(ai: AI): Bool
    {
      return (
        ai != null &&
        ai.state != AI_STATE_DEAD &&
        ai.state != AI_STATE_PRESERVED &&
        ai.isPlayerCultist()
      );
    }

// checks whether the current player host should draw defender hostility
  function isRivalBaseHostAttacker(ai: AI): Bool
    {
      return (
        ai != null &&
        ai.state != AI_STATE_DEAD &&
        ai.state != AI_STATE_PRESERVED &&
        (!ai.isCultist ||
         ai.cultID != rivalCultID)
      );
    }

// marks mission sewer exits so completed mission areas are removed
  function setupSewerExits()
    {
      for (o in game.area.getObjects())
        if (o.type == 'sewer_exit')
          {
            var exit: SewerExit = cast o;
            exit.missionID = id;
          }
    }

// finds a valid 2x2 sanctum anchor inside sewer rooms
  function findSanctumRoomLocation(): { x: Int, y: Int }
    {
      if (game.area.generatorInfo == null ||
          game.area.generatorInfo.rooms == null ||
          game.area.generatorInfo.rooms.length == 0)
        return null;

      var valid = [];
      var preferred = [];
      for (room in game.area.generatorInfo.rooms)
        {
          var centerX = room.x1 + Std.int(room.w / 2);
          var centerY = room.y1 + Std.int(room.h / 2);
          var anchor = findSanctumAnchorInRoom(room, centerX, centerY);
          if (anchor == null)
            continue;
          var info = {
            room: room,
            anchor: anchor,
          };
          valid.push(info);
          if (!hasSewerExitInRoom(room))
            preferred.push(info);
        }

      var pool = (preferred.length > 0 ? preferred : valid);
      if (pool.length == 0)
        return null;
      return pool[Std.random(pool.length)].anchor;
    }

// finds closest valid sanctum anchor inside one room
  function findSanctumAnchorInRoom(room: _Room,
      centerX: Int, centerY: Int): { x: Int, y: Int }
    {
      var desiredX = centerX - 1;
      var desiredY = centerY - 1;
      var spots = [];
      for (y in room.y1...room.y2 - RivalSanctum.SANCTUM_H + 2)
        for (x in room.x1...room.x2 - RivalSanctum.SANCTUM_W + 2)
          {
            if (!canPlaceSanctumAt(x, y))
              continue;
            var dx = x - desiredX;
            var dy = y - desiredY;
            spots.push({
              x: x,
              y: y,
              d2: dx * dx + dy * dy,
            });
          }
      return closestSanctumSpot(spots);
    }

// checks whether one room contains a sewer exit
  function hasSewerExitInRoom(room: _Room): Bool
    {
      for (o in game.area.getObjects())
        {
          if (o.type != 'sewer_exit')
            continue;
          if (o.x < room.x1 ||
              o.x > room.x2 ||
              o.y < room.y1 ||
              o.y > room.y2)
            continue;
          return true;
        }
      return false;
    }

// find closest valid 2x2 sanctum anchor near a tile
  function findSanctumLocationNear(xo: Int, yo: Int,
      radius: Int): { x: Int, y: Int }
    {
      var spots = [];
      for (dy in -radius...radius)
        for (dx in -radius...radius)
          {
            var x = xo + dx;
            var y = yo + dy;
            if (!canPlaceSanctumAt(x, y))
              continue;
            spots.push({
              x: x,
              y: y,
              d2: dx * dx + dy * dy,
            });
          }
      return closestSanctumSpot(spots);
    }

// find a valid 2x2 sanctum anchor anywhere in the area
  function findSanctumLocation(): { x: Int, y: Int }
    {
      var spots = [];
      for (y in 0...game.area.height - RivalSanctum.SANCTUM_H + 1)
        for (x in 0...game.area.width - RivalSanctum.SANCTUM_W + 1)
          {
            if (!canPlaceSanctumAt(x, y))
              continue;
            var dx = x - game.playerArea.x;
            var dy = y - game.playerArea.y;
            spots.push({
              x: x,
              y: y,
              d2: dx * dx + dy * dy,
            });
          }
      return closestSanctumSpot(spots);
    }

// choose closest sanctum spot with stable tie breaks
  function closestSanctumSpot(
      spots: Array<{ x: Int, y: Int, d2: Int }>): { x: Int, y: Int }
    {
      if (spots.length == 0)
        return null;
      spots.sort(function(a, b)
        {
          if (a.d2 != b.d2)
            return a.d2 - b.d2;
          if (a.y != b.y)
            return a.y - b.y;
          return a.x - b.x;
        });
      return {
        x: spots[0].x,
        y: spots[0].y,
      };
    }

// check whether a 2x2 sanctum can be placed at top-left tile x,y
  function canPlaceSanctumAt(x: Int, y: Int): Bool
    {
      for (dy in 0...RivalSanctum.SANCTUM_H)
        for (dx in 0...RivalSanctum.SANCTUM_W)
          {
            var tx = x + dx;
            var ty = y + dy;
            if (!game.area.isWalkable(tx, ty) ||
                game.area.hasObjectAt(tx, ty) ||
                game.area.getAI(tx, ty) != null ||
                (game.playerArea.x == tx &&
                 game.playerArea.y == ty))
              return false;
          }
      return true;
    }

// spawn one linked 2x2 sanctum group
  function spawnSanctumGroup(x: Int, y: Int): RivalSanctum
    {
      var sanctums = [];
      var icon = getSanctumIcon();
      for (dy in 0...RivalSanctum.SANCTUM_H)
        for (dx in 0...RivalSanctum.SANCTUM_W)
          {
            var partIndex = dy * RivalSanctum.SANCTUM_W + dx;
            sanctums.push(new RivalSanctum(game, game.area.id,
              x + dx, y + dy, id, partIndex, icon));
          }

      var partObjectIDs = [];
      for (sanctum in sanctums)
        partObjectIDs.push(sanctum.id);

      var rootObjectID = sanctums[0].id;
      for (sanctum in sanctums)
        sanctum.setSanctumGroup(rootObjectID, partObjectIDs);
      return sanctums[0];
    }

// returns cult-specific sanctum icon
  function getSanctumIcon(): _Icon
    {
      var rival = game.getRivalCultByID(rivalCultID);
      return CultConst.info(rival.rivalInfoID).sanctumIcon;
    }

// marks rival destroyed
  public override function onSuccess()
    {
      var rival = game.getCultByID(rivalCultID);
      rival.state = CULT_STATE_DEAD;
    }
}
