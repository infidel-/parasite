package render;

import three.Three;
import js.Browser;

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

// build ALL lamp cones as ONE InstancedMesh (shared geometry, one draw call) — a straight-down shell
// per bulb. `bulbs` = each lamp's bulb ground x/z (already pushed out over the road edge); bulbY =
// bulb height; radius = cone ground radius. added to `group` (toggled with the lamps in debug)
  public static function instanced(group:Object3D, bulbs:Array<{ x:Float, z:Float }>, bulbY:Float, radius:Float):Void
    {
      if (bulbs.length == 0)
        return;
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
      var q = new Quaternion(), mtx = new Matrix4(), pos = new Vector3(), one = new Vector3(1, 1, 1);
      for (i in 0...bulbs.length)
        {
          pos.set(bulbs[i].x, bulbY, bulbs[i].z);
          mtx.compose(pos, q, one); // identity rotation: straight-down shell
          inst.setMatrixAt(i, mtx);
        }
      untyped inst.instanceMatrix.needsUpdate = true;
      group.add(inst);
    }
}
