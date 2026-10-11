package render.military;

import citygen.CityConfig;
import game.AreaGame;
import render.Models.PropPlace;
import render.facility.FacilityDeco;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import three.Three;

// a military base's room furniture, off the row-20/21 tiles gen.military.MilitaryRooms stands: bunks
// and footlockers, mess and briefing tables with their benches, the serving counter, the map board,
// HQ desks and filing cabinets, latrine cubicles and the trough as quads into
// render.military.MilitaryGeom's per-texture buffers, one texture per face (docs/3d-geometry.md);
// the comms room's racks, operator desks and radios as hand-modelled glbs
// (models-src/military/roomkit_build.py) with their lamps blinking; one FacilityDetail.ground per RUN.
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
  // the store and the medical bay (mil-pack-o)
  static inline var TEX_SHELF = 'textures/military/shelf-front.png';
  static inline var TEX_MEDCAB = 'textures/military/medcab-front.png';
  static inline var TEX_COT = 'textures/military/cot-top.png';

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
  // the wall-backed fronts, each a SQUARE crop so its height is its width, and their depth
  static inline var SHELF_W = 3.6;
  static inline var SHELF_D = 1.5;
  static inline var MEDCAB_W = 2.6;
  static inline var MEDCAB_D = 1.3;
  // the comms room's glbs as roomkit_build.py measures them (bbox w x d x h), each drawn at its own
  // height so it lands at scale 1
  static inline var RACK_W = 2.8;
  static inline var RACK_D = 1.545;
  public static inline var RACK_H = 3.5;
  static inline var DESK_LEN = 3.9;
  static inline var CONSOLE_D = 2.0;
  public static inline var CONSOLE_H = 1.9;
  public static inline var RADIO_BIG_H = 1.0158;
  public static inline var RADIO_SMALL_H = 0.6527;
  // where a radio stands on its desk in the desk's own frame: along it, and its centre in from the
  // desk's back edge, so the face looks into the room with a hand's width of desk in front of it
  static inline var RADIO_BIG_X = 0.75;
  static inline var RADIO_SMALL_X = -0.85;
  static inline var RADIO_BACK = 0.25;
  static inline var RADIO_BIG_D = 0.93;
  static inline var RADIO_SMALL_D = 0.73;
  // the lamp sockets the art paints, in each glb's normalized frame (x across, y up from the base, z
  // out of the bbox centre toward the face), printed by roomkit_build.py's `leds`
  static var RACK_LEDS = [
    [ 0.4187, 2.5229, 0.7675 ], [ 0.5776, 2.5244, 0.7675 ], [ 0.7356, 2.5229, 0.7675 ],
    [ -0.6705, 1.7921, 0.7675 ], [ -0.5517, 1.7926, 0.7675 ], [ -0.4338, 1.7921, 0.7675 ],
    [ -0.3136, 1.7912, 0.7675 ], [ 0.2688, 1.3328, 0.7675 ], [ 0.398, 1.3324, 0.7675 ],
    [ 0.5243, 1.3338, 0.7675 ], [ -0.0448, 0.7048, 0.7675 ], [ 0.1066, 0.7048, 0.7675 ],
    [ 0.2617, 0.7053, 0.7675 ], [ 0.4225, 0.7057, 0.7675 ],
  ];
  static var BIG_LEDS = [
    [ -0.1356, 0.3883, 0.465 ], [ -0.0432, 0.388, 0.465 ], [ 0.0485, 0.3878, 0.465 ],
  ];
  static var SMALL_LEDS = [
    [ 0.1549, 0.3818, 0.365 ], [ 0.1547, 0.3243, 0.365 ], [ 0.1547, 0.267, 0.365 ],
    [ 0.1549, 0.2101, 0.365 ],
  ];
  // a lamp's world size (the art's sockets are 16 px of a 509-px 2.4 face, 0.075) and how far proud
  // of its face the additive quad floats
  static inline var LED_SIZE = 0.1;
  static inline var LED_EPS = 0.03;
  // a cot, one cell long out from its wall: military/cot-top's 504x236 strip, its frame's height
  static inline var COT_L = 3.6;
  static inline var COT_W = COT_L * 236 / 504;
  static inline var COT_H = 1.0;
  static inline var COT_LEG = 0.12;
  // the map board, a square, hung off the wall face
  static inline var BOARD_W = 3.2;
  static inline var BOARD_Y = 1.4;
  static inline var BOARD_OFF = 0.05;

  // the step from a cell to its wall on each side: -z, +z, -x, +x (CorpFurniture.lockerRect's)
  static var DX = [ 0, 0, -1, 1 ];
  static var DZ = [ -1, 1, 0, 0 ];
  // the turn that faces a glb's local +z away from the wall on each side
  static var YAW = [ 0.0, Math.PI, Math.PI / 2, -Math.PI / 2 ];

  // the comms room's glb places, batched by render.military.MilitaryGeom.build, and its lamps
  public static var racks:Array<PropPlace> = [];
  public static var desks:Array<PropPlace> = [];
  public static var radiosBig:Array<PropPlace> = [];
  public static var radiosSmall:Array<PropPlace> = [];
  static var leds:MeshBuf;

// emit every piece in the base's rooms, then light the comms room's lamps
  public static function build(scene:Scene, m:Facility, area:AreaGame):Void
    {
      racks = [];
      desks = [];
      radiosBig = [];
      radiosSmall = [];
      leds = MeshBufTools.make();
      var taken = [for (_ in 0...area.height) [for (_ in 0...area.width) false]];
      for (row in 0...area.height)
        for (col in 0...area.width)
          {
            var t = area.getCellType(col, row);
            if (!(t >= Const.TILE_MIL_BUNK && t <= Const.TILE_MIL_TROUGH) &&
                !(t >= Const.TILE_MIL_RADIO_RACK && t <= Const.TILE_MIL_MED_CABINET) ||
                taken[row][col])
              continue;
            // the run: along x if the next cell is the same, down z otherwise. A rack, a shelf, a
            // cabinet, a cot and a crate stack are one piece per cell however many stand in a row
            var len = 1;
            if (single(t))
              {
                taken[row][col] = true;
                piece(m, t, col, row, 1, false);
                continue;
              }
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
      FacilityDeco.lamps(scene, leds);
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
      else if (t == Const.TILE_MIL_CRATES)
        {
          // one or two of the yard's crates, turned off the cell's hash
          var hash = FacilityModel.mix((col * 27644437) ^ (row * 67867979));
          var turn = (hash % 2 == 1);
          var n = 1 + (hash >> 4) % 2;
          for (i in 0...n)
            MilitaryGeom.crates.push({
              x: (cell.x0 + cell.x1) / 2,
              z: (cell.z0 + cell.z1) / 2,
              yaw: (turn ? Math.PI / 2 : 0.0) + (i == 1 ? 0.12 : 0.0),
              y: i * MilitaryYard.CRATE_STEP,
            });
          r = across(cell, !turn, MilitaryYard.CRATE_D);
          h = n * MilitaryYard.CRATE_STEP;
        }
      else
        {
          // the rest stand against a wall: the side of the run's first cell that is plain masonry,
          // along the run for a run, any side for a single. NEVER A WINDOW: isWall counts one, and
          // a corner rack found the glass first and stood with its back to it
          var dir = -1;
          for (d in (len == 1 ? [ 0, 1, 2, 3 ] : (alongX ? [ 0, 1 ] : [ 2, 3 ])))
            if (dir < 0 &&
                FacilityModel.isSolidWall(m, col + DX[d], row + DZ[d]))
              dir = d;
          // a desk pair or a cot out in the middle of a room has no wall: the desk is a table, and
          // the cot lies along the run's axis with its pillow to the west or north
          if (dir < 0 &&
              t == Const.TILE_MIL_DESK)
            {
              r = across(cell, alongX, TABLE_W);
              h = TABLE_H;
              table(r, alongX, TEX_LAMINATE, TABLE_H);
            }
          else if (dir < 0 &&
              t == Const.TILE_MIL_COT)
            {
              r = across(across(cell, true, COT_W), false, COT_L);
              h = COT_H;
              cot(r, 2);
            }
          if (dir < 0)
            {
              if (r != null)
                FacilityDetail.ground(m, {
                  col: col,
                  row: row,
                  len: len,
                  alongX: alongX,
                  rect: r,
                  h: h,
                });
              return;
            }
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
          else if (t == Const.TILE_MIL_RADIO_RACK)
            {
              r = across(back(m, col, row, cell, dir, RACK_D), dir >= 2, RACK_W);
              h = RACK_H;
              racks.push(stood(r, dir, 0.0, 0.0, 0.0));
              lamps(RACK_LEDS, r, dir, 0.0, 0.0, 0.0, col, row);
            }
          else if (t == Const.TILE_MIL_SHELF ||
              t == Const.TILE_MIL_MED_CABINET)
            {
              var w = (t == Const.TILE_MIL_SHELF ? SHELF_W : MEDCAB_W);
              r = across(back(m, col, row, cell, dir, (t == Const.TILE_MIL_SHELF ? SHELF_D : MEDCAB_D)),
                dir >= 2, w);
              h = w;
              front(r, dir, (t == Const.TILE_MIL_SHELF ? TEX_SHELF : TEX_MEDCAB), w, TEX_ENAMEL);
            }
          else if (t == Const.TILE_MIL_CONSOLE)
            {
              r = back(m, col, row, cell, dir, CONSOLE_D);
              h = CONSOLE_H;
              console(r, dir, len, col + row);
            }
          else if (t == Const.TILE_MIL_COT)
            {
              r = across(back(m, col, row, cell, dir, COT_L), dir >= 2, COT_W);
              h = COT_H;
              cot(r, dir);
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

// a comms console run against its wall: an operator desk per cell, and on each a radio set on the
// desk's wall half, the transceiver and the keypad set by turns
  static function console(r:Rect, dir:Int, len:Int, seed:Int):Void
    {
      for (i in 0...len)
        {
          var c:Rect = (dir < 2 ? {
            x0: r.x0 + (r.x1 - r.x0) * i / len,
            x1: r.x0 + (r.x1 - r.x0) * (i + 1) / len,
            z0: r.z0,
            z1: r.z1,
          } : {
            x0: r.x0,
            x1: r.x1,
            z0: r.z0 + (r.z1 - r.z0) * i / len,
            z1: r.z0 + (r.z1 - r.z0) * (i + 1) / len,
          });
          desks.push(stood(c, dir, 0.0, 0.0, 0.0));
          var big = ((seed + i) % 2 == 0);
          var back = -CONSOLE_D / 2 + RADIO_BACK + (big ? RADIO_BIG_D : RADIO_SMALL_D) / 2;
          var x = (big ? RADIO_BIG_X : RADIO_SMALL_X);
          (big ? radiosBig : radiosSmall).push(stood(c, dir, x, back, CONSOLE_H));
          lamps((big ? BIG_LEDS : SMALL_LEDS), c, dir, x, back, CONSOLE_H, Std.int(c.x0 * 7),
            Std.int(c.z0 * 7));
        }
    }

// a glb's place at the centre of `r` turned to face away from its wall at `dir`, moved by (ox, oz) in
// its own frame (x across its face, z out of it) and raised by `y`
  static function stood(r:Rect, dir:Int, ox:Float, oz:Float, y:Float):PropPlace
    {
      var yaw = YAW[dir];
      return {
        x: (r.x0 + r.x1) / 2 + ox * Math.cos(yaw) + oz * Math.sin(yaw),
        z: (r.z0 + r.z1) / 2 - ox * Math.sin(yaw) + oz * Math.cos(yaw),
        yaw: yaw,
        y: y,
      };
    }

// blinking specks on the lamp sockets of a glb stood by `stood` with the same arguments: each a small
// additive quad a hair proud of the face, its level, phase and hue off the cell like
// FacilityDeco.lights', into the one mesh FacilityDeco.lamps makes of them
  static function lamps(at:Array<Array<Float>>, r:Rect, dir:Int, ox:Float, oz:Float, y:Float,
      col:Int, row:Int):Void
    {
      var p = stood(r, dir, ox, oz, y);
      var c = Math.cos(p.yaw);
      var s = Math.sin(p.yaw);
      var g = FacilityModel.mix((col * 971658137) ^ (row * 1266489917));
      var e = LED_SIZE / 2;
      for (i in 0...at.length)
        {
          var l = at[i];
          var z = l[2] + LED_EPS;
          var wx = p.x + l[0] * c + z * s;
          var wz = p.z - l[0] * s + z * c;
          var wy = y + l[1];
          var hh = FacilityModel.mix(g ^ (i * 40503));
          // r = level, g = blink phase, b = which of the two hues; see FacilityDeco.blink
          var lvl = 0.7 + ((hh % 1000) / 1000) * 0.3;
          var ph = ((hh >>> 11) % 1000) / 1000;
          var hue = ((hh >>> 21) % 3 == 0 ? 0.0 : 1.0);
          MeshBufTools.quadRGB(leds, [wx - e * c, wy - e, wz + e * s], [wx + e * c, wy - e, wz - e * s],
            [wx + e * c, wy + e, wz - e * s], [wx - e * c, wy + e, wz + e * s], [0, 0, 1, 0, 1, 1, 0, 1],
            lvl, ph, hue);
        }
    }

// the comms kit's glbs, for View's warm-up
  public static function warmProps():Array<{ path:String, h:Float }>
    {
      return [
        {
          path: RenderConfig.MODELS.militaryRadioRack,
          h: RACK_H,
        },
        {
          path: RenderConfig.MODELS.militaryRadioDesk,
          h: CONSOLE_H,
        },
        {
          path: RenderConfig.MODELS.militaryRadioBig,
          h: RADIO_BIG_H,
        },
        {
          path: RenderConfig.MODELS.militaryRadioSmall,
          h: RADIO_SMALL_H,
        },
      ];
    }

// a cot lying out from its wall at `dir`: four enamel legs, a rail round it, and the cot strip over
// the top with its pillow at the wall
  static function cot(r:Rect, dir:Int):Void
    {
      var steel = MilitaryGeom.buf(TEX_ENAMEL);
      for (px in [ r.x0, r.x1 - COT_LEG ])
        for (pz in [ r.z0, r.z1 - COT_LEG ])
          MilitaryGeom.box(steel, px, px + COT_LEG, pz, pz + COT_LEG, 0, COT_H, CELL);
      for (d in 0...4)
        FacilityGeom.face(steel, r.x0, r.x1, r.z0, r.z1, d, COT_H - 0.25, COT_H, CELL);
      art(MilitaryGeom.buf(TEX_COT), r, COT_H, -DX[dir], -DZ[dir]);
    }

// an authored top over a rect at height y, the art's u along (ox, oz) and its v a quarter turn from
// it, so the image reads unmirrored from above: u across the screen and v up it when u is east
  static function art(b:render.world.MeshBuf.MeshBuf, r:Rect, y:Float, ox:Float, oz:Float):Void
    {
      var cx = (r.x0 + r.x1) / 2;
      var cz = (r.z0 + r.z1) / 2;
      var lu = Math.abs(ox) * (r.x1 - r.x0) + Math.abs(oz) * (r.z1 - r.z0);
      var lv = Math.abs(oz) * (r.x1 - r.x0) + Math.abs(ox) * (r.z1 - r.z0);
      var uv:Array<Float> = [];
      for (p in [ [ r.x0, r.z1 ], [ r.x1, r.z1 ], [ r.x1, r.z0 ], [ r.x0, r.z0 ] ])
        {
          uv.push(0.5 + ((p[0] - cx) * ox + (p[1] - cz) * oz) / lu);
          uv.push(0.5 + ((p[0] - cx) * oz - (p[1] - cz) * ox) / lv);
        }
      MeshBufTools.quad(b, [r.x0, y, r.z1], [r.x1, y, r.z1], [r.x1, y, r.z0], [r.x0, y, r.z0], uv);
    }

// one piece per cell, never merged into a run
  static inline function single(t:Int):Bool
    {
      return t == Const.TILE_MIL_RADIO_RACK ||
        t == Const.TILE_MIL_SHELF ||
        t == Const.TILE_MIL_MED_CABINET ||
        t == Const.TILE_MIL_COT ||
        t == Const.TILE_MIL_CRATES;
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
