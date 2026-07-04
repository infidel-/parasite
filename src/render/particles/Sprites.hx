package render.particles;

import three.Three;
import js.Browser;
import citygen.CityConfig;
import game.Game;

// the 3D "canvas": a pool of reused sprite quads + an atlas-crop texture cache. one paint
// surface shared by the actor layer and every Particle3D. a frame is begin() -> many paint()
// -> end(); paint() consumes the next pooled quad, end() hides the leftover tail. mirrors the
// role the 2D CanvasRenderingContext2D plays for particles.Particle
class Sprites {
  public static inline var SIZE = CityConfig.CELL * 0.85; // base quad size (scale multiplies it)
  static inline var TILT = 0.6;                        // radians an upright sprite leans back toward the overhead camera

  var game:Game;                                        // for the sprite-atlas image provider
  var actorGroup:Group;                                 // scene group holding all sprite quads
  var pool:Array<Mesh> = [];                            // reused quad meshes
  var texCache:Map<String, CanvasTexture> = new Map();  // atlas-crop -> texture
  var idx:Int = 0;                                      // next free pool slot this frame

  public function new(game:Game, actorGroup:Group)
    {
      this.game = game;
      this.actorGroup = actorGroup;
    }

// start a frame: reset to the first pool slot
  public inline function begin():Void
    {
      idx = 0;
    }

// place/reuse a sprite quad at world (wx,wy,wz): texture tex, opacity op, uniform scale (of
// SIZE); flat lays it on the ground as a decal (yaw rotates it there). no-op if the atlas
// isn't decoded yet (tex == null) — the slot is not consumed
  public function paint(wx:Float, wy:Float, wz:Float, tex:CanvasTexture, op:Float, scale:Float, flat:Bool = false, yaw:Float = 0.0):Void
    {
      if (tex == null) return;
      var m = pool[idx];
      if (m == null)
        {
          // MeshStandard (not Basic) so sprites take the scene lights — ambient/moon/lamp glow —
          // instead of rendering full-bright and reading pasted-on over the lit world
          m = new Mesh(new PlaneGeometry(SIZE, SIZE),
            new MeshStandardMaterial({
              transparent: true,
              depthWrite: false,
              side: THREE.DoubleSide,
              roughness: 1,
              metalness: 0,
            }));
          pool[idx] = m;
          actorGroup.add(m);
        }
      var mat:Dynamic = m.material;
      mat.map = tex;
      mat.opacity = op;
      mat.needsUpdate = true;
      m.position.set(wx, wy, wz);
      m.scale.set(scale, scale, scale);
      // decal: lie flat on the ground (normal up). else face the front (fixed yaw, no camera
      // tracking) leaned back toward the overhead camera by TILT so it reads flatter
      if (flat)
        m.rotation.set(-Math.PI / 2, 0, yaw);
      else
        m.rotation.set(-TILT, 0, 0);
      m.visible = true;
      idx++;
    }

// crop one atlas cell (imageName, ix, iy) into a cached texture; null until the image decodes
  public function tex(imageName:String, ix:Int, iy:Int, male:Bool):CanvasTexture
    {
      var key = imageName + ':' + ix + ':' + iy + ':' + male;
      if (texCache.exists(key)) return texCache.get(key);
      var img:Dynamic = game.scene.images.getImage(imageName, male);
      // retry next frame if the atlas image isn't decoded yet
      if (img == null ||
          !img.complete ||
          img.naturalWidth <= 0)
        return null;
      var t = Const.TILE_SIZE_CLEAN;
      var cv:Dynamic = Browser.document.createElement('canvas');
      cv.width = t; cv.height = t;
      // mirror Entity.drawImage crop (the +1/-1 kludge avoids atlas bleed)
      cv.getContext('2d').drawImage(img, ix * t, iy * t + 1, t, t - 1, 0, 0, t, t);
      var tex = new CanvasTexture(cv);
      tex.colorSpace = THREE.SRGBColorSpace;
      texCache.set(key, tex);
      return tex;
    }

// end a frame: hide every pool quad left untouched this frame
  public function end():Void
    {
      for (i in idx...pool.length)
        if (pool[i] != null) pool[i].visible = false;
    }

// how many quads were painted this frame (profiler read)
  public inline function count():Int
    return idx;
}
