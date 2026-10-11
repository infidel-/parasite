package render.military;

import citygen.CityConfig;
import game.AreaGame;
import gen.military.MilitaryRooms;
import render.Models;
import render.Models.InstancedProp;
import render.Models.PropPlace;
import render.facility.FacilityDeco;
import render.facility.ClutterSlot;
import render.facility.FacilityDeco.DecoRect;
import render.facility.FacilityDetail;
import render.facility.FacilityGroundOpts;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityModel.Wall;
import render.facility.FacilityGround;
import render.facility.FacilityStyle;
import render.military.MilitaryClutter.LidKind;
import render.military.MilitaryClutter.MilitaryLid;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import three.Three;

// a military base's room furniture, off the row-20/21 tiles gen.military.MilitaryRooms stands. All of
// it is hand-modelled glbs (models-src/military/roomkit_build.py), one instanced batch per model:
// bunks, footlockers, cots, office desks and filing cabinets, folding chairs at every desk, the
// store's shelf units, the medical cabinets, mess and briefing tables and their benches, the serving
// counter, the comms room's racks, operator desks and radios with their lamps blinking, and the
// latrine's basins and toilets. The latrine's cubicles and the briefing room's map board and wall
// boards stay quads into render.military.MilitaryGeom's per-texture buffers: partitions and pictures
// on a wall. One `shade` per RUN, every piece and every chair.
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

  static inline var TEX_STALL = 'textures/military/stall-panel.png';
  static inline var TEX_STALL_DOOR = 'textures/military/stall-door.png';
  static inline var TEX_MIRROR = 'textures/military/mirror.png';
  static inline var TEX_BOARD = 'textures/military/map-board.png';
  static inline var TEX_BOARDS = 'textures/military/briefing-boards.png';

  // each glb's footprint as roomkit_build.py measures its bbox (along x, across), and the height it
  // is drawn at, which is its own so it lands at scale 1
  static inline var BUNK_H = 3.4;
  static inline var BUNK_W = 2.74;
  // the cot drawn 15% over its model ("scale these beds +15%"): 4.03 long, still inside a cell off the
  // wall's face
  static inline var COT_SCALE = 1.15;
  static inline var COT_L = 3.5 * COT_SCALE;
  static inline var COT_W = 1.6657 * COT_SCALE;
  static inline var COT_H = 1.1146 * COT_SCALE;
  static inline var FOOT_W = 2.6;
  static inline var FOOT_D = 1.775;
  static inline var FOOT_H = 1.0;
  // how far past a piece's footprint its floor pool fades out (`shade`), the same on every piece: a
  // fraction of the footprint put the rim 1.8 past the end of a table run ("why are these contact
  // shadows so large? they're way outside of the tables/benches")
  static inline var POOL_FADE = 0.4;
  static inline var DESK_D = 2.2;
  static inline var TABLE_H = 1.9;
  static inline var TABLE_W = 2.8;
  static inline var BENCH_H = 1.1;
  static inline var BENCH_W = 1.3;
  static inline var FILE_W = 2.2;
  static inline var FILE_D = 1.84;
  static inline var SHELF_W = 3.6;
  static inline var SHELF_D = 1.5;
  // its top board's face (roomkit_build.py: a hair under the uprights) and the part of it clear of
  // the four uprights, which clutter may lie on ("shelving tops should have clutter spots")
  static inline var SHELF_TOP = SHELF_W - 0.02;
  static inline var SHELF_TOP_W = SHELF_W - 0.3;
  static inline var SHELF_TOP_D = SHELF_D - 0.2;
  static inline var MEDCAB_W = 2.6;
  static inline var MEDCAB_D = 1.34;
  static inline var COUNTER_D = 2.36;
  static inline var COUNTER_H = 2.0;
  static inline var CHAIR_H = 2.1565;
  static inline var CHAIR_W = 1.0;
  static inline var CHAIR_D = 1.07;
  static inline var RACK_W = 2.8;
  static inline var RACK_D = 1.545;
  static inline var RACK_H = 3.5;
  // its top clear of the chamfered rim and the units proud of its front, which clutter may lie on
  // ("add clutter slots on top")
  static inline var RACK_TOP_W = RACK_W - 0.3;
  static inline var RACK_TOP_D = RACK_D - 0.3;
  static inline var CONSOLE_D = 2.0;
  // and how far off its wall it stands: flush, the lead from the socket up to its radio ran through
  // its top, which a cable MOUNT_PROUD + CABLE_EPS off the face is in front of ("cable goes through the
  // table, should probably be more space between table and wall")
  static inline var CONSOLE_GAP = 0.24;
  static inline var RADIO_BIG_H = 1.0158;
  static inline var RADIO_SMALL_H = 0.6527;
  // the rooms' standing props (gen.military.MilitaryRooms.slot) and the armory's pieces, bbox
  // across x by depth and height, each stood with its back to its wall
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
  // and its wall halo's: the cabinet's top, the bottle on it stands off the wall ("make water cooler
  // contact shadow lower")
  static inline var COOLER_HALO_H = 1.9;
  static inline var IV_W = 1.17;
  static inline var IV_D = 1.0511;
  static inline var IV_H = 3.5;
  // and the height its wall halo is cast to: the wheeled base and the foot of the pole, since a halo the
  // stand's whole height and width read as a slab's ("wall contact shadow too large for iv stand")
  static inline var IV_HALO_H = 0.9;
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
  static inline var COT_TOP = 0.955 * COT_SCALE;
  static inline var COT_FREE_X = -0.1 * COT_SCALE;
  static inline var COT_FREE_L = 1.3 * COT_SCALE;
  // a chair's centre out in front of its desk's front edge, half under it
  static inline var CHAIR_OUT = 0.3;
  // the latrine's basin (two to a cell, this far either side of its middle) and toilet, bbox depth and
  // height as roomkit_build.py measures them
  static inline var SINK_D = 1.122;
  static inline var SINK_H = 2.57;
  static inline var SINK_STEP = 1.0;
  static inline var TOILET_D = 1.75;
  static inline var TOILET_H = 1.97;
  // its urinal (wall-hung, its screen on the floor) and shower, the same way, the urinal's wall halo to
  // its hood's top, and the shower's puddle out from the wall's face, between the rose and the grate
  static inline var URINAL_W = 1.265;
  static inline var URINAL_D = 1.138;
  static inline var URINAL_H = 3.536;
  static inline var URINAL_HALO_H = 2.55;
  static inline var SHOWER_W = 0.93;
  static inline var SHOWER_D = 1.551;
  static inline var SHOWER_H = 4.339;
  static inline var SHOWER_PUDDLE = 1.1;
  // a mirror over each basin, military/mirror's 3:4 drawn whole, its top under a light well's sill
  // (FacilityStyle.WINDOW_HIGH_SILL 3.87)
  static inline var MIRROR_W = 0.84;
  static inline var MIRROR_H = MIRROR_W * 4 / 3;
  static inline var MIRROR_Y = 2.68;
  // and its emitted cubicles, a door (military/stall-door's 512x510) over the cell's whole width
  static inline var STALL_H = CELL * 510 / 512;
  static inline var STALL_D = CELL * 0.95;
  static inline var STALL_T = 0.1;
  static inline var STALL_DOOR_T = 0.05;
  // the map board, a square, hung off the wall face
  static inline var BOARD_W = 3.2;
  static inline var BOARD_Y = 1.4;
  static inline var BOARD_OFF = 0.05;
  // the briefing room's other boards (`boards`): each one's box on its 1024 sheet (x0, y0, x1, y1 px
  // at alpha > 128, the corkboard, the whiteboard, the org chart and the first-aid poster), drawn at
  // BOARD_PX sheet pixels a unit so none is stretched and the portrait two stand taller, centred
  // BOARDS_Y up the wall: over a bench and a table edge, under the 6.0 wall top
  static var BOARDS = [
    [ 22, 61, 498, 424 ], [ 524, 62, 1003, 423 ], [ 81, 464, 440, 950 ], [ 586, 464, 944, 949 ],
  ];
  static inline var BOARD_PX = 170.0;
  static inline var BOARDS_Y = 3.2;
  // a crate stack's height off the cell's hash, two stacks side by side per cell, and the gap
  // between them: one or two crates read as an empty armory ("stack them higher"). The gap clears
  // both lids' 0.03 overhang and two crates turned the full 0.06 toward each other (2 x 1.13 x 0.06):
  // at 0.08 they met ("two crates intersect")
  static inline var CRATES_MIN = 2;
  static inline var CRATES_MAX = 4;
  static inline var CRATE_GAP = 0.24;
  // where a radio stands on its desk in the desk's own frame: along it, and its back in from the
  // desk's back edge, close to the wall so its power lead runs up the wall into it: at 0.25 the lead
  // stopped behind the desk under its top ("cable does not go up to actual radio")
  static inline var RADIO_BIG_X = 0.75;
  static inline var RADIO_SMALL_X = -0.85;
  static inline var RADIO_BACK = 0.08;
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
  // and the keypad set's, 30% smaller: its sockets are a column down a face a third the size
  static inline var SMALL_LED_SIZE = LED_SIZE * 0.7;
  static inline var LED_EPS = 0.03;

  // the step from a cell to its wall on each side: -z, +z, -x, +x (CorpFurniture.lockerRect's)
  static var DX = [ 0, 0, -1, 1 ];
  static var DZ = [ -1, 1, 0, 0 ];
  // the turn that faces a glb's local +z away from the wall on each side
  public static var YAW = [ 0.0, Math.PI, Math.PI / 2, -Math.PI / 2 ];
  // and the one that points a bed's local -x (its head) AT the wall on each side
  static var HEAD = [ -Math.PI / 2, Math.PI / 2, 0.0, Math.PI ];

  // this build's places, per glb path, the lamps, and the area the tiles are read off and its model
  static var places:Map<String, Array<PropPlace>>;
  static var grid:AreaGame;
  static var fac:Facility;
  static var leds:MeshBuf;
  // and the furniture tops render.military.MilitaryClutter lays its decals on, and the spots under the
  // showers it lays a puddle on
  public static var lids:Array<MilitaryLid>;
  public static var drains:Array<PropPlace>;

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
        { path: md.militaryAmmoCans, h: AMMO_H },
        { path: md.militaryJerrycans, h: JERRY_H },
        { path: md.militaryFlag, h: FLAG_H },
        { path: md.militaryWaterCooler, h: COOLER_H },
        { path: md.militaryIvStand, h: IV_H },
        { path: md.militaryStretcher, h: STRETCHER_H },
        { path: md.militarySink, h: SINK_H },
        { path: md.militaryToilet, h: TOILET_H },
        { path: md.militaryUrinal, h: URINAL_H },
        { path: md.militaryShower, h: SHOWER_H },
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
      fac = m;
      places = new Map();
      for (k in warmProps())
        places.set(k.path, []);
      leds = MeshBufTools.make();
      lids = [];
      drains = [];
      var taken = [for (_ in 0...area.height) [for (_ in 0...area.width) false]];
      for (row in 0...area.height)
        for (col in 0...area.width)
          {
            var t = area.getCellType(col, row);
            if (!(t >= Const.TILE_MIL_BUNK && t <= Const.TILE_MIL_SINKS) &&
                !(t >= Const.TILE_MIL_RADIO_RACK && t <= Const.TILE_MIL_SHOWER) ||
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
      boards(m);
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
      }, dir, [ RACK_D, CONSOLE_D, COOLER_D ][k], (k == 1 ? CONSOLE_GAP : 0.0)), dir >= 2,
        [ RACK_W, TOP_L, COOLER_W ][k]);
      if (k != 1)
        return {
          x0: r.x0,
          x1: r.x1,
          z0: r.z0,
          z1: r.z1,
          dir: dir,
          hasWall: true,
          h: [ RACK_H, TABLE_H, COOLER_H ][k],
        };
      // an operator desk's lead goes up the wall into the radio on it, `console`'s set for the cell,
      // and not under the desk top ("cable does not go up to actual radio")
      var big = ((col + row) % 2 == 0);
      var p = stood(r, dir, (big ? RADIO_BIG_X : RADIO_SMALL_X), 0.0, 0.0);
      var hw = (big ? RADIO_BIG_W : RADIO_SMALL_W) / 2;
      return {
        x0: (dir < 2 ? p.x - hw : r.x0),
        x1: (dir < 2 ? p.x + hw : r.x1),
        z0: (dir < 2 ? r.z0 : p.z - hw),
        z1: (dir < 2 ? r.z1 : p.z + hw),
        dir: dir,
        hasWall: true,
        h: TABLE_H,
        lead: TABLE_H + (big ? RADIO_BIG_H : RADIO_SMALL_H) / 2,
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
          // two stacks of the yard's crates side by side, CRATES_MIN to CRATES_MAX high each, turned
          // off the cell's hash and every crate a whisker askew on the one under it
          var hash = FacilityModel.mix((col * 27644437) ^ (row * 67867979));
          var turn = (hash % 2 == 1);
          var tall = 0;
          for (k in 0...2)
            {
              var n = CRATES_MIN + (hash >>> (4 + k * 3)) % (CRATES_MAX - CRATES_MIN + 1);
              var o = (k == 0 ? -1 : 1) * (MilitaryYard.CRATE_D + CRATE_GAP) / 2;
              for (i in 0...n)
                MilitaryGeom.crates.push({
                  x: (cell.x0 + cell.x1) / 2 + (turn ? o : 0.0),
                  z: (cell.z0 + cell.z1) / 2 + (turn ? 0.0 : o),
                  yaw: (turn ? Math.PI / 2 : 0.0) + (((hash >>> (10 + k * 4 + i)) % 3) - 1) * 0.06,
                  y: i * MilitaryYard.CRATE_STEP,
                });
              tall = Std.int(Math.max(tall, n));
            }
          var deep = MilitaryYard.CRATE_D * 2 + CRATE_GAP;
          r = across(across(cell, true, (turn ? MilitaryYard.CRATE_W : deep)), false,
            (turn ? deep : MilitaryYard.CRATE_W));
          h = tall * MilitaryYard.CRATE_STEP;
        }
      else
        {
          // the rest stand against a wall: the side of the run's first cell that is plain masonry,
          // along the run for a run, any side for a single. NEVER A WINDOW: isWall counts one, and
          // a corner rack found the glass first and stood with its back to it. Except what lies under
          // the sill, a medical bay's cots and stretcher, which gen.military.MilitaryRooms stands
          // there on purpose
          var dir = backing(m, col, row, (len == 1 ? [ 0, 1, 2, 3 ] : (alongX ? [ 0, 1 ] : [ 2, 3 ])),
            MilitaryRooms.low(t));
          // a desk island or a cot out in the middle of a room has no wall: the desks stand back to
          // back, a row facing each aisle with a chair at each ("when tables are in the center, spawn
          // two back to back"), their pair 0.2 over the island's ring each side, and the cot lies
          // down the screen, its head north, so two side by side read as two
          if (dir < 0 &&
              t == Const.TILE_MIL_DESK)
            {
              r = across(cell, alongX, DESK_D * 2);
              h = TABLE_H;
              var mid = (alongX ? (r.z0 + r.z1) / 2 : (r.x0 + r.x1) / 2);
              for (d in (alongX ? [ 0, 1 ] : [ 2, 3 ]))
                {
                  // each backed onto the middle as if that were its wall
                  var far = (d == 0 || d == 2);
                  seated({
                    x0: (alongX || !far ? r.x0 : mid),
                    x1: (alongX || far ? r.x1 : mid),
                    z0: (!alongX || !far ? r.z0 : mid),
                    z1: (!alongX || far ? r.z1 : mid),
                  }, d, len, md.militaryOfficeDesk, DESK_D);
                }
            }
          else if (dir < 0 &&
              (t == Const.TILE_MIL_SHELF_ROW ||
              t == Const.TILE_MIL_SHELF))
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
                  top(cx + (ew ? o : 0.0), cz + (ew ? 0.0 : o), YAW[d], SHELF_TOP_W, SHELF_TOP_D,
                    SHELF_TOP, SHELF, []);
                }
            }
          else if (dir < 0 &&
              t == Const.TILE_MIL_COT)
            {
              r = across(across(cell, true, COT_L), false, COT_W);
              h = COT_H;
              put(md.militaryCot, (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, HEAD[0], 0.0);
              beds((r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, HEAD[0],
                FacilityGround.surfY(m.surf[row][col]), true);
            }
          if (dir < 0)
            {
              if (r != null)
                shade(m, {
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
          else if (t == Const.TILE_MIL_SINKS)
            {
              // two basins to a cell, backed onto the wall
              r = back(m, col, row, cell, dir, SINK_D);
              h = SINK_H;
              for (i in 0...len)
                for (k in [ -1, 1 ])
                  {
                    var p = stood(cut(r, dir < 2, i, 1), dir, k * SINK_STEP, 0.0, 0.0);
                    put(md.militarySink, p.x, p.z, p.yaw, 0.0);
                  }
              mirrors(m, col, row, cell, dir, len);
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
                {
                  lamps(RACK_LEDS, r, dir, 0.0, 0.0, 0.0, col, row);
                  top((r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, YAW[dir], RACK_TOP_W, RACK_TOP_D, RACK_H,
                    SHELF, []);
                }
              else if (t == Const.TILE_MIL_FILE ||
                  t == Const.TILE_MIL_MED_CABINET)
                top((r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, YAW[dir], w, d, w, CABINET, []);
              else if (t == Const.TILE_MIL_SHELF)
                top((r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, YAW[dir], SHELF_TOP_W, SHELF_TOP_D,
                  SHELF_TOP, SHELF, []);
            }
          else if (t == Const.TILE_MIL_CONSOLE)
            {
              r = back(m, col, row, cell, dir, CONSOLE_D, CONSOLE_GAP);
              h = TABLE_H;
              console(r, dir, len, col + row);
            }
          else if (t == Const.TILE_MIL_GUN_LOCKER)
            {
              // the armory's gun cabinet as furniture, placed, topped and shadowed as the object one
              // is. It was a rifle rack ("looks like crap ... remove it, use gun lockers")
              MilitaryGeom.locker(m, col, row, md.militaryGunCabinet);
              return;
            }
          else if (t >= Const.TILE_MIL_AMMO_CANS &&
              t <= Const.TILE_MIL_IV_STAND)
            {
              var k = t - Const.TILE_MIL_AMMO_CANS;
              var w = [ AMMO_W, JERRY_W, FLAG_W, COOLER_W, IV_W ][k];
              var d = [ AMMO_D, JERRY_D, FLAG_D, COOLER_D, IV_D ][k];
              r = across(back(m, col, row, cell, dir, d), dir >= 2, w);
              h = [ AMMO_H, JERRY_H, FLAG_H, COOLER_HALO_H, IV_HALO_H ][k];
              put([ md.militaryAmmoCans, md.militaryJerrycans, md.militaryFlag, md.militaryWaterCooler,
                md.militaryIvStand ][k], (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, YAW[dir], 0.0);
            }
          else if (t == Const.TILE_MIL_STRETCHER)
            {
              // out from the wall like a cot, its head at it
              r = across(back(m, col, row, cell, dir, STRETCHER_L, sill(m, col, row, dir)), dir >= 2,
                STRETCHER_W);
              h = STRETCHER_H;
              put(md.militaryStretcher, (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, HEAD[dir], 0.0);
            }
          else if (t == Const.TILE_MIL_COT)
            {
              // its head at the wall
              r = across(back(m, col, row, cell, dir, COT_L, sill(m, col, row, dir)), dir >= 2, COT_W);
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
              // and a toilet in each, its cistern to the wall: they stood empty behind their doors
              var w = back(m, col, row, cell, dir, TOILET_D);
              for (i in 0...len)
                {
                  var p = stood(cut(w, dir < 2, i, 1), dir, 0.0, 0.0, 0.0);
                  put(md.militaryToilet, p.x, p.z, p.yaw, 0.0);
                }
            }
          else if (t == Const.TILE_MIL_URINAL)
            {
              // hung on the wall, its halo the hood's height
              r = across(back(m, col, row, cell, dir, URINAL_D), dir >= 2, URINAL_W);
              h = URINAL_HALO_H;
              put(md.militaryUrinal, (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, YAW[dir], 0.0);
            }
          else if (t == Const.TILE_MIL_SHOWER)
            {
              // pipes on the wall and a grate on the floor, nothing a contact shadow reads on
              var c = across(back(m, col, row, cell, dir, SHOWER_D), dir >= 2, SHOWER_W);
              put(md.militaryShower, (c.x0 + c.x1) / 2, (c.z0 + c.z1) / 2, YAW[dir], 0.0);
              var b = back(m, col, row, cell, dir, 0.0);
              drains.push(stood(b, dir, 0.0, SHOWER_PUDDLE, 0.0));
              return;
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
      shade(m, {
        col: col,
        row: row,
        len: len,
        alongX: alongX,
        rect: r,
        h: h,
      });
    }

// THE ONE SHADOW CALL for a piece standing on a room floor: FacilityDetail.ground, and a floor pool
// round any piece too big for that one's, opaque over the footprint and gone POOL_FADE past it. Past
// GROUND_POOL_MAX the contact field carries it alone and spreads a footprint this wide to nothing:
// the footlocker had one written out by hand ("do these chests throw shadows? they should"), and the
// desks, tables and chairs went without ("ALL 3d objects should throw shadows by default"). Its plate
// is the run's cells, out to the slab face where a wall stands beside them and a cell further where
// floor does, so a desk pair over its island's ring is not cut off at the island's edge
  public static function shade(m:Facility, o:FacilityGroundOpts):Void
    {
      FacilityDetail.ground(m, o);
      var r = o.rect;
      if (Math.max(r.x1 - r.x0, r.z1 - r.z0) <= FacilityStyle.GROUND_POOL_MAX)
        return;
      var n = (o.len > 1 ? o.len : 1);
      var c0 = o.col, r0 = o.row;
      var c1 = o.col + (o.alongX ? n - 1 : 0), r1 = o.row + (o.alongX ? 0 : n - 1);
      var lo = CityConfig.cellToWorld(c0, r0);
      var hi = CityConfig.cellToWorld(c1, r1);
      // one side's edge: the wall's room face where masonry stands beside the run, else a cell on
      inline function edge(d:Int, col:Int, row:Int, open:Float):Float
        {
          if (!FacilityModel.isWall(m, col + DX[d], row + DZ[d]))
            return open;
          var sl = FacilityGeom.slab(m, col + DX[d], row + DZ[d]);
          return [ sl.z1, sl.z0, sl.x1, sl.x0 ][d];
        }
      FacilityDetail.pool({
        cx: (r.x0 + r.x1) / 2,
        cz: (r.z0 + r.z1) / 2,
        hw: (r.x1 - r.x0) / 2,
        hd: (r.z1 - r.z0) / 2,
        yaw: 0.0,
        y: FacilityGround.surfY(m.surf[o.row][o.col]),
        fade: POOL_FADE,
        plate: {
          x0: edge(2, c0, r0, lo.x - CELL * 1.5),
          x1: edge(3, c1, r1, hi.x + CELL * 1.5),
          z0: edge(0, c0, r0, lo.z - CELL * 1.5),
          z1: edge(1, c1, r1, hi.z + CELL * 1.5),
        },
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
      // and its shadow, on the floor cell it stands in: in front of its desk, never in a wall margin
      var at = CityConfig.worldToCell(p.x, p.z);
      var hw = (dir < 2 ? CHAIR_W : CHAIR_D) / 2;
      var hd = (dir < 2 ? CHAIR_D : CHAIR_W) / 2;
      shade(fac, {
        col: at.col,
        row: at.row,
        len: 1,
        alongX: true,
        rect: {
          x0: p.x - hw,
          x1: p.x + hw,
          z0: p.z - hd,
          z1: p.z + hd,
        },
        h: CHAIR_H,
      });
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
          // its shadow on the desk top, the gear's round pool
          FacilityDetail.deck({
            cx: q.x,
            cz: q.z,
            hw: (big ? RADIO_BIG_W : RADIO_SMALL_W) / 2,
            hd: (big ? RADIO_BIG_D : RADIO_SMALL_D) / 2,
            yaw: q.yaw,
            y: TABLE_H,
            plate: c,
          });
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
      place(path, {
        x: x,
        z: z,
        yaw: yaw,
        y: y,
      });
    }

// and one already made, for render.military.MilitaryClutter's gear laid on its back
  public static inline function place(path:String, p:PropPlace):Void
    {
      places.get(path).push(p);
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
        top(x + COT_FREE_X * c, z - COT_FREE_X * s, yaw, COT_FREE_L, COT_W - 0.25, COT_TOP, BED, []);
      else
        for (deck in BLANKET_Y)
          top(x + BLANKET_X * c, z - BLANKET_X * s, yaw, BLANKET_L, BLANKET_W, deck, BED, []);
      top(x, z, yaw, (cot ? COT_L - 0.5 : BUNK_L - 0.4), (cot ? COT_W : BUNK_W) - 0.3, y, UNDER, []);
    }

// the briefing room's boards: one on every other cell of its plain walls, none on the map board's,
// a flag stand's or a doorway's, one to a cell, each of the four by the cell's hash. The room was
// reported as wanting "more 2d decals - some bulletin boards or something"
  static function boards(m:Facility):Void
    {
      var b = MilitaryGeom.buf(TEX_BOARDS, true);
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var t = grid.getCellType(col, row);
            if (m.surf[row][col] != Surf.BRIEFING ||
                (col + row) % 2 != 0 ||
                t == Const.TILE_MIL_MAP_BOARD ||
                t == Const.TILE_MIL_FLAG)
              continue;
            for (d in 0...4)
              {
                if (!FacilityModel.isSolidWall(m, col + DX[d], row + DZ[d]) ||
                    FacilityModel.isDoor(m, col + DX[d], row + DZ[d]))
                  continue;
                var px = BOARDS[FacilityModel.mix((col * 73856093) ^ (row * 19349663)) % BOARDS.length];
                var w = (px[2] - px[0]) / BOARD_PX;
                var hh = (px[3] - px[1]) / BOARD_PX / 2;
                var x0 = col * CELL - half();
                var z0 = row * CELL - half();
                var r = across(back(m, col, row, {
                  x0: x0,
                  x1: x0 + CELL,
                  z0: z0,
                  z1: z0 + CELL,
                }, d, BOARD_OFF), d >= 2, w);
                // FacilityGeom.pane's quad, its uv the board's box on the sheet
                var e = FacilityGeom.ends(r.x0, r.x1, r.z0, r.z1, d ^ 1);
                var u0 = px[0] / 1024, u1 = px[2] / 1024;
                var v0 = 1 - px[3] / 1024, v1 = 1 - px[1] / 1024;
                MeshBufTools.quad(b,
                  [e[0], BOARDS_Y - hh, e[1]], [e[2], BOARDS_Y - hh, e[3]],
                  [e[2], BOARDS_Y + hh, e[3]], [e[0], BOARDS_Y + hh, e[1]],
                  [u0, v0, u1, v0, u1, v1, u0, v1]);
                break;
              }
          }
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
      var e = (at == SMALL_LEDS ? SMALL_LED_SIZE : LED_SIZE) / 2;
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
        t >= Const.TILE_MIL_GUN_LOCKER;
    }

// a mirror on the wall over each of a basin run's basins, military/mirror's whole 3:4 on a pane
  static function mirrors(m:Facility, col:Int, row:Int, cell:Rect, dir:Int, len:Int):Void
    {
      var b = MilitaryGeom.buf(TEX_MIRROR);
      var face = back(m, col, row, cell, dir, BOARD_OFF);
      for (i in 0...len)
        for (k in [ -1, 1 ])
          {
            var c = cut(face, dir < 2, i, 1);
            var o = (dir < 2 ? (c.x0 + c.x1) / 2 : (c.z0 + c.z1) / 2) + k * SINK_STEP;
            FacilityGeom.pane(b, (dir < 2 ? o - MIRROR_W / 2 : c.x0), (dir < 2 ? o + MIRROR_W / 2 : c.x1),
              (dir < 2 ? c.z0 : o - MIRROR_W / 2), (dir < 2 ? c.z1 : o + MIRROR_W / 2), dir ^ 1, MIRROR_Y,
              MIRROR_Y + MIRROR_H);
          }
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
          // the door, a slab STALL_DOOR_T thick across the open side, its outer face and its inner
          // one: one-sided it was a hole seen from inside the cubicle ("these quads should have other
          // side as well")
          var b = a0 + i * CELL;
          var o = dir ^ 1;
          var door:Rect = (alongX ? {
            x0: b,
            x1: b + CELL,
            z0: (o == 0 ? r.z0 : r.z1 - STALL_DOOR_T),
            z1: (o == 0 ? r.z0 + STALL_DOOR_T : r.z1),
          } : {
            x0: (o == 2 ? r.x0 : r.x1 - STALL_DOOR_T),
            x1: (o == 2 ? r.x0 + STALL_DOOR_T : r.x1),
            z0: b,
            z1: b + CELL,
          });
          for (d in [ o, dir ])
            FacilityGeom.pane(doors, door.x0, door.x1, door.z0, door.z1, d, 0, STALL_H);
        }
    }

// a run's cells cut to `d` off the room face of the wall on side `dir`, `gap` clear of it
  static function back(m:Facility, col:Int, row:Int, cell:Rect, dir:Int, d:Float,
      gap:Float = 0.0):Rect
    {
      var sl = FacilityGeom.slab(m, col + DX[dir], row + DZ[dir]);
      return switch (dir)
        {
          case 0: { x0: cell.x0, x1: cell.x1, z0: sl.z1 + gap, z1: sl.z1 + gap + d };
          case 1: { x0: cell.x0, x1: cell.x1, z0: sl.z0 - gap - d, z1: sl.z0 - gap };
          case 2: { x0: sl.x1 + gap, x1: sl.x1 + gap + d, z0: cell.z0, z1: cell.z1 };
          default: { x0: sl.x0 - gap - d, x1: sl.x0 - gap, z0: cell.z0, z1: cell.z1 };
        };
    }

// the wall a piece backs onto, of the `dirs` that are plain masonry, a latrine's light well up under the
// ceiling (or glazing, with `glass`): one with open floor in front of it first. A shelf in a store's
// corner found the end wall first and stood facing into the next shelf along, its front against that
// one's side
  static function backing(m:Facility, col:Int, row:Int, dirs:Array<Int>, glass:Bool = false):Int
    {
      var dir = -1;
      for (d in dirs)
        if (FacilityModel.isSolidWall(m, col + DX[d], row + DZ[d]) ||
            m.wall[row + DZ[d]][col + DX[d]] == Wall.WINDOW_HIGH ||
            glass &&
            FacilityModel.isWall(m, col + DX[d], row + DZ[d]))
          {
            if (m.fit[row - DZ[d]][col - DX[d]] == 0 &&
                !FacilityModel.isWall(m, col - DX[d], row - DZ[d]))
              return d;
            if (dir < 0)
              dir = d;
          }
      return dir;
    }

// how far off its wall a piece backed onto it at `dir` stands: on a window, the line of the masonry's
// face either side, the glazing being set (WALL_T - GLASS_T) / 2 deeper into the wall
  static function sill(m:Facility, col:Int, row:Int, dir:Int):Float
    {
      return (FacilityModel.isSolidWall(m, col + DX[dir], row + DZ[dir]) ? 0.0 :
        (FacilityStyle.WALL_T - FacilityStyle.GLASS_T) / 2);
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
