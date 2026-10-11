// what goes inside a finished room
//
// the room TEMPLATES — which role each room is dealt, and the furniture and floor each role gets —
// plus the shared placement helpers the washroom in FacilityToilet borrows. Everything here runs
// after FacilityBuilding has laid the walls, the doors and the bench runs, and writes FINAL tile ids
// rather than TEMP_* ones: FacilityGen.finalizeTiles only rewrites ids it has a row for and leaves
// these alone.

package gen.facility;

import Const;
import game.AreaGenerator;
import game.AreaGenerator.*;
import gen.Deco;
import gen.facility.FacilityTemp.*;

class FacilityRooms
{
  // how many wall fittings a researcher's office gets, placed outright rather than rolled: the
  // leftover-cell route in makeWindows only fires where a desk could not go, which on a small office
  // is often nowhere at all
  static inline var OFFICE_FITTING_MIN = 1;
  static inline var OFFICE_FITTING_MAX = 3;
  // how many of a room's bench cells clearTableSpots keeps bare, so a clue always has a legal spot.
  // THREE and not one: render.facility.FacilitySink takes a free edge cell of every bench block in
  // the room for its basin, and the clue's own activation range then wants the remaining two not to
  // be the same corner of the same run
  static inline var TABLE_CLEAR_MIN = 3;
  // the shortest wall run a store will take, in cells. RACKING IS THE ROOM: two bays of pallet rack
  // is 4 cells of unbroken masonry, and a room that cannot offer that is a room with shelves in it
  // and not a store. A candidate failing this is simply not made one — the washroom's own precedent,
  // where relaxing onto the fault was rejected
  static inline var STORE_RUN_MIN = 4;

// hand each room of this structure a template.
//
// the same shape game.CorpAreaGenerator uses for its four office themes: size, a quota and dice, with
// no persisted tag — the room's FLOOR TILE is what carries the theme out of here, and the 3D layer
// reads the theme back off that tile alone (render.facility.FacilityModel.surfOf)
  public static function assignRoomThemes(state: _FacilityState)
    {
      // a big room is a laboratory: the bench runs, the island and the aisle markings all want the
      // space, and a compound of nothing but small offices reads as an office block
      if (state.military)
        {
          militaryThemes(state);
          return;
        }
      var cells = state.area.getCells();
      var cand = [for (room in state.rooms)
        if (room.w <= ROOM_SIZE && room.h <= ROOM_SIZE) room];
      if (cand.length == 0)
        return;
      // THE WASHROOM IS PICKED FIRST AND PICKED FOR ITS WALL AND ITS DOOR. Its light wells need one
      // wall that is exterior masonry end to end, and a room in the middle of a building has none —
      // so a plain first-come roll put the compound's only washroom in an interior core about half
      // the time and it came out with no glazing at all. The lab and the office are indifferent to
      // this, so the toilet gets first refusal on a perimeter room and they take what is left.
      //
      // AND THE DOOR TEST IS THE OTHER HALF, reported as a washroom reached only through a
      // laboratory and carrying two doors into it. Nothing in FacilityConnect knows what a room is
      // FOR — roles are dealt here, two passes after the doors are cut, and the inner-wall pass
      // above has by then turned every corridor-facing room cell into the same tile as a lab-facing
      // one, so doorSpots rolls uniformly over a room's whole ring and a room's door COUNT is
      // accretion: one of its own plus one for every neighbour whose roll landed on the shared wall.
      // The ordering that makes the cut blind is what makes this cheap, though — by here the doors
      // are real objects and can simply be asked.
      //
      // AND THE TEST IS THE ROOM'S OWN DOORS AND NOT EVERY DOOR IN ITS WALLS, which is where "a lab
      // building always has a toilet" was actually won. Counting all of them rejected a room that had
      // exactly one corridor door of its own plus a NEIGHBOUR'S door landed in the wall they share —
      // the accretion above — and measured over 795 lab structures that is 21.8% of them with no
      // candidate at all against 1.6% once the neighbour's door is left out of it. A door this room
      // did not cut is not a way in to the washroom in any sense gen.facility.FacilityToilet cares
      // about; what that file needs is the one wall to lay its T against, and that is the room's own.
      // It asks the same question now, so the pick and the partition cannot disagree.
      //
      // NO CANDIDATE PASSES STILL MEANS NO WASHROOM in that 1.6%, rather than relaxing onto the
      // fault: the next tier down is a room whose only door opens into a LABORATORY, which is the
      // thing this test was added to stop
      var wash = -1;
      for (i in 0...cand.length)
        if (exteriorWall(cells, cand[i]) != null &&
            washroomDoor(state, cells, cand[i]))
          {
            wash = i;
            break;
          }
      // NO DICE. This was `chance(60) && wash >= 0`, so two lab buildings in five came out with no
      // washroom at all — and gen._GenDemand's own header names that very roll as the example of "a
      // roll was the easy way to express usually". A lab building HAS a toilet; the only thing that
      // can stop it now is no candidate passing, measured at 1.6% of structures
      if (wash >= 0)
        {
          cand[wash].role = ROLE_TOILET;
          FacilityConnect.sealWashroom(state, cand[wash]);
        }
      // and the store, dealt on the same shape and for the same reason the washroom is: it wants
      // something no other template needs — one wall run long enough to stand racking against — and
      // a room that has none is passed over rather than furnished badly. ONE PER BUILDING: a lab
      // building has a store the way it has a toilet, and two of them reads as a warehouse
      for (room in cand)
        if (room.role == null &&
            storeWall(state, room))
          {
            room.role = ROLE_STORAGE;
            break;
          }
      var cabinets = 0;
      for (i in 0...cand.length)
        {
          if (cand[i].role != null ||
              cabinets >= 2)
            continue;
          if (state.area.chance(85))
            {
              cabinets++;
              cand[i].role = ROLE_CABINET;
            }
        }
    }

// a military building's rooms, dealt on the same terms as a lab building's and from the same
// tests, but out of the base's own kinds. The FIRST building dealt is the HQ — its armory takes the
// base's one safe, so a building dealt with no safe yet standing is still the first — and every
// other one is a barracks block:
// - the latrine first, on the washroom's own two tests (an exterior wall, one door onto a corridor);
// - then the biggest room left is the HQ's briefing room or the block's mess hall;
// - the HQ takes its armory next, and every other room left is a barracks room in either. The HQ's
//   were offices, reported as "boring and almost the same as briefing"
  static function militaryThemes(state: _FacilityState)
    {
      FacilityConnect.sealRooms(state);
      var cells = state.area.getCells();
      var rooms = state.rooms.copy();
      rooms.sort(function(a, b) return a.w * a.h - b.w * b.h);
      for (room in rooms)
        if (room.w <= ROOM_SIZE &&
            room.h <= ROOM_SIZE &&
            exteriorWall(cells, room) != null &&
            washroomDoor(state, cells, room))
          {
            room.role = ROLE_LATRINE;
            FacilityConnect.sealWashroom(state, room);
            break;
          }
      var hq = (state.area.countSpawns('safe') == 0);
      var rest = [for (room in rooms) if (room.role == null) room];
      rest.reverse();
      if (rest.length > 1)
        rest.shift().role = (hq ? ROLE_BRIEFING : ROLE_MESS);
      if (hq &&
          rest.length > 0)
        rest.shift().role = ROLE_ARMORY;
      // then one of each of the building's own specialists, each only while a room of the plain kind
      // is left over for it: the HQ's comms room, the barracks building's medical bay and store
      for (role in (hq ? [ ROLE_COMMS ] : [ ROLE_MEDICAL, ROLE_SUPPLY ]))
        if (rest.length > 1)
          rest.shift().role = role;
      for (room in rest)
        room.role = ROLE_BARRACKS;
    }

// fill rooms with content. a military building's are furnished at the room level instead
// (gen.military.MilitaryZones.deal, then gen.military.MilitaryRooms.fill per zone)
  public static function generateRoomContents(state: _FacilityState)
    {
      if (state.military)
        return;
      for (room in state.rooms)
        {
          if (room.role == ROLE_CABINET)
            roomCabinet(state, room);
          else if (room.role == ROLE_TOILET)
            FacilityToilet.roomToilet(state, room);
          else if (room.role == ROLE_STORAGE)
            roomStorage(state, room);
          else roomChemistryLab(state, room);
        }
    }

// may this room be the washroom, as far as its DOORS are concerned: exactly one of them, and onto a
// corridor.
//
// gen.facility.FacilityToilet has assumed both since it was written — toiletPartition takes the
// FIRST door of the room and lays the T's bar, lobby and stem against that wall, so a second door on
// another wall opens into a sealed half or straight past the partition. This is what makes the
// assumption true rather than lucky.
//
// A DOOR'S `dir` POINTS OUT OF THE ROOM THAT CUT IT, which is why the roomID1 test is not
// redundant: a neighbour's door into our shared wall is in this room's door list too, and its delta
// names US. Such a door can never be onto a corridor, so it fails here and the room is passed over
  static function washroomDoor(state: _FacilityState, cells: Array<Array<Int>>, room: _Room): Bool
    {
      var mine = [for (d in FacilityConnect.getRoomDoors(state, room)) if (d.roomID1 == room.id) d];
      if (mine.length != 1)
        return false;
      var delta = deltaMap[mine[0].dir];
      return (cells[mine[0].x + delta.x][mine[0].y + delta.y] == TEMP_BUILDING_CORRIDOR);
    }

// the first wall of this room that is EXTERIOR masonry for its whole length, or null for a room in
// the middle of a building. an inner wall faces another room or a corridor and has nothing to be a
// light well onto, so this is both what FacilityToilet.toiletWindows paints and what
// assignRoomThemes prefers a washroom to have — asked before the roles are dealt, which is why it is
// its own function
  public static function exteriorWall(cells: Array<Array<Int>>, room: _Room): _Spot
    {
      for (spot in getRoomWallCorners(room))
        {
          var delta = deltaMap[spot.dir];
          var len = (spot.dir == DIR_RIGHT ? room.w : room.h);
          var solid = true;
          for (i in 0...len)
            if (cells[spot.x + delta.x * (i + 1)][spot.y + delta.y * (i + 1)] != TEMP_BUILDING_WALL)
              solid = false;
          if (solid)
            return spot;
        }
      return null;
    }

// make this room a researcher's office: the desks are already standing (makeWindows lays them as
// bench runs, which is the same furniture one texture family apart), so all this owes is the floor.
//
// the tiles are written FINAL and not TEMP, exactly as roomChemistryLab writes its drain and its
// unwalkable cells — finalizeTiles only rewrites ids it has a row for and leaves these alone
  static function roomCabinet(state: _FacilityState, room: _Room)
    {
      // the bookcases, document cabinets and server racks, placed OUTRIGHT on the free wall cells the
      // washroom's own machinery finds. they used to arrive only through makeWindows' leftover-cell
      // roll, which fires where a desk could not go and on a small office is often nowhere
      var edges = roomWallRuns(state, room);
      edges.sort(function(a, b) return b.length - a.length);
      var want = OFFICE_FITTING_MIN +
        state.area.random(OFFICE_FITTING_MAX - OFFICE_FITTING_MIN + 1);
      // one per wall before a second goes on any wall, so a small office does not get its whole set
      // stacked down one side
      for (i in 0...want)
        {
          var run = edges[i % edges.length];
          var k = Std.int(i / edges.length);
          if (k >= run.length)
            continue;
          addFitting(state, run[k].x, run[k].y, ROLE_CABINET);
          if (state.area.hasObjectAt(run[k].x, run[k].y))
            state.area.getCells()[run[k].x][run[k].y] = Const.TILE_FLOOR_TILE_UNWALKABLE;
        }
      paintRoomFloor(state, room, Const.TILE_FLOOR_WOOD1);
    }

// has this room a wall long enough to stand racking against?
//
// IT CANNOT ASK roomWallRuns, which is the trap here and cost a build: that function tests the floor
// cell against TEMP_BUILDING_ROOM, and at THEME TIME a room's floor still carries its own id mark
// (TEMP_BUILDING_ROOM_ID_START + id, measured at 102 and 112 on the first two rooms of seed 1) —
// so it returns four empty runs for every room in the compound and every seed came out storeless.
// roomCabinet gets away with it because it runs two passes later, after RoomBlock.clear.
//
// what it asks instead is the WALL and not the floor: a CONSECUTIVE run of cells backed by masonry
// and clear of an inner doorway, which is the shape racking actually needs and is a stronger test
// than the one it replaces — roomWallRuns counts cells and never asks whether they adjoin
  static function storeWall(state: _FacilityState, room: _Room): Bool
    {
      var cells = state.area.getCells();
      var walls = [
        { x: room.x1, y: room.y1, dx: 1, dy: 0, len: room.w, nx: 0, ny: -1 }, // top
        { x: room.x1, y: room.y2, dx: 1, dy: 0, len: room.w, nx: 0, ny: 1 },  // bottom
        { x: room.x1, y: room.y1, dx: 0, dy: 1, len: room.h, nx: -1, ny: 0 }, // left
        { x: room.x2, y: room.y1, dx: 0, dy: 1, len: room.h, nx: 1, ny: 0 },  // right
      ];
      for (w in walls)
        {
          var run = 0;
          for (i in 0...w.len)
            {
              var x = w.x + w.dx * i;
              var y = w.y + w.dy * i;
              var back = cells[x + w.nx][y + w.ny];
              if ((back != TEMP_BUILDING_WALL &&
                   back != TEMP_BUILDING_INNER_WALL) ||
                  nextTo(cells, x, y, TEMP_BUILDING_INNER_DOOR))
                {
                  run = 0;
                  continue;
                }
              run++;
              if (run >= STORE_RUN_MIN)
                return true;
            }
        }
      return false;
    }

// make this room a store: bare concrete under the racking, and nothing else the template has to do.
//
// EVERYTHING IN IT COMES FROM THE ZONES, which is the difference between this and roomCabinet next
// door. The office places its fittings outright because its own quota (desks) fills the room and
// leaves no bay for them; a store's quota IS its furniture — gen.blocks.RoomZones deals a core run
// of racking, a rolled bay of pallets and one bare aisle — so the template's whole job is the floor
  static function roomStorage(state: _FacilityState, room: _Room)
    {
      paintRoomFloor(state, room, Const.TILE_FLOOR_CONCRETE,
        Const.TILE_FLOOR_CONCRETE_UNWALKABLE);
    }

// make this room a chem lab
  static function roomChemistryLab(state: _FacilityState, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      var roomDoors = FacilityConnect.getRoomDoors(state, room);

      // put a drain
      var cx = room.x1 + 1 + area.random(room.w - 2),
        cy = room.y1 + 1 + area.random(room.h - 2);
      cells[cx][cy] = Const.TILE_FLOOR_TILE + 1 + area.random(3);
      if (area.chance(30))
        {
          area.add('floorDrain', cx, cy);
        }

      // make a big table near the center
      if (room.w < 7 || room.h < 7)
        return;

      var block = area.chance(50) ? Const.LABS_TABLE_3X2 :
        Const.LABS_TABLE_2X3;
      var tableW = block[0].length, tableH = block.length;
      var sx = -1, sy = -1;
      var xOffsets = [ 2, 3 ];
      var yOffsets = [ 2, 3 ];
      if (area.chance(50))
        xOffsets = [ 3, 2 ];
      if (area.chance(50))
        yOffsets = [ 3, 2 ];
      var foundSpot = false;
      for (xOffset in xOffsets)
        {
          var candidateX = room.x1 + xOffset;
          if (candidateX + tableW >= room.x2 - 2)
            candidateX = room.x1 + 2;
          for (yOffset in yOffsets)
            {
              var candidateY = room.y1 + yOffset;
              if (candidateY + tableH >= room.y2 - 2)
                candidateY = room.y1 + 2;
              if (!isBigTableSpotValid(state, room, roomDoors,
                  candidateX, candidateY, tableW, tableH))
                continue;
              sx = candidateX;
              sy = candidateY;
              foundSpot = true;
              break;
            }
          if (foundSpot)
            break;
        }
      if (!foundSpot)
        return;
      for (i in 0...tableH)
        for (j in 0...tableW)
          {
            cells[sx + j][sy + i] = block[i][j];
            if (area.chance(70))
              addDecoration(state, sx + j, sy + i,
                Const.CHEM_LABS_DECO_TABLE);
          }
    }

// check if a big table spot is clear floor and out of every door's lane
  static function isBigTableSpotValid(state: _FacilityState, room: _Room,
      doors: Array<_Door>, x: Int, y: Int, w: Int, h: Int): Bool
    {
      var cells = state.area.getCells();
      for (i in 0...h)
        for (j in 0...w)
          if (cells[x + j][y + i] != TEMP_BUILDING_ROOM ||
              inDoorLane(room, doors, x + j, y + i))
            return false;
      return true;
    }

// is this cell in the LANE a doorway opens onto: the strip straight in from an opening, one cell wide
// and as deep as the middle of the room.
//
// A DOORWAY IS NOT ONLY ITS OWN CELL, and every wall-hugging pass in this tree behaved as though it
// were — the one test they all make is `nextTo(..., TEMP_BUILDING_INNER_DOOR)`, which reaches exactly
// one cell. That is enough for a run one cell deep and it is not enough for anything standing further
// in: the lounge's low table stood in the middle of an office in the line of its own door. The rule
// was already here, hand-written inside isBigTableSpotValid as a march of BIG_TABLE_DOOR_CLEARANCE
// cells; this is that rule with a name, asked of a cell instead of a rect so every zone can ask it.
//
// THE DEPTH IS THE ROOM'S OWN HALF-SPAN, which is what "clear to the middle" means, and it is never
// deeper than the fixed 3 it replaces: a themed room is at most ROOM_SIZE on a side. Past the middle
// you are in the room, and walking round the furniture is what a room is for
  public static function inDoorLane(room: _Room, doors: Array<_Door>, x: Int, y: Int): Bool
    {
      for (door in doors)
        {
          if (door.x == room.x1 - 1)
            {
              if (y == door.y &&
                  x - room.x1 < Std.int(room.w / 2))
                return true;
            }
          else if (door.x == room.x2 + 1)
            {
              if (y == door.y &&
                  room.x2 - x < Std.int(room.w / 2))
                return true;
            }
          else if (door.y == room.y1 - 1)
            {
              if (x == door.x &&
                  y - room.y1 < Std.int(room.h / 2))
                return true;
            }
          else if (door.y == room.y2 + 1)
            {
              if (x == door.x &&
                  room.y2 - y < Std.int(room.h / 2))
                return true;
            }
        }
      return false;
    }

// repaint a themed room's floor, walkable cells in `tile` and the cells furniture stands on in
// `unwalk`. the bench tiles are left alone: a desk is a prop standing ON the floor, and the renderer
// takes a table cell's surface off the ROOM it sits in.
//
// `unwalk` DEFAULTS TO THE TWIN ONE TILESET ROW BELOW and the store is why it is an argument at all.
// The +16 rule holds for the themed floors of row 12, and CONCRETE is not one of them: it lives in
// the chem-lab block at OFFSET_CHEM_LAB + 6, so +16 lands on 134 — OFFSET_ROW8 + 6, i.e. a LAB
// WORKTOP. Measured before this argument existed: 5 seeds in 3000 came back with a store whose
// racking cells were worktop tiles, reported by gen.GenCheck.tablesSane as a corner-touching pair
// and by storageSane as floor nothing could walk to, both from the one cause. Concrete's real
// unwalkable twin is Const.TILE_FLOOR_CONCRETE_UNWALKABLE, nine along rather than sixteen
  public static function paintRoomFloor(state: _FacilityState, room: _Room, tile: Int,
      unwalk: Int = -1)
    {
      var cells = state.area.getCells();
      if (unwalk < 0)
        unwalk = tile + UNWALKABLE_TILE_OFFSET;
      for (y in room.y1...room.y2 + 1)
        for (x in room.x1...room.x2 + 1)
          {
            if (cells[x][y] == TEMP_BUILDING_ROOM)
              cells[x][y] = tile;
            else if (cells[x][y] == Const.TILE_FLOOR_TILE_UNWALKABLE)
              cells[x][y] = unwalk;
          }
    }

// the cells of each wall of this room a piece of standing furniture may take: on the room's edge,
// backed by SOLID masonry (a high fitting against glazing is dropped by the renderer), clear of every
// doorway and of whatever is standing there already. one array per wall, longest run wins
  public static function roomWallRuns(state: _FacilityState,
      room: _Room): Array<Array<{ x: Int, y: Int }>>
    {
      var area = state.area;
      var cells = area.getCells();
      var out = [];
      var walls = [
        { x: room.x1, y: room.y1, dx: 1, dy: 0, len: room.w, nx: 0, ny: -1 }, // top
        { x: room.x1, y: room.y2, dx: 1, dy: 0, len: room.w, nx: 0, ny: 1 },  // bottom
        { x: room.x1, y: room.y1, dx: 0, dy: 1, len: room.h, nx: -1, ny: 0 }, // left
        { x: room.x2, y: room.y1, dx: 0, dy: 1, len: room.h, nx: 1, ny: 0 },  // right
      ];
      for (w in walls)
        {
          var run = [];
          for (i in 0...w.len)
            {
              var x = w.x + w.dx * i, y = w.y + w.dy * i;
              var back = cells[x + w.nx][y + w.ny];
              if (cells[x][y] != TEMP_BUILDING_ROOM ||
                  (back != TEMP_BUILDING_WALL && back != TEMP_BUILDING_INNER_WALL) ||
                  nextTo(cells, x, y, TEMP_BUILDING_INNER_DOOR) ||
                  area.hasObjectAt(x, y))
                continue;
              run.push({ x: x, y: y });
            }
          out.push(run);
        }
      return out;
    }

// make sure every cell of this room's floor can be walked to from its own doorway, by taking
// fittings back off until it can.
//
// THE STORE IS THE FIRST ROOM THAT NEEDS THIS and the reason is its own furniture: racking stands on
// every wall a store has, and two perpendicular runs that each fill to their end seal the corner cell
// between them. Measured before this pass, over 3000 seeds: 5 stores with a corner nothing could
// walk to, and a rule that simply kept the corners clear made it 144 — because a bare corner with a
// rack on each of its two neighbours is the same pocket, drawn the other way round.
//
// So it is stated as the thing it actually is — a REACHABILITY repair, the same shape
// game.FacilityAreaGenerator.connectRooms applies to rooms and fixDiagonalTables to worktops: flood
// what the door can reach, and drop the one fitting standing between the flood and what it could not.
//
// it runs BEFORE the floor is painted, so the room's bare cells are still TEMP_BUILDING_ROOM and its
// furniture cells are the unwalkable tile placeFitting stamps — which is the only walkability test
// that means anything this early
  public static function openPockets(state: _FacilityState, room: _Room)
    {
      var cells = state.area.getCells();
      var doors = FacilityConnect.getRoomDoors(state, room);
      // dropping one fitting can expose the next pocket behind it, so this repeats until a whole
      // pass finds nothing. Every pass either returns or frees a cell, and there are finitely many
      while (true)
        {
          var seen = new Map<Int, Bool>();
          var stack = [];
          for (d in doors)
            for (i in 0...Const.dir4x.length)
              reach(cells, room, seen, stack, d.x + Const.dir4x[i], d.y + Const.dir4y[i]);
          // a room whose only way in is a neighbour's door has no seed here and is gen.GenCheck
          // .reachable's business, not this pass's: freeing every fitting in it would not open it
          if (stack.length == 0)
            {
              // a room whose only way in is a NEIGHBOUR'S door has no seed here and is
              // gen.GenCheck.reachable's business, not this pass's: freeing every fitting in it
              // would not open it
              if (doors.length == 0)
                return;
              // but a door with a fitting in its own lane leaves the flood nowhere to start, and
              // every cell in the room then reads as a pocket. open the doorway and try again
              var doorway = false;
              for (d in doors)
                if (freeOne(state, room, d.x, d.y))
                  {
                    doorway = true;
                    break;
                  }
              if (!doorway)
                return;
              continue;
            }
          while (stack.length > 0)
            {
              var p = stack.pop();
              for (i in 0...Const.dir4x.length)
                reach(cells, room, seen, stack, p.x + Const.dir4x[i], p.y + Const.dir4y[i]);
            }
          // THE CELL FREED IS THE FIRST POCKET CELL WITH A FITTING BESIDE IT, and not simply the
          // first pocket cell. That is the whole of the repair and the first version got it wrong:
          // it took the pocket in scan order and gave up when that one cell had no fitting on any
          // hand, which is every pocket bigger than one cell. Measured on seed 2235 as a 3x2 corner
          // of a 3x7 store whose top-left cell has two bare floor neighbours — reported by
          // storageSane as six cells nothing could walk to
          var opened = false;
          for (y in room.y1...room.y2 + 1)
            {
              for (x in room.x1...room.x2 + 1)
                if (cells[x][y] == TEMP_BUILDING_ROOM &&
                    !seen.exists(y * cells.length + x) &&
                    freeOne(state, room, x, y))
                  {
                    opened = true;
                    break;
                  }
              if (opened)
                break;
            }
          if (!opened)
            return;
        }
    }

// one cell of the flood openPockets runs inside a room: bare floor only, and inside the rect
  static function reach(cells: Array<Array<Int>>, room: _Room, seen: Map<Int, Bool>,
      stack: Array<{ x: Int, y: Int }>, x: Int, y: Int)
    {
      if (x < room.x1 ||
          x > room.x2 ||
          y < room.y1 ||
          y > room.y2 ||
          cells[x][y] != TEMP_BUILDING_ROOM ||
          seen.exists(y * cells.length + x))
        return;
      seen.set(y * cells.length + x, true);
      stack.push({ x: x, y: y });
    }

// take the fitting standing next to this pocket back off, and report whether there was one
  static function freeOne(state: _FacilityState, room: _Room, x: Int, y: Int): Bool
    {
      var cells = state.area.getCells();
      for (i in 0...Const.dir4x.length)
        {
          var nx = x + Const.dir4x[i];
          var ny = y + Const.dir4y[i];
          if (nx < room.x1 ||
              nx > room.x2 ||
              ny < room.y1 ||
              ny > room.y2 ||
              !state.area.hasObjectAt(nx, ny))
            continue;
          for (s in state.area.getObjectsAt(nx, ny))
            state.area.removeObject(s);
          cells[nx][ny] = TEMP_BUILDING_ROOM;
          return true;
        }
      return false;
    }

// leave at least TABLE_CLEAR_MIN of this room's bench cells bare, by taking decorations back off.
//
// A CLUE SPOT IS A BENCH TILE WITH NO OBJECT ON IT (game.AreaGame.initSpawnPoints) and this pass is
// the only thing that can promise one exists. makeWindows decorates about 70% of bench cells and
// FORCES one on all four room corners, and two render-only families then cover more of what is left —
// render.facility.FacilitySink takes a free edge cell of every bench block for its basin and
// render.facility.FacilityWork stands a workstation on the office desks (render.facility
// .FacilityClues prunes both out of the list). On a small room the three together reached zero, and a
// facility with no legal spot simply stops handing out clues.
//
// THE CORNERS ARE NEVER FREED and that is the one hard rule here: the walk forces a decoration onto
// them precisely so a clue cannot spawn there, because the activation range cross would reach through
// the wall. So the reserve is taken out of the middle of a run, where a bare metre of worktop is what
// a bench looks like anyway
  public static function clearTableSpots(state: _FacilityState, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      var free = 0;
      var taken = [];
      for (y in room.y1...room.y2 + 1)
        for (x in room.x1...room.x2 + 1)
          {
            if (!Const.isTableTile(cells[x][y]))
              continue;
            if (!area.hasObjectAt(x, y))
              {
                free++;
                continue;
              }
            // a corner cell is spoken for, and so is anything that is not a plain decoration — a
            // fitting or a generated object on a bench cell is somebody else's placement
            if ((x == room.x1 || x == room.x2) &&
                (y == room.y1 || y == room.y2))
              continue;
            for (o in area.getObjectsAt(x, y))
              if (o.type == 'decoration')
                taken.push(o);
          }
      var i = 0;
      while (free < TABLE_CLEAR_MIN &&
             i < taken.length)
        {
          area.removeObject(taken[i]);
          free++;
          i++;
        }
    }

// is this cell a worktop? the tile range clearTableSpots reads, and the one
// render.facility.FacilityModel.tableOf derives m.table from
  static inline function isTableCell(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      return Const.isTableTile(cells[x][y]);
    }

// close every pair of worktops that touches only at a CORNER — into an L where the room allows one,
// and by dropping one of the two where it does not.
//
// reported as two tables intersecting diagonally in a small room, and they really do intersect.
// render.facility.FacilityTables grows every worktop by BENCH_LIP 0.2 on each side that has no table
// ORTHOGONALLY next to it — every test in that file is one of the four axis steps, there is no
// diagonal probe anywhere — so two cells meeting at a corner each grow INTO the other: the caps
// overlap in a lip-squared square, the edge bands cross, and both cells emit their full casework
// right up to the shared point.
//
// IT IS THE BAY RHYTHM FALLING OUT OF PHASE WITH THE ROOM, not a placement bug. In a room narrower
// than NARROW_ROOM the runs take two-cell bays, and on a 3x3 the top run's bay ends one cell short of
// the corner while the right run's first row is the one gen.blocks.RoomBlock.glazeWall skips — which
// leaves a table at (x1+1,y1) and another at (x2,y1+1) with both cells between them bare.
//
// AND IT IS REPAIRED IN THE GENERATOR AND NOT IN THE RENDERER, which is not a preference: m.table is
// derived from the persisted tile id, the 2D view reads those ids directly and GenCheck.clueSpots
// counts bare bench cells, so a render-side edit would desync all three.
//
// THE FIRST CUT ASKED THE WRONG QUESTION AND THAT IS THE LESSON HERE. It looked at one CELL — no
// orthogonal table beside it, at least one diagonally — i.e. it culled LOOSE cells, on the reasoning
// that a cell with a neighbour is part of a run and should be left alone. But two RUNS whose ends
// meet corner to corner have an orthogonal neighbour each, so neither was ever a candidate, and
// 20000 seeds passed over a fault still on screen at 27,14. Measured with the corrected check:
// 1503 of 2000 seeds carry at least one such pair, where the loose case alone was 1387.
//
// The fault is a property of the PAIR: two cells touch corner-only when they are diagonal and BOTH
// of the two cells they share are bare.
//
// AND THE FIRST ANSWER TO IT — drop one of the two — WAS THE POORER HALF OF THE REPAIR, because the
// two runs are almost always the two arms of an L that stopped one cell short of its own corner. So
// the corner is FILLED first and only what cannot be filled is dropped. `promote` states what
// "cannot" means; what goes when it comes to that is still the loose end of the SHORTER run, so a
// long bench keeps its length and the stub beside it is what disappears
  public static function fixDiagonalTables(state: _FacilityState, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      // TWO PASSES AND NOT ONE INTERLEAVED LOOP, which is what makes this terminate: promotion only
      // ever turns a floor cell into a worktop and the cull only ever the reverse, so a single loop
      // could fill a nook, drop it again and come round for ever. Each pass repeats on its own until
      // a whole scan finds nothing, since either edit can expose a pair that was hidden behind it —
      // and each strictly grows or strictly shrinks the set of worktop cells, so each terminates
      for (fill in [ true, false ])
        {
          var again = true;
          while (again)
            {
              again = false;
              for (y in room.y1...room.y2 + 1)
                for (x in room.x1...room.x2 + 1)
                  // the two diagonals with a HIGHER y only: the other two are the same pairs seen
                  // from their far cell, and testing both ends does the same work twice
                  for (dx in [ -1, 1 ])
                    {
                      if (!isTableCell(cells, x, y) ||
                          !cornerOnly(cells, x, y, dx, 1))
                        continue;
                      if (fill)
                        {
                          // the two cells the pair shares, each with the two hands that are NOT the
                          // pair: for (x+dx, y) they are +dx and -y, for (x, y+1) they are -dx and
                          // +y. either one closes the L, and the nook test picks which
                          if (promote(state, cells, x + dx, y, dx, -1) ||
                              promote(state, cells, x, y + 1, -dx, 1))
                            again = true;
                          continue;
                        }
                      // a tie takes the diagonal partner, which is the later cell in the row-major
                      // scan and so stable for a seed
                      if (orthTables(cells, x, y) < orthTables(cells, x + dx, y + 1))
                        clearTable(state, cells, x, y);
                      else
                        clearTable(state, cells, x + dx, y + 1);
                      again = true;
                    }
            }
        }
    }

// close a corner-touching pair into an L by filling one of the two cells it shares, and say whether
// it did.
//
// ONLY A DEAD-END NOOK IS FILLED, and that guard is the whole reason this needs no reachability pass
// behind it. The cell has to be bare floor with MASONRY on both of the hands that are not the pair,
// so all four of its orthogonal neighbours are solid: two walls and the two worktops. It is an
// alcove and never a link — movement is 8-way (Const.dirx) and nothing stops a player cutting the
// corner into it, but a route THROUGH it would have to cut a blocked corner at both ends while the
// open room lies alongside. So filling it can disconnect nothing, which is the repair
// gen.facility.FacilityRooms.openPockets exists to make, done in reverse and for free.
//
// It is also the cell the L actually wants. The bay rhythm this fault comes out of leaves the arms
// one short of the room's OWN corner (see above), so the nook is that corner: walled on two sides,
// with an arm coming at it along each of the other two.
//
// THE TILE IS THE PLAIN 1X1 AND NOT THE FAMILY'S, deliberately. Nothing downstream reads a worktop's
// family — render.facility.FacilityModel keeps only the boolean, and the bench-or-desk finish comes
// off the room's surface — so the one thing the choice decides is the 2D sprite, and a 1x1 is the
// only art in either family that is a whole worktop on its own cell
  static function promote(state: _FacilityState, cells: Array<Array<Int>>, x: Int, y: Int,
      ax: Int, by: Int): Bool
    {
      if (cells[x][y] != TEMP_BUILDING_ROOM ||
          !isMasonry(cells, x + ax, y) ||
          !isMasonry(cells, x, y + by) ||
          state.area.hasObjectAt(x, y))
        return false;
      cells[x][y] = Const.TILE_LABS_TABLE_1X1;
      return true;
    }

// is this cell wall or glazing, as the building pass left it — the two things a worktop may back
// onto. A DOORWAY IS DELIBERATELY NOT ONE: it is not TEMP_BUILDING_ROOM either, so a plain
// "not walkable" test would read one as solid and let `promote` brick up the cell beside it
  static inline function isMasonry(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      var t = cells[x][y];
      return (t == TEMP_BUILDING_WALL ||
        t == TEMP_BUILDING_INNER_WALL ||
        t == TEMP_BUILDING_WINDOW_HIGH ||
        (t >= TEMP_BUILDING_WINDOW &&
         t <= TEMP_BUILDING_WINDOWV3));
    }

// do (x,y) and its (dx,dy) diagonal touch ONLY at that corner? GenCheck.corner, and the two must
// stay the same test — this culls what that one counts
  static inline function cornerOnly(cells: Array<Array<Int>>, x: Int, y: Int,
      dx: Int, dy: Int): Bool
    {
      return (isTableCell(cells, x + dx, y + dy) &&
        !isTableCell(cells, x + dx, y) &&
        !isTableCell(cells, x, y + dy));
    }

// how many of the four orthogonal neighbours are worktops — how long a run this cell is part of, to
// the only depth the choice needs
  static function orthTables(cells: Array<Array<Int>>, x: Int, y: Int): Int
    {
      var n = 0;
      for (i in 0...Const.dir4x.length)
        if (isTableCell(cells, x + Const.dir4x[i], y + Const.dir4y[i]))
          n++;
      return n;
    }

// take one worktop cell back to bare floor, decoration and all
  static function clearTable(state: _FacilityState, cells: Array<Array<Int>>, x: Int, y: Int)
    {
      cells[x][y] = TEMP_BUILDING_ROOM;
      for (o in state.area.getObjectsAt(x, y))
        if (o.type == 'decoration')
          state.area.removeObject(o);
    }

// add a decoration that the 3D view draws as real furniture: whatever Const.FACILITY_DECO places on
// a high floor cell of this room kind, carrying one of that entry's own atlas frames.
//
// the frame is what the 2D view keeps drawing and what render.facility.FacilityModel reads the kind
// back out of, so nothing new is written to the object and every save made before this existed
// still resolves — see Const.fittingOf
// THE ROLE IS REQUIRED AND IT USED TO BE OPTIONAL, which is the whole of how a bank of machines
// came to stand next to the cubicles in a washroom. `?role` defaulting to BLOCK_LAB meant a caller
// that simply did not think about the room got handed the LABORATORY'S OWN furniture list, silently
// and correctly-compiling — and gen.blocks.RoomBlock.slot, which dresses every room's leftover bays
// including a washroom's, was exactly that caller. An optional argument whose default is one of the
// real answers cannot be told apart from a deliberate choice; a required one makes the compiler ask
  public static function addFitting(state: _FacilityState, x: Int, y: Int, role: String)
    {
      // the 'floor-high' mount only: the table also holds the low list's drums, bins and short
      // server stacks, and none of those is a piece of standing furniture. the ROLE is the block
      // name as-is, so a researcher's office deals the office's own list without a branch here
      var fr = Deco.pick(state.area, Deco.MOUNT_FLOOR_HIGH, role);
      state.area.addDecoration(x, y, fr.row, fr.col);
    }

// stand one fitting of a NAMED kind, for a room template placing its own furniture instead of rolling
// it. the cell goes unwalkable here and the template's own floor pass repaints it in its finish
  public static function placeFitting(state: _FacilityState, x: Int, y: Int, kind: _FittingKind)
    {
      var frames = Const.framesOf(kind);
      var fr = frames[state.area.random(frames.length)];
      state.area.addDecoration(x, y, fr.row, fr.col);
      state.area.getCells()[x][y] = Const.TILE_FLOOR_TILE_UNWALKABLE;
    }

// give the floor back under every fitting the renderer draws in a wall's recess.
//
// A FITTING AGAINST A WALL STANDS IN THE WALL CELL, NOT ON ITS OWN. A wall slab is centred in its
// 4-unit cell, so its face stands 1.0-1.4 units back from the boundary, and
// render.facility.FacilityDeco stands a 1.2-deep rack, cabinet or drum off that face — a sliver of
// it reaches its own cell and the rest is bare floor. Stamped unwalkable, that read as empty floor
// nobody could step on, which is how it was reported in the hangar, the offices and the labs.
//
// RUN AFTER finalizeTiles AND NOT AT PLACEMENT, because every room pass before it treats
// TEMP_BUILDING_ROOM as a free cell and the unwalkable stamp is what keeps a bench off a cabinet.
// The wall test is FacilityDeco.wall's on final ids: masonry for anything, and glazing or the shutter
// as well for the LOW list, which the renderer pushes against any wall face. A fitting with no wall
// on any hand stands mid-cell and keeps its block
  public static function clearFittings(state: _FacilityState)
    {
      var cells = state.area.getCells();
      for (s in state.area.spawns)
        {
          if (s.type != 'decoration')
            continue;
          var kind = Const.fittingOf(s.row, s.col);
          if (!standsClear(kind))
            continue;
          var low = Const.isLowFitting(kind);
          var backed = false;
          for (i in 0...Const.dir4x.length)
            {
              var t = cells[s.x + Const.dir4x[i]][s.y + Const.dir4y[i]];
              if (t == Const.TILE_BUILDING ||
                  (low &&
                   (t == Const.TILE_HANGAR_DOOR ||
                    t == Const.TILE_WINDOW_HIGH ||
                    (t >= Const.TILE_WINDOWH1 && t <= Const.TILE_WINDOWV3))))
                backed = true;
            }
          if (!backed)
            continue;
          var t = cells[s.x][s.y];
          if (t == Const.TILE_FLOOR_TILE_UNWALKABLE)
            cells[s.x][s.y] = Const.TILE_FLOOR_TILE;
          else if (t == Const.TILE_FLOOR_CONCRETE_UNWALKABLE)
            cells[s.x][s.y] = Const.TILE_FLOOR_CONCRETE;
          else if (t == Const.TILE_FLOOR_WOOD1 + UNWALKABLE_TILE_OFFSET ||
                   t == Const.TILE_FLOOR_MARBLE1 + UNWALKABLE_TILE_OFFSET)
            cells[s.x][s.y] = t - UNWALKABLE_TILE_OFFSET;
        }
    }

// does this fitting, stood against a wall, leave its own cell's centre clear?
//
// ponytail: a hand list off the render depths, measured live as the gap between the drawn rect and
// the cell centre — 1.08..1.68 for every kind here, 0.08..0.68 for the machines, the analyser, the
// basin and the stall. A new kind or a deeper model wants a line here; deriving it from FacilityStyle
// would put the renderer in the headless generator
  static function standsClear(kind: _FittingKind): Bool
    {
      return switch (kind)
        {
          case FIT_SHELVING, FIT_BOOKCASE, FIT_RACK, FIT_RACK_LOW, FIT_CABINET,
            FIT_DRUM_STEEL, FIT_DRUM_BIO, FIT_DRUM_RAD, FIT_BIN, FIT_SOFA, FIT_TABLE_LOW,
            FIT_PALLET_RACK, FIT_PALLET_STACK, FIT_DRUM_PALLET: true;
          default: false;
        }
    }

// add decoration from a list
  public static function addDecoration(state: _FacilityState, x: Int, y: Int,
      infos: Array<_TileRow>)
    {
      var info = infos[state.area.random(infos.length)];
      var col = state.area.random(info.amount);
      state.area.addDecoration(x, y, info.row, col);
    }
}
