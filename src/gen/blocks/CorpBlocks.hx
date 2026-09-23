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
import game.AreaGenerator.DIR_UP;
import game.AreaGenerator.DIR_DOWN;
import game.AreaGenerator.DIR_LEFT;

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
  // AND THE SIX THE FLOOR WAS MISSING. Each borrows a floor surface one of the seven above
  // already owns (gen.corp.CorpRooms' own header says which), so the whole of a new kind is a
  // demand, a dispatch case and a furniture list
  public static inline var ROOM_SOLO = 'room-solo';
  public static inline var ROOM_BREAK = 'room-break';
  public static inline var ROOM_COPY = 'room-copy';
  public static inline var ROOM_ARCHIVE = 'room-archive';
  public static inline var ROOM_RECEPTION = 'room-reception';
  public static inline var ROOM_SECURITY = 'room-security';
  // the widest a reception may be dealt, on either axis. a front desk and a couple of chairs is
  // what it is; the floor's big rooms belong to the open plan and the cubicle farm
  public static inline var RECEPTION_MAX = 6;

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
          case ROOM_SOLO: ROLE_SOLO;
          case ROOM_BREAK: ROLE_BREAK;
          case ROOM_COPY: ROLE_COPY;
          case ROOM_ARCHIVE: ROLE_ARCHIVE;
          case ROOM_RECEPTION: ROLE_RECEPTION;
          case ROOM_SECURITY: ROLE_SECURITY;
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
          case ROLE_SOLO: ROOM_SOLO;
          case ROLE_BREAK: ROOM_BREAK;
          case ROLE_COPY: ROOM_COPY;
          case ROLE_ARCHIVE: ROOM_ARCHIVE;
          case ROLE_RECEPTION: ROOM_RECEPTION;
          case ROLE_SECURITY: ROOM_SECURITY;
          default: ROOM_OPEN;
        }
    }

  // the rooms a WC or a server room must not be dealt to: something else's only route runs through
  // them. Filled by `assign` off the door graph and read by the two demands' own `must`, which
  // Quota.deal and gen.GenCheck.blocksFit both honour. A static because a _GenDemand carries no
  // state of its own and both readers are the same area's own pass — see
  // gen.corp.CorpBuilding.passThrough, which is where the fault it is for is written up
  public static var blocked: Map<Int, Bool> = new Map();

  // and WHERE THE LIFT IS, in cells, for the same reason and by the same route: `assign` fills it
  // before it deals and the reception demand's `fit` reads it. A _GenDemand carries no state, and
  // "the reception is by the lift" is a placement rule that cannot be said any other way — it is
  // not about the rect's shape, which is all `fit` can otherwise see
  public static var liftX = 0;
  public static var liftY = 0;

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
        // AND IT IS DECLARED FIRST, which is the third rule. `gen.Quota.deal` fills the
        // MINIMA most-constrained-first and then walks the maxima in DECLARATION ORDER,
        // and this demand's min is 0 — so wherever it sat in the list, every room with a
        // min had already chosen and the near-lift rects were gone. Measured with the
        // assert forced, over 3,000 seeds: 82 towers put their reception more than 36
        // cells from the car, worst 65
        // THE RECEPTION IS BY THE LIFT AND IT IS SMALL, which are two rules `fit: smallest` could
        // not state. It used to take whatever small rect was going, which put the floor's front
        // desk behind three other rooms as often as not; and "smallest" is a preference that
        // loses to the tie-break on area, so a 9 x 4 reception with an 8-cell desk in the middle
        // of it was the common case. `must` caps the rect, `fit` is the negative of the taxicab
        // distance from the rect's centre to the lift car, and the two together deal it the
        // nearest small room to the doors it is the reception FOR
        {
          kind: ROOM_RECEPTION,
          min: 0,
          max: 1,
          minW: 4,
          minH: 4,
          // SMALL IS A PREFERENCE, BY THE LIFT IS A RULE, and it took two measurements to get
          // that round the right way. The SIZE cap was a `must` first and it cost a third of the
          // towers their reception outright — 0.99 dealt per floor down to 0.66 — because `min`
          // is 0, so a floor whose free rects are all 7 wide simply does not get one. As a
          // penalty in `fit` it loses to any rect that is both nearer and within the cap, and
          // wins when there is nothing else.
          //
          // DISTANCE IS THE OTHER WAY ROUND: a reception 64 cells from the car is not a
          // reception, so that one is a `must` and a floor with nothing near the lift gets no
          // reception at all. Declaring first took the outliers from 82 towers in 3,000 to 6, and
          // those 6 have no small rect near the car at any price — a carve outcome, not a
          // ranking one
          must: function(b: _GenNode)
            return Std.int(Math.abs((b.x1 + b.x2) / 2 - liftX)) +
              Std.int(Math.abs((b.y1 + b.y2) / 2 - liftY)) <= GenCheck.RECEPTION_NEAR,
          fit: function(b: _GenNode)
            return -(Std.int(Math.abs((b.x1 + b.x2) / 2 - liftX)) +
              Std.int(Math.abs((b.y1 + b.y2) / 2 - liftY)) +
              2 * Std.int(Math.max(0, GenTree.width(b) - RECEPTION_MAX)) +
              2 * Std.int(Math.max(0, GenTree.height(b) - RECEPTION_MAX))),
        },
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
        // AND FROM HERE DOWN THE ORDER IS THE MIX, because Quota.deal's second pass spends what
        // the mins left over in DECLARATION ORDER, each demand to its max. The floor carves 29
        // rooms and the six kinds above only ever named ten of them, so 19 a floor came out as
        // the open-plan filler — a sparse duplicate of one template over half the tower.
        //
        // the six below are MIN 0 ON PURPOSE. Only 14.4 rooms a floor clear 5 on both axes and
        // 20.5 clear 4, and seven demands above already hold mins against that supply; another
        // six would be the "quota short: room-toilet got 0" this file's `assign` already carries
        // a retry loop for. A min is for the thing a floor MUST have, and a floor does not have
        // to have an archive on it. What puts one there is the max, and the supply is ample
        {
          kind: ROOM_SECURITY,
          min: 0,
          max: 1,
          minW: 4,
          minH: 4,
          fit: smallest,
        },
        // the recreation room the user asked for by name, and the only one of the six with a min.
        // 4 x 4 AND NOT 5 x 5: at 5 it was an eighth min against the 14.4 rooms a floor that clear
        // 5 on both axes, and two towers in 2,000 came out with nothing left to put it in. Below 5
        // the room loses its island of tables and is its wall fixtures alone — a vending machine,
        // a fridge and a cooler, which is what a small firm's break room is
        {
          kind: ROOM_BREAK,
          min: 1,
          max: 2,
          minW: 4,
          minH: 4,
        },
        {
          kind: ROOM_COPY,
          min: 0,
          max: 3,
          minW: 3,
          minH: 3,
          fit: smallest,
        },
        {
          // 5 AND NOT 4 ON EITHER AXIS, which is a number the oracle set. A rank spans the interior
          // x1+1 .. x2-1 with one DEALT gap in it, so at w 4 a rank is ONE cell and at w 5 it is
          // two; and the rows sit at RACK_PITCH 2 from y1+1 and stop at y2-1, so h 4 buys one rank
          // and h 5 buys two. At 4 on either axis the whole room is therefore one or two fittings
          // -- and gen.corp.CorpConnect.openPockets may legitimately erode every one of them to
          // un-seal the strip a full-width rank leaves against the wall, which shipped archives
          // holding NOTHING: 4 seeds in 600, every one of them 4 on an axis (gen.GenCheck
          // .archiveSane). At 5x5 a room has two ranks of two and the repair has something to
          // spend. The cost is that the filler takes the rooms this no longer fits, which is what
          // the filler is for
          kind: ROOM_ARCHIVE,
          min: 0,
          max: 2,
          minW: 5,
          minH: 5,
          fit: smallest,
        },
        // OPEN PLAN IS NOW A DEALT KIND WITH A CAP, not the leftover bucket. An open-plan floor is
        // a real corporate thing and three of them is one; 19 is what happens when a quota runs
        // out of names. It takes the ROOMIEST rooms left, which is where a bank of desks belongs
        {
          kind: ROOM_OPEN,
          min: 0,
          max: 3,
          minW: 5,
          minH: 5,
          fit: biggest,
        },
        // and the solo office takes EVERYTHING ELSE, which is what makes the filler branch
        // unreachable: it is declared last, its max is a number nothing reaches, and at 3 x 3 it
        // fits every rect the carve can produce (measured: 29.12 rooms a floor and 29.12 of them
        // are 3 x 3 or bigger). A small private office is also what a tower floor is mostly made
        // of, so the kind that soaks up the remainder is the right one to soak it
        {
          kind: ROOM_SOLO,
          min: 0,
          max: MANY,
          minW: 3,
          minH: 3,
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
      // and WHERE THE LIFT IS, for the reception demand's `fit`. The car is not on the grid yet —
      // ElevatorBlock fills after this — but `frontDir` is, and the car stands at the middle of
      // the plate's wall on that hand, which is all the demand needs
      liftX = Std.int((state.px1 + state.px2) / 2);
      liftY = Std.int((state.py1 + state.py2) / 2);
      switch (state.frontDir)
        {
          case DIR_UP: liftY = state.py1;
          case DIR_DOWN: liftY = state.py2;
          case DIR_LEFT: liftX = state.px1;
          default: liftX = state.px2;
        }

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
