package render.world.roofs;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import render.RenderConfig;
import render.RenderConfig.DETAIL_TYPES;
import render.Textures;
import render.Poly.tag;
import render.world.Geom;
import render.world.WorldCtx;

// rooftop clutter: one citywide pass laying a top-down sprite decal per roof sector,
// instanced per detail type, or a single centred deck where FlatRoofs put a helipad.
// The mechanical penthouse footprint is reserved so no decal pokes through its walls.
class RoofDetails {
  static inline var CELL = CityConfig.CELL;

  // roof details: a top-down sprite decal per sector, instanced per type
  public static function addRoofDetails(scene:Scene):Void {
    var buildings = WorldCtx.buildings;
    var sprites = [for (t in DETAIL_TYPES) Textures.loadKeyedTexture(t.tex, t.crop, RenderConfig.DETAIL_BOX_COLOR)];
    // one material per detail type, shared by every building: only `map` differs between types, so
    // allocating per building left ~750 identical materials live citywide where 6 do the same job
    var mats = [for (t in 0...DETAIL_TYPES.length) new MeshLambertMaterial({
      map: sprites[t],
      transparent: false,
      alphaTest: 0.5,
      side: THREE.DoubleSide,
    })];
    var q = new Quaternion();
    var qx = new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), -Math.PI / 2);
    var up = new Vector3(0, 1, 0);
    var pos = new Vector3();
    var scl = new Vector3();
    var decalGeo = new PlaneGeometry(1, 1);
    // one shared helipad material for the whole city (null outside an area style that has pads)
    var padMat = WorldCtx.style.helipadTex == null ? null : tag(new MeshLambertMaterial({
      map: Textures.loadTexture(WorldCtx.style.helipadTex, 'facade'),
      side: THREE.DoubleSide,
    }), 'roof-helipad', 'rooftop helipad', WorldCtx.style.helipadTex);

    for (b in buildings) {
      if (Gables.isGabled(b)) continue; // gabled roofs (warehouses, slums cottages) — nothing stands on a slope
      // an intermediate setback deck is a one-cell ring around the tier rising out of it —
      // a top-down decal there runs straight into that wall. only lower tiers clear the flag
      if (!b.roofPenthouse) continue;
      var wWorld = b.w * CELL;
      var dWorld = b.d * CELL;
      var hx = wWorld / 2 - RenderConfig.ROOF_DETAIL_MARGIN;
      var hz = dWorld / 2 - RenderConfig.ROOF_DETAIL_MARGIN;
      if (hx <= 0 || hz <= 0) continue;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      // a helipad takes the whole roof: one centred deck instead of the sector grid (and
      // FlatRoofs.addDowntownRoof drops the penthouse for the same building)
      var pad = FlatRoofs.helipadRect(b, center, wWorld, dWorld);
      if (pad != null)
        {
          var m = new Mesh(decalGeo, padMat);
          m.rotation.x = -Math.PI / 2;
          m.scale.set(pad.w, pad.d, 1);
          m.position.set(pad.x, b.h + 0.05, pad.z);
          m.userData.b = b;
          scene.add(m);
          continue;
        }
      // the mechanical penthouse is real massing standing on this roof — a decal under it
      // pokes through its walls, so reserve its footprint
      var pen = WorldCtx.style.roofDowntown && WorldCtx.style.penthouseWall != null
        ? FlatRoofs.penthouseRect(b, center, wWorld, dWorld) : null;

      var cols = Std.int(Geom.imax(1, Math.round((2 * hx) / RenderConfig.ROOF_SECTOR)));
      var rows = Std.int(Geom.imax(1, Math.round((2 * hz) / RenderConfig.ROOF_SECTOR)));
      while (cols * rows > RenderConfig.DETAIL_MAX) { if (cols >= rows) cols--; else rows--; }
      var secW = (2 * hx) / cols;
      var secD = (2 * hz) / rows;

      var order = [for (i in 0...DETAIL_TYPES.length) i];
      var i = order.length - 1;
      while (i > 0) {
        var j = Std.int(Math.random() * (i + 1));
        var tmp = order[i]; order[i] = order[j]; order[j] = tmp;
        i--;
      }
      // per-building matrices, grouped by detail type
      var decalM:Array<Array<Matrix4>> = [for (t in DETAIL_TYPES) []];
      var pick = 0;
      for (ci in 0...cols) {
        for (cj in 0...rows) {
          var t = order[(pick++) % order.length];
          var type = DETAIL_TYPES[t];
          var yaw = Std.int(Math.random() * 4) * (Math.PI / 2);
          var x = center.x - hx + (ci + 0.5) * secW;
          var z = center.z - hz + (cj + 0.5) * secD;
          // yaw is a multiple of 90°, so the decal's world AABB is its size or its transpose
          var dx = (Math.abs(Math.cos(yaw)) > 0.5 ? type.w : type.d) / 2;
          var dz = (Math.abs(Math.cos(yaw)) > 0.5 ? type.d : type.w) / 2;
          if (pen != null
              && Math.abs(x - pen.x) < pen.w / 2 + dx
              && Math.abs(z - pen.z) < pen.d / 2 + dz)
            continue;
          q.setFromAxisAngle(up, yaw).multiply(qx);
          pos.set(x, b.h + 0.05, z);
          scl.set(type.w, type.d, 1);
          decalM[t].push(new Matrix4().compose(pos, q, scl));
        }
      }
      // one instanced mesh per used type, tagged with the building so Occlusion fades them too
      for (t in 0...DETAIL_TYPES.length) {
        if (decalM[t].length == 0) continue;
        var decals = new InstancedMesh(decalGeo, mats[t], decalM[t].length);
        for (k in 0...decalM[t].length) decals.setMatrixAt(k, decalM[t][k]);
        decals.instanceMatrix.needsUpdate = true;
        decals.userData.b = b;
        scene.add(decals);
      }
    }
  }
}
