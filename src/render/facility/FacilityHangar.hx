// what stands in the hangar: the study podium, the cable fan that feeds it, and the floor round it
//
// RENDER-ONLY AND DERIVED, like the roof and the parked cars: nothing new is stamped on the tiles, so
// every compound already saved grows its podium the moment it is drawn again. The one thing the
// surface grid cannot answer — walkable concrete and the pad's unwalkable concrete are both
// Surf.CONCRETE — is answered once in render.facility.FacilityModel.findPads while the raw tiles are
// still in scope, and arrives here as a list of centre cells.
//
// THE CABLE FAN IS NOT NEW GEOMETRY AND COSTS NO DRAW CALL. render.facility.FacilityCable already
// owns a ribbon emitter and a mesh to put ribbons in; this borrows the buffer the way FacilityWork's
// desk leads do, so the shed's fan merges into the compound's one cable mesh. What it adds over a
// floor lead to a standing unit is only the SPAN — a lab lead crosses a metre and these cross four —
// which is two constants and not a second emitter.
//
// AND THE FLOOR CLUTTER IS render.facility.FacilityClutter's arithmetic against a second sheet. The
// pack64 cell -> quad mapping is the same six lines in three places now (here, FacilityClutter.emit
// and FacilityCable.flat) and it stays copied rather than shared on purpose: each one differs in the
// axis it lays the quad on and in nothing else, and the shared version would take the difference as
// an argument and be longer than all three.

package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

typedef Hangar = {
  // the podium batch, one instance per shed. null when the compound has no hangar with a pad in it
  podium:Models.InstancedProp,
  // and how many cable runs and floor decals landed, for __facility()
  runs:Int,
  clutter:Int,
};

class FacilityHangar
{
  static inline var CELL = CityConfig.CELL;

  // the sheet cells actually dealt, derived off FacilityStyle.HANGAR_CLUTTER_SKIP exactly as
  // render.facility.FacilityClutter derives its own two — the skip list stays the one place the
  // measurement lives
  static var PICK:Array<Int> = [
    for (i in 0...FacilityStyle.HANGAR_CLUTTER_CELLS)
      if (FacilityStyle.HANGAR_CLUTTER_SKIP.indexOf(i) < 0) i
  ];

// build the hangar's contents.
//
// `cable` is FacilityCable's own buffer, BORROWED — it has to be filled before that pass merges it,
// which is the one ordering constraint in render.facility.FacilityArea's build block
  public static function build(scene:Scene, m:Facility, cable:MeshBuf):Hangar
    {
      var out:Hangar = {
        podium: null,
        runs: 0,
        clutter: 0,
      };
      // NO EARLY RETURN ON AN EMPTY COMPOUND. render.Models.instanced hands back a real but empty
      // InstancedProp for an empty placement list, and render.facility.FacilityArea pushes whatever
      // this returns onto `green` — which has to stay index-aligned with EXTRA, and which
      // render.Models.cull walks every frame. A null here is a crash in tick and not a missing prop
      var places:Array<Models.PropPlace> = [];
      var b = MeshBufTools.make();
      for (p in m.pads)
        {
          var c = CityConfig.cellToWorld(p.col, p.row);
          // no yaw roll. the dais is a circle and its ring is eightfold, so a turn on it is
          // invisible — and the four machine banks the generator carves sit on the compass points,
          // which is where the gaps between posts have to stay
          places.push({
            x: c.x,
            z: c.z,
            yaw: 0.0,
          });
          out.runs += fan(cable, m, p.col, p.row);
          out.runs += power(cable, m, m.owner[p.row][p.col]);
          out.clutter += floor(b, m, p.col, p.row);
        }
      out.podium = Models.instanced(scene, RenderConfig.MODELS.facilityHangarPodium, places,
        FacilityStyle.PODIUM_H, SOLID);
      add(scene, b);
      return out;
    }

// the cable fan: one run from every machine standing in this shed to the podium's rim.
//
// EVERY MACHINE AND NOT THE FOUR THE GENERATOR CARVES, because this cannot see the tree — it reads
// `deco` off the finished grid the way every pass here does. That is the better question anyway: a
// rack bay against a wall is machinery too, and a fan that reaches the walls is what makes the shed
// read as one rig rather than a podium with four boxes near it.
//
// MACHINES ONLY, AND NEAREST FIRST. `deco` also carries the bins and drums HangarBlock.slot dresses
// the spare floor with, and a row-major scan under the RUN_MAX cap spent the whole budget on whatever
// stood in the top rows — reported as leads from the ship to a waste bin while the machine banks on
// either side stood unplugged. Nearest first hands the cap to the four carved banks before a wall rack
  static function fan(b:MeshBuf, m:Facility, col:Int, row:Int):Int
    {
      var mid = CityConfig.cellToWorld(col, row);
      var r = FacilityStyle.PODIUM_H * 0.5 * 5.60 * FacilityStyle.PODIUM_CABLE_R;
      var si = m.owner[row][col];
      var ends = [];
      for (rr in 0...m.h)
        for (cc in 0...m.w)
          {
            if (m.owner[rr][cc] != si ||
                !machine(m.deco[rr][cc] - 1))
              continue;
            // OUT OF THE UNIT AND NOT OUT OF THE MIDDLE OF ITS CELL. render.facility.FacilityDeco
            // slides every fitting back onto its wall FACE, so a DECO_RACK_D 1.2 rack in a 4.0 cell
            // ends 0.8 short of that cell's centre — and a run begun at the centre therefore started
            // in open air in front of the rack and read as stopping near it rather than leaving it.
            // The rect's own centre is INSIDE the box, so the ribbon's first span is hidden by the
            // thing it comes out of, which is what a cable under a cabinet looks like
            var r0 = FacilityDeco.rectOf(m, cc, rr, m.deco[rr][cc] - 1);
            var x = (r0.x0 + r0.x1) / 2, z = (r0.z0 + r0.z1) / 2;
            var d = Math.sqrt((mid.x - x) * (mid.x - x) + (mid.z - z) * (mid.z - z));
            if (d < r + CELL * 0.5)
              continue;
            ends.push({
              x: x,
              z: z,
              d: d,
              seed: FacilityModel.mix((cc * 70001) ^ (rr * 30011)),
            });
          }
      ends.sort(function(p, q) return Reflect.compare(p.d, q.d));
      var n = 0;
      for (e in ends)
        {
          if (n >= FacilityStyle.CABLE_RUN_MAX)
            break;
          var dx = mid.x - e.x, dz = mid.z - e.z;
          // the run STOPS AT THE RIM and not at the centre: the last span has to arrive at the
          // port band the lower step wears, and a ribbon carried to the middle of the dais would
          // run up over the tread everything else is keeping clear of
          FacilityCable.strip(b, {
            a: [ e.x, FacilityStyle.PODIUM_CABLE_Y, e.z ],
            c: [ mid.x - dx / e.d * r, FacilityStyle.PODIUM_CABLE_Y, mid.z - dz / e.d * r ],
            n: [ 0.0, 1.0, 0.0 ],
            side: null,
            bow: FacilityStyle.PODIUM_CABLE_BOW,
            wave: FacilityStyle.PODIUM_CABLE_WAVE,
            seed: e.seed,
          });
          n++;
        }
      return n;
    }

// the corner server racks to the power generators: a messy BUNDLE from every rack unit in this shed
// to the generator nearest it (gen.blocks.HangarBlock.generators stands one off each racked corner
// first, so nearest is almost always its own).
//
// INTO THE SAME BORROWED BUFFER as the fan, so the bundles are the compound's one cable mesh and cost
// no draw call. Everything about a strand is rolled off its own seed — whether the bundle takes a
// third, where each end is thrown, which way it bows, how it kinks (StripOpts.mess) — and each lies
// GEN_CABLE_LIFT over the last, because a messy bundle crosses itself and two crossing ribbons in one
// plane z-fight
  static function power(b:MeshBuf, m:Facility, si:Int):Int
    {
      var gens = [];
      var racks = [];
      for (rr in 0...m.h)
        for (cc in 0...m.w)
          {
            if (m.owner[rr][cc] != si)
              continue;
            var k = m.deco[rr][cc] - 1;
            if (k != _FittingKind.FIT_GENERATOR &&
                k != _FittingKind.FIT_RACK &&
                k != _FittingKind.FIT_RACK_LOW)
              continue;
            var r0 = FacilityDeco.rectOf(m, cc, rr, k);
            var p = {
              x: (r0.x0 + r0.x1) / 2,
              z: (r0.z0 + r0.z1) / 2,
              seed: FacilityModel.mix((cc * 92821) ^ (rr * 68917)),
            };
            if (k == _FittingKind.FIT_GENERATOR)
              gens.push(p);
            else
              racks.push(p);
          }
      if (gens.length == 0)
        return 0;
      var n = 0;
      for (r in racks)
        {
          var g = gens[0];
          var best = Math.POSITIVE_INFINITY;
          for (q in gens)
            {
              var d = (q.x - r.x) * (q.x - r.x) + (q.z - r.z) * (q.z - r.z);
              if (d < best)
                {
                  best = d;
                  g = q;
                }
            }
          var strands = FacilityStyle.GEN_CABLE_STRANDS +
            (r.seed % 100 < FacilityStyle.GEN_CABLE_THIRD_PCT ? 1 : 0);
          for (i in 0...strands)
            {
              var s = FacilityModel.mix(r.seed ^ ((i + 1) * 40503));
              var sp = FacilityStyle.GEN_CABLE_SPLAY;
              // each end thrown its own way off the unit's centre, -1..1 of the splay on both axes
              var j = function(k:Int):Float
                return (((s >>> k) % 1000) / 500.0 - 1.0) * sp;
              var y = FacilityStyle.PODIUM_CABLE_Y + i * FacilityStyle.GEN_CABLE_LIFT;
              FacilityCable.strip(b, {
                a: [ r.x + j(1), y, r.z + j(5) ],
                c: [ g.x + j(9), y, g.z + j(13) ],
                n: [ 0.0, 1.0, 0.0 ],
                side: null,
                bow: FacilityStyle.GEN_CABLE_BOW * (0.5 + ((s >>> 17) % 100) / 100.0),
                wave: FacilityStyle.GEN_CABLE_WAVE,
                mess: FacilityStyle.GEN_CABLE_MESS,
                seed: s,
              });
              n++;
            }
        }
      return n;
    }

// is this fitting kind a MACHINE a lead could come out of? racks, machine casings and the analyser —
// not a bin, a drum or a shelf
  static function machine(kind:Int):Bool
    {
      return kind == _FittingKind.FIT_RACK ||
        kind == _FittingKind.FIT_RACK_LOW ||
        kind == _FittingKind.FIT_MACHINE ||
        kind == _FittingKind.FIT_MACHINE_LOW ||
        kind == _FittingKind.FIT_ANALYSER;
    }

// the shed's floor decals: one roll per bare concrete cell of this structure.
//
// bare and not merely concrete — a cell carrying a fitting, a worktop or the pad itself is spoken
// for, and CLEAR keeps the rest off the dais's own apron so the podium is not lying in litter
  static function floor(b:MeshBuf, m:Facility, pcol:Int, prow:Int):Int
    {
      var si = m.owner[prow][pcol];
      var keep = Std.int(FacilityStyle.PODIUM_PAD / 2) + FacilityStyle.HANGAR_CLUTTER_CLEAR;
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.owner[row][col] != si ||
                m.surf[row][col] != Surf.CONCRETE ||
                m.deco[row][col] != 0 ||
                m.table[row][col] ||
                (Std.int(Math.abs(col - pcol)) <= keep &&
                 Std.int(Math.abs(row - prow)) <= keep))
              continue;
            var h = FacilityModel.mix((col * 374761393) ^ (row * 40503));
            if (h % 100 >= FacilityStyle.HANGAR_CLUTTER_PCT)
              continue;
            var c = CityConfig.cellToWorld(col, row);
            var sz = FacilityStyle.HANGAR_CLUTTER_SZ +
              ((h >> 7) % 1000 / 1000.0 - 0.5) * 2 * FacilityStyle.HANGAR_CLUTTER_SZ_VAR;
            emit(b, c.x, c.z, sz, (h >> 17) % 6283 / 1000.0,
              PICK[(h >> 3) % PICK.length]);
            n++;
          }
      return n;
    }

// one pack64 cell as a yawed quad lying on the floor. FacilityClutter.emit's arithmetic, against
// this family's own sheet and at floor height — v is FLIPPED, so the source's TOP row is the HIGH v
  static function emit(b:MeshBuf, x:Float, z:Float, sz:Float, yaw:Float, idx:Int):Void
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
      var t = FacilityStyle.HANGAR_CLUTTER_COLS;
      var cc = idx % t, cr = Std.int(idx / t);
      var u0 = cc / t, u1 = (cc + 1) / t;
      var v0 = 1 - (cr + 1) / t, v1 = 1 - cr / t;
      var y = FacilityStyle.HANGAR_CLUTTER_Y;
      MeshBufTools.quad(b,
        [wx[0], y, wz[0]], [wx[1], y, wz[1]], [wx[2], y, wz[2]], [wx[3], y, wz[3]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// the whole family as one mesh, FacilityClutter.add's material exactly and for its three reasons: an
// opaque alphaTest draws DoubleSide in ONE pass, it still writes depth so nothing sorts against the
// concrete under it, and leaving `transparent` false keeps VisionMask on its darkening branch
  static function add(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(FacilityStyle.HANGAR_CLUTTER_TEX, 'wall', 1),
        alphaTest: FacilityStyle.CLUTTER_CUT,
        side: THREE.DoubleSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
