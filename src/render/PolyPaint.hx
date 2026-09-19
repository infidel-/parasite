package render;

import three.Three;
import js.Browser;
import haxe.Json;
import render.world.ObjModels;
import render.world.ObjModels.ObjModel;

// in-game emissive-map PAINTER (debug key T, inside street-debug mode). A prop's emissive map is a
// MARKER and not art: render.world.PropGlow's `lamps` column matches flat tints back by normalised
// hue, so all the map encodes is WHICH TEXELS belong to which lamp family.
//
// THE UNIT IS A TEXEL. It used to be a triangle, because tools/emissive.py defines a map as a
// triangle set and an index list fed that bake exactly — but propstat reads 41 texels per triangle
// at 2048, so a triangle is about six texels across and painting whole ones made every lamp a
// faceted blob. Worse, the bake's own bleed guard (`kept = lit & ~grow(other,1)`) ate more of a
// 100k-triangle mesh than it kept, and the --near exemption bought that back by lighting every
// triangle that merely TOUCHED the selection. Both of those problems are properties of the unit.
//
// The brush is still stated in WORLD units and is still a sphere; what changed is how it resolves.
// For every triangle the sphere reaches, its UV triangle is rasterised and each covered texel is
// back-projected to a local position by barycentric interpolation and tested against the sphere.
// A disc painted in UV space around the hit's uv would be wrong here — a TRELLIS atlas is a
// shattered mosaic, so a UV disc spills into unrelated charts, which is the original bug wearing a
// new hat. Going through the geometry costs nothing at a chart seam and is correct across it.
//
// WHAT IS DRAWN IS WHAT SHIPS. tools/models.mjs embeds `emissiveSrc` verbatim (readFileSync ->
// setImage, no resize), so the PNG this writes is the PNG the glb carries. SAVE grows the painted
// mask two texels into the GUTTER ONLY — texels no triangle covers — which makes foreign bleed
// zero by construction instead of by a guard, and never removes a texel that was painted. It then
// hands the file to host.debug.writeImage, the channel map.Image.dumpDebugViewPNGs already uses,
// so this adds no IPC: the map lands in <userData>/debug/ for the source tree to pick up.
class PolyPaint {
  static inline var LS_KEY = 'emispaint'; // localStorage: { "<glb path>": { res, tris, png } }
  static inline var HUE_TOL = 0.25;       // normalised-hue match when snapping a map to the palette
  static inline var LIT = 8;              // a texel under this on every channel belongs to no family
  static inline var GUT = 0.5;            // texels a UV triangle is grown by when rasterising, so a
                                          // chart thinner than a texel still covers one
  static inline var DILATE = 2;           // texels the export pushes into the gutter. emissive.py's
                                          // own default, and bilinear reads a 2x2 neighbourhood
  static inline var UNDO = 20;            // strokes kept

  public static function attach(getScene:Void->Scene, camera:PerspectiveCamera, dom:Dynamic):Void {
    var ray = new Raycaster();
    var ndc = new Vector2();

    // the bound prop. everything here is null/0 until a hover picks one
    var obj:Object3D = null;
    var row:ObjModel = null;
    var tex:Dynamic = null;
    var res = 0;
    var tris = 0;
    var flipY = false;
    var scl = 1.0;                         // world units per local unit (Models scales uniformly)
    var mw = new Matrix4();                // mesh world x this instance's matrix
    var mwInv = new Matrix4();             // and its inverse: world -> the glb's own frame
    var pos:BufferAttribute = null;
    var uvA:BufferAttribute = null;
    var idx:Dynamic = null;
    var cent:js.lib.Float32Array = null;   // per-triangle centroid, local
    var nrm:js.lib.Float32Array = null;    // per-triangle geometric normal, local
    var trad:js.lib.Float32Array = null;   // per-triangle radius about that centroid, for the reject
    var hues:Array<Int> = [];              // the palette, straight off the row's lamp families

    // THE STATE: one ImageData over the whole map. a texel's family is read back out of it by exact
    // byte comparison, so there is no second table to keep in step and the canvas round-trips
    var img:Dynamic = null;
    var px:js.lib.Uint8ClampedArray = null;
    var base:js.lib.Uint8ClampedArray = null;  // how the session opened, for R
    var covered:js.lib.Uint8Array = null;      // texels ANY triangle covers; built lazily at save
    var touch:js.lib.Uint8Array = null;        // first-touch flag inside one stroke
    var cnt:Array<Int> = [];                   // lit texels per family, kept incrementally
    var sIdx:Array<Int> = [];                  // the live stroke: texel index
    var sPrev:Array<Int> = [];                 // and the packed rgb it had before
    var undoStack:Array<{ idx:Array<Int>, prev:Array<Int> }> = [];
    // the dirty rectangle, so a stroke uploads a few thousand texels and not four million
    var rx0 = 0;
    var ry0 = 0;
    var rx1 = -1;
    var ry1 = -1;
    var fullNext = false;                  // the canvas is showing a dilated export; repaint it all

    var curFam = 0;
    var radius = 0.35;                     // brush, WORLD units
    var dirty = false;
    var painting = false;
    var erasing = false;
    var lastX = 0.0;
    var lastY = 0.0;
    var lastHit:Vector3 = null;            // previous hit, so a stroke paints a capsule not a dot
    var lsTimer:haxe.Timer = null;
    var queued = false;                    // a mousemove is waiting for the next frame
    var qx = 0.0;
    var qy = 0.0;
    var scanAt = 0.0;                      // when the unbound whole-scene search last ran

    // the paint target, swapped in over the glb's own ImageBitmap (which cannot be drawn into).
    // alpha:false so toDataURL writes an opaque png rather than a needlessly RGBA one
    var canvas:Dynamic = Browser.document.createElement('canvas');
    var ctx:Dynamic = canvas.getContext('2d', { alpha: false, willReadFrequently: true });
    // and an offscreen scratch for reading the shipped map back and for encoding the session
    var sampCanvas:Dynamic = Browser.document.createElement('canvas');
    var sampCtx:Dynamic = sampCanvas.getContext('2d', { willReadFrequently: true });

    // HUD: a status panel with the SAVE button, plus the brush ring that replaces the cursor
    var bar = Browser.document.createElement('div');
    bar.style.cssText = 'position:fixed;left:8px;bottom:150px;z-index:321;background:#000c;' +
      'padding:6px 8px;font:12px monospace;color:#cde;display:none;pointer-events:auto';
    var info = Browser.document.createElement('div');
    info.style.cssText = 'white-space:pre;line-height:1.5';
    var saveBtn:Dynamic = Browser.document.createElement('button');
    saveBtn.textContent = 'SAVE — write the png';
    saveBtn.style.cssText = 'margin-top:4px;background:#222;color:#fc6;border:1px solid #555;' +
      'font:11px monospace;cursor:pointer;display:none';
    bar.appendChild(info);
    bar.appendChild(saveBtn);
    Browser.document.body.appendChild(bar);
    var ring = Browser.document.createElement('div');
    ring.style.cssText = 'position:fixed;z-index:322;pointer-events:none;border-radius:50%;' +
      'display:none;text-align:center;font:bold 13px monospace;color:#fff;text-shadow:0 0 3px #000';
    Browser.document.body.appendChild(ring);

    inline function active() return Tools.mode == 'paint';

    Tools.legend('paint',
      'T  leave paint mode        ctrl+LMB  fly-cam look (LMB is the brush here)\n' +
      'LMB  paint texels          RMB  erase them      wheel  brush size\n' +
      'C  next lamp family        Z  undo stroke       R  back to how this session opened\n' +
      'Ctrl+C / SAVE  write the painted map to <userData>/debug/');

// 0xRRGGBB as six lower-case hex digits
    function hex(c:Int):String {
      var s = StringTools.hex(c & 0xffffff, 6);
      return s.toLowerCase();
    }

// vertex index of corner k of triangle t (indexed or not)
    function vi(t:Int, k:Int):Int
      return idx != null ? Std.int(idx.getX(t * 3 + k)) : t * 3 + k;

// a vertex's uv in TEXEL coordinates of the emissive map. glb maps are flipY=false, three's own
// are flipY=true; repeat/offset are identity on a baked glb but cost nothing to honour
    function tx(i:Int):Float
      return (uvA.getX(i) * tex.repeat.x + tex.offset.x) * res;
    function ty(i:Int):Float {
      var v = uvA.getY(i) * tex.repeat.y + tex.offset.y;
      return (flipY ? 1 - v : v) * res;
    }

// is the mesh actually shown? the raycaster ignores visibility, so a hidden batch (a ghost that is
// not faded in, a light cone toggled off) still reports hits — walk the parent chain
    function isShown(o:Object3D):Bool {
      var cur:Object3D = o;
      while (cur != null) {
        if (!cur.visible)
          return false;
        cur = cur.parent;
      }
      return true;
    }

// read a texture's pixels back to the CPU. null if it has no image or the canvas is tainted
    function readback(t:Dynamic):Dynamic {
      if (t == null || t.image == null)
        return null;
      var w:Int = t.image.width;
      var h:Int = t.image.height;
      sampCanvas.width = w;
      sampCanvas.height = h;
      try {
        sampCtx.drawImage(t.image, 0, 0, w, h);
        var id = sampCtx.getImageData(0, 0, w, h);
        return { data: id.data, w: w, h: h };
      }
      catch (_:Dynamic)
        return null;
    }

// squared distance from a point to the segment ab
    function segD2(qx:Float, qy:Float, qz:Float, ax:Float, ay:Float, az:Float,
        bx:Float, by:Float, bz:Float):Float {
      var vx = bx - ax;
      var vy = by - ay;
      var vz = bz - az;
      var wx = qx - ax;
      var wy = qy - ay;
      var wz = qz - az;
      var vv = vx * vx + vy * vy + vz * vz;
      var t = vv > 1e-12 ? (wx * vx + wy * vy + wz * vz) / vv : 0.0;
      if (t < 0)
        t = 0;
      else if (t > 1)
        t = 1;
      var dx = wx - vx * t;
      var dy = wy - vy * t;
      var dz = wz - vz * t;
      return dx * dx + dy * dy + dz * dz;
    }

// which family a texel's exact bytes are, or -1. exact and not nearest: the map only ever holds
// bytes this tool wrote, and a nearest match would quietly accept a blend as a family
    function famOf(r:Int, g:Int, b:Int):Int {
      var c = (r << 16) | (g << 8) | b;
      for (f in 0...hues.length)
        if (hues[f] == c)
          return f;
      return -1;
    }

// mark the whole map as needing re-upload (a restore, an undo, a reset)
    function markAll():Void {
      rx0 = 0;
      ry0 = 0;
      rx1 = res - 1;
      ry1 = res - 1;
    }

// push the dirty rectangle to the GPU. the texture object is SHARED — Models.cache is keyed on
// path, SOLID uses the template material and GHOST clones it by reference — so this one write
// reaches the solid batch, the ghost batch, every instance and the warm scene at once
    function flush():Void {
      if (rx1 < rx0)
        return;
      if (fullNext) {
        markAll();
        fullNext = false;
      }
      ctx.putImageData(img, 0, 0, rx0, ry0, rx1 - rx0 + 1, ry1 - ry0 + 1);
      tex.image = canvas;
      tex.needsUpdate = true;
      rx0 = res;
      ry0 = res;
      rx1 = -1;
      ry1 = -1;
    }

// force every texel onto the palette: an exact family hue stays, anything else inside HUE_TOL of
// one is REWRITTEN to that family's exact bytes, and the rest goes black. The shipped map carried
// 893 texels of e0c8e0 — ImageChops.lighter compositing amber over cyan — sitting 0.73 and 0.62
// from the two markers against a 0.25 tolerance, so they matched no family and glowed as nothing.
// Returns how many texels were moved
    function snap():Int {
      var mk:Array<Array<Float>> = [];
      for (h in hues) {
        var r = ((h >> 16) & 255) / 255.0;
        var g = ((h >> 8) & 255) / 255.0;
        var b = (h & 255) / 255.0;
        var mx = Math.max(r, Math.max(g, b));
        mk.push([ r / mx, g / mx, b / mx ]);
      }
      for (f in 0...hues.length)
        cnt[f] = 0;
      var fixed = 0;
      var n = res * res;
      for (ti in 0...n) {
        var o = ti * 4;
        var r = px[o];
        var g = px[o + 1];
        var b = px[o + 2];
        px[o + 3] = 255;
        var mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
        if (mx < LIT) {
          if (mx != 0) {
            px[o] = 0;
            px[o + 1] = 0;
            px[o + 2] = 0;
            fixed++;
          }
          continue;
        }
        var f = famOf(r, g, b);
        if (f < 0) {
          var hr = r / mx;
          var hg = g / mx;
          var hb = b / mx;
          var bd = HUE_TOL;
          for (k in 0...mk.length) {
            var dr = hr - mk[k][0];
            var dg = hg - mk[k][1];
            var db = hb - mk[k][2];
            var dd = Math.sqrt(dr * dr + dg * dg + db * db);
            if (dd < bd) {
              bd = dd;
              f = k;
            }
          }
          fixed++;
          if (f < 0) {
            px[o] = 0;
            px[o + 1] = 0;
            px[o + 2] = 0;
            continue;
          }
          px[o] = (hues[f] >> 16) & 255;
          px[o + 1] = (hues[f] >> 8) & 255;
          px[o + 2] = hues[f] & 255;
        }
        cnt[f]++;
      }
      return fixed;
    }

// the session as a png data url, built off the EDITABLE state rather than off the canvas, which
// may be showing a dilated export
    function encode():String {
      sampCanvas.width = res;
      sampCanvas.height = res;
      var id = sampCtx.createImageData(res, res);
      id.data.set(px);
      sampCtx.putImageData(id, 0, 0);
      return sampCanvas.toDataURL('image/png');
    }

// persist the session per glb path, so a reload (or a rebuild) does not throw the work away.
// DEBOUNCED: encoding a 2048 map costs enough to be felt at the end of every stroke
    function saveLs():Void {
      if (lsTimer != null)
        lsTimer.stop();
      lsTimer = haxe.Timer.delay(function() {
        lsTimer = null;
        try {
          var raw = Browser.window.localStorage.getItem(LS_KEY);
          var all:Dynamic = raw != null ? Json.parse(raw) : {};
          Reflect.setField(all, tex.name, { res: res, tris: tris, png: encode() });
          Browser.window.localStorage.setItem(LS_KEY, Json.stringify(all));
        }
        catch (_:Dynamic) {}
      }, 800);
    }

// the file the export writes. host.debug.writeImage takes a BARE basename and validates it against
// [A-Za-z0-9_.-], so this strips the glb's directories and extension
    function fileName():String {
      var p:String = tex.name != null ? tex.name : 'prop.glb';
      var s = p.lastIndexOf('/');
      if (s >= 0)
        p = p.substr(s + 1);
      var d = p.lastIndexOf('.');
      if (d > 0)
        p = p.substr(0, d);
      return p + '-emissive.png';
    }

// hide the overlay + ring and forget the live stroke (leaving the mode, or the cursor leaving the prop)
    function idle():Void {
      painting = false;
      lastHit = null;
      ring.style.display = 'none';
    }

// the status panel: which family the brush is loaded with, how big it is, and what is lit
    function refreshBar():Void {
      if (!active() ||
          obj == null) {
        bar.style.display = 'none';
        return;
      }
      var swatch = '';
      var tot = 0;
      for (f in 0...hues.length) {
        tot += cnt[f];
        swatch += '<span style="background:#' + hex(hues[f]) + ';color:#000;padding:0 4px;margin-right:4px;' +
          (f == curFam ? 'outline:2px solid #fff' : 'opacity:0.45') + '">' + cnt[f] + '</span>';
      }
      info.innerHTML = '<div>' + swatch + '</div>' +
        '<div>brush ' + Math.round(radius * 100) / 100 + '   lit ' + tot + ' of ' + (res * res) +
        ' texels (' + Math.round(tot * 10000.0 / (res * res)) / 100 + '%)</div>' +
        '<div style="color:#8ab">' + tex.name + '  ' + res + 'px  ' + tris + ' tris</div>';
      saveBtn.style.display = dirty ? 'inline-block' : 'none';
      bar.style.display = 'block';
    }

// square max filter by r texels, separably. the same Chebyshev dilation emissive.py's grow() does
    function grow(m:js.lib.Uint8Array, r:Int):js.lib.Uint8Array {
      if (r <= 0)
        return m;
      var a = new js.lib.Uint8Array(res * res);
      for (y in 0...res) {
        var rowo = y * res;
        for (x in 0...res) {
          if (m[rowo + x] == 0)
            continue;
          var x0 = x - r < 0 ? 0 : x - r;
          var x1 = x + r >= res ? res - 1 : x + r;
          for (k in x0...x1 + 1)
            a[rowo + k] = 1;
        }
      }
      var b = new js.lib.Uint8Array(res * res);
      for (y in 0...res) {
        var rowo = y * res;
        var y0 = y - r < 0 ? 0 : y - r;
        var y1 = y + r >= res ? res - 1 : y + r;
        for (x in 0...res) {
          if (a[rowo + x] == 0)
            continue;
          for (k in y0...y1 + 1)
            b[k * res + x] = 1;
        }
      }
      return b;
    }

// rasterise one triangle's uv triangle and hand every covered texel to `hit`. conservative by GUT
// texels measured perpendicular to each edge, for the same reason emissive.py supersamples 4x: a
// chart thinner than a texel encloses no texel centre and would cover nothing at all.
// `hit` receives the texel index and its barycentric weights, so a caller can back-project it
    function raster(t:Int, hit:(Int, Float, Float, Float) -> Void):Void {
      var a = vi(t, 0);
      var b = vi(t, 1);
      var c = vi(t, 2);
      var axp = tx(a);
      var ayp = ty(a);
      var bxp = tx(b);
      var byp = ty(b);
      var cxp = tx(c);
      var cyp = ty(c);
      var area = (bxp - axp) * (cyp - ayp) - (byp - ayp) * (cxp - axp);
      if (Math.abs(area) < 1e-9)
        return;
      var sgn = area > 0 ? 1.0 : -1.0;
      var inv = 1 / area;
      var lbc = Math.sqrt((cxp - bxp) * (cxp - bxp) + (cyp - byp) * (cyp - byp));
      var lca = Math.sqrt((axp - cxp) * (axp - cxp) + (ayp - cyp) * (ayp - cyp));
      var lab = Math.sqrt((bxp - axp) * (bxp - axp) + (byp - ayp) * (byp - ayp));
      var x0 = Std.int(Math.floor(Math.min(axp, Math.min(bxp, cxp)) - GUT));
      var x1 = Std.int(Math.ceil(Math.max(axp, Math.max(bxp, cxp)) + GUT));
      var y0 = Std.int(Math.floor(Math.min(ayp, Math.min(byp, cyp)) - GUT));
      var y1 = Std.int(Math.ceil(Math.max(ayp, Math.max(byp, cyp)) + GUT));
      if (x0 < 0)
        x0 = 0;
      if (y0 < 0)
        y0 = 0;
      if (x1 > res - 1)
        x1 = res - 1;
      if (y1 > res - 1)
        y1 = res - 1;
      for (yy in y0...y1 + 1) {
        for (xx in x0...x1 + 1) {
          var qx = xx + 0.5;
          var qy = yy + 0.5;
          var ea = sgn * ((cxp - bxp) * (qy - byp) - (cyp - byp) * (qx - bxp));
          if (ea < -GUT * lbc)
            continue;
          var eb = sgn * ((axp - cxp) * (qy - cyp) - (ayp - cyp) * (qx - cxp));
          if (eb < -GUT * lca)
            continue;
          var ec = sgn * ((bxp - axp) * (qy - ayp) - (byp - ayp) * (qx - axp));
          if (ec < -GUT * lab)
            continue;
          var wa = ea * inv * sgn;
          var wb = eb * inv * sgn;
          hit(yy * res + xx, wa, wb, 1 - wa - wb);
        }
      }
    }

// the brush cursor: a ring at the brush's own size on screen, carrying + or -. a DOM circle rather
// than a CSS cursor image because browsers cap those at 128px and this brush goes past it
    function showRing(cx:Float, cy:Float, dist:Float):Void {
      var p = radius * (dom.clientHeight * 0.5) / (dist * Math.tan(camera.fov * Math.PI / 360));
      if (p < 4)
        p = 4;
      var col = '#' + hex(erasing ? 0xff3355 : hues[curFam]);
      ring.style.left = (cx - p) + 'px';
      ring.style.top = (cy - p) + 'px';
      ring.style.width = (p * 2) + 'px';
      ring.style.height = (p * 2) + 'px';
      ring.style.lineHeight = (p * 2) + 'px';
      ring.style.border = '2px solid ' + col;
      ring.textContent = erasing ? '−' : '+';
      ring.style.display = 'block';
    }

// THE BRUSH. world-space sphere, resolved per texel through the geometry.
// the colour written is the family's EXACT bytes or exact black, never a blend: PropGlow's lamp
// term is `propLampCol[i] * lw * base * beat` with no lmx and no emissiveColor factor, and
// lhue = emissiveColor/lmx is invariant under a scale toward black — so a half-opacity texel
// lights at FULL until it falls under the lmx > 0.004 gate, which is one 8-bit step. Feathering
// buys nothing, and blending BETWEEN families lands in the dead band where both tol shoulders miss
    function paintTexels(from:Vector3, to:Vector3):Void {
      if (obj == null)
        return;
      // a CAPSULE and not a sphere: one mousemove can jump further than the brush is wide, and a
      // texel brush lays dots where a triangle one got away with it. sweeping the segment costs
      // one scan, where re-raycasting the gap would cost a 100k-triangle intersect per step
      var p = new Vector3(from.x, from.y, from.z).applyMatrix4(mwInv);
      var q = new Vector3(to.x, to.y, to.z).applyMatrix4(mwInv);
      var mx = (p.x + q.x) * 0.5;
      var my = (p.y + q.y) * 0.5;
      var mz = (p.z + q.z) * 0.5;
      var half = Math.sqrt((q.x - p.x) * (q.x - p.x) + (q.y - p.y) * (q.y - p.y) +
        (q.z - p.z) * (q.z - p.z)) * 0.5;
      var cam = new Vector3(0, 0, 0).applyMatrix4(camera.matrixWorld).applyMatrix4(mwInv);
      var r = radius / scl;
      var r2 = r * r;
      var f = erasing ? -1 : curFam;
      var col = erasing ? 0 : hues[curFam];
      var cr = (col >> 16) & 255;
      var cg = (col >> 8) & 255;
      var cb = col & 255;
      // ponytail: linear scan over every triangle, then a rasterisation of the few the sphere
      // reaches. a UV or spatial grid is the upgrade if a denser prop ever stutters — measure first
      for (t in 0...tris) {
        var dx = cent[t * 3] - mx;
        var dy = cent[t * 3 + 1] - my;
        var dz = cent[t * 3 + 2] - mz;
        var rr = r + trad[t] + half;
        if (dx * dx + dy * dy + dz * dz > rr * rr)
          continue;
        if (nrm[t * 3] * (cent[t * 3] - cam.x) +
            nrm[t * 3 + 1] * (cent[t * 3 + 1] - cam.y) +
            nrm[t * 3 + 2] * (cent[t * 3 + 2] - cam.z) >= 0)
          continue;
        var ia = vi(t, 0);
        var ib = vi(t, 1);
        var ic = vi(t, 2);
        var ax = pos.getX(ia);
        var ay = pos.getY(ia);
        var az = pos.getZ(ia);
        var bx = pos.getX(ib);
        var by = pos.getY(ib);
        var bz = pos.getZ(ib);
        var cx2 = pos.getX(ic);
        var cy2 = pos.getY(ic);
        var cz2 = pos.getZ(ic);
        raster(t, function(ti:Int, wa:Float, wb:Float, wc:Float) {
          // back-project the texel centre onto the triangle and test the sphere there
          var lx = ax * wa + bx * wb + cx2 * wc;
          var ly = ay * wa + by * wb + cy2 * wc;
          var lz = az * wa + bz * wb + cz2 * wc;
          if (segD2(lx, ly, lz, p.x, p.y, p.z, q.x, q.y, q.z) > r2)
            return;
          var o = ti * 4;
          var pr = px[o];
          var pg = px[o + 1];
          var pb = px[o + 2];
          if (pr == cr &&
              pg == cg &&
              pb == cb)
            return;
          if (touch[ti] == 0) {
            touch[ti] = 1;
            sIdx.push(ti);
            sPrev.push((pr << 16) | (pg << 8) | pb);
          }
          var was = famOf(pr, pg, pb);
          if (was >= 0)
            cnt[was]--;
          if (f >= 0)
            cnt[f]++;
          px[o] = cr;
          px[o + 1] = cg;
          px[o + 2] = cb;
          px[o + 3] = 255;
          var qx = ti % res;
          var qy = Std.int(ti / res);
          if (qx < rx0)
            rx0 = qx;
          if (qx > rx1)
            rx1 = qx;
          if (qy < ry0)
            ry0 = qy;
          if (qy > ry1)
            ry1 = qy;
        });
      }
    }

// every texel ANY triangle covers, grown a texel. the export may only dilate into what is left,
// which is pure gutter — that is what makes foreign bleed zero by construction rather than by a
// guard that also ate the mask
    function buildCovered():Void {
      if (covered != null)
        return;
      var m = new js.lib.Uint8Array(res * res);
      for (t in 0...tris)
        raster(t, function(ti:Int, _, _, _) m[ti] = 1);
      covered = grow(m, 1);
    }

// the shipped map: the painted texels, plus DILATE texels of each family pushed into the gutter so
// bilinear and the mip chain do not read black at a chart edge. families are written in order and
// the last one wins a contested gutter texel — never a blend, which is what put a fourth hue in
// the old bake. nothing painted is ever removed
    function dilateExport():js.lib.Uint8ClampedArray {
      buildCovered();
      var out = new js.lib.Uint8ClampedArray(px);
      var n = res * res;
      var painted = new js.lib.Uint8Array(n);
      for (ti in 0...n) {
        var o = ti * 4;
        if (px[o] != 0 ||
            px[o + 1] != 0 ||
            px[o + 2] != 0)
          painted[ti] = 1;
      }
      for (f in 0...hues.length) {
        var cr = (hues[f] >> 16) & 255;
        var cg = (hues[f] >> 8) & 255;
        var cb = hues[f] & 255;
        var m = new js.lib.Uint8Array(n);
        for (ti in 0...n) {
          var o = ti * 4;
          if (px[o] == cr &&
              px[o + 1] == cg &&
              px[o + 2] == cb)
            m[ti] = 1;
        }
        var g = grow(m, DILATE);
        for (ti in 0...n) {
          if (g[ti] == 0 ||
              covered[ti] != 0 ||
              painted[ti] != 0)
            continue;
          var o = ti * 4;
          out[o] = cr;
          out[o + 1] = cg;
          out[o + 2] = cb;
          out[o + 3] = 255;
        }
      }
      return out;
    }

// the export: the finished png straight to <userData>/debug/ through the channel map.Image already
// uses, so the renderer's sandbox is not widened for a dev tool. the dilated map is also put on the
// canvas, which means the prop in front of you is now showing exactly what will ship
    function doSave():Void {
      if (obj == null)
        return;
      var out = dilateExport();
      var id = ctx.createImageData(res, res);
      id.data.set(out);
      ctx.putImageData(id, 0, 0);
      tex.image = canvas;
      tex.needsUpdate = true;
      fullNext = true;
      var url:String = canvas.toDataURL('image/png');
      var b64 = url.substr(url.indexOf(',') + 1);
      var name = fileName();
      var ok = HostBridge.debugWriteImage(name, b64);
      saveLs();
      StreetPerf.copyText(Json.stringify({
        glb: tex.name,
        res: res,
        tris: tris,
        file: name,
      }));
      dirty = false;
      refreshBar();
      var lit = 0;
      for (f in 0...hues.length)
        lit += cnt[f];
      trace('[polypaint] ' + (ok ? 'wrote ' : 'REFUSED (no .debug sentinel?) ') + name + ' — ' +
        Math.round(b64.length / 1024) + 'KB, ' + lit + ' painted texels + gutter');
    }

// restore a stored session onto the bound prop. false when there is none, or when it was saved
// against a different bake of the same model. the decode is async, so the seed is on screen first
    function loadLs():Bool {
      try {
        var raw = Browser.window.localStorage.getItem(LS_KEY);
        if (raw == null)
          return false;
        var e:Dynamic = Reflect.field(Json.parse(raw), tex.name);
        if (e == null ||
            e.tris != tris ||
            e.res != res ||
            e.png == null)
          return false;
        var im:Dynamic = Browser.document.createImageElement();
        im.onload = function(_) {
          sampCanvas.width = res;
          sampCanvas.height = res;
          sampCtx.clearRect(0, 0, res, res);
          sampCtx.drawImage(im, 0, 0);
          px.set(sampCtx.getImageData(0, 0, res, res).data);
          snap();
          // R goes back to the state the session STARTED in, which is the restored one when there
          // was one — keeping the readback instead would silently throw the stored work away
          base.set(px);
          markAll();
          flush();
          refreshBar();
        };
        im.src = e.png;
        return true;
      }
      catch (_:Dynamic)
        return false;
    }

// take the picked mesh as the paint target: its emissive texture, its ObjModels row (whose lamp
// families ARE the palette), its per-triangle tables, and the map it currently ships as the state
    function bind(o:Object3D, iid:Int, mat:Dynamic):Void {
      obj = o;
      tex = mat.emissiveMap;
      res = tex.image.width;
      flipY = tex.flipY != false ? true : false;
      // the row is found by the glb path render.Models stamps on every map a model carries — the
      // only provenance an embedded texture has at runtime
      row = null;
      for (m in ObjModels.MODELS)
        if (m.path == tex.name &&
            m.lamps != null) {
          row = m;
          break;
        }
      hues = [];
      if (row != null)
        for (l in row.lamps.list)
          hues.push(l.hue);
      if (hues.length == 0)
        hues = [ 0xffffff ]; // a prop with a map but no lamp families still paints, in white
      cnt = [];
      for (_ in 0...hues.length)
        cnt.push(0);
      curFam = 0;
      // mesh world x this instance's matrix: the frame the glb, tools/emissive.py and the P probe's
      // `local xyz` are all written in
      mw = o.matrixWorld;
      if (o.isInstancedMesh &&
          iid >= 0) {
        var im = new Matrix4();
        (cast o).getMatrixAt(iid, im);
        mw = new Matrix4().multiplyMatrices(o.matrixWorld, im);
      }
      mwInv = new Matrix4().copy(mw).invert();
      // the brush is stated in world units and tested in the glb's frame, so it needs the scale
      // Models.instanced folded in. measured off the matrix rather than read out of it
      var p0 = new Vector3(0, 0, 0).applyMatrix4(mw);
      var p1 = new Vector3(1, 0, 0).applyMatrix4(mw);
      scl = Math.sqrt((p1.x - p0.x) * (p1.x - p0.x) + (p1.y - p0.y) * (p1.y - p0.y) +
        (p1.z - p0.z) * (p1.z - p0.z));
      if (scl <= 0)
        scl = 1;
      var g:Dynamic = (cast o).geometry;
      pos = g.attributes.position;
      uvA = g.attributes.uv;
      idx = g.index;
      tris = idx != null ? Std.int(idx.count / 3) : Std.int(pos.count / 3);
      cent = new js.lib.Float32Array(tris * 3);
      nrm = new js.lib.Float32Array(tris * 3);
      trad = new js.lib.Float32Array(tris);
      for (t in 0...tris) {
        var a = vi(t, 0);
        var b = vi(t, 1);
        var c = vi(t, 2);
        var ax:Float = pos.getX(a), ay:Float = pos.getY(a), az:Float = pos.getZ(a);
        var bx:Float = pos.getX(b), by:Float = pos.getY(b), bz:Float = pos.getZ(b);
        var cx:Float = pos.getX(c), cy:Float = pos.getY(c), cz:Float = pos.getZ(c);
        var gx = (ax + bx + cx) / 3;
        var gy = (ay + by + cy) / 3;
        var gz = (az + bz + cz) / 3;
        cent[t * 3] = gx;
        cent[t * 3 + 1] = gy;
        cent[t * 3 + 2] = gz;
        // the sphere reject is against the triangle, not its centroid: a texel of a big triangle
        // can be inside the brush when the centroid is well outside it
        var da = (ax - gx) * (ax - gx) + (ay - gy) * (ay - gy) + (az - gz) * (az - gz);
        var db = (bx - gx) * (bx - gx) + (by - gy) * (by - gy) + (bz - gz) * (bz - gz);
        var dc = (cx - gx) * (cx - gx) + (cy - gy) * (cy - gy) + (cz - gz) * (cz - gz);
        trad[t] = Math.sqrt(Math.max(da, Math.max(db, dc)));
        var ux:Float = bx - ax, uy:Float = by - ay, uz:Float = bz - az;
        var vx:Float = cx - ax, vy:Float = cy - ay, vz:Float = cz - az;
        var nx:Float = uy * vz - uz * vy;
        var ny:Float = uz * vx - ux * vz;
        var nz:Float = ux * vy - uy * vx;
        var nl = Math.sqrt(nx * nx + ny * ny + nz * nz);
        if (nl > 0) {
          nx /= nl;
          ny /= nl;
          nz /= nl;
        }
        nrm[t * 3] = nx;
        nrm[t * 3 + 1] = ny;
        nrm[t * 3 + 2] = nz;
      }
      // the seed is the map the prop ships, copied texel for texel. there is no classification to
      // get wrong any more — the triangle version recovered only 646 of 1,228 and 2,559 of 4,983,
      // because the bake's bleed mask left ~3 lit texels on a 10-texel triangle
      canvas.width = res;
      canvas.height = res;
      img = ctx.createImageData(res, res);
      px = img.data;
      var s = readback(tex);
      if (s != null &&
          s.w == res &&
          s.h == res)
        px.set(s.data);
      var fixed = snap();
      // DROP THE GUTTER the last export pushed out. Binding to a shipped map otherwise takes its
      // dilation as paint and dilates THAT, so save -> install -> save would creep two texels
      // outward every round. A painted texel always lies inside some triangle's conservative
      // cover, so "lit and covered by nothing" is exactly the gutter and this is the exact
      // inverse of the export — which makes the round trip a fixed point
      covered = null;
      buildCovered();
      var eroded = 0;
      for (ti in 0...res * res) {
        if (covered[ti] != 0)
          continue;
        var o = ti * 4;
        var f = famOf(px[o], px[o + 1], px[o + 2]);
        if (f < 0)
          continue;
        cnt[f]--;
        px[o] = 0;
        px[o + 1] = 0;
        px[o + 2] = 0;
        eroded++;
      }
      base = new js.lib.Uint8ClampedArray(px);
      touch = new js.lib.Uint8Array(res * res);
      undoStack = [];
      sIdx = [];
      sPrev = [];
      dirty = loadLs(); // a restored session is already unsaved work
      markAll();
      flush();
      trace('[polypaint] bound ' + tex.name + ' — ' + tris + ' tris, ' + res + 'px map, ' +
        hues.length + ' families, ' + fixed + ' texels snapped to the palette, ' +
        eroded + ' gutter texels dropped' +
        (dirty ? ' (restoring a stored session)' : ''));
    }

// nearest front hit on the BOUND mesh, in the glb's own frame. three's intersectObjects is brute
// force and measured 9.4ms against this 100k-triangle prop, which is a whole frame per mousemove;
// this rejects on the per-triangle bounding sphere we already built for the brush and only runs
// Moller-Trumbore on what survives.
// ponytail: still a linear scan. a grid over the centroids is the upgrade if a denser prop stutters
    function rayLocal():Intersection {
      // local ray, direction NOT renormalised so t stays a WORLD distance
      var o = new Vector3(ray.ray.origin.x, ray.ray.origin.y, ray.ray.origin.z).applyMatrix4(mwInv);
      var e = new Vector3(ray.ray.origin.x + ray.ray.direction.x,
        ray.ray.origin.y + ray.ray.direction.y,
        ray.ray.origin.z + ray.ray.direction.z).applyMatrix4(mwInv);
      var dx = e.x - o.x;
      var dy = e.y - o.y;
      var dz = e.z - o.z;
      var dl2 = dx * dx + dy * dy + dz * dz;
      if (dl2 < 1e-20)
        return null;
      var best = 1e30;
      var bi = -1;
      for (t in 0...tris) {
        var wx = cent[t * 3] - o.x;
        var wy = cent[t * 3 + 1] - o.y;
        var wz = cent[t * 3 + 2] - o.z;
        // perpendicular distance from the centroid to the ray line, squared
        var cxx = wy * dz - wz * dy;
        var cyy = wz * dx - wx * dz;
        var czz = wx * dy - wy * dx;
        var rad = trad[t];
        if ((cxx * cxx + cyy * cyy + czz * czz) / dl2 > rad * rad)
          continue;
        if (wx * dx + wy * dy + wz * dz < 0)
          continue; // behind the eye
        var ia = vi(t, 0);
        var ib = vi(t, 1);
        var ic = vi(t, 2);
        var ax:Float = pos.getX(ia), ay:Float = pos.getY(ia), az:Float = pos.getZ(ia);
        var e1x:Float = pos.getX(ib) - ax, e1y:Float = pos.getY(ib) - ay, e1z:Float = pos.getZ(ib) - az;
        var e2x:Float = pos.getX(ic) - ax, e2y:Float = pos.getY(ic) - ay, e2z:Float = pos.getZ(ic) - az;
        var px2 = dy * e2z - dz * e2y;
        var py2 = dz * e2x - dx * e2z;
        var pz2 = dx * e2y - dy * e2x;
        var det = e1x * px2 + e1y * py2 + e1z * pz2;
        if (det > -1e-12 && det < 1e-12)
          continue;
        var invDet = 1 / det;
        var tx2 = o.x - ax;
        var ty2 = o.y - ay;
        var tz2 = o.z - az;
        var u = (tx2 * px2 + ty2 * py2 + tz2 * pz2) * invDet;
        if (u < 0 || u > 1)
          continue;
        var qx2 = ty2 * e1z - tz2 * e1y;
        var qy2 = tz2 * e1x - tx2 * e1z;
        var qz2 = tx2 * e1y - ty2 * e1x;
        var v = (dx * qx2 + dy * qy2 + dz * qz2) * invDet;
        if (v < 0 || u + v > 1)
          continue;
        var tt = (e2x * qx2 + e2y * qy2 + e2z * qz2) * invDet;
        if (tt <= 0 || tt >= best)
          continue;
        best = tt;
        bi = t;
      }
      if (bi < 0)
        return null;
      var w = new Vector3(o.x + dx * best, o.y + dy * best, o.z + dz * best).applyMatrix4(mw);
      return cast { object: obj, point: w, distance: best };
    }

// raycast the cursor. before a prop is bound this searches the scene for one carrying an emissive
// map; after, it tests the bound mesh alone, so nothing behind it can steal a hit
    function pick(cx:Float, cy:Float):Intersection {
      var r = dom.getBoundingClientRect();
      ndc.x = ((cx - r.left) / r.width) * 2 - 1;
      ndc.y = -((cy - r.top) / r.height) * 2 + 1;
      ray.setFromCamera(ndc, camera);
      if (obj != null)
        return rayLocal();
      // the whole-scene search happens once, so it is throttled rather than made fast
      var now = haxe.Timer.stamp();
      if (now - scanAt < 0.1)
        return null;
      scanAt = now;
      for (h in ray.intersectObjects(getScene().children, true)) {
        var face = h.face;
        var o = h.object;
        if (face == null ||
            (cast o).geometry == null ||
            (cast o).geometry.attributes.uv == null)
          continue;
        if (!isShown(o))
          continue;
        var m:Dynamic = o.material;
        var mat:Dynamic = Std.isOfType(m, Array) ? m[face.materialIndex] : m;
        if (mat == null ||
            mat.emissiveMap == null ||
            mat.emissiveMap.image == null)
          continue;
        var iid:Dynamic = h.instanceId;
        bind(o, iid == null ? -1 : iid, mat);
        return h;
      }
      return null;
    }

// re-cast at a screen position and refresh everything that follows from it. the WHEEL runs this
// too, not just a move: a brush whose ring only caught up on the next mousemove made sizing a guess
    function hover(cx:Float, cy:Float):Void {
      lastX = cx;
      lastY = cy;
      if (!active())
        return;
      var h = pick(cx, cy);
      if (h == null ||
          h.point == null) {
        idle();
        return;
      }
      showRing(cx, cy, h.distance);
      if (painting) {
        paintTexels(lastHit != null ? lastHit : h.point, h.point);
        lastHit = new Vector3(h.point.x, h.point.y, h.point.z);
        flush();
        dirty = true;
      }
      refreshBar();
    }

    // ONE update per animation frame. a 125Hz mouse fires twice per frame and every one of those
    // was a pick, a paint pass and an innerHTML write; the pointer cannot move faster than it is
    // drawn, so the extra ones were pure cost
    function schedule(cx:Float, cy:Float):Void {
      qx = cx;
      qy = cy;
      if (queued)
        return;
      queued = true;
      Browser.window.requestAnimationFrame(function(_) {
        queued = false;
        hover(qx, qy);
      });
    }

    dom.addEventListener('mousemove', function(e:js.html.MouseEvent) schedule(e.clientX, e.clientY));

    dom.addEventListener('mousedown', function(e:js.html.MouseEvent) {
      if (!active() ||
          obj == null)
        return;
      // ctrl+LMB is left to the fly cam, which gives up plain LMB while this mode owns it
      if (e.button == 0 && e.ctrlKey)
        return;
      if (e.button != 0 &&
          e.button != 2)
        return;
      erasing = e.button == 2;
      painting = true;
      sIdx = [];
      sPrev = [];
      lastHit = null;
      touch.fill(0);
      lastX = e.clientX;
      lastY = e.clientY;
      schedule(e.clientX, e.clientY);
    });

    Browser.window.addEventListener('mouseup', function(_) {
      if (!painting &&
          sIdx.length == 0)
        return;
      painting = false;
      lastHit = null;
      if (sIdx.length > 0) {
        undoStack.push({ idx: sIdx, prev: sPrev });
        if (undoStack.length > UNDO)
          undoStack.shift();
        saveLs();
      }
      sIdx = [];
      sPrev = [];
      erasing = false;
      refreshBar();
    });

    dom.addEventListener('wheel', function(e:js.html.WheelEvent) {
      if (!active())
        return;
      e.preventDefault();
      radius *= e.deltaY > 0 ? 1 / 1.15 : 1.15;
      radius = Math.max(0.01, Math.min(8.0, radius));
      schedule(e.clientX, e.clientY);
    }, { passive: false });

    Browser.window.addEventListener('keydown', function(e:js.html.KeyboardEvent) {
      if (!Tools.enabled)
        return;
      if (e.code == 'KeyT' && !e.ctrlKey && !e.metaKey && !e.altKey) {
        Tools.setMode(active() ? 'none' : 'paint');
        return;
      }
      if (!active())
        return;
      if ((e.ctrlKey || e.metaKey) && e.code == 'KeyC') {
        e.preventDefault();
        if (obj != null)
          doSave();
        return;
      }
      if (e.ctrlKey || e.metaKey || e.altKey || obj == null)
        return;
      if (e.code == 'KeyC') {
        curFam = (curFam + 1) % hues.length;
        schedule(lastX, lastY);
      }
      else if (e.code == 'KeyZ') {
        if (undoStack.length == 0)
          return;
        var s = undoStack.pop();
        for (i in 0...s.idx.length) {
          var o = s.idx[i] * 4;
          var c = s.prev[i];
          var was = famOf(px[o], px[o + 1], px[o + 2]);
          if (was >= 0)
            cnt[was]--;
          px[o] = (c >> 16) & 255;
          px[o + 1] = (c >> 8) & 255;
          px[o + 2] = c & 255;
          var now = famOf(px[o], px[o + 1], px[o + 2]);
          if (now >= 0)
            cnt[now]++;
        }
        markAll();
        flush();
        saveLs();
        refreshBar();
      }
      else if (e.code == 'KeyR') {
        px.set(base);
        snap();
        undoStack = [];
        dirty = false;
        markAll();
        flush();
        saveLs();
        refreshBar();
      }
    });

    saveBtn.addEventListener('click', function(_) doSave());

    Tools.listen(function() {
      if (active()) {
        dom.style.cursor = 'none'; // the ring IS the cursor here
        refreshBar();
        return;
      }
      dom.style.cursor = '';
      idle();
      bar.style.display = 'none';
    });
  }
}
