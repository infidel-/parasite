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
import render.Models;
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
  public static function build(scene:Scene, m:Facility):{ n:Int, props:Array<Models.InstancedProp> }
    {
      var desk = MeshBufTools.make();
      var util = MeshBufTools.make();
      // and the handful of cells that are PROPS rather than decals — see CorpStyle.CLUTTER_PROP_OF
      var props = [for (_ in 0...CorpStyle.CLUTTER_PROPS) new Array<Models.PropPlace>()];
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!m.table[row][col])
              continue;
            n += cell(m, col, row, deskish(m.surf[row][col]) ? desk : util, props);
          }
      add(scene, desk, CorpStyle.CLUTTER_DESK_TEX);
      add(scene, util, CorpStyle.CLUTTER_UTIL_TEX);
      // and the third sheet, which is not a worktop at all: what the people in the cubicle farm
      // have pinned to their own panels
      var panel = MeshBufTools.make();
      for (q in CorpFurniture.panels)
        n += face(q, panel);
      add(scene, panel, CorpStyle.PANEL_TEX);
      // ONE BATCH PER PATH, which is what four props cost and the whole of what the promotion is
      // argued against: the two sheets above are two calls for sixty-odd kinds, and every glb here
      // is a call of its own however few land
      var out = [];
      for (i in 0...CorpStyle.CLUTTER_PROPS)
        out.push(CorpProps.clutterBatch(scene, CorpStyle.CLUTTER_PROP_PATH[i], props[i],
          CorpStyle.CLUTTER_PROP_H[i]));
      return {
        n: n,
        props: out,
      };
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
  static function cell(m:Facility, col:Int, row:Int, b:MeshBuf,
      props:Array<Array<Models.PropPlace>>):Int
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
          // A PROMOTED CELL STANDS A GLB INSTEAD, on the same roll, at the same place and the same
          // free yaw — so the scatter is untouched and a floor plate comes back identical either
          // way. `y` is the worktop's own top, which is where a decal lay and where a prop stands
          var idx = (h >>> 22) % CorpStyle.CLUTTER_CELLS;
          var prop = CorpStyle.CLUTTER_PROP_OF.exists(idx) ?
            CorpStyle.CLUTTER_PROP_OF.get(idx) : -1;
          if (prop >= 0)
            props[prop].push({
              x: box.x,
              z: box.z,
              yaw: yaw,
              y: y,
            });
          else
            emit(b, box.x, box.z, sz, yaw, idx, y);
          n++;
        }
      return n;
    }

// ONE PANEL'S TWO FACES' WORTH, and the arithmetic is the worktop's turned on its side.
//
// a panel is a 0.1-thick slab standing on a cell boundary, so its two faces look into two
// DIFFERENT bays and each is one worker's own wall — which is why the roll is per face and not per
// panel. Nothing has to be claimed against: the only things on a panel are the ones this pass puts
// there, so the rejection sampling the worktop needs (a monitor and a keyboard are already
// standing on it) has no work to do here and the slots are simply spread along the run.
//
// A FACE CARRYING THE COMPANY'S POSTER IS LEFT BARE. CorpFurniture.panelPoster is the shared
// predicate and render.corp.CorpSigns hangs the poster itself, into the sheet it already owns
  static function face(q:CorpFurniture.CorpPanel, b:MeshBuf):Int
    {
      var n = 0;
      for (side in 0...2)
        {
          if (CorpFurniture.panelPoster(q, side))
            continue;
          var g = FacilityModel.mix(q.seed ^ ((side + 1) * 1103515245));
          var want = g % (CorpStyle.PANEL_MAX + 1);
          for (i in 0...want)
            {
              var h = FacilityModel.mix(g ^ ((i + 1) * 668265263));
              var sz = CorpStyle.PANEL_SZ + ((h % 1000) / 1000) * CorpStyle.PANEL_SZ_VAR;
              // along the run, spread the way CorpLamps and CorpSigns spread theirs: slot i sits
              // (i + 0.5) / want of the way down, so one item lands on the panel's own centre
              var lo = (q.alongX ? q.x0 : q.z0) + CorpStyle.PANEL_END;
              var hi = (q.alongX ? q.x1 : q.z1) - CorpStyle.PANEL_END;
              if (hi - lo < sz)
                continue;
              var at = lo + (hi - lo) * (i + 0.5) / want;
              var y = CorpStyle.PARTITION_H *
                (CorpStyle.PANEL_LO + (CorpStyle.PANEL_HI - CorpStyle.PANEL_LO) *
                  (((h >>> 12) % 1000) / 1000));
              var out = (((h >>> 22) & 1) == 0 ? -1.0 : 1.0);
              emitFace(b, q, at, y, sz, out, (h >>> 4) % CorpStyle.PANEL_CELLS);
              n++;
            }
        }
      return n;
    }

// one pinned decal: a square quad standing PANEL_PROUD off one face of the panel, square on to it.
//
// no turn and no yaw roll, which is the opposite call to the worktop's: a thing lying on a desk was
// PUT DOWN and a thing pinned to a wall was HUNG, and a wall of jaunty angles reads as a collage
  static function emitFace(b:MeshBuf, q:CorpFurniture.CorpPanel, at:Float, y:Float, sz:Float,
      out:Float, idx:Int):Void
    {
      var hs = sz * 0.5;
      var y0 = y - hs, y1 = y + hs;
      var a0 = at - hs, a1 = at + hs;
      // the face's own plane: the panel's near or far hand, pushed out by PANEL_PROUD
      var p = (q.alongX
        ? (out < 0 ? q.z0 - CorpStyle.PANEL_PROUD : q.z1 + CorpStyle.PANEL_PROUD)
        : (out < 0 ? q.x0 - CorpStyle.PANEL_PROUD : q.x1 + CorpStyle.PANEL_PROUD));
      var t = CorpStyle.PANEL_COLS;
      var cc = idx % t, cr = Std.int(idx / t);
      var u0 = cc / t, u1 = (cc + 1) / t;
      var v0 = 1 - (cr + 1) / t, v1 = 1 - cr / t;
      // the material draws DoubleSide in one opaque pass, so the winding is free and one order
      // serves both hands — FacilityClutter.add's own three reasons, restated in `add` below
      if (q.alongX)
        MeshBufTools.quad(b, [a0, y0, p], [a1, y0, p], [a1, y1, p], [a0, y1, p],
          [u0, v0, u1, v0, u1, v1, u0, v1]);
      else
        MeshBufTools.quad(b, [p, y0, a0], [p, y0, a1], [p, y1, a1], [p, y1, a0],
          [u0, v0, u1, v0, u1, v1, u0, v1]);
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
