package render.particles;

import three.Three;
import js.Browser;

// a pooled layer of camera-facing, soft-textured, additive streak quads for impact sparks.
// unlike Beams (flat-on-ground solid squares), each quad here billboards to the camera, carries a
// soft radial glow so it reads as a round ember (not a hard square), and stretches along its
// velocity into a motion streak. pooled: a firefight allocates nothing and the one material
// compiles once. a frame is begin() -> streak() ... -> end()
class Sparks {
  var actorGroup:Group;                                 // scene group holding the quads
  var camera:Object3D;                                  // billboards face this
  var tex:Texture;                                      // soft radial glow-dot (procedural, tinted per-quad)
  var pool:Array<Mesh> = [];                            // reused quad meshes (own material each)
  var idx:Int = 0;                                      // next free pool slot this frame
  // scratch reused every streak() so a burst allocates nothing
  var ax:Vector3 = new Vector3();
  var ay:Vector3 = new Vector3();
  var az:Vector3 = new Vector3();
  var mtx:Matrix4 = new Matrix4();

  public function new(actorGroup:Group, camera:Object3D)
    {
      this.actorGroup = actorGroup;
      this.camera = camera;
      tex = makeDotTexture();
    }

// start a frame: reset to the first pool slot
  public inline function begin():Void
    {
      idx = 0;
    }

// draw a soft additive ember at (cx,cy,cz): the quad faces the camera and stretches `len` along
// world velocity (vx,vy,vz), `width` across; tinted color at opacity op. len<=width => round dot
  public function streak(cx:Float, cy:Float, cz:Float, vx:Float, vy:Float, vz:Float, len:Float, width:Float, color:Int, op:Float):Void
    {
      var m = pool[idx];
      if (m == null)
        {
          m = new Mesh(new PlaneGeometry(1, 1),
            new MeshBasicMaterial({
              map: tex,
              color: 0xffffff,
              transparent: true,
              opacity: 1.0,
              depthWrite: false,
              side: THREE.DoubleSide,
              blending: untyped THREE.AdditiveBlending,
            }));
          pool[idx] = m;
          actorGroup.add(m);
        }
      var mat:Dynamic = m.material;
      mat.opacity = op;
      untyped mat.color.setHex(color);
      // orthonormal basis so local +X (length) = velocity dir, +Z (normal) ~ toward camera,
      // +Y = width; fed as the mesh rotation, with scale stretching X/Y afterward
      var sp = Math.sqrt(vx * vx + vy * vy + vz * vz);
      var dx = 1.0, dy = 0.0, dz = 0.0;
      if (sp > 1e-5) { dx = vx / sp; dy = vy / sp; dz = vz / sp; }
      // toward the camera
      var tx = camera.position.x - cx, ty = camera.position.y - cy, tz = camera.position.z - cz;
      var tl = Math.sqrt(tx * tx + ty * ty + tz * tz);
      if (tl < 1e-5) { tx = 0; ty = 1; tz = 0; tl = 1; }
      tx /= tl; ty /= tl; tz /= tl;
      // width axis = normalize(toCam x dir); if dir ~parallel to the view, pick a fallback perp
      var wx = ty * dz - tz * dy;
      var wy = tz * dx - tx * dz;
      var wz = tx * dy - ty * dx;
      var wl = Math.sqrt(wx * wx + wy * wy + wz * wz);
      if (wl < 1e-4)
        {
          wx = dz; wy = 0.0; wz = -dx;                   // dir x world-up
          wl = Math.sqrt(wx * wx + wz * wz);
          if (wl < 1e-4) { wx = 1.0; wy = 0.0; wz = 0.0; wl = 1.0; }
        }
      wx /= wl; wy /= wl; wz /= wl;
      // normal = dir x width (re-orthogonalized)
      ax.set(dx, dy, dz);
      ay.set(wx, wy, wz);
      az.set(dy * wz - dz * wy, dz * wx - dx * wz, dx * wy - dy * wx);
      untyped mtx.makeBasis(ax, ay, az);
      untyped m.quaternion.setFromRotationMatrix(mtx);
      m.position.set(cx, cy, cz);
      m.scale.set(len, width, 1);
      m.visible = true;
      idx++;
    }

// draw a Y-axis-billboard textured quad at (cx,cy,cz): width w, height h; keeps world-up vertical
// and yaws to face the camera in the ground plane, so an upright texture (flame) reads upright.
// tinted color, additive at opacity op. shares this pool with streak() — the flame body sprite
  public function flameQuad(cx:Float, cy:Float, cz:Float, w:Float, h:Float, texture:Texture, color:Int, op:Float):Void
    {
      var m = pool[idx];
      if (m == null)
        {
          m = new Mesh(new PlaneGeometry(1, 1),
            new MeshBasicMaterial({
              map: texture,
              color: 0xffffff,
              transparent: true,
              opacity: 1.0,
              depthWrite: false,
              side: THREE.DoubleSide,
              blending: untyped THREE.AdditiveBlending,
            }));
          pool[idx] = m;
          actorGroup.add(m);
        }
      var mat:Dynamic = m.material;
      mat.opacity = op;
      untyped mat.color.setHex(color);
      untyped mat.map = texture;
      // yaw about world up to face the camera; world-up stays the quad's vertical axis
      var yaw = Math.atan2(camera.position.x - cx, camera.position.z - cz);
      m.position.set(cx, cy, cz);
      m.rotation.set(0, yaw, 0);
      m.scale.set(w, h, 1);
      m.visible = true;
      idx++;
    }

// end a frame: hide every pool quad left untouched this frame
  public function end():Void
    {
      for (i in idx...pool.length)
        if (pool[i] != null) pool[i].visible = false;
    }

// how many quads were drawn this frame (profiler read)
  public inline function count():Int
    return idx;

// build a soft round glow texture once (white radial gradient -> transparent); tinted per-quad
  function makeDotTexture():Texture
    {
      var s = 64;
      var cv:Dynamic = Browser.document.createElement('canvas');
      cv.width = s; cv.height = s;
      var g:Dynamic = cv.getContext('2d');
      var grd:Dynamic = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
      grd.addColorStop(0, 'rgba(255,255,255,1)');
      grd.addColorStop(0.35, 'rgba(255,255,255,0.6)');
      grd.addColorStop(1, 'rgba(255,255,255,0)');
      g.fillStyle = grd;
      g.fillRect(0, 0, s, s);
      var t = new CanvasTexture(cv);
      t.colorSpace = THREE.SRGBColorSpace;
      return t;
    }
}
