package render.world.roofs;

import three.Three;
import citygen.CityModel.Building;
import render.RenderConfig;
import render.Poly.tag;
import render.world.Geom;
import render.world.WorldCtx;

// pitched gable roofs: the two overhanging slabs meeting at the ridge plus the
// triangular gable ends capping the wall below (metal warehouses, slums cottages).
// Worn-face classification comes from Geom.
class Gables {
// does this building carry a gable roof? its flat top is buried under the slopes, so it takes
// none of the flat-roof dressing (contact shadows, detail decals). must match Buildings' `gable`
// exactly, or the dressing lands under a gable — or goes missing off a flat one
  public static inline function isGabled(b:Building):Bool
    return b.shop < 0 && WorldCtx.style.isGable(b.facade);

  // metal warehouse gable ("double slope") roof: TWO THIN SLABS meeting at the ridge and
  // overhanging the box on all four sides, plus 2 triangular gable ends capping the wall below.
  // ridge runs along the LONGER footprint axis. the slabs use a dedicated roof texture on EVERY
  // face — top, soffit, eave fascia, rake — so a roof reads as built material with a thickness
  // instead of a folded sheet; the vertical gable-END triangles are wall (clean or worn to match
  // the wall below — a worn back wall gets a worn gable end). world-tiled (no stretch), ribs run
  // down-slope. only for simple-rectangle buildings (metal warehouses + the slums single-floor
  // houses). DoubleSide so winding never hides a face. the box's own flat top stays, hidden
  // beneath the slopes. `roofPath` is the slope texture's source path, for the Poly registry
  public static function addGableRoof(scene:Scene, b:Building, center:{x:Float, z:Float}, wWorld:Float, dWorld:Float, cleanWall:Texture, wornWall:Texture, roofTex:Texture, roofPath:String):Void {
    var TILE = RenderConfig.WALL_TILE;
    var gV = RenderConfig.GABLE_V; // gable ends sample a CLEAN mid-texture V band (worn metal has a dirty base strip; eaves up high shouldn't show ground grime). ribs are vertical so V-shift keeps corrugation aligned.
    var OV = RenderConfig.GABLE_OVER, TH = RenderConfig.GABLE_THICK;
    var eaveY = b.h;
    var bxMin = center.x - wWorld / 2, bxMax = center.x + wWorld / 2;
    var bzMin = center.z - dWorld / 2, bzMax = center.z + dWorld / 2;
    var sP = new Array<Float>(), sU = new Array<Float>();   // slabs (roof texture, every face)
    var aP = new Array<Float>(), aU = new Array<Float>();   // gable end A
    var bP = new Array<Float>(), bU = new Array<Float>();   // gable end B
    // one axis pair instead of two mirrored branches: `along` is the ridge axis, `cross` the other,
    // and this mapper is the only place that knows which is x and which is z. everything below is
    // written once and works for both orientations
    var xz = wWorld >= dWorld;
    var alongMin = xz ? bxMin : bzMin, alongMax = xz ? bxMax : bzMax;
    var crossMin = xz ? bzMin : bxMin, crossMax = xz ? bzMax : bxMax;
    var crossC = xz ? center.z : center.x;
    inline function v(p:Array<Float>, u:Array<Float>, along:Float, y:Float, cross:Float, tu:Float, tv:Float):Void
    {
      p.push(xz ? along : cross);
      p.push(y);
      p.push(xz ? cross : along);
      u.push(tu);
      u.push(tv);
    }
    // push a quad, corners in order, each given as [along, y, cross, u, v]
    function quad(p:Array<Float>, u:Array<Float>, c0:Array<Float>, c1:Array<Float>, c2:Array<Float>, c3:Array<Float>):Void
    {
      v(p, u, c0[0], c0[1], c0[2], c0[3], c0[4]);
      v(p, u, c1[0], c1[1], c1[2], c1[3], c1[4]);
      v(p, u, c2[0], c2[1], c2[2], c2[3], c2[4]);
      v(p, u, c0[0], c0[1], c0[2], c0[3], c0[4]);
      v(p, u, c2[0], c2[1], c2[2], c2[3], c2[4]);
      v(p, u, c3[0], c3[1], c3[2], c3[3], c3[4]);
    }

    var half = (crossMax - crossMin) / 2;
    var pitchH = Math.min(half * 0.44, 2.6); // shallow gable (~18-20°)
    var ridgeY = eaveY + pitchH;
    var tanP = pitchH / half;
    var a0 = alongMin - OV, a1 = alongMax + OV;         // rake overhang, past both gable ends
    var eDist = half + OV;                              // ridge -> eave across the slope, overhung
    var eaveOutY = eaveY - OV * tanP;                   // the overhung eave hangs below the wall head
    var sV = eDist * Math.sqrt(1 + tanP * tanP) / TILE; // down-slope tile span
    var fV = TH / TILE;                                 // slab thickness in tiles, for the edge strips

    // one slope as a THIN SLAB: the sloped quad, the same quad raised GABLE_THICK STRAIGHT UP, and
    // the three exposed edge strips (eave fascia + both rakes). vertical, NOT along the slope
    // normal — a normal offset slides each top surface sideways and opens a notch along the ridge,
    // where raised straight up the two tops still meet exactly on the ridge line. the ridge edge
    // strip is skipped for the same reason both slabs own it, and two coplanar faces z-fight.
    // sg = +1 for the slope falling toward crossMax, -1 toward crossMin
    function slab(sg:Float):Void
    {
      var ec = crossC + sg * eDist;
      var eB0 = [a0, eaveOutY, ec, a0 / TILE, 0.0], eB1 = [a1, eaveOutY, ec, a1 / TILE, 0.0];
      var rB0 = [a0, ridgeY, crossC, a0 / TILE, sV], rB1 = [a1, ridgeY, crossC, a1 / TILE, sV];
      var eT0 = [a0, eaveOutY + TH, ec, a0 / TILE, 0.0], eT1 = [a1, eaveOutY + TH, ec, a1 / TILE, 0.0];
      var rT0 = [a0, ridgeY + TH, crossC, a0 / TILE, sV], rT1 = [a1, ridgeY + TH, crossC, a1 / TILE, sV];
      quad(sP, sU, eT0, eT1, rT1, rT0); // top: the roof surface
      quad(sP, sU, rB0, rB1, eB1, eB0); // soffit: same mapping, seen from below
      // eave fascia — u runs along the ridge, v continues BELOW the top surface's v=0 eave line
      quad(sP, sU,
        [a0, eaveOutY, ec, a0 / TILE, -fV],
        [a1, eaveOutY, ec, a1 / TILE, -fV],
        [a1, eaveOutY + TH, ec, a1 / TILE, 0.0],
        [a0, eaveOutY + TH, ec, a0 / TILE, 0.0]);
      // rakes — the two gable-end strips, u down-slope (matching the top face), v up the thickness
      quad(sP, sU,
        [a0, eaveOutY, ec, 0.0, 0.0],
        [a0, ridgeY, crossC, sV, 0.0],
        [a0, ridgeY + TH, crossC, sV, fV],
        [a0, eaveOutY + TH, ec, 0.0, fV]);
      quad(sP, sU,
        [a1, eaveOutY, ec, 0.0, 0.0],
        [a1, ridgeY, crossC, sV, 0.0],
        [a1, ridgeY + TH, crossC, sV, fV],
        [a1, eaveOutY + TH, ec, 0.0, fV]);
    }
    // ponytail: the overhang is unconditional, so a gabled box that abuts a shorter neighbour pokes
    // an eave over its roof. gate it per face on Geom.faceIsStreet / real adjacency if that reads wrong
    slab(1);
    slab(-1);

    // gable ends (vertical triangles) stay at the WALL plane — the rake now stands proud of them.
    // uv by the cross world coord (along the wall) × height
    var aDir = xz ? 2 : 0, bDir = xz ? 3 : 1;
    v(aP, aU, alongMax, eaveY, crossMax, crossMax / TILE, gV);
    v(aP, aU, alongMax, eaveY, crossMin, crossMin / TILE, gV);
    v(aP, aU, alongMax, ridgeY, crossC, crossC / TILE, gV + pitchH / TILE);
    v(bP, bU, alongMin, eaveY, crossMin, crossMin / TILE, gV);
    v(bP, bU, alongMin, eaveY, crossMax, crossMax / TILE, gV);
    v(bP, bU, alongMin, ridgeY, crossC, crossC / TILE, gV + pitchH / TILE);

    inline function mesh(p:Array<Float>, u:Array<Float>, tex:Texture, nm:String, desc:String, path:String):Void {
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(p, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(u, 2));
      geo.computeVertexNormals();
      var t = tex.clone(); t.needsUpdate = true; t.wrapS = t.wrapT = THREE.RepeatWrapping;
      var m = tag(new MeshLambertMaterial({ map: t, side: THREE.DoubleSide }), nm, desc, path);
      // geometry is baked in world coords (mesh stays at origin), so tag the building
      // explicitly — Occlusion's position bucketing can't place an origin-anchored mesh
      var mesh = new Mesh(geo, m);
      mesh.userData.b = b;
      scene.add(mesh);
    }
    // name the Poly classes after THIS style's facade slot: a slums cottage roof must not share
    // the warehouse's handle in the UV editor (Poly.info is first-write-wins across areas)
    var st = WorldCtx.style;
    var k = st.facadeName(b.facade);
    var cleanPath = st.walls[b.facade % st.walls.length];
    var wornPath = st.wornWalls[b.facade % st.wornWalls.length];
    mesh(sP, sU, roofTex, 'roof-gable-$k', '$k gable roof', roofPath);
    var aWorn = Geom.isWornFace(b, aDir), bWorn = Geom.isWornFace(b, bDir);
    mesh(aP, aU, aWorn ? wornWall : cleanWall, 'gable-end-$k' + (aWorn ? '-worn' : ''), '$k gable end' + (aWorn ? ' (worn)' : ''), aWorn ? wornPath : cleanPath);
    mesh(bP, bU, bWorn ? wornWall : cleanWall, 'gable-end-$k' + (bWorn ? '-worn' : ''), '$k gable end' + (bWorn ? ' (worn)' : ''), bWorn ? wornPath : cleanPath);
  }
}
