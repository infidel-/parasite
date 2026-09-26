// what goes inside one corp room, per role
//
// the seven room templates and the two shared wall-dressing passes, ported from
// game.CorpAreaGenerator's roomSolo / roomMeeting / roomKitchen / roomWork and their decorate*
// helpers. Three of the seven are new: the cubicle farm, the washroom and the server room.
//
// EVERY TEMPLATE PAINTS ITS OWN FLOOR FIRST and that floor is the room's record. _Room.role is
// written beside it by gen.blocks.CorpBlocks, but the role is a field on a structure only new
// saves carry, where the floor id is in the cell grid of every save there has ever been — so
// render.corp.CorpModel reads the floor and treats the role as the refinement.

package gen.corp;

import Const;
import game.AreaGenerator.*;
import gen.GenTree;
import gen.blocks.CorpBlocks;
import gen.corp.CorpTemp.*;

class CorpRooms
{
  // A CUBICLE BLOCK IS `W` PODS WIDE AND TWO DEEP, with a passage column between blocks and an
  // aisle row between bands. One pod is ONE cell: a desk, its own chair in the aisle it faces, and
  // a partition on every boundary it shares with another pod. 3 where the room can hold two blocks
  // of three plus their passages, 2 otherwise
  public static inline var POD_BLOCK_W = 3;
  public static inline var POD_BLOCK_MIN = 2;
  // one band is desk, desk, aisle — and the band above it supplied the aisle its first desk row
  // faces, which is why the pitch is three rows and not four. IT WAS FOUR while the partition
  // between the two rows owned a cell of its own; it is emitted on their shared boundary now
  public static inline var POD_BAND_H = 3;
  // and how far apart a server room's rack rows stand: a row of racks and an aisle to reach them
  public static inline var RACK_PITCH = 2;
  // HOW MANY FIXTURES A ROOM GETS, WHICH IS NOT HOW WIDE IT IS. Every one of these runs used to
  // span the whole wall, so a washroom read as a row of nine basins facing a row of five stalls
  // and a server room as a warehouse — the fittings scaled linearly with the room and nothing
  // said they should. A real washroom has three basins whether it is in a small office or a big
  // one. Centred on their wall rather than started at one end, so the run reads as an
  // installation and not as a leftover
  public static inline var BASIN_MAX = 3;
  public static inline var STALL_MAX = 3;
  public static inline var RACK_ROWS_MAX = 4;
  // the archive's wall ring: the percent of its cells left bare, and the span a rank has to reach
  // before it is cut in two by a cross aisle
  public static inline var ARCHIVE_RING_BARE = 15;
  public static inline var ARCHIVE_GAP_SPAN = 5;
  // and the percent chance each walled corner of it takes a bin
  public static inline var ARCHIVE_CORNER_BIN = 40;
  // and the percent chance a ring cell with only glazing behind it takes a table
  public static inline var ARCHIVE_TABLE = 70;
  // and the boardroom table, which was the last run in this file still written the old way:
  // `tw = room.w - 4` with no cap at all. Measured over 800 meeting rooms — min 12 cells, median
  // 32, max 64, and 783 of the 800 had an axis of five cells or more. At CityConfig.CELL 4 and
  // FacilityStyle.WALL_H 6 for a 3 m storey a cell is 2 m, so the MEDIAN boardroom table was
  // 16 m x 8 m and the largest 16 m square, a third of the room's floor by construction
  // the biggest a boardroom table may be, in cells. 4 x 3 was fitted when the cap first went on,
  // against the uncapped `w - 4` that gave a 16 m x 8 m median table; measured after, a 5-wide
  // room takes `min(1, 4)` on one axis and a 10 x 5 boardroom came out with a 1 x 3 table in it
  // — 9.8% of the rect furnished, the emptiest room on the floor. 6 x 4 is a twelve-seater at
  // this scale and still leaves the two clear cells a side that `w - 4` guarantees
  public static inline var TABLE_W_MAX = 6;
  public static inline var TABLE_H_MAX = 4;
  // THE EXEC SUITE'S SIZE GATE: 4 across and 7 long, on either axis. See `execSuite`
  public static inline var SUITE_SPAN = 4;
  public static inline var SUITE_LEN_X = 7;
  public static inline var SUITE_LEN_Y = 7;
  // and the biggest a plain exec office's rug may be, in cells on either axis
  public static inline var RUG_MAX = 4;

// --- the shared spawn helpers. gen.facility.FacilityRooms has its own pair and they are NOT
// interchangeable: that one drops _TileRow.col, which is right for the facility's tables (none of
// them set it) and wrong for half the corp ones, where the col is what picks the sub-run out of a
// shared atlas row

// one decoration off a flat list of atlas runs
  public static function addDecoration(state: _CorpState, x: Int, y: Int,
      infos: Array<_TileRow>)
    {
      var info = infos[state.area.random(infos.length)];
      var col = state.area.random(info.amount) + (info.col != null ? info.col : 0);
      state.area.addDecoration(x, y, info.row, col);
    }

// one decoration off a list of GROUPS, without repeating a group until every one has been spent.
// returns the remaining groups, refilled from `full` once it empties — the caller carries that
// array from cell to cell, which is what keeps a wall from wearing four water coolers
  public static function addDecorationExt(state: _CorpState, x: Int, y: Int,
      groups: Array<_TileGroup>, full: Array<_TileGroup>): Array<_TileGroup>
    {
      if (groups.length == 0)
        return groups;
      var group = groups[state.area.random(groups.length)];
      groups.remove(group);
      if (groups.length == 0)
        groups = full.copy();
      var info = group[state.area.random(group.length)];
      var col = state.area.random(info.amount) + (info.col != null ? info.col : 0);
      state.area.addDecoration(x, y, info.row, col);
      // A BIN DOES NOT TAKE THE TILE. The callers write the room's unwalkable twin before the group
      // is picked, and a waste bin standing on a sealed cell was a whole tile of floor lost to a
      // thing you can step round — reported for every room that deals one. Every caller hands in a
      // twin, so taking the offset back off is the room's own floor; render.corp.CorpDeco.bins
      // stands the bin against the masonry so the actor on the cell never meets it
      if (group == Const.CORP_TRASH)
        {
          var cells = state.area.getCells();
          cells[x][y] -= UNWALKABLE_TILE_OFFSET;
        }
      return groups;
    }

// dress the four corners of a room, each with either a small table or a full-height unit
  public static function decorateCorners(state: _CorpState, room: _Room,
      small: Array<_TileGroup>, big: Array<_TileGroup>,
      smallFloorID: Int, bigFloorID: Int, smallChance: Int)
    {
      var cells = state.area.getCells();
      var deco = small.copy();
      var decoBig = big.copy();
      var corners = [
        { x: room.x1, y: room.y1 },
        { x: room.x2, y: room.y1 },
        { x: room.x1, y: room.y2 },
        { x: room.x2, y: room.y2 },
      ];
      for (c in corners)
        {
          // and never the cell a doorway opens onto — see `atDoor`
          if (atDoor(cells, c.x, c.y))
            continue;
          if (state.area.chance(smallChance))
            {
              cells[c.x][c.y] = smallFloorID;
              deco = addDecorationExt(state, c.x, c.y, deco, small);
            }
          else
            {
              cells[c.x][c.y] = bigFloorID;
              decoBig = addDecorationExt(state, c.x, c.y, decoBig, big);
            }
        }
    }

// IS THIS CELL THE ONE A DOORWAY OPENS ONTO, on any of its four hands?
//
// every dressing this file lays is an UNWALKABLE floor twin, so a cell inside a threshold is a
// sealed room. The test used to look only STRAIGHT THROUGH the wall a run was walking — the left
// run checked (x1-1, y) and the right run (x2+1, y) — which cannot see a door in the TOP or BOTTOM
// wall, and a corner cell has one of each. And the corner took its dressing unconditionally:
// `hasLeft || isCorner`, with the door test folded into `hasLeft` alone.
//
// Invisible while rooms were 8 x 8, because a room that size has other ways in and the flood found
// one. At the halved size it is 61 rooms over 200 towers — 52 of them open plan, which owns the
// longest dressing list in the file
  static function atDoor(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      for (i in 0...Const.dir4x.length)
        if (cells[x + Const.dir4x[i]][y + Const.dir4y[i]] == BLDG_INNER_DOOR)
          return true;
      return false;
    }

// dress the two long walls of a room, never twice in a row and never beside a doorway.
//
// A CORNER ALWAYS TAKES ONE, whatever the roll says — that is the original's `hasLeft || isCorner`
// and it is load-bearing for the same reason the facility's is: a clue spawns on a bare cell and
// the corner is where its activation cross reaches two walls at once
// `smallFloorID`/`bigFloorID` ARE THE CALLER'S OWN FLOOR, unwalkable twin — this writes them into
// the grid, so a room that hands over somebody else's floor finalises as somebody else's ROOM. See
// `meeting`, which did exactly that and produced four unrelated-looking faults from one id
  public static function decorateWalls(state: _CorpState, room: _Room,
      small: Array<_TileGroup>, big: Array<_TileGroup>,
      smallFloorID: Int, bigFloorID: Int, chance: Int, smallChance: Int)
    {
      var cells = state.area.getCells();
      var deco = small.copy();
      var decoBig = big.copy();
      var prevLeft = false, prevRight = false;
      for (y in room.y1...room.y2 + 1)
        {
          var isCorner = (y == room.y1 || y == room.y2);

          // left side
          var hasLeft = state.area.chance(chance);
          if (prevLeft)
            {
              hasLeft = false;
              prevLeft = false;
            }
          if ((hasLeft || isCorner) &&
              !atDoor(cells, room.x1, y))
            {
              prevLeft = true;
              if (state.area.chance(smallChance))
                {
                  cells[room.x1][y] = smallFloorID;
                  deco = addDecorationExt(state, room.x1, y, deco, small);
                }
              else
                {
                  cells[room.x1][y] = bigFloorID;
                  decoBig = addDecorationExt(state, room.x1, y, decoBig, big);
                }
            }

          // right side
          var hasRight = state.area.chance(chance);
          if (prevRight)
            {
              hasRight = false;
              prevRight = false;
            }
          if ((hasRight || isCorner) &&
              !atDoor(cells, room.x2, y))
            {
              prevRight = true;
              if (state.area.chance(smallChance))
                {
                  cells[room.x2][y] = smallFloorID;
                  deco = addDecorationExt(state, room.x2, y, deco, small);
                }
              else
                {
                  cells[room.x2][y] = bigFloorID;
                  decoBig = addDecorationExt(state, room.x2, y, decoBig, big);
                }
            }
        }
    }

// --- the templates

// an executive office: dark marble, the executive's desk and chair with two visitor chairs in front
// of it, a lounge at the far end where the room is long enough for one, a plant in every free corner
// and a rug on the floor in front of whatever it has
  public static function exec(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, MARBLE1);
      // the SUITE first, desk and lounge at the two ends of the long axis, and the plain office
      // where the room will not take one: a 3x2 desk from 4 x 4, and under that a run
      if (!execSuite(state, node, room))
        {
          // 4 x 4, AND THE GUARD HAS COME DOWN TWICE WITH THE CARVE. It was 6 x 6, then 5 x 5 when
          // the demand asked for 5; with ROOM_SIZE 6 and SPLIT_MIN 5 a floor carries 29 rooms and
          // only a handful clear 5 on both axes, so six 5x5 demands dealt ahead of this one left it
          // with nothing — "quota short: room-exec got 0" on 14 towers in 3,000
          if (room.w >= 4 &&
              room.h >= 4)
            execDesk(state, node, room);
          else
            execRun(state, node, room);
        }
      // the rug BEFORE the plants: in a 3-wide office the only clear 2x2 left by a desk run takes
      // the end corners, and a plant in a rect's corner stands off the oval rug anyway
      execRug(state, room);
      cornerPlants(state, room);
    }

// the executive's own 3x2 desk, against whichever end wall has no door in it, with the visitors'
// chairs on its far side
  static function execDesk(state: _CorpState, node: _GenNode, room: _Room)
    {
      var hasNorthDoor = false, hasSouthDoor = false;
      for (door in state.doors)
        if (door.roomID1 == room.id ||
            door.roomID2 == room.id)
          {
            if (door.y == room.y1 - 1)
              hasNorthDoor = true;
            if (door.y == room.y2 + 1)
              hasSouthDoor = true;
          }
      var tx = room.x1 + Std.int(room.w / 2) - 1;
      var ty = room.y1 + 1;
      var cy = ty - 1;
      if (hasNorthDoor)
        {
          ty = room.y2 - 2;
          cy = ty + 2;
        }
      // A DOOR IN BOTH END WALLS USED TO MEAN NO DESK AT ALL, and 382 exec offices in 600 seeds
      // came out as bare marble because of it — every zone-less room on a corp floor was one of
      // these. There is a third place to put a desk and it is the obvious one: the middle of the
      // room, free-standing, facing the way the occupant would sit. Nothing about an executive's
      // desk requires a wall behind it
      if (hasNorthDoor && hasSouthDoor)
        {
          ty = room.y1 + Std.int((room.h - 2) / 2);
          cy = ty - 1;
        }
      execDeskAt(state, node, tx, ty, tx + 1, cy);
      // THE VISITORS SIT ACROSS THE DESK FROM ITS OWNER, one at each end of the slab. A chair is a
      // walkable decoration like every seat in the tower, so it costs the room no lane; it only
      // needs a free cell of the room's own floor that is not a doorway
      var vy = (cy < ty ? ty + 2 : ty - 1);
      for (vx in [ tx, tx + 2 ])
        seat(state, room, vx, vy, Const.CORP_ARMCHAIR);
    }

// lay the 3x2 desk block with its top-left at (tx,ty) and its owner's chair at (cx,cy), which is
// one of the two cells over the middle of a long side. the monitor stands on the desk cell next to
// the chair and the rest of the top takes a roll of desk things
  static function execDeskAt(state: _CorpState, node: _GenNode, tx: Int, ty: Int, cx: Int, cy: Int)
    {
      var cells = state.area.getCells();
      var full = [
        Const.CORP_TABLE_PHONE,
        Const.CORP_TABLE_LAMP,
        Const.CORP_TABLE_FILES,
        Const.CORP_TABLE_STATIONERY,
      ];
      var deco = full.copy();
      var compx = cx;
      var compy = (cy < ty ? ty : ty + 1);
      GenTree.add(node, CorpBlocks.ZONE_TABLE, tx, ty, tx + 2, ty + 1);
      addDecoration(state, cx, cy, Const.CORP_EXEC_CHAIR);
      addDecoration(state, compx, compy, Const.CORP_COMPUTERS);
      var left = full.length;
      for (dy in 0...2)
        for (dx in 0...3)
          {
            cells[tx + dx][ty + dy] = Const.DARK_TABLE_MARBLE1_3X2[dy][dx];
            if (tx + dx == compx &&
                ty + dy == compy)
              continue;
            if (state.area.chance(40) &&
                left > 0)
              {
                deco = addDecorationExt(state, tx + dx, ty + dy, deco, full);
                left--;
              }
          }
    }

// a small exec office's desk: a run of two or three worktop cells down the middle of the room's
// LONG axis, with the owner's chair beside its middle cell.
//
// ALONG THE LONG AXIS, because 58% of exec offices are 3 cells on their short side and the old
// across-the-room run was ONE pedestal there. Two cells of clearance at the ends keep both lanes
// joined, and it is skipped outright where it would seal a doorway, the fault `atDoor` exists for
  static function execRun(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      var alongX = (room.w >= room.h);
      var len = (alongX ? room.w : room.h) - 2;
      if (len > 3)
        len = 3;
      if (len < 2)
        return;
      var sx = (alongX ? room.x1 + Std.int((room.w - len) / 2) : room.x1 + Std.int((room.w - 1) / 2));
      var sy = (alongX ? room.y1 + Std.int((room.h - 1) / 2) : room.y1 + Std.int((room.h - len) / 2));
      var ex = (alongX ? sx + len - 1 : sx);
      var ey = (alongX ? sy : sy + len - 1);
      for (x in sx...ex + 1)
        for (y in sy...ey + 1)
          if (atDoor(cells, x, y))
            return;
      GenTree.add(node, CorpBlocks.ZONE_DESK_RUN, sx, sy, ex, ey);
      var full = [
        Const.CORP_TABLE_PHONE,
        Const.CORP_TABLE_LAMP,
        Const.CORP_TABLE_FILES,
        Const.CORP_TABLE_STATIONERY,
      ];
      var deco = full.copy();
      for (i in 0...len)
        {
          var x = (alongX ? sx + i : sx);
          var y = (alongX ? sy : sy + i);
          cells[x][y] = Const.TILE_DARK_TABLE_MARBLE1_1X1;
          if (i == len - 1)
            addDecoration(state, x, y, Const.CORP_COMPUTERS);
          else if (state.area.chance(50))
            deco = addDecorationExt(state, x, y, deco, full);
        }
      // the chair on the far side of the middle cell from the room's first wall
      var mx = (alongX ? sx + Std.int(len / 2) : sx + 1);
      var my = (alongX ? sy + 1 : sy + Std.int(len / 2));
      addDecoration(state, mx, my, Const.CORP_EXEC_CHAIR);
    }

// THE EXEC SUITE: the desk at one end of the room's long axis and a lounge at the other — a sofa
// against the end wall, a low table in front of it and two armchairs facing it across the table.
//
// Measured over 300 seeds, 58% of exec offices are 3 cells on their short side, and a room at least
// 4 across and 7 long comes up 4.07 times a floor (1.97 of them long across X). Across Y the desk
// block is 2 deep and its chairs take the rows either side, so at exactly 7 the visitors' row is
// the lane and the visitors are left out. The lounge is a
// solid 3x2 block and keeps a lane down each side of it — the rule gen.blocks.RoomBlock.lounge paid
// for with two unreachable 7x3 offices in 4000 seeds — and the desk and the lounge keep a lane
// between them. Tried at both ends and at every lane-keeping offset across the room, centre first;
// false when nothing fits clear of the doorways, and `exec` falls back to the plain office
  static function execSuite(state: _CorpState, node: _GenNode, room: _Room): Bool
    {
      var cells = state.area.getCells();
      var alongX = (room.w >= room.h);
      var len = (alongX ? room.w : room.h);
      var span = (alongX ? room.h : room.w);
      if (span < SUITE_SPAN ||
          len < (alongX ? SUITE_LEN_X : SUITE_LEN_Y))
        return false;
      // the offsets across the room, centre first: the lounge's first row, and the desk's
      var lounge = byCentre(1, span - 3);
      var desk = (alongX ? byCentre(1, span - 3) : byCentre(0, span - 3));
      // the desk's first cell along the axis. across X the chairs are beside the slab, so a room
      // with a spare cell buys the desk a lane behind it; across Y the owner's chair takes u 0
      var du = (alongX ? (len >= SUITE_LEN_X + 1 ? 1 : 0) : 1);
      for (flip in [ false, true ])
        for (v0 in lounge)
          for (dv in desk)
            {
              var at = function(u: Int, v: Int)
                {
                  var x = (alongX ? (flip ? room.x2 - u : room.x1 + u) : room.x1 + v);
                  var y = (alongX ? room.y1 + v : (flip ? room.y2 - u : room.y1 + u));
                  return { x: x, y: y };
                };
              // every cell the suite stands on, solid or seat, has to be the room's bare floor and
              // not a doorway
              var solid = [];
              for (u in len - 3...len)
                for (v in v0...v0 + 2)
                  solid.push(at(u, v));
              var deskCells = [];
              var owner = null;
              var visitors = [];
              if (alongX)
                {
                  for (u in du...du + 3)
                    for (v in dv...dv + 2)
                      deskCells.push(at(u, v));
                  owner = at(du + 1, dv - 1);
                  visitors = [ at(du, dv + 2), at(du + 2, dv + 2) ];
                }
              else
                {
                  for (u in du...du + 2)
                    for (v in dv...dv + 3)
                      deskCells.push(at(u, v));
                  owner = at(du - 1, dv + 1);
                  // and at 7 long the visitors' row would stand back to back with the lounge's
                  // armchairs, so a room that short keeps the row as its lane instead
                  if (len > SUITE_LEN_Y)
                    visitors = [ at(du + 2, dv), at(du + 2, dv + 2) ];
                }
              var ok = true;
              var blocked = new Map<Int, Bool>();
              for (c in solid.concat(deskCells).concat([ owner ]))
                if (cells[c.x][c.y] != MARBLE1 ||
                    atDoor(cells, c.x, c.y))
                  ok = false;
              for (c in solid.concat(deskCells))
                blocked.set(c.x * 1000 + c.y, true);
              // AND IT MAY NOT SEAL ANY OF THE ROOM OFF. A placement that does is not caught by the
              // oracle — gen.corp.CorpConnect.openPockets erodes whatever walls the pocket in, and
              // what it erodes is the furniture: measured on the first build, a 9 x 4 suite came
              // back with the desk's first column and both door-end plants eaten
              if (!ok ||
                  !roomOpen(state, room, blocked))
                continue;

              // the desk, off its top-left cell whichever way round the room is
              var tx = room.x2, ty = room.y2;
              for (c in deskCells)
                {
                  if (c.x < tx)
                    tx = c.x;
                  if (c.y < ty)
                    ty = c.y;
                }
              execDeskAt(state, node, tx, ty, owner.x, owner.y);
              for (c in visitors)
                seat(state, room, c.x, c.y, Const.CORP_ARMCHAIR);

              // the lounge, and the rug under it: the rug runs one lane wider than the furniture
              // on each side, so the whole group stands ON it rather than beside its edge
              var twin = Const.TILE_FLOOR_EXEC_RUG + UNWALKABLE_TILE_OFFSET;
              for (u in len - 3...len)
                for (v in v0 - 1...v0 + 3)
                  {
                    var c = at(u, v);
                    if (cells[c.x][c.y] == MARBLE1)
                      cells[c.x][c.y] = Const.TILE_FLOOR_EXEC_RUG;
                  }
              var l0 = at(len - 3, v0), l1 = at(len - 1, v0 + 1);
              GenTree.add(node, CorpBlocks.ZONE_LOUNGE,
                Std.int(Math.min(l0.x, l1.x)), Std.int(Math.min(l0.y, l1.y)),
                Std.int(Math.max(l0.x, l1.x)), Std.int(Math.max(l0.y, l1.y)));
              for (v in v0...v0 + 2)
                {
                  var groups = [ Const.CORP_ARMCHAIR, Const.CORP_TABLE_LOW, Const.CORP_SOFA ];
                  for (i in 0...3)
                    {
                      var c = at(len - 3 + i, v);
                      cells[c.x][c.y] = twin;
                      addDecoration(state, c.x, c.y, groups[i]);
                    }
                }
              return true;
            }
      return false;
    }

// the offsets lo..hi ordered by their distance from the middle of that range
  static function byCentre(lo: Int, hi: Int): Array<Int>
    {
      var mid = (lo + hi) / 2;
      var out = [for (i in lo...hi + 1) i];
      out.sort(function(a, b) return Reflect.compare(Math.abs(a - mid), Math.abs(b - mid)));
      return out;
    }

// seat one chair on a free cell of the room's own floor, if there is one there
  static function seat(state: _CorpState, room: _Room, x: Int, y: Int, group: _TileGroup)
    {
      var cells = state.area.getCells();
      if (x < room.x1 ||
          x > room.x2 ||
          y < room.y1 ||
          y > room.y2 ||
          cells[x][y] != MARBLE1 ||
          atDoor(cells, x, y))
        return;
      addDecoration(state, x, y, group);
    }

// a plant in every corner of the room that is still its bare floor (or its rug) and is not a
// doorway.
//
// THIS OPENS WHAT `exec` HELD SHUT AT w >= 7, and on purpose: the dressed corners it measured were
// a cooler, a coffee table and a router as well as a plant, which sealed a 4x4 office round a 3x2
// slab (fill 26.9% -> 20.7% once CorpConnect.openPockets had eaten the desk to reach the floor). A
// corner is the one cell of a room no lane runs through, so a plant there seals nothing a lane
// needs; the oracle is what says so, not this comment
  static function cornerPlants(state: _CorpState, room: _Room)
    {
      var cells = state.area.getCells();
      for (c in [
          { x: room.x1, y: room.y1 },
          { x: room.x2, y: room.y1 },
          { x: room.x1, y: room.y2 },
          { x: room.x2, y: room.y2 },
        ])
        {
          var blocked = new Map<Int, Bool>();
          blocked.set(c.x * 1000 + c.y, true);
          var onRug = (cells[c.x][c.y] == Const.TILE_FLOOR_EXEC_RUG);
          if ((cells[c.x][c.y] != MARBLE1 &&
              !onRug) ||
              atDoor(cells, c.x, c.y) ||
              state.area.hasObjectAt(c.x, c.y) ||
              !roomOpen(state, room, blocked))
            continue;
          cells[c.x][c.y] = (onRug ? Const.TILE_FLOOR_EXEC_RUG : Const.TILE_FLOOR_MARBLE1) +
            UNWALKABLE_TILE_OFFSET;
          addDecoration(state, c.x, c.y, Const.CORP_PLANT);
        }
    }

// can every walkable cell of the exec office still be reached from its doorways, with the cells in
// `blocked` (keyed x * 1000 + y) taken as furniture? True for a room with no doorway to start from.
//
// THE EXEC OFFICE ASKS THIS OF ITSELF because the repair downstream cannot tell a pocket it should
// open from furniture it should keep: gen.corp.CorpConnect.openPockets reaches a sealed cell by
// eroding whatever stands in the way, so a placement that walls a lane in is not rejected, it is
// half-deleted after the fact
  static function roomOpen(state: _CorpState, room: _Room, blocked: Map<Int, Bool>): Bool
    {
      var cells = state.area.getCells();
      var walk = function(x: Int, y: Int)
        return x >= room.x1 &&
          x <= room.x2 &&
          y >= room.y1 &&
          y <= room.y2 &&
          !blocked.exists(x * 1000 + y) &&
          (cells[x][y] == MARBLE1 ||
          cells[x][y] == Const.TILE_FLOOR_EXEC_RUG);
      var seen = new Map<Int, Bool>();
      var stack = [];
      var total = 0;
      for (x in room.x1...room.x2 + 1)
        for (y in room.y1...room.y2 + 1)
          if (walk(x, y))
            {
              total++;
              if (atDoor(cells, x, y))
                {
                  seen.set(x * 1000 + y, true);
                  stack.push({ x: x, y: y });
                }
            }
      if (stack.length == 0)
        return true;
      var n = stack.length;
      while (stack.length > 0)
        {
          var c = stack.pop();
          for (d in [ [ 1, 0 ], [ -1, 0 ], [ 0, 1 ], [ 0, -1 ] ])
            {
              var x = c.x + d[0], y = c.y + d[1];
              if (!walk(x, y) ||
                  seen.exists(x * 1000 + y))
                continue;
              seen.set(x * 1000 + y, true);
              stack.push({ x: x, y: y });
              n++;
            }
        }
      return n == total;
    }

// the rug in an office that has no lounge: the biggest rect of bare floor at least 2x2, capped at
// RUG_MAX on either axis, nearest the room's middle. Written as Const.TILE_FLOOR_EXEC_RUG, which
// is still the room's marble to walk on and is what render.corp.CorpRugs lays the oval over.
// A room that already has a rug (the suite's) is left alone
  static function execRug(state: _CorpState, room: _Room)
    {
      var cells = state.area.getCells();
      for (x in room.x1...room.x2 + 1)
        for (y in room.y1...room.y2 + 1)
          if (cells[x][y] == Const.TILE_FLOOR_EXEC_RUG ||
              cells[x][y] == Const.TILE_FLOOR_EXEC_RUG + UNWALKABLE_TILE_OFFSET)
            return;
      var best = null;
      var bestArea = 0;
      var bestD = 0.0;
      var mx = (room.x1 + room.x2) / 2, my = (room.y1 + room.y2) / 2;
      for (w in 2...RUG_MAX + 1)
        for (h in 2...RUG_MAX + 1)
          for (x0 in room.x1...room.x2 - w + 2)
            for (y0 in room.y1...room.y2 - h + 2)
              {
                var free = true;
                for (x in x0...x0 + w)
                  for (y in y0...y0 + h)
                    if (cells[x][y] != MARBLE1)
                      free = false;
                if (!free)
                  continue;
                var d = Math.abs(x0 + (w - 1) / 2 - mx) + Math.abs(y0 + (h - 1) / 2 - my);
                if (w * h > bestArea ||
                    (w * h == bestArea && d < bestD))
                  {
                    best = { x: x0, y: y0, w: w, h: h };
                    bestArea = w * h;
                    bestD = d;
                  }
              }
      if (best == null)
        return;
      for (x in best.x...best.x + best.w)
        for (y in best.y...best.y + best.h)
          cells[x][y] = Const.TILE_FLOOR_EXEC_RUG;
    }

// a meeting room: one long table in the middle, boards and a projector round the walls.
//
// **THE `bigFloorID` ARGUMENT IS THE ROOM'S OWN FLOOR, UNWALKABLE TWIN**, and this one line used
// to read `TILE_FLOOR_CARPET` where every sibling template passes its own (exec MARBLE1, kitchen
// WOOD1, cubicle CUBICLE, servers SERVER, toilet MARBLE2, open WOOD2). `decorateWalls` stamps it
// straight into the grid on the room's x1/x2 columns, so one wrong id produced four separate
// faults at once and they looked unrelated:
//   the WALL RUN ALTERNATED. CorpModel.surfOf read the stray cells back as Surf.CARPET, and
//     CorpStyle's wallInto leaves CARPET on the WALL_OFFICE catch-all — so every other cell of one
//     boardroom wall wore office board and the rest wore wall-meeting.
//   THE TABLE WAS REPAINTED. FacilityModel.themeRooms takes the LAST themed cell in row-major
//     order, which is the (x2,y2) corner, and decorateWalls always dresses a corner — so at
//     smallChance 20 that corner carried the bad id 80% of the time and the whole boardroom slab
//     finalised as CARPET.
//   AND IT BECAME A CORRIDOR. CorpLamps.corridors() is gated on Surf.CARPET, so it hung ceiling
//     panels inside the room and stamped FULL-CELL light pools on those cells — which overlap the
//     room's own POOL_INSET pool additively and spill into the margin it deliberately leaves bare.
//     That is the "two floor textures": both are the one additive glow mesh at GLOW_Y, not floors.
  public static function meeting(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, CARPET_MEETING);
      // 5 AND NOT 6, because the carve moved under it: a room is now floored at SPLIT_MIN on
      // either axis and `meetingTable` only needs `w - 4` and `h - 4` to be at least 1
      if (room.w >= 5 &&
          room.h >= 5)
        meetingTable(state, node, room);
      decorateWalls(state, room, [
          Const.CORP_TABLE_COFFEE,
          Const.CORP_TABLE_PHONE,
          Const.CORP_TABLE_PROJECTOR,
          Const.CORP_TABLE_ROUTER,
        ], [
          Const.CORP_COOLER,
          Const.CORP_PLANT,
          Const.CORP_TRASH,
          Const.CORP_WHITEBOARD,
        ],
        Const.TILE_DARK_TABLE_CARPET_1X1,
        Const.TILE_FLOOR_CARPET_MEETING + UNWALKABLE_TILE_OFFSET,
        50, 20);
    }

  static function meetingTable(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      var full = [
        Const.CORP_TABLE_PHONE,
        Const.CORP_TABLE_PROJECTOR,
      ];
      var deco = full.copy();
      // CAPPED AND CENTRED, `toilet`'s own shape two functions down: a boardroom seats twelve
      // whether the room it is in is 6 x 6 or 12 x 12, and the slack belongs round the table as
      // circulation rather than in it
      var tw = room.w - 4;
      var th = room.h - 4;
      if (tw > TABLE_W_MAX)
        tw = TABLE_W_MAX;
      if (th > TABLE_H_MAX)
        th = TABLE_H_MAX;
      // the LONG axis follows the room's, so a long thin boardroom gets a long thin table
      if ((room.w >= room.h) != (tw >= th))
        {
          var t = tw;
          tw = th;
          th = t;
          if (tw > room.w - 4)
            tw = room.w - 4;
          if (th > room.h - 4)
            th = room.h - 4;
        }
      var tx = room.x1 + Std.int((room.w - tw) / 2);
      var ty = room.y1 + Std.int((room.h - th) / 2);
      GenTree.add(node, CorpBlocks.ZONE_TABLE, tx, ty, tx + tw - 1, ty + th - 1);
      var left = full.length;
      for (dy in 0...th)
        for (dx in 0...tw)
          {
            var tilex = (dx == 0 ? 0 : (dx == tw - 1 ? 2 : 1));
            var tiley = (dy == 0 ? 0 : (dy == th - 1 ? 2 : 1));
            cells[tx + dx][ty + dy] = Const.DARK_TABLE_CARPET_3X3[tiley][tilex];
            if (state.area.chance(20) &&
                left > 0)
              {
                deco = addDecorationExt(state, tx + dx, ty + dy, deco, full);
                left--;
              }
          }
    }

// a staff kitchen and the floor's break room in one: a column of 2x2 tables, or a galley counter
// where the room is too small for them, with the machines people cook with and the ones they stand
// at round the walls
  public static function kitchen(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, WOOD1);
      // and the same 5 the boardroom takes — `kitchenTables` lays 2x2 units at pitch 3 inside the
      // room's own inset, which a 5-cell run still holds one of. A 4-WIDE KITCHEN IS STILL A
      // KITCHEN: it is dealt at minW/minH 4 on purpose (see CorpBlocks), and every 4 x 9 one came
      // out as wall fixtures alone at 21.2% fill, so below the island it takes a counter run
      if (room.w >= 5 &&
          room.h >= 5)
        kitchenTables(state, node, room);
      else
        deskRun(state, node, room, [
            Const.CORP_TABLE_KETTLE,
            Const.CORP_TABLE_MICROWAVE,
            Const.CORP_TABLE_MUG,
            Const.CORP_TABLE_FRUIT,
          ]);
      decorateWalls(state, room, [
          Const.CORP_TABLE_COFFEE,
          Const.CORP_TABLE_CLEANING,
          Const.CORP_TABLE_BLENDER,
          Const.CORP_TABLE_KETTLE,
          Const.CORP_TABLE_MICROWAVE,
          Const.CORP_TABLE_CONTAINER,
          Const.CORP_TABLE_MUG,
          Const.CORP_TABLE_FRUIT,
          Const.CORP_TABLE_TISSUE,
        ], [
          Const.CORP_COOLER,
          Const.CORP_PLANT,
          Const.CORP_TRASH,
          Const.CORP_VENDING,
          Const.CORP_FRIDGE,
          Const.CORP_TAP,
        ],
        Const.TILE_LIGHT_TABLE_WOOD1_1X1,
        Const.TILE_FLOOR_WOOD1 + UNWALKABLE_TILE_OFFSET,
        60, 30);
    }

  static function kitchenTables(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      var tx = room.x1 + Std.int(room.w / 2) - 1;
      var full = [
        Const.CORP_TABLE_TISSUE,
        Const.CORP_TABLE_SAUCES,
        Const.CORP_TABLE_SALT,
        Const.CORP_TABLE_MUG,
        Const.CORP_TABLE_FRUIT,
      ];
      var deco = full.copy();
      var cnt = -1;
      while (true)
        {
          cnt++;
          if (cnt > 100)
            break;
          var ty = cnt * 3 + room.y1 + 2;
          if (ty + 2 >= room.y2)
            break;
          GenTree.add(node, CorpBlocks.ZONE_COUNTER_RUN, tx, ty, tx + 1, ty + 1);
          for (dy in 0...2)
            for (dx in 0...2)
              {
                cells[tx + dx][ty + dy] = Const.LIGHT_TABLE_WOOD1_2X2[dy][dx];
                if (state.area.chance(30))
                  deco = addDecorationExt(state, tx + dx, ty + dy, deco, full);
              }
        }
    }

// open plan: rows of 3x1 desks with a chair under each, printers and boards round the walls
  public static function open(state: _CorpState, node: _GenNode, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, WOOD2);
      var block = Const.CORP_TABLE_3X1;
      var tableW = 3, tableH = 1;
      var effectiveWidth = room.w - 4;
      var cols = Std.int(effectiveWidth / 4);
      if (effectiveWidth == 7)
        cols = 2;
      else if (effectiveWidth == 3)
        cols = 1;
      if (cols < 1)
        cols = 1;
      var xstep = Std.int(effectiveWidth / cols);
      if (effectiveWidth == 7)
        xstep = 4;

      var hasSouthDoor = false;
      for (door in state.doors)
        if (door.roomID1 == room.id ||
            door.roomID2 == room.id)
          {
            if (door.y == room.y2 + 1)
              {
                hasSouthDoor = true;
                break;
              }
          }
      // one chair model and one computer model for the whole floor of desks: a bank of identical
      // workstations is what an office looks like, and rolling each one turns it into a jumble
      var chairID = area.random(Const.CORP_CHAIR[0].amount);
      var computerID = area.random(Const.CORP_COMPUTERS_BLOCK.width);

      var col = 0, ry = 0, cnt = 0;
      while (true)
        {
          cnt++;
          if (cnt > 100)
            break;
          var sx = room.x1 + 2 + (col * xstep);
          if (cols == 1)
            sx = room.x1 + Std.int(room.w / 2) - 1;
          var sy = room.y1 + 1 + (tableH + 1) * ry;
          // A CENTRED SINGLE COLUMN IS ALREADY CLEAR OF BOTH EDGES, so it does not want the
          // walkway margin a multi-column run needs — and with it, `sx + tableW >= room.x2` was
          // true for EVERY row at any width under 7, so the loop spun to its cnt guard and the
          // room came out with no desk at all. 64 of 771 open rooms before the carve was retuned
          // and far more after it, since a capped carve mints many more 6-wide rooms. It is also
          // a BREAK and not a continue: the width does not change between rows
          if (cols == 1
              ? sx + tableW - 1 > room.x2
              : sx + tableW >= room.x2)
            {
              if (cols == 1)
                break;
              ry++;
              col = 0;
              continue;
            }
          col++;
          if (cols == 1)
            ry++;
          if (sy + tableH > room.y2 - (hasSouthDoor ? 1 : 0))
            break;

          GenTree.add(node, CorpBlocks.ZONE_DESK_RUN, sx, sy, sx + tableW - 1, sy);
          var full = [
            Const.CORP_TABLE_MISC,
            Const.CORP_TABLE_LAMP,
            Const.CORP_TABLE_PLANTS,
            Const.CORP_TABLE_PHONE,
            Const.CORP_TABLE_FILES,
            Const.CORP_TABLE_STATIONERY,
          ];
          var deco = full.copy();
          for (i in 0...block.length)
            {
              cells[sx + i][sy] = block[i];
              if (i == 1)
                area.addDecoration(sx + i, sy, Const.CORP_COMPUTERS_BLOCK.row,
                  Const.CORP_COMPUTERS_BLOCK.col + computerID);
              else if (area.chance(50))
                deco = addDecorationExt(state, sx + i, sy, deco, full);
            }
          area.addDecoration(sx + 1, sy + 1, Const.CORP_CHAIR[0].row, chairID);
        }
      decorateWorkWalls(state, room);
    }

// a cubicle farm: blocks of pods, with a passage between every block.
//
// A BLOCK IS `bw` PODS WIDE AND TWO DEEP — two rows of desks BACK TO BACK, a passage column each
// side of the block and an aisle row each side of the band, so every worker gets a bay of his own.
// NO PANEL COSTS A CELL: render.corp.CorpFurniture stands one on every boundary between two
// adjacent cubicle desk cells, which walls three sides of each desk and leaves open exactly the
// hand the chair is on.
//
// THE SPINE USED TO OWN A ROW OF ITS OWN, and that is what the band was four rows deep for. A
// panel a tenth of a unit thick standing in the middle of a 4-unit cell touches neither desk, and
// the cell it spent was a whole tile of floor for 2.5% of a tile of geometry. The two desk rows
// are adjacent now, the panel is emitted on the boundary they share, and a band is three rows:
// desk, desk, aisle.
//
// AND THE TWO WALL COLUMNS ARE PODS. `decorateCubicleWalls` reserved x1 and x2 for a cabinet run,
// and `decorateWalls` forces a dressing at every CORNER whatever the roll says — four unwalkable
// cells a room, which is what "all corners are unwalkable, but they're empty" was looking at. The
// farm's furniture is its desks; what dresses it now is what is pinned to the panels.
//
// WHICH WAY THE BANDS RUN IS NOT THE ROOM'S OWN AXES. A band is three lines deep and only whole
// bands are laid, so a room whose short axis leaves two lines over stands a large empty slab in
// it — an 8 x 9 farm took two bands, 28 desks, and wasted rows 13 and 14 entirely. Turned a
// quarter turn the same room takes two bands of four blocks: 32 desks, one spare COLUMN. Both ways
// are costed by seats and the better one is laid, which is what `vert` threads through `cx`/`cy`.
// Nothing downstream is told — render.corp.CorpFurniture.podBack reads the back hand off the PAIR
  public static function cubicle(state: _CorpState, node: _GenNode, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, CUBICLE);
      var chairID = area.random(Const.CORP_CHAIR[0].amount);
      var computerID = area.random(Const.CORP_COMPUTERS_BLOCK.width);

      // the WHOLE interior, wall columns included — nothing dresses them any more. `along` runs
      // down the blocks and their passages, `across` down the bands
      var vert = (seats(room.h, room.w) > seats(room.w, room.h));
      var along = (vert ? room.h : room.w);
      var across = (vert ? room.w : room.h);
      var widths = podBlocks(along);
      var bands = Std.int((across - 1) / POD_BAND_H);
      if (widths.length < 1 ||
          bands < 1)
        return;
      var off = Std.int((along - span(widths)) / 2);
      // the spare line after every block but the last — the passages, and the only cells in a farm
      // that are neither desk nor aisle. `cubicleFittings` stands the room's two machines at their
      // two ends
      var gaps = [];
      var at = off;
      for (b in 0...widths.length - 1)
        {
          at += widths[b];
          gaps.push(at);
          at++;
        }

      for (band in 0...bands)
        {
          // the band's two desk lines, with the aisle its first line faces one line back
          var a0 = 1 + band * POD_BAND_H;
          at = off;
          for (b in 0...widths.length)
            {
              var bw = widths[b];
              GenTree.add(node, CorpBlocks.ZONE_POD_ROW,
                cx(room, vert, at, a0), cy(room, vert, at, a0),
                cx(room, vert, at + bw - 1, a0 + 1), cy(room, vert, at + bw - 1, a0 + 1));
              for (i in 0...bw)
                pods(state, room, vert, at + i, a0, computerID, chairID);
              at += bw + 1;
            }
        }
      cubicleFittings(state, room,
        [for (g in gaps) for (e in [0, across - 1])
          {
            x: cx(room, vert, g, e),
            y: cy(room, vert, g, e),
          }]);
    }

// how many desks a farm seats with its blocks running one way: two lines per band, and a band is
// desk, desk, aisle with the band before it supplying the first line's aisle
  static function seats(along: Int, across: Int): Int
    {
      var n = 0;
      for (w in podBlocks(along))
        n += w;
      return 2 * Std.int((across - 1) / POD_BAND_H) * n;
    }

// the world cell of a point on the farm's OWN two axes
  static inline function cx(room: _Room, vert: Bool, along: Int, across: Int): Int
    {
      return room.x1 + (vert ? across : along);
    }

  static inline function cy(room: _Room, vert: Bool, along: Int, across: Int): Int
    {
      return room.y1 + (vert ? along : across);
    }

// HOW THE ROOM'S LINES SPLIT INTO POD BLOCKS, one spare line between each two.
//
// a fixed width and a floor division left whatever did not divide as DEAD FLOOR — a 10-column farm
// took two blocks of three and a passage, covered nine columns of ten and stood a bare strip down
// one side of the room, reported as "one empty column, why?". Both widths are tried and the one
// that COVERS MORE wins, then whatever is still spare is spent widening blocks from the left. A
// narrower block is not a worse farm; an empty column is
  static function podBlocks(inner: Int): Array<Int>
    {
      var best = [];
      for (w in [POD_BLOCK_W, POD_BLOCK_MIN])
        {
          var n = Std.int((inner + 1) / (w + 1));
          if (n < 1)
            continue;
          // one column of the remainder goes to each of the first `spare` blocks; past that there
          // is no room for another passage and the rest genuinely cannot be filled
          var spare = inner + 1 - n * (w + 1);
          var out = [for (i in 0...n) w + (i < spare ? 1 : 0)];
          if (span(out) > span(best))
            best = out;
        }
      return best;
    }

// how many lines a list of block widths covers, passages included
  static inline function span(widths: Array<Int>): Int
    {
      var n = -1;
      for (w in widths)
        n += w + 1;
      return n;
    }

// THE FARM'S TWO MACHINES. a cubicle farm is pods and aisles wall to wall — `decorateCubicleWalls`
// was taken out when the wall columns became pods — so the only cell a standing fitting can have
// masonry behind it is the HEAD of a passage column, against the room's top wall. Which is where
// an office really puts them: off the walkway and out of every bay.
//
// AND THE CELL STAYS WALKABLE, which every other wall dressing in this file does not. The
// unwalkable twin `decorateWalls` writes is what usually says "something stands here", and on this
// cell it SEALS A POCKET: the top aisle row is the only thing joining the two halves of the farm's
// first band, so one blocked cell in the middle of it left the cells either side unreachable and
// CorpConnect.openPockets ate a column of desks to get back in. Measured on two farms — band 2
// came out [2,2] exactly and band 1 lost its inner pods. render.corp.CorpProps.standing needs the
// decoration, masonry on a hand and a cell that is neither worktop nor fitting; it does not need
// the twin, so the glb stands and nothing is sealed
  static function cubicleFittings(state: _CorpState, room: _Room, heads: Array<{ x:Int, y:Int }>)
    {
      var cells = state.area.getCells();
      // THE PASSAGE ENDS FIRST and then anywhere else on the room's own perimeter ring. A farm's
      // first line is not always the tower's own masonry — half of them face the perimeter
      // GLAZING, which FacilityModel.isSolidWall rejects on purpose (a window's sill is where a
      // worktop would be) — and a room whose far end is a doorway has none there either, so a
      // single candidate cell put the machines in about one farm in four
      var spots = [];
      for (p in heads)
        spot(spots, state, cells, p.x, p.y);
      for (x in room.x1...room.x2 + 1)
        for (y in [room.y1, room.y2])
          spot(spots, state, cells, x, y);
      for (y in room.y1 + 1...room.y2)
        for (x in [room.x1, room.x2])
          spot(spots, state, cells, x, y);
      if (spots.length == 0)
        return;
      var deco = [Const.CORP_COOLER, Const.CORP_TABLE_PRINTER];
      var first = state.area.random(deco.length);
      var n = (spots.length < deco.length ? spots.length : deco.length);
      for (i in 0...n)
        {
          // the two ENDS of what the room offered, so the machines are not stood side by side:
          // the list runs passage ends first, so the pair comes out one at a passage and one in
          // the far corner
          var s = spots[n < 2 ? 0 : Std.int(i * (spots.length - 1) / (n - 1))];
          addDecoration(state, s.x, s.y, deco[(first + i) % deco.length]);
        }
    }

// one candidate cell onto the list, if it is free and not already on it
  static function spot(spots: Array<{ x:Int, y:Int }>, state: _CorpState,
      cells: Array<Array<Int>>, x: Int, y: Int): Void
    {
      if (!bare(state, cells, x, y))
        return;
      for (p in spots)
        if (p.x == x &&
            p.y == y)
          return;
      spots.push({
        x: x,
        y: y,
      });
    }

// may a standing fitting go on this cell? bare farm floor, masonry on a hand, clear of a doorway
// and of whatever is already there — a pod's chair sits in the aisle line the pod faces
  static function bare(state: _CorpState, cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      return cells[x][y] == CUBICLE &&
        atWall(cells, x, y) &&
        !atDoor(cells, x, y) &&
        !state.area.hasObjectAt(x, y);
    }

// is there MASONRY on one of this cell's four hands? not a window and not a corridor: the render
// side stands a fitting off a solid wall slab (render.corp.CorpDeco.backHandOf), so a cell with a
// glazed flank or an open one would take the decoration and then draw nothing at all
  static function atWall(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      for (i in 0...Const.dir4x.length)
        {
          var t = cells[x + Const.dir4x[i]][y + Const.dir4y[i]];
          if (t == BLDG_WALL ||
              t == BLDG_INNER_WALL)
            return true;
        }
      return false;
    }

// does every bare archive floor cell of this room still join a doorway? a flood over the room's own
// floor id from the cells a door opens onto, which is all a ring table can cut
  static function reachable(cells: Array<Array<Int>>, room: _Room): Bool
    {
      var total = 0;
      var stack = [];
      var seen = new Map<Int, Bool>();
      for (x in room.x1...room.x2 + 1)
        for (y in room.y1...room.y2 + 1)
          {
            if (cells[x][y] != ARCHIVE)
              continue;
            total++;
            if (atDoor(cells, x, y))
              {
                stack.push({ x: x, y: y });
                seen.set(x * 1000 + y, true);
              }
          }
      var n = 0;
      while (stack.length > 0)
        {
          var c = stack.pop();
          n++;
          for (i in 0...Const.dir4x.length)
            {
              var nx = c.x + Const.dir4x[i];
              var ny = c.y + Const.dir4y[i];
              if (nx < room.x1 ||
                  nx > room.x2 ||
                  ny < room.y1 ||
                  ny > room.y2 ||
                  cells[nx][ny] != ARCHIVE ||
                  seen.exists(nx * 1000 + ny))
                continue;
              seen.set(nx * 1000 + ny, true);
              stack.push({ x: nx, y: ny });
            }
        }
      return n == total;
    }

// is a table tile on one of this cell's four hands?
  static function besideTable(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      for (i in 0...Const.dir4x.length)
        if (cells[x + Const.dir4x[i]][y + Const.dir4y[i]] == Const.TILE_DARK_TABLE_WOOD2_1X1)
          return true;
      return false;
    }

// is the cell a doorway opens onto (see `atDoor`) on one of this cell's four hands? a table there
// stands in the way of whoever walks in, and its bench glb crowds the door leaf
  static function besideDoor(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      for (i in 0...Const.dir4x.length)
        if (atDoor(cells, x + Const.dir4x[i], y + Const.dir4y[i]))
          return true;
      return false;
    }

// is a rank cell on one of this cell's four hands?
  static function besideRank(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      for (i in 0...Const.dir4x.length)
        if (rank(cells[x + Const.dir4x[i]][y + Const.dir4y[i]]))
          return true;
      return false;
    }

// is this an archive rank cell, racking or full-height shelving?
  static inline function rank(t: Int): Bool
    {
      return t == Const.TILE_FLOOR_ARCHIVE + UNWALKABLE_TILE_OFFSET ||
        t == ARCHIVE_HIGH;
    }

// is this cell one of the list's?
  static function dealt(list: Array<{ x:Int, y:Int }>, x: Int, y: Int): Bool
    {
      for (c in list)
        if (c.x == x &&
            c.y == y)
          return true;
      return false;
    }

// would a bin here stand within two cells of a bin or a copier already dealt? one cell apart still
// read as a row of bins along the wall
  static function crowded(bins: Array<{ x:Int, y:Int }>, copiers: Array<{ x:Int, y:Int }>,
      x: Int, y: Int): Bool
    {
      for (c in bins.concat(copiers))
        if (Math.abs(c.x - x) + Math.abs(c.y - y) <= 2)
          return true;
      return false;
    }

// is this cell one of the room's four corners?
  static inline function corner(room: _Room, x: Int, y: Int): Bool
    {
      return (x == room.x1 || x == room.x2) &&
        (y == room.y1 || y == room.y2);
    }

// is there a WALL of any kind on one of this cell's four hands -- masonry or glazing? what a bin
// needs (render.corp.CorpDeco.bins stands it against either, and a cell with neither leaves it in
// the middle of the tile), and what an archive's wall cabinet is dealt on — see `archive`
  static function walled(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      for (i in 0...Const.dir4x.length)
        {
          var t = cells[x + Const.dir4x[i]][y + Const.dir4y[i]];
          if (t == BLDG_WALL ||
              t == BLDG_INNER_WALL ||
              (t >= BLDG_WINDOW && t <= BLDG_WINDOWV3) ||
              (t >= INNER_WINDOW && t <= INNER_WINDOWV3))
            return true;
        }
      return false;
    }

// ONE PAIR OF PODS, back to back: two desk cells, their workstations, and a chair each in the
// aisle it faces.
//
// SKIPPED BESIDE A DOORWAY, which it never had to be while the wall columns were reserved: a pod
// run reaches x1 and x2 now, so a door in a side wall can open straight onto a desk and seal the
// room. `CorpConnect.openPockets` would carve it back out, but a repair is not a placement rule.
//
// AND THE PAIR IS THE UNIT — BOTH OR NEITHER. Skipping one of the two left its partner standing
// with its back open to the aisle instead of against another worker: three panels and a monitor
// facing a gap, reported from the game as a half-done cubicle beside a door. The panel emitter
// says the same thing, since render.corp.CorpFurniture raises a back only where two pods meet
  static function pods(state: _CorpState, room: _Room, vert: Bool, at: Int, a0: Int,
      computerID: Int, chairID: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      var px = [cx(room, vert, at, a0), cx(room, vert, at, a0 + 1)];
      var py = [cy(room, vert, at, a0), cy(room, vert, at, a0 + 1)];
      if (atDoor(cells, px[0], py[0]) ||
          atDoor(cells, px[1], py[1]))
        return;
      // each one's chair, one line back for the first of the pair and one line on for the second
      var sx = [cx(room, vert, at, a0 - 1), cx(room, vert, at, a0 + 2)];
      var sy = [cy(room, vert, at, a0 - 1), cy(room, vert, at, a0 + 2)];
      for (i in 0...2)
        {
          // THE MIDDLE ID OF THE 3x1 RUN, because a pod is one cell and the run's two ends are its
          // carcass sides. render.corp.CorpFurniture stands a `corp/desk-bench` module per cell and
          // asks the SURFACE, not the column, so any table id of the family draws the same desk
          cells[px[i]][py[i]] = Const.CORP_TABLE_3X1[1];
          area.addDecoration(px[i], py[i], Const.CORP_COMPUTERS_BLOCK.row,
            Const.CORP_COMPUTERS_BLOCK.col + computerID);
          area.addDecoration(sx[i], sy[i], Const.CORP_CHAIR[0].row, chairID);
        }
    }

// a server room: rows of racks with an aisle between them, and nothing soft in it
// RANKS OF CABINETS across a room, one row every `pitch`, never touching the boundary ring and
// always with one DEALT gap in each row — see the gap note inside. shared by the server room, the
// archive and the security room, which are the same rank with three different cabinet frames
  static function rackRows(state: _CorpState, node: _GenNode, room: _Room, tile: Int,
      deco: _TileGroup, chance: Int, maxRows: Int, pitch: Int, clearDoors: Bool = false)
    {
      var area = state.area;
      var cells = area.getCells();
      var row = 0;
      while (true)
        {
          row++;
          if (row > maxRows)
            break;
          var ry = room.y1 + 1 + (row - 1) * pitch;
          if (ry > room.y2 - 1)
            break;
          GenTree.add(node, CorpBlocks.ZONE_RACK_ROW, room.x1 + 1, ry, room.x2 - 1, ry);
          // ONE GAP IS DEALT AND THE REST ARE ROLLED. The row spans the whole interior width and
          // the roll was the only thing that ever broke it — at 5 wide that is three cells, so
          // one row in two came out solid and sealed the floor behind it off. The dealt gap is
          // placed off the row index so consecutive ranks stagger rather than line up
          var span = room.x2 - room.x1 - 1;
          var gap = (span < 1 ? 0 : room.x1 + 1 + (row * 2 + 1) % span);
          // AND A ROW THAT ROLLS ITSELF EMPTY IS NOT A ROW. The gap is dealt so a rank can never
          // seal the floor; this is the same rule from the other end, because nothing stops the
          // `chance` roll taking every survivor. At the dealt minimum of 4 on both axes there is
          // exactly ONE rank and it has two or three eligible cells, so at `chance` 25 a 6x4 room
          // comes out bare 1.6% of the time and a 7x4 one 0.4% — measured as 3 archives in 600
          // seeds holding nothing at all (gen.GenCheck.archiveSane, which is what found it).
          //
          // `first` is the fallback and it is DETERMINISTIC: the row's leftmost eligible cell, so
          // the same seed still builds the same floor
          var first = -1;
          var laid = 0;
          for (x in room.x1 + 1...room.x2)
            {
              if (x == gap)
                continue;
              // A DOORWAY MAY NOT OPEN FLAT INTO A RANK, for `clearDoors`. The row spans the
              // INTERIOR (x1+1 .. x2-1) so it can never overwrite a door cell itself — but a door
              // in a side wall opens onto (x1, ry), and the cell beyond that is this rank's end.
              // `CorpConnect.openPockets` would carve it back out and a repair is not a placement
              // rule, which is the note `pods` carries one template over
              if (clearDoors &&
                  atDoor(cells, x, ry))
                continue;
              if (first < 0)
                first = x;
              if (area.chance(chance))
                continue;
              cells[x][ry] = tile;
              addDecoration(state, x, ry, deco);
              laid++;
            }
          if (laid == 0 &&
              first >= 0)
            {
              cells[first][ry] = tile;
              addDecoration(state, first, ry, deco);
            }
        }
    }

  public static function servers(state: _CorpState, node: _GenNode, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, SERVER);
      // rack rows run across the room's SHORT axis and are reached from the aisle beside them,
      // so a row is never more than one step from walkable floor
      rackRows(state, node, room, Const.TILE_FLOOR_SERVER + UNWALKABLE_TILE_OFFSET,
        Const.CORP_MACHINERY, 20, RACK_ROWS_MAX, RACK_PITCH);

      // one router bench and a bin by the door
      decorateWalls(state, room, [
          Const.CORP_TABLE_ROUTER,
          Const.CORP_TABLE_MISC_LARGE,
        ], [
          Const.CORP_MACHINERY,
          Const.CORP_TRASH,
        ],
        Const.TILE_DARK_TABLE_WOOD2_1X1,
        Const.TILE_FLOOR_SERVER + UNWALKABLE_TILE_OFFSET,
        30, 30);
    }

// a washroom: a basin run down one wall and a row of stalls down the other
  public static function toilet(state: _CorpState, node: _GenNode, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, MARBLE2);
      var fixture = Const.TILE_FLOOR_MARBLE2 + UNWALKABLE_TILE_OFFSET;

      // the basins are a continuous counter along the top wall, BASIN_MAX of them, centred
      var bn = (room.w < BASIN_MAX ? room.w : BASIN_MAX);
      var bx = room.x1 + Std.int((room.w - bn) / 2);
      GenTree.add(node, CorpBlocks.ZONE_BASIN_RUN, bx, room.y1, bx + bn - 1, room.y1);
      for (x in bx...bx + bn)
        {
          if (cells[x][room.y1 - 1] == BLDG_INNER_DOOR)
            continue;
          cells[x][room.y1] = fixture;
          addDecoration(state, x, room.y1, Const.CORP_TAP);
        }

      // and the stalls are separate cells along the bottom one, every other cell so each has its
      // own doorway
      // STALL_MAX of them, and the span they need is every other cell — so 3 stalls want 5 cells
      var sn = STALL_MAX;
      while (sn > 1 && 2 * sn - 1 > room.w)
        sn--;
      var sx = room.x1 + Std.int((room.w - (2 * sn - 1)) / 2);
      GenTree.add(node, CorpBlocks.ZONE_STALL_RUN, sx, room.y2, sx + 2 * sn - 2, room.y2);
      var x = sx;
      while (x <= sx + 2 * sn - 2)
        {
          if (cells[x][room.y2 + 1] != BLDG_INNER_DOOR)
            {
              cells[x][room.y2] = fixture;
              addDecoration(state, x, room.y2, Const.CORP_TABLE_TOILET_PAPER);
            }
          x += 2;
        }

      // a bin and a paper dispenser on the end walls
      decorateCorners(state, room, [
          Const.CORP_TABLE_TISSUE,
          Const.CORP_TABLE_CLEANING,
        ], [
          Const.CORP_TRASH,
          Const.CORP_PLANT,
        ],
        Const.TILE_DARK_TABLE_MARBLE1_1X1,
        fixture,
        40);
    }

// --- the kinds the floor was missing.
//
// THE FLOOR CARVES 29 ROOMS AND THE QUOTA ONLY EVER NAMED TEN OF THEM, so 19 rooms a floor came
// out as the open-plan FILLER: one template, one floor, and a median 16% of its cells furnished.
// Each of these borrows an EXISTING floor surface (render.corp.CorpModel.surfOf knows eight and
// there are no more), so a new kind costs no tile id, no texture, no material and no draw call —
// what makes it a different room is its furniture list and its fixture, which is what a reader in
// the room actually sees. NOT plain CARPET, ever: that surface is what CorpLamps.corridors() reads
// as circulation, and a room wearing it gets ceiling panels hung inside it (see `meeting`)

// one desk run across the middle of a room, with a chair in front of it and `full`'s decorations
// on it. the small office's own desk, generalised: a security room's monitor bench and a galley
// kitchen's counter are the same object with a different list of things standing on it
  static function deskRun(state: _CorpState, node: _GenNode, room: _Room,
      full: Array<_TileGroup>)
    {
      var area = state.area;
      var cells = area.getCells();
      var block = Const.CORP_TABLE_3X1;
      // A DESK THAT SPANS THE ROOM IS A WALL. The run was always three cells, and an office is
      // dealt at minW 3 — so in a 3-wide room `tx` came out at x1 and the desk crossed the room's
      // whole midline, cutting the floor into two strips with no way between them. Reported from
      // 50,31: a 5x3 office whose interior came back
      //     # . . . #
      //     . # # # .
      //     # . . . #
      // three disconnected pieces, the door opening onto one of them. Two cells of clearance is
      // the rule and one of them is a lane: at w 5 the run is 3 and both ends stay open, at w 3 it
      // is a single pedestal
      var n = block.length;
      if (n > room.w - 2)
        n = room.w - 2;
      if (n < 1)
        return;
      var tx = room.x1 + Std.int((room.w - n) / 2);
      var ty = room.y1 + Std.int((room.h - 1) / 2);
      for (dx in 0...n)
        if (atDoor(cells, tx + dx, ty))
          return;
      GenTree.add(node, CorpBlocks.ZONE_DESK_RUN, tx, ty, tx + n - 1, ty);
      var deco = full.copy();
      for (dx in 0...n)
        {
          cells[tx + dx][ty] = block[n == 1 ? 1 : dx];
          if (dx == n - 1)
            addDecoration(state, tx + dx, ty, Const.CORP_COMPUTERS);
          else if (area.chance(50))
            deco = addDecorationExt(state, tx + dx, ty, deco, full);
        }
      area.addDecoration(tx + Std.int(n / 2), ty + 1, Const.CORP_CHAIR[0].row,
        area.random(Const.CORP_CHAIR[0].amount));
    }

// an archive: the server room's rank-and-aisle with PAPER in it instead of machines, which is what
// it always said it was and, until this floor id existed, never once drew.
//
// IT USED TO BE A SERVER ROOM AND NOT BY RESEMBLANCE -- IDENTICALLY. It laid TILE_FLOOR_SERVER's own
// unwalkable twin, and render.corp.CorpModel.fitOf reads that twin as FIT_RACK, so every rank in
// here built a steel server cabinet with a blinking LED field and a cable drape over its lid. Its
// own CORP_CABINET decorations drew NOTHING, because render.corp.CorpDeco.casework skips any cell
// that already carries a fitting. Two rooms, one id, one look. So the archive has a floor id of its
// own now (Const.TILE_FLOOR_ARCHIVE) -- concrete to look at and Surf.SERVER to the shell, so it
// costs no texture and no draw call, and the whole of what it buys is a twin that means SHELVING.
  public static function archive(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, ARCHIVE);
      var shelf = Const.TILE_FLOOR_ARCHIVE + UNWALKABLE_TILE_OFFSET;
      // PACKED, reported as "should be WAY more packed": a RING of casework on every wall and SOLID
      // ranks inside it.
      //
      // THE RING STAYS WALKABLE. A wall cabinet is 1.2 deep in a 4.0 cell, and writing the twin
      // under it sealed almost every wall-adjacent tile for nothing -- and then cost the ranks the
      // aisle they needed to keep the ring reachable, so a 5x7 room held one column of shelving.
      // The cabinet is the decoration alone: render.corp.CorpModel.archiveWalls reads it as
      // FIT_ARCHIVE and render.corp.CorpFurniture.archives backs it onto the masonry. The ring is
      // the room's one loop of floor, so the ranks fill everything inside it.
      //
      // AGAINST MASONRY ONLY, since a cabinet stood against the glazing blocks the window -- which
      // got reported -- and that test is the RENDER's, not this one: CorpModel.runsOfThree and
      // loneWindows demote short runs of glass to masonry after generation, so a masonry test here
      // left bare a wall that draws as masonry. So every ring cell with a wall of any kind on a
      // hand is dealt one, and archiveWalls keeps the ones that end up backed by masonry (a corp
      // decoration never draws its sprite, so the rest are nothing). A doorway's cell stays bare.
      //
      // the ranks FIRST, every COLUMN RACK_PITCH apart from the ring inward -- they run down the
      // room's y axis, asked for as reading better that way. Solid, one cross aisle once a rank is
      // long enough to want one, placed mid-rank so the two sections come out even
      //
      // SPLIT IN TWO SECTIONS by column, the first half one family and the rest the other, which
      // way round on a roll. The ARCH-SHELF half goes on ARCHIVE_HIGH (Const.TILE_ARCHIVE_HIGH),
      // which BLOCKS LINE OF SIGHT — asked for as "high archive shelves should break los": 4.8
      // (2.4 m) of shelving is a wall to anyone standing beside it, where the racking is 2.6 of
      // open steel and stays on the see-through twin. render.corp.CorpFurniture.rankFamily reads
      // it back
      var cols = [];
      var cx = room.x1 + 1;
      while (cx <= room.x2 - 1 &&
          cols.length < RACK_ROWS_MAX)
        {
          cols.push(cx);
          cx += RACK_PITCH;
        }
      var flip = (state.area.random(2) == 0);
      var span = room.y2 - room.y1 - 1;
      var gap = (span >= ARCHIVE_GAP_SPAN ? room.y1 + 1 + Std.int(span / 2) : -1);
      for (i in 0...cols.length)
        {
          var rx = cols[i];
          var id = ((i < Math.ceil(cols.length / 2)) != flip ? shelf : ARCHIVE_HIGH);
          GenTree.add(node, CorpBlocks.ZONE_RACK_ROW, rx, room.y1 + 1, rx, room.y2 - 1);
          for (y in room.y1 + 1...room.y2)
            {
              if (y == gap)
                continue;
              cells[rx][y] = id;
              addDecoration(state, rx, y, Const.CORP_CABINET);
            }
        }
      var ring = [];
      for (x in room.x1...room.x2 + 1)
        for (y in room.y1...room.y2 + 1)
          if ((x == room.x1 ||
              x == room.x2 ||
              y == room.y1 ||
              y == room.y2) &&
              !atDoor(cells, x, y))
            ring.push({ x: x, y: y });
      // ONE OR TWO COPIERS, which is all the copy room it replaced ever had to say: on a ring cell
      // with masonry behind it, since render.corp.CorpProps stands the printer glb off a solid wall
      // and on bare floor only (a copier dealt onto a worktop drew nothing, which is how the copy
      // room came to hold none at all). NOT against a rank's end, which is a bin slot and leaves the
      // copier jammed behind the racking
      var masonry = [for (c in ring)
        if (atWall(cells, c.x, c.y) &&
            !besideRank(cells, c.x, c.y)) c];
      var copiers = [];
      for (i in 0...1 + state.area.random(2))
        {
          if (masonry.length == 0)
            break;
          var c = masonry[state.area.random(masonry.length)];
          masonry.remove(c);
          copiers.push(c);
        }
      // THE BINS, SPACED: each is skipped if it would stand within two cells of a bin or a copier
      // already dealt. Four rules dealing independently put four bins in a seven-cell row —
      // reported. So:
      //   - one or two in the BIN SLOTS, the cell just SOUTH of a rank section (the cross aisle,
      //     or the ring cell under the rank's last one) — CorpDeco.bins stands a bin with a rank
      //     to its north against that rank's end;
      //   - one in a walled corner on a roll.
      // The copier's own bin is NOT dealt here: it stands in the copier's cell, and a cell holds
      // one object (gen.GenCtx.addDecoration refuses a second), so render.corp.CorpDeco.bins
      // stands it as dressing — see there
      var bins = [];
      var slots = [];
      for (x in room.x1 + 1...room.x2)
        for (y in room.y1 + 2...room.y2 + 1)
          if (rank(cells[x][y - 1]) &&
              !rank(cells[x][y]) &&
              !atDoor(cells, x, y) &&
              !crowded(bins, copiers, x, y))
            slots.push({ x: x, y: y });
      for (i in 0...1 + state.area.random(2))
        {
          if (slots.length == 0)
            break;
          var c = slots[state.area.random(slots.length)];
          slots.remove(c);
          if (!crowded(bins, copiers, c.x, c.y))
            bins.push(c);
        }
      for (c in ring)
        if (corner(room, c.x, c.y) &&
            walled(cells, c.x, c.y) &&
            copiers.indexOf(c) < 0 &&
            !crowded(bins, copiers, c.x, c.y) &&
            state.area.chance(ARCHIVE_CORNER_BIN))
          bins.push(c);
      for (c in bins)
        addDecoration(state, c.x, c.y, Const.CORP_TRASH);
      for (c in ring)
        {
          if (copiers.indexOf(c) >= 0)
            {
              addDecoration(state, c.x, c.y, Const.CORP_TABLE_PRINTER);
              continue;
            }
          if (dealt(bins, c.x, c.y))
            continue;
          if (atWall(cells, c.x, c.y))
            {
              if (!state.area.chance(ARCHIVE_RING_BARE))
                addDecoration(state, c.x, c.y, Const.CORP_CABINET);
            }
          // AND A TABLE UNDER THE GLAZING, where a cabinet may not stand: a sorting bench with
          // the stationery on it. A table tile BLOCKS, unlike everything else on this ring, so it
          // is only kept if the room's floor still reaches every doorway without that cell.
          //
          // NEVER BESIDE A DOORWAY'S CELL, where it blocks the way in -- reported at 22,14.
          //
          // AND NEVER BESIDE ANOTHER ONE. A lone table cell draws the `corp/desk-bench` glb; two
          // that touch are a RUN, which render.corp.CorpFurniture.worktop emits as a slab of
          // quads — asked for as "let's not spawn quad tables there"
          else if (walled(cells, c.x, c.y))
            {
              if (!besideTable(cells, c.x, c.y) &&
                  !besideDoor(cells, c.x, c.y) &&
                  state.area.chance(ARCHIVE_TABLE))
                {
                  cells[c.x][c.y] = Const.TILE_DARK_TABLE_WOOD2_1X1;
                  if (reachable(cells, room))
                    {
                      addDecoration(state, c.x, c.y, (state.area.random(2) == 0 ?
                        Const.CORP_TABLE_STATIONERY : Const.CORP_TABLE_MISC_LARGE));
                      continue;
                    }
                  cells[c.x][c.y] = ARCHIVE;
                }
              // and a cabinet where no table went: glass HERE is often masonry by the time the
              // model is built (CorpModel.runsOfThree / loneWindows demote short runs), and
              // CorpModel.archiveWalls keeps a cabinet only where it ends up backed by masonry —
              // a cell left bare was a stretch of solid wall with nothing on it
              if (!state.area.chance(ARCHIVE_RING_BARE))
                addDecoration(state, c.x, c.y, Const.CORP_CABINET);
            }
        }
    }

// a reception: the executive's marble and the same 3x2 slab, standing as a counter, with seating
// and greenery round the walls
// THE RECEPTION'S COUNTER IS ITS FRONT WALL, and it runs along the hand nearer the lift.
//
// It used to borrow `execDesk`, which stands a 3 x 2 slab in the MIDDLE of the room — a reception
// with an island in it, and the highest furniture-pocket rate on the floor (75.4% of its rooms held
// floor the lift flood could not reach, because the slab and the wall dressings between them cut
// the rect in half). A counter is one cell deep, it stands against the wall the visitor walks
// toward, and the floor in front of it stays one piece.
//
// IT IS LAID ON THE EDGE ROW ITSELF, not one cell in. One cell in leaves a back strip whose only
// ways out are the two corners, and `decorateWalls` dresses a corner unconditionally — that strip
// is a sealed pocket in every seed where it fits. On the row itself there is no strip.
//
// AND IT IS ALWAYS HORIZONTAL. `decorateWalls` dresses columns x1 and x2 and nothing else, so a
// run held to x1+1 .. x2-1 can never be overwritten by the dressing that follows it; a vertical
// counter would be. ponytail: the lift is then only followed on one axis, which for a room capped
// at 6 x 6 is a cell or two of difference
  static function counter(state: _CorpState, node: _GenNode, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      var line = (gen.blocks.CorpBlocks.liftY < (room.y1 + room.y2) / 2 ? room.y1 : room.y2);
      var lo = room.x1 + 1;
      var hi = room.x2 - 1;
      if (hi < lo)
        return;
      GenTree.add(node, CorpBlocks.ZONE_COUNTER_RUN, lo, line, hi, line);
      var full = [
        Const.CORP_COMPUTERS,
        Const.CORP_TABLE_PHONE,
        Const.CORP_TABLE_FILES,
      ];
      var deco = full.copy();
      var n = 0;
      for (x in lo...hi + 1)
        {
          if (atDoor(cells, x, line))
            continue;
          cells[x][line] = Const.TILE_DARK_TABLE_MARBLE1_1X1;
          deco = addDecorationExt(state, x, line, deco, full);
          n++;
        }
      // and the receptionist's chair, in front of the middle of whatever run was actually laid
      if (n > 0)
        area.addDecoration(Std.int((lo + hi) / 2), line + (line == room.y1 ? 1 : -1),
          Const.CORP_CHAIR[0].row, area.random(Const.CORP_CHAIR[0].amount));
    }

  public static function reception(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, RECEPTION);
      counter(state, node, room);

      decorateWalls(state, room, [
          Const.CORP_TABLE_PHONE,
          Const.CORP_TABLE_MISC,
          Const.CORP_TABLE_PLANTS,
        ], [
          Const.CORP_PLANT,
          Const.CORP_COOLER,
          Const.CORP_WHITEBOARD,
        ],
        Const.TILE_DARK_TABLE_MARBLE1_1X1,
        Const.TILE_FLOOR_RECEPTION + UNWALKABLE_TILE_OFFSET,
        40, 40);
    }

// a security post: the server room's floor, a bank of monitors on one wall and the machines that
// feed them on the other
  public static function security(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, SERVER);
      // THE MONITOR BENCH AND A RANK OF GEAR, because a control room with nothing in the middle
      // of it is a cupboard. Measured before this: 19.9% of the rect furnished, and every one of
      // those cells was a wall dressing — `decorateWalls` was the entire body of this template
      deskRun(state, node, room, [
          Const.CORP_COMPUTERS,
          Const.CORP_TABLE_ROUTER,
          Const.CORP_TABLE_MISC_LARGE,
        ]);
      rackRows(state, node, room, Const.TILE_FLOOR_SERVER + UNWALKABLE_TILE_OFFSET,
        Const.CORP_MACHINERY, 25, 2, 3);
      decorateWalls(state, room, [
          Const.CORP_COMPUTERS,
          Const.CORP_TABLE_ROUTER,
          Const.CORP_TABLE_MISC_LARGE,
        ], [
          Const.CORP_MACHINERY,
          Const.CORP_CABINET,
          Const.CORP_TRASH,
        ],
        Const.TILE_DARK_TABLE_WOOD2_1X1,
        Const.TILE_FLOOR_SERVER + UNWALKABLE_TILE_OFFSET,
        60, 50);
    }

// open plan's own wall furniture, which is a longer list than any other room's
  static function decorateWorkWalls(state: _CorpState, room: _Room)
    {
      decorateWalls(state, room, [
          Const.CORP_TABLE_COFFEE,
          Const.CORP_TABLE_PRINTER,
          Const.CORP_TABLE_PROJECTOR,
          Const.CORP_TABLE_ROUTER,
          Const.CORP_TABLE_MISC_LARGE,
        ], [
          Const.CORP_WHITEBOARD,
          Const.CORP_COOLER,
          Const.CORP_PLANT,
          Const.CORP_CABINET,
          Const.CORP_TRASH,
          Const.CORP_MACHINERY,
        ],
        Const.TILE_DARK_TABLE_WOOD2_1X1,
        Const.TILE_FLOOR_WOOD2 + UNWALKABLE_TILE_OFFSET,
        40, 50);
    }
}
