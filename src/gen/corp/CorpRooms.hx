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
import game.AreaGenerator._Spot;
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
  // a security room's console under its north wall, and the lockers down its west wall (the gun
  // cabinet among them), in cells
  public static inline var SECURITY_CONSOLE_MAX = 4;
  public static inline var SECURITY_LOCKERS_MAX = 4;
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
  // — 9.8% of the rect furnished, the emptiest room on the floor. 6 x 4 then came back from the
  // game as a giant EMPTY top: at 2 m a cell a 4-deep slab is 8 m across, nobody seated on one side
  // reaches the middle, and nothing on it fills it. So the DEPTH is capped at 2 — a 4 m boardroom
  // table, one row of chairs down each long side (render.corp.CorpProps.boardChairs) — and the
  // length keeps its 6
  public static inline var TABLE_W_MAX = 6;
  public static inline var TABLE_D_MAX = 2;
  // the meeting room's wall dressing: one cell in this many along each wall line, and the percent
  // chance a dressed cell takes a bin rather than a plant
  public static inline var MEETING_WALL_PITCH = 2;
  public static inline var MEETING_WALL_BIN = 20;
  // THE EXEC SUITE'S SIZE GATE: 4 across and 7 long, on either axis. See `execSuite`
  public static inline var SUITE_SPAN = 4;
  public static inline var SUITE_LEN_X = 7;
  public static inline var SUITE_LEN_Y = 7;
  // and the biggest a plain exec office's rug may be, in cells on either axis
  public static inline var RUG_MAX = 4;
  // the reception's back office: at most this many desk banks, one every this many rows (chair,
  // desk, desk, chair)
  public static inline var BACK_OFFICE_BANKS = 2;
  public static inline var BACK_OFFICE_PITCH = 4;

// the decoration groups that stand FLAT AGAINST A WALL in 3D and so never seal their cell: a bin
// (0.66 across), a plant (1.35), a water cooler (0.58) and a whiteboard, which hangs on the wall and
// has no footprint at all — against a 4.0 cell. See addDecorationExt, and docs/area-gen.md on
// the unwalkable twin. Anything added here is dealt walkable by every template at once
  public static var WALL_HUGGERS = [
    Const.CORP_TRASH,
    Const.CORP_PLANT,
    Const.CORP_COOLER,
    Const.CORP_WHITEBOARD,
    // 1.20 deep: reported as an unwalkable tile in front of a reception's filing cabinet
    Const.CORP_CABINET,
  ];

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
      // A WALL-HUGGER DOES NOT TAKE THE TILE. The callers write the room's unwalkable twin before
      // the group is picked, and a thing standing flat against the wall on a sealed cell is a whole
      // 2 m tile of floor lost to something 30 cm deep — reported first for the bin, then for the
      // exec corner plants, then for a boardroom cooler, each fixed on its own and the next one
      // missed. So it is one list (WALL_HUGGERS): every caller hands in a twin, so taking the offset
      // back off is the room's own floor, and render.corp.CorpProps / CorpDeco stand each of these
      // against the wall so the actor on the cell never meets it
      if (WALL_HUGGERS.indexOf(group) >= 0)
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
  public static function atDoor(cells: Array<Array<Int>>, x: Int, y: Int): Bool
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
      // and whether that previous cell is SEALED. The corner is forced straight after one, and it
      // used to be sealed then too, so nothing noticed; a WALL_HUGGERS corner is walkable now, and
      // with a sealed cell above it and a counter along its row it is a boxed-in pocket that
      // CorpConnect.openPockets opens by CLEARING THE COUNTER — reception lost its one-cell run on
      // seeds 52 and 110. Skipping the corner leaves the same pocket as bare floor. So a corner
      // after a sealed cell keeps the twin, whatever it was dealt: it could not be reached anyway
      var sealedLeft = false, sealedRight = false;
      var open = bigFloorID - UNWALKABLE_TILE_OFFSET;
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
              if (isCorner &&
                  sealedLeft &&
                  cells[room.x1][y] == open)
                cells[room.x1][y] = bigFloorID;
              sealedLeft = (cells[room.x1][y] != open);
            }
          else
            sealedLeft = false;

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
              if (isCorner &&
                  sealedRight &&
                  cells[room.x2][y] == open)
                cells[room.x2][y] = bigFloorID;
              sealedRight = (cells[room.x2][y] != open);
            }
          else
            sealedRight = false;
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
      cornerPlants(state, room, MARBLE1);
    }

// the executive's own desk, TURNED SO ITS OWNER FACES THE WAY IN: he sits against the wall behind
// him, the desk in front and the visitors' chairs across it. Of the four ways he could face, one
// with no door of the room behind him wins, and of those one with a door in the wall he faces.
//
// A DOOR IN BOTH END WALLS USED TO MEAN NO DESK AT ALL (382 bare exec offices in 600 seeds), then a
// desk mid-room facing south with the north door at its owner's back. Turned a quarter he faces a
// side wall with both doors beside him. Only a room with a door in every wall leaves one behind
// him, and there the desk stands free mid-room, facing the way with the fewest
  static function execDesk(state: _CorpState, node: _GenNode, room: _Room)
    {
      // the owner's cell against the back wall for facing (fx, fy), `v` cells out from it, and
      // centred across the room
      var ownerAt = function(fx: Int, fy: Int, v: Int)
        {
          return {
            x: (fx == 0 ? room.x1 + Std.int(room.w / 2) : (fx > 0 ? room.x1 + v : room.x2 - v)),
            y: (fy == 0 ? room.y1 + Std.int(room.h / 2) : (fy > 0 ? room.y1 + v : room.y2 - v)),
          };
        };
      var best = null;
      var bestScore = 0;
      for (f in [ [ 0, 1 ], [ 0, -1 ], [ 1, 0 ], [ -1, 0 ] ])
        {
          var o = ownerAt(f[0], f[1], 0);
          var score = doorsBehind(state, room, o.x, o.y, f[0], f[1]) * 10 -
            (doorsAhead(state, room, f[0], f[1]) > 0 ? 1 : 0);
          if (best == null ||
              score < bestScore)
            {
              best = f;
              bestScore = score;
            }
        }
      var fx = best[0], fy = best[1];
      // a door behind him whichever way he turns: out from the wall, mid-room
      var depth = (fx == 0 ? room.h : room.w);
      var o = ownerAt(fx, fy, (bestScore >= 9 ? Std.int((depth - 2) / 2) - 1 : 0));
      // the desk's long axis, across the way he faces
      var px = (fx == 0 ? 1 : 0), py = (fx == 0 ? 0 : 1);
      // THE VISITORS SIT ACROSS THE DESK FROM ITS OWNER, one at each end of the slab, and an
      // armchair BLOCKS its cell: the model is 2.5 of the cell's 4 wide, so two of them either side
      // of a walkable cell read as a wall with a gap you could not fit through. So the room is
      // flooded first — the 3x2 slab when both visitors fit round it, else the 3x1 run on the
      // owner's row (the visitors one row in) with whichever visitors still leave the room open
      for (deep in [ true, false ])
        {
          var rows = (deep ? 2 : 1);
          var blocked = new Map<Int, Bool>();
          var x0 = o.x, y0 = o.y, x1 = o.x, y1 = o.y;
          for (v in 1...rows + 1)
            for (k in -1...2)
              {
                var x = o.x + fx * v + px * k, y = o.y + fy * v + py * k;
                blocked.set(x * 1000 + y, true);
                x0 = (x < x0 ? x : x0);
                y0 = (y < y0 ? y : y0);
                x1 = (x > x1 ? x : x1);
                y1 = (y > y1 ? y : y1);
              }
          var vx = o.x + fx * (rows + 1), vy = o.y + fy * (rows + 1);
          var cands = [
            for (k in [ -1, 1 ])
              if (canSeat(state, room, vx + px * k, vy + py * k))
                { x: vx + px * k, y: vy + py * k }
          ];
          var visitors = fitVisitors(state, room, blocked, cands);
          if (deep &&
              (visitors.length < cands.length ||
              !roomOpen(state, room, blocked, MARBLE1)))
            continue;
          // the bbox above took the owner's own cell in too: off it again
          if (fx != 0)
            {
              x0 = (fx > 0 ? o.x + 1 : x0);
              x1 = (fx > 0 ? x1 : o.x - 1);
            }
          else
            {
              y0 = (fy > 0 ? o.y + 1 : y0);
              y1 = (fy > 0 ? y1 : o.y - 1);
            }
          execDeskAt(state, node, x0, y0, x1, y1, o.x, o.y);
          for (c in visitors)
            seat(state, room, c.x, c.y, Const.CORP_ARMCHAIR);
          return;
        }
    }

// how many of the room's doors are BEHIND someone standing at (x,y) facing (fx,fy) — the rule every
// exec office keeps: its owner never sits with his back to a way in. a door level with him (in a
// side wall, on his own row) is beside him and does not count
  public static function doorsBehind(state: _CorpState, room: _Room, x: Int, y: Int, fx: Int,
      fy: Int): Int
    {
      var n = 0;
      for (door in state.doors)
        if ((door.roomID1 == room.id ||
            door.roomID2 == room.id) &&
            (door.x - x) * fx + (door.y - y) * fy < 0)
          n++;
      return n;
    }

// how many of the room's doors are in the wall someone facing (fx,fy) looks at
  static function doorsAhead(state: _CorpState, room: _Room, fx: Int, fy: Int): Int
    {
      var n = 0;
      for (door in state.doors)
        if ((door.roomID1 == room.id ||
            door.roomID2 == room.id) &&
            ((fy > 0 && door.y == room.y2 + 1) ||
            (fy < 0 && door.y == room.y1 - 1) ||
            (fx > 0 && door.x == room.x2 + 1) ||
            (fx < 0 && door.x == room.x1 - 1)))
          n++;
      return n;
    }

// the visitor cells (of `cands`) that can take an armchair without sealing any of the room off,
// each one added to `blocked` as it is kept
  static function fitVisitors(state: _CorpState, room: _Room, blocked: Map<Int, Bool>,
      cands: Array<{ x: Int, y: Int }>): Array<{ x: Int, y: Int }>
    {
      var out = [];
      for (c in cands)
        {
          blocked.set(c.x * 1000 + c.y, true);
          if (roomOpen(state, room, blocked, MARBLE1))
            out.push(c);
          else
            blocked.remove(c.x * 1000 + c.y);
        }
      return out;
    }

// lay the exec desk over the rect (x0,y0)..(x1,y1) — the 3x2 block either way round, or the 3x1
// run — with its owner's chair at (cx,cy), beside the middle of a long side. the monitor stands on
// the desk cell next to the chair and the rest of the top takes a roll of desk things. the 3x2
// TILE GROUP only fits the block laid 3 across x; turned, it takes the plain worktop tile, which
// render.corp.CorpExec reads the same (any exec worktop) and stands the same glb over, turned
  static function execDeskAt(state: _CorpState, node: _GenNode, x0: Int, y0: Int, x1: Int, y1: Int,
      cx: Int, cy: Int)
    {
      var cells = state.area.getCells();
      var full = [
        Const.CORP_TABLE_PHONE,
        Const.CORP_TABLE_LAMP,
        Const.CORP_TABLE_FILES,
        Const.CORP_TABLE_STATIONERY,
      ];
      var deco = full.copy();
      // the desk cell in front of the chair
      var compx = (cx < x0 ? x0 : (cx > x1 ? x1 : cx));
      var compy = (cy < y0 ? y0 : (cy > y1 ? y1 : cy));
      var group = (x1 - x0 == 2 &&
        y1 - y0 == 1);
      GenTree.add(node, CorpBlocks.ZONE_TABLE, x0, y0, x1, y1);
      addDecoration(state, cx, cy, Const.CORP_EXEC_CHAIR);
      addDecoration(state, compx, compy, Const.CORP_COMPUTERS);
      var left = full.length;
      for (y in y0...y1 + 1)
        for (x in x0...x1 + 1)
          {
            cells[x][y] = (group ? Const.DARK_TABLE_MARBLE1_3X2[y - y0][x - x0] :
              Const.TILE_DARK_TABLE_MARBLE1_1X1);
            if (x == compx &&
                y == compy)
              continue;
            if (state.area.chance(40) &&
                left > 0)
              {
                deco = addDecorationExt(state, x, y, deco, full);
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
      // the chair beside the middle cell, on whichever side leaves no door at its owner's back
      // (doorsBehind), the far side from the room's first wall when both or neither do
      var mx = (alongX ? sx + Std.int(len / 2) : sx + 1);
      var my = (alongX ? sy + 1 : sy + Std.int(len / 2));
      var fx = (alongX ? 0 : -1), fy = (alongX ? -1 : 0);
      var ax = mx + 2 * fx, ay = my + 2 * fy;
      if (ax >= room.x1 &&
          ay >= room.y1 &&
          doorsBehind(state, room, ax, ay, -fx, -fy) < doorsBehind(state, room, mx, my, fx, fy))
        {
          mx = ax;
          my = ay;
        }
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
            for (side in [ false, true ])
              {
                var at = function(u: Int, v: Int)
                  {
                    var x = (alongX ? (flip ? room.x2 - u : room.x1 + u) : room.x1 + v);
                    var y = (alongX ? room.y1 + v : (flip ? room.y2 - u : room.y1 + u));
                    return { x: x, y: y };
                  };
                // every cell the suite stands on, solid or seat, has to be the room's bare floor
                // and not a doorway
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
                    owner = at(du + 1, (side ? dv + 2 : dv - 1));
                    var vv = (side ? dv - 1 : dv + 2);
                    visitors = [ at(du, vv), at(du + 2, vv) ];
                  }
                else
                  {
                    for (u in du...du + 2)
                      for (v in dv...dv + 3)
                        deskCells.push(at(u, v));
                    owner = at((side ? du + 2 : du - 1), dv + 1);
                    // and at 7 long the visitors' row would stand back to back with the lounge's
                    // armchairs, so a room that short keeps the row as its lane instead. turned
                    // round, they sit against the end wall and the owner's row is the lane
                    if (side)
                      visitors = [ at(du - 1, dv), at(du - 1, dv + 2) ];
                    else if (len > SUITE_LEN_Y)
                      visitors = [ at(du + 2, dv), at(du + 2, dv + 2) ];
                  }
                // THE OWNER NEVER SITS WITH HIS BACK TO A DOOR (doorsBehind): the desk is tried
                // with his chair on its other long side before the placement is given up
                var fx = 0, fy = 0;
                for (c in deskCells)
                  if (Math.abs(c.x - owner.x) + Math.abs(c.y - owner.y) == 1)
                    {
                      fx = c.x - owner.x;
                      fy = c.y - owner.y;
                    }
                if (doorsBehind(state, room, owner.x, owner.y, fx, fy) > 0)
                  continue;
                var ok = true;
                var blocked = new Map<Int, Bool>();
                for (c in solid.concat(deskCells).concat([ owner ]))
                  if (cells[c.x][c.y] != MARBLE1 ||
                      atDoor(cells, c.x, c.y))
                    ok = false;
                for (c in solid.concat(deskCells))
                  blocked.set(c.x * 1000 + c.y, true);
                // AND IT MAY NOT SEAL ANY OF THE ROOM OFF. A placement that does is not caught by
                // the oracle — gen.corp.CorpConnect.openPockets erodes whatever walls the pocket in,
                // and what it erodes is the furniture: measured on the first build, a 9 x 4 suite
                // came back with the desk's first column and both door-end plants eaten
                if (!ok ||
                    !roomOpen(state, room, blocked, MARBLE1))
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
                execDeskAt(state, node, tx, ty, tx + 2, ty + 1, owner.x, owner.y);
                // the armchairs block, so a visitor that would seal a cell off stays out
                for (c in fitVisitors(state, room, blocked,
                    [ for (c in visitors) if (canSeat(state, room, c.x, c.y)) c ]))
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

// can a chair stand here: a free cell of the room's own floor that is not a doorway
  static function canSeat(state: _CorpState, room: _Room, x: Int, y: Int): Bool
    {
      var cells = state.area.getCells();
      return x >= room.x1 &&
        x <= room.x2 &&
        y >= room.y1 &&
        y <= room.y2 &&
        cells[x][y] == MARBLE1 &&
        !atDoor(cells, x, y);
    }

// seat one armchair on a free cell of the room's own floor, if there is one there. the cell takes
// the marble's unwalkable twin (the FINAL id: the temp MARBLE1 + 16 has no final tile)
  static function seat(state: _CorpState, room: _Room, x: Int, y: Int, group: _TileGroup)
    {
      if (!canSeat(state, room, x, y))
        return;
      state.area.getCells()[x][y] = Const.TILE_FLOOR_MARBLE1 + UNWALKABLE_TILE_OFFSET;
      addDecoration(state, x, y, group);
    }

// a plant in every corner of the room that is still its bare floor (or its rug) and is not a
// doorway.
//
// THE PLANT IS WALKABLE: its cell keeps its own floor id and only the decoration goes on it, the
// way the exec chair's does. A blocking plant made every corner a dead cell, and in 3D the glb
// stands pushed into the corner, so it read as free floor you could not step on
  static function cornerPlants(state: _CorpState, room: _Room, floor: Int)
    {
      var cells = state.area.getCells();
      for (c in [
          { x: room.x1, y: room.y1 },
          { x: room.x2, y: room.y1 },
          { x: room.x1, y: room.y2 },
          { x: room.x2, y: room.y2 },
        ])
        {
          if ((cells[c.x][c.y] != floor &&
              cells[c.x][c.y] != Const.TILE_FLOOR_EXEC_RUG) ||
              atDoor(cells, c.x, c.y) ||
              state.area.hasObjectAt(c.x, c.y))
            continue;
          addDecoration(state, c.x, c.y, Const.CORP_PLANT);
        }
    }

// can every walkable cell of the room still be reached from its doorways, with the cells in
// `blocked` (keyed x * 1000 + y) taken as furniture? `floor` is the room's own walkable floor id.
// True for a room with no doorway to start from. `joined` floods from ONE doorway, so the floor must
// also be a single piece: a rank that splits a room between two doors passes the plain test, and
// the half whose door leads nowhere is a pocket CorpConnect.openPockets tears furniture out to reach.
//
// THE EXEC OFFICE ASKS THIS OF ITSELF because the repair downstream cannot tell a pocket it should
// open from furniture it should keep: gen.corp.CorpConnect.openPockets reaches a sealed cell by
// eroding whatever stands in the way, so a placement that walls a lane in is not rejected, it is
// half-deleted after the fact
  public static function roomOpen(state: _CorpState, room: _Room, blocked: Map<Int, Bool>,
      floor: Int, joined: Bool = false): Bool
    {
      var cells = state.area.getCells();
      var walk = function(x: Int, y: Int)
        return x >= room.x1 &&
          x <= room.x2 &&
          y >= room.y1 &&
          y <= room.y2 &&
          !blocked.exists(x * 1000 + y) &&
          (cells[x][y] == floor ||
          cells[x][y] == Const.TILE_FLOOR_EXEC_RUG);
      var seen = new Map<Int, Bool>();
      var stack = [];
      var total = 0;
      for (x in room.x1...room.x2 + 1)
        for (y in room.y1...room.y2 + 1)
          if (walk(x, y))
            {
              total++;
              if (atDoor(cells, x, y) &&
                  !(joined &&
                  stack.length > 0))
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

// a meeting room: one long table in the middle, a plant in every free corner, and plants, a
// whiteboard, a cooler and a bin spaced along the walls.
//
// IT USED `decorateWalls` AND THAT WAS THE EMPTY EDGES. That pass forces a dressing into all four
// corners and onto about half of the x1/x2 columns, 80% of them on the room's UNWALKABLE twin — and
// half of what it dealt draws nothing on the floor (a whiteboard hangs on the wall, a plant stands
// pushed into its corner), so the room came back ringed with dead cells that looked like carpet.
// Its 1x1 wall tables were the other half: a lone table tile renders as a desk, and nothing seats a
// desk in here. The kitchen and the exec office dropped it for the same reasons.
//
// NOTHING HERE WRITES THE UNWALKABLE TWIN: everything on the walls is a WALL_HUGGERS group. If a
// sealing piece is ever added, it takes the room's OWN twin — a borrowed floor id finalises the cell
// as another room's surface, and the wall run, the table and the ceiling lamps all read it back
// (docs/area-gen.md on `CARPET_MEETING + 16`)
  public static function meeting(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, CARPET_MEETING);
      // 5 AND NOT 6, because the carve moved under it: a room is now floored at SPLIT_MIN on
      // either axis and `meetingTable` only needs `w - 4` and `h - 4` to be at least 1
      if (room.w >= 5 &&
          room.h >= 5)
        meetingTable(state, node, room);
      cornerPlants(state, room, CARPET_MEETING);
      meetingWalls(state, room);
    }

// the meeting room's wall dressing: every MEETING_WALL_PITCH-th cell along each wall line, corners
// excepted (cornerPlants has those), that is still bare carpet and not beside a doorway. One
// whiteboard on a masonry cell, one cooler on another, and plants and the odd bin on the rest. ALL
// OF THEM keep their floor (WALL_HUGGERS): they stand flat against the wall in 3D, or hang on it, so
// the cell is still floor to walk on. The cooler used to take the twin and was reported as an
// unwalkable tile in front of a water cooler
  static function meetingWalls(state: _CorpState, room: _Room)
    {
      var cells = state.area.getCells();
      var cand = [];
      var masonry = [];
      // the four wall lines, each cell with the hand its wall is on
      var add = function(x: Int, y: Int, i: Int, dx: Int, dy: Int)
        {
          if (i % MEETING_WALL_PITCH != 0 ||
              cells[x][y] != CARPET_MEETING ||
              atDoor(cells, x, y) ||
              state.area.hasObjectAt(x, y))
            return;
          cand.push({ x: x, y: y });
          var t = cells[x + dx][y + dy];
          if (t == BLDG_WALL ||
              t == BLDG_INNER_WALL)
            masonry.push(cand.length - 1);
        };
      for (x in room.x1 + 1...room.x2)
        {
          add(x, room.y1, x - room.x1, 0, -1);
          add(x, room.y2, x - room.x1, 0, 1);
        }
      for (y in room.y1 + 1...room.y2)
        {
          add(room.x1, y, y - room.y1, -1, 0);
          add(room.x2, y, y - room.y1, 1, 0);
        }
      var board = (masonry.length > 0 ? masonry[state.area.random(masonry.length)] : -1);
      var cooler = (masonry.length > 1 ? masonry[state.area.random(masonry.length)] : -1);
      if (cooler == board)
        cooler = -1;
      for (i in 0...cand.length)
        {
          var c = cand[i];
          if (i == board)
            addDecoration(state, c.x, c.y, Const.CORP_WHITEBOARD);
          else if (i == cooler)
            addDecoration(state, c.x, c.y, Const.CORP_COOLER);
          else if (state.area.chance(MEETING_WALL_BIN))
            addDecoration(state, c.x, c.y, Const.CORP_TRASH);
          else
            addDecoration(state, c.x, c.y, Const.CORP_PLANT);
        }
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
      // circulation rather than in it. The LONG axis follows the room's, so a long thin boardroom
      // gets a long thin table, and the depth is capped separately (see TABLE_D_MAX)
      var alongX = (room.w >= room.h);
      var len = (alongX ? room.w : room.h) - 4;
      var deep = (alongX ? room.h : room.w) - 4;
      if (len > TABLE_W_MAX)
        len = TABLE_W_MAX;
      if (deep > TABLE_D_MAX)
        deep = TABLE_D_MAX;
      var tw = (alongX ? len : deep);
      var th = (alongX ? deep : len);
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

// a staff kitchen and the floor's break room in one. The template only lays the floor; what stands
// on it is three sub-blocks gen.corp.CorpKitchen divides the room into and fills a level down — a
// prep counter along one wall, a snack corner by a door and the dining tables in the middle
  public static function kitchen(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, WOOD1);
      CorpKitchen.zones(state, node, room);
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

// a server room: solid ranks of racks with an aisle between them, and nothing else in it.
//
// ROW BY ROW, EACH RANK LAID WHOLE across the interior (x1+1 .. x2-1). It used to roll every cell
// at 20% and deal one gap a rank, which read as cabinets scattered over the floor rather than rows
// of them. The gap was there to keep the floor joined, and the room's two edge columns do that now
// that nothing dresses its walls: the router benches went, and so did the wall machines, which
// render.corp.CorpFurniture.machine drew as half-height racks against the wall. Ranks every
// RACK_PITCH rows, RACK_ROWS_MAX of them at most, centred on the room's depth
  public static function servers(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, SERVER);
      var rows = Std.int((room.h - 1) / RACK_PITCH);
      if (rows > RACK_ROWS_MAX)
        rows = RACK_ROWS_MAX;
      var y0 = room.y1 + 1 + Std.int((room.h - 1 - RACK_PITCH * rows) / 2);
      for (i in 0...rows)
        {
          var ry = y0 + i * RACK_PITCH;
          GenTree.add(node, CorpBlocks.ZONE_RACK_ROW, room.x1 + 1, ry, room.x2 - 1, ry);
          for (x in room.x1 + 1...room.x2)
            {
              cells[x][ry] = RACK_HIGH;
              addDecoration(state, x, ry, Const.CORP_MACHINERY);
            }
        }
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

// a reception: a marble counter where its wall onto the corridor was, facing the lift, a lane
// behind it for the receptionist, and greenery round the other walls
//
// THE COUNTER IS THE FRONT WALL ITSELF, laid over the ring cells from one corner post to the other
// (gen.corp.CorpBuilding.frontWall picks the wall, gen.blocks.CorpBlocks.fronts carries it here).
// The visitor stands in the corridor and the receptionist in the room; the room is entered by a
// door in another wall, which CorpBuilding.frontShuts guaranteed before the room was dealt.
//
// IT USED TO BE A DESK RUN ON THE ROOM'S OWN EDGE ROW, always horizontal and facing whichever of
// y1/y2 was nearer a lift point that was itself mirrored — so it usually faced away from the car
  static function counter(state: _CorpState, node: _GenNode, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      var front = CorpBlocks.fronts.get(room.id);
      var d = deltaMap[front[0].dir];
      // THE DOORS IN IT GO, which is what the room was dealt on the promise of
      for (door in CorpBuilding.frontDoors(state, front))
        state.doors.remove(door);
      for (s in front)
        {
          cells[s.x][s.y] = RECEPTION_COUNTER;
          // the lobby: the corridor straight out from the counter, across its width
          for (k in 1...CORRIDOR_W + 1)
            {
              if (cells[s.x + d.x * k][s.y + d.y * k] != BLDG_CORRIDOR)
                break;
              cells[s.x + d.x * k][s.y + d.y * k] = RECEPTION;
            }
          // and the receptionist's LANE, the row behind it: `decorateWalls` dresses columns x1
          // and x2 whole, which on a counter down a side wall would stand a cooler behind every
          // cell of it
          var lx = s.x - d.x;
          var ly = s.y - d.y;
          cells[lx][ly] = RECEPTION;
          for (o in area.getObjectsAt(lx, ly))
            area.removeObject(o);
        }
      var last = front[front.length - 1];
      GenTree.add(node, CorpBlocks.ZONE_COUNTER_RUN, front[0].x, front[0].y, last.x, last.y);
      // and a receptionist's chair behind every station along it
      var chairID = area.random(Const.CORP_CHAIR[0].amount);
      for (k in Const.receptionStations(front.length))
        area.addDecoration(front[k].x - d.x, front[k].y - d.y, Const.CORP_CHAIR[0].row, chairID);
      lobbyPlants(state, front, d);
    }

// a tall plant in the corridor against each corner post, flanking the counter. A wall-hugger, so
// the corridor cell stays floor
  static function lobbyPlants(state: _CorpState, front: Array<_Spot>, d: { x:Int, y:Int })
    {
      var cells = state.area.getCells();
      var along = deltaMap[front[0].dir90];
      var last = front[front.length - 1];
      for (p in [
          { x: front[0].x - along.x, y: front[0].y - along.y },
          { x: last.x + along.x, y: last.y + along.y },
        ])
        {
          var x = p.x + d.x;
          var y = p.y + d.y;
          if (cells[x][y] == BLDG_CORRIDOR &&
              !atDoor(cells, x, y) &&
              !state.area.hasObjectAt(x, y))
            addDecoration(state, x, y, Const.CORP_PLANT);
        }
    }

// THE BACK OFFICE: banks of desks behind the receptionist, two rows back to back with a chair on
// each outer side, running along x. A reception is dealt big (the counter wants the whole corridor
// wall) and was reported as feeling empty: wall dressing and a lane was all it had. The banks stay
// clear of the dressed side columns, the aisle beside each and the receptionist's lane, and a bank
// that would cut the room off from a doorway is not laid (`roomOpen`)
  static function backOffice(state: _CorpState, node: _GenNode, room: _Room, d: { x:Int, y:Int })
    {
      var area = state.area;
      var cells = area.getCells();
      var x0 = room.x1 + 2;
      var x1 = room.x2 - 2;
      // the first and last row a CHAIR may take: never the lane, nor the row in front of it
      var lo = room.y1 + (d.y < 0 ? 2 : 0);
      var hi = room.y2 - (d.y > 0 ? 2 : 0);
      if (x1 < x0)
        return;
      var chairID = area.random(Const.CORP_CHAIR[0].amount);
      var banks = 0;
      // TWO ROWS BACK TO BACK where they fit, ONE where they do not. A back-to-back bank wants a
      // chair row either side of it, and with the counter on y1 or y2 a 5-deep room has three rows
      // left after the lane and the row in front of it — a chair short, so the middle came out bare.
      // Reported from area 5646's 5x5 reception. A single row keeps only its first chair
      for (depth in [2, 1])
        {
          var a = lo + 1;
          while (a + (depth == 2 ? 2 : 0) <= hi &&
              banks < BACK_OFFICE_BANKS)
            {
              var blocked = new Map<Int, Bool>();
              var ok = true;
              for (x in x0...x1 + 1)
                for (y in a...a + depth)
                  {
                    if (cells[x][y] != RECEPTION ||
                        area.hasObjectAt(x, y) ||
                        atDoor(cells, x, y))
                      ok = false;
                    blocked.set(x * 1000 + y, true);
                  }
              if (ok &&
                  roomOpen(state, room, blocked, RECEPTION))
                {
                  GenTree.add(node, CorpBlocks.ZONE_DESK_RUN, x0, a, x1, a + depth - 1);
                  for (x in x0...x1 + 1)
                    for (i in 0...depth)
                      {
                        cells[x][a + i] = Const.CORP_TABLE_3X1[1];
                        addDecoration(state, x, a + i, Const.CORP_COMPUTERS);
                        area.addDecoration(x, a + (i == 0 ? -1 : 2), Const.CORP_CHAIR[0].row,
                          chairID);
                      }
                  banks++;
                  a += BACK_OFFICE_PITCH;
                }
              else
                a++;
            }
          if (banks > 0)
            break;
        }
    }

// NO WHITEBOARD: the back wall is where the company's name hangs, facing the counter. Dressed at
// 80% and not 40, a workstation among the wall tables, and the back office's desk banks in the
// middle: reported as feeling empty with a lane and the odd plant in a 5 x 7 room
  public static function reception(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, RECEPTION);
      decorateWalls(state, room, [
          Const.CORP_COMPUTERS,
          Const.CORP_TABLE_PHONE,
          Const.CORP_TABLE_MISC,
          Const.CORP_TABLE_PLANTS,
        ], [
          Const.CORP_PLANT,
          Const.CORP_COOLER,
          Const.CORP_CABINET,
        ],
        Const.TILE_DARK_TABLE_MARBLE1_1X1,
        Const.TILE_FLOOR_RECEPTION + UNWALKABLE_TILE_OFFSET,
        80, 50);
      // AFTER the dressing, so the lane behind the counter is cleared of it
      counter(state, node, room);
      backOffice(state, node, room, deltaMap[CorpBlocks.fronts.get(room.id)[0].dir]);
    }

// a security post, one wall to a job. THE CONSOLE UNDER THE NORTH WALL faces the video wall
// render.corp hangs over it, which is the wall the camera looks at; the RACKS that feed it run down
// the east wall and the LOCKERS down the west, one of them the gun cabinet. The south wall is left
// bare, being the one the camera looks over.
//
// THE RACK USED TO STAND IN THE MIDDLE. `rackRows` lays its first rank at y1+1, clear of every
// wall by construction, and in a 4x4 room that is the desk run's own row, so the fallback wrote a
// rack over a desk cell every time. Nothing stands mid-room now, so the two cannot meet
  public static function security(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, SERVER);
      // NO GLAZING: a guard post is not a fishbowl, and the lockers and racks stood in front of the
      // panes. The ring's windows go back to the wall they were cut into, curtain wall or partition
      for (x in room.x1 - 1...room.x2 + 2)
        for (y in room.y1 - 1...room.y2 + 2)
          {
            var t = cells[x][y];
            if (t >= BLDG_WINDOW &&
                t <= BLDG_WINDOWV3)
              cells[x][y] = BLDG_WALL;
            else if (t >= INNER_WINDOW &&
                t <= INNER_WINDOWV3)
              cells[x][y] = BLDG_INNER_WALL;
          }
      if (!consoleRun(state, node, room))
        deskRun(state, node, room, [
            Const.CORP_COMPUTERS,
            Const.CORP_TABLE_ROUTER,
          ]);
      var racks = wallColumn(state, room, room.x2);
      var lockers = wallColumn(state, room, room.x1);
      if (lockers.length > SECURITY_LOCKERS_MAX)
        lockers = lockers.slice(0, SECURITY_LOCKERS_MAX);
      // the gun cabinet is an object, objects.GunCabinet, on plain floor. Like a locker and a wall
      // rack it stands in the wall's own margin and its cell stays walkable, so nothing here can seal
      // the floor. It wants FLOOR IN FRONT OF IT for its door to swing into: the locker nearest the
      // run's middle that has it
      //
      // AND NEVER IN A CORNER: the render turns it by its wall (render.world.ObjModels, WALL yaw), and
      // a corner has two, the north one asked first -- a cabinet in the west column turned to face
      // down its own locker run
      var cab = -1;
      for (i in 0...lockers.length)
        if (cells[lockers[i].x + 1][lockers[i].y] == SERVER &&
            !corner(room, lockers[i].x, lockers[i].y) &&
            (cab < 0 ||
            Math.abs(i - lockers.length / 2) < Math.abs(cab - lockers.length / 2)))
          cab = i;
      if (racks.length > 0)
        GenTree.add(node, CorpBlocks.ZONE_RACK_ROW, room.x2, racks[0].y, room.x2,
          racks[racks.length - 1].y);
      for (c in racks)
        {
          cells[c.x][c.y] = Const.TILE_CORP_WALL_RACK;
          addDecoration(state, c.x, c.y, Const.CORP_MACHINERY);
        }
      for (i in 0...lockers.length)
        {
          var c = lockers[i];
          if (i == cab)
            state.area.add('gunCabinet', c.x, c.y);
          else
            cells[c.x][c.y] = Const.TILE_CORP_LOCKER;
        }
    }

// a security room's console: a desk run along the north wall with a workstation on every cell,
// and a chair in front of all but the middle one, which is where the guard stands
// (game.AreaGame.initSpawnPoints finds the post off this run). A DOORWAY IN THAT WALL SPLITS IT:
// the desks stand either side of the door and its own cell stays floor. It used to fall back to a
// free-standing `deskRun` mid-room, which drew as bare tables with no screen or chair. False only
// when the door leaves no cell, and the caller falls back to that run still
  static function consoleRun(state: _CorpState, node: _GenNode, room: _Room): Bool
    {
      var area = state.area;
      var cells = area.getCells();
      // the corners belong to the two wall columns
      var n = room.w - 2;
      if (n > SECURITY_CONSOLE_MAX)
        n = SECURITY_CONSOLE_MAX;
      var tx = room.x1 + Std.int((room.w - n) / 2);
      var ty = room.y1;
      var desks = [];
      for (dx in 0...n)
        if (!atDoor(cells, tx + dx, ty))
          desks.push(tx + dx);
      if (desks.length == 0)
        return false;
      // one 3x1 run per stretch between doors, its end pieces on the stretch's own ends
      var block = Const.CORP_TABLE_3X1;
      var post = desks[Std.int(desks.length / 2)];
      for (x in desks)
        {
          var left = (desks.indexOf(x - 1) >= 0);
          var right = (desks.indexOf(x + 1) >= 0);
          cells[x][ty] = (left == right ? block[1] : right ? block[0] : block[2]);
          if (!left)
            {
              var end = x;
              while (desks.indexOf(end + 1) >= 0)
                end++;
              GenTree.add(node, CorpBlocks.ZONE_DESK_RUN, x, ty, end, ty);
            }
          addDecoration(state, x, ty, Const.CORP_COMPUTERS);
          if (x != post)
            area.addDecoration(x, ty + 1, Const.CORP_CHAIR[0].row,
              area.random(Const.CORP_CHAIR[0].amount));
        }
      return true;
    }

// where a security room's guard stands: in front of the middle cell of its desk run, which on the
// console is the one cell with no chair. Null for a room whose run was never laid. Read off the
// FINISHED grid, so game.AreaGame.initSpawnPoints can ask it of any saved tower
  public static function securityPost(cells: Array<Array<Int>>, room: _Room): { x:Int, y:Int }
    {
      for (y in room.y1...room.y2 + 1)
        {
          var run = [];
          for (x in room.x1...room.x2 + 1)
            if (Const.CORP_TABLE_3X1.indexOf(cells[x][y]) >= 0)
              run.push(x);
          if (run.length > 0)
            return {
              x: run[Std.int(run.length / 2)],
              y: y + 1,
            };
        }
      return null;
    }

// the free cells of a room's wall column, north to south: not the ones a doorway opens onto or
// the ones beside them, and not a cell something already stands on
  static function wallColumn(state: _CorpState, room: _Room, x: Int): Array<{ x:Int, y:Int }>
    {
      var cells = state.area.getCells();
      var out = [];
      for (y in room.y1...room.y2 + 1)
        if (cells[x][y] == SERVER &&
            !atDoor(cells, x, y) &&
            !besideDoor(cells, x, y) &&
            !state.area.hasObjectAt(x, y))
          out.push({ x: x, y: y });
      return out;
    }
}
