// what stands inside one room
//
// the ROOM level of the generation tree. A room node glazes its own exterior walls, then divides the
// strip of floor immediately inside them into sub-blocks — a `bench` where a run of worktop fits, a
// `slot` where one does not — and each of those is filled by its own small function. The `vent-cap`
// at the end of a glazed run is a third child kind, pushed last so the walk reaches it after the
// slots whose bare cells it reads.
//
// THIS WAS ONE 235-LINE LOOP (FacilityBuilding.makeWindows) doing the glazing, the worktops and the
// floor clutter off one set of running counters, which is why FacilityRooms.clearTableSpots has to
// take decorations back off afterwards: a slot could not know what a bench two cells later was going
// to want. Split into passes that each see a finished grid, every one of them asks plain questions of
// it instead — is this cell still bare, is it beside glazing, is there a doorway in the swing — and a
// new room kind is a kind string and a function rather than another branch in the counters.

package gen.blocks;

import Const;
import game.AreaGenerator;
import game.AreaGenerator.*;
import gen.GenTree;
import gen.Quota;
import gen.facility.FacilityBuilding;
import gen.facility.FacilityConnect;
import gen.facility.FacilityRooms;
import gen.facility.FacilityToilet;
import gen.facility._FacilityState;
import gen.facility.FacilityTemp.*;

class RoomBlock
{
  // the room kinds. one per template in FacilityRooms, named for the place and not for the role
  // string, because the role is what the finished area persists and this is what built it
  public static inline var LAB = 'room-lab';
  public static inline var OFFICE = 'room-office';
  public static inline var WASHROOM = 'room-washroom';
  public static inline var STORAGE = 'room-storage';
  // and what a room divides into. BAY is what the glazing pass pushes — an undealt bay of floor
  // under one bay of window — and gen.Quota then turns every one of them into one of the rest
  public static inline var BAY = 'bay';
  public static inline var BENCH = 'bench';
  public static inline var SLOT = 'slot';
  public static inline var VENT_CAP = 'vent-cap';
  // and the washroom's three, which are the same idea against its own walls: the strip you stand in
  // with the door at your back, the run of cubicles, and the basin counter
  public static inline var LOBBY = 'lobby';
  public static inline var STALL_RUN = 'stall-run';
  public static inline var BASIN_RUN = 'basin-run';
  // a desk with a workstation on it and room for the chair, a bank of machines, a row of server
  // racks. the last two are runs of ONE kind rather than the mixed wall furniture Deco.pick deals,
  // which is the whole difference: several of a thing in a row reads as a bay, one reads as clutter
  public static inline var WORKPLACE = 'workplace';
  public static inline var MACHINERY = 'machinery';
  public static inline var SERVER_RACK_BAY = 'server-rack-bay';
  // the one zone that is TWO CELLS DEEP: a two-seater against the masonry with a low table on the
  // cell in front of it. Everything else here is a run along a wall
  public static inline var LOUNGE = 'lounge';
  // and the store's three: a run of pallet racking, a bay of pallets standing on the floor, and the
  // strip kept bare. AISLE writes nothing and that IS the zone, exactly as LOBBY is in a washroom —
  // racking is 4.2 tall and blocks sight as well as movement, so the one thing a store needs stated
  // is where it does NOT stand
  public static inline var SHELF_RUN = 'shelf-run';
  public static inline var PALLET_BAY = 'pallet-bay';
  public static inline var AISLE = 'aisle';

  // marks a sub-block carries for its own filler and for gen.blocks.RoomZones' `must`: which tile
  // family its run is drawn from, whether the worktops under that run have drawers, whether it
  // stands in a doorway's swing, and whether it is the bay that ran off the end of the room
  static inline var TAG_H2 = 'h2';
  static inline var TAG_H3 = 'h3';
  static inline var TAG_V2 = 'v2';
  static inline var TAG_V3 = 'v3';
  static inline var TAG_DRAWER = 'drawer';
  public static inline var TAG_DOOR = 'door';
  public static inline var TAG_END = 'end';

  // a room narrower than this on the run's axis gets two-cell bays instead of three
  static inline var NARROW_ROOM = 7;

  // how many pallets one bay of a store may take, and how often one of them is a pallet of drums
  // rather than a wrapped stack. TWO and not the bay's length: a pallet is 1.5 tall and what stands
  // on a store's floor is a couple of them with room to walk past, where `standing`'s rack run is a
  // wall of racking that fills its bay bar one cell
  static inline var STORE_PALLET_MAX = 2;
  static inline var STORE_DRUM_PCT = 40;
  // how often a slot is dressed at all, how often it is dressed with something standing rather than
  // something on the floor, and how often a slot beside glazing is left bare on purpose
  static inline var SLOT_FILL_PCT = 70;
  static inline var SLOT_HIGH_PCT = 50;
  static inline var SLOT_GLAZED_BARE_PCT = 70;
  // how often a worktop cell carries glassware, and how often a run along the top wall is the family
  // with drawers under it
  static inline var BENCH_DECO_PCT = 70;
  static inline var BENCH_DRAWER_PCT = 50;
  // how often a lone window at the end of a run becomes a vent with no help from the floor inside it
  static inline var VENT_PCT = 30;

  // the ribbon, per bay size and run direction: three cells of glass horizontally, three vertically,
  // then the two-cell pair each of those falls back to in a narrow room
  static var WINDOW_TILES = [
    [ TEMP_BUILDING_WINDOWH1, TEMP_BUILDING_WINDOWH2, TEMP_BUILDING_WINDOWH3 ],
    [ TEMP_BUILDING_WINDOWV1, TEMP_BUILDING_WINDOWV2, TEMP_BUILDING_WINDOWV3 ],
    [ TEMP_BUILDING_WINDOWH1, TEMP_BUILDING_WINDOWH3 ],
    [ TEMP_BUILDING_WINDOWV1, TEMP_BUILDING_WINDOWV3 ],
  ];
  // the worktop runs that go under it, indexed the same way. the second family is the one with
  // drawers, which only reads from above and so only ever goes along the TOP wall
  static var TABLE_TILES = [
    [ Const.TILE_LABS_TABLE_3X1_1, Const.TILE_LABS_TABLE_3X1_2, Const.TILE_LABS_TABLE_3X1_3, ],
    [ Const.TILE_LABS_TABLE_1X3_1, Const.TILE_LABS_TABLE_1X3_2, Const.TILE_LABS_TABLE_1X3_3, ],
    [ Const.TILE_LABS_TABLE_3X1_1, Const.TILE_LABS_TABLE_3X1_3, ],
    [ Const.TILE_LABS_TABLE_1X3_1, Const.TILE_LABS_TABLE_1X3_3, ],
  ];
  static var TABLE_DRAWER_TILES = [
    [ Const.TILE_LABS_TABLE2_3X1_1, Const.TILE_LABS_TABLE2_3X1_2, Const.TILE_LABS_TABLE2_3X1_3, ],
    [ Const.TILE_LABS_TABLE2_1X3_1, Const.TILE_LABS_TABLE2_1X3_2, Const.TILE_LABS_TABLE2_1X3_3, ],
    [ Const.TILE_LABS_TABLE2_3X1_1, Const.TILE_LABS_TABLE2_3X1_3, ],
    [ Const.TILE_LABS_TABLE2_1X3_1, Const.TILE_LABS_TABLE2_1X3_3, ],
  ];

// make this room's node and hang it under the building it is in
  public static function node(state: _FacilityState, parent: _GenNode, room: _Room): _GenNode
    {
      var n = GenTree.add(parent, kindOf(room), room.x1, room.y1, room.x2, room.y2);
      n.roomID = room.id;
      return n;
    }

// which template this room was dealt, as a node kind
// which room kind BUILT this room, off the role it persists. public for console.GoBlock, so
// `go block room-washroom` names a room the same way this file's own tree does
  public static function kindOf(room: _Room): String
    {
      if (room.role == ROLE_TOILET)
        return WASHROOM;
      if (room.role == ROLE_CABINET)
        return OFFICE;
      if (room.role == ROLE_STORAGE)
        return STORAGE;
      return LAB;
    }

// build one node of the room level.
//
// the filler table for everything below a building, and the whole of it. Reached through the room's
// own gen.GenTree.build and not through the area walk — see FacilityBuilding.generateBuilding for
// why the ordering forbids deferring it
  public static function fill(state: _FacilityState, node: _GenNode)
    {
      var room = FacilityConnect.roomByID(state, node.roomID);
      switch (node.kind)
        {
          // a washroom takes NONE of what the other two do: not the ribbon glazing, not the worktop
          // runs, not the floor clutter. it gets light wells up one wall and is otherwise dressed
          // entirely by its own template in FacilityToilet
          case WASHROOM:
            clear(state, room);
            FacilityToilet.toiletWindows(state.area.getCells(), room);
            FacilityToilet.zones(state, room, node);

          case STALL_RUN:
            FacilityToilet.stallRun(state, node);

          case BASIN_RUN:
            FacilityToilet.basinRun(state, node);

          // the lobby writes nothing, and that IS the zone: it is the one strip of a washroom that
          // has to stay walkable, so naming it is how everything else knows to keep off
          case LOBBY:

          case LAB, OFFICE:
            clear(state, room);
            glaze(state, room, node, true);

          // A STORE DEALS LIKE THE OTHER TWO AND GLAZES LIKE THE WASHROOM, and that pairing is the
          // whole of what makes its racking possible. `solid` refuses a cell next to a ribbon window
          // — a 4.2-tall rack in front of the glass is a rack instead of a window — so a store
          // glazed like a laboratory has almost no wall to stand anything against: measured on the
          // first build, ONE pallet rack in a whole compound. Light wells are the washroom's own
          // answer to the same problem (their TEMP id is outside the range `nextToWindow` tests, so
          // the cell under one is solid), and a store with high windows is what a store has anyway
          case STORAGE:
            clear(state, room);
            FacilityToilet.toiletWindows(state.area.getCells(), room);
            glaze(state, room, node, false);

          case SHELF_RUN:
            standing(state, node, FIT_PALLET_RACK);

          case PALLET_BAY:
            pallets(state, node);

          // and the aisle writes nothing, the washroom lobby's own trick one room along: naming the
          // strip is how every other zone knows to keep off it
          case AISLE:

          case BENCH:
            bench(state, room, node);

          // the office's own name for the same run of worktop, and not a second filler: a bench tile
          // on an office floor ALREADY comes out as a desk with a monitor, a tower, a keyboard and a
          // chair pulled up to it — render.facility.FacilityTables draws the tile as a desk when the
          // surface is OFFICE, FacilityWork stands the workstation, FacilityWork.chairs seats it.
          // The name is what the office's core demand is called, and what a desk island would hang
          // off later; inventing a difference here would only move furniture that already reads right
          case WORKPLACE:
            bench(state, room, node);

          case SERVER_RACK_BAY:
            standing(state, node, FIT_RACK);

          case MACHINERY:
            standing(state, node, FIT_MACHINE);

          case LOUNGE:
            lounge(state, room, node);

          case SLOT:
            slot(state, room, node);

          case VENT_CAP:
            ventCap(state, room, node);

          default:
        }
    }

// blank the room back to plain floor before anything is laid in it
  static function clear(state: _FacilityState, room: _Room)
    {
      drawBlock(state.area.getCells(), room.x1, room.y1, room.w, room.h,
        TEMP_BUILDING_ROOM);
    }

// glaze all four walls of this room, divide the floor inside them into bays, and deal the room's
// quota over those bays.
//
// the deal is the whole point of the level. Every bay is pushed undealt, so the quota sees the room
// ENTIRE — which is what lets a demand say "one of these, somewhere in here" instead of each bay
// answering for itself. gen.Quota mutates `kind` in place and never reorders, so the children stay
// in wall order and the fills still claim contested corner cells in the order the walls were walked
  static function glaze(state: _FacilityState, room: _Room, node: _GenNode, glass: Bool)
    {
      var caps = [];
      var bays = [];
      for (spot in getRoomWallCorners(room))
        {
          var cap = glazeWall(state, room, node, spot, bays, glass);
          if (cap != null)
            caps.push(cap);
        }
      Quota.deal(bays, RoomZones.demands(state, room, node.kind), SLOT, state.area.rng);
      // the caps are pushed LAST so the breadth-first walk reaches them after every bench and slot
      // of this room: whether a lone window becomes a vent depends on the floor inside it still
      // being bare once the clutter has been dealt
      for (c in caps)
        {
          var n = GenTree.add(node, VENT_CAP, c.x, c.y, c.x, c.y);
          n.roomID = room.id;
        }
    }

// walk one wall of a room: paint the ribbon along it and push one sub-block per bay of floor inside
// it. returns the run's last cell when that cell came out a LONE window rather than a ribbon end,
// which is the only cell that may become a vent
  static function glazeWall(state: _FacilityState, room: _Room, node: _GenNode,
      spot: _Spot, bays: Array<_GenNode>, glass: Bool): _Spot
    {
      var area = state.area;
      var cells = area.getCells();
      // the ribbon stops at the first cell of the run that is not exterior masonry and never starts
      // again: a wall that turns into a corridor or a doorway partway along has no elevation left
      // `glass` false is the STORE: it takes the bay rhythm and none of the ribbon, so every wall
      // cell stays masonry and `solid` accepts it
      var noWindow = (!glass || cells[spot.x][spot.y] != TEMP_BUILDING_WALL);

      // only the run along the TOP wall may get the worktops with drawers under them — the other
      // three are seen from the side or from behind, where there is nothing of them to see
      var drawers = (spot.dir == DIR_RIGHT &&
        spot.dir90 == DIR_DOWN &&
        area.chance(BENCH_DRAWER_PCT));

      // the bay rhythm: three cells of glass, or two in a room too narrow to carry three
      var windowSize = 3;
      var windowTiles = null;
      var tag = null;
      if (spot.dir == DIR_RIGHT &&
          room.w < NARROW_ROOM)
        {
          windowSize = 2;
          windowTiles = WINDOW_TILES[2];
          tag = TAG_H2;
        }
      else if (spot.dir == DIR_RIGHT)
        {
          windowTiles = WINDOW_TILES[0];
          tag = TAG_H3;
        }
      else if (room.h < NARROW_ROOM)
        {
          windowSize = 2;
          windowTiles = WINDOW_TILES[3];
          tag = TAG_V2;
        }
      else
        {
          windowTiles = WINDOW_TILES[1];
          tag = TAG_V3;
        }

      var delta = deltaMap[spot.dir];
      var delta90 = deltaMap[spot.dir90];
      // the door-clearance box one bay of worktop needs: its length along the run and its one cell
      // across it
      var tw = (spot.dir == DIR_DOWN ? 1 : windowSize);
      var th = (spot.dir == DIR_RIGHT ? 1 : windowSize);
      var x = spot.x, y = spot.y;
      var len = 0;
      var noTable = false;
      // does THIS bay stand beside a doorway? taken on the TABLE line and not the window line,
      // because a doorway one row past the worktop is still one a bench stands in the swing of; and
      // re-taken at every bay boundary, so a run that passes a door in the middle tables again after
      var doorBlock = FacilityBuilding.isBlockNearDoor(cells,
        spot.x + delta.x + delta90.x, spot.y + delta.y + delta90.y, tw, th);
      var run = [];
      while (true)
        {
          x += delta.x;
          y += delta.y;
          var tx = x + delta90.x;
          var ty = y + delta90.y;
          if (cells[x][y] != TEMP_BUILDING_WALL)
            noWindow = true;
          if (len >= windowSize)
            {
              // the blank cell between two bays. close the bay that just ended, then re-test the
              // next one against the far wall and against the doorways.
              //
              // BOTH AXES TEST `>` AND THE VERTICAL ONE USED TO TEST `>=`, which cost a whole wall of
              // worktop in every room whose height divided evenly into the rhythm. `x`/`y` here is the
              // BLANK cell, so the next bay spans it + 1 .. it + windowSize and fits exactly when the
              // last of those is room.y2 — which `>=` called running off the end. Reported from the
              // game as labs coming back empty, and measured on the seed it was reported from: a 4 x 7
              // lab with three doors had its two 3-cell vertical bays marked TAG_END and both
              // horizontal bays taken by doorways, so gen.blocks.RoomZones' core demand could accept
              // nothing and every bay in the room fell through to the SLOT filler. 2 bench cells in 28
              // The latch is deliberate and stays: once a run has passed the far wall the rest of it
              // has too
              addBay(node, room, bays, run, tag, drawers, noTable, doorBlock);
              run = [];
              len = 0;
              if (spot.dir == DIR_DOWN &&
                  y > room.y2 - windowSize)
                noTable = true;
              else if (spot.dir == DIR_RIGHT &&
                  x > room.x2 - windowSize)
                noTable = true;
              doorBlock = FacilityBuilding.isBlockNearDoor(cells, tx, ty, tw, th);
              continue;
            }
          if (spot.dir == DIR_RIGHT &&
              x >= room.x2 + 1)
            break;
          else if (spot.dir == DIR_DOWN &&
              y >= room.y2 + 1)
            break;
          if (!noWindow)
            cells[x][y] = windowTiles[len];
          len++;
          // the cell the run along the horizontal wall already took. ITS TABLE LINE IS THE ROOM'S
          // FIRST AND LAST ROW, so a vertical run meets it at exactly one cell on each end — and
          // this used to read `cnt == 0`, which is a count of CLOSED BAYS and not of cells, so it
          // dropped the whole first bay of both vertical walls: 2 or 3 cells that belonged to no bay
          // node at all, never reached gen.Quota.deal, and stayed bare floor. Reported from the game
          // as an empty 2x2 in the corner of a lab and an empty corner in an office
          if (spot.dir == DIR_DOWN &&
              (ty == room.y1 || ty == room.y2))
            continue;
          run.push({ x: tx, y: ty });
        }
      addBay(node, room, bays, run, tag, drawers, noTable, doorBlock);

      // the run's last cell. a bay that ended one short is closed off rather than left showing a
      // mid-ribbon tile, and a bay that got only its FIRST cell is not a ribbon at all — it becomes
      // a single window, and that is the one this returns as a vent candidate
      x -= delta.x;
      y -= delta.y;
      if (cells[x][y] == TEMP_BUILDING_WINDOWH2)
        cells[x][y] = TEMP_BUILDING_WINDOWH3;
      else if (cells[x][y] == TEMP_BUILDING_WINDOWV2)
        cells[x][y] = TEMP_BUILDING_WINDOWV3;
      else if (cells[x][y] == TEMP_BUILDING_WINDOWH1 ||
          cells[x][y] == TEMP_BUILDING_WINDOWV1)
        {
          cells[x][y] = TEMP_BUILDING_WINDOW;
          return {
            x: x,
            y: y,
            dir: spot.dir,
            dir90: spot.dir90,
          };
        }
      return null;
    }

// close one bay and hand it to the dealer UNDEALT.
//
// the two flags the walk latched are written down as tags rather than spent on a kind here, because
// they are things only the walk knows: the door box is measured at the blank cell BEFORE the bay and
// at the full bay width even when the bay came out short, and "ran off the end" latches for the rest
// of the run. gen.blocks.RoomZones reads them back as a `must`
  static function addBay(node: _GenNode, room: _Room, bays: Array<_GenNode>,
      run: Array<{ x: Int, y: Int }>, tag: String, drawers: Bool, noTable: Bool, doorBlock: Bool)
    {
      if (run.length == 0)
        return;
      var last = run[run.length - 1];
      var n = GenTree.add(node, BAY, run[0].x, run[0].y, last.x, last.y);
      n.roomID = room.id;
      n.tags = [ tag ];
      if (drawers)
        n.tags.push(TAG_DRAWER);
      if (doorBlock)
        n.tags.push(TAG_DOOR);
      if (noTable)
        n.tags.push(TAG_END);
      bays.push(n);
    }

// does this node carry that mark?
  public static inline function tagged(node: _GenNode, tag: String): Bool
    {
      return (node.tags != null &&
        node.tags.indexOf(tag) >= 0);
    }

// stand a run of worktop along this bay and put glassware on most of it
  static function bench(state: _FacilityState, room: _Room, node: _GenNode)
    {
      var area = state.area;
      var cells = area.getCells();
      var tiles = benchTiles(node.tags);
      var n = 0;
      for (c in cellsOf(node))
        {
          // the run along the next wall reached this corner first
          if (cells[c.x][c.y] != TEMP_BUILDING_ROOM)
            continue;
          cells[c.x][c.y] = tiles[n];
          n++;
          // NOTE: a room corner ALWAYS carries something, so that a clue cannot spawn there — its
          // activation range is a cross and it would reach through the wall
          if (area.chance(BENCH_DECO_PCT) ||
              ((c.x == room.x1 || c.x == room.x2) &&
               (c.y == room.y1 || c.y == room.y2)))
            FacilityRooms.addDecoration(state, c.x, c.y, Const.CHEM_LABS_DECO_TABLE);
        }
    }

// stand a row of ONE kind of furniture along this bay — a bank of machines, a row of server racks.
//
// every cell goes unwalkable, which is what standing furniture is, and the cells it will not take are
// the same ones a high decoration is refused: a cell something already stands on, and a cell with
// glass behind it rather than masonry
  static function standing(state: _FacilityState, node: _GenNode, kind: _FittingKind)
    {
      // ONE CELL OF THE BAY IS ALWAYS LEFT, and it is not a stylistic gap. Everything else on a
      // room's perimeter leaves holes by construction — a bench bay skips the cell a neighbour
      // already took, a slot rolls 70% and often places nothing — so a room has always had a lane
      // round its own walls by accident. A run that fills EVERY cell it is dealt is the first thing
      // here that does not, and with two or three such runs a small room can end up ringed: measured
      // at 2 seeds in 4000, against 0 in 10000 before these zones existed, and
      // FacilityConnect.connectRooms cannot repair it because a cut needs a walkable cell on the
      // room side as well as the far one
      var room = FacilityConnect.roomByID(state, node.roomID);
      var left = solidRun(state, node) - 1;
      for (c in cellsOf(node))
        {
          if (left <= 0)
            return;
          if (!solid(state, room, c.x, c.y))
            continue;
          FacilityRooms.placeFitting(state, c.x, c.y, kind);
          left--;
        }
    }

// fill a bay with pallets on the floor: shrink-wrapped cartons, or a pallet of drums.
//
// NOT `standing`, and the difference is the LANE. A rack run is 4.2 tall and fills its bay to one
// cell short; a pallet is 1.5 and what a store actually has on the floor is a couple of them side by
// side with room to walk past, so this deals at most STORE_PALLET_MAX and rolls each cell
  static function pallets(state: _FacilityState, node: _GenNode)
    {
      var room = FacilityConnect.roomByID(state, node.roomID);
      var left = STORE_PALLET_MAX;
      for (c in cellsOf(node))
        {
          if (left <= 0)
            return;
          if (!solid(state, room, c.x, c.y))
            continue;
          // a pallet of drums or a wrapped stack. the drums are the same three liveries the
          // laboratory's own low list draws, standing on a pallet instead of on the floor
          FacilityRooms.placeFitting(state, c.x, c.y,
            state.area.chance(STORE_DRUM_PCT) ? FIT_DRUM_PALLET : FIT_PALLET_STACK);
          left--;
        }
    }

// how many cells of this bay could hold a piece of standing furniture. gen.blocks.RoomZones asks it
// as a `must`, and `standing` above fills exactly the cells it counted
  public static function solidRun(state: _FacilityState, node: _GenNode): Int
    {
      var room = FacilityConnect.roomByID(state, node.roomID);
      var n = 0;
      for (c in cellsOf(node))
        if (solid(state, room, c.x, c.y))
          n++;
      return n;
    }

// stand a two-seater against this bay's masonry with a low table BESIDE it.
//
// THE TABLE IS ON THE WALL LINE AND NOT IN FRONT OF THE SOFA, which is where it went for one build
// and is what the depth-2 idea cost. A low table on the cell into the room stands in the MIDDLE of an
// office — the one strip everything has to walk through and the one strip a room this size has to
// spare — and that is exactly how it read from the game. Beside it, the suite is a depth-1 run like
// every other zone here: two adjacent cells of the bay, sofa on the first and table on the second,
// with the floor in front of both left as a lane
  static function lounge(state: _FacilityState, room: _Room, node: _GenNode)
    {
      var cells = cellsOf(node);
      var d = inward(room, node);
      for (i in 0...cells.length - 1)
        {
          var a = cells[i], b = cells[i + 1];
          if (!loungeSpot(state, room, a.x, a.y, d) ||
              !loungeSpot(state, room, b.x, b.y, d))
            continue;
          FacilityRooms.placeFitting(state, a.x, a.y, FIT_SOFA);
          FacilityRooms.placeFitting(state, b.x, b.y, FIT_TABLE_LOW);
          // ONE suite per zone and then done: a wall of sofas is a waiting room, and this is an
          // office with a corner to sit in
          return;
        }
    }

// can one of the pair stand here? the cell takes everything standing furniture takes, and THERE HAS
// TO BE A LANE IN FRONT OF IT.
//
// the lane is the guard this zone could not do without, and it is the only one in the family: every
// other zone leaves holes in itself by construction — a bench bay skips the cell a neighbour took, a
// slot rolls 70% — where the suite fills both of its cells outright. Requiring two cells of clear
// room floor in front says "deep enough to walk past the furniture" without asking anything about the
// rest of the plan, and it is what keeps a 7x3 office reachable: measured before it existed, 2 seeds
// in 4000 came out with an office the flood could not reach, both of them 7x3
  static function loungeSpot(state: _FacilityState, room: _Room, x: Int, y: Int,
      d: { x: Int, y: Int }): Bool
    {
      var cells = state.area.getCells();
      var tx = x + d.x, ty = y + d.y;
      var lx = tx + d.x, ly = ty + d.y;
      return (solid(state, room, x, y) &&
        inRoom(room, tx, ty) &&
        inRoom(room, lx, ly) &&
        cells[tx][ty] == TEMP_BUILDING_ROOM &&
        cells[lx][ly] == TEMP_BUILDING_ROOM &&
        !nextTo(cells, tx, ty, TEMP_BUILDING_INNER_DOOR) &&
        !state.area.hasObjectAt(tx, ty));
    }

// is this cell inside the room's own rect?
  static inline function inRoom(room: _Room, x: Int, y: Int): Bool
    {
      return (x >= room.x1 &&
        x <= room.x2 &&
        y >= room.y1 &&
        y <= room.y2);
    }

// how many ADJACENT PAIRS in this bay could take the suite. pairs and not cells, because the sofa and
// the table now stand side by side: a bay with two usable cells at opposite ends houses no lounge
  public static function loungeRun(state: _FacilityState, room: _Room, node: _GenNode): Int
    {
      var n = 0;
      var d = inward(room, node);
      var cells = cellsOf(node);
      for (i in 0...cells.length - 1)
        if (loungeSpot(state, room, cells[i].x, cells[i].y, d) &&
            loungeSpot(state, room, cells[i + 1].x, cells[i + 1].y, d))
          n++;
      return n;
    }

// which way the room lies from this bay. a bay is the line one cell in from a wall, so the room is
// on the hand the bay's own edge is not
  static inline function inward(room: _Room, node: _GenNode): { x: Int, y: Int }
    {
      if (node.y1 == room.y1 && node.y2 == room.y1)
        return { x: 0, y: 1 };
      if (node.y1 == room.y2 && node.y2 == room.y2)
        return { x: 0, y: -1 };
      if (node.x1 == room.x1)
        return { x: 1, y: 0 };
      return { x: -1, y: 0 };
    }

// may a piece of standing furniture go here?
//
// THE DOORWAY TEST IS THE LOAD-BEARING ONE and leaving it out is what this cost. A run of racks
// fills EVERY cell it is dealt, where a slot rolls and often leaves one — so a bay ending beside an
// opening walled the room off, FacilityConnect.connectRooms cut an emergency door into it, and the
// compound came out with two extra doors and, once in 4000 seeds, a room the flood could not reach
// at all. The same three tests FacilityRooms.roomWallRuns has always made, plus the DOOR LANE — a
// doorway in a corner of its wall puts the strip you walk in on along the bay line of the NEXT wall,
// where orthogonal adjacency cannot see it (FacilityRooms.inDoorLane)
  static function solid(state: _FacilityState, room: _Room, x: Int, y: Int): Bool
    {
      var cells = state.area.getCells();
      return (cells[x][y] == TEMP_BUILDING_ROOM &&
        !nextToWindow(cells, x, y) &&
        !nextTo(cells, x, y, TEMP_BUILDING_INNER_DOOR) &&
        !state.area.hasObjectAt(x, y) &&
        !FacilityRooms.inDoorLane(room, FacilityConnect.getRoomDoors(state, room), x, y));
    }

// which worktop family this bay is drawn from
  static function benchTiles(tags: Array<String>): Array<Int>
    {
      var list = (tags.indexOf(TAG_DRAWER) >= 0 ? TABLE_DRAWER_TILES : TABLE_TILES);
      if (tags.indexOf(TAG_H3) >= 0)
        return list[0];
      if (tags.indexOf(TAG_V3) >= 0)
        return list[1];
      if (tags.indexOf(TAG_H2) >= 0)
        return list[2];
      return list[3];
    }

// dress a bay that got no worktop: a piece of standing furniture against plain masonry, something on
// the floor where the wall is glass, or nothing at all
  static function slot(state: _FacilityState, room: _Room, node: _GenNode)
    {
      var area = state.area;
      var cells = area.getCells();
      var door = tagged(node, TAG_DOOR);
      for (c in cellsOf(node))
        {
          if (cells[c.x][c.y] != TEMP_BUILDING_ROOM)
            continue;
          // the cell orthogonally next to an opening gets nothing at all, which is what keeps the
          // doorway itself walkable
          if (nextTo(cells, c.x, c.y, TEMP_BUILDING_INNER_DOOR) ||
              area.hasObjectAt(c.x, c.y))
            continue;
          if (!area.chance(SLOT_FILL_PCT))
            continue;
          var high = area.chance(SLOT_HIGH_PCT);
          var glazed = nextToWindow(cells, c.x, c.y);
          // a decoration beside glazing has to be a LOW one or it stands in the window, and so does
          // the one standing in for a bench beside a DOORWAY: a 2.8-tall fitting there reads as
          // blocking the opening, where a bin or a drum reads as something somebody left by the door
          if (glazed ||
              door)
            high = false;
          // and beside glazing it is often nothing at all. THAT GAP IS READ BACK OUT OF THE GRID by
          // ventCap below — a run whose end cell is left bare caps its ribbon with a vent
          if (glazed &&
              area.chance(SLOT_GLAZED_BARE_PCT))
            continue;
          // a HIGH decoration has plain masonry behind it, which is what a piece of standing
          // furniture needs, so it may come out as real 3D geometry instead of an upright sprite —
          // see Const.FACILITY_DECO and render.facility.FacilityDeco.
          //
          // an office takes STANDING furniture and nothing else: a crate of flasks or a waste drum
          // on the floor is the laboratory's clutter, and the low list is all laboratory
          // A WASHROOM'S LEFTOVER BAYS TAKE NOTHING. gen.facility.FacilityToilet deals its own zones
          // and everything that is neither the stall run nor the basin run falls through to this
          // filler, which asks gen.Deco with NO role — i.e. the laboratory's own block — so a
          // washroom came back with a bank of machines and a shelving unit in it. Its clutter is a
          // bin, a broom and a bucket, and all three are render-only passes
          if (room.role == ROLE_TOILET)
            continue;
          // A STORE'S LEFTOVER BAYS TAKE THE STORE'S OWN LIST and never the laboratory's, which is
          // the omission gen/area-gen's own notes say has bitten three times: without this arm a
          // bay no demand wanted comes back holding lab glassware and a bench lathe. gen.Deco deals
          // on the role, so the block name is the whole of the fix
          if (room.role == ROLE_STORAGE ||
              room.role == ROLE_CABINET)
            {
              if (high)
                FacilityRooms.addFitting(state, c.x, c.y, room.role);
            }
          else if (high &&
              area.chance(Const.FACILITY_FITTING_PCT))
            FacilityRooms.addFitting(state, c.x, c.y, Deco.BLOCK_LAB);
          // the other arm, and it consults NO table: these are raw row lists, and row 8 holds the
          // machine's own five frames at cols 4-8. Nothing filters them by role, so this line is
          // only correct because the two branches above have already taken the washroom and the
          // office out. gen.GenCheck.decoBlocks is what holds it — it reads the finished grid
          // rather than the dealer, so it catches a fitting that arrives down this arm exactly as
          // it catches one that was rolled
          else
            FacilityRooms.addDecoration(state, c.x, c.y, high ?
              Const.CHEM_LABS_DECO_FLOOR_HIGH :
              Const.CHEM_LABS_DECO_FLOOR_LOW);
          // change to unwalkable tile
          if (area.hasObjectAt(c.x, c.y))
            cells[c.x][c.y] = Const.TILE_FLOOR_TILE_UNWALKABLE;
        }
    }

// cap a glazed run that ended on a single window: a vent where the floor inside it was left bare,
// and otherwise a plain roll.
//
// the bare cell is the whole reason this node is walked after the slots. It used to be a flag the
// one big loop carried along the run; it is a question about the finished grid now, which is both
// shorter and truer — a duct comes down into a gap, whether that gap was left deliberately or
// because a worktop could not reach it
  static function ventCap(state: _FacilityState, room: _Room, node: _GenNode)
    {
      var area = state.area;
      var cells = area.getCells();
      var bare = false;
      for (i in 0...Const.dir4x.length)
        {
          var x = node.x1 + Const.dir4x[i];
          var y = node.y1 + Const.dir4y[i];
          if (x < room.x1 ||
              x > room.x2 ||
              y < room.y1 ||
              y > room.y2)
            continue;
          if (cells[x][y] == TEMP_BUILDING_ROOM)
            bare = true;
        }
      if (area.chance(VENT_PCT) ||
          bare)
        cells[node.x1][node.y1] = TEMP_BUILDING_VENT;
    }

// the cells of a sub-block, in run order. every one of them is a LINE — one bay of a wall run — so
// walking rows then columns gives the order the run was laid in whichever way it points
  public static function cellsOf(node: _GenNode): Array<{ x: Int, y: Int }>
    {
      var out = [];
      for (y in node.y1...node.y2 + 1)
        for (x in node.x1...node.x2 + 1)
          out.push({ x: x, y: y });
      return out;
    }

// is this cell next to a window?
  static function nextToWindow(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      for (i in 0...Const.dir4x.length)
        {
          var tile = FacilityBuilding.at(cells, x + Const.dir4x[i], y + Const.dir4y[i]);
          if (tile >= TEMP_BUILDING_WINDOW &&
              tile <= TEMP_BUILDING_WINDOWV3)
            return true;
        }
      return false;
    }
}
