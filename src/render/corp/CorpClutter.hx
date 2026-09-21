package render.corp;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.ClutterSlot;
import render.facility.ClutterSlot.ClutterSlotTools;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the small FLAT things lying about on the tower's worktops — a laptop, a mug, a folder, a spread
// of paper on a desk; a carafe, a tray of cups, a folded towel on a counter or a vanity.
//
// RENDER-ONLY DRESSING, the contract render.facility.FacilityClutter opens with and the reason the
// rest of this file is shaped the way it is. These are not objects.Decoration: they carry no atlas
// frame, take no cell, block no movement and never enter a save. Every position, size, turn and
// choice of art is rolled off FacilityModel.mix on the CELL, so a floor plate comes back identical
// on every rebuild and no corp area already saved had to be migrated to get them.
//
// TWO SHEETS AND NOT ONE, picked off the cell's Surf: a keyboard and a document tray belong on a
// desk and a cafetiere and a hand towel do not. And two and not four — the kitchenette, the
// boardroom and the washroom would have filled about twenty cells each, and a PACK64 is 64 cells
// and ONE draw call whatever is on it.
//
// THE COMPOUND'S OWN FILE IS NOT REUSED AND COULD NOT BE. FacilityClutter spends most of its length
// on the CLUTTER SLOTS — the lid of every standing fitting the generator left in `m.deco`, the
// store's crates, the shelving's three plates — and a tower plate has no `m.deco` at all: its
// furniture is emitted quads off `m.table` and `m.fit`. What is left once that goes is the worktop
// scatter, which is this file, and the pack-cell arithmetic, which docs/3d-textures.md notes is
// already deliberately copied in four places rather than shared.
class CorpClutter
{
// every decal on the plate as TWO merged meshes, one per sheet. returns how many landed — a merged
// mesh has no instance count and this is the only handle on the family
  public static function build(scene:Scene, m:Facility):Int
    {
      var desk = MeshBufTools.make();
      var util = MeshBufTools.make();
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!m.table[row][col])
              continue;
            n += cell(m, col, row, deskish(m.surf[row][col]) ? desk : util);
          }
      add(scene, desk, CorpStyle.CLUTTER_DESK_TEX);
      add(scene, util, CorpStyle.CLUTTER_UTIL_TEX);
      return n;
    }

// which of the two sheets a worktop takes. a desk, a cubicle return and an exec desk carry the
// office things; a kitchen counter, a boardroom slab and a washroom vanity carry the other
  static inline function deskish(s:Surf):Bool
    {
      return s == Surf.OPEN ||
        s == Surf.CUBICLE ||
        s == Surf.EXEC;
    }

// one worktop cell's worth. returns how many actually landed, which is not the rolled count: an
// item that cannot find room in CLUTTER_TRIES attempts is dropped rather than pushed somewhere it
// does not fit.
//
// THE ROLLED COUNT REACHES ZERO ON PURPOSE. `h % (CLUTTER_MAX + 1)` gives 0..3 evenly and the empty
// cells are what stop two hundred worktops reading as a grid again — which is the whole complaint
// this family answers. Flooring it at one would put something on every cell and rebuild the rhythm
  static function cell(m:Facility, col:Int, row:Int, b:MeshBuf):Int
    {
      var g = FacilityModel.mix((col * 1103515245) ^ (row * 12345));
      var want = g % (CorpStyle.CLUTTER_MAX + 1);
      if (want == 0)
        return 0;
      // EVERYTHING ALREADY ON THIS WORKTOP, as boxes: the monitor and the keyboard, asked of
      // CorpProps rather than guessed at here. That call is a pure function of the saved grid, so
      // neither pass has to run before the other — and one oracle is what keeps a document tray
      // from landing under the screen
      var spots = CorpProps.claims(m, col, row);
      var c = CityConfig.cellToWorld(col, row);
      // the worktop is the cell pulled in by CorpFurniture's own inset, and a corp run is never
      // thinned the way a compound bench is (CorpFurniture.worktop fills its cell), so the rect is
      // the cell and this needs none of the open-hand arithmetic the compound's version carries
      var span = CityConfig.CELL / 2 - CorpStyle.FIT_INSET;
      var y = CorpFurniture.topH(m.surf[row][col]) + CorpStyle.CLUTTER_Y;
      var n = 0;
      for (i in 0...want)
        {
          var h = FacilityModel.mix(g ^ ((i + 1) * 668265263));
          var sz = CorpStyle.CLUTTER_SZ + ((h % 1000) / 1000) * CorpStyle.CLUTTER_SZ_VAR;
          var r = span - sz * 0.5 - CorpStyle.CLUTTER_INSET;
          if (r <= 0)
            continue;
          // a FREE yaw, which is the point of the family: a rank of square-on cut-outs reads as a
          // layout and a turned one reads as things somebody put down
          var yaw = ((h >>> 12) % 1000) / 1000 * 2 * Math.PI;
          var box = ClutterSlotTools.turned(c.x, c.z, sz, sz, yaw);
          var ok = false;
          for (t in 0...CorpStyle.CLUTTER_TRIES)
            {
              var hh = FacilityModel.mix(h ^ ((t + 1) * 83492791));
              box.x = c.x + (((hh % 1000) / 1000) * 2 - 1) * r;
              box.z = c.z + ((((hh >>> 10) % 1000) / 1000) * 2 - 1) * r;
              ok = !hits(spots, box);
              if (ok)
                break;
            }
          if (!ok)
            continue;
          spots.push(box);
          emit(b, box.x, box.z, sz, yaw, (h >>> 22) % CorpStyle.CLUTTER_CELLS, y);
          n++;
        }
      return n;
    }

// would this box land on something already claimed? the separating-axis test for two axis-aligned
// rects with ONE gap counted per PAIR — ClutterSlotTools.hits' own arithmetic, re-stated here only
// because that one reads the COMPOUND's clearance constant and a tower's worktops are tighter
  static function hits(slots:Array<ClutterSlot>, b:ClutterSlot):Bool
    {
      for (s in slots)
        if (Math.abs(b.x - s.x) < b.hw + s.hw + CorpStyle.CLUTTER_GAP &&
            Math.abs(b.z - s.z) < b.hd + s.hd + CorpStyle.CLUTTER_GAP)
          return true;
      return false;
    }

// one decal: a square quad lying flat on the worktop, TURNED about its own centre.
//
// it cannot go through FacilityGeom.cap, which takes an axis-aligned rect — and the turn is the
// point. The corners walk FacilityDeco.crate's cyclic order, wound to cap's own winding so the face
// looks UP, and the UV is the sheet's cell with v FLIPPED, the trap FacilitySink.emit records:
// three flips y, so the source's TOP row is the HIGH v and reading order across the sheet is the
// order the prompt listed its 64 subjects in
  static function emit(b:MeshBuf, x:Float, z:Float, sz:Float, yaw:Float, idx:Int, y:Float):Void
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
      var t = CorpStyle.CLUTTER_COLS;
      var cc = idx % t, cr = Std.int(idx / t);
      var u0 = cc / t, u1 = (cc + 1) / t;
      var v0 = 1 - (cr + 1) / t, v1 = 1 - cr / t;
      MeshBufTools.quad(b,
        [wx[0], y, wz[0]], [wx[1], y, wz[1]], [wx[2], y, wz[2]], [wx[3], y, wz[3]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// one sheet's worth as one mesh. FacilityClutter.add's material exactly, for its three reasons: an
// opaque alphaTest draws DoubleSide in ONE pass, it still writes depth so nothing sorts against the
// worktop under it, and leaving `transparent` false keeps VisionMask on its darkening branch rather
// than the alpha-scaling one.
//
// NO CONTACT POOL, unlike everything that STANDS on a worktop. A pool is the shadow of a thing
// meeting the surface it rests on; this IS the surface it rests on, with nothing between
  static function add(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        alphaTest: CorpStyle.CLUTTER_CUT,
        side: THREE.DoubleSide,
      })));
      mesh.name = 'corp clutter ' + tex;
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
