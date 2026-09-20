// what a corp tower floor is made of
//
// the corp office's quota, and it deals ROOMS rather than plots. That is the one structural
// difference from gen.blocks.FacilityBlocks: a compound is open ground that gets CUT into plots by
// gen.Subdivide, while a tower floor is a single plate whose rooms are already carved by the
// corridor and the wall subdivision — so there is nothing to split, and what is left is exactly the
// half a quota is for.
//
// WHAT IT REPLACES is game.CorpAreaGenerator's dice ladder: `if small { kitchen 85% else meeting
// 85% else solo 85% else a flat 33/33/33 reroll } else work`. That is the fault gen._GenDemand's
// own header is written about — a roll standing in for "usually" — and it meant a floor could come
// out with three kitchens and no meeting room, or with no small room at all and therefore nothing
// but open plan. A quota says the thing that was meant.

package gen.blocks;

import gen.corp.CorpTemp.*;
import gen.corp._CorpState;

class CorpBlocks
{
  // the node kinds a tower floor deals in. strings and not an enum, because gen.GenTree is shared
  // with every other area type and a filler table keyed on one area's enum would not be
  public static inline var PLATE = 'plate';
  public static inline var ELEVATOR = 'elevator';
  public static inline var ROOM_OPEN = 'room-open';
  public static inline var ROOM_CUBICLE = 'room-cubicle';
  public static inline var ROOM_MEETING = 'room-meeting';
  public static inline var ROOM_KITCHEN = 'room-kitchen';
  public static inline var ROOM_EXEC = 'room-exec';
  public static inline var ROOM_TOILET = 'room-toilet';
  public static inline var ROOM_SERVERS = 'room-servers';

  // the zone kinds a room pushes under itself. they write no cells of their own — the template
  // that pushed one has already laid it — and exist so the tree is a record of WHERE the furniture
  // went, which is what `make gen args="--stats"` counts and what `go block` can later offer
  public static inline var ZONE_DESK_RUN = 'desk-run';
  public static inline var ZONE_POD_ROW = 'pod-row';
  public static inline var ZONE_RACK_ROW = 'rack-row';
  public static inline var ZONE_TABLE = 'table';
  public static inline var ZONE_COUNTER_RUN = 'counter-run';
  public static inline var ZONE_STALL_RUN = 'stall-run';
  public static inline var ZONE_BASIN_RUN = 'basin-run';

  // a max nothing is expected to reach, for the kind that takes whatever is left
  static inline var MANY = 99;

// the room role each dealt kind writes into _Room.role
  public static function roleOf(kind: String): String
    {
      return switch (kind)
        {
          case ROOM_CUBICLE: ROLE_CUBICLE;
          case ROOM_MEETING: ROLE_MEETING;
          case ROOM_KITCHEN: ROLE_KITCHEN;
          case ROOM_EXEC: ROLE_EXEC;
          case ROOM_TOILET: ROLE_TOILET;
          case ROOM_SERVERS: ROLE_SERVERS;
          default: ROLE_OPEN;
        }
    }

// what a tower floor must end up with.
//
// the minW/minH are what each template needs to produce the thing rather than a token of it: a
// cubicle farm below 9x7 fits one pod row and reads as a small office with a partition in it, and a
// boardroom below 6x6 has no room for a table once meetingTable's 2-cell inset is taken off.
//
// the two `min: 1`s that matter are the WASHROOM and the SERVER ROOM, and they are mins for the
// reason _GenDemand's header gives: a floor of a corporate tower has a toilet on it, and a roll is
// not a way to say that. Both take the SMALLEST rect that will hold them (`fit` is negative area),
// so neither can spend the plate's one big room — that room is what a cubicle farm is for
  public static function demands(): Array<_GenDemand>
    {
      var smallest = function(b: _GenNode)
        return -GenTree.width(b) * GenTree.height(b);
      var biggest = function(b: _GenNode)
        return GenTree.width(b) * GenTree.height(b);
      return [
        {
          kind: ROOM_TOILET,
          min: 1,
          max: 1,
          minW: 5,
          minH: 5,
          fit: smallest,
        },
        {
          kind: ROOM_SERVERS,
          min: 1,
          max: 1,
          minW: 5,
          minH: 5,
          fit: smallest,
        },
        {
          kind: ROOM_KITCHEN,
          min: 1,
          max: 1,
          minW: 6,
          minH: 6,
          fit: smallest,
        },
        // the cubicle farm wants the ROOMIEST room on the floor, which is the one the old generator
        // would have made open plan. It is what the floor reads as from the lift, so one is
        // required and a second is allowed where the plate is big enough to carve two
        {
          kind: ROOM_CUBICLE,
          min: 1,
          max: 2,
          minW: 9,
          minH: 7,
          fit: biggest,
        },
        {
          kind: ROOM_MEETING,
          min: 1,
          max: 2,
          minW: 6,
          minH: 6,
        },
        {
          kind: ROOM_EXEC,
          min: 1,
          max: 3,
          minW: 5,
          minH: 5,
          fit: smallest,
        },
      ];
    }

// deal a kind to every room the carve produced, write the role onto the _Room, and hang one node
// per room off the plate so the finished tree is a record of the whole floor.
//
// OPEN PLAN IS THE FILLER and has no demand of its own: it is what a room is when nothing else
// claimed it, which is the same relationship the compound's `yard` has to its plots. The
// consequence is worth stating — a floor carved into exactly the six rooms the mins want has NO
// open-plan space at all, and that is correct rather than a miss
  public static function assign(state: _CorpState, plate: _GenNode): Array<_GenNode>
    {
      var nodes = [];
      for (room in state.rooms)
        {
          var n = GenTree.root('', room.x1, room.y1, room.x2, room.y2);
          n.roomID = room.id;
          nodes.push(n);
        }
      Quota.deal(nodes, demands(), ROOM_OPEN, state.area.rng);
      for (i in 0...nodes.length)
        {
          state.rooms[i].role = roleOf(nodes[i].kind);
          plate.children.push(nodes[i]);
        }
      return nodes;
    }
}
