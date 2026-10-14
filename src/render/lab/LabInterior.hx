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
};

// what a build plans before the batches exist: every placement, by path
typedef LabInteriorPlan = {
  places:Map<String, Array<Models.PropPlace>>,
  heights:Map<String, Float>,
  lids:Array<LabDecals.LabLid>,     // the bench tops render.lab.LabDecals lays clutter on
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
          // the generated ones (TRELLIS, art/models.json lab/<name>): height, depth, width, and the
          // turn that brings the front round where it came back on a flank
          'reactor' => gen('reactor', 4.5, 6.64, 6.35),
          'screenwall' => gen('screenwall', 5.0, 2.23, 4.16, -HALF_PI),
          'hatchbox' => gen('hatchbox', 4.4, 3.08, 3.68, -HALF_PI),
          'dialtank' => gen('dialtank', 3.6, 3.36, 3.35),
          'autopsy' => gen('autopsy', 3.4, 2.82, 2.48),
          'tube' => gen('tube', 4.6, 2.08, 2.76),
          'tubeempty' => gen('tubeempty', 4.6, 2.46, 2.5),
          'trolley' => gen('trolley', 2.4, 1.38, 2.4),
          'instconsole' => gen('instconsole', 3.2, 1.48, 4.86),
          'restraint' => gen('restraint', 3.4, 2.27, 2.32),
          'switchrack' => gen('switchrack', 4.6, 1.79, 2.98, -HALF_PI),
          'scanner' => gen('scanner', 4.0, 1.99, 2.39),
          'terminal' => gen('terminal', 3.4, 2.3, 3.26),
          'holo' => gen('holo', 3.6, 2.25, 4.02),
          'tubeconsole' => gen('tubeconsole', 3.0, 1.12, 2.4),
          'joystick' => gen('joystick', 2.6, 2.68, 4.94, -HALF_PI),
          'monitorstack' => gen('monitorstack', 4.4, 1.44, 2.32, -HALF_PI),
          'pipecapsule' => gen('pipecapsule', 2.8, 1.54, 5.47),
          'clamp' => gen('clamp', 3.6, 6.87, 6.87),
          'tentacle' => gen('tentacle', 4.4, 3.5, 3.95),
          'bioscreen' => gen('bioscreen', 4.0, 2.89, 4.29, -HALF_PI),
          'cryopod' => gen('cryopod', 2.65, 3.63, 3.4),
          'probe' => gen('probe', 2.75, 3.41, 3.63),
          'stasis' => gen('stasis', 5.0, 1.8, 2.63, -HALF_PI),
          'capsule' => gen('capsule', 2.3, 3.58, 7.3),
          'robochair' => gen('robochair', 3.4, 2.79, 1.8),
          'winconsole' => gen('winconsole', 3.0, 2.67, 4.18),
          'upw' => gen('upw', 4.6, 1.95, 3.97),
          'booth' => gen('booth', 5.2, 2.93, 3.62),
          'incinerator' => gen('incinerator', 4.0, 3.26, 4.66),
          'analysis' => gen('analysis', 3.0, 4.21, 4.23),
          'bioprinter' => gen('bioprinter', 4.8, 2.16, 3.28),
          'specimencase' => gen('specimencase', 4.0, 1.96, 5.23),
          'ambertanks' => gen('ambertanks', 4.8, 2.81, 4.74),
          'processor' => gen('processor', 4.8, 3.17, 5.26),
          'incubator' => gen('incubator', 4.4, 2.49, 4.19),
          'brainscan' => gen('brainscan', 3.8, 1.96, 3.82, Math.PI),
          'cryobank' => gen('cryobank', 5.2, 3.02, 5.16),
          'centrifuge' => gen('centrifuge', 4.4, 7.25, 7.26),
          'embryonic' => gen('embryonic', 5.4, 1.92, 4.86, -HALF_PI),
          'gestation' => gen('gestation', 3.2, 5.62, 5.64),
          'rack8' => gen('rack8', 4.4, 1.83, 5.93),
          'rack6' => gen('rack6', 4.4, 1.78, 4.57),
          'canisters' => gen('canisters', 4.6, 2.32, 4.61),
          'generator' => gen('generator', 4.8, 2.6, 5.27),
          'press' => gen('press', 4.3, 2.28, 3.66),
          'robotarm' => gen('robotarm', 4.8, 2.84, 3.07),
          'kiosk' => gen('kiosk', 4.0, 0.98, 1.42, -HALF_PI),
          'cagecase' => gen('cagecase', 2.4, 1.49, 2.61),
          'sheetcage' => gen('sheetcage', 3.2, 3.4, 3.82),
          'gurney' => gen('gurney', 2.6, 2.28, 4.05, -HALF_PI),
          'tarpcrate' => gen('tarpcrate', 3.0, 2.29, 3.13),
          'gurneys' => gen('gurneys', 3.0, 1.72, 3.22),
          'palletcrate' => gen('palletcrate', 1.85, 3.61, 3.52),
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
          gen('plant6', 2.6, 1.97, 2.14),
        ],
        // what hangs on a hazmat rack's rail, and the one left in a heap under it
        suits: [
          gen('suit', LabStyle.SUIT_H, 0.63, 1.25),
          gen('suitfloor', 1.0, 1.86, 2.24),
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
      return [for (path in p.places.keys()) batch(scene, path, p.places.get(path), p.heights.get(path))];
    }

// one of every piece at the origin, for render.lab.LabWarm. Returns the paths to wait on
  public static function warm(scene:Scene):Array<String>
    {
      var A = art();
      var all = [for (a in A.furniture) a].concat([A.shelfRow, A.drum, A.crate])
        .concat([for (a in A.machines) a]).concat(A.work).concat(A.plants).concat(A.suits);
      for (a in all)
        batch(scene, a.path, [{
          x: 0.0,
          z: 0.0,
          yaw: 0.0,
        }], a.h);
      return [for (a in all) a.path];
    }

// one batch
  static function batch(scene:Scene, path:String, places:Array<Models.PropPlace>, h:Float):Models.InstancedProp
    {
      var prop = Models.instanced(scene, path, places, h, SOLID);
      Models.get(path, function(_)
        {
          VisionMask.patchMesh(prop.mesh);
          prop.mesh.castShadow = false;
        });
      return prop;
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
      p.lids.push({
        x: x + Math.sin(yaw) * off,
        z: z + Math.cos(yaw) * off,
        yaw: yaw,
        w: (heavy ? 3.6 : 3.8),
        d: (heavy ? 2.1 : 2.2),
        y: (heavy ? 2.0 : 1.96),
        workshop: (m.surf[row][col] == Surf.LAB_WORKSHOP),
        keep: (heavy ? {
          x: 1.45,
          z: 0.95,
          r: 0.45,
        } : null),
      });
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

// a hazmat rack's suits: up to SUIT_N on its rail at hashed gaps, and now and then one dropped in a
// heap in front of it. The rail is SUIT_RAIL out from the rack's centre and the suit's hook is its top
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
          put(p, S[0], x + ox * out + sx * s, z + oz * out + sz * s, yaw, y);
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
        }
      else
        {
          var hh = FacilityModel.mix((col * 40503151) ^ (row * 57885161));
          yaw = (alongX ? 0.0 : Math.PI / 2) + ((hh >>> 4) % 2) * Math.PI;
        }
      put(p, a, x, z, yaw);
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
