package render.lab;

import three.Three;
import citygen.CityConfig;
import gen.lab.LabKinds;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityStyle;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// one batch's art: the glb, the height it is drawn at, its depth across the wall it backs onto (at
// that height and after `turn`), how far off the floor its lowest point hangs, and the turn that
// brings a GENERATED glb's front round to +z — TRELLIS keeps whatever yaw the reference implied, so a
// machine can come back facing its own flank (docs/3d-models.md)
typedef LabPieceArt = {
  path:String,
  h:Float,
  d:Float,
  ?y:Float,
  ?turn:Float,
  ?w:Float,         // its width along the footprint, when it is shorter than the footprint (a
                    // generated machine keeps its own proportions); the footprint's otherwise
  ?glass:LabPieceArt,             // a see-through shell drawn as its own transparent batch at the
                                  // same place and turn (a jar's wall, a box's panes)
  ?ox:Float,                      // a glass shell's own centre off its body's, to the body's right,
  ?oz:Float,                      // and toward its front: Models.normalize centres every glb on its
                                  // own bbox, and a shell over part of a machine is not centred on it
  ?flame:LabAnchor,               // where a burner's gas flame stands on it (LabFlames)
  ?leds:Array<LabAnchor>,         // its blinking status lights, each facing the piece's front
};

// a point on a piece in its own frame, in world units at the height the piece is drawn: x to its
// right, y up off its foot, z toward its front, from its footprint's centre
typedef LabAnchor = {
  x:Float,
  y:Float,
  z:Float,
};

// what a build plans before the batches exist: every placement, by path
typedef LabInteriorPlan = {
  places:Map<String, Array<Models.PropPlace>>,
  heights:Map<String, Float>,
  lids:Array<LabDecals.LabLid>,     // the bench tops render.lab.LabDecals lays clutter on
  flames:Array<LabFlames.LabFlame>, // the burners' flames render.lab.LabFlames draws
  leds:Array<{ x:Float, y:Float, z:Float, yaw:Float }>, // the kit's status lights, in the world
};

// the underground lab's furniture and its box machines: everything the generator stands as a Const
// row-23 tile or a gen.lab.LabKinds origin, drawn as one instanced batch per glb (models-src/lab/
// labkit_build.py, boxkit_build.py).
//
// A PIECE BACKS ONTO ITS WALL. Furniture stands one per cell in the wall's margin (the tile is
// walkable, the piece is not in the way of the cell's centre), so it is pushed back until its back is
// on the masonry's face — FacilityGeom.wallFace, one unit into the wall cell — and turned to face away
// from it. A wall MACHINE's footprint touches its wall (gen.lab.LabRooms.wallMachines), so it is
// pushed back the same way; one out on the floor stands on its footprint's centre at a hashed turn.
//
// TWO STEPS, because they fall either side of render.Chunks.build: `plan` reads the grid and lays
// every contact shadow (the ContactMask field is repainted before the chunks), `build` makes the
// batches after them — an instanced batch sits at the origin, and one built before the chunks would
// be bucketed into the chunk there and culled with it
class LabInterior
{
  static inline var CELL = CityConfig.CELL;
  static var HALF_PI = Math.PI / 2;
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the tables below, built on first use: they read Const's and RenderConfig's statics, and a static
  // initialiser here could run before theirs
  static var tables:{
    furniture:Map<Int, LabPieceArt>,
    machines:Map<String, LabPieceArt>,
    shelfRow:LabPieceArt,
    drum:LabPieceArt,
    crate:LabPieceArt,
    work:Array<LabPieceArt>,
    plants:Array<LabPieceArt>,
    suits:Array<LabPieceArt>,
    tops:Array<Array<LabPieceArt>>,
  } = null;

// the art tables: the furniture by Const row-23 tile (a PLANT is one of the generated pots by hash),
// the store's free-standing rows, the drums and the crates, the machines by gen.lab.LabKinds name —
// hand-modelled and generated alike — and the suits a hazmat rack hangs
  static function art():{
    furniture:Map<Int, LabPieceArt>,
    machines:Map<String, LabPieceArt>,
    shelfRow:LabPieceArt,
    drum:LabPieceArt,
    crate:LabPieceArt,
    work:Array<LabPieceArt>,
    plants:Array<LabPieceArt>,
    suits:Array<LabPieceArt>,
    tops:Array<Array<LabPieceArt>>,
  }
    {
      if (tables != null)
        return tables;
      var M = RenderConfig.MODELS;
      tables = {
        furniture: [
          Const.TILE_LAB_BENCH => row(M.labBench, 1.96, 2.4),
          Const.TILE_LAB_WORKBENCH => row(M.labWorkbench, 3.3, 2.6),
          Const.TILE_LAB_CONSOLE => row(M.labDesk, 1.55, 2.4),
          Const.TILE_LAB_SHELF => row(M.labShelf, 4.6, 1.6),
          Const.TILE_LAB_SHELF_LOW => row(M.labShelfLow, 2.6, 1.44),
          Const.TILE_LAB_LOCKER => row(M.labLocker, 4.4, 1.6),
          Const.TILE_LAB_HAZMAT => row(M.labHazmat, 4.2, 1.1),
          Const.TILE_LAB_SEAT => row(M.labSeat, 2.1, 1.195),
          Const.TILE_LAB_FRIDGE => row(M.labFridge, 4.4, 2.0),
          Const.TILE_LAB_BIN => gen('bin', 2.660, 2.170, 2.100),
        ],
        machines: [
          'sr203' => row(M.labBoxSr203, 3.0, 2.84),
          'vault' => row(M.labBoxVault, 5.2, 6.44),
          'drawercab' => row(M.labBoxDrawercab, 4.6, 2.24),
          'radlocker' => row(M.labBoxRadlocker, 4.4, 1.84),
          'drawers' => row(M.labBoxDrawers, 3.6, 1.84),
          'coldbank' => row(M.labBoxColdbank, 4.8, 2.64),
          'powerbox' => row(M.labBoxPowerbox, 4.6, 1.84),
          'leverbox' => row(M.labBoxLeverbox, 4.7, 1.0, 1.3),
          'controlbox' => row(M.labBoxControlbox, 6.0, 1.2),
          'container' => row(M.labContainer, 5.22, 6.56),
          // the hand-modelled machines (models-src/lab/mach/<name>.py, art/models.json lab/<name>), at
          // the size they were built: height, depth, width; a glass shell and status lights where they
          // have them
          'reactor' => glazed(gen('reactor', 4.340, 7.200, 7.200),
            shell('reactor-glass', 1.300, 5.040, 5.040, 2.680, 0.000, 0.000)),
          'screenwall' => lit(gen('screenwall', 5.000, 2.225, 5.270), [
            {
              x: -2.475,
              y: 3.7,
              z: 1.11,
            },
            {
              x: 1.815,
              y: 0.25,
              z: 0.99,
            },
            {
              x: 1.895,
              y: 4.92,
              z: 0.81,
            },
            {
              x: -2.035,
              y: 3.71,
              z: 1.0,
            },
            {
              x: -2.035,
              y: 2.71,
              z: 1.0,
            },
            {
              x: -2.035,
              y: 1.71,
              z: 1.0,
            },
            {
              x: -2.035,
              y: 0.71,
              z: 1.0,
            },
            {
              x: -0.535,
              y: 3.71,
              z: 1.0,
            },
            {
              x: -0.535,
              y: 2.71,
              z: 1.0,
            },
            {
              x: -0.535,
              y: 1.71,
              z: 1.0,
            },
            {
              x: -0.535,
              y: 0.71,
              z: 1.0,
            },
            {
              x: 0.965,
              y: 3.71,
              z: 1.0,
            },
            {
              x: 0.965,
              y: 2.71,
              z: 1.0,
            },
            {
              x: 0.965,
              y: 1.71,
              z: 1.0,
            },
            {
              x: 0.965,
              y: 0.71,
              z: 1.0,
            },
          ]),
          'hatchbox' => glazed(gen('hatchbox', 4.350, 3.324, 4.300),
            shell('hatchbox-glass', 1.620, 0.100, 1.620, 1.990, -0.200, 1.558)),
          'dialtank' => gen('dialtank', 3.580, 3.446, 3.400),
          'switchrack' => gen('switchrack', 4.870, 2.162, 4.760),
          'holo' => lit(gen('holo', 3.800, 3.582, 4.824), [
            {
              x: 1.411,
              y: 1.853,
              z: 1.509,
            },
          ]),
          'monitorstack' => lit(gen('monitorstack', 5.044, 2.480, 3.474), [
            {
              x: 1.243,
              y: 4.915,
              z: 1.135,
            },
            {
              x: 0.713,
              y: 2.805,
              z: 1.145,
            },
          ]),
          'pipecapsule' => gen('pipecapsule', 3.305, 2.687, 6.600),
          'tentacle' => gen('tentacle', 5.304, 3.596, 5.320),
          'bioscreen' => gen('bioscreen', 3.960, 3.520, 5.120),
          'upw' => gen('upw', 4.620, 2.950, 4.810),
          'tube' => glazed(gen('tube', 4.620, 3.200, 3.200),
            shell('tube-glass', 2.660, 2.240, 2.240, 0.980, 0.000, 0.000)),
          'autopsy' => gen('autopsy', 4.030, 3.560, 5.160),
          'terminal' => gen('terminal', 3.800, 2.680, 5.530),
          'restraint' => gen('restraint', 3.770, 3.264, 3.200),
          'cryopod' => glazed(gen('cryopod', 3.010, 3.400, 5.400),
            shell('cryopod-glass', 0.820, 1.966, 2.520, 2.370, -0.850, 0.000)),
          'stasis' => lit(gen('stasis', 5.070, 2.680, 2.850), [
            {
              x: 0.8,
              y: 3.43,
              z: 1.2,
            },
            {
              x: -0.82,
              y: 1.91,
              z: 1.2,
            },
          ]),
          'bioprinter' => gen('bioprinter', 5.470, 4.645, 5.300),
          'brainscan' => gen('brainscan', 4.534, 2.700, 5.584),
          'centrifuge' => gen('centrifuge', 3.950, 7.200, 7.200),
          'embryonic' => lit(gen('embryonic', 5.570, 2.210, 6.600), [
            {
              x: -1.48,
              y: 4.91,
              z: 0.965,
            },
            {
              x: 1.656,
              y: 4.91,
              z: 0.965,
            },
          ]),
          'gestation' => gen('gestation', 3.493, 7.360, 7.200),
          'incubator' => lit(glazed(gen('incubator', 5.180, 2.580, 5.200),
            shell('incubator-glass', 3.840, 0.040, 3.840, 0.520, 0.000, 1.100)), [
            {
              x: 0.318,
              y: 4.82,
              z: 0.21,
            },
            {
              x: 2.21,
              y: 0.46,
              z: 1.275,
            },
          ]),
          'ambertanks' => lit(glazed(gen('ambertanks', 4.920, 3.230, 6.250),
            shell('ambertanks-glass', 2.670, 2.700, 5.650, 1.080, 0.050, -0.115)), [
            {
              x: 0.375,
              y: 4.0,
              z: 1.55,
            },
          ]),
          'specimencase' => lit(glazed(gen('specimencase', 4.860, 3.080, 7.700),
            shell('specimencase-glass', 3.050, 0.040, 6.490, 1.025, 0.000, 1.360)), [
            {
              x: -3.01,
              y: 0.8,
              z: 1.5,
            },
            {
              x: -2.89,
              y: 0.8,
              z: 1.5,
            },
            {
              x: -2.77,
              y: 0.8,
              z: 1.5,
            },
          ]),
          'processor' => gen('processor', 4.820, 3.400, 6.680),
          'cryobank' => glazed(gen('cryobank', 5.480, 4.875, 8.620),
            shell('cryobank-glass', 2.460, 0.410, 4.460, 2.220, -0.140, 2.148)),
          'rack8' => gen('rack8', 4.490, 2.600, 7.570),
          'rack6' => gen('rack6', 4.550, 2.833, 6.760),
          'canisters' => gen('canisters', 5.360, 2.327, 5.160),
          'generator' => glazed(gen('generator', 4.889, 2.845, 7.340),
            shell('generator-glass', 0.984, 0.030, 2.149, 0.880, 1.534, 1.303)),
          'press' => gen('press', 4.320, 2.600, 3.520),
          'robotarm' => gen('robotarm', 5.349, 2.020, 2.724),
          'incinerator' => gen('incinerator', 4.960, 3.554, 4.622),
          'kiosk' => gen('kiosk', 4.000, 1.260, 1.900),
          'cagecase' => glazed(gen('cagecase', 2.944, 3.474, 5.420),
            shell('cagecase-glass', 1.880, 2.900, 5.000, 0.000, 0.000, 0.077)),
          'sheetcage' => gen('sheetcage', 3.300, 3.514, 6.280),
          'gurney' => gen('gurney', 2.724, 2.320, 5.420),
          'gurneys' => gen('gurneys', 3.077, 2.219, 5.340),
          'tarpcrate' => gen('tarpcrate', 2.988, 3.408, 5.348),
          'palletcrate' => gen('palletcrate', 1.958, 3.323, 5.800),
          'scanframe' => gen('scanframe', 2.860, 3.280, 7.400),
        ],
        shelfRow: row(M.labShelfRow, 4.6, 2.4),
        drum: row(M.labDrum, 1.84, 1.26),
        crate: row(M.labCrate, 1.8, 2.0),
        // the facility's workstation on every computer desk, the one reuse the lab is allowed: the
        // monitor, the tower and the keyboard (render.facility.FacilityWork's three glbs)
        work: [
          row(M.facilityMonitor, FacilityStyle.WORK_FOOT_H + FacilityStyle.WORK_STAND_H +
            FacilityStyle.WORK_SCREEN_H, FacilityStyle.WORK_FOOT_D),
          row(M.facilityTower, FacilityStyle.WORK_TOWER_H, FacilityStyle.WORK_TOWER_D),
          row(M.facilityKeyboard, FacilityStyle.WORK_KEY_H, FacilityStyle.WORK_KEY_D),
        ],
        // a PLANT cell's pot, one of these by hash
        plants: [
          gen('plant2', 3.0, 2.3, 2.24),
          gen('plant3', 3.2, 1.69, 1.73),
          gen('plant5', 3.2, 1.58, 1.5),
          gen('plant6', 2.499, 1.920, 2.476),
          gen('plant1', 2.829, 2.964, 2.892),
          gen('plant4', 2.270, 2.317, 2.210),
        ],
        // what hangs on a hazmat rack's rail, and the one left in a heap under it
        suits: [
          gen('suit', LabStyle.SUIT_H, 0.63, 1.25),
          gen('suitfloor', 1.0, 1.86, 2.24),
          gen('suittorn', LabStyle.SUIT_H, 0.61, 1.27),
        ],
        // what stands on a bench top, by the lid's sheet: [0] every room's but the workshop's, [1] the
        // workshop's
        tops: [
          [
            bench('microscope', 1.0, 0.32, 0.47),
            fire(bench('bunsen', 0.5, 0.355, 0.64), {
              x: -0.15,
              y: 0.5,
              z: 0.0075,
            }),
            bench('mortar', 0.391, 0.472, 0.436),
            bench('tuberack', 0.42, 0.18, 0.58),
            bench('desklamp', 0.639, 0.483, 0.423),
            bench('aidcase', 0.3, 0.538, 0.7),
            bench('radio', 0.761, 0.356, 0.524),
            bench('bottles', 0.56, 0.364, 0.54),
            blink(bench('labelprinter', 0.34, 0.483, 0.46), {
              x: 0.186,
              y: 0.058,
              z: 0.171,
            }),
            glazed(bench('specbox', 0.63, 0.37, 0.52), bench('specbox-glass', 0.41, 0.29, 0.44, 0.095)),
            glazed(bench('embryojar', 0.635, 0.348, 0.348, 0.095), bench('embryojar-glass', 0.65, 0.33, 0.33)),
            blink(bench('minifuge', 0.325, 0.441, 0.43), {
              x: 0.098,
              y: 0.143,
              z: 0.207,
            }),
            bench('pipette', 0.63, 0.3, 0.3),
          ],
          [
            bench('welder', 0.79, 0.774, 0.784),
            bench('drillpress', 1.4, 0.713, 0.46),
            bench('armkit', 0.622, 0.48, 0.564),
            bench('cleaner', 0.404, 0.412, 0.5),
            bench('grinder', 0.347, 0.32, 0.59),
            bench('toolbox', 0.462, 0.403, 0.584),
            bench('multimeter', 0.126, 0.45, 0.44),
            bench('hvcases', 0.492, 0.465, 0.584),
          ],
        ],
      };
      return tables;
    }

// one table row
  static function row(path:String, h:Float, d:Float, ?y:Float):LabPieceArt
    {
      return {
        path: path,
        h: h,
        d: d,
        y: y,
      };
    }

// one bench-top row, hand-modelled at world scale (models-src/lab/top_build.py), so its height, depth
// and width ARE the glb's own: models/lab/lab-top-<name>.glb, lifted `y` off the lid when it is a
// body standing inside its own glass
  static function bench(name:String, h:Float, d:Float, w:Float, ?y:Float):LabPieceArt
    {
      return {
        path: 'models/lab/lab-top-' + name + '.glb',
        h: h,
        d: d,
        w: w,
        y: y,
      };
    }

// a row with its glass shell, its burner's flame or its status light, returned for the table
  static function glazed(a:LabPieceArt, g:LabPieceArt):LabPieceArt
    {
      a.glass = g;
      return a;
    }

// a machine's glass shell: models/lab/<name>.glb at height h, `y` off the floor, its centre `ox` to the
// body's right and `oz` toward its front
  static function shell(name:String, h:Float, d:Float, w:Float, y:Float, ox:Float,
      oz:Float):LabPieceArt
    {
      return {
        path: 'models/lab/' + name + '.glb',
        h: h,
        d: d,
        w: w,
        y: y,
        ox: ox,
        oz: oz,
      };
    }

  static function fire(a:LabPieceArt, at:LabAnchor):LabPieceArt
    {
      a.flame = at;
      return a;
    }

  static function blink(a:LabPieceArt, at:LabAnchor):LabPieceArt
    {
      a.leds = [at];
      return a;
    }

  static function lit(a:LabPieceArt, at:Array<LabAnchor>):LabPieceArt
    {
      a.leds = at;
      return a;
    }

// one generated row: models/lab/<name>.glb
  static function gen(name:String, h:Float, d:Float, w:Float, ?turn:Float):LabPieceArt
    {
      return {
        path: 'models/lab/' + name + '.glb',
        h: h,
        d: d,
        w: w,
        turn: turn,
      };
    }

// every placement off the area's grid, and every piece's contact shadow
  public static function plan(m:Facility, tile:(Int, Int)->Int):LabInteriorPlan
    {
      var p:LabInteriorPlan = {
        places: new Map(),
        heights: new Map(),
        lids: [],
        flames: [],
        leds: [],
      };
      var A = art();
      // the grid as gen.lab.LabKinds.alongX reads it, column-major
      var cells = [for (x in 0...m.w) [for (y in 0...m.h) tile(x, y)]];
      for (r in 0...m.h)
        for (col in 0...m.w)
          {
            var t = cells[col][r];
            var a = (t == Const.TILE_LAB_PLANT ?
              A.plants[FacilityModel.mix((col * 83492791) ^ (r * 73856093)) % A.plants.length] :
              A.furniture.get(t));
            if (a != null)
              furniture(p, m, tile, col, r, t, a);
            else if (t == Const.TILE_LAB_SHELF_ROW)
              shelfRow(p, m, tile, col, r);
            else if (t == Const.TILE_LAB_DRUMS ||
                t == Const.TILE_LAB_CRATES)
              stack(p, m, col, r, t);
            else
              {
                var k = LabKinds.kindAt(t);
                if (k != null &&
                    A.machines.exists(k.name))
                  machine(p, m, cells, col, r, k, A.machines.get(k.name));
              }
          }
      return p;
    }

// one batch per planned path, mask-patched and not casting — every piece stands under a room lamp
// that does not cast, and an instanced caster is a second call whenever it is in view
  public static function build(scene:Scene, p:LabInteriorPlan):Array<Models.InstancedProp>
    {
      leds(scene, p.leds);
      return [for (path in p.places.keys()) batch(scene, path, p.places.get(path), p.heights.get(path))];
    }

// the kit's status lights: one speck each in render.facility.FacilityDeco's own blinking mesh, a rack
// port's square wave on its own hashed phase, burning that mesh's green. The compound's material and
// clock, so the whole lab's lights are one draw call and nothing new to compile
  static function leds(scene:Scene, at:Array<{ x:Float, y:Float, z:Float, yaw:Float }>):Void
    {
      if (at.length == 0)
        return;
      var b = MeshBufTools.make();
      var s = LabStyle.TOP_LED_SZ / 2;
      for (l in at)
        {
          // proud of the face along the piece's front, `r` across it
          var nx = Math.sin(l.yaw), nz = Math.cos(l.yaw);
          var rx = Math.cos(l.yaw), rz = -Math.sin(l.yaw);
          var cx = l.x + nx * LabStyle.TOP_LED_EPS, cz = l.z + nz * LabStyle.TOP_LED_EPS;
          var h = FacilityModel.mix(Std.int(l.x * 977) ^ (Std.int(l.z * 131) << 10));
          MeshBufTools.quadRGB(b,
            [cx - rx * s, l.y - s, cz - rz * s], [cx + rx * s, l.y - s, cz + rz * s],
            [cx + rx * s, l.y + s, cz + rz * s], [cx - rx * s, l.y + s, cz - rz * s],
            [0, 0, 1, 0, 1, 1, 0, 1], 1.0, (h % 1000) / 1000, 1.0);
        }
      render.facility.FacilityDeco.lamps(scene, b);
    }

// one of every piece at the origin, for render.lab.LabWarm. Returns the paths to wait on
  public static function warm(scene:Scene):Array<String>
    {
      var A = art();
      var all = [for (a in A.furniture) a].concat([A.shelfRow, A.drum, A.crate])
        .concat([for (a in A.machines) a]).concat(A.work).concat(A.plants).concat(A.suits)
        .concat(A.tops[0]).concat(A.tops[1]);
      all = all.concat([for (a in all) if (a.glass != null) a.glass]);
      leds(scene, [{
        x: 0.0,
        y: 0.0,
        z: 0.0,
        yaw: 0.0,
      }]);
      for (a in all)
        batch(scene, a.path, [{
          x: 0.0,
          z: 0.0,
          yaw: 0.0,
        }], a.h);
      return [for (a in all) a.path];
    }

// the machines' screens and windows as the lab's power goes: every glowing batch's emissive scaled
// by `f`, 1 lit to 0 dark, off the strength its glb carries (taken once, on the shared template —
// only the lab draws these paths)
  public static function dim(batches:Array<Models.InstancedProp>, f:Float):Void
    {
      for (b in batches)
        {
          if (b.mesh == null)
            continue;
          // Dynamic: the loaded glb's material, which the three extern types as Dynamic on Object3D —
          // it is Models.toLambert's MeshLambertMaterial
          var mat:Dynamic = b.mesh.material;
          if (mat.emissiveMap == null)
            continue;
          if (mat.userData.labEmi == null)
            mat.userData.labEmi = mat.emissiveIntensity;
          mat.emissiveIntensity = mat.userData.labEmi * f;
        }
    }

// a glass shell's look, set once on the shared template material (only the lab draws these paths):
// render.lab.LabVats.dress's vat glass, a faint double-sided tint that writes no depth, so what the
// body holds inside it (an embryo, a specimen) shows through
  // Dynamic: the loaded glb's material, which the three extern types as Dynamic on Object3D — it is
  // Models.toLambert's MeshLambertMaterial
  static function glass(mat:Dynamic):Void
    {
      mat.transparent = true;
      mat.opacity = LabStyle.TOP_GLASS_OPACITY;
      mat.depthWrite = false;
      mat.side = THREE.DoubleSide;
      mat.needsUpdate = true;
    }

// one batch
  static function batch(scene:Scene, path:String, places:Array<Models.PropPlace>, h:Float):Models.InstancedProp
    {
      var prop = Models.instanced(scene, path, places, h, SOLID);
      Models.get(path, function(_)
        {
          if (StringTools.endsWith(path, '-glass.glb'))
            glass(prop.mesh.material);
          VisionMask.patchMesh(prop.mesh);
          prop.mesh.castShadow = false;
        });
      return prop;
    }

// a piece and what goes with it: its glass shell at the same place, its burner's flame and its status
// lights turned into the world with it. `phase` is the flame's flicker phase
  static function dress(p:LabInteriorPlan, a:LabPieceArt, x:Float, z:Float, yaw:Float, y:Float,
      phase:Float):Void
    {
      put(p, a, x, z, yaw, y);
      // the shell's offset and the anchors are in the piece's own frame, so they turn with its yaw
      var t = yaw + (a.turn != null ? a.turn : 0.0);
      var c = Math.cos(t), sy = Math.sin(t);
      var g = a.glass;
      if (g != null)
        {
          var ox = (g.ox != null ? g.ox : 0.0), oz = (g.oz != null ? g.oz : 0.0);
          put(p, g, x + ox * c + oz * sy, z - ox * sy + oz * c, yaw, y);
        }
      if (a.flame != null)
        p.flames.push({
          x: x + a.flame.x * c + a.flame.z * sy,
          y: y + a.flame.y,
          z: z - a.flame.x * sy + a.flame.z * c,
          phase: phase,
        });
      if (a.leds != null)
        for (e in a.leds)
          p.leds.push({
            x: x + e.x * c + e.z * sy,
            y: y + e.y,
            z: z - e.x * sy + e.z * c,
            yaw: t,
          });
    }

// one placement onto its path's list
  static function put(p:LabInteriorPlan, a:LabPieceArt, x:Float, z:Float, yaw:Float, ?y:Float):Void
    {
      if (!p.places.exists(a.path))
        {
          p.places.set(a.path, []);
          p.heights.set(a.path, a.h);
        }
      p.places.get(a.path).push({
        x: x,
        z: z,
        yaw: yaw + (a.turn != null ? a.turn : 0.0),
        y: (y != null ? y : 0.0) + (a.y != null ? a.y : 0.0),
      });
    }

// which hand of a cell its wall is on, 0..3 as DC/DR, or -1. A corner cell takes the wall its run
// does not run along, so a corner piece lines up with the rest of its run
  static function wallOf(m:Facility, tile:(Int, Int)->Int, col:Int, row:Int):Int
    {
      var t = tile(col, row);
      var alongX = (tile(col - 1, row) == t ||
        tile(col + 1, row) == t);
      var alongZ = (tile(col, row - 1) == t ||
        tile(col, row + 1) == t);
      var best = -1;
      for (d in 0...4)
        {
          if (!FacilityModel.isWall(m, col + DC[d], row + DR[d]))
            continue;
          if ((d < 2 && alongZ && !alongX) ||
              (d >= 2 && alongX && !alongZ))
            continue;
          if (best < 0)
            best = d;
        }
      return best;
    }

// the yaw that faces a piece away from the wall on hand `d`
  static inline function away(d:Int):Float
    {
      return Math.atan2(-DC[d], -DR[d]);
    }

// how far past its cell's edge the masonry's face stands on hand `d`
  static function faceOff(m:Facility, col:Int, row:Int, d:Int):Float
    {
      return CELL / 2 - FacilityGeom.wallFace(m, col + DC[d], row + DR[d], d ^ 1);
    }

// a furniture piece backed onto its wall, and its run's shadow if this cell starts the run
  static function furniture(p:LabInteriorPlan, m:Facility, tile:(Int, Int)->Int, col:Int, row:Int,
      t:Int, a:LabPieceArt):Void
    {
      var d = wallOf(m, tile, col, row);
      if (d < 0)
        return;
      var c = CityConfig.cellToWorld(col, row);
      // the cell centre to the wall face, less half the piece's depth
      var back = CELL / 2 + faceOff(m, col, row, d) - a.d / 2;
      put(p, a, c.x + DC[d] * back, c.z + DR[d] * back, away(d));
      if (t == Const.TILE_LAB_CONSOLE)
        work(p, c.x + DC[d] * back, c.z + DR[d] * back, d, a.h);
      if (t == Const.TILE_LAB_HAZMAT)
        suits(p, c.x + DC[d] * back, c.z + DR[d] * back, d, col, row);
      if (t == Const.TILE_LAB_BENCH ||
          t == Const.TILE_LAB_WORKBENCH)
        top(p, m, c.x + DC[d] * back, c.z + DR[d] * back, d, col, row, t == Const.TILE_LAB_WORKBENCH);
      // a run's shadow once, from its first cell (lowest col/row) along the wall
      var alongX = (d < 2);
      if (tile(col - (alongX ? 1 : 0), row - (alongX ? 0 : 1)) == t &&
          wallOf(m, tile, col - (alongX ? 1 : 0), row - (alongX ? 0 : 1)) == d)
        return;
      var n = 1;
      while (tile(col + (alongX ? n : 0), row + (alongX ? 0 : n)) == t &&
          wallOf(m, tile, col + (alongX ? n : 0), row + (alongX ? 0 : n)) == d)
        n++;
      var cx = c.x + DC[d] * back + (alongX ? (n - 1) * CELL / 2 : 0.0);
      var cz = c.z + DR[d] * back + (alongX ? 0.0 : (n - 1) * CELL / 2);
      var hw = (alongX ? n * CELL / 2 : a.d / 2);
      var hd = (alongX ? a.d / 2 : n * CELL / 2);
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: n,
        alongX: alongX,
        rect: {
          x0: cx - hw,
          x1: cx + hw,
          z0: cz - hd,
          z1: cz + hd,
        },
        h: a.h,
      });
    }

// a bench's top for render.lab.LabDecals, in the piece's own frame (models-src/lab/labkit_build.py): the
// lab table's whole epoxy top, the workbench's butcher block short of its back upstand and clear of
// the vice on its front corner. A workshop's tops deal off the workshop sheet, every other room's
// off the research one
  static function top(p:LabInteriorPlan, m:Facility, x:Float, z:Float, d:Int, col:Int, row:Int,
      heavy:Bool):Void
    {
      var yaw = away(d);
      var off = (heavy ? 0.1 : 0.0);
      var l:LabDecals.LabLid = {
        x: x + Math.sin(yaw) * off,
        z: z + Math.cos(yaw) * off,
        yaw: yaw,
        w: (heavy ? 3.6 : 3.8),
        d: (heavy ? 2.1 : 2.2),
        y: (heavy ? 2.0 : 1.96),
        workshop: (m.surf[row][col] == Surf.LAB_WORKSHOP),
        keeps: (heavy ? [{
          x: 1.45,
          z: 0.95,
          r: 0.45,
        }] : []),
      };
      p.lids.push(l);
      kit(p, l, col, row);
    }

// a lid's standing kit off art().tops: one piece at a hashed end of its back edge, a second at the
// other end on TOP_PAIR in a hundred, each kept out of the lid for the flat clutter. The pick, the
// end and a small turn are hashed off the cell
  static function kit(p:LabInteriorPlan, l:LabDecals.LabLid, col:Int, row:Int):Void
    {
      var list = art().tops[l.workshop ? 1 : 0];
      var h = FacilityModel.mix((col * 19349663) ^ (row * 83492791));
      var k = [(h >>> 8) % list.length];
      if (h % 100 < LabStyle.TOP_PAIR)
        k.push((k[0] + 1 + (h >>> 16) % (list.length - 1)) % list.length);
      var side = (((h >>> 4) & 1) == 0 ? -1.0 : 1.0);
      var cs = Math.cos(l.yaw), sn = Math.sin(l.yaw);
      for (i in 0...k.length)
        {
          var a = list[k[i]];
          var r = Math.max(a.w, a.d) / 2;
          var lx = side * (l.w / 2 - r - LabStyle.TOP_MARGIN);
          var lz = -l.d / 2 + r + LabStyle.TOP_MARGIN;
          l.keeps.push({
            x: lx,
            z: lz,
            r: r,
          });
          // the lid's frame into the world as LabDecals.lid turns it
          var x = l.x + lx * cs + lz * sn, z = l.z - lx * sn + lz * cs;
          var yaw = l.yaw + ((h >>> (20 + i * 4)) % 9 - 4) * LabStyle.TOP_JITTER;
          dress(p, a, x, z, yaw, l.y, (h % 628) / 100);
          side = -side;
        }
    }

// a desk's workstation on its top: the screen at the back, the keyboard before it, the tower at the
// end away from the drawer pedestal
  static function work(p:LabInteriorPlan, x:Float, z:Float, d:Int, top:Float):Void
    {
      var w = art().work;
      // `out` away from the wall, `side` along it to the desk's left as you face it (its drawer
      // pedestal is on the right, models-src/lab/labkit_build.py desk)
      var ox = -DC[d], oz = -DR[d];
      var sx = -oz, sz = ox;
      put(p, w[0], x - ox * 0.4, z - oz * 0.4, away(d), top);
      put(p, w[2], x + ox * 0.55, z + oz * 0.55, away(d), top);
      put(p, w[1], x + sx * 1.35 - ox * 0.2, z + sz * 1.35 - oz * 0.2, away(d), top);
    }

// a hazmat rack's suits: up to SUIT_N on its rail at hashed gaps, one hook in SUIT_TORN holding the
// torn and bloodied one, and now and then one dropped in a heap in front of it. The rail is SUIT_RAIL
// out from the rack's centre and the suit's hook is its top
  static function suits(p:LabInteriorPlan, x:Float, z:Float, d:Int, col:Int, row:Int):Void
    {
      var S = art().suits;
      var h = FacilityModel.mix((col * 19349663) ^ (row * 83492791));
      var ox = -DC[d], oz = -DR[d];
      var sx = -oz, sz = ox;
      var out = LabStyle.SUIT_RAIL;
      var y = LabStyle.SUIT_HOOK - LabStyle.SUIT_H;
      for (i in 0...LabStyle.SUIT_N)
        {
          // a hook in four is empty
          if ((h >>> (i * 3)) % 4 == 0)
            continue;
          var s = (i - (LabStyle.SUIT_N - 1) / 2) * LabStyle.SUIT_GAP;
          var yaw = away(d) + (((h >>> (i * 3 + 12)) % 7) - 3) * 0.05;
          var torn = ((h >>> (i * 3 + 20)) % LabStyle.SUIT_TORN == 0);
          put(p, S[torn ? 2 : 0], x + ox * out + sx * s, z + oz * out + sz * s, yaw, y);
        }
      if ((h >>> 24) % 3 == 0)
        put(p, S[1], x + ox * (out + 1.4), z + oz * (out + 1.4), away(d) + ((h >>> 26) % 4) * 0.7);
    }

// a store's free-standing shelf row: on its cell's centre, its faces across the row's run
  static function shelfRow(p:LabInteriorPlan, m:Facility, tile:(Int, Int)->Int, col:Int, row:Int):Void
    {
      var t = Const.TILE_LAB_SHELF_ROW;
      var a = art().shelfRow;
      var alongX = (tile(col - 1, row) == t ||
        tile(col + 1, row) == t);
      var c = CityConfig.cellToWorld(col, row);
      put(p, a, c.x, c.z, (alongX ? 0.0 : Math.PI / 2));
      var hw = (alongX ? CELL / 2 : a.d / 2);
      var hd = (alongX ? a.d / 2 : CELL / 2);
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: 1,
        alongX: alongX,
        rect: {
          x0: c.x - hw,
          x1: c.x + hw,
          z0: c.z - hd,
          z1: c.z + hd,
        },
        h: a.h,
      });
    }

// a cell of drums or a crate stack, backed onto its wall when it has one: two or three of the one
// glb at hashed spots and turns, a crate stack two wide with a hashed third on top
  static function stack(p:LabInteriorPlan, m:Facility, col:Int, row:Int, t:Int):Void
    {
      var h = FacilityModel.mix((col * 73856093) ^ (row * 19349663));
      var d = -1;
      for (k in 0...4)
        if (d < 0 &&
            FacilityModel.isWall(m, col + DC[k], row + DR[k]))
          d = k;
      var c = CityConfig.cellToWorld(col, row);
      // the wall's frame: `bx`/`bz` toward the masonry, `sx`/`sz` along it
      var bx = (d < 0 ? 0 : DC[d]), bz = (d < 0 ? 1 : DR[d]);
      var sx = -bz, sz = bx;
      var back = (d < 0 ? 0.0 : CELL / 2 + faceOff(m, col, row, d));
      var drums = (t == Const.TILE_LAB_DRUMS);
      var A = art();
      var a = (drums ? A.drum : A.crate);
      var spots = (drums ?
        [ [-0.72, 0.7], [0.72, 0.7], [0.0 + ((h >>> 3) % 5 - 2) * 0.15, 1.9] ] :
        [ [-1.03, 1.02], [1.03, 1.02] ]);
      var n = (drums ? 2 + (h >>> 7) % 2 : 2);
      for (i in 0...n)
        {
          var s = spots[i];
          var off = back - s[1];
          var yaw = (d < 0 ? 0.0 : away(d)) + (((h >>> (i * 5)) % 9) - 4) * 0.04;
          put(p, a, c.x + bx * off + sx * s[0], c.z + bz * off + sz * s[0], yaw);
        }
      // the crate on top, over one of the two below
      if (!drums &&
          (h >>> 11) % 3 != 0)
        {
          var s = ((h >>> 13) % 2 == 0 ? -0.95 : 0.95);
          var off = back - 1.05;
          put(p, a, c.x + bx * off + sx * s, c.z + bz * off + sz * s,
            (d < 0 ? 0.0 : away(d)) + (((h >>> 17) % 9) - 4) * 0.06, A.crate.h);
        }
      var hw = (d < 2 ? CELL / 2 : 1.1);
      var hd = (d < 2 ? 1.1 : CELL / 2);
      var cx = c.x + bx * (back - 1.1), cz = c.z + bz * (back - 1.1);
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: 1,
        alongX: (d < 2),
        rect: {
          x0: cx - hw,
          x1: cx + hw,
          z0: cz - hd,
          z1: cz + hd,
        },
        h: (drums ? A.drum.h : A.crate.h * 2),
      });
    }

// a machine on its footprint: a wall kind backed onto the wall its footprint touches, a floor kind
// on the footprint's centre at a hashed one of the turns its footprint allows
  static function machine(p:LabInteriorPlan, m:Facility, cells:Array<Array<Int>>, col:Int, row:Int,
      k:gen.lab._LabMachine, a:LabPieceArt):Void
    {
      var alongX = LabKinds.alongX(cells, col, row, k);
      var fw = (alongX ? k.len : k.depth);
      var fh = (alongX ? k.depth : k.len);
      var c = CityConfig.cellToWorld(col, row);
      var cx = c.x + (fw - 1) * CELL / 2;
      var cz = c.z + (fh - 1) * CELL / 2;
      // the wall the footprint touches: a hand whose whole edge is masonry
      var d = -1;
      if (k.wall)
        for (h in (alongX ? [0, 1, 2, 3] : [2, 3, 0, 1]))
          if (d < 0 &&
              (k.len == k.depth || (h < 2) == alongX) &&
              edgeWalled(m, col, row, fw, fh, h))
            d = h;
      var yaw:Float;
      var x = cx, z = cz;
      if (d >= 0)
        {
          // the footprint's centre to its wall-side edge, then on to the masonry's face
          var half = (d < 2 ? fh : fw) * CELL / 2;
          var back = half + faceOff(m, col, row, d) - a.d / 2;
          x += DC[d] * back;
          z += DR[d] * back;
          yaw = away(d);
          // the container's door end is its +x, and on a side wall away(d) can aim it up the wall
          // away from the camera; its two long sides are alike, so turn it end for end instead
          if (k.name == 'container' &&
              Math.sin(yaw) > 0.5)
            yaw += Math.PI;
        }
      else
        {
          var hh = FacilityModel.mix((col * 40503151) ^ (row * 57885161));
          yaw = (alongX ? 0.0 : Math.PI / 2) + ((hh >>> 4) % 2) * Math.PI;
        }
      dress(p, a, x, z, yaw, 0.0, (FacilityModel.mix(col * 7919 + row) % 628) / 100);
      // the footprint's own shadow; a wall box hung off the floor throws none on it
      if (a.y != null)
        return;
      // facing along z, its long side runs along x, and the other way round
      var long = (a.w != null ? a.w : (alongX ? fw : fh) * CELL - 0.4);
      var facesZ = (d >= 0 ? d < 2 : alongX);
      var w = (facesZ ? long : a.d);
      var dd = (facesZ ? a.d : long);
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: 1,
        alongX: alongX,
        rect: {
          x0: x - w / 2,
          x1: x + w / 2,
          z0: z - dd / 2,
          z1: z + dd / 2,
        },
        h: a.h,
      });
    }

// is the whole of a footprint's edge on hand `d` masonry?
  static function edgeWalled(m:Facility, col:Int, row:Int, fw:Int, fh:Int, d:Int):Bool
    {
      var n = (d < 2 ? fw : fh);
      for (i in 0...n)
        {
          var x = (d < 2 ? col + i : (d == 2 ? col - 1 : col + fw));
          var y = (d < 2 ? (d == 0 ? row - 1 : row + fh) : row + i);
          if (!FacilityModel.isWall(m, x, y))
            return false;
        }
      return true;
    }
}
