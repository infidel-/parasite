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
  // a partition behind it on the spine the two rows share. 3 where the room can hold two blocks of
  // three plus their passages, 2 otherwise
  public static inline var POD_BLOCK_W = 3;
  public static inline var POD_BLOCK_MIN = 2;
  // one band is desk, spine, desk, aisle — and the band above it supplied the aisle its first desk
  // row faces, which is why the pitch is four rows and not five
  public static inline var POD_BAND_H = 4;
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

// an executive office: marble, one big desk facing the door, a cooler and a plant in the corners
  public static function exec(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, MARBLE1);

      // `hasTable` has to come OUT of execDesk and not be assumed from its guard: it gives up
      // silently when the room has a door in both end walls (there is then no wall to face the
      // desk at), and setting the flag true anyway closed the `!hasTable` escape below. At
      // exactly w == 6 the `w >= 7` arm is closed too, so the room got marble and NOTHING ELSE —
      // 23 of 600 seeds, and the "37,12 room is empty" this pass started from
      // 4 x 4, AND THE GUARD HAS COME DOWN TWICE WITH THE CARVE. It was 6 x 6, then 5 x 5 when
      // the demand asked for 5; with ROOM_SIZE 6 and SPLIT_MIN 5 a floor carries 29 rooms and only
      // a handful clear 5 on both axes, so six 5x5 demands dealt ahead of this one left it with
      // nothing — "quota short: room-exec got 0" on 14 towers in 3,000. A 3-wide desk centred in a
      // 4-wide room lands x1+1..x1+3, i.e. against the far wall with a clear column on the near
      // side, which is what an office that size looks like anyway
      var hasTable = (room.w >= 4 &&
        room.h >= 4 &&
        execDesk(state, node, room));
      // THE CORNERS STAY AT `w >= 7`, and the plan to open them to every room is WITHDRAWN on
      // the measurement. `execDesk` always returns true now, so this reads as the width test
      // alone and it looks like a room under 7 wide gets a desk and nothing else. Dressing the
      // corners anyway was tried and MEASURED: exec fill 26.9% -> 20.7%, because a 3x2 slab and
      // four dressed corners in a 4x4 office seal the floor, and what `CorpConnect.openPockets`
      // then undoes to reach it is the desk. More furniture, less furniture standing
      if (!hasTable ||
          room.w >= 7)
        decorateCorners(state, room, [
            Const.CORP_TABLE_COFFEE,
            Const.CORP_TABLE_ROUTER,
          ], [
            Const.CORP_COOLER,
            Const.CORP_PLANT,
          ],
          Const.TILE_DARK_TABLE_MARBLE1_1X1,
          Const.TILE_FLOOR_MARBLE1 + UNWALKABLE_TILE_OFFSET,
          20);
    }

// the executive's own 3x2 desk, against whichever end wall has no door in it. returns whether it
// actually laid one — see `exec`, which has no other way to find out
  static function execDesk(state: _CorpState, node: _GenNode, room: _Room): Bool
    {
      var cells = state.area.getCells();
      var full = [
        Const.CORP_TABLE_PHONE,
        Const.CORP_TABLE_LAMP,
        Const.CORP_TABLE_FILES,
        Const.CORP_TABLE_STATIONERY,
      ];
      var deco = full.copy();

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
      var cx = tx + 1, cy = ty - 1;
      var compx = cx, compy = ty;
      if (hasNorthDoor)
        {
          ty = room.y2 - 2;
          cy = ty + 2;
          compy = ty + 1;
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
          compy = ty;
        }
      GenTree.add(node, CorpBlocks.ZONE_TABLE, tx, ty, tx + 2, ty + 1);
      state.area.addDecoration(cx, cy, Const.CORP_CHAIR[0].row, 1);
      addDecoration(state, compx, compy, Const.CORP_COMPUTERS);

      var left = full.length;
      for (dy in 0...2)
        for (dx in 0...3)
          {
            cells[tx + dx][ty + dy] = Const.DARK_TABLE_MARBLE1_3X2[dy][dx];
            if (tx + dx == compx && ty + dy == compy)
              continue;
            if (state.area.chance(40) &&
                left > 0)
              {
                deco = addDecorationExt(state, tx + dx, ty + dy, deco, full);
                left--;
              }
          }
      return true;
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

// a staff kitchen: a column of 2x2 tables, appliances round the walls
  public static function kitchen(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, WOOD1);
      // and the same 5 the boardroom takes — `kitchenTables` lays 2x2 units at pitch 3 inside the
      // room's own inset, which a 5-cell run still holds one of
      if (room.w >= 5 &&
          room.h >= 5)
        kitchenTables(state, node, room);
      decorateWalls(state, room, [
          Const.CORP_TABLE_COFFEE,
          Const.CORP_TABLE_CLEANING,
          Const.CORP_TABLE_BLENDER,
          Const.CORP_TABLE_KETTLE,
          Const.CORP_TABLE_MICROWAVE,
          Const.CORP_TABLE_CONTAINER,
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
        50, 20);
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
// A BLOCK IS `bw` PODS WIDE AND TWO DEEP — two rows of desks back to back with one run of
// partition between them, a passage column each side of the block and an aisle row each side of
// the band — so every worker gets a bay of his own. The side panels between neighbours inside a
// block cost NO CELL: render.corp.CorpFurniture stands one on the boundary between two adjacent
// cubicle desk cells, which is what "each has his private space" asks for without spending a grid
// column on every divider.
//
// IT USED TO BE A FIVE-ROW BAND WITH A 3-CELL DESK RUN per pod — three people sharing one
// unbroken worktop with no divider anywhere along it, and the run started at x1+1 and marched
// until it ran out, so the whole remainder landed on the x2 side and the last pod could sit flush
// against the dressed wall column. The run is CENTRED now and the remainder split
  public static function cubicle(state: _CorpState, node: _GenNode, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, CUBICLE);
      var spine = Const.TILE_FLOOR_CUBICLE + UNWALKABLE_TILE_OFFSET;
      var chairID = area.random(Const.CORP_CHAIR[0].amount);
      var computerID = area.random(Const.CORP_COMPUTERS_BLOCK.width);

      // the interior, between the two wall columns `decorateWalls` dresses
      var inner = room.w - 2;
      var bw = (inner >= POD_BLOCK_W * 2 + 3 ? POD_BLOCK_W : POD_BLOCK_MIN);
      var blocks = Std.int((inner + 1) / (bw + 1));
      if (blocks < 1 ||
          room.h < POD_BAND_H + 1)
        {
          decorateCubicleWalls(state, room);
          return;
        }
      var runW = blocks * (bw + 1) - 1;
      var x0 = room.x1 + 1 + Std.int((inner - runW) / 2);

      var band = 0;
      while (true)
        {
          band++;
          if (band > 20)
            break;
          // the band's three rows, with the aisle its first desk row faces one row above
          var dy0 = room.y1 + 1 + (band - 1) * POD_BAND_H;
          var sy = dy0 + 1;
          var dy1 = dy0 + 2;
          if (dy1 + 1 > room.y2)
            break;

          for (b in 0...blocks)
            {
              var bx = x0 + b * (bw + 1);
              GenTree.add(node, CorpBlocks.ZONE_POD_ROW, bx, dy0, bx + bw - 1, dy1);
              for (i in 0...bw)
                {
                  cells[bx + i][sy] = spine;
                  pod(state, bx + i, dy0, dy0 - 1, computerID, chairID);
                  pod(state, bx + i, dy1, dy1 + 1, computerID, chairID);
                }
              // and a bin where the passage meets the aisle past this block, on its own unwalkable
              // cell so it is a real obstacle rather than something the player walks through
              var binX = bx + bw;
              if (binX < room.x2 &&
                  area.chance(50))
                {
                  cells[binX][dy1 + 1] = spine;
                  addDecoration(state, binX, dy1 + 1, Const.CORP_TRASH);
                }
            }
        }

      decorateCubicleWalls(state, room);
    }

// one pod: a desk cell, the workstation on it, and its chair in the aisle it faces
  static function pod(state: _CorpState, x: Int, dy: Int, cy: Int, computerID: Int, chairID: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      // THE MIDDLE ID OF THE 3x1 RUN, because a pod is one cell and the run's two ends are its
      // carcass sides. render.corp.CorpFurniture stands a `corp/desk-bench` module per cell and
      // asks the SURFACE, not the column, so any table id of the family draws the same desk
      cells[x][dy] = Const.CORP_TABLE_3X1[1];
      area.addDecoration(x, dy, Const.CORP_COMPUTERS_BLOCK.row,
        Const.CORP_COMPUTERS_BLOCK.col + computerID);
      area.addDecoration(x, cy, Const.CORP_CHAIR[0].row, chairID);
    }

// the farm's own wall furniture: cabinets, a cooler, a plant, bins.
//
// NO `small` LIST AND SO NO TABLE TILE ON THE PERIMETER, which is the other half of the reported
// "this desk should not exist". `decorateWalls`' small branch writes TILE_DARK_TABLE_WOOD2_1X1,
// a corp TABLE id — so render.corp.CorpModel gave that cell m.table, FacilityModel.themeRooms
// gave it Surf.CUBICLE, CorpFurniture.deskCell answered true and a whole desk-bench module stood
// in the aisle against the wall. The three small items it dealt (a printer, a coffee machine, a
// router) draw NOTHING anyway — CorpDeco.kindOf answers K_NONE for all of row 28 and 29 while
// CorpDeco.draws suppresses their sprites — so the branch was laying an invisible object on an
// unwalkable table cell. Everything in the list below has geometry or a glb behind it
  static function decorateCubicleWalls(state: _CorpState, room: _Room)
    {
      var floor = Const.TILE_FLOOR_CUBICLE + UNWALKABLE_TILE_OFFSET;
      decorateWalls(state, room, [
          Const.CORP_CABINET,
        ], [
          Const.CORP_CABINET,
          Const.CORP_COOLER,
          Const.CORP_PLANT,
          Const.CORP_TRASH,
          Const.CORP_WHITEBOARD,
        ],
        floor, floor, 35, 0);
    }

// a server room: rows of racks with an aisle between them, and nothing soft in it
// RANKS OF CABINETS across a room, one row every `pitch`, never touching the boundary ring and
// always with one DEALT gap in each row — see the gap note inside. shared by the server room, the
// archive and the security room, which are the same rank with three different cabinet frames
  static function rackRows(state: _CorpState, node: _GenNode, room: _Room, tile: Int,
      deco: _TileGroup, chance: Int, maxRows: Int, pitch: Int)
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
          for (x in room.x1 + 1...room.x2)
            {
              if (x == gap ||
                  area.chance(chance))
                continue;
              cells[x][ry] = tile;
              addDecoration(state, x, ry, deco);
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

// --- the six kinds the floor was missing.
//
// THE FLOOR CARVES 29 ROOMS AND THE QUOTA ONLY EVER NAMED TEN OF THEM, so 19 rooms a floor came
// out as the open-plan FILLER: one template, one floor, and a median 16% of its cells furnished.
// Each of these borrows an EXISTING floor surface (render.corp.CorpModel.surfOf knows eight and
// there are no more), so a new kind costs no tile id, no texture, no material and no draw call —
// what makes it a different room is its furniture list and its fixture, which is what a reader in
// the room actually sees. NOT plain CARPET, ever: that surface is what CorpLamps.corridors() reads
// as circulation, and a room wearing it gets ceiling panels hung inside it (see `meeting`)

// a solo office: one desk across the middle, a cabinet and a plant in the corners. The small room
// the carve mints most of — 14.7 rooms a floor are under 5 on an axis and nothing else fits them
  public static function solo(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, CUBICLE);
      soloDesk(state, node, room);
      decorateCorners(state, room, [
          Const.CORP_TABLE_LAMP,
          Const.CORP_TABLE_FILES,
          Const.CORP_TABLE_STATIONERY,
        ], [
          Const.CORP_CABINET,
          Const.CORP_PLANT,
        ],
        Const.TILE_DARK_TABLE_WOOD2_1X1,
        Const.TILE_FLOOR_CUBICLE + UNWALKABLE_TILE_OFFSET,
        40);
    }

// the solo office's one desk: the open-plan floor's own 3x1 run, centred, with a chair behind it.
//
// SKIPPED WHERE IT WOULD SEAL A DOORWAY. A 3-wide room is exactly as wide as the desk, so the run
// reaches both side walls and an unwalkable table in front of a door walls the room off — which is
// the fault `atDoor` was written for one template over
  static function soloDesk(state: _CorpState, node: _GenNode, room: _Room)
    {
      deskRun(state, node, room, [
          Const.CORP_TABLE_MISC,
          Const.CORP_TABLE_LAMP,
          Const.CORP_TABLE_PHONE,
          Const.CORP_TABLE_FILES,
        ]);
    }

// one desk run across the middle of a room, with a chair in front of it and `full`'s decorations
// on it. the solo office's own desk, generalised: a copy room's copier bank and a security room's
// monitor bench are the same object with a different list of things standing on it
  static function deskRun(state: _CorpState, node: _GenNode, room: _Room,
      full: Array<_TileGroup>)
    {
      var area = state.area;
      var cells = area.getCells();
      var block = Const.CORP_TABLE_3X1;
      // A DESK THAT SPANS THE ROOM IS A WALL. The run was always three cells, and a solo office is
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

// a break room: the kitchen's own floor and counters, with the machines people stand at instead of
// the ones they cook with. The canteen is this room where the carve gave it the space for a second
// run of tables, and not a kind of its own — see gen.blocks.CorpBlocks.demands
  public static function breakRoom(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, WOOD1);
      // A 4-WIDE BREAK ROOM IS STILL A BREAK ROOM. It is dealt at minW/minH 4 on purpose (see
      // CorpBlocks) and `kitchenTables` wants 5 on both axes for its island, so every 4 x 9 one
      // came out as wall fixtures alone at 21.2% fill. Below the island it takes a counter run
      // instead, which is what a galley kitchenette is
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
          Const.CORP_TABLE_MUG,
          Const.CORP_TABLE_FRUIT,
          Const.CORP_TABLE_TISSUE,
        ], [
          Const.CORP_VENDING,
          Const.CORP_FRIDGE,
          Const.CORP_COOLER,
          Const.CORP_PLANT,
          Const.CORP_TRASH,
        ],
        Const.TILE_LIGHT_TABLE_WOOD1_1X1,
        Const.TILE_FLOOR_WOOD1 + UNWALKABLE_TILE_OFFSET,
        60, 30);
    }

// a copy room: both walls lined with copiers and stationery, and a clear floor to stand on. The
// one room in the tower that is ALL wall and no middle, which is what the highest `chance` in the
// file is for
  public static function copyRoom(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, WOOD2);
      // THE COPIER BANK DOWN THE MIDDLE WAS TRIED AND TAKEN BACK OUT, and the reason is the
      // `chance` two calls below: at 70 / 50 this room is the most heavily dressed in the tower
      // and it is dealt narrow, so the only cells joining its two halves are the ones most likely
      // to carry a cabinet. A centred run took its fill DOWN 29.4% -> 23.4% and a flush one to
      // 27.6% — both of them the repair pass eroding furniture to reach what the run had sealed.
      // A copy room is a corridor lined with copiers, which is what it already was
      decorateWalls(state, room, [
          Const.CORP_TABLE_PRINTER,
          Const.CORP_TABLE_STATIONERY,
          Const.CORP_TABLE_MISC_LARGE,
        ], [
          Const.CORP_CABINET,
          Const.CORP_MACHINERY,
          Const.CORP_TRASH,
        ],
        Const.TILE_DARK_TABLE_WOOD2_1X1,
        Const.TILE_FLOOR_WOOD2 + UNWALKABLE_TILE_OFFSET,
        70, 50);
    }

// an archive: the server room's rank-and-aisle with paper in it instead of machines
  public static function archive(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, SERVER);
      var shelf = Const.TILE_FLOOR_SERVER + UNWALKABLE_TILE_OFFSET;
      rackRows(state, node, room, shelf, Const.CORP_CABINET, 25, RACK_ROWS_MAX, RACK_PITCH);

      decorateWalls(state, room, [
          Const.CORP_TABLE_FILES,
          Const.CORP_TABLE_CONTAINER,
        ], [
          Const.CORP_CABINET,
          Const.CORP_TRASH,
        ],
        Const.TILE_DARK_TABLE_WOOD2_1X1,
        shelf,
        40, 40);
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
      drawBlock(cells, room.x1, room.y1, room.w, room.h, MARBLE1);
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
        Const.TILE_FLOOR_MARBLE1 + UNWALKABLE_TILE_OFFSET,
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
