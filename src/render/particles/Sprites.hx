package render.particles;

import three.Three;
import js.Browser;
import citygen.CityConfig;
import render.RenderConfig;
import game.Game;

// the 3D "canvas": a pool of reused sprite quads + an atlas-crop texture cache. one paint
// surface shared by the actor layer and every Particle3D. a frame is begin() -> many paint()
// -> end(); paint() consumes the next pooled quad, end() hides the leftover tail. mirrors the
// role the 2D CanvasRenderingContext2D plays for particles.Particle
class Sprites {
  public static inline var SIZE = CityConfig.CELL * 0.75; // base quad size (scale multiplies it)
  public static inline var TILT = 0.6;                 // radians an upright sprite leans back toward the overhead camera
  // transparent draw layering (higher = on top): ground decals < fake shadow < target markers <
  // upright actor icon. all these share this pool + depthWrite:false, so renderOrder (not Y) fixes
  // their stacking deterministically at any camera angle
  public static inline var ORD_DECAL = 0;              // blood/debris/flat ground-decal objects
  public static inline var ORD_SHADOW = 1;             // fake cast shadow (above decals -> darkens them)
  public static inline var ORD_MARK = 2;               // targeting frame / reticle (above the shadow)
  public static inline var ORD_ACTOR = 3;              // upright actor billboard (above its own shadow)

  var game:Game;                                        // for the sprite-atlas image provider
  var actorGroup:Group;                                 // scene group holding all sprite quads
  var pool:Array<Mesh> = [];                            // reused quad meshes
  var texCache:Map<String, CanvasTexture> = new Map();  // atlas-crop / svg -> texture
  var svgImgs:Map<String, Dynamic> = new Map();         // svg cache key -> decoding <img> (async)
  var contentCache:Map<String, GroundSprite> = new Map(); // atlas-crop -> content-trimmed sprite
  var shadowCache:Map<String, GroundSprite> = new Map();  // atlas-crop -> black soft-edged silhouette
  var idx:Int = 0;                                      // next free pool slot this frame
  // scratch reused by paintShadow so a shadow pass allocates nothing
  var _sa:Vector3 = new Vector3();
  var _sb:Vector3 = new Vector3();
  var _sc:Vector3 = new Vector3();
  var _smtx:Matrix4 = new Matrix4();
  // scratch reused by paintTopple (death topple) so it allocates nothing per frame
  var _te:Euler = new Euler();
  var _tq:Quaternion = new Quaternion();
  var _yAxis:Vector3 = new Vector3(0, 1, 0);

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

// place/reuse a sprite quad (see PaintOpts); flat lays it on the ground as a decal (yaw rotates
// it there). no-op if the atlas isn't decoded yet (tex == null) — the slot is not consumed
  public function paint(o:PaintOpts):Void
    {
      if (o.tex == null) return;
      var m = slot(o.tex, o.op, o.x, o.y, o.z, o.scale);
      var yaw = (o.yaw != null ? o.yaw : 0.0);
      // horizontal facing (side-view actor turning): scale x by faceX in [-1..1], squashing through
      // 0 for the turn. mirrors the mesh, not the shared cached texture
      if (o.faceX != null &&
          o.faceX != 1.0)
        m.scale.x = o.scale * o.faceX;
      // decal: lie flat on the ground (normal up). else face the front (fixed yaw, no camera
      // tracking) leaned back toward the overhead camera by TILT so it reads flatter
      if (o.flat)
        m.rotation.set(-Math.PI / 2, 0, yaw);
      else
        m.rotation.set(-TILT, 0, yaw); // yaw doubles as in-plane roll for upright sprites (badge wiggle)
      m.renderOrder = (o.order != null ? o.order : 0);
      // warm self-glow (flame flickering on a nearby actor): emissiveMap = the sprite, so the glow
      // is shaped by the sprite and flickers with emissiveInt. default 0 = no glow (unchanged path)
      var mat:Dynamic = m.material;
      untyped mat.emissive.setHex(o.emissive != null ? o.emissive : 0);
      mat.emissiveIntensity = (o.emissiveInt != null ? o.emissiveInt : 0.0);
      // wet sheen: rough < 1 lets this quad catch a soft specular highlight off the scene lights
      // (moon/lamp/flame) instead of full-matte. blood splats use it; everything else stays 1.
      // metal > 0 tints that glint by the (dark red) albedo for a stronger, wetter sheen
      mat.roughness = (o.rough != null ? o.rough : 1.0);
      mat.metalness = (o.metal != null ? o.metal : 0.0);
      // depthTest off = always-on-top UI (entity badges): never occluded by walls in front.
      // depthFunc (when set) flips the compare — GreaterDepth draws only where occluded (x-ray)
      untyped mat.depthTest = (o.depthTest != false);
      if (o.depthFunc != null)
        untyped mat.depthFunc = o.depthFunc;
      m.visible = true;
      idx++;
    }

// paint a content-cropped ground sprite (from texContent) flat on the ground, sized to its real
// pixel footprint (fw/fh of a cell) * scale and centered on the point, yaw-rotated in-plane. used
// for debris so a small off-centre atlas sprite lands at its true size where we place it
  public function paintGround(o:PaintGroundOpts):Void
    {
      if (o.gs == null || o.gs.tex == null) return;
      var m = slot(o.gs.tex, o.op, o.x, o.y, o.z, o.scale);
      // geometry is SIZE x SIZE; scale each ground axis by the content fraction so the quad
      // matches the trimmed sprite's true aspect + size
      m.scale.set(o.gs.fw * o.scale, o.gs.fh * o.scale, 1);
      m.rotation.set(-Math.PI / 2, 0, o.yaw);
      m.renderOrder = (o.order != null ? o.order : 0);
      m.visible = true;
      idx++;
    }

// place a toppling actor sprite for the death animation: from the live upright rest pose (fall 0)
// to flat on the ground (fall 1), spun about the vertical by spinY radians. pivots at the planted
// feet (topples over, doesn't slide) — head falls away from the camera so it lands face-up
  public function paintTopple(o:PaintToppleOpts):Void
    {
      if (o.tex == null) return;
      // gravity-ish ease-in; vertical (no camera lean) through the spin so it doesn't wobble,
      // then tips flat over the fall
      var e = o.fall * o.fall;
      var half = SIZE * 0.5 * o.scale;
      var tip = -(Math.PI / 2) * e;                 // tip about local X: 0 upright -> -PI/2 flat
      // the FEET stay planted (o.x,o.z) and the center rides the tip arc — a true topple, not a
      // slide. head (local +Y) swings to -Z (away from camera), so it lands face-up, feet anchored
      var cy = o.y + half * Math.cos(tip) + 0.05 * e;
      var cz = o.z + half * Math.sin(tip);
      var m = slot(o.tex, o.op, o.x, cy, cz, o.scale);
      // quaternion = spin * tip: the local X-tip applies first, then the world-vertical spin
      _te.set(tip, 0, 0);
      _tq.setFromEuler(_te);
      m.quaternion.setFromAxisAngle(_yAxis, o.spinY);
      m.quaternion.multiply(_tq);
      m.renderOrder = ORD_ACTOR;
      m.visible = true;
      idx++;
    }

// paint a fake cast shadow: a flat black silhouette (from shadowContent) rooted at the feet
// (feetX,feetZ) on the ground and stretched len along (dirX,dirZ) — the direction away from
// the light — wid across. no shadow map; just an oriented, darkened, alpha-shaped copy of the
// sprite laid on the road (dir is the away-from-barrel unit vector; len/wid are world units)
  public function paintShadow(o:PaintShadowOpts):Void
    {
      if (o.gs == null || o.gs.tex == null) return;
      // rooted at the feet: centre sits half the length out along the away direction
      var cx = o.feetX + o.dirX * o.len * 0.5;
      var cz = o.feetZ + o.dirZ * o.len * 0.5;
      var m = slot(o.gs.tex, o.op, cx, o.floorY, cz, 1.0);
      // basis: sprite local +Y (image up / head) -> length dir (so the silhouette lies head-away,
      // feet-near), local +X (image width) -> perpendicular, local +Z (normal) -> world up
      // right-handed basis (det +1) so setFromRotationMatrix stays a proper rotation and the quad
      // lies FLAT: local +Y -> length dir, local +X -> width (mirrored, harmless), local +Z -> up
      _sa.set(-o.dirZ, 0, o.dirX);
      _sb.set(o.dirX, 0, o.dirZ);
      _sc.set(0, 1, 0);
      untyped _smtx.makeBasis(_sa, _sb, _sc);
      untyped m.quaternion.setFromRotationMatrix(_smtx);
      // geometry is SIZE square; scale each axis so the quad spans the world width/length
      m.scale.set(o.wid / SIZE, o.len / SIZE, 1);
      m.renderOrder = (o.order != null ? o.order : 0);
      m.visible = true;
      idx++;
    }

// place/reuse a quad standing on a wall face: its normal points outward along faceRotY (see
// Geom.faceRotY), spun in-plane by roll. same pool as paint(); used for bullet-hole decals
  public function paintWall(o:PaintWallOpts):Void
    {
      if (o.tex == null) return;
      var m = slot(o.tex, o.op, o.x, o.y, o.z, o.scale);
      // roll about the plane's own normal (local Z), then yaw to face the wall dir (Y). default
      // Euler XYZ applies Z before Y, so the roll stays about the reoriented outward normal
      m.rotation.set(0, o.faceRotY, o.roll);
      // wet sheen for wall blood (rough < 1); bullet holes pass neither and stay matte via slot()'s reset
      var mat:Dynamic = m.material;
      mat.roughness = (o.rough != null ? o.rough : 1.0);
      mat.metalness = (o.metal != null ? o.metal : 0.0);
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
              // emissiveMap present from creation so the define is stable (no recompile when an
              // actor later flickers a warm emissive glow onto its own sprite — see paint())
              map: tex,
              emissiveMap: tex,
            }));
          pool[idx] = m;
          actorGroup.add(m);
        }
      var mat:Dynamic = m.material;
      // swap the crop texture + reset per-frame state. NO material.needsUpdate: the material is
      // created once with map+emissiveMap present (stable defines), so swapping to another cached
      // texture only rebinds a uniform — forcing a version bump every quad every frame made three.js
      // re-derive the program each frame for nothing. (texture upload is driven by texture.version)
      mat.map = tex;
      mat.opacity = op;
      // reset per-frame overridables to their defaults; specialized paints re-set as needed. keeps
      // pool reuse from leaking one call's emissive/renderOrder into the next slot user
      untyped mat.emissiveMap = tex;
      untyped mat.emissive.setHex(0);
      mat.emissiveIntensity = 0;
      untyped mat.depthTest = true;
      untyped mat.depthFunc = THREE.LessEqualDepth;
      mat.roughness = 1;
      mat.metalness = 0;
      m.renderOrder = 0;
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

// rasterize a fully-colored inline SVG string to a cached CanvasTexture at px edge; null until the
// SVG <img> decodes (retry next frame, like tex()). key uniquely ids the svg markup + px. lets
// entity badges scale crisply (SVG source) instead of baking to a fixed atlas cell
  public function svgTex(key:String, svg:String, px:Int):CanvasTexture
    {
      if (texCache.exists(key)) return texCache.get(key);
      var img:Dynamic = svgImgs.get(key);
      if (img == null)
        {
          img = Browser.document.createElement('img');
          img.src = 'data:image/svg+xml;charset=utf-8,' + StringTools.urlEncode(svg);
          svgImgs.set(key, img);
        }
      // retry next frame until the async decode completes
      if (!img.complete ||
          img.naturalWidth <= 0)
        return null;
      var cv:Dynamic = Browser.document.createElement('canvas');
      cv.width = px; cv.height = px;
      var cx = cv.getContext('2d');
      cx.drawImage(img, 0, 0, px, px);
      var tex = new CanvasTexture(cv);
      tex.colorSpace = THREE.SRGBColorSpace;
      texCache.set(key, tex);
      return tex;
    }

// solid-white silhouette of an atlas cell (sprite alpha kept, RGB forced white) → cached
// CanvasTexture. tinted at paint time (emissive) into a flat colored silhouette for the AI
// through-wall x-ray outline. null until the atlas image decodes (retry next frame, like tex())
  public function silTex(imageName:String, ix:Int, iy:Int, male:Bool, fill:String, spacing:Int, thick:Int):CanvasTexture
    {
      var key = 'sil:' + imageName + ':' + ix + ':' + iy + ':' + male + ':' + fill + ':' + spacing + ':' + thick;
      if (texCache.exists(key)) return texCache.get(key);
      var img:Dynamic = game.scene.images.getImage(imageName, male);
      if (img == null ||
          !img.complete ||
          img.naturalWidth <= 0)
        return null;
      var t = Const.TILE_SIZE_CLEAN;
      var cv:Dynamic = Browser.document.createElement('canvas');
      cv.width = t; cv.height = t;
      var cx = cv.getContext('2d');
      // same crop as tex() (the +1/-1 kludge avoids atlas bleed), then whiten + carve the pattern
      cx.drawImage(img, ix * t, iy * t + 1, t, t - 1, 0, 0, t, t);
      patternWhiten(cx, t, t, fill, spacing, thick);
      var tex = new CanvasTexture(cv);
      tex.colorSpace = THREE.SRGBColorSpace;
      texCache.set(key, tex);
      return tex;
    }

// force every pixel's RGB to white (a tintable mask; the soft alpha edge stays anti-aliased) and
// carve an interior pattern into the sprite's alpha — 'solid' keeps the whole shape, 'diag'/'cross'
// hatch lines, 'scan' horizontal lines, 'dots' stipple. pattern lives in texture space (rides the
// billboard). spacing = line period, thick = line width, both in crop px
  inline function patternWhiten(ctx:Dynamic, w:Int, h:Int, fill:String, spacing:Int, thick:Int):Void
    {
      var id = ctx.getImageData(0, 0, w, h);
      var d = id.data;
      for (y in 0...h)
        for (x in 0...w)
          {
            var i = (y * w + x) << 2;
            d[i] = 255;
            d[i + 1] = 255;
            d[i + 2] = 255;
            if (d[i + 3] == 0) // outside the sprite already — nothing to carve
              continue;
            var on = switch (fill)
              {
                case 'diag': (x + y) % spacing < thick;
                case 'cross': (x + y) % spacing < thick ||
                              ((x - y) % spacing + spacing) % spacing < thick;
                case 'scan': y % spacing < thick;
                case 'dots': x % spacing < thick &&
                             y % spacing < thick;
                default: true; // solid
              }
            if (!on)
              d[i + 3] = 0;
          }
      ctx.putImageData(id, 0, 0);
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
      // bottom margin: empty cell rows below the content (py grows downward, so t-1-maxY),
      // as a cell fraction — lets an upright sprite drop its content bottom onto the ground
      var gs:GroundSprite = { tex: tex, fw: cw / t, fh: ch / t, by: (t - 1 - maxY) / t };
      contentCache.set(key, gs);
      return gs;
    }

// build a black, soft-edged silhouette of an atlas cell for a fake cast shadow. reuses texContent
// with mul=0 (black RGB, sprite alpha kept), then blurs that tight crop into a padded canvas so the
// edge is soft (shadowSoftPx). cached per cell; null until the atlas image decodes
  public function shadowContent(imageName:String, ix:Int, iy:Int, male:Bool):GroundSprite
    {
      var key = imageName + ':' + ix + ':' + iy + ':' + male;
      if (shadowCache.exists(key)) return shadowCache.get(key);
      // black tight silhouette (mul=0 -> RGB 0, alpha preserved)
      var base = texContent(imageName, ix, iy, male, 0.0);
      if (base == null)
        return null;
      var tx:Dynamic = base.tex;
      var src:Dynamic = tx.image;                        // the tight crop canvas (cw x ch)
      var pad = RenderConfig.FLAME.shadowSoftPx * 2;      // blur bleeds beyond the edge -> pad so it isn't clipped
      var bc:Dynamic = Browser.document.createElement('canvas');
      bc.width = src.width + pad * 2;
      bc.height = src.height + pad * 2;
      var bcx = bc.getContext('2d');
      bcx.filter = 'blur(' + RenderConfig.FLAME.shadowSoftPx + 'px)';
      bcx.drawImage(src, pad, pad);
      var tex = new CanvasTexture(bc);
      tex.colorSpace = THREE.SRGBColorSpace;
      var t = Const.TILE_SIZE_CLEAN;
      var gs:GroundSprite = { tex: tex, fw: bc.width / t, fh: bc.height / t, by: 0.0 };
      shadowCache.set(key, gs);
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
