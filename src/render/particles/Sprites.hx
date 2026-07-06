package render.particles;

import three.Three;
import js.Browser;
import citygen.CityConfig;
import game.Game;

// a content-cropped atlas cell: texture trimmed to the cell's opaque bounding box, plus that
// box's size as a fraction (0..1) of the full cell. lets small sprites (debris) paint at their
// true pixel footprint, centered on the point, instead of stretched across the whole SIZE quad
typedef GroundSprite = { tex:CanvasTexture, fw:Float, fh:Float };

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
  var contentCache:Map<String, GroundSprite> = new Map(); // atlas-crop -> content-trimmed sprite
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
      var m = slot(tex, op, wx, wy, wz, scale);
      // decal: lie flat on the ground (normal up). else face the front (fixed yaw, no camera
      // tracking) leaned back toward the overhead camera by TILT so it reads flatter
      if (flat)
        m.rotation.set(-Math.PI / 2, 0, yaw);
      else
        m.rotation.set(-TILT, 0, 0);
      m.visible = true;
      idx++;
    }

// paint a content-cropped ground sprite (from texContent) flat on the ground, sized to its real
// pixel footprint (fw/fh of a cell) * scale and centered on the point, yaw-rotated in-plane. used
// for debris so a small off-centre atlas sprite lands at its true size where we place it
  public function paintGround(wx:Float, wy:Float, wz:Float, gs:GroundSprite, op:Float, scale:Float, yaw:Float):Void
    {
      if (gs == null || gs.tex == null) return;
      var m = slot(gs.tex, op, wx, wy, wz, scale);
      // geometry is SIZE x SIZE; scale each ground axis by the content fraction so the quad
      // matches the trimmed sprite's true aspect + size
      m.scale.set(gs.fw * scale, gs.fh * scale, 1);
      m.rotation.set(-Math.PI / 2, 0, yaw);
      m.visible = true;
      idx++;
    }

// place/reuse a quad standing on a wall face at world (wx,wy,wz): its normal points outward
// along faceRotY (see Geom.faceRotY), spun in-plane by roll. same pool as paint(); used for
// bullet-hole decals
  public function paintWall(wx:Float, wy:Float, wz:Float, tex:Texture, op:Float, scale:Float, faceRotY:Float, roll:Float):Void
    {
      if (tex == null) return;
      var m = slot(tex, op, wx, wy, wz, scale);
      // roll about the plane's own normal (local Z), then yaw to face the wall dir (Y). default
      // Euler XYZ applies Z before Y, so the roll stays about the reoriented outward normal
      m.rotation.set(0, faceRotY, roll);
      m.visible = true;
      idx++;
    }

// get (or lazily create) the next pooled quad, set its texture/opacity/position/scale
  inline function slot(tex:Texture, op:Float, wx:Float, wy:Float, wz:Float, scale:Float):Mesh
    {
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
      return m;
    }

// crop one atlas cell (imageName, ix, iy) into a cached texture; null until the image decodes.
// mul < 1 darkens the crop's RGB (ground decals — see darkenCanvas); actors pass the default 1.0
  public function tex(imageName:String, ix:Int, iy:Int, male:Bool, mul:Float = 1.0):CanvasTexture
    {
      var key = imageName + ':' + ix + ':' + iy + ':' + male + ':' + mul;
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
      var cx = cv.getContext('2d');
      // mirror Entity.drawImage crop (the +1/-1 kludge avoids atlas bleed)
      cx.drawImage(img, ix * t, iy * t + 1, t, t - 1, 0, 0, t, t);
      if (mul < 1.0)
        darkenCanvas(cx, t, t, mul);
      var tex = new CanvasTexture(cv);
      tex.colorSpace = THREE.SRGBColorSpace;
      texCache.set(key, tex);
      return tex;
    }

// multiply a canvas's RGB down by `mul` (alpha preserved) so a lit 3D decal reads darker without a
// hue shift. one pass, run once per cached crop
  inline function darkenCanvas(ctx:Dynamic, w:Int, h:Int, mul:Float):Void
    {
      var id = ctx.getImageData(0, 0, w, h);
      var d = id.data;
      var i = 0;
      while (i < d.length)
        {
          d[i] = Std.int(d[i] * mul);
          d[i + 1] = Std.int(d[i + 1] * mul);
          d[i + 2] = Std.int(d[i + 2] * mul);
          i += 4;
        }
      ctx.putImageData(id, 0, 0);
    }

// crop an atlas cell to its opaque content rect; cache the trimmed texture + normalized (0..1)
// content size. null until the atlas image decodes. scans the cell's alpha once per unique cell.
// mul < 1 darkens the crop's RGB (ground decals — see darkenCanvas)
  public function texContent(imageName:String, ix:Int, iy:Int, male:Bool, mul:Float = 1.0):GroundSprite
    {
      var key = imageName + ':' + ix + ':' + iy + ':' + male + ':' + mul;
      if (contentCache.exists(key)) return contentCache.get(key);
      var img:Dynamic = game.scene.images.getImage(imageName, male);
      if (img == null ||
          !img.complete ||
          img.naturalWidth <= 0)
        return null;
      var t = Const.TILE_SIZE_CLEAN;
      // draw the full cell to a scratch canvas, then scan its alpha for the opaque bounding box
      var cv:Dynamic = Browser.document.createElement('canvas');
      cv.width = t; cv.height = t;
      var cx = cv.getContext('2d');
      cx.drawImage(img, ix * t, iy * t + 1, t, t - 1, 0, 0, t, t);
      var data = cx.getImageData(0, 0, t, t).data;
      var minX = t, minY = t, maxX = -1, maxY = -1;
      for (py in 0...t)
        for (px in 0...t)
          {
            if (data[(py * t + px) * 4 + 3] <= 8) // near-transparent -> not content
              continue;
            if (px < minX) minX = px;
            if (px > maxX) maxX = px;
            if (py < minY) minY = py;
            if (py > maxY) maxY = py;
          }
      // fully transparent cell: fall back to the whole cell so we still return something valid
      if (maxX < minX)
        {
          minX = 0; minY = 0; maxX = t - 1; maxY = t - 1;
        }
      var cw = maxX - minX + 1, ch = maxY - minY + 1;
      // tight-cropped texture holding just the content rect
      var tc:Dynamic = Browser.document.createElement('canvas');
      tc.width = cw; tc.height = ch;
      var tcx = tc.getContext('2d');
      tcx.drawImage(cv, minX, minY, cw, ch, 0, 0, cw, ch);
      if (mul < 1.0)
        darkenCanvas(tcx, cw, ch, mul);
      var tex = new CanvasTexture(tc);
      tex.colorSpace = THREE.SRGBColorSpace;
      var gs:GroundSprite = { tex: tex, fw: cw / t, fh: ch / t };
      contentCache.set(key, gs);
      return gs;
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
