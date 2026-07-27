package render.world.roofs;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import render.RenderConfig;
import render.Textures;
import render.world.Geom;
import render.world.WorldCtx;

// fake contact shadows under the parapet: one citywide pass emitting instanced gradient
// decals along every exposed roof edge, plus radial ones at the convex/reentrant corners.
// Edge coverage comes from Geom, so a shadow band only exists where a parapet does.
class RoofShadows {
  static inline var CELL = CityConfig.CELL;

  // fake contact shadow under the parapet: instanced gradient decals on the roof
  public static function addRoofShadows(scene:Scene):Void {
    var buildings = WorldCtx.buildings;
    var geo = new PlaneGeometry(1, 1);
    inline function mkMat(alphaMap:Texture):MeshBasicMaterial return new MeshBasicMaterial({
      color: 0x000000, alphaMap: alphaMap, transparent: true, opacity: RenderConfig.ROOF_SHADOW_ALPHA,
      depthWrite: false, side: THREE.DoubleSide });
    var q = new Quaternion();
    var qx = new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), -Math.PI / 2);
    var up = new Vector3(0, 1, 0);
    var pos = new Vector3();
    var scl = new Vector3();
    var W = RenderConfig.ROOF_SHADOW_W;
    var CW = W * 1.7;
    var OV = 0;
    var edgeM:Array<Matrix4> = [];
    var cornM:Array<Matrix4> = [];
    inline function push(arr:Array<Matrix4>, len1:Float, len2:Float, yaw:Float, px:Float, py:Float, pz:Float) {
      q.setFromAxisAngle(up, yaw).multiply(qx);
      pos.set(px, py, pz);
      scl.set(len1, len2, 1);
      arr.push(new Matrix4().compose(pos, q, scl));
    }
    for (b in buildings) {
      if (Gables.isGabled(b)) continue; // gabled roofs (warehouses, slums cottages) have no flat parapet roof to shade
      var wWorld = b.w * CELL;
      var dWorld = b.d * CELL;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      var y = b.h + 0.03;
      var offX = wWorld / 2 - RenderConfig.PARAPET_T / 2 + OV;
      var offZ = dWorld / 2 - RenderConfig.PARAPET_T / 2 + OV;
      // skip shadow where the parapet was removed at a same-height junction, else
      // a contact-shadow band lingers on the roof with no wall to cast it
      var covered = Geom.coveredEdges(b);
      var bxMin = center.x - wWorld / 2, bxMax = center.x + wWorld / 2;
      var bzMin = center.z - dWorld / 2, bzMax = center.z + dWorld / 2;
      // shadow follows wall: edge bands only on exposed (parapet-bearing) spans, cut
      // at same-height seams where the parapet — and so its shadow — was removed
      for (seg in Geom.exposedSpans(covered, 0, bxMin, bxMax, 0)) push(edgeM, seg.b - seg.a, W, 0, (seg.a + seg.b) / 2, y, center.z + offZ - W / 2);
      for (seg in Geom.exposedSpans(covered, 1, bxMin, bxMax, 0)) push(edgeM, seg.b - seg.a, W, Math.PI, (seg.a + seg.b) / 2, y, center.z - offZ + W / 2);
      for (seg in Geom.exposedSpans(covered, 2, bzMin, bzMax, 0)) push(edgeM, seg.b - seg.a, W, Math.PI / 2, center.x + offX - W / 2, y, (seg.a + seg.b) / 2);
      for (seg in Geom.exposedSpans(covered, 3, bzMin, bzMax, 0)) push(edgeM, seg.b - seg.a, W, -Math.PI / 2, center.x - offX + W / 2, y, (seg.a + seg.b) / 2);
      // convex corner radials — only at real outline corners. skip any corner whose
      // adjacent edge is covered there (a junction/colinear point, no two walls meet)
      function coveredAt(dir:Int, coord:Float):Bool {
        for (iv in covered[dir]) if (iv.a - 1e-4 <= coord && coord <= iv.b + 1e-4) return true;
        return false;
      }
      var SR = W * 0.7; // concave radials a touch smaller than the band so they never overgrow it
      inline function concave(px:Float, pz:Float, nsx:Float, nsz:Float) {
        var yaw = nsx > 0 ? (nsz > 0 ? 0.0 : Math.PI / 2) : (nsz > 0 ? -Math.PI / 2 : Math.PI);
        push(cornM, SR, SR, yaw, px - nsx * SR / 2, y, pz - nsz * SR / 2);
      }
      // per outline corner: outward diagonal void (else buried → skip). both edges
      // exposed → real convex corner. both edges covered but the diagonal still open →
      // a reentrant corner where the void is only the diagonal notch (e.g. a + centre,
      // fully ringed by arms); its two interior walls meet here → concave radial. one
      // edge covered → a colinear straight point, no radial
      var corners:Array<Array<Float>> = [[1, 1, 0], [1, -1, Math.PI / 2], [-1, -1, Math.PI], [-1, 1, -Math.PI / 2]];
      for (cdef in corners) {
        var sx = cdef[0], sz = cdef[1], yaw = cdef[2];
        var cornerX = center.x + sx * wWorld / 2, cornerZ = center.z + sz * dWorld / 2;
        if (Geom.cornerBuried(b, cornerX, cornerZ, sx, sz)) continue;
        var ec0 = coveredAt(sz > 0 ? 0 : 1, cornerX), ec1 = coveredAt(sx > 0 ? 2 : 3, cornerZ);
        if (!ec0 && !ec1) push(cornM, CW, CW, yaw, center.x + sx * (offX - CW / 2), y, center.z + sz * (offZ - CW / 2));
        else if (ec0 && ec1) concave(cornerX, cornerZ, sx, sz);
      }
      // reentrant corner at the interior end of a covered span (an L/T tip), where two
      // exposed perimeter walls meet at an inside corner — fill that nook
      for (iv in covered[0]) { if (iv.a > bxMin + 1e-4) concave(iv.a, bzMax, -1, 1); if (iv.b < bxMax - 1e-4) concave(iv.b, bzMax, 1, 1); }
      for (iv in covered[1]) { if (iv.a > bxMin + 1e-4) concave(iv.a, bzMin, -1, -1); if (iv.b < bxMax - 1e-4) concave(iv.b, bzMin, 1, -1); }
      for (iv in covered[2]) { if (iv.a > bzMin + 1e-4) concave(bxMax, iv.a, 1, -1); if (iv.b < bzMax - 1e-4) concave(bxMax, iv.b, 1, 1); }
      for (iv in covered[3]) { if (iv.a > bzMin + 1e-4) concave(bxMin, iv.a, -1, -1); if (iv.b < bzMax - 1e-4) concave(bxMin, iv.b, -1, 1); }
    }
    var sets = [{ mats: edgeM, tex: Textures.makeShadowGradient() }, { mats: cornM, tex: Textures.makeRadialShadowGradient() }];
    for (s in sets) {
      var mesh = new InstancedMesh(geo, mkMat(s.tex), s.mats.length);
      for (k in 0...s.mats.length) mesh.setMatrixAt(k, s.mats[k]);
      mesh.instanceMatrix.needsUpdate = true;
      scene.add(mesh);
    }
  }
}
