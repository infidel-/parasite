package render;

import three.Three;
import js.Browser;
import haxe.Json;
import render.world.ObjModels;
import render.world.ObjModels.ObjModel;

// in-game emissive-map PAINTER (debug key T, inside street-debug mode). A prop's emissive map is a
// MARKER and not art: render.world.PropGlow's `lamps` column matches flat tints back by normalised
// hue, so all the map encodes is WHICH TRIANGLES belong to which lamp family. tools/emissive.py picks
// those triangles offline by a bounding box on the centroid narrowed by an albedo key, which cannot
// see what a lamp is and scattered the alien ship's cyan family over 4,983 of them.
//
// so the selection is made HERE, on the prop, with the mouse, and exported as the triangle indices
// themselves. THE UNIT IS A TRIANGLE AND NOT A TEXEL, which is the whole design. emissive.py already
// defines a map as a triangle set conservatively rasterised into UV space with its gutter dilation
// masked against every unselected triangle (the `bleed 0` gate), so an index list feeds that pipeline
// exactly where an exported PNG would bypass it. It also makes erase, undo and re-seed free — the
// canvas is a pure function of the triangle -> family map — and at ~10 texels per triangle on this
// prop a triangle already IS a fine brush.
//
// what is drawn in the game is a PREVIEW: browser antialiasing, no conservative raster, no bleed
// mask. The shipped PNG is still baked by `tools/emissive.py --tris` off the exported JSON, which
// lives in localStorage under `emispaint` (the idiom render.Editor's UV overrides already use) and
// is also copied to the clipboard by the SAVE button
class PolyPaint {
  static inline var LS_KEY = 'emispaint'; // localStorage: { "<glb path>": <the export below> }
  static inline var MAXSEL = 40000;       // selection-overlay capacity, triangles
  static inline var HUE_TOL = 0.25;       // normalised-hue match when seeding off the shipped map
  static inline var LIT = 8;              // a texel under this on every channel belongs to no family
  static inline var EXPAND = 1.5;         // texels a triangle is grown by when reading a map back,
                                          // to meet the gutter dilation the bake pushed outward

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
    var pos:Dynamic = null;
    var uvA:Dynamic = null;
    var idx:Dynamic = null;
    var cent:js.lib.Float32Array = null;   // per-triangle centroid, local
    var nrm:js.lib.Float32Array = null;    // per-triangle geometric normal, local
    var fam:js.lib.Int8Array = null;       // per-triangle family index, -1 = unpainted
    var seed:js.lib.Int8Array = null;      // what bind() produced, so R can go back to it
    var hues:Array<Int> = [];              // the palette, straight off the row's lamp families
    var curFam = 0;
    var radius = 0.35;                     // brush, WORLD units
    var dirty = false;
    var painting = false;
    var erasing = false;
    var sel:Array<Int> = [];               // triangles under the brush right now
    var lastX = 0.0;                       // last cursor position, so the wheel can re-cast
    var lastY = 0.0;
    var strokeAcc:Array<Int> = [];         // the live stroke as (tri, previous family) pairs
    var undoStack:Array<Array<Int>> = [];

    // the paint target, swapped in over the glb's own ImageBitmap (which cannot be drawn into)
    var canvas:Dynamic = Browser.document.createElement('canvas');
    var ctx:Dynamic = canvas.getContext('2d');
    // and an offscreen scratch for reading the shipped map back, to seed the session from it
    var sampCanvas:Dynamic = Browser.document.createElement('canvas');
    var sampCtx:Dynamic = sampCanvas.getContext('2d', { willReadFrequently: true });

    // HUD: a status panel with the SAVE button, plus the brush ring that replaces the cursor
    var bar = Browser.document.createElement('div');
    bar.style.cssText = 'position:fixed;left:8px;bottom:150px;z-index:321;background:#000c;' +
      'padding:6px 8px;font:12px monospace;color:#cde;display:none;pointer-events:auto';
    var info = Browser.document.createElement('div');
    info.style.cssText = 'white-space:pre;line-height:1.5';
    var saveBtn:Dynamic = Browser.document.createElement('button');
    saveBtn.textContent = 'SAVE — copy selection JSON';
    saveBtn.style.cssText = 'margin-top:4px;background:#222;color:#fc6;border:1px solid #555;' +
      'font:11px monospace;cursor:pointer;display:none';
    bar.appendChild(info);
    bar.appendChild(saveBtn);
    Browser.document.body.appendChild(bar);
    var ring = Browser.document.createElement('div');
    ring.style.cssText = 'position:fixed;z-index:322;pointer-events:none;border-radius:50%;' +
      'display:none;text-align:center;font:bold 13px monospace;color:#fff;text-shadow:0 0 3px #000';
    Browser.document.body.appendChild(ring);

    // the selection overlay: ONE preallocated mesh whose draw range is trimmed per move, so a
    // per-mousemove highlight never allocates a geometry or leaks a GPU buffer
    var selGeo:BufferGeometry = null;
    var selAttr:Float32BufferAttribute = null;
    var selMat:MeshBasicMaterial = null;
    var selMesh:Mesh = null;

    inline function active() return Tools.mode == 'paint';

    Tools.legend('paint',
      'T  leave paint mode        ctrl+LMB  fly-cam look (LMB is the brush here)\n' +
      'LMB  paint the brush       RMB  erase it        wheel  brush size\n' +
      'C  next lamp family        Z  undo stroke       R  back to how this session opened\n' +
      'Ctrl+C / SAVE  copy the triangle selection as JSON');

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

// repaint the whole map from the triangle -> family table and hand it to the GPU. the hairline
// stroke is not decoration: a chart thinner than a texel fills to nothing, and the shipped bake's
// own rasteriser is conservative for the same reason
    function repaint():Void {
      ctx.fillStyle = '#000000';
      ctx.fillRect(0, 0, res, res);
      for (f in 0...hues.length) {
        var any = false;
        ctx.beginPath();
        for (t in 0...tris) {
          if (fam[t] != f)
            continue;
          var a = vi(t, 0);
          var b = vi(t, 1);
          var c = vi(t, 2);
          ctx.moveTo(tx(a), ty(a));
          ctx.lineTo(tx(b), ty(b));
          ctx.lineTo(tx(c), ty(c));
          ctx.closePath();
          any = true;
        }
        if (!any)
          continue;
        var col = '#' + hex(hues[f]);
        ctx.fillStyle = col;
        ctx.strokeStyle = col;
        ctx.lineWidth = 1;
        ctx.fill();
        ctx.stroke();
      }
      tex.image = canvas;
      tex.needsUpdate = true;
    }

// draw only the triangles a stroke just added — the whole-canvas repaint is for erase and undo,
// where texels have to come OFF
    function drawTris(list:Array<Int>, f:Int):Void {
      var col = '#' + hex(hues[f]);
      ctx.beginPath();
      for (t in list) {
        var a = vi(t, 0);
        var b = vi(t, 1);
        var c = vi(t, 2);
        ctx.moveTo(tx(a), ty(a));
        ctx.lineTo(tx(b), ty(b));
        ctx.lineTo(tx(c), ty(c));
        ctx.closePath();
      }
      ctx.fillStyle = col;
      ctx.strokeStyle = col;
      ctx.lineWidth = 1;
      ctx.fill();
      ctx.stroke();
      tex.image = canvas;
      tex.needsUpdate = true;
    }

// the selection as the export format: one triangle-index list per lamp family, plus the triangle
// count as a staleness guard — decimation moves both indices and charts, so a bake against a glb
// of a different size must refuse rather than light the wrong surface
    function exportJson():String {
      var fams:Array<Dynamic> = [];
      for (f in 0...hues.length) {
        var list:Array<Int> = [];
        for (t in 0...tris)
          if (fam[t] == f)
            list.push(t);
        fams.push({ hue: hex(hues[f]), tris: list });
      }
      return Json.stringify({ glb: tex.name, res: res, tris: tris, families: fams });
    }

// persist the session per glb path, so a reload (or a rebuild) does not throw the work away
    function saveLs():Void {
      try {
        var raw = Browser.window.localStorage.getItem(LS_KEY);
        var all:Dynamic = raw != null ? Json.parse(raw) : {};
        Reflect.setField(all, tex.name, Json.parse(exportJson()));
        Browser.window.localStorage.setItem(LS_KEY, Json.stringify(all));
      }
      catch (_:Dynamic) {}
    }

// restore a stored session onto the bound prop. false when there is none, or when it was saved
// against a different bake of the same model
    function loadLs():Bool {
      try {
        var raw = Browser.window.localStorage.getItem(LS_KEY);
        if (raw == null)
          return false;
        var e:Dynamic = Reflect.field(Json.parse(raw), tex.name);
        if (e == null ||
            e.tris != tris)
          return false;
        for (t in 0...tris)
          fam[t] = -1;
        var fl:Array<Dynamic> = e.families;
        for (f in 0...hues.length) {
          var h = hex(hues[f]);
          for (rec in fl) {
            if (rec.hue != h)
              continue;
            var list:Array<Int> = rec.tris;
            for (t in list)
              fam[t] = f;
          }
        }
        return true;
      }
      catch (_:Dynamic)
        return false;
    }

// classify every triangle by the map the prop currently ships, so a session starts showing exactly
// what the game draws and the brush is used to CORRECT it rather than to redo it. the match is the
// shader's own: normalise the texel by its max channel and take the nearest marker
    function seedFromMap():Void {
      for (t in 0...tris)
        fam[t] = -1;
      var samp = readback(tex);
      if (samp == null)
        return;
      var mk:Array<Array<Float>> = [];
      for (h in hues) {
        var r = ((h >> 16) & 255) / 255.0;
        var g = ((h >> 8) & 255) / 255.0;
        var b = (h & 255) / 255.0;
        var mx = Math.max(r, Math.max(g, b));
        mk.push([ r / mx, g / mx, b / mx ]);
      }
      var d:Dynamic = samp.data;
      // how far to scale a corner away from the centroid so it moves out by EXPAND texels
      function push(dx:Float, dy:Float):Float {
        var l = Math.sqrt(dx * dx + dy * dy);
        return l < 1e-6 ? 1.0 : (l + EXPAND) / l;
      }
      // one texel of the readback, already in texel coordinates
      var rgb = [ 0.0, 0.0, 0.0 ];
      function at(px:Int, py:Int):Bool {
        if (px < 0 || px >= samp.w || py < 0 || py >= samp.h)
          return false;
        var i = (py * samp.w + px) * 4;
        rgb[0] = d[i];
        rgb[1] = d[i + 1];
        rgb[2] = d[i + 2];
        return Math.max(rgb[0], Math.max(rgb[1], rgb[2])) >= LIT;
      }
      for (t in 0...tris) {
        var a = vi(t, 0);
        var b = vi(t, 1);
        var c = vi(t, 2);
        // RASTERISE the triangle's own uv triangle and take the first lit texel in it. Four probe
        // points (centroid + the corners pulled in) were tried first and recovered 44% of the
        // shipped map: the bake subtracts every texel within one of a foreign chart, so a triangle
        // here keeps ~3 lit texels of its ~10 and a fixed probe set walks straight past them.
        //
        // and the triangle is EXPANDED by a texel and a half first, because the map it is reading
        // was dilated outward into the chart gutter by two: a strict inside test recovered FEWER
        // than the four probes did, since half of what the bake lit sits just outside the triangle
        // that asked for it
        var axp = tx(a), ayp = ty(a);
        var bxp = tx(b), byp = ty(b);
        var cxp = tx(c), cyp = ty(c);
        var gx = (axp + bxp + cxp) / 3;
        var gy = (ayp + byp + cyp) / 3;
        var ka = push(axp - gx, ayp - gy);
        var kb = push(bxp - gx, byp - gy);
        var kc = push(cxp - gx, cyp - gy);
        axp = gx + (axp - gx) * ka;
        ayp = gy + (ayp - gy) * ka;
        bxp = gx + (bxp - gx) * kb;
        byp = gy + (byp - gy) * kb;
        cxp = gx + (cxp - gx) * kc;
        cyp = gy + (cyp - gy) * kc;
        var x0 = Std.int(Math.floor(Math.min(axp, Math.min(bxp, cxp))));
        var x1 = Std.int(Math.ceil(Math.max(axp, Math.max(bxp, cxp))));
        var y0 = Std.int(Math.floor(Math.min(ayp, Math.min(byp, cyp))));
        var y1 = Std.int(Math.ceil(Math.max(ayp, Math.max(byp, cyp))));
        var lit = false;
        var yy = y0;
        while (yy <= y1 && !lit) {
          var xx = x0;
          while (xx <= x1) {
            var qx = xx + 0.5;
            var qy = yy + 0.5;
            var e0 = (bxp - axp) * (qy - ayp) - (byp - ayp) * (qx - axp);
            var e1 = (cxp - bxp) * (qy - byp) - (cyp - byp) * (qx - bxp);
            var e2 = (axp - cxp) * (qy - cyp) - (ayp - cyp) * (qx - cxp);
            if (((e0 >= 0 && e1 >= 0 && e2 >= 0) ||
                 (e0 <= 0 && e1 <= 0 && e2 <= 0)) &&
                at(xx, yy)) {
              lit = true;
              break;
            }
            xx++;
          }
          yy++;
        }
        // a chart narrower than a texel encloses no texel centre at all, so fall back to the one
        // the centroid lands in
        if (!lit)
          lit = at(Std.int((axp + bxp + cxp) / 3), Std.int((ayp + byp + cyp) / 3));
        if (!lit)
          continue;
        var mx = Math.max(rgb[0], Math.max(rgb[1], rgb[2]));
        var hr = rgb[0] / mx, hg = rgb[1] / mx, hb = rgb[2] / mx;
        var best = -1;
        var bestD = HUE_TOL;
        for (f in 0...mk.length) {
          var dr = hr - mk[f][0];
          var dg = hg - mk[f][1];
          var db = hb - mk[f][2];
          var dd = Math.sqrt(dr * dr + dg * dg + db * db);
          if (dd < bestD) {
            bestD = dd;
            best = f;
          }
        }
        if (best >= 0)
          fam[t] = best;
      }
    }

// hide the overlay + ring and forget the live stroke (leaving the mode, or the cursor leaving the prop)
    function idle():Void {
      painting = false;
      ring.style.display = 'none';
      if (selMesh != null)
        selMesh.visible = false;
    }

// the status panel: which family the brush is loaded with, how big it is, and what is selected
    function refreshBar():Void {
      if (!active() || obj == null) {
        bar.style.display = 'none';
        return;
      }
      var swatch = '';
      for (f in 0...hues.length)
        swatch += '<span style="background:#' + hex(hues[f]) + ';color:#000;padding:0 4px;margin-right:4px;' +
          (f == curFam ? 'outline:2px solid #fff' : 'opacity:0.45') + '">' + hex(hues[f]) + '</span>';
      var n = 0;
      for (t in 0...tris)
        if (fam[t] >= 0)
          n++;
      info.innerHTML = '<div>' + swatch + '</div>' +
        '<div>brush ' + Math.round(radius * 100) / 100 + '   sel ' + sel.length +
        '   lit ' + n + ' / ' + tris + ' tris</div>' +
        '<div style="color:#8ab">' + tex.name + '</div>';
      saveBtn.style.display = dirty ? 'inline-block' : 'none';
      bar.style.display = 'block';
    }

// the export: to the clipboard for a human, and to localStorage for the bake to be read back out
// over CDP. the renderer is sandboxed (nodeIntegration off) so the game cannot write into
// models-src, and a new IPC channel for a dev tool is a worse trade than reading one string
    function doSave():Void {
      if (obj == null)
        return;
      var js = exportJson();
      saveLs();
      StreetPerf.copyText(js);
      dirty = false;
      refreshBar();
      trace('[polypaint] ' + js.length + ' bytes copied — localStorage.' + LS_KEY + '["' + tex.name + '"]');
    }

// take the picked mesh as the paint target: its emissive texture, its ObjModels row (whose lamp
// families ARE the palette), its per-triangle centroids and normals, and a starting family map
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
      fam = new js.lib.Int8Array(tris);
      for (t in 0...tris) {
        var a = vi(t, 0);
        var b = vi(t, 1);
        var c = vi(t, 2);
        var ax:Float = pos.getX(a), ay:Float = pos.getY(a), az:Float = pos.getZ(a);
        var bx:Float = pos.getX(b), by:Float = pos.getY(b), bz:Float = pos.getZ(b);
        var cx:Float = pos.getX(c), cy:Float = pos.getY(c), cz:Float = pos.getZ(c);
        cent[t * 3] = (ax + bx + cx) / 3;
        cent[t * 3 + 1] = (ay + by + cy) / 3;
        cent[t * 3 + 2] = (az + bz + cz) / 3;
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
      seedFromMap();
      dirty = loadLs(); // a restored session is already unsaved work
      // R goes back to the state the session STARTED in, which is the restored one when there was
      // one — restoring the readback instead would silently throw the stored work away
      seed = new js.lib.Int8Array(tris);
      seed.set(fam);
      undoStack = [];
      canvas.width = res;
      canvas.height = res;
      repaint();
      trace('[polypaint] bound ' + tex.name + ' — ' + tris + ' tris, ' + res + 'px map, ' +
        hues.length + ' families' + (dirty ? ' (restored a stored session)' : ''));
    }

// build the selection overlay once, at capacity
    function ensureSel():Void {
      if (selMesh != null) {
        if (selMesh.parent == null)
          getScene().add(selMesh);
        return;
      }
      selGeo = new BufferGeometry();
      selAttr = new Float32BufferAttribute(MAXSEL * 9, 3);
      selGeo.setAttribute('position', selAttr);
      selMat = new MeshBasicMaterial({
        color: 0xffffff,
        transparent: true,
        opacity: 0.55,
        depthTest: false,
        side: THREE.DoubleSide,
      });
      selMesh = new Mesh(selGeo, selMat);
      selMesh.renderOrder = 999;
      selMesh.frustumCulled = false;
      getScene().add(selMesh);
    }

// every triangle whose centroid is inside the brush AND whose face turns toward the camera. the
// facing test is not polish: a sphere through a thin hull reaches the far side of it, and painting
// the inside of a saucer is invisible until it is baked
    function brushAt(hit:Vector3):Void {
      sel = [];
      if (obj == null)
        return;
      var p = new Vector3(hit.x, hit.y, hit.z).applyMatrix4(mwInv);
      var cam = new Vector3(0, 0, 0).applyMatrix4(camera.matrixWorld).applyMatrix4(mwInv);
      var r = radius / scl;
      var r2 = r * r;
      for (t in 0...tris) {
        var dx = cent[t * 3] - p.x;
        var dy = cent[t * 3 + 1] - p.y;
        var dz = cent[t * 3 + 2] - p.z;
        if (dx * dx + dy * dy + dz * dz > r2)
          continue;
        if (nrm[t * 3] * (cent[t * 3] - cam.x) +
            nrm[t * 3 + 1] * (cent[t * 3 + 1] - cam.y) +
            nrm[t * 3 + 2] * (cent[t * 3 + 2] - cam.z) >= 0)
          continue;
        sel.push(t);
        if (sel.length >= MAXSEL)
          break;
      }
    }

// mirror the selection into the overlay, in world space through this instance's matrix
    function showSel():Void {
      ensureSel();
      var arr = selAttr.array;
      var w = new Vector3();
      var k = 0;
      for (t in sel) {
        for (kk in 0...3) {
          var i = vi(t, kk);
          w.set(pos.getX(i), pos.getY(i), pos.getZ(i));
          w.applyMatrix4(mw);
          arr[k++] = w.x;
          arr[k++] = w.y;
          arr[k++] = w.z;
        }
      }
      selAttr.needsUpdate = true;
      selGeo.setDrawRange(0, sel.length * 3);
      selMat.color.setHex(erasing ? 0xff3355 : hues[curFam]);
      selMesh.visible = sel.length > 0;
    }

// the brush cursor: a ring at the brush's own size on screen, carrying + or -. a DOM circle rather
// than a CSS cursor image because browsers cap those at 128px and this brush goes past it
    function showRing(cx:Float, cy:Float, dist:Float):Void {
      var px = radius * (dom.clientHeight * 0.5) / (dist * Math.tan(camera.fov * Math.PI / 360));
      if (px < 4)
        px = 4;
      var col = '#' + hex(erasing ? 0xff3355 : hues[curFam]);
      ring.style.left = (cx - px) + 'px';
      ring.style.top = (cy - px) + 'px';
      ring.style.width = (px * 2) + 'px';
      ring.style.height = (px * 2) + 'px';
      ring.style.lineHeight = (px * 2) + 'px';
      ring.style.border = '2px solid ' + col;
      ring.textContent = erasing ? '−' : '+';
      ring.style.display = 'block';
    }

// write the current brush into the family table. add draws only what changed; erase has to take
// texels OFF, which only a full repaint does
    function applyBrush():Void {
      var f = erasing ? -1 : curFam;
      var changed:Array<Int> = [];
      for (t in sel) {
        if (fam[t] == f)
          continue;
        strokeAcc.push(t);
        strokeAcc.push(fam[t]);
        fam[t] = f;
        changed.push(t);
      }
      if (changed.length == 0)
        return;
      if (erasing)
        repaint();
      else
        drawTris(changed, f);
      dirty = true;
    }

// raycast the cursor. before a prop is bound this searches the scene for one carrying an emissive
// map; after, it tests the bound mesh alone, so the overlay and the props behind cannot steal a hit
    function pick(cx:Float, cy:Float):Intersection {
      var r = dom.getBoundingClientRect();
      ndc.x = ((cx - r.left) / r.width) * 2 - 1;
      ndc.y = -((cy - r.top) / r.height) * 2 + 1;
      ray.setFromCamera(ndc, camera);
      if (obj != null) {
        var hits = ray.intersectObjects([ obj ], true);
        return hits.length > 0 ? hits[0] : null;
      }
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
// too, not just a move: a brush whose ring and selection only caught up on the next mousemove made
// sizing it a guess
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
      brushAt(h.point);
      showSel();
      showRing(cx, cy, h.distance);
      if (painting)
        applyBrush();
      refreshBar();
    }

    dom.addEventListener('mousemove', function(e:js.html.MouseEvent) hover(e.clientX, e.clientY));

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
      strokeAcc = [];
      hover(e.clientX, e.clientY);
    });

    Browser.window.addEventListener('mouseup', function(_) {
      if (!painting)
        return;
      painting = false;
      if (strokeAcc.length > 0) {
        undoStack.push(strokeAcc);
        saveLs();
      }
      strokeAcc = [];
      erasing = false;
      refreshBar();
    });

    dom.addEventListener('wheel', function(e:js.html.WheelEvent) {
      if (!active())
        return;
      e.preventDefault();
      radius *= e.deltaY > 0 ? 1 / 1.15 : 1.15;
      radius = Math.max(0.02, Math.min(8.0, radius));
      hover(e.clientX, e.clientY);
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
        hover(lastX, lastY);
      }
      else if (e.code == 'KeyZ') {
        if (undoStack.length == 0)
          return;
        var s = undoStack.pop();
        var i = s.length - 2;
        while (i >= 0) {
          fam[s[i]] = s[i + 1];
          i -= 2;
        }
        repaint();
        saveLs();
        refreshBar();
      }
      else if (e.code == 'KeyR') {
        fam.set(seed);
        undoStack = [];
        dirty = false;
        repaint();
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
