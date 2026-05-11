// mission to destroy a simplified rival cult base
package cult.missions;

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

// spawn sanctum and defenders
  public override function turn()
    {
      if (spawned ||
          game.location != LOCATION_AREA ||
          game.area == null ||
          game.area.id != areaID)
        return;
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
      for (i in 0...3)
        {
          var spawn = game.area.findEmptyLocationNear(guardX, guardY, 5);
          if (spawn == null)
            continue;
          var ai = game.area.spawnAI(i == 0 ? 'security' : 'thug',
            spawn.x, spawn.y);
          ai.isGuard = true;
          ai.guardTargetX = guardX;
          ai.guardTargetY = guardY;
        }
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
      for (dy in 0...RivalSanctum.SANCTUM_H)
        for (dx in 0...RivalSanctum.SANCTUM_W)
          {
            var partIndex = dy * RivalSanctum.SANCTUM_W + dx;
            sanctums.push(new RivalSanctum(game, game.area.id,
              x + dx, y + dy, id, partIndex));
          }

      var partObjectIDs = [];
      for (sanctum in sanctums)
        partObjectIDs.push(sanctum.id);

      var rootObjectID = sanctums[0].id;
      for (sanctum in sanctums)
        sanctum.setSanctumGroup(rootObjectID, partObjectIDs);
      return sanctums[0];
    }

// marks rival destroyed
  public override function onSuccess()
    {
      var rival = game.getCultByID(rivalCultID);
      rival.state = CULT_STATE_DEAD;
    }
}
