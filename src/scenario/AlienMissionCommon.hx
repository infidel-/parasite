// container for abduction mission goal-related methods

package scenario;

import scenario.GoalsAlienCrashLanding;
import scenario.GoalsAlienCrashLanding.*;
import ai.*;
import game.*;

class AlienMissionCommon
{
// on receive goal
  public static function onReceive(game:Game, player:Player)
    {
      // find random area
      var area = game.region.getRandom({ type: AREA_CORP, noEvents: true });

      // add hidden NPC to it
      // NOTE: all dynamic NPCs should belong to an event anyway
      var npc = new NPC(game);
      npc.event = game.timeline.getEvent('alienMission');
      npc.event.npc.push(npc);
      npc.isMale = true;
      npc.tileAtlasX = 3;
      npc.tileAtlasY = 4;
      npc.job = 'corporate executive';
      npc.jobKnown = true;
      npc.type = 'corpo';
      npc.areaID = area.id;
      npc.areaKnown = true;
      npc.noEventClues = true; // cannot brain probe for clues
      area.npc.add(npc);
      game.debug('' + npc);

      // store npc id for later use
      var missionState: _MissionState = {
        npcID: npc.id,
        areaID: area.id,
        areaX: 0,
        areaY: 0,
        guardX: 0,
        guardY: 0,
        alertRaised: false,
      };
      game.timeline.setVar('missionState', missionState);
    }

  public static function aiInit(game:Game, ai:AI)
    {
      if (ai.type != 'smiler')
        return;
      // if we're in the mission target area, spawn with key card
      var missionState = getMissionState(game);
      if (game.area.id != missionState.areaID)
        return;
      var item = ai.inventory.addID('keycard');
      item.lockID = 'corp-mission';
    }

// called every turn
  public static function onTurn(game:Game, player:Player)
    {
      var missionState = getMissionState(game);
      var missionType = game.timeline.getStringVar('alienMissionType');
      switch (missionType)
        {
          // if player has target host, complete goal
          case 'abduction':
            if (player.state == PLR_STATE_HOST &&
                player.host.npc != null &&
                player.host.npc.id == missionState.npcID)
              game.goals.complete(SCENARIO_ALIEN_MISSION_ABDUCTION);
        }

      // when in mission area, check for alertness
      if (!missionState.alertRaised &&
          game.area.id == missionState.areaID)
        {
          // check if area manager has call law events
          for (ev in game.managerArea.getList())
            if (ev.type == AREAEVENT_CALL_LAW ||
                ev.type == AREAEVENT_ALERT_LAW ||
                ev.type == AREAEVENT_ARRIVE_LAW)
              {
                missionState.alertRaised = true;
                game.area.alertness = 100;
                var languageID = getLanguageID(game);
                game.message(
                  '<span class=alien' + languageID + '>' + 'Galbuzp</span>! The alert was raised. I cannot leave this location without completing the mission.', 'event/security_alert');
                break;
              }
        }
      // alert raised
      if (game.area.id == missionState.areaID &&
          missionState.alertRaised)
        {
          // freeze alertness
          game.area.alertness = 100;
/* not really playable
          // increase AI alertness
          for (ai in game.area.getAllAI())
            ai.alertness += 10;*/
        }

      var npc = game.timeline.getEventNPC('alienMission',
        missionState.npcID);
      switch (missionType)
        {
          // if mission npc is dead, fail the goal
          case 'abduction':
            if (npc.isDead)
              game.goals.fail(SCENARIO_ALIEN_MISSION_ABDUCTION);
          case 'liquidation':
            if (npc.isDead)
              game.goals.complete(SCENARIO_ALIEN_MISSION_LIQUIDATION);
          case 'intel':
            if (npc.isDead)
              game.goals.fail(SCENARIO_ALIEN_MISSION_INTEL);
            else
              {
                var playerHost = player.host;
                if (playerHost != null &&
                    playerHost.npc != null &&
                    playerHost.npc.id == missionState.npcID &&
                    playerHost.brainProbed > 0)
                  game.goals.complete(SCENARIO_ALIEN_MISSION_INTEL);
              }
        }
    }

  public static function leaveAreaPre(game:Game, player:Player, area: AreaGame)
    {
      // when in corp area, disallow on alert raised
      var missionState = getMissionState(game);
      if (game.area.id != missionState.areaID)
        return true;
      if (missionState.alertRaised)
        {
          game.actionFailed('You cannot leave this area without completing the mission.');
          return false;
        }
      return true;
    }

  public static function onEnter(game:Game)
    {
      var missionState = getMissionState(game);
      // goal active, on enter spawn CEO
      if (game.area.id != missionState.areaID)
        return;
      // first entry - find a spot
      var firstTime = false;
      var pt = {
        x: missionState.areaX,
        y: missionState.areaY
      };
      var guardPt = {
        x: missionState.guardX,
        y: missionState.guardY
      }
      if (pt.x == 0 && pt.y == 0)
        {
          // find mission target spawn point
          pt = rollMissionTargetXY(game);
          missionState.areaX = pt.x;
          missionState.areaY = pt.y;
          // find personal guard spawn point
          guardPt = rollGuardXY(game, pt);
          firstTime = true;
        }

      // spawn ceo
      var npc = null;
      for (v in game.area.npc)
        if (v.id == missionState.npcID)
          {
            npc = v;
            break;
          }
      var ai = game.area.spawnAI('corpo', pt.x, pt.y);
      game.debug('spawn npc ' + npc.id + ' (ai: ' + ai.id + ', pos: ' + ai.x + ',' + ai.y + ')');
      ai.setNPC(npc);
      ai.isGuard = true;
      if (guardPt != null)
        {
          var guard = game.area.spawnAI('security', guardPt.x, guardPt.y);
          guard.isGuard = true;
        }

      // find all doors leading to this room and lock them
      if (firstTime)
        {
          // find room record
          var generatorInfo = game.area.generatorInfo;
          var room = generatorInfo.getRoomAt(ai.x, ai.y);
          if (room == null)
            {
              trace('room is null for (' + ai.x + ',' + ai.y + ')!');
              return;
            }
          var doors = [];
          for (d in generatorInfo.doors)
            if (d.roomID1 == room.id ||
                d.roomID2 == room.id)
              {
                doors.push(d);
                break;
              }
          // lock all doors with key card
//            trace(doors);
          for (door in doors)
            {
              var objs = game.area.getObjectsAt(door.x, door.y);
              for (o in objs)
                if (o.type == 'door')
                  {
                    var d: objects.Door = cast o;
                    d.isLocked = true;
                    d.lockID = 'corp-mission';
                    break;
                  }
            }
        }
    }

// helper - find new spawn point for personal guard
  static function rollGuardXY(game, pt)
    {
      // get all points around the mission target
      var pts = [];
      for (yy in pt.y - 3...pt.y + 3)
        for (xx in pt.x - 3...pt.x + 3)
          if (game.area.isWalkable(xx, yy))
            if (xx != pt.x || yy != pt.y)
              pts.push({ x: xx, y: yy });
      if (pts.length == 0)
        return null;
      return pts[Std.random(pts.length)];
    }

// helper - find new spawn point for corp mission target
  static function rollMissionTargetXY(game)
    {
      // find nearest office (marble floor)
      // NOTE: there can be no office, then the task is easier
      // limit by 100 points
      var solopts = [];
      var workpts = [];
      var meetingpts = [];
      var cells = game.area.getCells();
      for (y in 0...cells.length)
        if (solopts.length < 100)
          {
            for (x in 0...cells[y].length)
              if (cells[x][y] == Const.TILE_FLOOR_MARBLE1)
                solopts.push({ x: x, y: y });
              else if (cells[x][y] == Const.TILE_FLOOR_CARPET_MEETING)
                meetingpts.push({ x: x, y: y });
              else if (cells[x][y] == Const.TILE_FLOOR_WOOD2)
                workpts.push({ x: x, y: y });
          }
        else break;

      // solo office -> meeting room -> work room
      var pt = null;
      if (solopts.length > 0)
        {
          game.debug('solo office found');
          pt = solopts[Std.random(solopts.length)];
        }
      else if (meetingpts.length > 0)
        {
          game.debug('meeting room found');
          pt = meetingpts[Std.random(meetingpts.length)];
        }
      else
        {
          game.debug('work room found');
          pt = workpts[Std.random(workpts.length)];
        }

      return pt;
    }

// mission note
  public static function noteFunc(game:Game): String
    {
      var missionState = getMissionState(game);
      var area = game.world.get(0).get(missionState.areaID);
      return Const.col('gray', Const.small(
        'Target location: (' + area.x + ',' + area.y + ')'));
    }
}
