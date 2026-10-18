package render;

import three.Three;
import js.Browser;
import js.html.CanvasElement;

// texture loaders. If a file is missing, swap in a procedurally drawn canvas so
// the prototype still renders. Cropped / chroma-keyed variants build a canvas off
// the source image. Gradient canvases drive the fake roof contact shadows.
//
// every loader here stamps `name` with the path it loaded, which is the only place that survives:
// a keyed or cropped variant hands three.js a CANVAS, so `image.src` is gone and the material has
// no idea what art it is wearing. render.PolyProbe prints it under the texture view — clicking a
// surface and being told which file to go and repaint is the whole point of that tool
class Textures {
  // the persistent renderer, once render.View has made it: a loaded map is uploaded the moment its
  // image lands rather than on the first frame something draws with it (a fresh tour used to pay 71
  // uploads, 3-15 ms each, on the frames the player first looked at a room)
  public static var renderer:WebGLRenderer;
  // ONE private master per loader + path (+ crop/key params): the decoded image every Texture a
  // loader hands out for it shares, and with it one GPU upload per wrap/colour-space set (three keys
  // its GL textures on source + params). never handed out itself, since callers change wrap, colour
  // space and offset on what they get. measured at boot: 316 uploads, 106 Mpx (roof-base.png alone
  // 9 times), a real build then loaded its own copies again, and every rebuild leaked them
  // (render.View.disposeScene leaves textures alone)
  static var masters:Map<String, Texture> = new Map();
  // copies handed out before their image landed, keyed by the shared source. a native Map: haxe's
  // ObjectMap would write an __id__ field onto three's Source objects
  static var waiting:js.lib.Map<TextureSource, Array<Texture>> = new js.lib.Map();
  // copies of an image that has already landed, uploaded together from one microtask
  static var fresh:Array<Texture> = [];

// a Texture of its own (wrap, repeat and offset are the caller's to change) over the one shared
// image for `path`. `kind` only shapes the procedural stand-in for a missing file
  public static function loadTexture(path:String, kind:String, repeat:Float = 1):Texture {
    var tex = share(image('t|' + path, path, kind, false));
    tex.repeat.set(repeat, repeat);
    return tex;
  }

// loadTexture with alpha premultiplied on upload, for hand-painted alpha whose junk RGB under
// near-transparent texels otherwise bleeds in as specks once minified. a master of its own:
// premultiplyAlpha is part of three's GPU cache key, so flipping it on a shared copy re-uploads
  public static function loadPremultiplied(path:String, kind:String):Texture {
    return share(image('pm|' + path, path, kind, true));
  }

// the master for a plain image load, created and started once per key
  static function image(key:String, path:String, kind:String, premultiply:Bool):Texture {
    var m = masters.get(key);
    if (m != null)
      return m;
    m = master(key, path);
    m.wrapS = m.wrapT = THREE.RepeatWrapping;
    m.anisotropy = 4;
    m.premultiplyAlpha = premultiply;
    var img = new js.html.Image();
    img.onload = function(_) landed(m, img);
    img.onerror = function(_)
      {
        Browser.console.warn('[textures] "$path" missing — using procedural fallback for $kind');
        landed(m, proceduralCanvas(kind));
      };
    // what three's ImageLoader set on the image TextureLoader used to make
    img.crossOrigin = 'anonymous';
    img.src = path;
    return m;
  }

// a new master under `key`, stamped with the colour space and name every loader gives its art,
// and an empty waiting list for its source
  static function master(key:String, path:String):Texture {
    var m = new Texture();
    m.colorSpace = THREE.SRGBColorSpace;
    m.name = path;
    masters.set(key, m);
    waiting.set(m.source, []);
    return m;
  }

// the image (or its stand-in) is in: every copy waiting on it becomes uploadable at once, without
// bumping the shared source again, and goes up now — their callers finished setting wrap and colour
// space long ago, in the task that asked for them. the master itself is never uploaded: no draw
// samples it, and its own wrap set was a second upload of doors and grime that nothing used
  static function landed(m:Texture, image:Dynamic):Void { // Dynamic: an <img> or a canvas, whatever three's untyped Texture.image takes
    m.image = image;
    m.needsUpdate = true;
    var list = waiting.get(m.source);
    waiting.delete(m.source);
    for (c in list)
      c.version++;
    if (renderer == null)
      return;
    for (c in list)
      renderer.initTexture(c);
  }

// a Texture of its own over t's image: own wrap/repeat/offset, same decode and GPU upload. three's
// clone() bumps the SHARED source.version, which re-uploads (and re-decodes an <img>) on the next
// bind, so that version is put back. a copy of an image still in flight waits for landed(); one of
// a landed image is uploaded from a microtask, after its caller's synchronous setup — never here,
// since three reads wrap and colour space only at upload
  public static function share(t:Texture):Texture {
    var v = t.source.version;
    var c = t.clone();
    c.source.version = v;
    var list = waiting.get(c.source);
    if (list != null)
      {
        c.version = 0;
        list.push(c);
        return c;
      }
    if (renderer == null)
      return c;
    if (fresh.length == 0)
      js.lib.Promise.resolve(null).then(function(_) flush());
    fresh.push(c);
    return c;
  }

// upload the copies share() handed out over landed images
  static function flush():Void {
    var list = fresh;
    fresh = [];
    for (c in list)
      renderer.initTexture(c);
  }

  // load a facade cell but crop its center before tiling — trims the wall margin
  public static function loadCroppedTexture(path:String, cropX:Float, cropY:Float = 1):Texture {
    var key = 'crop|$path|$cropX|$cropY';
    var m = masters.get(key);
    if (m == null)
      {
        m = master(key, path);
        m.wrapS = m.wrapT = THREE.RepeatWrapping;
        m.anisotropy = 4;
        var img = new js.html.Image();
        img.onload = function(_) {
          var cw = Math.round(img.width * cropX);
          var ch = Math.round(img.height * cropY);
          var ox = Math.round((img.width - cw) / 2);
          var oy = Math.round((img.height - ch) / 2);
          var cv = Browser.document.createCanvasElement();
          cv.width = cw;
          cv.height = ch;
          cv.getContext2d().drawImage(img, ox, oy, cw, ch, 0, 0, cw, ch);
          landed(m, cv);
        };
        img.onerror = function(_) landed(m, proceduralCanvas('facade'));
        img.src = path;
      }
    return share(m);
  }

  // load a sprite and crop it to its own ALPHA bounding box, so a quad mapping 0..1 covers exactly
  // the opaque art. loadCroppedTexture's centred fractions cannot do this job: they are fitted by
  // hand and go stale the moment the source is re-cut, and a centred rect cannot express a bbox
  // that is off-centre at all — the lit window's sits 9px high of its image, which shaved the top
  // rail off the frame and left an empty strip under the glass for alphaTest to discard
  public static function loadAlphaCropped(path:String):Texture {
    var key = 'alpha|$path';
    var m = masters.get(key);
    if (m != null)
      return share(m);
    m = master(key, path);
    m.wrapS = m.wrapT = THREE.ClampToEdgeWrapping;
    m.anisotropy = 4;
    var img = new js.html.Image();
    img.onload = function(_) {
      var cv = Browser.document.createCanvasElement();
      cv.width = img.width;
      cv.height = img.height;
      var ctx = cv.getContext2d();
      ctx.drawImage(img, 0, 0);
      var d = ctx.getImageData(0, 0, img.width, img.height).data;
      var x0 = img.width, y0 = img.height, x1 = -1, y1 = -1;
      for (y in 0...img.height)
        for (x in 0...img.width) {
          if (d[(y * img.width + x) * 4 + 3] <= 8)
            continue;
          if (x < x0)
            x0 = x;
          if (x > x1)
            x1 = x;
          if (y < y0)
            y0 = y;
          if (y > y1)
            y1 = y;
        }
      // an opaque source, or one whose cut took everything: the whole image is the crop
      if (x1 < x0) {
        x0 = 0;
        y0 = 0;
        x1 = img.width - 1;
        y1 = img.height - 1;
      }
      var out = Browser.document.createCanvasElement();
      out.width = x1 - x0 + 1;
      out.height = y1 - y0 + 1;
      out.getContext2d().drawImage(cv, x0, y0, out.width, out.height, 0, 0, out.width, out.height);
      landed(m, out);
    };
    img.onerror = function(_) landed(m, proceduralCanvas('facade'));
    img.src = path;
    return share(m);
  }

  // crop a detail sprite to its center, then chroma-key the flat bg color to
  // transparent (gpt can't emit alpha) so only the object shows over the roof
  public static function loadKeyedTexture(path:String, crop:Float, keyColor:Int, tol:Int = 24):Texture {
    var key = 'key|$path|$crop|$keyColor|$tol';
    var m = masters.get(key);
    if (m != null)
      return share(m);
    m = master(key, path);
    var kr = (keyColor >> 16) & 255;
    var kg = (keyColor >> 8) & 255;
    var kb = keyColor & 255;
    var img = new js.html.Image();
    img.onload = function(_) {
      var cw = Math.round(img.width * crop);
      var ch = Math.round(img.height * crop);
      var ox = Math.round((img.width - cw) / 2);
      var oy = Math.round((img.height - ch) / 2);
      var cv = Browser.document.createCanvasElement();
      cv.width = cw; cv.height = ch;
      var ctx = cv.getContext2d();
      ctx.drawImage(img, ox, oy, cw, ch, 0, 0, cw, ch);
      var d = ctx.getImageData(0, 0, cw, ch);
      var p = d.data;
      var i = 0;
      while (i < p.length) {
        if (Math.abs(p[i] - kr) < tol && Math.abs(p[i + 1] - kg) < tol && Math.abs(p[i + 2] - kb) < tol) p[i + 3] = 0;
        i += 4;
      }
      ctx.putImageData(d, 0, 0);
      landed(m, cv);
    };
    img.onerror = function(_) landed(m, proceduralCanvas('facade'));
    img.src = path;
    return share(m);
  }

  // NO loadRampTexture. it baked a vertical alpha ramp (opaque at the bottom, transparent toward
  // the top) into an opaque tile, and drove both grime bands until each moved to hand-painted alpha
  // in the source. one alpha per image ROW is what made a band read as a gradient wash with no
  // shape of its own — see render.sewer.SewerDetail.grime

  // alpha-gradient strip: opaque (white) at v=0 (parapet edge), transparent at v=1
  public static function makeShadowGradient():Texture {
    var cv = Browser.document.createCanvasElement();
    cv.width = 4; cv.height = 64;
    var ctx = cv.getContext2d();
    var g = ctx.createLinearGradient(0, 0, 0, 64);
    g.addColorStop(0.0, '#000000');
    g.addColorStop(0.55, '#3a3a3a');
    g.addColorStop(1.0, '#ffffff');
    ctx.fillStyle = cast g;
    ctx.fillRect(0, 0, 4, 64);
    var tex = new CanvasTexture(cv);
    tex.colorSpace = THREE.NoColorSpace;
    return tex;
  }

  // radial version for roof corners: opaque at uv(1,0), fading out in a quarter disc
  public static function makeRadialShadowGradient():Texture {
    var N = 64;
    var cv = Browser.document.createCanvasElement();
    cv.width = N; cv.height = N;
    var ctx = cv.getContext2d();
    var g = ctx.createRadialGradient(N, N, 0, N, N, N);
    g.addColorStop(0.0, '#ffffff');
    g.addColorStop(0.5, '#7a7a7a');
    g.addColorStop(1.0, '#000000');
    ctx.fillStyle = cast g;
    ctx.fillRect(0, 0, N, N);
    var tex = new CanvasTexture(cv);
    tex.colorSpace = THREE.NoColorSpace;
    return tex;
  }

  // SMOOTH-RECTANGULAR falloff: a rounded box, opaque in the middle and easing to nothing before the
  // quad's rim. this is makeGlowGradient's twin for a fixture that should read as a BOX behind a
  // diffuser rather than a bare bulb.
  //
  // NOTE the round one never drew an oval: it is a CIRCULAR gradient on a square canvas, and the
  // ellipse comes from UV-mapping that square onto a non-square quad (the sewer glow is 0.75 x 0.5).
  // The same stretch applies here and is wanted — a rounded box stretched is still a rounded box.
  //
  // written per-texel from a rounded-box distance field rather than drawn with a canvas blur: the
  // corner radius and the edge softness are then exact numbers instead of a filter's guess
  //
  // `radFrac` is the corner radius as a fraction of the canvas. the default 0.16 against a half-extent
  // of 0.30 leaves only 0.14 of straight run, which is a squircle and reads as a blob — right for a
  // wall fixture's diffuser, wrong for the patch of ground outside a window, which has the straight
  // edges of the opening that cut it. pass 0 for a box with square corners; the falloff still curves
  // round them, which is what a soft edge does
  //
  // `halfFrac` and `softFrac` are the shape's other two numbers, defaulted to what every glow here
  // was drawn with. They are arguments and not literals because one caller SIZES ITS QUAD off them:
  // render.facility.FacilityDetail.halo scales an object by 1 / (2 * halfFrac) so the opaque core
  // lands exactly on the object, and mirroring 0.30 over there would be a silent coupling across two
  // files that a retune here would break without a compile error
  //
  // `peak` scales the whole field down, and it is here because an alphaMap is the ONLY place some
  // callers can put their weight: render.facility.FacilityRoof's contact shadows ride the fading
  // deck, and FacilityArea.apply SETS material.opacity off the deck's own ease every frame, so a
  // weight left on the material is overwritten the first time the player walks toward the building
  public static function makeRectGlowGradient(radFrac:Float = 0.16, halfFrac:Float = 0.30,
      softFrac:Float = 0.16, peak:Float = 1.0):Texture {
    var N = 64;
    var rad = N * radFrac; // corner radius, canvas px
    var half = N * halfFrac;  // half-extent of the box's straight section from the centre
    var soft = N * softFrac;  // how far the edge fades out past the box
    var cv = Browser.document.createCanvasElement();
    cv.width = N; cv.height = N;
    var ctx = cv.getContext2d();
    var img = ctx.createImageData(N, N);
    for (y in 0...N)
      for (x in 0...N)
        {
          // distance to the rounded box, negative inside (the standard 2D rounded-box SDF)
          var qx = Math.abs(x + 0.5 - N / 2) - (half - rad);
          var qy = Math.abs(y + 0.5 - N / 2) - (half - rad);
          var mx = qx > 0 ? qx : 0.0;
          var my = qy > 0 ? qy : 0.0;
          var out = Math.sqrt(mx * mx + my * my) + Math.min(Math.max(qx, qy), 0.0) - rad;
          // smoothstep the band [0, soft] outward, so the falloff has no visible shoulder
          var t = out <= 0 ? 0.0 : (out >= soft ? 1.0 : out / soft);
          var v = Std.int(255 * peak * (1 - t * t * (3 - 2 * t)));
          var i = (y * N + x) * 4;
          img.data[i] = v;
          img.data[i + 1] = v;
          img.data[i + 2] = v;
          img.data[i + 3] = 255;
        }
    ctx.putImageData(img, 0, 0);
    var tex = new CanvasTexture(cv);
    tex.colorSpace = THREE.NoColorSpace;
    return tex;
  }

  // CENTRED radial falloff: opaque at uv(0.5,0.5), transparent at the quad's rim. the two above are
  // both anchored at an edge (a parapet strip, a roof corner); this one is the shape of a glow, and
  // it is what keeps a light-fixture quad from reading as a hard-edged sticker on the wall
  public static function makeGlowGradient():Texture {
    var N = 64;
    var cv = Browser.document.createCanvasElement();
    cv.width = N; cv.height = N;
    var ctx = cv.getContext2d();
    var g = ctx.createRadialGradient(N / 2, N / 2, 0, N / 2, N / 2, N / 2);
    g.addColorStop(0.0, '#ffffff');
    g.addColorStop(0.35, '#c8c8c8');
    g.addColorStop(1.0, '#000000');
    ctx.fillStyle = cast g;
    ctx.fillRect(0, 0, N, N);
    var tex = new CanvasTexture(cv);
    tex.colorSpace = THREE.NoColorSpace;
    return tex;
  }

  static function proceduralCanvas(kind:String):CanvasElement {
    var size = 256;
    var c = Browser.document.createCanvasElement();
    c.width = c.height = size;
    var ctx = c.getContext2d();
    if (kind == 'asphalt') {
      ctx.fillStyle = '#16181d';
      ctx.fillRect(0, 0, size, size);
      for (_ in 0...2000) {
        var v = 18 + Math.floor(Math.random() * 18);
        ctx.fillStyle = 'rgb(${v},${v + 2},${v + 4})';
        ctx.fillRect(Math.random() * size, Math.random() * size, 1, 1);
      }
    } else if (kind == 'roof') {
      ctx.fillStyle = '#2a2c30';
      ctx.fillRect(0, 0, size, size);
      ctx.strokeStyle = '#1c1e22';
      ctx.lineWidth = 2;
      ctx.strokeRect(6, 6, size - 12, size - 12);
      ctx.fillStyle = '#3a3d42';
      for (i in 0...5) {
        var w = 30 + Math.random() * 50;
        var h = 30 + Math.random() * 50;
        ctx.fillRect(Math.random() * (size - w), Math.random() * (size - h), w, h);
      }
    } else {
      ctx.fillStyle = '#23252b';
      ctx.fillRect(0, 0, size, size);
      var cols = 6, rows = 6;
      var pad = size / cols;
      for (r in 0...rows) {
        for (col in 0...cols) {
          var lit = Math.random() < 0.18;
          ctx.fillStyle = lit ? '#5a4a26' : '#15161a';
          ctx.fillRect(col * pad + pad * 0.25, r * pad + pad * 0.25, pad * 0.5, pad * 0.5);
        }
      }
    }
    return c;
  }
}
