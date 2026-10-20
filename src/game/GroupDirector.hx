// group regional director goal hooks: spawn on a military base in a locked room with blackops
// guards, keycards on the door sentry and the base officers, alarm lock-in, note.
// the same shape as scenario.AlienMissionCommon

package game;

import ai.AI;
import gen.facility.FacilityTemp;

class GroupDirector
{
  static inline var LOCK_ID = 'group-director';

// intel complete: pick the base, the group feels the leak, then receive the goal
// (the goals hud reads noteFunc while receiving, so the base has to be picked first)
  public static function start(game: Game)
    {
      var group = game.group;
      var area = game.region.getRandom({ type: AREA_MILITARY_BASE });
      group.directorAreaID = area.id;
      group.directorX = 0;
      group.directorY = 0;
      group.directorID = -1;
      group.directorAlert = false;

      // the group knows the parasite is coming
      group.priority = 100;
      if (group.team != null)
        group.team.distance /= 2;
      else if (group.teamTimeout > 20)
        group.teamTimeout = 20;
      game.message({
        text: 'I know who directs the hunt: a regional controller working out of a military base. They will know I am coming.',
        img: 'pedia/group'
      });
      game.goals.receive(GOAL_GROUP_DIRECTOR);

      // already standing on that base
      if (game.location == LOCATION_AREA &&
          game.area.id == area.id)
        onEnter(game);
    }

// ai constructor hook: the officers on the director's base carry the room keycard
  public static function aiInit(game: Game, ai: AI)
    {
      if (ai.type != 'officer' ||
          game.area.id != game.group.directorAreaID)
        return;
      var item = ai.inventory.addID('keycard');
      item.lockID = LOCK_ID;
    }

// on area entry: spawn the director and the guards, lock the room on the first visit
  public static function onEnter(game: Game)
    {
      var group = game.group;
      if (game.area.id != group.directorAreaID)
        return;

      // first visit: pick the room and the director's spot in it
      var info = game.area.generatorInfo;
      var firstTime = (group.directorX == 0 &&
        group.directorY == 0);
      if (firstTime)
        {
          var pt = rollDirectorXY(game);
          group.directorX = pt.x;
          group.directorY = pt.y;
        }
      var room = info.getRoomAt(group.directorX, group.directorY);

      // the director
      var ai = game.area.spawnAI('agent', group.directorX, group.directorY);
      ai.job = 'regional controller';
      ai.isGuard = true;
      ai.guardTargetX = ai.x;
      ai.guardTargetY = ai.y;
      group.directorID = ai.id;

      // the first guard is the door sentry with the keycard, the rest guard the director inside
      var door = roomDoor(info, room);
      for (i in 0...guardCount(group))
        {
          var pt = (i == 0 && door != null ? sentryXY(game, room, door) : null);
          if (pt == null)
            pt = insideXY(game, room, door, ai.x, ai.y);
          if (pt == null)
            continue;
          var guard = game.area.spawnAI('blackops', pt.x, pt.y);
          guard.isGuard = true;
          guard.guardTargetX = pt.x;
          guard.guardTargetY = pt.y;
          if (i == 0)
            {
              var item = guard.inventory.addID('keycard');
              item.lockID = LOCK_ID;
            }
        }

      // lock every door into the room (the objects keep the lock between visits)
      if (!firstTime)
        return;
      for (d in info.doors)
        if (d.roomID1 == room.id ||
            d.roomID2 == room.id)
          for (o in game.area.getObjectsAt(d.x, d.y))
            if (o.type == 'door')
              {
                var obj: objects.Door = cast o;
                obj.lock(LOCK_ID);
              }
    }

// each turn while the goal is active: raise the alarm lock-in once the base is alerted
  public static function onTurn(game: Game, player: Player)
    {
      var group = game.group;
      if (game.location != LOCATION_AREA ||
          game.area.id != group.directorAreaID)
        return;
      if (!group.directorAlert &&
          isAlerted(game))
        {
          group.directorAlert = true;
          game.message({
            text: 'The alarm is up. I cannot leave this base until the controller is dealt with.',
            img: 'event/security_alert'
          });
        }
      // freeze alertness
      if (group.directorAlert)
        game.area.alertness = 100;
    }

// leaving the base is blocked once the alarm is up
  public static function leaveAreaPre(game: Game, player: Player, area: AreaGame): Bool
    {
      if (area.id != game.group.directorAreaID ||
          !game.group.directorAlert)
        return true;
      game.actionFailed('You cannot leave this base until the controller is dealt with.');
      return false;
    }

// goal note: the base location
  public static function noteFunc(game: Game): String
    {
      var area = game.world.get(0).get(game.group.directorAreaID);
      return Const.col('gray', Const.small(
        'Target location: (' + area.x + ',' + area.y + ')'));
    }

// blackops guards around the director, by group difficulty
  static function guardCount(group: Group): Int
    {
      return switch (group.difficulty)
        {
          case EASY: 1;
          case HARD: 3;
          default: 2;
        };
    }

// is the base alerted: law called, or the director or a blackops guard alert
  static function isAlerted(game: Game): Bool
    {
      for (ev in game.managerArea.getList())
        if (ev.type == AREAEVENT_CALL_LAW ||
            ev.type == AREAEVENT_ALERT_LAW ||
            ev.type == AREAEVENT_ARRIVE_LAW)
          return true;
      var director = game.area.getAIByID(game.group.directorID);
      if (director != null &&
          director.state == AI_STATE_ALERT)
        return true;
      for (ai in game.area.getAIWithType('blackops'))
        if (ai.state == AI_STATE_ALERT)
          return true;
      return false;
    }

// pick the director's spot: the comms room, then the briefing room, then any room with a door
  static function rollDirectorXY(game: Game): { x: Int, y: Int }
    {
      var info = game.area.generatorInfo;
      for (role in [ FacilityTemp.ROLE_COMMS, FacilityTemp.ROLE_BRIEFING, null ])
        {
          var rooms = [];
          for (r in info.rooms)
            if ((role == null ||
                r.role == role) &&
                roomDoor(info, r) != null)
              rooms.push(r);
          while (rooms.length > 0)
            {
              var room = rooms[Std.random(rooms.length)];
              rooms.remove(room);
              var door = roomDoor(info, room);
              var pts = [];
              for (y in room.y1...room.y2 + 1)
                for (x in room.x1...room.x2 + 1)
                  if (isFree(game, x, y) &&
                      Const.distanceSquared(x, y, door.x, door.y) >= 4)
                    pts.push({ x: x, y: y });
              if (pts.length > 0)
                return pts[Std.random(pts.length)];
            }
        }
      throw 'no room for the group director';
    }

// first door into this room
  static function roomDoor(info: _GeneratorInfo, room: _Room): _Door
    {
      for (d in info.doors)
        if (d.roomID1 == room.id ||
            d.roomID2 == room.id)
          return d;
      return null;
    }

// sentry spot: a free cell next to the door, outside the room
  static function sentryXY(game: Game, room: _Room, door: _Door): { x: Int, y: Int }
    {
      for (dir in [ [1, 0], [-1, 0], [0, 1], [0, -1] ])
        {
          var x = door.x + dir[0];
          var y = door.y + dir[1];
          if (!inRoom(room, x, y) &&
              isFree(game, x, y))
            return { x: x, y: y };
        }
      return null;
    }

// inside guard spot: a free cell in the room near the director, clear of the doorway
  static function insideXY(game: Game, room: _Room, door: _Door, cx: Int, cy: Int): { x: Int, y: Int }
    {
      var pts = [];
      for (y in cy - 2...cy + 3)
        for (x in cx - 2...cx + 3)
          if (inRoom(room, x, y) &&
              isFree(game, x, y) &&
              (door == null ||
               Const.distanceSquared(x, y, door.x, door.y) > 2))
            pts.push({ x: x, y: y });
      if (pts.length == 0)
        return null;
      return pts[Std.random(pts.length)];
    }

// is this cell inside the room rect
  static inline function inRoom(room: _Room, x: Int, y: Int): Bool
    {
      return (x >= room.x1 &&
        x <= room.x2 &&
        y >= room.y1 &&
        y <= room.y2);
    }

// walkable, no AI and not the player
  static function isFree(game: Game, x: Int, y: Int): Bool
    {
      return (game.area.isWalkable(x, y) &&
        !game.area.hasAI(x, y) &&
        (game.playerArea.x != x ||
         game.playerArea.y != y));
    }
}
