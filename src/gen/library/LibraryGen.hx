// university library generation, the Game-free half
//
// the reading floor of the university library: one plate in a void, a corridor across it, the stair
// lobby and two reading halls south of the corridor, the stacks north of it, and the restricted
// archive in a north corner, walled off from the corridor and opening onto the stacks alone. The
// Necronomicon lies on the archive's lectern (game.LibraryAreaGenerator.enter).
//
// the lab's pattern (gen.lab.LabGen): FINAL ids only, no temp alphabet, no Subdivide, the plan laid
// in the plate's own fill and every room filled by gen.library.LibraryRooms. Like the lab and the
// corp floor it must never reach for a game.Game. See docs/area-gen.md.

package gen.library;

import gen.GenCtx;
import gen.GenTree;

class LibraryGen
{
  // the floor is generated at exactly this size: game.AreaGame.setType leaves it alone
  public static inline var WIDTH = 60;
  public static inline var HEIGHT = 44;

  // the area level and the room roles, verbatim in _Room.role; a room node's kind is 'room-' + role
  public static inline var PLATE = 'plate';
  public static inline var CORRIDOR = 'corridor';
  public static inline var ROLE_HALL = 'hall';
  public static inline var ROLE_LOBBY = 'lobby';
  public static inline var ROLE_STACKS = 'stacks';
  public static inline var ROLE_ARCHIVE = 'archive';

  // the first floor cell from the grid edge: the void ring, then the wall ring
  static inline var M = 2;
  // the lobby's width, and the archive's
  static inline var LOBBY_W_MIN = 10;
  static inline var LOBBY_W_MAX = 12;
  static inline var ARCHIVE_W_MIN = 9;
  static inline var ARCHIVE_W_MAX = 11;

// generate a whole floor into a context: void everywhere, then the plate and the walk
  public static function build(ctx: GenCtx): _LibraryState
    {
      var state: _LibraryState = {
        area: ctx,
        rooms: [],
        doors: [],
        stairs: null,
        lectern: null,
      };
      var cells = ctx.getCells();
      for (x in 0...ctx.width)
        for (y in 0...ctx.height)
          cells[x][y] = Const.TILE_LIB_VOID;
      GenTree.add(ctx.root, PLATE, 1, 1, ctx.width - 2, ctx.height - 2);
      GenTree.build(ctx.root, function(n) fill(state, n));
      return state;
    }

// build one node of the tree. The corridor is a leaf: what dresses it is render-side
  static function fill(state: _LibraryState, node: _GenNode)
    {
      if (node.kind == PLATE)
        plan(state, node);
      else if (node.roomID != null)
        LibraryRooms.fill(state, room(state, node.roomID));
    }

// lay the plate: the floors, the walls, the doorways and the stairs, and push the rooms
  static function plan(state: _LibraryState, node: _GenNode)
    {
      var a = state.area;
      var w = a.width;
      var h = a.height;
      var x1 = M;
      var x2 = w - 1 - M;
      var y1 = M;
      var y2 = h - 1 - M;
      // the corridor's two rows, then the north band above its wall and the south band below its wall
      var cy = Std.int(h / 2) + a.random(3) - 1;
      var ny2 = cy - 2;
      var sy1 = cy + 3;

      // south of the corridor: the lobby, a reading hall either side of it
      var lw = roll(a, LOBBY_W_MIN, LOBBY_W_MAX);
      var lx1 = Std.int((w - lw) / 2) + a.random(7) - 3;
      var lx2 = lx1 + lw - 1;
      var hallW = mk(1, ROLE_HALL, x1, sy1, lx1 - 2, y2);
      var lobby = mk(2, ROLE_LOBBY, lx1, sy1, lx2, y2);
      var hallE = mk(3, ROLE_HALL, lx2 + 2, sy1, x2, y2);

      // north of it: the archive in a corner, the whole band high, and the stacks beside it
      var aw = roll(a, ARCHIVE_W_MIN, ARCHIVE_W_MAX);
      var west = a.chance(50);
      var archive = (west ?
        mk(5, ROLE_ARCHIVE, x1, y1, x1 + aw - 1, ny2) :
        mk(5, ROLE_ARCHIVE, x2 - aw + 1, y1, x2, ny2));
      var stacks = (west ?
        mk(4, ROLE_STACKS, archive.x2 + 2, y1, x2, ny2) :
        mk(4, ROLE_STACKS, x1, y1, archive.x1 - 2, ny2));
      state.rooms = [ hallW, lobby, hallE, stacks, archive ];

      // floors, the corridor, then a wall on every void cell touching any of them
      var cells = a.getCells();
      for (r in state.rooms)
        rect(cells, r.x1, r.y1, r.x2, r.y2, floorOf(r.role));
      rect(cells, x1, cy, x2, cy + 1, Const.TILE_LIB_FLOOR_CORRIDOR);
      walls(a);

      // the doorways. the lobby opens on the corridor four wide, each hall and the stacks (twice)
      // through two cells of the corridor wall, and the archive through two cells of its wall onto
      // the stacks and nowhere else
      door(state, lobby.id, lobby.x1 + Std.int(lw / 2) - 2, cy + 2, 4, false);
      for (r in [ hallW, hallE ])
        door(state, r.id, r.x1 + 2 + a.random(r.w - 5), cy + 2, 2, false);
      var third = Std.int(stacks.w / 3);
      door(state, stacks.id, stacks.x1 + third - 1, cy - 1, 2, false);
      door(state, stacks.id, stacks.x2 - third, cy - 1, 2, false);
      door(state, archive.id, (west ? archive.x2 + 1 : archive.x1 - 1),
        archive.y1 + Std.int(archive.h / 2) - 1 + a.random(5) - 2, 2, true);

      // the stairs: their well against the lobby's south wall, the object on its corridor-side cell
      var sx = lobby.x1 + 2 + a.random(lw - 4);
      for (c in gen.corp.CorpTemp.stairsCells(sx, y2, sx, y2 + 1))
        cells[c.x][c.y] = Const.TILE_LIB_WELL;
      state.stairs = {
        x: sx,
        y: y2 - 1,
      };
      a.add('stairs', sx, y2 - 1);

      // the tree: the corridor, then the rooms, which LibraryRooms furnishes in the next level
      GenTree.add(node, CORRIDOR, x1, cy, x2, cy + 1);
      for (r in state.rooms)
        GenTree.add(node, 'room-' + r.role, r.x1, r.y1, r.x2, r.y2).roomID = r.id;
    }

// a doorway `len` cells long in a wall, down (vertical) or across, recorded once per doorway
  static function door(state: _LibraryState, roomID: Int, x: Int, y: Int, len: Int, vertical: Bool)
    {
      var cells = state.area.getCells();
      for (i in 0...len)
        cells[x + (vertical ? 0 : i)][y + (vertical ? i : 0)] = Const.TILE_LIB_DOOR;
      state.doors.push({
        x: x,
        y: y,
        dir: 0,
        roomID1: roomID,
        roomID2: 0,
        skip: false,
      });
    }

// every void cell touching floor on any of its eight sides becomes wall
  static function walls(a: GenCtx)
    {
      var cells = a.getCells();
      var open = [for (x in 0...a.width) [for (y in 0...a.height)
        cells[x][y] != Const.TILE_LIB_VOID]];
      for (x in 1...a.width - 1)
        for (y in 1...a.height - 1)
          {
            if (open[x][y])
              continue;
            for (i in 0...Const.dirx.length)
              if (open[x + Const.dirx[i]][y + Const.diry[i]])
                {
                  cells[x][y] = Const.TILE_LIB_WALL;
                  break;
                }
          }
    }

// the floor a room of this role is laid in
  public static function floorOf(role: String): Int
    {
      return switch (role)
        {
          case ROLE_HALL: Const.TILE_LIB_FLOOR_HALL;
          case ROLE_LOBBY: Const.TILE_LIB_FLOOR_LOBBY;
          case ROLE_STACKS: Const.TILE_LIB_FLOOR_STACKS;
          default: Const.TILE_LIB_FLOOR_ARCHIVE;
        };
    }

// the archive's lectern, off the finished grid: where the book lies
  public static function lectern(cells: Array<Array<Int>>): _Point
    {
      for (x in 0...cells.length)
        for (y in 0...cells[x].length)
          if (cells[x][y] == Const.TILE_LIB_LECTERN)
            return {
              x: x,
              y: y,
            };
      return null;
    }

// the librarian's post: the cell in front of (south of) the lectern
  public static function librarianPost(cells: Array<Array<Int>>): _Point
    {
      var l = lectern(cells);
      return (l == null ? null : {
        x: l.x,
        y: l.y + 1,
      });
    }

// the campus guard's post: the cell behind (north of) the circulation counter's second cell
  public static function counterPost(cells: Array<Array<Int>>): _Point
    {
      for (y in 0...cells[0].length)
        for (x in 0...cells.length)
          if (cells[x][y] == Const.TILE_LIB_COUNTER)
            return {
              x: x + 1,
              y: y - 1,
            };
      return null;
    }

  static function room(state: _LibraryState, id: Int): _Room
    {
      for (r in state.rooms)
        if (r.id == id)
          return r;
      return null;
    }

  static inline function roll(a: GenCtx, lo: Int, hi: Int): Int
    {
      return lo + a.random(hi - lo + 1);
    }

  static function mk(id: Int, role: String, x1: Int, y1: Int, x2: Int, y2: Int): _Room
    {
      return {
        id: id,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        w: x2 - x1 + 1,
        h: y2 - y1 + 1,
        role: role,
      };
    }

  static function rect(cells: Array<Array<Int>>, x1: Int, y1: Int, x2: Int, y2: Int, t: Int)
    {
      for (x in x1...x2 + 1)
        for (y in y1...y2 + 1)
          cells[x][y] = t;
    }
}

// what one library floor looks like while it is being built. Not persisted: the grid is saved
// verbatim and the rooms and doors are copied into game.AreaGame.generatorInfo by the live adapter
typedef _LibraryState = {
  // the grid being written, the seeded rng and the spawn list
  var area: GenCtx;
  // the west hall, the lobby, the east hall, the stacks and the archive, in that order (ids 1-5)
  var rooms: Array<_Room>;
  var doors: Array<_Door>;
  // the stairs object's cell, and the lectern's once the archive is furnished
  var stairs: _Point;
  var lectern: _Point;
}
