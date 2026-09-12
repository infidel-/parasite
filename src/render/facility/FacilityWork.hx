package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.ContactMask;
import render.world.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the workstation standing on a researcher's desk: a monitor on a stand, a tower beside it, a
// keyboard in front, two leads between them and a pair of status lights on the tower.
//
// IT WAS A GLB AND THAT WAS THE WRONG CALL. facility/computer.glb spent 1,200 triangles on three
// axis-aligned slabs and was reported, correctly, as blocky — which is CLAUDE.md's own test: a
// silhouette earns a mesh generator and a SURFACE does not, and a monitor is a rectangle with a
// picture on it. Emitted, the whole set is 22 quads, its proportions are FacilityStyle's numbers
// rather than a bake's approximation of them, and every face samples the game's own art at full
// texel density. The one piece of the set that IS a silhouette — the chair, with its shaped back and
// its five-star base — stayed a glb, which is the same test answered the other way.
//
// ONE TEXTURE FOR THE WHOLE SET and not one per face. Four authored cells on a 2x2 sheet, addressed
// by sub-rect: the facility/sink idiom, where two images would have been two materials, two meshes
// and two draw calls to draw one fixture. So a compound's every workstation is ONE draw call, and
// the leads and the lights cost none at all — they are pushed into buffers two other families
// already merge (render.facility.FacilityCable's ribbon and FacilityDeco's additive LED mesh)
class FacilityWork
{
  static inline var CELL = CityConfig.CELL;

  // the four cell-edge directions, in FacilityGeom.face's order: 0 = -z, 1 = +z, 2 = -x, 3 = +x
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the plane a ribbon lying on a desk is bowed in
  static var UP = [0.0, 1.0, 0.0];

// where the workstation on this office desk cell stands, or null for a cell that carries none.
//
// A PURE FUNCTION OF THE SAVED GRID, and deliberately so: three passes ask it and none of them may
// depend on having run first — FacilityTables for the contact pool under the screen, FacilityClutter
// for the footprint its paper has to keep clear of, and `build` below for the geometry itself. The
// same discipline FacilityPoint.places and FacilityDeco.rectOf already keep
  public static function at(m:Facility, col:Int, row:Int):WorkSpot
    {
      if (!m.table[row][col] ||
          m.surf[row][col] != Surf.OFFICE ||
          m.tableSink[row][col])
        return null;
      var h = FacilityModel.mix((col * 374761393) ^ (row * 40503));
      if (h % FacilityStyle.WORK_EVERY != 0)
        return null;
      var dir = FacilityTables.wallHand(m, col, row);
      if (dir < 0)
        return null;
      var c = CityConfig.cellToWorld(col, row);
      // back of the desk = the wall hand, measured from the CELL's own edge on that side
      var back = CELL / 2 - FacilityStyle.WORK_BACK;
      var x = c.x + DC[dir] * back;
      var z = c.z + DR[dir] * back;
      // and which hand the TOWER stands on, off the same hash `set` rolls it from — asked for here
      // rather than re-derived, because FacilityClutter puts the desk's paperwork on the OTHER end and
      // a second copy of this roll is a second place for it to drift
      var g = FacilityModel.mix((col * 971658137) ^ (row * 1266489917));
      var ts = (g % 2 == 0 ? 1.0 : -1.0);
      var tx = (dir < 2 ? 1.0 : 0.0), tz = (dir < 2 ? 0.0 : 1.0);
      return {
        x: x,
        z: z,
        dir: dir,
        tx: x + tx * ts * FacilityStyle.WORK_TOWER_OFF,
        tz: z + tz * ts * FacilityStyle.WORK_TOWER_OFF,
        side: ts,
      };
    }

// every workstation in the compound, merged. `leds` and `cab` belong to other families and are
// borrowed: the lights go in render.facility.FacilityDeco's additive mesh and the leads in
// FacilityCable's ribbon, so this whole pass costs exactly ONE draw call however many desks it
// dresses. Returns how many it stood
  public static function build(scene:Scene, m:Facility, leds:MeshBuf, cab:MeshBuf):Int
    {
      var b = MeshBufTools.make();
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var p = at(m, col, row);
            if (p == null)
              continue;
            set(b, leds, cab, m, col, row, p);
            n++;
          }
      FacilityGeom.add(scene, b, FacilityStyle.WORK_TEX, true, false);
      return n;
    }

// one set. everything here is axis-aligned, because a desk hugs a wall and a wall runs on an axis —
// so the whole thing is emitted in world coordinates with no transform and no per-instance matrix,
// which is what lets the compound's workstations merge into one mesh
  static function set(b:MeshBuf, leds:MeshBuf, cab:MeshBuf, m:Facility, col:Int, row:Int,
      p:WorkSpot):Void
    {
      var cx = p.x, cz = p.z, dir = p.dir;
      // `out` is the way the screen looks, i.e. away from the wall and at whoever sits there — the
      // bug this pass was opened on was a screen facing the masonry
      var out = dir ^ 1;
      var nx = DC[out] * 1.0, nz = DR[out] * 1.0;
      // and the run axis, which is the one the wall hand is NOT on. the tower goes along it
      var tx = (dir < 2 ? 1.0 : 0.0), tz = (dir < 2 ? 0.0 : 1.0);
      var y = FacilityStyle.BENCH_H;
      var g = FacilityModel.mix((col * 971658137) ^ (row * 1266489917));
      // which hand the tower stands on — `at` rolled it off this same hash and hands it over, so the
      // geometry and everything that dodges it cannot disagree
      var ts = p.side;

      // the monitor's foot and the post under the screen, both on the screen's own centre line
      box(b, cx, y, cz, FacilityStyle.WORK_FOOT_W, FacilityStyle.WORK_FOOT_H,
        FacilityStyle.WORK_FOOT_D, nx, nz, tx, tz, FacilityStyle.WORK_C_CASE);
      box(b, cx, y + FacilityStyle.WORK_FOOT_H, cz, FacilityStyle.WORK_STAND_W,
        FacilityStyle.WORK_STAND_H, FacilityStyle.WORK_STAND_W, nx, nz, tx, tz,
        FacilityStyle.WORK_C_CASE);
      // the screen itself, its FRONT face carrying the one cell of the sheet that is a picture
      var sy = y + FacilityStyle.WORK_FOOT_H + FacilityStyle.WORK_STAND_H;
      box(b, cx, sy, cz, FacilityStyle.WORK_SCREEN_W, FacilityStyle.WORK_SCREEN_H,
        FacilityStyle.WORK_SCREEN_D, nx, nz, tx, tz, FacilityStyle.WORK_C_SCREEN);

      // the tower, stood on end beside it — its centre comes off `at` with the hand it stands on
      var wx = p.tx, wz = p.tz;
      box(b, wx, y, wz, FacilityStyle.WORK_TOWER_W, FacilityStyle.WORK_TOWER_H,
        FacilityStyle.WORK_TOWER_D, nx, nz, tx, tz, FacilityStyle.WORK_C_TOWER);
      lights(leds, wx, y, wz, nx, nz, tx, tz, g);

      // and the keyboard lying in front of the screen
      var kx = cx + nx * FacilityStyle.WORK_KEY_FWD;
      var kz = cz + nz * FacilityStyle.WORK_KEY_FWD;
      box(b, kx, y, kz, FacilityStyle.WORK_KEY_W, FacilityStyle.WORK_KEY_H,
        FacilityStyle.WORK_KEY_D, nx, nz, tx, tz, FacilityStyle.WORK_C_KEY);

      // the two leads. both leave the keyboard's BACK edge and both lie on the worktop, so the bow
      // rides the horizontal perpendicular of their own chord — see FacilityCable.strip, whose
      // `side` hint is what decides which way a run curves when the seed would otherwise
      var ky = y + FacilityStyle.WORK_CABLE_Y;
      var ka = [kx - nx * FacilityStyle.WORK_KEY_D / 2, ky, kz - nz * FacilityStyle.WORK_KEY_D / 2];
      FacilityCable.strip(cab, {
        a: ka,
        c: [cx, ky, cz],
        n: UP,
        side: null,
        bow: FacilityStyle.WORK_CABLE_BOW,
        wave: FacilityStyle.WORK_CABLE_WAVE,
        seed: g,
      });
      FacilityCable.strip(cab, {
        a: ka,
        c: [wx, ky, wz],
        n: UP,
        side: null,
        bow: FacilityStyle.WORK_CABLE_BOW,
        wave: FacilityStyle.WORK_CABLE_WAVE,
        seed: g ^ 40503,
      });
    }

// one axis-aligned box standing on `y`, 5 faces and no underside — it sits on a worktop and the
// bottom is never seen. `front` names the sheet cell its OUT face takes; every other face takes the
// case, which is what makes a monitor a screen on a plastic carcass rather than five screens
  static function box(b:MeshBuf, cx:Float, y:Float, cz:Float, w:Float, h:Float, d:Float,
      nx:Float, nz:Float, tx:Float, tz:Float, front:Int):Void
    {
      // half extents on the two world axes, resolved off which axis is depth here
      var hx = Math.abs(tx) * w / 2 + Math.abs(nx) * d / 2;
      var hz = Math.abs(tz) * w / 2 + Math.abs(nz) * d / 2;
      var x0 = cx - hx, x1 = cx + hx;
      var z0 = cz - hz, z1 = cz + hz;
      var y1 = y + h;
      // the out face carries the authored cell, the three others the carcass
      for (dir in 0...4)
        {
          var cell = (DC[dir] == nx && DR[dir] == nz ? front : FacilityStyle.WORK_C_CASE);
          face(b, x0, x1, z0, z1, dir, y, y1, cell);
        }
      lid(b, x0, x1, z0, z1, y1, FacilityStyle.WORK_C_CASE);
    }

// one upright face of a box, mapped 0..1 over a single cell of the sheet. FacilityGeom.face cannot
// serve: it tiles world-aligned, and every cell here is an authored picture that has to land whole
  static function face(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int,
      y0:Float, y1:Float, cell:Int):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      var u = uv(cell);
      MeshBufTools.quad(b,
        [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [u[0], u[2], u[1], u[2], u[1], u[3], u[0], u[3]]);
    }

// and its lid, wound to FacilityGeom.cap's winding so it faces up
  static function lid(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float, cell:Int):Void
    {
      var u = uv(cell);
      MeshBufTools.quad(b,
        [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
        [u[0], u[2], u[1], u[2], u[1], u[3], u[0], u[3]]);
    }

// one cell of the 2x2 sheet as u0,u1,v0,v1. the index reads left to right and TOP ROW FIRST, and
// three flips y, so row 0 of the image is the HIGH v — the placards' own convention
  static inline function uv(cell:Int):Array<Float>
    {
      var t = FacilityStyle.WORK_COLS;
      var cc = cell % t;
      var cr = Std.int(cell / t);
      return [cc / t, (cc + 1) / t, 1 - (cr + 1) / t, 1 - cr / t];
    }

// the tower's status lights: a column of specks on its front face, each with its own blink phase.
//
// pushed into render.facility.FacilityDeco's OWN additive buffer, so they join the server racks'
// mesh and the machines' — one draw call for every blinking thing in the compound, and no per-frame
// work at all beyond the clock that family already ticks. `b` in 0..1 picks the RACK branch of the
// shader patch there, which is a square wave at DECO_LED_RATE: one blink per ~3 turn-durations,
// which is a machine at rest rather than a sequencer running
  static function lights(b:MeshBuf, cx:Float, y:Float, cz:Float, nx:Float, nz:Float,
      tx:Float, tz:Float, g:Int):Void
    {
      var d = FacilityStyle.WORK_TOWER_D / 2 + FacilityStyle.WORK_LED_EPS;
      var s = FacilityStyle.WORK_LED_SIZE / 2;
      var fx = cx + nx * d, fz = cz + nz * d;
      for (i in 0...FacilityStyle.WORK_LED_N)
        {
          var hh = FacilityModel.mix(g ^ (i * 40503));
          // up the face, in its top third where a case carries its ports
          var yc = y + FacilityStyle.WORK_TOWER_H * (0.72 + 0.1 * i);
          var ac = 0.0 - FacilityStyle.WORK_TOWER_W * 0.25;
          var px = fx + tx * ac, pz = fz + tz * ac;
          var lvl = 0.7 + ((hh % 1000) / 1000) * 0.3;
          var ph = ((hh >>> 11) % 1000) / 1000;
          var hue = ((hh >>> 21) % 3 == 0 ? 0.0 : 1.0);
          MeshBufTools.quadRGB(b,
            [px - tx * s, yc - s, pz - tz * s],
            [px + tx * s, yc - s, pz + tz * s],
            [px + tx * s, yc + s, pz + tz * s],
            [px - tx * s, yc + s, pz - tz * s],
            [0, 0, 1, 0, 1, 1, 0, 1], lvl, ph, hue);
        }
    }

// the chairs, one instanced batch for the compound. one per workstation and none anywhere else: a
// chair at a desk nobody works at is furniture, a chair at a workstation is somebody's seat
  public static function chairs(scene:Scene, m:Facility):Models.InstancedProp
    {
      var places:Array<Models.PropPlace> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var p = at(m, col, row);
            if (p == null)
              continue;
            var out = p.dir ^ 1;
            var c = CityConfig.cellToWorld(col, row);
            var x = c.x + DC[out] * (CELL / 2 + FacilityStyle.CHAIR_OUT);
            var z = c.z + DR[out] * (CELL / 2 + FacilityStyle.CHAIR_OUT);
            // the cell it would stand in has to be clear floor — a desk run facing another run, or
            // one against the far side of a narrow room, has nowhere to put a seat
            var nc = col + DC[out], nr = row + DR[out];
            if (!FacilityModel.isIndoor(m, nc, nr) ||
                FacilityModel.isTable(m, nc, nr) ||
                m.deco[nr][nc] > 0)
              continue;
            var g = FacilityModel.mix((col * 1266489917) ^ (row * 971658137));
            places.push({
              x: x,
              z: z,
              // facing the desk, with a little play either side so a room of them is not a showroom
              yaw: Math.atan2(DC[p.dir], DR[p.dir]) +
                (((g % 1000) / 1000) - 0.5) * 2 * FacilityStyle.CHAIR_YAW_JIT,
              y: 0.0,
            });
            ContactMask.prop(x - CELL / 4, x + CELL / 4, z - CELL / 4, z + CELL / 4);
          }
      var prop = Models.instanced(scene, RenderConfig.MODELS.facilityChair, places,
        FacilityStyle.CHAIR_H, SOLID);
      // NOT CASTING, the indoor drums' own finding: an instanced batch is drawn into the moon's
      // shadow map as many times as into the frame, and these stand under a faded roof
      if (places.length > 0)
        Models.get(RenderConfig.MODELS.facilityChair, function(_)
          {
            VisionMask.patchMesh(prop.mesh);
            prop.mesh.castShadow = false;
          });
      return prop;
    }
}
