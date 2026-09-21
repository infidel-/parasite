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

// and the inverse: which block BUILT a room, off the role it persists. public for console.GoBlock,
// so `go block room-cubicle` names a room the same way this file's own tree does
  public static function kindOf(room: _Room): String
    {
      return switch (room.role)
        {
          case ROLE_CUBICLE: ROOM_CUBICLE;
          case ROLE_MEETING: ROOM_MEETING;
          case ROLE_KITCHEN: ROOM_KITCHEN;
          case ROLE_EXEC: ROOM_EXEC;
          case ROLE_TOILET: ROOM_TOILET;
          case ROLE_SERVERS: ROOM_SERVERS;
          default: ROOM_OPEN;
        }
    }

  // the rooms a WC or a server room must not be dealt to: something else's only route runs through
  // them. Filled by `assign` off the door graph and read by the two demands' own `must`, which
  // Quota.deal and gen.GenCheck.blocksFit both honour. A static because a _GenDemand carries no
  // state of its own and both readers are the same area's own pass — see
  // gen.corp.CorpBuilding.passThrough, which is where the fault it is for is written up
  public static var blocked: Map<Int, Bool> = new Map();

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
          must: function(b) return !blocked.exists(b.roomID),
        },
        {
          kind: ROOM_SERVERS,
          min: 1,
          max: 1,
          minW: 5,
          minH: 5,
          fit: smallest,
          must: function(b) return !blocked.exists(b.roomID),
        },
        {
          kind: ROOM_KITCHEN,
          min: 1,
          max: 1,
          minW: 5,
          minH: 5,
          fit: smallest,
        },
        // the cubicle farm wants the ROOMIEST room on the floor, which is the one the old generator
        // would have made open plan. It is what the floor reads as from the lift, so one is
        // required and a second is allowed where the plate is big enough to carve two
        {
          kind: ROOM_CUBICLE,
          // 6 x 5, AND THE NUMBER HAS MOVED TWICE BECAUSE THE CARVE MOVED UNDER IT BOTH TIMES.
          // It was 9 x 7 when a floor carried 12 rooms averaging 110 cells; 8 x 6 when the cap
          // took that to 19 averaging 67; and with ROOM_SIZE 6 and SPLIT_MIN 5 a floor carries 28
          // and no room is guaranteed wider than 5. At 8 x 6 that was 124 towers in 400 with no
          // cubicle farm at all. A pod row is a 3-cell desk plus its aisle, and the template's own
          // guard is `w >= 4 && h >= 5`, so 6 x 5 is what the thing actually costs
          min: 1,
          max: 2,
          minW: 5,
          minH: 5,
          fit: biggest,
        },
        {
          kind: ROOM_MEETING,
          min: 1,
          max: 2,
          minW: 5,
          minH: 5,
        },
        {
          kind: ROOM_EXEC,
          min: 1,
          max: 3,
          minW: 4,
          minH: 4,
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
// how many rooms the two 5x5 demands could still legally take. `blocked` is what shrinks it, and a
// count under two means one of them has nowhere to go — see the loop in `assign`
  static function homes(nodes: Array<_GenNode>): Int
    {
      var n = 0;
      for (b in nodes)
        if (!blocked.exists(b.roomID) &&
            GenTree.width(b) >= 5 &&
            GenTree.height(b) >= 5)
          n++;
      return n;
    }

  public static function assign(state: _CorpState, plate: _GenNode): Array<_GenNode>
    {
      var nodes = [];
      for (room in state.rooms)
        {
          var n = GenTree.root('', room.x1, room.y1, room.x2, room.y2);
          n.roomID = room.id;
          nodes.push(n);
        }
      // WHAT IS BEHIND WHAT, before anything is dealt — see gen.corp.CorpBuilding.passThrough
      blocked = gen.corp.CorpBuilding.passThrough(state);

      // and DEAL UNTIL NOTHING IS WALLED IN BEHIND A TOILET. The pre-deal test names the rooms a
      // dead end cannot go in one at a time; two of them in parallel defeat it, and predicting
      // THAT rules out so much of the plate that a third of towers end up with nowhere to put a
      // server room (CorpBuilding.deadEnds carries the measurement). So the deal is checked and
      // re-made instead: 3 towers in 3000 take the second attempt and none has ever taken a third
      //
      // AND THE RULING-OUT IS NOT ALLOWED TO STARVE THE DEAL, which is what `relaxed` is for.
      // `deadEnds` is blunt on purpose — one stranded room blocks EVERY toilet and server room on
      // the floor — so over four attempts `blocked` only ever grows, and once the carve's own cap
      // came down from ROOM_SIZE * 1.5 to * 1.2 a floor carries 19 rooms instead of 12, the
      // chains off the corridor are longer, and the fourth attempt could find nothing legal left
      // at all: 11 towers in 3,000 reported "quota short: room-toilet got 0". A tower with its
      // washroom behind another room is a defect; a tower with NO washroom is a broken area, so
      // where the two cannot both be had the deal wins and the walk gives way
      // WHAT THE LAST ROUND FOUND IN THE WAY is applied at the TOP of the next one and never
      // after the deal that stands — gen.GenCheck.blocksFit re-reads `blocked` once the area is
      // built and asserts the deal honours it, so a ruling-out added after the final deal is a
      // self-inflicted failure ("room-servers dealt a block its own must rejects")
      var relaxed = false;
      var bad:Array<Int> = [];
      for (attempt in 0...8)
        {
          // ADD ONLY WHAT STILL LEAVES A BOARD TO DEAL ON. `deadEnds` names every WC and server
          // room on the floor, and unchecked rounds of that rule out every 5 x 5 room there is —
          // which is the "quota short: room-toilet got 0" this loop exists to avoid, not cause
          for (id in bad)
            {
              blocked.set(id, true);
              if (homes(nodes) < 2)
                {
                  blocked.remove(id);
                  break;
                }
            }
          if (!relaxed &&
              homes(nodes) < 2)
            {
              blocked = new Map();
              relaxed = true;
            }
          for (n in nodes)
            n.kind = '';
          Quota.deal(nodes, demands(), ROOM_OPEN, state.area.rng);
          for (i in 0...nodes.length)
            state.rooms[i].role = roleOf(nodes[i].kind);
          if (relaxed)
            break;
          bad = gen.corp.CorpBuilding.deadEnds(state);
          if (bad.length == 0)
            break;
        }
      for (n in nodes)
        plate.children.push(n);
      return nodes;
    }
}
