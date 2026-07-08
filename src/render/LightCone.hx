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

// build the shaft for a lamp's SpotLight, aimed down the bulb->ground-target axis (so its base sits
// exactly on the SpotLight's lit circle, not straight-down-under-the-bulb), and parent it to the
// light. targetX/Z = the light's ground-aim point (world); radius = cone ground radius
  public static function add(light:Object3D, targetX:Float, targetZ:Float, radius:Float):Void
    {
      var C = RenderConfig.LAMP_CONE;
      // bulb -> ground-target axis in light-LOCAL space. the SpotLight object keeps identity
      // rotation (aiming is internal shading), so local = world - the light's own position
      var tx = targetX - light.position.x;
      var ty = -light.position.y;              // target is on the ground (y = 0)
      var tz = targetZ - light.position.z;
      var len = Math.sqrt(tx * tx + ty * ty + tz * tz);
      var dirX = tx / len, dirY = ty / len, dirZ = tz / len;
      // the shaft spans startFrac..1 of the axis; a top radius that follows the cone at that fraction
      var s = C.startFrac;
      var h = len * (1 - s);
      var rTop = radius * s;
      if (rTop < C.topR)
        rTop = C.topR;
      var geo = new CylinderGeometry(rTop, radius, h, C.seg, 1, true);
      var mat = new MeshBasicMaterial({
        color: C.color,
        transparent: true,
        opacity: C.opacity,
        depthWrite: false,
        side: THREE.DoubleSide,
        blending: untyped THREE.AdditiveBlending,
        alphaMap: gradient(),
      });
      var cone = new Mesh(geo, mat);
      // rotate the cylinder's big (bottom, -Y) end to point down the bulb->target direction
      var q = new Quaternion();
      q.setFromUnitVectors(new Vector3(0, -1, 0), new Vector3(dirX, dirY, dirZ));
      cone.quaternion.copy(q);
      // center the shaft segment along the axis (top at s*len, base at len = the ground target)
      var mid = (s + 1) * 0.5 * len;
      cone.position.set(dirX * mid, dirY * mid, dirZ * mid);
      light.add(cone);
    }
}
