package render;

import three.Three;
import js.Browser;
import js.html.CanvasElement;

// texture loaders. If a file is missing, swap in a procedurally drawn canvas so
// the prototype still renders. Cropped / chroma-keyed variants build a canvas off
// the source image. Gradient canvases drive the fake roof contact shadows
class Textures {
  static var loader = new TextureLoader();

  public static function loadTexture(path:String, kind:String, repeat:Float = 1):Texture {
    var tex:Texture = null;
    var undef = js.Lib.undefined; // three checks `onLoad !== undefined`, so null would be called
    tex = loader.load(path, undef, undef, function(_) {
      Browser.console.warn('[textures] "$path" missing — using procedural fallback for $kind');
      tex.image = proceduralCanvas(kind);
      tex.needsUpdate = true;
    });
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
    tex.repeat.set(repeat, repeat);
    tex.anisotropy = 4;
    return tex;
  }

  // load a facade cell but crop its center before tiling — trims the wall margin
  public static function loadCroppedTexture(path:String, cropX:Float, cropY:Float = 1):Texture {
    var tex = new Texture();
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
    tex.anisotropy = 4;
    var img = new js.html.Image();
    img.onload = function(_) {
      var cw = Math.round(img.width * cropX);
      var ch = Math.round(img.height * cropY);
      var ox = Math.round((img.width - cw) / 2);
      var oy = Math.round((img.height - ch) / 2);
      var cv = Browser.document.createCanvasElement();
      cv.width = cw; cv.height = ch;
      cv.getContext2d().drawImage(img, ox, oy, cw, ch, 0, 0, cw, ch);
      tex.image = cv;
      tex.needsUpdate = true;
    };
    img.onerror = function(_) { tex.image = proceduralCanvas('facade'); tex.needsUpdate = true; };
    img.src = path;
    return tex;
  }

  // crop a detail sprite to its center, then chroma-key the flat bg color to
  // transparent (gpt can't emit alpha) so only the object shows over the roof
  public static function loadKeyedTexture(path:String, crop:Float, keyColor:Int, tol:Int = 24):Texture {
    var tex = new Texture();
    tex.colorSpace = THREE.SRGBColorSpace;
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
      tex.image = cv;
      tex.needsUpdate = true;
    };
    img.onerror = function(_) { tex.image = proceduralCanvas('facade'); tex.needsUpdate = true; };
    img.src = path;
    return tex;
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
  public static function makeRectGlowGradient():Texture {
    var N = 64;
    var rad = N * 0.16;   // corner radius, canvas px
    var half = N * 0.30;  // half-extent of the box's straight section from the centre
    var soft = N * 0.16;  // how far the edge fades out past the box
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
          var v = Std.int(255 * (1 - t * t * (3 - 2 * t)));
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
