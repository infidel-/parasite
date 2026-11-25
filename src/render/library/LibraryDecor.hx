package render.library;

import three.Three;
import citygen.CityConfig;
import render.Models.PropPlace;
import render.RenderConfig;
import render.Textures;
import render.facility.ClutterSlot;
import render.facility.ClutterSlot.ClutterSlotTools;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// where LibraryDecor stood its glbs, one list per batch, and how many flat cut-outs it laid
typedef LibraryDecorSet = {
  lamps:Array<PropPlace>,   // the banker's lamps on the tables and the counter
  books:Array<Array<PropPlace>>, // every book of every stack, one list per cover (RenderConfig.MODELS.libraryBooks)
  baskets:Array<PropPlace>, // the wastepaper baskets
  decals:Int,               // books, journals, magazines and papers lying flat
};

// the library's DECOR SLOTS, render-only and rolled off the cell hash (FacilityModel.mix), so nothing
// is saved and a floor comes back identical on every rebuild:
//
//   * a READING TABLE'S top: up to two banker's lamps on its spine, sometimes a stack of books, then
//     four to seven flat cut-outs (library/desk-books, library/desk-papers) round them;
//   * the COUNTER'S top: a lamp at one end, often a stack of books, a few papers;
//   * a CARD CATALOGUE'S top: often a stack of books, a paper or two, now and then a lamp;
//   * a BOOKCASE'S or a stack rank's head, rarely: a stack of books lying up there;
//   * the WALL MARGIN of a bare cell backed onto the north, west or east wall (a hole in a bookcase
//     run, a lobby or stacks wall), clear of the doorways: a wastepaper basket or a pile of books,
//     standing where a bookcase would (the corp WALL_HUGGERS rule, so the cell stays walkable).
//
// A STACK is one to three single books (two or three on the floor), each its own cover, a little
// turned off the one below and laid exactly on its thickness, so no two books cut into each other.
// Everything on one top claims its box first (render.facility.ClutterSlot), the glbs before the
// cut-outs, so nothing lands on anything else
class LibraryDecor
{
  static inline var CELL = CityConfig.CELL;
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the table top and the counter top, their half extents (library_build.py), and how far in from the
  // edge anything lies
  static inline var TABLE_HW = 7.7;
  static inline var TABLE_HD = 3.7;
  static inline var COUNTER_HW = 7.95;
  static inline var COUNTER_HD = 1.3;
  static inline var EDGE = 0.45;
  // the lamps' spacing off the table's middle along its spine, and off the counter's along it
  static inline var TABLE_LAMP_X = 3.85;
  static inline var COUNTER_LAMP_X = 6.2;
  // a table's lamps: none on this many in a hundred, one on the next band, else two
  static inline var LAMP_NONE_PCT = 15;
  static inline var LAMP_ONE_PCT = 50;
  // a book stack on a table, on the counter, on a bookcase head this often
  static inline var TABLE_BOOKS_PCT = 40;
  static inline var COUNTER_BOOKS_PCT = 70;
  static inline var CASE_BOOKS_PCT = 12;
  // a catalogue's top: a book stack this often, a lamp this often, and up to this many papers
  static inline var CAT_BOOKS_PCT = 45;
  static inline var CAT_LAMP_PCT = 12;
  static inline var CAT_PAPERS = 2;
  // the glbs' footprints at their drawn size (decor_build.py's, by LibraryStyle's height over its own)
  static inline var LAMP_W = 1.14;
  static inline var LAMP_D = 0.61;
  // a stack's claim round its books' own turns, each book's turn off the stack's, its scale's spread
  // and the air between two books
  static inline var STACK_W = LibraryStyle.BOOK_W + 0.4;
  static inline var STACK_D = LibraryStyle.BOOK_D + 0.4;
  static inline var BOOK_TURN = 0.25;
  static inline var BOOK_SCALE = 0.9;
  static inline var BOOK_SCALE_VAR = 0.15;
  static inline var BOOK_GAP = 0.002;
  static inline var BASKET_W = 0.9;
  // a cut-out's size, the spread over it, how far over its top it lies, and the tries each gets
  static inline var DECAL_SZ = 2.2;
  static inline var DECAL_SZ_VAR = 0.6;
  static inline var DECAL_Y = 0.012;
  static inline var DECAL_TRIES = 14;
  // of a table's cut-outs, a book or journal this often (else a magazine or a paper); the counter's
  // are papers this often
  static inline var TABLE_BOOK_PCT = 55;
  // desk-books' cells dealt: its last, the reading glasses, came back with solid dark lenses and read
  // as two black dots on a table
  static inline var DESK_CELLS = 15;
  static inline var COUNTER_PAPER_PCT = 70;
  // the floor props: a bare wall-margin cell takes one this often by room role (corridor, hall, lobby,
  // stacks, archive), and it is a basket (else a pile of books) this often
  static var FLOOR_PCT = [ 0, 40, 45, 30, 50 ];
  static var BASKET_PCT = [ 0, 60, 85, 50, 30 ];
  // how far off the masonry a floor prop stands, and how far it may slide along its wall
  static inline var WALL_GAP = 0.08;
  static inline var SLIDE = 0.8;

// every slot on the floor. The cut-outs go into the scene as two meshes here; the glbs come back for
// the caller's batches, and the floor props' contact shadows are laid as they go, so call this before
// the contact field is repainted. `cases`, `stacks` and `catalogues` are the furniture plan's own
// placements
  public static function plan(scene:Scene, m:Facility, tile:(Int, Int)->Int,
      cases:Array<PropPlace>, stacks:Array<PropPlace>, catalogues:Array<PropPlace>):LibraryDecorSet
    {
      var out:LibraryDecorSet = {
        lamps: [],
        books: [for (_ in RenderConfig.MODELS.libraryBooks) []],
        baskets: [],
        decals: 0,
      };
      var desk = MeshBufTools.make();
      var papers = MeshBufTools.make();
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var t = tile(col, row);
            var c = CityConfig.cellToWorld(col, row);
            var h = FacilityModel.mix((col * 1103515245) ^ (row * 12345) ^ 0x1b873593);
            if (t == Const.TILE_LIB_TABLE &&
                tile(col - 1, row) != Const.TILE_LIB_TABLE &&
                tile(col, row - 1) != Const.TILE_LIB_TABLE)
              {
                // the 4x2 block's top, from its north-west cell
                var x = c.x + 1.5 * CELL;
                var z = c.z + 0.5 * CELL;
                var slots:Array<ClutterSlot> = [];
                var nl = ((h >>> 3) % 100 < LAMP_NONE_PCT ? 0 : ((h >>> 3) % 100 < LAMP_ONE_PCT ? 1 : 2));
                for (i in 0...nl)
                  {
                    var lx = (nl == 1 ? ((h >>> 10) % 2 == 0 ? -1 : 1) : (i == 0 ? -1 : 1)) * TABLE_LAMP_X;
                    lamp(out, slots, x + lx, z, LibraryStyle.TABLE_H, FacilityModel.mix(h + i * 31));
                  }
                if ((h >>> 12) % 100 < TABLE_BOOKS_PCT)
                  topBooks(out, slots, x, z, TABLE_HW, TABLE_HD, LibraryStyle.TABLE_H, h);
                out.decals += scatter(desk, papers, slots, x, z, TABLE_HW, TABLE_HD,
                  LibraryStyle.TABLE_H, 4 + (h >>> 16) % 4, TABLE_BOOK_PCT, h);
              }
            else if (t == Const.TILE_LIB_COUNTER &&
                tile(col - 1, row) != Const.TILE_LIB_COUNTER)
              {
                var x = c.x + 1.5 * CELL;
                var slots:Array<ClutterSlot> = [];
                lamp(out, slots, x + ((h >>> 10) % 2 == 0 ? -1 : 1) * COUNTER_LAMP_X, c.z,
                  LibraryStyle.COUNTER_H, h);
                if ((h >>> 12) % 100 < COUNTER_BOOKS_PCT)
                  topBooks(out, slots, x, c.z, COUNTER_HW, COUNTER_HD, LibraryStyle.COUNTER_H, h);
                out.decals += scatter(desk, papers, slots, x, c.z, COUNTER_HW, COUNTER_HD,
                  LibraryStyle.COUNTER_H, 2 + (h >>> 16) % 3, 100 - COUNTER_PAPER_PCT, h);
              }
            else if (LibraryStyle.isFloor(t))
              floorProp(out, m, tile, col, row, h);
          }
      // a catalogue's top: its own claims, the lamp first, then the books, then the papers
      for (p in catalogues)
        {
          var h = FacilityModel.mix(Std.int(p.x * 197) ^ (Std.int(p.z * 641) << 9) ^ 0x5c1);
          // the top's half extents in the world: a side-wall catalogue stands turned a quarter
          var turned = (Math.abs(Math.sin(p.yaw)) > 0.5);
          var hw = (turned ? LibraryStyle.CATALOGUE_D : LibraryStyle.CATALOGUE_W) / 2;
          var hd = (turned ? LibraryStyle.CATALOGUE_W : LibraryStyle.CATALOGUE_D) / 2;
          var slots:Array<ClutterSlot> = [];
          if ((h >>> 3) % 100 < CAT_LAMP_PCT)
            lamp(out, slots, p.x + ((h >>> 10) % 2 == 0 ? -1 : 1) * (hw - LAMP_W / 2 - EDGE), p.z,
              LibraryStyle.CATALOGUE_H, h);
          if ((h >>> 12) % 100 < CAT_BOOKS_PCT)
            topBooks(out, slots, p.x, p.z, hw, hd, LibraryStyle.CATALOGUE_H, h);
          out.decals += scatter(desk, papers, slots, p.x, p.z, hw, hd, LibraryStyle.CATALOGUE_H,
            (h >>> 16) % (CAT_PAPERS + 1), 0, h);
        }
      // a stack of books lying on a bookcase's or a rank's head, now and then
      for (list in [ cases, stacks ])
        for (p in list)
          {
            var h = FacilityModel.mix(Std.int(p.x * 131) ^ (Std.int(p.z * 977) << 9) ^ 0x7e3);
            if ((h >>> 3) % 100 >= CASE_BOOKS_PCT)
              continue;
            var w = (list == cases ? LibraryStyle.CASE_W : LibraryStyle.STACK_W);
            var a = (((h >>> 8) % 1001) / 1000 - 0.5) * (w - STACK_D);
            stack(out, p.x + a * Math.cos(p.yaw), p.z - a * Math.sin(p.yaw), LibraryStyle.CASE_H,
              p.yaw + Math.PI / 2 + (((h >>> 18) % 1001) / 1000 - 0.5) * 0.6, 1 + (h >>> 22) % 3, h);
          }
      add(scene, desk, LibraryStyle.DESK_BOOKS);
      add(scene, papers, LibraryStyle.DESK_PAPERS);
      return out;
    }

// one cut-out off each sheet at the origin, for LibraryArea.warm
  public static function warm(scene:Scene):Void
    {
      for (s in [ LibraryStyle.DESK_BOOKS, LibraryStyle.DESK_PAPERS ])
        {
          var b = MeshBufTools.make();
          emit(b, 0.0, 0.0, 1.0, 0.0, 0, 1.0);
          add(scene, b, s);
        }
    }

// a lamp on a top at (x, z), its shade along x turned to face one side of it, a little off square
  static function lamp(out:LibraryDecorSet, slots:Array<ClutterSlot>, x:Float, z:Float, y:Float,
      h:Int):Void
    {
      var yaw = ((h >>> 4) % 2 == 0 ? 0.0 : Math.PI) + (((h >>> 6) % 1001) / 1000 - 0.5) * 0.3;
      slots.push(ClutterSlotTools.turned(x, z, LAMP_W, LAMP_D, yaw));
      out.lamps.push({
        x: x,
        z: z,
        yaw: yaw,
        y: y,
      });
    }

// a stack of books somewhere on a top clear of what already stands on it, or none if nowhere is
  static function topBooks(out:LibraryDecorSet, slots:Array<ClutterSlot>, x:Float, z:Float, hw:Float,
      hd:Float, y:Float, h:Int):Void
    {
      for (k in 0...DECAL_TRIES)
        {
          var r = FacilityModel.mix(h + k * 104729);
          var yaw = ((r >>> 4) % 628) / 100;
          var b = ClutterSlotTools.turned(0, 0, STACK_W, STACK_D, yaw);
          var bx = x + (((r >>> 12) % 1001) / 1000 - 0.5) * 2 * (hw - EDGE - b.hw);
          var bz = z + (((r >>> 22) % 1001) / 1000 - 0.5) * 2 * (hd - EDGE - b.hd);
          if (ClutterSlotTools.hits(slots, bx, bz, b.hw, b.hd))
            continue;
          slots.push(ClutterSlotTools.turned(bx, bz, STACK_W, STACK_D, yaw));
          stack(out, bx, bz, y, yaw, 1 + (r >>> 2) % 3, r);
          return;
        }
    }

// a stack of `n` books standing on `y` at (x, z), turned `yaw`, each its own cover, turn and scale,
// laid on the one below's own thickness. Returns its height
  static function stack(out:LibraryDecorSet, x:Float, z:Float, y:Float, yaw:Float, n:Int, h:Int):Float
    {
      var top = y;
      for (i in 0...n)
        {
          var r = FacilityModel.mix(h + 0x2545f491 + i * 6151);
          var s = BOOK_SCALE + ((r >>> 4) % 101) / 100 * BOOK_SCALE_VAR;
          out.books[(r >>> 12) % out.books.length].push({
            x: x,
            z: z,
            yaw: yaw + (((r >>> 16) % 1001) / 1000 - 0.5) * 2 * BOOK_TURN,
            y: top,
            scale: s,
          });
          top += LibraryStyle.BOOK_T * s + BOOK_GAP;
        }
      return top - y;
    }

// `want` cut-outs over a top, each off desk-books on `bookPct` in a hundred (else desk-papers), at a
// free turn and spot clear of the claims. Returns how many landed
  static function scatter(desk:MeshBuf, papers:MeshBuf, slots:Array<ClutterSlot>, x:Float, z:Float,
      hw:Float, hd:Float, y:Float, want:Int, bookPct:Int, h:Int):Int
    {
      var n = 0;
      var k = 0;
      while (n < want &&
          k < want * DECAL_TRIES)
        {
          var r = FacilityModel.mix(h + 0x3c6ef372 + k * 7919);
          k++;
          var sz = DECAL_SZ + (r % 11) * DECAL_SZ_VAR / 10;
          var yaw = ((r >>> 4) % 628) / 100;
          // a cell's art fills about 0.85 of it, so that is the box claimed
          var b = ClutterSlotTools.turned(0, 0, sz * 0.85, sz * 0.85, yaw);
          var dx = x + (((r >>> 10) % 1001) / 1000 - 0.5) * 2 * (hw - EDGE - b.hw);
          var dz = z + (((r >>> 20) % 1001) / 1000 - 0.5) * 2 * (hd - EDGE - b.hd);
          if (ClutterSlotTools.hits(slots, dx, dz, b.hw, b.hd))
            continue;
          slots.push(ClutterSlotTools.turned(dx, dz, sz * 0.85, sz * 0.85, yaw));
          var book = ((r >>> 26) % 100 < bookPct);
          emit((book ? desk : papers), dx, dz, sz, yaw, (r >>> 14) % (book ? DESK_CELLS : 16),
            y + DECAL_Y + n * 0.002);
          n++;
        }
      return n;
    }

// a basket or a pile of books standing in the wall margin of a bare cell backed onto masonry to its
// north, west or east, clear of the doorways, on its room's odds
  static function floorProp(out:LibraryDecorSet, m:Facility, tile:(Int, Int)->Int, col:Int, row:Int,
      h:Int):Void
    {
      var role = roleOf(m.surf[row][col]);
      if ((h >>> 3) % 100 >= FLOOR_PCT[role])
        return;
      var dir = -1;
      for (d in [ 0, 2, 3 ])
        if (dir < 0 &&
            FacilityModel.isSolidWall(m, col + DC[d], row + DR[d]))
          dir = d;
      if (dir < 0)
        return;
      for (dx in -1...2)
        for (dy in -1...2)
          if (tile(col + dx, row + dy) == Const.TILE_LIB_DOOR)
            return;
      var basket = ((h >>> 10) % 100 < BASKET_PCT[role]);
      var size = (basket ? BASKET_W : STACK_D);
      var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
      var c = CityConfig.cellToWorld(col, row);
      var slide = (((h >>> 14) % 1001) / 1000 - 0.5) * 2 * SLIDE;
      var off = size / 2 + WALL_GAP;
      var x = (dir == 0 ? c.x + slide : (dir == 2 ? s.x1 + off : s.x0 - off));
      var z = (dir == 0 ? s.z1 + off : c.z + slide);
      var yaw = ((h >>> 20) % 628) / 100;
      var tall = LibraryStyle.BASKET_H;
      if (basket)
        out.baskets.push({
          x: x,
          z: z,
          yaw: yaw,
        });
      else
        tall = stack(out, x, z, 0.0, yaw, 2 + (h >>> 26) % 2, h);
      var r = size / 2;
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: 1,
        alongX: true,
        rect: {
          x0: x - r,
          x1: x + r,
          z0: z - r,
          z1: z + r,
        },
        h: tall,
      });
    }

// the room role a cell's surface names, as FLOOR_PCT's index
  static function roleOf(s:Surf):Int
    {
      return switch (s)
        {
          case Surf.LIB_HALL: 1;
          case Surf.LIB_LOBBY: 2;
          case Surf.LIB_STACKS: 3;
          case Surf.LIB_ARCHIVE: 4;
          default: 0;
        }
    }

// one flat cut-out at (x, y, z), `sz` across, turned `yaw`, showing cell `idx` of a 4x4 sheet.
// render.corp.CorpClutter.emit's, copied for that file's reason (LabDecals does the same)
  static function emit(b:MeshBuf, x:Float, z:Float, sz:Float, yaw:Float, idx:Int, y:Float):Void
    {
      var hs = sz * 0.5;
      var cs = Math.cos(yaw);
      var sn = Math.sin(yaw);
      var lx = [ -hs, hs, hs, -hs ];
      var lz = [ hs, hs, -hs, -hs ];
      var wx = [];
      var wz = [];
      for (i in 0...4)
        {
          wx.push(x + lx[i] * cs - lz[i] * sn);
          wz.push(z + lx[i] * sn + lz[i] * cs);
        }
      var cc = idx % 4;
      var cr = Std.int(idx / 4);
      var u0 = cc / 4;
      var u1 = (cc + 1) / 4;
      var v0 = 1 - (cr + 1) / 4;
      var v1 = 1 - cr / 4;
      MeshBufTools.quad(b,
        [wx[0], y, wz[0]], [wx[1], y, wz[1]], [wx[2], y, wz[2]], [wx[3], y, wz[3]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// one sheet's cut-outs as one mesh, on render.corp.CorpClutter.add's material for its reasons: an
// opaque alphaTest draws DoubleSide in one pass, still writes depth, and keeps the vision mask on its
// darkening branch
  static function add(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        alphaTest: LibraryStyle.DECAL_CUT,
        side: THREE.DoubleSide,
      });
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(mat));
      mesh.name = 'library decals ' + tex;
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
