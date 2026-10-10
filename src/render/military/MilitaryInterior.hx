package render.military;

import citygen.CityConfig;
import game.AreaGame;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.world.MeshBuf.MeshBufTools;

// a military base's room furniture, emitted off the row-20 tiles gen.military.MilitaryRooms stands:
// bunks and footlockers, mess and briefing tables with their benches, the serving counter, the map
// board, HQ desks and filing cabinets, latrine cubicles and the trough. All of it is slabs, so all of
// it is quads into render.military.MilitaryGeom's per-texture buffers, one texture per face
// (docs/3d-geometry.md), and one FacilityDetail.ground per RUN.
//
// a run is the longest straight line of one tile, x tried first: the generator never puts two runs
// of one tile side by side, but a desk on each of two walls can meet at the room's corner, and
// the cells a run takes are marked so the second desk is not read as the tail of the first
class MilitaryInterior
{
  static inline var CELL = CityConfig.CELL;

  // the base's own steels (mil-pack-n): grey enamel for furniture frames, gunmetal for cabinets
  static inline var TEX_ENAMEL = 'textures/military/enamel.png';
  static inline var TEX_GUNMETAL = 'textures/military/gunmetal.png';
  // a footlocker's sides are the crate's olive planks: it is a wooden box
  static inline var TEX_PLANKS = 'textures/military/crate-side.png';
  static inline var TEX_STAINLESS = 'textures/military/steel.png';
  static inline var TEX_BLANKET = 'textures/military/blanket.png';
  static inline var TEX_LAMINATE = 'textures/military/laminate.png';
  static inline var TEX_DARKWOOD = 'textures/military/darkwood.png';
  static inline var TEX_BENCH = 'textures/military/bench-wood.png';
  static inline var TEX_STALL = 'textures/military/stall-panel.png';
  static inline var TEX_STALL_DOOR = 'textures/military/stall-door.png';
  static inline var TEX_FILE = 'textures/military/file-front.png';
  static inline var TEX_FOOT_LID = 'textures/military/footlocker-lid.png';
  static inline var TEX_BOARD = 'textures/military/map-board.png';

  // a table's top and how wide it stands across its cell; the lab worktop is BENCH_H 2.0
  static inline var TABLE_H = 1.9;
  static inline var TABLE_W = 2.8;
  static inline var TOP_T = 0.15;
  static inline var LEG_W = 0.3;
  // a bench beside it
  static inline var BENCH_H = 1.1;
  static inline var BENCH_W = 1.3;
  // a bunk: two decks, a post at each corner
  static inline var BUNK_W = 2.8;
  static inline var DECK_LO = 0.9;
  static inline var DECK_HI = 2.7;
  static inline var DECK_T = 0.45;
  static inline var POST_H = 3.4;
  static inline var POST_W = 0.2;
  // a footlocker, lid 0..1 over its top
  static inline var FOOT_W = 2.6;
  static inline var FOOT_D = 1.7;
  static inline var FOOT_H = 1.0;
  // wall-backed pieces: depth off the wall's room face, and height
  static inline var COUNTER_D = 2.2;
  static inline var COUNTER_H = 2.0;
  static inline var TROUGH_D = 1.6;
  static inline var TROUGH_H = 1.8;
  static inline var DESK_D = 2.2;
  static inline var DESK_SIDE = 0.5;
  // a filing cabinet's front is a SQUARE crop (military/file-front), so its height is its width
  static inline var FILE_W = 2.2;
  static inline var FILE_D = 1.8;
  // a cubicle's door is military/stall-door's 512x510, over the cell's whole width
  static inline var STALL_H = CELL * 510 / 512;
  static inline var STALL_D = CELL * 0.95;
  static inline var STALL_T = 0.1;
  // the map board, a square, hung off the wall face
  static inline var BOARD_W = 3.2;
  static inline var BOARD_Y = 1.4;
  static inline var BOARD_OFF = 0.05;

  // the step from a cell to its wall on each side: -z, +z, -x, +x (CorpFurniture.lockerRect's)
  static var DX = [ 0, 0, -1, 1 ];
  static var DZ = [ -1, 1, 0, 0 ];

// emit every piece in the base's rooms
  public static function build(m:Facility, area:AreaGame):Void
    {
      var taken = [for (_ in 0...area.height) [for (_ in 0...area.width) false]];
      for (row in 0...area.height)
        for (col in 0...area.width)
          {
            var t = area.getCellType(col, row);
            if (t < Const.TILE_MIL_BUNK ||
                t > Const.TILE_MIL_TROUGH ||
                taken[row][col])
              continue;
            // the run: along x if the next cell is the same, down z otherwise
            var len = 1;
            while (area.getCellType(col + len, row) == t &&
                !taken[row][col + len])
              len++;
            var alongX = (len > 1);
            if (!alongX)
              while (area.getCellType(col, row + len) == t &&
                  !taken[row + len][col])
                len++;
            for (i in 0...len)
              taken[row + (alongX ? 0 : i)][col + (alongX ? i : 0)] = true;
            piece(m, t, col, row, len, alongX);
          }
    }

// one run of one tile
  static function piece(m:Facility, t:Int, col:Int, row:Int, len:Int, alongX:Bool):Void
    {
      var x0 = col * CELL - half();
      var z0 = row * CELL - half();
      var cell = {
        x0: x0,
        x1: x0 + (alongX ? len : 1) * CELL,
        z0: z0,
        z1: z0 + (alongX ? 1 : len) * CELL,
      };
      var r:Rect = null;
      var h = 0.0;
      if (t == Const.TILE_MIL_BUNK)
        {
          r = across(cell, alongX, BUNK_W);
          h = POST_H;
          bunk(r);
        }
      else if (t == Const.TILE_MIL_FOOTLOCKER)
        {
          r = across(across(cell, true, FOOT_D), false, FOOT_W);
          h = FOOT_H;
          footlocker(r);
        }
      else if (t == Const.TILE_MIL_MESS_TABLE ||
          t == Const.TILE_MIL_BRIEF_TABLE)
        {
          r = across(cell, alongX, TABLE_W);
          h = TABLE_H;
          table(r, alongX, (t == Const.TILE_MIL_MESS_TABLE ? TEX_LAMINATE : TEX_DARKWOOD), TABLE_H);
        }
      else if (t == Const.TILE_MIL_BENCH)
        {
          r = across(cell, alongX, BENCH_W);
          h = BENCH_H;
          table(r, alongX, TEX_BENCH, BENCH_H);
        }
      else
        {
          // the rest stand against a wall: the side of the run's first cell that is one, along the
          // run for a run, any side for a single
          var dir = -1;
          for (d in (len == 1 ? [ 0, 1, 2, 3 ] : (alongX ? [ 0, 1 ] : [ 2, 3 ])))
            if (dir < 0 &&
                FacilityModel.isWall(m, col + DX[d], row + DZ[d]))
              dir = d;
          if (dir < 0)
            return;
          if (t == Const.TILE_MIL_COUNTER ||
              t == Const.TILE_MIL_TROUGH)
            {
              var counter = (t == Const.TILE_MIL_COUNTER);
              r = back(m, col, row, cell, dir, (counter ? COUNTER_D : TROUGH_D));
              h = (counter ? COUNTER_H : TROUGH_H);
              MilitaryGeom.box(MilitaryGeom.buf(TEX_STAINLESS), r.x0, r.x1, r.z0, r.z1, 0, h,
                CELL);
            }
          else if (t == Const.TILE_MIL_DESK)
            {
              r = back(m, col, row, cell, dir, DESK_D);
              h = TABLE_H;
              desk(r, dir);
            }
          else if (t == Const.TILE_MIL_FILE)
            {
              r = across(back(m, col, row, cell, dir, FILE_D), dir >= 2, FILE_W);
              h = FILE_W;
              front(r, dir, TEX_FILE, FILE_W, TEX_GUNMETAL);
            }
          else if (t == Const.TILE_MIL_STALL)
            {
              r = back(m, col, row, cell, dir, STALL_D);
              h = STALL_H;
              stalls(r, dir, len);
            }
          else if (t == Const.TILE_MIL_MAP_BOARD)
            {
              // hung on the wall, nothing on the floor to shadow
              var b = across(back(m, col, row, cell, dir, BOARD_OFF), dir >= 2, BOARD_W);
              FacilityGeom.pane(MilitaryGeom.buf(TEX_BOARD), b.x0, b.x1, b.z0, b.z1, dir ^ 1,
                BOARD_Y, BOARD_Y + BOARD_W);
              return;
            }
        }
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: len,
        alongX: alongX,
        rect: r,
        h: h,
      });
    }

// a two-deck bunk over its rect: a post at each corner and the two blanketed decks between them
  static function bunk(r:Rect):Void
    {
      var steel = MilitaryGeom.buf(TEX_ENAMEL);
      var bed = MilitaryGeom.buf(TEX_BLANKET);
      for (px in [ r.x0, r.x1 - POST_W ])
        for (pz in [ r.z0, r.z1 - POST_W ])
          MilitaryGeom.box(steel, px, px + POST_W, pz, pz + POST_W, 0, POST_H, CELL);
      for (y in [ DECK_LO, DECK_HI ])
        MilitaryGeom.box(bed, r.x0 + POST_W, r.x1 - POST_W, r.z0 + POST_W, r.z1 - POST_W, y,
          y + DECK_T, CELL);
    }

// a footlocker: an olive plank box, its stencilled lid 0..1 over the top
  static function footlocker(r:Rect):Void
    {
      var planks = MilitaryGeom.buf(TEX_PLANKS);
      for (d in 0...4)
        FacilityGeom.face(planks, r.x0, r.x1, r.z0, r.z1, d, 0, FOOT_H, CELL);
      MeshBufTools.quad(MilitaryGeom.buf(TEX_FOOT_LID), [r.x0, FOOT_H, r.z1], [r.x1, FOOT_H, r.z1],
        [r.x1, FOOT_H, r.z0], [r.x0, FOOT_H, r.z0], [0, 0, 1, 0, 1, 1, 0, 1]);
    }

// a table or a bench: its top slab in its own material, grain along the run, and a steel trestle
// under each end
  static function table(r:Rect, alongX:Bool, tex:String, y:Float):Void
    {
      var top = MilitaryGeom.buf(tex);
      FacilityGeom.cap(top, r.x0, r.x1, r.z0, r.z1, y, CELL, !alongX);
      for (d in 0...4)
        FacilityGeom.face(top, r.x0, r.x1, r.z0, r.z1, d, y - TOP_T, y, CELL);
      var steel = MilitaryGeom.buf(TEX_ENAMEL);
      var inset = LEG_W * 2;
      if (alongX)
        for (lx in [ r.x0 + inset, r.x1 - inset - LEG_W ])
          MilitaryGeom.box(steel, lx, lx + LEG_W, r.z0 + inset, r.z1 - inset, 0, y - TOP_T, CELL);
      else
        for (lz in [ r.z0 + inset, r.z1 - inset - LEG_W ])
          MilitaryGeom.box(steel, r.x0 + inset, r.x1 - inset, lz, lz + LEG_W, 0, y - TOP_T, CELL);
    }

// an HQ desk: a laminate top on two steel side panels
  static function desk(r:Rect, dir:Int):Void
    {
      table(r, dir < 2, TEX_LAMINATE, TABLE_H);
      var steel = MilitaryGeom.buf(TEX_ENAMEL);
      if (dir < 2)
        for (sx in [ r.x0, r.x1 - DESK_SIDE ])
          MilitaryGeom.box(steel, sx, sx + DESK_SIDE, r.z0, r.z1, 0, TABLE_H - TOP_T, CELL);
      else
        for (sz in [ r.z0, r.z1 - DESK_SIDE ])
          MilitaryGeom.box(steel, r.x0, r.x1, sz, sz + DESK_SIDE, 0, TABLE_H - TOP_T, CELL);
    }

// a box with an authored front facing out of its wall and `side` on the rest
  static function front(r:Rect, dir:Int, tex:String, h:Float, side:String):Void
    {
      var steel = MilitaryGeom.buf(side);
      for (d in 0...4)
        if (d != dir &&
            d != (dir ^ 1))
          FacilityGeom.face(steel, r.x0, r.x1, r.z0, r.z1, d, 0, h, CELL);
      FacilityGeom.cap(steel, r.x0, r.x1, r.z0, r.z1, h, CELL);
      FacilityGeom.pane(MilitaryGeom.buf(tex), r.x0, r.x1, r.z0, r.z1, dir ^ 1, 0, h);
    }

// a row of cubicles: a partition at every cell edge out from the wall, and a door 0..1 across each
// cell's open side
  static function stalls(r:Rect, dir:Int, len:Int):Void
    {
      var panel = MilitaryGeom.buf(TEX_STALL);
      var doors = MilitaryGeom.buf(TEX_STALL_DOOR);
      var alongX = (dir < 2);
      var a0 = (alongX ? r.x0 : r.z0);
      for (i in 0...len + 1)
        {
          var a = Math.min(a0 + i * CELL, (alongX ? r.x1 : r.z1) - STALL_T);
          if (alongX)
            MilitaryGeom.box(panel, a, a + STALL_T, r.z0, r.z1, 0, STALL_H, CELL);
          else
            MilitaryGeom.box(panel, r.x0, r.x1, a, a + STALL_T, 0, STALL_H, CELL);
          if (i == len)
            break;
          var b = a0 + i * CELL;
          if (alongX)
            FacilityGeom.pane(doors, b, b + CELL, r.z0, r.z1, dir ^ 1, 0, STALL_H);
          else
            FacilityGeom.pane(doors, r.x0, r.x1, b, b + CELL, dir ^ 1, 0, STALL_H);
        }
    }

// a run's cells cut to `d` off the room face of the wall on side `dir`
  static function back(m:Facility, col:Int, row:Int, cell:Rect, dir:Int, d:Float):Rect
    {
      var sl = FacilityGeom.slab(m, col + DX[dir], row + DZ[dir]);
      return switch (dir)
        {
          case 0: { x0: cell.x0, x1: cell.x1, z0: sl.z1, z1: sl.z1 + d };
          case 1: { x0: cell.x0, x1: cell.x1, z0: sl.z0 - d, z1: sl.z0 };
          case 2: { x0: sl.x1, x1: sl.x1 + d, z0: cell.z0, z1: cell.z1 };
          default: { x0: sl.x0 - d, x1: sl.x0, z0: cell.z0, z1: cell.z1 };
        };
    }

// a rect narrowed to `w` round its centre ACROSS a run along x (so in z), or across one along z
  static function across(r:Rect, alongX:Bool, w:Float):Rect
    {
      if (alongX)
        {
          var c = (r.z0 + r.z1) / 2;
          return {
            x0: r.x0,
            x1: r.x1,
            z0: c - w / 2,
            z1: c + w / 2,
          };
        }
      var c = (r.x0 + r.x1) / 2;
      return {
        x0: c - w / 2,
        x1: c + w / 2,
        z0: r.z0,
        z1: r.z1,
      };
    }

// half the city grid's span, the world offset of cell (0, 0)'s low corner
  static inline function half():Float
    return (CityConfig.GRID * CELL) / 2;
}
