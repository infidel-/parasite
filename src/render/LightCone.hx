package render;

import three.Three;
import js.Browser;

// one instanced batch of light shafts. a STEADY set (phases empty) is built once and never touched
// again; a FLICKERING set keeps its per-lamp phases and the on/off state pulse() last packed, so a
// cone whose bulb is in its dark stretch simply isn't drawn that frame
typedef ConeSet = {
  var mesh:InstancedMesh;      // null when the set is empty (no draw call at all)
  var matrices:Array<Matrix4>; // every instance's transform, in build order
  var phases:Array<Float>;     // per-instance flicker phase; empty = a steady set
  var on:Array<Bool>;          // per-instance: was it packed into the draw last pulse()
};

// a cheap volumetric light shaft: a hollow additive cone shell hung under a lamp's bulb, outlining
// the (otherwise invisible) cone of lit air the SpotLight throws. three has no volumetric
// scattering, so this fakes it with one open-ended CylinderGeometry — amber, additive, with a
// vertical alpha fade (bright at the bulb, fading to the ground). parented to the light so it
// hides/toggles with it (debug 0/5). one static mesh per lamp, no per-frame cost
class LightCone {
  static var gradTex:Texture = null; // shared vertical fade (bright top -> faint bottom), built once

// vertical alpha gradient down the cone: brightest near the bulb (canvas top = cylinder v=1),
// faintest at the ground (canvas bottom = v=0). alphaMap samples the red channel, so grey = alpha
  static function gradient():Texture
    {
      if (gradTex != null)
        return gradTex;
      var C = RenderConfig.LAMP_CONE;
      var cv = Browser.document.createCanvasElement();
      cv.width = 4;
      cv.height = 64;
      var ctx = cv.getContext2d();
      var g = ctx.createLinearGradient(0, 0, 0, 64);
      g.addColorStop(0.0, grey(C.topA)); // bulb end: strongest
      g.addColorStop(1.0, grey(C.botA)); // ground end: faintest
      ctx.fillStyle = cast g;
      ctx.fillRect(0, 0, 4, 64);
      gradTex = new CanvasTexture(cv);
      gradTex.colorSpace = THREE.NoColorSpace;
      return gradTex;
    }

// a grey whose brightness encodes an alpha 0..1 (for the alphaMap's red channel)
  static inline function grey(a:Float):String
    {
      var v = Std.int(a * 255);
      return 'rgb(' + v + ',' + v + ',' + v + ')';
    }

// build a batch of lamp cones as ONE InstancedMesh (shared geometry, one draw call) — a straight-down
// shell per bulb. `bulbs` = each lamp's bulb ground x/z (already pushed out over the road edge);
// bulbY = bulb height; radius = cone ground radius. added to `group` (toggled with the lamps in
// debug). `phases` (optional, same length as bulbs) marks this as a FLICKERING set for pulse()
  public static function instanced(group:Object3D, bulbs:Array<{ x:Float, z:Float }>, bulbY:Float, radius:Float, ?phases:Array<Float>):ConeSet
    {
      var set:ConeSet = { mesh: null, matrices: [], phases: phases != null ? phases : [], on: [] };
      if (bulbs.length == 0)
        return set;
      var C = RenderConfig.LAMP_CONE;
      // the shaft spans startFrac..1 of the bulb->ground axis; a top radius that follows the cone there
      var s = C.startFrac;
      var h = bulbY * (1 - s);
      var rTop = radius * s;
      if (rTop < C.topR)
        rTop = C.topR;
      var geo = new CylinderGeometry(rTop, radius, h, C.seg, 1, true);
      // fold the vertical placement into the geometry so an instance sitting at the bulb has its base
      // on the ground: center offset = -bulbY*(1+startFrac)/2 below the bulb
      geo.translate(0, -bulbY * (1 + s) / 2, 0);
      var mat = new MeshBasicMaterial({
        color: C.color,
        transparent: true,
        opacity: C.opacity,
        depthWrite: false,
        side: THREE.DoubleSide,
        blending: untyped THREE.AdditiveBlending,
        alphaMap: gradient(),
      });
      var inst = new InstancedMesh(geo, mat, bulbs.length);
      // instances are scattered across the city, but three's whole-mesh cull tests a boundingSphere
      // from the base geometry at origin — wrong place, so it pops all cones in/out of frustum on
      // zoom. disable the coarse cull (one cheap draw call regardless)
      untyped inst.frustumCulled = false;
      // above Sprites.ORD_ACTOR: the additive shaft draws LAST among transparents, so anything seen
      // THROUGH the beam (ground, decals, bodies, AI behind it) gets the amber tint — else the beam
      // reads as fake glass over an untinted object. a UNIQUE order (nothing else sits here) also
      // avoids the decal-slot tie it had at the default 0, which flipped cone-over-blood on zoom
      untyped inst.renderOrder = render.particles.Sprites.ORD_ACTOR + 1;
      var q = new Quaternion(), pos = new Vector3(), one = new Vector3(1, 1, 1);
      for (i in 0...bulbs.length)
        {
          pos.set(bulbs[i].x, bulbY, bulbs[i].z);
          var mtx = new Matrix4();
          mtx.compose(pos, q, one); // identity rotation: straight-down shell
          inst.setMatrixAt(i, mtx);
          set.matrices.push(mtx); // kept so pulse() can repack a subset of them
          set.on.push(true);
        }
      untyped inst.instanceMatrix.needsUpdate = true;
      group.add(inst);
      set.mesh = inst;
      return set;
    }

// per-frame on/off for a FLICKERING cone set: a cone whose bulb is in its dark stretch is left out of
// the packed prefix, exactly the way Models.cull drops off-screen instances. this is why the
// flickering cones live in their own mesh — a shared material could only fade all of them together,
// so every outage in the area would happen in unison. no per-instance colour channel is involved.
// ponytail: on/off only, the cone does not dim through the stutter — at LAMP_CONE.opacity 0.03 that
// was never visible in the shaft. upgrade path is a real instanceColor extern
  public static function pulse(set:ConeSet, t:Float):Void
    {
      if (set.mesh == null)
        return;
      // outages are seconds apart, so on almost every frame nothing changed and the whole repack +
      // buffer upload is skipped
      var cut = RenderConfig.LAMP_LIGHT.flickOff;
      var changed = false;
      for (i in 0...set.phases.length)
        {
          var lit = render.particles.LampLights.flicker(t, set.phases[i]) >= cut;
          if (lit != set.on[i])
            {
              set.on[i] = lit;
              changed = true;
            }
        }
      if (!changed)
        return;
      var k = 0;
      for (i in 0...set.on.length)
        {
          if (!set.on[i])
            continue;
          set.mesh.setMatrixAt(k, set.matrices[i]);
          k++;
        }
      set.mesh.count = k;
      untyped set.mesh.instanceMatrix.needsUpdate = true;
    }
}
