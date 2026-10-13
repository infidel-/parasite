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
import render.facility.FacilityStyle;
import render.world.VisionMask;

// one batch's art: the glb, the height it is drawn at (its own measured one, so it draws at scale 1),
// its depth across the wall it backs onto, and how far off the floor its lowest point hangs
typedef LabPieceArt = {
  path:String,
  h:Float,
  d:Float,
  ?y:Float,
};

// what a build plans before the batches exist: every placement, by path
typedef LabInteriorPlan = {
  places:Map<String, Array<Models.PropPlace>>,
  heights:Map<String, Float>,
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
  } = null;

// the art tables: the furniture by Const row-23 tile (PLANT and BIN are generated props, Phase 5's
// batch), the store's free-standing rows, the drums and the crates, and the machines this pass draws
// by gen.lab.LabKinds name — the generated ones join that table
  static function art():{
    furniture:Map<Int, LabPieceArt>,
    machines:Map<String, LabPieceArt>,
    shelfRow:LabPieceArt,
    drum:LabPieceArt,
    crate:LabPieceArt,
    work:Array<LabPieceArt>,
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

// every placement off the area's grid, and every piece's contact shadow
  public static function plan(m:Facility, tile:(Int, Int)->Int):LabInteriorPlan
    {
      var p:LabInteriorPlan = {
        places: new Map(),
        heights: new Map(),
      };
      var A = art();
      // the grid as gen.lab.LabKinds.alongX reads it, column-major
      var cells = [for (x in 0...m.w) [for (y in 0...m.h) tile(x, y)]];
      for (r in 0...m.h)
        for (col in 0...m.w)
          {
            var t = cells[col][r];
            var a = A.furniture.get(t);
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
        .concat([for (a in A.machines) a]).concat(A.work);
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
        yaw: yaw,
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
      var long = (alongX ? fw : fh) * CELL - 0.4;
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
