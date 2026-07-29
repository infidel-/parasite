package render.world.roofs;

import three.Three;
import citygen.CityConfig;
import citygen.CityModel.Building;
import render.RenderConfig;
import render.Poly.tag;
import render.world.Geom;
import render.world.WorldCtx;

// downtown flat roofs: the thin coping ring (via Parapets), the mechanical penthouse
// bulkhead, and the deterministic penthouse / helipad footprints the roof-decal pass
// reserves so nothing lands on top of them.
class FlatRoofs {
  static inline var CELL = CityConfig.CELL;

// footprint of the mechanical penthouse on a downtown roof, or null when the building carries
// none (a lower setback tier, whose centre the tier above occupies, or too short/narrow).
// deterministic from the footprint (stable across reloads, unlike the detail shuffle) so the
// roof-detail pass can reserve the same rect without the penthouse having been built yet
  public static function penthouseRect(b:Building, center:{x:Float, z:Float}, wWorld:Float, dWorld:Float):{x:Float, z:Float, w:Float, d:Float} {
    if (!b.roofPenthouse) return null;
    var minSide = wWorld < dWorld ? wWorld : dWorld;
    if (b.h < CityConfig.GROUND_H + 6 * CityConfig.FLOOR_H || minSide < 5 * CELL) return null;
    var hsh = b.col * 53 + b.row * 131;
    var pw = minSide * (0.4 + (hsh % 3) * 0.08);
    var pd = minSide * (0.4 + ((hsh >> 2) % 3) * 0.08);
    return {
      x: center.x + ((hsh >> 4) % 5 - 2) * (wWorld / 2 - pw / 2) / 3,
      z: center.z + ((hsh >> 6) % 5 - 2) * (dWorld / 2 - pd / 2) / 3,
      w: pw,
      d: pd,
    };
  }

// centred helicopter landing deck on a tall, wide roof, or null when this roof carries none.
// deterministic from the footprint (like penthouseRect) so the roof pass and the detail pass agree
// on it without sharing state. a pad OWNS the roof: its building gets no mechanical penthouse and
// no sector detail decals, because both would stand in the middle of the landing area
  public static function helipadRect(b:Building, center:{x:Float, z:Float}, wWorld:Float, dWorld:Float):{x:Float, z:Float, w:Float, d:Float}
    {
      var st = WorldCtx.style;
      if (st.helipadTex == null
          || !b.roofPenthouse // a lower setback tier's deck is a one-cell ring — nothing lands there
          || (st.helipadFacades != null && st.helipadFacades.indexOf(b.facade) < 0)) // skyscrapers only, not the mid-rises/sleek
        return null;
      var minSide = wWorld < dWorld ? wWorld : dWorld;
      if (b.h < CityConfig.GROUND_H + RenderConfig.HELIPAD_MIN_FLOORS * CityConfig.FLOOR_H
          || minSide < RenderConfig.HELIPAD_MIN_CELLS * CELL)
        return null;
      if ((b.col * 197 + b.row * 71) % 100 >= Std.int(st.helipadChance * 100))
        return null;
      var s = Math.min(RenderConfig.HELIPAD_SIZE, minSide - 2 * RenderConfig.ROOF_DETAIL_MARGIN);
      return {
        x: center.x,
        z: center.z,
        w: s,
        d: s,
      };
    }

  // downtown flat roof: a thin coping ring (like the non-masonry parapet) plus a mechanical
  // penthouse bulkhead box (elevator/stair core + HVAC massing) on tall-enough towers. the
  // penthouse is real occluding massing, so it is baked into the merged moon caster (shadowPos/
  // shadowIdx, appended by the caller) exactly like the main building box, and userData.b tagged
  // so Occlusion fades it with its building
  public static function addDowntownRoof(scene:Scene, b:Building, center:{x:Float, z:Float}, wWorld:Float, dWorld:Float,
      copingTex:Texture, penthouseTex:Texture, shadowPos:Array<Float>, shadowIdx:Array<Int>):Void {
    var T = RenderConfig.PARAPET_T;
    var covered = Geom.coveredEdges(b);
    // the ring sits ON the wall head, not sunk into it: the full PARAPET_EMBED (0.6) hangs over
    // the top of the wall, and on a cell-locked glass tower that is a visibly guillotined top
    // window row. the ring's inner face is already flush with the wall plane and its footprint is
    // entirely OUTSIDE the roof, so there is nothing coplanar to z-fight — this hair is only to
    // stop a grazing-angle seam at the junction
    var h = RenderConfig.PARAPET_H, embed = 0.05, E = 0.12;
    var capY = b.h + h / 2 - embed / 2, capBoxH = h + embed;
    // single flat-roof coping ring, dropped at same-height junctions (extend=0 → stops at the cut)
    Parapets.parapetRing(scene, b, center.x, center.z, wWorld / 2 + T / 2 + E, dWorld / 2 + T / 2 + E,
      capY, capBoxH, Parapets.copingMats(copingTex, 8, 0.0), T + 2 * E, covered, 0);
    if (penthouseTex == null) return;
    if (helipadRect(b, center, wWorld, dWorld) != null) return; // the pad is centred — no bulkhead standing on it
    var r = penthouseRect(b, center, wWorld, dWorld);
    if (r == null) return; // lower setback tiers / too small: coping only, no bulkhead
    var pw = r.w, pd = r.d;
    var ph = CityConfig.FLOOR_H * (1.4 + ((b.col * 53 + b.row * 131) % 2) * 0.6);
    var px = r.x, pz = r.z, py = b.h + ph / 2;
    var geo = new BoxGeometry(pw, ph, pd);
    var t = penthouseTex.clone();
    t.needsUpdate = true;
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.repeat.set(Geom.imax(1, Math.round(pw / RenderConfig.WALL_TILE)), Geom.imax(1, Math.round(ph / RenderConfig.WALL_TILE)));
    var mat = tag(new MeshLambertMaterial({ map: t }),
      'penthouse', 'mechanical penthouse', WorldCtx.style.penthouseWall);
    var mesh = new Mesh(geo, mat);
    mesh.position.set(px, py, pz);
    mesh.userData.b = b;
    mesh.castShadow = false; // the merged caster below carries it
    mesh.receiveShadow = true;
    scene.add(mesh);
    // bake the penthouse volume into the city-wide moon caster (position-only, world-baked)
    var bgeo:BufferGeometry = cast geo;
    var bpos = bgeo.attributes.position;
    var vbase = Std.int(shadowPos.length / 3);
    for (i in 0...(bpos.count : Int)) {
      shadowPos.push(bpos.getX(i) + px);
      shadowPos.push(bpos.getY(i) + py);
      shadowPos.push(bpos.getZ(i) + pz);
    }
    for (k in 0...(bgeo.index.count : Int)) shadowIdx.push(vbase + bgeo.index.getX(k));
  }
}
