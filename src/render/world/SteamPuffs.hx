package render.world;

import js.Browser;
import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.particles.Sprites;

// the steam off the city's sewer hatches (render.CityArea hands over each lid): soft puffs rising
// off the lid, swelling and thinning as they climb. ONE instanced additive quad for every puff
// in the city, so the whole plume is one draw call; a puff fades by its instance colour, which on an
// additive blend IS its opacity. frontal like every FX tied to a world object (fixed yaw, leaned back
// by Sprites.TILT), never camera-facing, and only the vents near the camera's target puff at all
class SteamPuffs
{
  // puffs per vent, the vents that may puff at once, and how near the target a vent must be (cells)
  static inline var PER = 10;
  static inline var CAP = 8;
  static inline var RANGE = 9;
  // a puff's life in turns (RenderConfig.BASE_MS), the height it climbs, its size at birth and at death,
  // its peak brightness
  static inline var LIFE = 20.0;
  static inline var RISE = 3.2;
  static inline var SIZE0 = 0.9;
  static inline var SIZE1 = 3.2;
  static inline var PEAK = 0.26;

  var vents:Array<Vector3>;
  var mesh:InstancedMesh;
  var t = 0.0;
  // scratch, so a frame allocates nothing
  var mtx = new Matrix4();
  var pos = new Vector3();
  var scl = new Vector3();
  var col = new Color();
  var tilt = new Quaternion();

  public function new(scene:Scene, vents:Array<Vector3>)
    {
      this.vents = vents;
      if (vents.length == 0)
        return;
      var mat = new MeshBasicMaterial({
        map: puffTexture(),
        transparent: true,
        depthWrite: false,
        side: THREE.DoubleSide,
        blending: untyped THREE.AdditiveBlending,
      });
      mesh = new InstancedMesh(new PlaneGeometry(1, 1), mat, CAP * PER);
      mesh.instanceColor = new InstancedBufferAttribute(new js.lib.Float32Array(CAP * PER * 3), 3);
      mesh.count = 0;
      mesh.frustumCulled = false;
      mesh.renderOrder = Sprites.ORD_ACTOR;
      tilt.setFromEuler(new Euler(-Sprites.TILT, 0, 0));
      scene.add(mesh);
    }

// advance the plumes and repack the puffs of the vents within RANGE of `focus`
  public function tick(dtMs:Float, focus:Vector3):Void
    {
      if (mesh == null)
        return;
      t += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      var reach = RANGE * CityConfig.CELL;
      var n = 0;
      var used = 0;
      for (vi in 0...vents.length)
        {
          var v = vents[vi];
          if (used >= CAP ||
              Math.abs(v.x - focus.x) > reach ||
              Math.abs(v.z - focus.z) > reach)
            continue;
          used++;
          for (k in 0...PER)
            {
              // each puff its own phase through one life, the vents out of step with each other
              var f = (t / LIFE + k / PER + vi * 0.37) % 1.0;
              var size = SIZE0 + (SIZE1 - SIZE0) * f;
              // a lean downwind that grows as it climbs, and a wobble of its own
              var drift = f * f * 1.2 + Math.sin(f * 5.0 + vi * 1.7 + k * 2.3) * 0.25 * f;
              pos.set(v.x + drift, v.y + f * RISE + size * 0.25, v.z + drift * 0.4);
              scl.set(size, size, 1);
              mtx.compose(pos, tilt, scl);
              mesh.setMatrixAt(n, mtx);
              // in fast, out slow
              var a = PEAK * Math.min(1.0, f * 6.0) * (1.0 - f);
              col.setScalar(a);
              mesh.setColorAt(n, col);
              n++;
            }
        }
      mesh.count = n;
      mesh.instanceMatrix.needsUpdate = true;
      mesh.instanceColor.needsUpdate = true;
    }

// a soft lumpy puff, white on clear, drawn once
  static function puffTexture():Texture
    {
      var s = 64;
      var cv = Browser.document.createCanvasElement();
      cv.width = s;
      cv.height = s;
      var g = cv.getContext2d();
      // three overlapping soft blobs, so a puff is not a perfect disc
      for (b in [[32, 34, 26], [24, 28, 16], [40, 26, 18]])
        {
          var grd = g.createRadialGradient(b[0], b[1], 0, b[0], b[1], b[2]);
          grd.addColorStop(0, 'rgba(255,255,255,0.45)');
          grd.addColorStop(0.55, 'rgba(255,255,255,0.18)');
          grd.addColorStop(1, 'rgba(255,255,255,0)');
          g.fillStyle = grd;
          g.fillRect(0, 0, s, s);
        }
      var tex = new CanvasTexture(cv);
      tex.colorSpace = THREE.SRGBColorSpace;
      return tex;
    }
}
