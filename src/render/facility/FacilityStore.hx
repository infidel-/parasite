package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the store room's floor: the flat litter, spills and markings a working store has on it.
//
// RENDER-ONLY AND DERIVED, like the roof and the parked cars: nothing is stamped on the tiles for
// it, so every compound already saved dresses its store the moment it is drawn again. What it is
// derived FROM is the floor itself — gen.facility.FacilityRooms.roomStorage paints a store in
// concrete and it is the one INDOOR room in the compound that is, so "Surf.CONCRETE inside a
// structure that is not the shed" names exactly the store's cells and nothing else. No room list, no
// role lookup, no second grid.
//
// THE ARITHMETIC IS render.facility.FacilityClutter.emit's, against a fourth pack64 sheet, and it
// stays copied rather than shared for the reason FacilityHangar's header gives: each copy differs
// only in the axis it lays the quad on, and a shared version would take that as an argument and come
// out longer than all four.
//
// ONE MERGED MESH, so the whole family is ONE draw call however many decals land, and mask-patched
// like everything else a player walks in on
class FacilityStore
{
// every store decal in the compound as one mesh. returns how many landed, for __facility() — a
// merged mesh has no instance count and this is the only handle on the family
  public static function build(scene:Scene, m:Facility):Int
    {
      var b = MeshBufTools.make();
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var si = m.owner[row][col];
            // bare concrete floor in a lab building: a cell carrying a fitting or a worktop is
            // spoken for, and the shed's own floor is the hangar pass's business one storey down
            if (si < 0 ||
                m.structures[si].hangar ||
                m.surf[row][col] != Surf.CONCRETE ||
                m.deco[row][col] != 0 ||
                m.table[row][col])
              continue;
            var h = FacilityModel.mix((col * 374761393) ^ (row * 40503));
            if (h % 100 >= FacilityStyle.STORE_CLUTTER_PCT)
              continue;
            var c = CityConfig.cellToWorld(col, row);
            var sz = FacilityStyle.STORE_CLUTTER_SZ +
              ((h >> 7) % 1000 / 1000.0 - 0.5) * 2 * FacilityStyle.STORE_CLUTTER_SZ_VAR;
            emit(b, c.x, c.z, sz, (h >> 17) % 6283 / 1000.0,
              (h >> 3) % FacilityStyle.STORE_CLUTTER_CELLS);
            n++;
          }
      add(scene, b);
      return n;
    }

// one pack64 cell as a yawed quad lying on the floor
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
      var t = FacilityStyle.STORE_CLUTTER_COLS;
      var cc = idx % t, cr = Std.int(idx / t);
      var u0 = cc / t, u1 = (cc + 1) / t;
      var v0 = 1 - (cr + 1) / t, v1 = 1 - cr / t;
      var y = FacilityGround.surfY(Surf.CONCRETE) + FacilityStyle.STORE_CLUTTER_Y;
      MeshBufTools.quad(b,
        [wx[0], y, wz[0]], [wx[1], y, wz[1]], [wx[2], y, wz[2]], [wx[3], y, wz[3]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// the whole family as one mesh, FacilityHangar.add's material exactly and for its three reasons: an
// opaque alphaTest draws DoubleSide in ONE pass, it still writes depth so nothing sorts against the
// concrete under it, and leaving `transparent` false keeps VisionMask on its darkening branch
  static function add(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(FacilityStyle.STORE_CLUTTER_TEX, 'wall', 1),
        alphaTest: FacilityStyle.CLUTTER_CUT,
        side: THREE.DoubleSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
