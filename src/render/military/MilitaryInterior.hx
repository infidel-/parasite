package render.military;

import citygen.CityConfig;
import game.AreaGame;
import render.Models;
import render.Models.InstancedProp;
import render.Models.PropPlace;
import render.facility.FacilityDeco;
import render.facility.ClutterSlot;
import render.facility.FacilityDeco.DecoRect;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityGround;
import render.military.MilitaryClutter.LidKind;
import render.military.MilitaryClutter.MilitaryLid;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import three.Three;

// a military base's room furniture, off the row-20/21 tiles gen.military.MilitaryRooms stands. All of
// it is hand-modelled glbs (models-src/military/roomkit_build.py), one instanced batch per model:
// bunks, footlockers, cots, office desks and filing cabinets, folding chairs at every desk, the
// store's shelf units, the medical cabinets, mess and briefing tables and their benches, the serving
// counter, and the comms room's racks, operator desks and radios with their lamps blinking. The
// latrine's cubicles and trough and the briefing room's map board stay quads into
// render.military.MilitaryGeom's per-texture buffers: partitions, a basin slab and a picture on a
// wall. One FacilityDetail.ground per RUN.
//
// THE ROOMS WERE ALL EMITTED SLABS and were reported from the game as "very empty and emitted": a
// rack was a box wearing a picture of radios, a console a slab with radios and a log painted into its
// top, a shelf a box wearing a picture of shelves.
//
// a run is the longest straight line of one tile, x tried first: the generator never puts two runs
// of one tile side by side, but a desk on each of two walls can meet at the room's corner, and
// the cells a run takes are marked so the second desk is not read as the tail of the first
class MilitaryInterior
{
  static inline var CELL = CityConfig.CELL;

  static inline var TEX_STAINLESS = 'textures/military/steel.png';
  static inline var TEX_STALL = 'textures/military/stall-panel.png';
  static inline var TEX_STALL_DOOR = 'textures/military/stall-door.png';
  static inline var TEX_BOARD = 'textures/military/map-board.png';

  // each glb's footprint as roomkit_build.py measures its bbox (along x, across), and the height it
  // is drawn at, which is its own so it lands at scale 1
  static inline var BUNK_H = 3.4;
  static inline var BUNK_W = 2.74;
  static inline var COT_L = 3.5;
  static inline var COT_W = 1.6657;
  static inline var COT_H = 1.1146;
  static inline var FOOT_W = 2.6;
  static inline var FOOT_D = 1.775;
  static inline var FOOT_H = 1.0;
  static inline var FOOT_SHADOW = 0.2;
  static inline var DESK_D = 2.2;
  static inline var TABLE_H = 1.9;
  static inline var TABLE_W = 2.8;
  static inline var BENCH_H = 1.1;
  static inline var BENCH_W = 1.3;
  static inline var FILE_W = 2.2;
  static inline var FILE_D = 1.84;
  static inline var SHELF_W = 3.6;
  static inline var SHELF_D = 1.5;
  static inline var MEDCAB_W = 2.6;
  static inline var MEDCAB_D = 1.34;
  static inline var COUNTER_D = 2.36;
  static inline var COUNTER_H = 2.0;
  static inline var CHAIR_H = 2.1549;
  static inline var RACK_W = 2.8;
  static inline var RACK_D = 1.545;
  static inline var RACK_H = 3.5;
  static inline var CONSOLE_D = 2.0;
  static inline var RADIO_BIG_H = 1.0158;
  static inline var RADIO_SMALL_H = 0.6527;
  // the rooms' standing props (gen.military.MilitaryRooms.slot) and the armory's pieces, bbox
  // across x by depth and height, each stood with its back to its wall
  static inline var RIFLE_W = 2.8;
  static inline var RIFLE_D = 0.81;
  static inline var RIFLE_H = 2.6;
  static inline var AMMO_W = 2.08;
  static inline var AMMO_D = 1.12;
  static inline var AMMO_H = 1.3413;
  static inline var JERRY_W = 1.47;
  static inline var JERRY_D = 1.2;
  static inline var JERRY_H = 2.548;
  static inline var FLAG_W = 2.2;
  static inline var FLAG_D = 0.9;
  static inline var FLAG_H = 3.95;
  static inline var COOLER_W = 0.9;
  static inline var COOLER_D = 1.125;
  static inline var COOLER_H = 3.34;
  static inline var IV_W = 1.17;
  static inline var IV_D = 1.0511;
  static inline var IV_H = 3.5;
  static inline var STRETCHER_L = 3.6;
  static inline var STRETCHER_W = 1.33;
  static inline var STRETCHER_H = 0.9956;
  public static inline var LOCKER_H = 4.0;
  public static inline var SAFE_H = 1.9271;
  // the barracks gear render.military.MilitaryClutter stands about
  public static inline var BOOTS_H = 0.5387;
  public static inline var RUCKSACK_H = 1.2252;
  public static inline var CANTEEN_H = 0.46;
  // the bedding a bunk's and a cot's clutter lies on, off roomkit_build.py: the bunk 7.74 long, its
  // blanket 5.3 x 2.56 at 0.37 over each deck and centred 1.09 toward the foot (+x); the cot's canvas
  // bare between its pillow and its folded blanket, 1.3 x 1.45 at 0.955 and 0.1 toward the head
  static inline var BUNK_L = 7.74;
  static var BLANKET_Y = [ 1.27, 3.07 ];
  static inline var BLANKET_X = 1.09;
  static inline var BLANKET_L = 5.2;
  static inline var BLANKET_W = 2.46;
  static inline var COT_TOP = 0.955;
  static inline var COT_FREE_X = -0.1;
  static inline var COT_FREE_L = 1.3;
  // a chair's centre out in front of its desk's front edge, half under it
  static inline var CHAIR_OUT = 0.3;
  // the latrine's emitted pieces: the trough's depth off its wall and height, and a cubicle's door
  // (military/stall-door's 512x510) over the cell's whole width
  static inline var TROUGH_D = 1.6;
  static inline var TROUGH_H = 1.8;
  static inline var STALL_H = CELL * 510 / 512;
  static inline var STALL_D = CELL * 0.95;
  static inline var STALL_T = 0.1;
  // the map board, a square, hung off the wall face
  static inline var BOARD_W = 3.2;
  static inline var BOARD_Y = 1.4;
  static inline var BOARD_OFF = 0.05;
  // where a radio stands on its desk in the desk's own frame: along it, and its centre in from the
  // desk's back edge, so the face looks into the room with a hand's width of desk in front of it
  static inline var RADIO_BIG_X = 0.75;
  static inline var RADIO_SMALL_X = -0.85;
  static inline var RADIO_BACK = 0.25;
  static inline var RADIO_BIG_D = 0.93;
  static inline var RADIO_SMALL_D = 0.73;
  static inline var RADIO_BIG_W = 1.5;
  static inline var RADIO_SMALL_W = 1.1;
  // a desk's and a table's top along its length (roomkit_build.py's CELL - 0.1)
  static inline var TOP_L = 3.9;
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

  // the step from a cell to its wall on each side: -z, +z, -x, +x (CorpFurniture.lockerRect's)
  static var DX = [ 0, 0, -1, 1 ];
  static var DZ = [ -1, 1, 0, 0 ];
  // the turn that faces a glb's local +z away from the wall on each side
  public static var YAW = [ 0.0, Math.PI, Math.PI / 2, -Math.PI / 2 ];
  // and the one that points a bed's local -x (its head) AT the wall on each side
  static var HEAD = [ -Math.PI / 2, Math.PI / 2, 0.0, Math.PI ];

  // this build's places, per glb path, the lamps, and the area the tiles are read off
  static var places:Map<String, Array<PropPlace>>;
  static var grid:AreaGame;
  static var leds:MeshBuf;
  // and the furniture tops render.military.MilitaryClutter lays its decals on
  public static var lids:Array<MilitaryLid>;

// every glb the rooms stand and the height it is drawn at: the batches, and View's warm-up
  public static function warmProps():Array<{ path:String, h:Float }>
    {
      var md = RenderConfig.MODELS;
      return [
        { path: md.militaryBunk, h: BUNK_H },
        { path: md.militaryCot, h: COT_H },
        { path: md.militaryFootlocker, h: FOOT_H },
        { path: md.militaryOfficeDesk, h: TABLE_H },
        { path: md.militaryFileCabinet, h: FILE_W },
        { path: md.militaryChair, h: CHAIR_H },
        { path: md.militaryShelf, h: SHELF_W },
        { path: md.militaryMedCabinet, h: MEDCAB_W },
        { path: md.militaryMessTable, h: TABLE_H },
        { path: md.militaryBriefTable, h: TABLE_H },
        { path: md.militaryBench, h: BENCH_H },
        { path: md.militaryCounter, h: COUNTER_H },
        { path: md.militaryCounter2, h: COUNTER_H },
        { path: md.militaryRadioRack, h: RACK_H },
        { path: md.militaryRadioDesk, h: TABLE_H },
        { path: md.militaryRadioBig, h: RADIO_BIG_H },
        { path: md.militaryRadioSmall, h: RADIO_SMALL_H },
        { path: md.militaryRifleRack, h: RIFLE_H },
        { path: md.militaryAmmoCans, h: AMMO_H },
        { path: md.militaryJerrycans, h: JERRY_H },
        { path: md.militaryFlag, h: FLAG_H },
        { path: md.militaryWaterCooler, h: COOLER_H },
        { path: md.militaryIvStand, h: IV_H },
        { path: md.militaryStretcher, h: STRETCHER_H },
        { path: md.militaryLocker, h: LOCKER_H },
        { path: md.militaryGunCabinet, h: LOCKER_H },
        { path: md.militarySafe, h: SAFE_H },
        { path: md.militaryBoots, h: BOOTS_H },
        { path: md.militaryRucksack, h: RUCKSACK_H },
        { path: md.militaryCanteen, h: CANTEEN_H },
      ];
    }

// emit every piece in the base's rooms, then light the comms room's lamps
  public static function build(scene:Scene, m:Facility, area:AreaGame):Void
    {
      grid = area;
      places = new Map();
      for (k in warmProps())
        places.set(k.path, []);
      leds = MeshBufTools.make();
      lids = [];
      var taken = [for (_ in 0...area.height) [for (_ in 0...area.width) false]];
      for (row in 0...area.height)
        for (col in 0...area.width)
          {
            var t = area.getCellType(col, row);
            if (!(t >= Const.TILE_MIL_BUNK && t <= Const.TILE_MIL_TROUGH) &&
                !(t >= Const.TILE_MIL_RADIO_RACK && t <= Const.TILE_MIL_STRETCHER) ||
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

// a base room piece that draws power, as the footprint render.facility.FacilityCable drops a lead off:
// a radio rack, an operator desk, a water cooler. null for anything else. Off `m.fit` (MilitaryStyle
// .fitOf) and the walls alone, so either pass may run first. ponytail: the backing wall is `backing`'s
// for a single, which on a console run's corner cell may be the end wall rather than the run's
  public static function powered(m:Facility, col:Int, row:Int):DecoRect
    {
      var t = m.fit[row][col];
      var k = [ Const.TILE_MIL_RADIO_RACK, Const.TILE_MIL_CONSOLE, Const.TILE_MIL_WATER_COOLER ]
        .indexOf(t);
      if (k < 0)
        return null;
      var dir = backing(m, col, row, [ 0, 1, 2, 3 ]);
      if (dir < 0)
        return null;
      var x0 = col * CELL - half();
      var z0 = row * CELL - half();
      var r = across(back(m, col, row, {
        x0: x0,
        x1: x0 + CELL,
        z0: z0,
        z1: z0 + CELL,
      }, dir, [ RACK_D, CONSOLE_D, COOLER_D ][k]), dir >= 2, [ RACK_W, TOP_L, COOLER_W ][k]);
      return {
        x0: r.x0,
        x1: r.x1,
        z0: r.z0,
        z1: r.z1,
        dir: dir,
        hasWall: true,
        h: [ RACK_H, TABLE_H, COOLER_H ][k],
      };
    }

// this build's glbs, one instanced batch each, for render.military.MilitaryGeom.build to mask and hand
// on with the yard's
  public static function batches(scene:Scene):Array<{ prop:InstancedProp, path:String }>
    {
      return [for (k in warmProps())
        {
          prop: Models.instanced(scene, k.path, places.get(k.path), k.h, SOLID),
          path: k.path,
        }];
    }

// one run of one tile
  static function piece(m:Facility, t:Int, col:Int, row:Int, len:Int, alongX:Bool):Void
    {
      var md = RenderConfig.MODELS;
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
          // two cells to a bunk, its head at whichever end of the run meets a wall
          r = across(cell, alongX, BUNK_W);
          h = BUNK_H;
          var low = FacilityModel.isSolidWall(m, col - (alongX ? 1 : 0), row - (alongX ? 0 : 1));
          var yaw = (alongX ? (low ? 0.0 : Math.PI) : (low ? -Math.PI / 2 : Math.PI / 2));
          for (k in 0...Std.int(Math.max(1, len / 2)))
            {
              var c = cut(r, alongX, k * 2, Std.int(Math.min(2, len)));
              put(md.militaryBunk, (c.x0 + c.x1) / 2, (c.z0 + c.z1) / 2, yaw, 0.0);
              beds((c.x0 + c.x1) / 2, (c.z0 + c.z1) / 2, yaw, FacilityGround.surfY(m.surf[row][col]),
                false);
            }
        }
      else if (t == Const.TILE_MIL_FOOTLOCKER)
        {
          // facing out of the wall it stands against, or away from the bunk it stands at the foot of
          var wall = -1;
          var bunk = -1;
          for (d in 0...4)
            if (FacilityModel.isSolidWall(m, col + DX[d], row + DZ[d]))
              wall = d;
            else if (grid.getCellType(col + DX[d], row + DZ[d]) == Const.TILE_MIL_BUNK)
              bunk = d;
          var face = (wall >= 0 ? wall ^ 1 : (bunk >= 0 ? bunk ^ 1 : 1));
          r = across(across(cell, true, (face < 2 ? FOOT_D : FOOT_W)), false,
            (face < 2 ? FOOT_W : FOOT_D));
          h = FOOT_H;
          put(md.militaryFootlocker, (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, YAW[face ^ 1], 0.0);
          top((r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, YAW[face ^ 1], FOOT_W, FOOT_D - 0.1, FOOT_H,
            FOOTLOCKER, []);
          // a pool round its foot as well as the contact field, which a box this wide spreads to
          // nothing: past GROUND_POOL_MAX FacilityDetail.ground lays none ("do these chests throw
          // shadows? they should"). Its core taken FOOT_SHADOW past the box, or the darkest of the
          // ramp sits under the box and the rim the camera sees came out 3-10/255
          FacilityDetail.pool({
            cx: (r.x0 + r.x1) / 2,
            cz: (r.z0 + r.z1) / 2,
            hw: FOOT_W / 2 + FOOT_SHADOW,
            hd: FOOT_D / 2 + FOOT_SHADOW,
            yaw: YAW[face ^ 1],
            y: FacilityGround.surfY(m.surf[row][col]),
            plate: cell,
          });
        }
      else if (t == Const.TILE_MIL_MESS_TABLE ||
          t == Const.TILE_MIL_BRIEF_TABLE ||
          t == Const.TILE_MIL_BENCH)
        {
          var bench = (t == Const.TILE_MIL_BENCH);
          r = across(cell, alongX, (bench ? BENCH_W : TABLE_W));
          h = (bench ? BENCH_H : TABLE_H);
          var path = (bench ? md.militaryBench : t == Const.TILE_MIL_MESS_TABLE ?
            md.militaryMessTable : md.militaryBriefTable);
          for (i in 0...len)
            {
              var c = cut(r, alongX, i, 1);
              put(path, (c.x0 + c.x1) / 2, (c.z0 + c.z1) / 2, (alongX ? 0.0 : Math.PI / 2), 0.0);
              if (!bench)
                top((c.x0 + c.x1) / 2, (c.z0 + c.z1) / 2, (alongX ? 0.0 : Math.PI / 2), TOP_L, TABLE_W,
                  TABLE_H, TABLE, []);
            }
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
          var dir = backing(m, col, row, (len == 1 ? [ 0, 1, 2, 3 ] : (alongX ? [ 0, 1 ] : [ 2, 3 ])));
          // a desk pair or a cot out in the middle of a room has no wall: the desks stand side by
          // side facing the same way with a chair at each, and the cot lies with its head west
          if (dir < 0 &&
              t == Const.TILE_MIL_DESK)
            {
              r = across(cell, alongX, DESK_D);
              h = TABLE_H;
              seated(r, (alongX ? 0 : 2), len, md.militaryOfficeDesk, DESK_D);
            }
          else if (dir < 0 &&
              t == Const.TILE_MIL_SHELF)
            {
              // a store's row out in its floor: two units back to back, one facing each aisle, the
              // row running down whichever axis its neighbours along it are not open floor on
              var ew = (m.fit[row][col - 1] == 0 &&
                m.fit[row][col + 1] == 0);
              var cx = (cell.x0 + cell.x1) / 2;
              var cz = (cell.z0 + cell.z1) / 2;
              r = across(across(cell, !ew, SHELF_D * 2), ew, SHELF_W);
              h = SHELF_W;
              for (d in (ew ? [ 2, 3 ] : [ 0, 1 ]))
                {
                  // backing toward the middle from the far side of it, as if that were its wall
                  var o = (d == 0 || d == 2 ? 1 : -1) * SHELF_D / 2;
                  put(md.militaryShelf, cx + (ew ? o : 0.0), cz + (ew ? 0.0 : o), YAW[d], 0.0);
                }
            }
          else if (dir < 0 &&
              t == Const.TILE_MIL_COT)
            {
              r = across(across(cell, true, COT_W), false, COT_L);
              h = COT_H;
              put(md.militaryCot, (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, 0.0, 0.0);
              beds((r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, 0.0, FacilityGround.surfY(m.surf[row][col]),
                true);
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
          if (t == Const.TILE_MIL_COUNTER)
            {
              r = back(m, col, row, cell, dir, COUNTER_D);
              h = COUNTER_H;
              for (i in 0...len)
                {
                  var c = cut(r, dir < 2, i, 1);
                  put(((col + row + i) % 2 == 0 ? md.militaryCounter : md.militaryCounter2),
                    (c.x0 + c.x1) / 2, (c.z0 + c.z1) / 2, YAW[dir], 0.0);
                }
            }
          else if (t == Const.TILE_MIL_TROUGH)
            {
              r = back(m, col, row, cell, dir, TROUGH_D);
              h = TROUGH_H;
              MilitaryGeom.box(MilitaryGeom.buf(TEX_STAINLESS), r.x0, r.x1, r.z0, r.z1, 0, h,
                CELL);
            }
          else if (t == Const.TILE_MIL_DESK)
            {
              r = back(m, col, row, cell, dir, DESK_D);
              h = TABLE_H;
              seated(r, dir, len, md.militaryOfficeDesk, DESK_D);
            }
          else if (t == Const.TILE_MIL_FILE ||
              t == Const.TILE_MIL_SHELF ||
              t == Const.TILE_MIL_MED_CABINET ||
              t == Const.TILE_MIL_RADIO_RACK)
            {
              // a cabinet square to its wall: its footprint, its height and its glb
              var w = (t == Const.TILE_MIL_FILE ? FILE_W : t == Const.TILE_MIL_SHELF ? SHELF_W :
                t == Const.TILE_MIL_MED_CABINET ? MEDCAB_W : RACK_W);
              var d = (t == Const.TILE_MIL_FILE ? FILE_D : t == Const.TILE_MIL_SHELF ? SHELF_D :
                t == Const.TILE_MIL_MED_CABINET ? MEDCAB_D : RACK_D);
              r = across(back(m, col, row, cell, dir, d), dir >= 2, w);
              h = (t == Const.TILE_MIL_RADIO_RACK ? RACK_H : w);
              put((t == Const.TILE_MIL_FILE ? md.militaryFileCabinet : t == Const.TILE_MIL_SHELF ?
                md.militaryShelf : t == Const.TILE_MIL_MED_CABINET ? md.militaryMedCabinet :
                md.militaryRadioRack), (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, YAW[dir], 0.0);
              if (t == Const.TILE_MIL_RADIO_RACK)
                lamps(RACK_LEDS, r, dir, 0.0, 0.0, 0.0, col, row);
              else if (t == Const.TILE_MIL_FILE ||
                  t == Const.TILE_MIL_MED_CABINET)
                top((r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, YAW[dir], w, d, w, CABINET, []);
            }
          else if (t == Const.TILE_MIL_CONSOLE)
            {
              r = back(m, col, row, cell, dir, CONSOLE_D);
              h = TABLE_H;
              console(r, dir, len, col + row);
            }
          else if (t >= Const.TILE_MIL_RIFLE_RACK &&
              t <= Const.TILE_MIL_IV_STAND)
            {
              var k = t - Const.TILE_MIL_RIFLE_RACK;
              var w = [ RIFLE_W, AMMO_W, JERRY_W, FLAG_W, COOLER_W, IV_W ][k];
              var d = [ RIFLE_D, AMMO_D, JERRY_D, FLAG_D, COOLER_D, IV_D ][k];
              r = across(back(m, col, row, cell, dir, d), dir >= 2, w);
              h = [ RIFLE_H, AMMO_H, JERRY_H, FLAG_H, COOLER_H, IV_H ][k];
              put([ md.militaryRifleRack, md.militaryAmmoCans, md.militaryJerrycans, md.militaryFlag,
                md.militaryWaterCooler, md.militaryIvStand ][k], (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2,
                YAW[dir], 0.0);
            }
          else if (t == Const.TILE_MIL_STRETCHER)
            {
              // out from the wall like a cot, its head at it
              r = across(back(m, col, row, cell, dir, STRETCHER_L), dir >= 2, STRETCHER_W);
              h = STRETCHER_H;
              put(md.militaryStretcher, (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, HEAD[dir], 0.0);
            }
          else if (t == Const.TILE_MIL_COT)
            {
              // its head at the wall
              r = across(back(m, col, row, cell, dir, COT_L), dir >= 2, COT_W);
              h = COT_H;
              put(md.militaryCot, (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, HEAD[dir], 0.0);
              beds((r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, HEAD[dir],
                FacilityGround.surfY(m.surf[row][col]), true);
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

// a run of desks backed onto the wall at `dir` (or standing free, facing the way `dir` faces), one
// glb per cell, and a folding chair pulled up to each, facing it
  static function seated(r:Rect, dir:Int, len:Int, path:String, depth:Float):Void
    {
      for (i in 0...len)
        {
          var c = cut(r, dir < 2, i, 1);
          var p = stood(c, dir, 0.0, 0.0, 0.0);
          put(path, p.x, p.z, p.yaw, 0.0);
          chair(c, dir, 0.0, depth);
          top(p.x, p.z, p.yaw, TOP_L, depth, TABLE_H, DESK, []);
        }
    }

// a folding chair in front of a piece `depth` deep stood by `stood(c, dir, ox, ...)`, turned to face it
  static function chair(c:Rect, dir:Int, ox:Float, depth:Float):Void
    {
      var p = stood(c, dir, ox, depth / 2 + CHAIR_OUT, 0.0);
      put(RenderConfig.MODELS.militaryChair, p.x, p.z, p.yaw + Math.PI, 0.0);
    }

// a comms console run against its wall: an operator desk per cell with a chair at it, and on each a
// radio set on the desk's wall half, the transceiver and the keypad set by turns
  static function console(r:Rect, dir:Int, len:Int, seed:Int):Void
    {
      var md = RenderConfig.MODELS;
      for (i in 0...len)
        {
          var c = cut(r, dir < 2, i, 1);
          var p = stood(c, dir, 0.0, 0.0, 0.0);
          put(md.militaryRadioDesk, p.x, p.z, p.yaw, 0.0);
          chair(c, dir, 0.0, CONSOLE_D);
          var big = ((seed + i) % 2 == 0);
          var back = -CONSOLE_D / 2 + RADIO_BACK + (big ? RADIO_BIG_D : RADIO_SMALL_D) / 2;
          var x = (big ? RADIO_BIG_X : RADIO_SMALL_X);
          var q = stood(c, dir, x, back, TABLE_H);
          put((big ? md.militaryRadioBig : md.militaryRadioSmall), q.x, q.z, q.yaw, TABLE_H);
          top(p.x, p.z, p.yaw, TOP_L, CONSOLE_D, TABLE_H, DESK, [
            {
              x: x,
              z: back,
              hw: (big ? RADIO_BIG_W : RADIO_SMALL_W) / 2,
              hd: (big ? RADIO_BIG_D : RADIO_SMALL_D) / 2,
            }
          ]);
          lamps((big ? BIG_LEDS : SMALL_LEDS), c, dir, x, back, TABLE_H, Std.int(c.x0 * 7),
            Std.int(c.z0 * 7));
        }
    }

// one glb place, for render.military.MilitaryGeom's armory pieces as well as this file's
  public static inline function put(path:String, x:Float, z:Float, yaw:Float, y:Float):Void
    {
      places.get(path).push({
        x: x,
        z: z,
        yaw: yaw,
        y: y,
      });
    }

// a furniture top for render.military.MilitaryClutter: centre, turn (stood's), extents along its own
// x and z, height, what kind of top it is and what already stands on it in its own frame. Public for
// render.military.MilitaryGeom's lockers
  public static function top(x:Float, z:Float, yaw:Float, w:Float, d:Float, y:Float, kind:LidKind,
      claims:Array<ClutterSlot>):Void
    {
      lids.push({
        x: x,
        z: z,
        yaw: yaw,
        w: w,
        d: d,
        y: y,
        kind: kind,
        col: Std.int((x + half()) / CELL),
        row: Std.int((z + half()) / CELL),
        claims: claims,
      });
    }

// a bunk's or a cot's tops at its centre and turn: the bedding of each deck, and the floor at `y`
// under it. Asked for from the game as clutter spots "on top and bottom and under"
  static function beds(x:Float, z:Float, yaw:Float, y:Float, cot:Bool):Void
    {
      var c = Math.cos(yaw), s = Math.sin(yaw);
      if (cot)
        top(x + COT_FREE_X * c, z - COT_FREE_X * s, yaw, COT_FREE_L, COT_W - 0.22, COT_TOP, BED, []);
      else
        for (deck in BLANKET_Y)
          top(x + BLANKET_X * c, z - BLANKET_X * s, yaw, BLANKET_L, BLANKET_W, deck, BED, []);
      top(x, z, yaw, (cot ? COT_L - 0.5 : BUNK_L - 0.4), (cot ? COT_W : BUNK_W) - 0.3, y, UNDER, []);
    }

// cells `i` to `i + n` of a run's rect, along x or z
  static function cut(r:Rect, alongX:Bool, i:Int, n:Int):Rect
    {
      return (alongX ? {
        x0: r.x0 + i * CELL,
        x1: r.x0 + (i + n) * CELL,
        z0: r.z0,
        z1: r.z1,
      } : {
        x0: r.x0,
        x1: r.x1,
        z0: r.z0 + i * CELL,
        z1: r.z0 + (i + n) * CELL,
      });
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

// one piece per cell, never merged into a run
  static inline function single(t:Int):Bool
    {
      return t == Const.TILE_MIL_RADIO_RACK ||
        t == Const.TILE_MIL_SHELF ||
        t == Const.TILE_MIL_MED_CABINET ||
        t == Const.TILE_MIL_COT ||
        t == Const.TILE_MIL_CRATES ||
        t == Const.TILE_MIL_FOOTLOCKER ||
        t >= Const.TILE_MIL_RIFLE_RACK;
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

// the wall a piece backs onto, of the `dirs` that are plain masonry: one with open floor in front of it
// first. A shelf in a store's corner found the end wall first and stood facing into the next shelf
// along, its front against that one's side
  static function backing(m:Facility, col:Int, row:Int, dirs:Array<Int>):Int
    {
      var dir = -1;
      for (d in dirs)
        if (FacilityModel.isSolidWall(m, col + DX[d], row + DZ[d]))
          {
            if (m.fit[row - DZ[d]][col - DX[d]] == 0 &&
                !FacilityModel.isWall(m, col - DX[d], row - DZ[d]))
              return d;
            if (dir < 0)
              dir = d;
          }
      return dir;
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
