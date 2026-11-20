// the library's furniture, a cell per piece, written as final Const.TILE_LIB_* ids
//
// - a HALL: bookcases on its north, west and east walls in short runs, a bay of reading tables with
//   chairs on both long sides to one side, and short ranks of back-to-back shelving filling the rest;
// - the LOBBY: the circulation counter, card catalogues on its side walls and a back-to-back island
//   (the stairs are the plan's);
// - the STACKS: a maze of full-height rank columns, broken by rolled gaps into short runs;
// - the ARCHIVE: bookcases on its walls, the lectern in the middle with a clear ring round it, and
//   ranks above and below that ring.
//
// THE AISLE IS THE INVARIANT, as in the corp archive (docs/area-gen.md): a rank or a table only
// takes a cell whose eight neighbours are all its room's own floor, so a ring of floor runs round
// every wall and every doorway opens onto it. Nothing here needs a reachability repair.
//
// NO SOUTH-WALL DRESSING: the camera looks north, so a piece against a south wall hides the room.

package gen.library;

import gen.GenCtx;
import gen.library.LibraryGen;

class LibraryRooms
{
  // the reading table, cells along x and deep along y, and the gap between two along a row
  static inline var TABLE_L = 4;
  static inline var TABLE_GAP = 2;
  // a chair is left out (pushed back, taken away) this often
  static inline var CHAIR_SKIP_PCT = 20;
  // a stack rank's runs between gaps, and how often a gap is two cells instead of one
  static inline var RUN_MIN = 2;
  static inline var RUN_MAX = 4;
  // a wall bookcase run, before the one-cell hole that ends it
  static inline var CASE_RUN = 3;
  static inline var WIDE_GAP_PCT = 20;
  // the card catalogue's run along a lobby side wall
  static inline var CATALOGUE_L = 3;
  // the counter's length
  static inline var COUNTER_L = 4;

// furnish one room by its role
  public static function fill(state: _LibraryState, r: _Room)
    {
      switch (r.role)
        {
          case LibraryGen.ROLE_HALL:
            hall(state.area, r);
          case LibraryGen.ROLE_LOBBY:
            lobby(state, r);
          case LibraryGen.ROLE_STACKS:
            ranks(state.area, r, -1);
          case LibraryGen.ROLE_ARCHIVE:
            archive(state, r);
          default:
        }
    }

// a reading hall: wall bookcases, then a bay of table rows (chair, table, table, chair, aisle) on one
// side inside the bookcase ring and its aisle, and short back-to-back ranks over the rest of it. The
// bay takes all the table columns that fit but one, at least one
  static function hall(a: GenCtx, r: _Room)
    {
      bookcases(a, r);
      var cells = a.getCells();
      var iw = r.w - 4;
      var cols = Std.int(Math.max(1,
        Std.int((iw + TABLE_GAP) / (TABLE_L + TABLE_GAP)) - 1));
      var bay = cols * (TABLE_L + TABLE_GAP) - TABLE_GAP;
      var west = a.chance(50);
      var x0 = (west ? r.x1 + 2 : r.x2 - 1 - bay);
      var ih = r.h - 3;
      var rows = Std.int((ih + 1) / 5);
      var y0 = r.y1 + 2 + Std.int((ih - (rows * 5 - 1)) / 2);
      for (row in 0...rows)
        for (col in 0...cols)
          {
            var ty = y0 + row * 5;
            var tx = x0 + col * (TABLE_L + TABLE_GAP);
            for (dx in 0...TABLE_L)
              {
                var x = tx + dx;
                cells[x][ty + 1] = Const.TILE_LIB_TABLE;
                cells[x][ty + 2] = Const.TILE_LIB_TABLE;
                for (cy in [ ty, ty + 3 ])
                  if (!a.chance(CHAIR_SKIP_PCT))
                    cells[x][cy] = Const.TILE_LIB_CHAIR;
              }
          }

      // the shelving beside the bay, its ranks' columns at a pitch of two from the far edge in
      var sx1 = (west ? x0 + bay + TABLE_GAP : r.x1 + 2);
      var sx2 = (west ? r.x2 - 2 : x0 - 1 - TABLE_GAP);
      ranksIn(a, r, sx1, sx2, -1);
    }

// the lobby: the counter on the half away from the stairs, a catalogue run on each side wall
  static function lobby(state: _LibraryState, r: _Room)
    {
      var a = state.area;
      var cells = a.getCells();
      var mid = r.x1 + Std.int(r.w / 2);
      var cx = (state.stairs.x < mid ? r.x2 - 1 - COUNTER_L : r.x1 + 2);
      var cy = r.y2 - 3;
      for (dx in 0...COUNTER_L)
        cells[cx + dx][cy] = Const.TILE_LIB_COUNTER;
      var y0 = r.y1 + 3 + a.random(r.h - 9);
      for (x in [ r.x1, r.x2 ])
        for (dy in 0...CATALOGUE_L)
          cells[x][y0 + dy] = Const.TILE_LIB_CATALOGUE;

      // and a back-to-back catalogue island in the north half, centred, an aisle round it
      var ix = mid - Std.int(CATALOGUE_L / 2);
      for (dx in 0...CATALOGUE_L)
        for (dy in 0...2)
          cells[ix + dx][r.y1 + 3 + dy] = Const.TILE_LIB_CATALOGUE;
    }

// the archive: bookcases, the lectern in the middle, ranks above and below its clear ring
  static function archive(state: _LibraryState, r: _Room)
    {
      var a = state.area;
      bookcases(a, r);
      var lx = r.x1 + Std.int(r.w / 2);
      var ly = r.y1 + Std.int(r.h / 2);
      ranks(a, r, ly);
      a.getCells()[lx][ly] = Const.TILE_LIB_LECTERN;
      state.lectern = {
        x: lx,
        y: ly,
      };
    }

// bookcases on every floor cell with masonry to its north, west or east, clear of the doorways, in
// runs of CASE_RUN along each wall with a one-cell hole between
  static function bookcases(a: GenCtx, r: _Room)
    {
      var cells = a.getCells();
      for (x in r.x1...r.x2 + 1)
        for (y in r.y1...r.y2 + 1)
          {
            if (cells[x][y] != LibraryGen.floorOf(r.role))
              continue;
            if (cells[x][y - 1] != Const.TILE_LIB_WALL &&
                cells[x - 1][y] != Const.TILE_LIB_WALL &&
                cells[x + 1][y] != Const.TILE_LIB_WALL)
              continue;
            if (nearDoor(cells, x, y))
              continue;
            var along = (cells[x][y - 1] == Const.TILE_LIB_WALL ? x - r.x1 : y - r.y1);
            if (along % (CASE_RUN + 1) == CASE_RUN)
              continue;
            cells[x][y] = Const.TILE_LIB_BOOKCASE;
          }
    }

// rank columns over a whole room
  static function ranks(a: GenCtx, r: _Room, ringY: Int)
    {
      ranksIn(a, r, r.x1 + 1, r.x2 - 1, ringY);
    }

// rank columns at a pitch of two across columns x1..x2, from x2 in so the last column sits on the
// span's far edge, broken into runs by rolled gaps. A cell takes a rank only when all eight neighbours
// are bare floor of this room (the aisle invariant). `ringY` >= 0 keeps the three rows round it clear
// on each side (the archive's lectern ring)
  static function ranksIn(a: GenCtx, r: _Room, x1: Int, x2: Int, ringY: Int)
    {
      var cells = a.getCells();
      var floor = LibraryGen.floorOf(r.role);
      var x = x1 + (x2 - x1) % 2;
      while (x <= x2)
        {
          var y = r.y1 + 1;
          var run = RUN_MIN + a.random(RUN_MAX - RUN_MIN + 1);
          while (y <= r.y2 - 1)
            {
              if (run > 0)
                {
                  if ((ringY < 0 ||
                      Math.abs(y - ringY) > 3) &&
                      clear(cells, x, y, floor))
                    cells[x][y] = Const.TILE_LIB_STACK;
                  run--;
                  y++;
                  continue;
                }
              y += (a.chance(WIDE_GAP_PCT) ? 2 : 1);
              run = RUN_MIN + a.random(RUN_MAX - RUN_MIN + 1);
            }
          x += 2;
        }
    }

// are the eight cells round (x,y) this room's bare floor, or a rank already laid this pass?
  static function clear(cells: Array<Array<Int>>, x: Int, y: Int, floor: Int): Bool
    {
      for (i in 0...Const.dirx.length)
        {
          var t = cells[x + Const.dirx[i]][y + Const.diry[i]];
          if (t != floor &&
              t != Const.TILE_LIB_STACK)
            return false;
        }
      return true;
    }

// is a doorway cell within one cell of (x,y), on any side?
  static function nearDoor(cells: Array<Array<Int>>, x: Int, y: Int): Bool
    {
      for (dx in -1...2)
        for (dy in -1...2)
          if (cells[x + dx][y + dy] == Const.TILE_LIB_DOOR)
            return true;
      return false;
    }
}
