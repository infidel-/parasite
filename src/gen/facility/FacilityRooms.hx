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
  static inline var BIG_TABLE_DOOR_CLEARANCE = 3;

// hand each room of this structure a template.
//
// the same shape game.CorpAreaGenerator uses for its four office themes: size, a quota and dice, with
// no persisted tag — the room's FLOOR TILE is what carries the theme out of here, and the 3D layer
// reads the theme back off that tile alone (render.facility.FacilityModel.surfOf)
  public static function assignRoomThemes(state: _FacilityState)
    {
      // a big room is a laboratory: the bench runs, the island and the aisle markings all want the
      // space, and a compound of nothing but small offices reads as an office block
      var cells = state.area.getCells();
      var cand = [for (room in state.rooms)
        if (room.w <= ROOM_SIZE && room.h <= ROOM_SIZE) room];
      if (cand.length == 0)
        return;
      // THE WASHROOM IS PICKED FIRST AND PICKED FOR ITS WALL. Its light wells need one wall that is
      // exterior masonry end to end, and a room in the middle of a building has none — so a plain
      // first-come roll put the compound's only washroom in an interior core about half the time and
      // it came out with no glazing at all. The lab and the office are indifferent to this, so the
      // toilet gets first refusal on a perimeter room and they take what is left
      var wash = -1;
      for (i in 0...cand.length)
        if (exteriorWall(cells, cand[i]) != null)
          {
            wash = i;
            break;
          }
      if (wash < 0)
        wash = 0;
      if (state.area.chance(60))
        cand[wash].role = ROLE_TOILET;
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

// fill rooms with content
  public static function generateRoomContents(state: _FacilityState)
    {
      for (room in state.rooms)
        {
          if (room.role == ROLE_CABINET)
            roomCabinet(state, room);
          else if (room.role == ROLE_TOILET)
            FacilityToilet.roomToilet(state, room);
          else roomChemistryLab(state, room);
        }
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

// check if a big table spot keeps room door ingress clear
  static function isBigTableSpotValid(state: _FacilityState, room: _Room,
      doors: Array<_Door>, x: Int, y: Int, w: Int, h: Int): Bool
    {
      var cells = state.area.getCells();
      for (i in 0...h)
        for (j in 0...w)
          if (cells[x + j][y + i] != TEMP_BUILDING_ROOM)
            return false;

      for (door in doors)
        {
          var sx = 0, sy = 0;
          var dx = 0, dy = 0;
          var hasIngress = false;
          if (door.x == room.x1 - 1)
            {
              sx = room.x1;
              sy = door.y;
              dx = 1;
              hasIngress = true;
            }
          else if (door.x == room.x2 + 1)
            {
              sx = room.x2;
              sy = door.y;
              dx = -1;
              hasIngress = true;
            }
          else if (door.y == room.y1 - 1)
            {
              sx = door.x;
              sy = room.y1;
              dy = 1;
              hasIngress = true;
            }
          else if (door.y == room.y2 + 1)
            {
              sx = door.x;
              sy = room.y2;
              dy = -1;
              hasIngress = true;
            }
          if (!hasIngress)
            continue;

          for (i in 0...BIG_TABLE_DOOR_CLEARANCE)
            {
              var px = sx + dx * i;
              var py = sy + dy * i;
              if (px >= x &&
                  px < x + w &&
                  py >= y &&
                  py < y + h)
                return false;
            }
        }
      return true;
    }

// repaint a themed room's floor, walkable cells in `tile` and the cells furniture stands on in its
// unwalkable twin one tileset row below. the bench tiles are left alone: a desk is a prop standing ON
// the floor, and the renderer takes a table cell's surface off the ROOM it sits in
  public static function paintRoomFloor(state: _FacilityState, room: _Room, tile: Int)
    {
      var cells = state.area.getCells();
      for (y in room.y1...room.y2 + 1)
        for (x in room.x1...room.x2 + 1)
          {
            if (cells[x][y] == TEMP_BUILDING_ROOM)
              cells[x][y] = tile;
            else if (cells[x][y] == Const.TILE_FLOOR_TILE_UNWALKABLE)
              cells[x][y] = tile + UNWALKABLE_TILE_OFFSET;
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
            if (cells[x][y] < Const.TILE_LABS_TABLE_3X3_7 ||
                cells[x][y] > Const.TILE_LABS_TABLE2_1X1)
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

// add a decoration that the 3D view draws as real furniture: a KIND off Const.FACILITY_FITTINGS,
// carrying one of that kind's own atlas frames.
//
// the frame is what the 2D view keeps drawing and what render.facility.FacilityModel reads the kind
// back out of, so nothing new is written to the object and every save made before this existed
// still resolves — see Const.fittingOf
  public static function addFitting(state: _FacilityState, x: Int, y: Int, ?role: String)
    {
      // the HIGH kinds only: the table also holds the low list's drums, bins and short server
      // stacks, and none of those is a piece of standing furniture. an office takes the narrower
      // list — a bench lathe against the wall of a researcher's room is the laboratory's furniture
      var kinds = (role == ROLE_CABINET ? Const.officeFittings() : Const.highFittings());
      var f = kinds[state.area.random(kinds.length)];
      var fr = f.frames[state.area.random(f.frames.length)];
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

// add decoration from a list
  public static function addDecoration(state: _FacilityState, x: Int, y: Int,
      infos: Array<_TileRow>)
    {
      var info = infos[state.area.random(infos.length)];
      var col = state.area.random(info.amount);
      state.area.addDecoration(x, y, info.row, col);
    }
}
