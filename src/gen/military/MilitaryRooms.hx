// what a military building keeps in its rooms that a lab building does not
//
// the shared building pass (gen.facility.FacilityBuilding) lays the walls, the corridors and the
// rooms, and gen.facility.FacilityRooms deals the washroom, the store and the offices. A base's store
// is its ARMORY, and this is what makes it one: a run of steel lockers down a free wall, the gun
// cabinet among them, and the HQ's safe.

package gen.military;

import gen.facility._FacilityState;
import gen.facility.FacilityRooms;

class MilitaryRooms
{
  // how many lockers one armory takes at most, the gun cabinet and the safe not counted
  public static inline var LOCKERS_MAX = 5;

// stand the lockers, the gun cabinet and (in the first armory dealt, which is the HQ's) the safe on
// this store's free wall cells.
//
// they are OBJECTS on plain floor, like the corp security room's gun cabinet: each stands in its
// wall's margin and its cell stays walkable, so nothing here can seal the room. The cabinet stands in
// the middle of the longest free wall with the lockers either side, spilling onto the next walls, and
// the safe goes on the second wall. NEVER IN A CORNER, for the cabinet's own reason: the render turns
// each one by its wall, and a corner has two
  public static function armory(state: _FacilityState, room: _Room)
    {
      var area = state.area;
      var runs = [for (run in FacilityRooms.roomWallRuns(state, room))
        [for (c in run) if (!corner(room, c.x, c.y)) c]];
      runs.sort(function(a, b) return b.length - a.length);
      if (runs[0].length == 0)
        return;
      // the safe takes the second wall's first cell, or the first wall's last when there is no second
      if (area.countSpawns('safe') == 0)
        {
          var run = (runs[1].length > 0 ? runs[1] : runs[0]);
          var c = (run == runs[0] ? run.pop() : run.shift());
          area.add('safe', c.x, c.y);
        }
      // the cabinet in the middle of the longest run, lockers either side of it and on down the
      // other walls in turn
      var lockers = 0;
      for (i in 0...runs.length)
        {
          var mid = (i == 0 ? Std.int(Math.min(runs[0].length, LOCKERS_MAX + 1) / 2) : -1);
          for (k in 0...runs[i].length)
            {
              if (k == mid)
                area.add('gunCabinet', runs[i][k].x, runs[i][k].y);
              else if (lockers < LOCKERS_MAX)
                {
                  area.add('locker', runs[i][k].x, runs[i][k].y);
                  lockers++;
                }
            }
        }
    }

// is this cell one of the room's four corners?
  static inline function corner(room: _Room, x: Int, y: Int): Bool
    {
      return (x == room.x1 || x == room.x2) &&
        (y == room.y1 || y == room.y2);
    }
}
