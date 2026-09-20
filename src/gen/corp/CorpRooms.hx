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
  // how far apart cubicle pods sit: 3 cells of desk plus one of gap along the run, and five rows
  // per back-to-back band (aisle, desk, spine, desk, aisle) plus one of gap between bands
  public static inline var POD_W = 4;
  public static inline var POD_BAND_H = 6;
  // and how far apart a server room's rack rows stand: a row of racks and an aisle to reach them
  public static inline var RACK_PITCH = 2;

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

// dress the two long walls of a room, never twice in a row and never beside a doorway.
//
// A CORNER ALWAYS TAKES ONE, whatever the roll says — that is the original's `hasLeft || isCorner`
// and it is load-bearing for the same reason the facility's is: a clue spawns on a bare cell and
// the corner is where its activation cross reaches two walls at once
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
          if (cells[room.x1 - 1][y] == BLDG_INNER_DOOR)
            hasLeft = false;
          if (prevLeft)
            {
              hasLeft = false;
              prevLeft = false;
            }
          if (hasLeft || isCorner)
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
          if (cells[room.x2 + 1][y] == BLDG_INNER_DOOR)
            hasRight = false;
          if (prevRight)
            {
              hasRight = false;
              prevRight = false;
            }
          if (hasRight || isCorner)
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

      var hasTable = false;
      if (room.w >= 6 &&
          room.h >= 6)
        {
          execDesk(state, node, room);
          hasTable = true;
        }
      if (room.w >= 7 ||
          !hasTable)
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

// the executive's own 3x2 desk, against whichever end wall has no door in it
  static function execDesk(state: _CorpState, node: _GenNode, room: _Room)
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
      if (hasNorthDoor && hasSouthDoor)
        return;

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
    }

// a meeting room: one long table in the middle, boards and a projector round the walls
  public static function meeting(state: _CorpState, node: _GenNode, room: _Room)
    {
      var cells = state.area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, CARPET_MEETING);
      if (room.w >= 6 &&
          room.h >= 6)
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
        Const.TILE_FLOOR_CARPET + UNWALKABLE_TILE_OFFSET,
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
      var tx = room.x1 + 2, ty = room.y1 + 2;
      var tw = room.w - 4, th = room.h - 4;
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
      if (room.w >= 6 &&
          room.h >= 6)
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
          if (sx + tableW >= room.x2)
            {
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

// a cubicle farm: bands of pods laid back to back against a shared spine.
//
// A BAND IS FIVE ROWS — aisle, desk, spine, desk, aisle — so two rows of people sit facing away
// from each other with one run of partition between them, which is what a cubicle farm IS. The
// spine cells are the room's floor made UNWALKABLE and carry no decoration: they are a mark, and
// render.corp.CorpCubicle is what stands a panel on them. Everything else here is the same 3x1
// desk and chair the open-plan template lays, because a cubicle is a desk with a wall round it
  public static function cubicle(state: _CorpState, node: _GenNode, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, CUBICLE);
      var spine = Const.TILE_FLOOR_CUBICLE + UNWALKABLE_TILE_OFFSET;
      var chairID = area.random(Const.CORP_CHAIR[0].amount);
      var computerID = area.random(Const.CORP_COMPUTERS_BLOCK.width);

      var band = 0;
      while (true)
        {
          band++;
          if (band > 20)
            break;
          // the band's spine row, with a desk row either side of it and an aisle beyond each
          var sy = room.y1 + 2 + (band - 1) * POD_BAND_H;
          if (sy + 2 > room.y2)
            break;

          var x = room.x1 + 1;
          while (x + 2 <= room.x2)
            {
              GenTree.add(node, CorpBlocks.ZONE_POD_ROW, x, sy - 1, x + 2, sy + 1);
              for (i in 0...3)
                cells[x + i][sy] = spine;
              // the two desks, one each side of the spine, and their chairs in the aisles
              for (s in 0...2)
                {
                  var dy = (s == 0 ? sy - 1 : sy + 1);
                  var cy = (s == 0 ? sy - 2 : sy + 2);
                  if (dy <= room.y1 - 1 || dy > room.y2)
                    continue;
                  var full = [
                    Const.CORP_TABLE_MISC,
                    Const.CORP_TABLE_LAMP,
                    Const.CORP_TABLE_PLANTS,
                    Const.CORP_TABLE_FILES,
                    Const.CORP_TABLE_STATIONERY,
                  ];
                  var deco = full.copy();
                  for (i in 0...3)
                    {
                      cells[x + i][dy] = Const.CORP_TABLE_3X1[i];
                      if (i == 1)
                        area.addDecoration(x + i, dy, Const.CORP_COMPUTERS_BLOCK.row,
                          Const.CORP_COMPUTERS_BLOCK.col + computerID);
                      else if (area.chance(45))
                        deco = addDecorationExt(state, x + i, dy, deco, full);
                    }
                  if (cy >= room.y1 && cy <= room.y2)
                    area.addDecoration(x + 1, cy, Const.CORP_CHAIR[0].row, chairID);
                }
              x += POD_W;
            }
        }

      // and the farm's own wall furniture: printers, boards, a cooler
      decorateWalls(state, room, [
          Const.CORP_TABLE_PRINTER,
          Const.CORP_TABLE_COFFEE,
          Const.CORP_TABLE_ROUTER,
        ], [
          Const.CORP_CABINET,
          Const.CORP_COOLER,
          Const.CORP_PLANT,
          Const.CORP_TRASH,
        ],
        Const.TILE_DARK_TABLE_WOOD2_1X1,
        Const.TILE_FLOOR_CUBICLE + UNWALKABLE_TILE_OFFSET,
        35, 40);
    }

// a server room: rows of racks with an aisle between them, and nothing soft in it
  public static function servers(state: _CorpState, node: _GenNode, room: _Room)
    {
      var area = state.area;
      var cells = area.getCells();
      drawBlock(cells, room.x1, room.y1, room.w, room.h, SERVER);
      var rack = Const.TILE_FLOOR_SERVER + UNWALKABLE_TILE_OFFSET;

      // rack rows run across the room's SHORT axis and are reached from the aisle beside them, so
      // a row is never more than one step from walkable floor
      var row = 0;
      while (true)
        {
          row++;
          if (row > 20)
            break;
          var ry = room.y1 + 1 + (row - 1) * RACK_PITCH;
          if (ry > room.y2 - 1)
            break;
          GenTree.add(node, CorpBlocks.ZONE_RACK_ROW, room.x1 + 1, ry, room.x2 - 1, ry);
          for (x in room.x1 + 1...room.x2)
            {
              // a gap every few racks, so a row reads as a rank of cabinets and not as a wall
              if (area.chance(20))
                continue;
              cells[x][ry] = rack;
              addDecoration(state, x, ry, Const.CORP_MACHINERY);
            }
        }

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

      // the basins are a continuous counter along the top wall
      GenTree.add(node, CorpBlocks.ZONE_BASIN_RUN, room.x1, room.y1, room.x2, room.y1);
      for (x in room.x1...room.x2 + 1)
        {
          if (cells[x][room.y1 - 1] == BLDG_INNER_DOOR)
            continue;
          cells[x][room.y1] = fixture;
          addDecoration(state, x, room.y1, Const.CORP_TAP);
        }

      // and the stalls are separate cells along the bottom one, every other cell so each has its
      // own doorway
      GenTree.add(node, CorpBlocks.ZONE_STALL_RUN, room.x1, room.y2, room.x2, room.y2);
      var x = room.x1;
      while (x <= room.x2)
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
