package render.lab;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// one furniture top the lab's flat clutter may lie on, recorded by render.lab.LabInterior as it stands
// the piece: the lid's centre and turn, its extents in its own frame (w along local x, d along local
// z), its height, which sheet it deals from, the most it may carry (it deals that or up to two fewer,
// never none), and the circles in its frame nothing may land in (the workbench's vice, the standing
// kit render.lab.LabInterior puts on it)
typedef LabLid = {
  x:Float,
  z:Float,
  yaw:Float,
  w:Float,
  d:Float,
  y:Float,
  workshop:Bool,
  count:Int,
  keeps:Array<{ x:Float, z:Float, r:Float }>,
};

// one cold machine render.lab.LabDecals frosts round: its footprint on the floor, and when it backs
// onto masonry, that wall's face (the point mid-way along the piece's back, the way the room is from
// it as a yaw, the piece's width along it and its height)
typedef LabFrost = {
  x0:Float,
  x1:Float,
  z0:Float,
  z1:Float,
  wall:Bool,
  wx:Float,
  wz:Float,
  yaw:Float,
  ww:Float,
  h:Float,
};

// the FLAT things of the underground lab, every one a cut-out off a pack sheet laid as a quad: the
// grime on its floors (lab/floor-decals, a 4x4), its paint and stencils (lab/floor-marks, a 4x4) and
// what the staff left lying on the benches (lab/bench-research and lab/bench-workshop, 6x6 each).
//
// A ROOM DEALS ITS OWN CELLS. A floor cell's tile names its role (gen.lab's floor rows run corridor,
// entrance, vat, workshop, storage, research), and each role rolls off its own short list of each
// sheet: slime and drag smears on the clone floor, oil and scorch in the workshop, stencils in the
// corridor. A cell under furniture, a machine, a door, the lift or a vat pad takes nothing.
//
// RENDER-ONLY, like render.military.MilitaryClutter: every pick, spot, size and turn is rolled off
// FacilityModel.mix on the cell, nothing is saved and nothing blocks. ONE MERGED MESH PER SHEET, so
// the whole lab pays four calls for it
class LabDecals
{
  static inline var CELL = CityConfig.CELL;

  // per floor role (corridor, entrance, vat, workshop, storage, research), the cells of each floor
  // sheet it deals from. floor-decals: 0 green slime, 1 brown sludge, 2 purple ooze, 3 black oil,
  // 4 grey water, 5 blue spill, 6-8 claw marks, 9 crack, 10 glass, 11 debris, 12 drain, 13 hatch,
  // 14 footprints, 15 drag smear. floor-marks: 0-2 stencils, 3 biohazard, 4 lit grate, 5 chevrons,
  // 6 arrow, 7 hazard arc, 8 slurry (the drained vat's, never dealt), 9 box junction, 10 no entry,
  // 11 taped square, 12 oil stain, 13 scorch, 14 stand here, 15 tape
  static var GRIME = [
    [ 4, 9, 6, 14, 12, 3 ],
    [ 15, 7, 4, 9, 11 ],
    [ 0, 2, 14, 15, 6, 12, 10 ],
    [ 3, 1, 9, 11, 13 ],
    [ 4, 9, 11, 12 ],
    [ 5, 10, 2, 8 ],
  ];
  static var MARKS = [
    [ 0, 1, 2, 5, 6, 15 ],
    [ 14, 10, 5 ],
    [ 3, 4, 7, 12 ],
    [ 9, 11, 12, 13 ],
    [ 9, 11, 15, 0 ],
    [ 13, 2, 11 ],
  ];

// every floor decal and every bench top's clutter, one mesh per sheet. returns the counts, for __lab()
  public static function build(scene:Scene, m:Facility, tile:(Int, Int)->Int,
      lids:Array<LabLid>, frosts:Array<LabFrost>):{ grime:Int, marks:Int, tops:Int, frost:Int }
    {
      var grime = MeshBufTools.make();
      var marks = MeshBufTools.make();
      var ng = 0, nm = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var role = tile(col, row) - Const.TILE_LAB_CORRIDOR;
            if (role < 0 ||
                role > Const.TILE_LAB_FLOOR_RESEARCH - Const.TILE_LAB_CORRIDOR)
              continue;
            var h = FacilityModel.mix((col * 73856093) ^ (row * 19349663) ^ 0x1ab);
            var roll = (h >>> 4) % 1000;
            var c = CityConfig.cellToWorld(col, row);
            var x = c.x + (((h >>> 14) % 17) - 8) * 0.08;
            var z = c.z + (((h >>> 19) % 17) - 8) * 0.08;
            var yaw = ((h >>> 24) % 64) * Math.PI / 32;
            if (roll < LabStyle.GRIME_RATE)
              {
                var l = GRIME[role];
                var sz = LabStyle.GRIME_SZ + ((h >>> 9) % 11) * LabStyle.GRIME_SZ_VAR / 10;
                emit(grime, x, z, sz, yaw, l[(h >>> 11) % l.length], LabStyle.DECAL_Y, 4);
                ng++;
              }
            else if (roll < LabStyle.GRIME_RATE + LabStyle.MARK_RATE)
              {
                // a mark lies square to the room, the way it was painted
                var l = MARKS[role];
                var sz = LabStyle.MARK_SZ + ((h >>> 9) % 11) * LabStyle.MARK_SZ_VAR / 10;
                emit(marks, c.x, c.z, sz, ((h >>> 24) % 4) * Math.PI / 2, l[(h >>> 11) % l.length],
                  LabStyle.DECAL_Y + 0.004, 4);
                nm++;
              }
          }
      var tops = [ MeshBufTools.make(), MeshBufTools.make() ];
      var nt = 0;
      for (l in lids)
        nt += lid(tops[l.workshop ? 1 : 0], l);
      add(scene, grime, LabStyle.DECAL_GRIME_TEX);
      add(scene, marks, LabStyle.DECAL_MARKS_TEX);
      add(scene, tops[0], LabStyle.DECAL_RESEARCH_TEX);
      add(scene, tops[1], LabStyle.DECAL_WORKSHOP_TEX);
      var ice = MeshBufTools.make();
      var nf = 0;
      for (f in frosts)
        nf += frost(ice, f);
      add(scene, ice, LabStyle.FROST_TEX, LabStyle.FROST_GLOW);
      return {
        grime: ng,
        marks: nm,
        tops: nt,
        frost: nf,
      };
    }

// one quad off each sheet at the origin, for render.lab.LabWarm
  public static function warm(scene:Scene):Void
    {
      for (tex in [ LabStyle.DECAL_GRIME_TEX, LabStyle.DECAL_MARKS_TEX, LabStyle.DECAL_RESEARCH_TEX,
          LabStyle.DECAL_WORKSHOP_TEX, LabStyle.FROST_TEX ])
        {
          var b = MeshBufTools.make();
          emit(b, 0.0, 0.0, 1.0, 0.0, 0, LabStyle.DECAL_Y, 4);
          add(scene, b, tex, (tex == LabStyle.FROST_TEX ? LabStyle.FROST_GLOW : 0));
        }
    }

// one lid's worth: 2-4 cut-outs rejection-sampled in the lid's own frame clear of each other and of
// its keep-outs, then turned into the world. An item that finds no room in DECAL_TRIES is dropped
  static function lid(b:MeshBuf, l:LabLid):Int
    {
      // the height in the hash too: a workbench's lower shelf stands right under its top
      var h = FacilityModel.mix(Std.int(l.x * 131) ^ (Std.int(l.z * 977) << 8) ^
        (Std.int(l.y * 37) << 20));
      var want = Std.int(Math.max(1, l.count - (h >>> 3) % 3));
      var cs = Math.cos(l.yaw), sn = Math.sin(l.yaw);
      var placed = l.keeps.copy();
      var n = 0, k = 0;
      while (n < want &&
          k < want * LabStyle.DECAL_TRIES)
        {
          var r = FacilityModel.mix(h + k * 7919);
          k++;
          var sz = LabStyle.TOP_SZ + (r % 11) * LabStyle.TOP_SZ_VAR / 10;
          var hs = sz * 0.4;
          var lx = ((r >>> 4) % 1001 / 1000 - 0.5) * (l.w - 2 * hs);
          var lz = ((r >>> 14) % 1001 / 1000 - 0.5) * (l.d - 2 * hs);
          var clear = true;
          for (p in placed)
            if ((p.x - lx) * (p.x - lx) + (p.z - lz) * (p.z - lz) < (p.r + hs) * (p.r + hs))
              clear = false;
          if (!clear)
            continue;
          placed.push({
            x: lx,
            z: lz,
            r: hs,
          });
          // three's turn of the lid's frame: local x to (cos, -sin), local z to (sin, cos)
          emit(b, l.x + lx * cs + lz * sn, l.z - lx * sn + lz * cs, sz,
            l.yaw + ((r >>> 24) % 64) * Math.PI / 32, (r >>> 9) % 36, l.y + LabStyle.TOP_LIFT, 6);
          n++;
        }
      return n;
    }

// the frost round one cold machine off lab/frost (cells 0-7 drawn top-down for the floor, 8-15 flat-on
// for a wall): patches every FROST_STEP or so round its footprint's edge, none past the wall it backs
// onto, and on that wall a crust beside it on each hand standing on the floor and an icicled fringe
// over its top. Returns the quads laid
  static function frost(b:MeshBuf, f:LabFrost):Int
    {
      var h = FacilityModel.mix(Std.int(f.x0 * 131) ^ (Std.int(f.z0 * 977) << 8) ^ 0xf05);
      var n = 0;
      // the room-ward normal of the wall, so a floor patch behind the piece is skipped
      var nx = Math.sin(f.yaw), nz = Math.cos(f.yaw);
      var w = f.x1 - f.x0, d = f.z1 - f.z0;
      var per = 2 * (w + d);
      var k = Std.int(Math.max(4, per / LabStyle.FROST_STEP));
      for (i in 0...k)
        {
          var r = FacilityModel.mix(h + i * 7919);
          // a point round the perimeter, a little way out from it
          var t = (i + ((r >>> 4) % 100) / 200) / k * per;
          var px:Float, pz:Float;
          if (t < w)
            {
              px = f.x0 + t;
              pz = f.z0 - LabStyle.FROST_OUT;
            }
          else if (t < w + d)
            {
              px = f.x1 + LabStyle.FROST_OUT;
              pz = f.z0 + t - w;
            }
          else if (t < 2 * w + d)
            {
              px = f.x1 - (t - w - d);
              pz = f.z1 + LabStyle.FROST_OUT;
            }
          else
            {
              px = f.x0 - LabStyle.FROST_OUT;
              pz = f.z1 - (t - 2 * w - d);
            }
          if (f.wall &&
              (px - f.wx) * nx + (pz - f.wz) * nz < LabStyle.FROST_OUT)
            continue;
          var sz = LabStyle.FROST_SZ + ((r >>> 9) % 11) * LabStyle.FROST_SZ_VAR / 10;
          emit(b, px, pz, sz, ((r >>> 24) % 64) * Math.PI / 32,
            LabStyle.FROST_PATCH_CELLS[(r >>> 14) % LabStyle.FROST_PATCH_CELLS.length],
            LabStyle.DECAL_Y + 0.008, 4);
          n++;
        }
      if (!f.wall)
        return n;
      // on the wall: a crust standing on the floor at each hand, a fringe over the top
      var rx = Math.cos(f.yaw), rz = -Math.sin(f.yaw);
      var ox = f.wx + nx * LabStyle.FROST_PROUD, oz = f.wz + nz * LabStyle.FROST_PROUD;
      for (s in [-1.0, 1.0])
        {
          var r = FacilityModel.mix(h + Std.int(s + 2) * 104729);
          var sz = LabStyle.FROST_WALL_SZ + ((r >>> 9) % 11) * LabStyle.FROST_SZ_VAR / 10;
          var a = s * (f.ww / 2 + sz * 0.3);
          upright(b, ox + rx * a, sz / 2, oz + rz * a, sz, f.yaw, LabStyle.FROST_FLOOR_CELLS[(r >>> 4) %
            LabStyle.FROST_FLOOR_CELLS.length]);
          n++;
        }
      var sz = LabStyle.FROST_WALL_SZ;
      upright(b, ox, f.h + sz * 0.3, oz, sz, f.yaw, LabStyle.FROST_FRINGE_CELLS[(h >>> 6) %
        LabStyle.FROST_FRINGE_CELLS.length]);
      return n + 1;
    }

// one flat-on sheet quad standing on a wall, centred at (x, y, z), `sz` across, its face turned to
// `yaw` (the art's top up), showing cell `idx` of lab/frost's 4x4
  static function upright(b:MeshBuf, x:Float, y:Float, z:Float, sz:Float, yaw:Float, idx:Int):Void
    {
      var hs = sz * 0.5;
      var rx = Math.cos(yaw) * hs, rz = -Math.sin(yaw) * hs;
      var u0 = (idx % 4) / 4, u1 = (idx % 4 + 1) / 4;
      var v0 = 1 - (Std.int(idx / 4) + 1) / 4, v1 = 1 - Std.int(idx / 4) / 4;
      MeshBufTools.quad(b,
        [x - rx, y - hs, z - rz], [x + rx, y - hs, z + rz], [x + rx, y + hs, z + rz],
        [x - rx, y + hs, z - rz],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// one flat sheet quad at (x, y, z), `sz` across, turned `yaw`, showing cell `idx` of a cols x cols
// sheet. render.corp.CorpClutter.emit's, copied for that file's reason (MilitaryClutter does the same)
  static function emit(b:MeshBuf, x:Float, z:Float, sz:Float, yaw:Float, idx:Int, y:Float, cols:Int):Void
    {
      var hs = sz * 0.5;
      var cs = Math.cos(yaw), sn = Math.sin(yaw);
      var lx = [ -hs, hs, hs, -hs ];
      var lz = [ hs, hs, -hs, -hs ];
      var wx = [], wz = [];
      for (i in 0...4)
        {
          wx.push(x + lx[i] * cs - lz[i] * sn);
          wz.push(z + lx[i] * sn + lz[i] * cs);
        }
      var cc = idx % cols, cr = Std.int(idx / cols);
      var u0 = cc / cols, u1 = (cc + 1) / cols;
      var v0 = 1 - (cr + 1) / cols, v1 = 1 - cr / cols;
      MeshBufTools.quad(b,
        [wx[0], y, wz[0]], [wx[1], y, wz[1]], [wx[2], y, wz[2]], [wx[3], y, wz[3]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// one sheet's worth as one mesh, on render.corp.CorpClutter.add's material for its three reasons: an
// opaque alphaTest draws DoubleSide in one pass, it still writes depth, and leaving `transparent` false
// keeps VisionMask on its darkening branch. A `glow` other than 0 lights the sheet off its own map
// at that colour (the frost)
  static function add(scene:Scene, b:MeshBuf, tex:String, ?glow:Int = 0):Void
    {
      if (b.idx.length == 0)
        return;
      var map = Textures.loadTexture(tex, 'wall', 1);
      var mat = new MeshLambertMaterial({
        map: map,
        alphaTest: LabStyle.DECAL_CUT,
        side: THREE.DoubleSide,
      });
      if (glow != 0)
        {
          mat.emissiveMap = map;
          mat.emissive = new Color(glow);
        }
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(mat));
      mesh.name = 'lab decals ' + tex;
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
