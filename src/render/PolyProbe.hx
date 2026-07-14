package render;

import three.Three;
import js.Browser;

// single-polygon probe (debug key P): click a mesh to select ONE triangle. highlights that face
// in the 3D view (filled + outlined, drawn over everything) and mirrors it onto texture-view canvases
// in the upper-right — the clicked triangle drawn in UV space over its base-color + emissive maps, so
// you can see exactly which texel region a poly samples. built to pinpoint model/UV/baking issues.
// key G then classifies EVERY triangle of the picked mesh by emissive footprint (red = emits, blue =
// dark), so you can literally point out which faces self-glow vs which shouldn't.
class PolyProbe {
  static inline var TEX = 320; // texture-view canvas edge, px

  public static function attach(getScene:Void->Scene, camera:PerspectiveCamera, dom:Dynamic):Void {
    var ray = new Raycaster();
    var ndc = new Vector2();
    var hl:Group = null; // current 3D highlight (fill mesh + edge lines), null when nothing selected
    var glowHl:Group = null; // whole-mesh emissive-face overlay (debug G), independent of the single-face hl
    var lastObj:Object3D = null; // last picked mesh so G can classify it without re-clicking
    var lastInstanceId:Int = -1;
    // offscreen scratch for reading emissive texels back to the CPU (cached per texture uuid)
    var sampCanvas:Dynamic = Browser.document.createElement('canvas');
    var sampCtx:Dynamic = sampCanvas.getContext('2d', { willReadFrequently: true });
    var sampCache:Map<String, Dynamic> = new Map();

    // texture-view overlay (upper-right): stacked panes (base-color map + emissive map), each
    // showing the clicked triangle's UVs over the texel grid, plus a caption strip
    var box = Browser.document.createElement('div');
    box.style.cssText = 'position:fixed;top:8px;right:8px;z-index:320;display:none;pointer-events:none;font:11px monospace';
    // one labeled pixelated canvas pane; returns its 2d ctx + canvas + label (hidden when unused)
    function mkPane(title:String, border:String):{ x:Dynamic, c:Dynamic, lbl:Dynamic } {
      var lbl = Browser.document.createElement('div');
      lbl.textContent = title;
      lbl.style.cssText = 'background:#000c;color:#cde;padding:2px 6px';
      var c:Dynamic = Browser.document.createElement('canvas');
      c.width = TEX;
      c.height = TEX;
      c.style.cssText = 'display:block;border:1px solid ${border};background:#111;image-rendering:pixelated';
      var x:Dynamic = c.getContext('2d');
      x.imageSmoothingEnabled = false; // show raw texels, not a blurred interpolation
      box.appendChild(lbl);
      box.appendChild(c);
      return { x: x, c: c, lbl: lbl };
    }
    var basePane = mkPane('base map', '#6cf');
    var emisPane = mkPane('emissive map', '#fc6');
    var cap = Browser.document.createElement('div');
    cap.style.cssText = 'background:#000c;color:#cde;padding:4px 6px;white-space:pre;max-width:${TEX}px';
    box.appendChild(cap);
    Browser.document.body.appendChild(box);

    inline function active() return Tools.mode == 'poly';

// drop the current 3D highlight + hide the texture view
    function clear():Void {
      if (hl != null) {
        getScene().remove(hl);
        hl = null;
      }
      box.style.display = 'none';
    }

// drop the whole-mesh emissive-face overlay (independent of the single-face highlight)
    function clearGlow():Void {
      if (glowHl != null) {
        getScene().remove(glowHl);
        glowHl = null;
      }
    }

// build the over-everything highlight for one triangle: translucent red fill + yellow edges,
// in world space. for an InstancedMesh the clicked instance's matrix is folded in (instanceId >= 0),
// else the mesh's own world matrix — without this the highlight lands at the origin for instanced
// props (lamps/windows/most bulk geometry), which is why it stopped showing in the 3D view
    function highlight(obj:Object3D, instanceId:Int, a:Int, b:Int, c:Int):Void {
      var pos:Dynamic = (cast obj).geometry.attributes.position;
      // surface world matrix: mesh world · (this instance's matrix, when instanced)
      var mw = obj.matrixWorld;
      if ((cast obj).isInstancedMesh && instanceId >= 0) {
        var im = new Matrix4();
        (cast obj).getMatrixAt(instanceId, im);
        mw = new Matrix4().multiplyMatrices(obj.matrixWorld, im);
      }
      var w:Array<Vector3> = [];
      for (vi in [a, b, c]) {
        var v = new Vector3(pos.getX(vi), pos.getY(vi), pos.getZ(vi));
        v.applyMatrix4(mw);
        w.push(v);
      }
      var g = new BufferGeometry();
      g.setAttribute('position', new Float32BufferAttribute(
        [w[0].x, w[0].y, w[0].z, w[1].x, w[1].y, w[1].z, w[2].x, w[2].y, w[2].z], 3));
      var fill = new Mesh(g, new MeshBasicMaterial(
        { color: 0xff3355, transparent: true, opacity: 0.45, depthTest: false, side: THREE.DoubleSide }));
      fill.renderOrder = 1000;
      // edges as a closed loop (a-b, b-c, c-a)
      var eg = new BufferGeometry();
      eg.setAttribute('position', new Float32BufferAttribute(
        [w[0].x, w[0].y, w[0].z, w[1].x, w[1].y, w[1].z,
         w[1].x, w[1].y, w[1].z, w[2].x, w[2].y, w[2].z,
         w[2].x, w[2].y, w[2].z, w[0].x, w[0].y, w[0].z], 3));
      var edges = new LineSegments(eg, new LineBasicMaterial({ color: 0xffee44, depthTest: false }));
      edges.renderOrder = 1001;
      hl = new Group();
      hl.add(fill);
      hl.add(edges);
      getScene().add(hl);
    }

// draw the clicked triangle onto a texture pane: the given texture fills the canvas, then the
// face's 3 UVs are outlined + dotted over it. flipY decides the v axis (glb maps are flipY=false,
// three's own textures flipY=true). repeat/offset applied; rotation ignored (models bake identity)
    function paintTex(ctx:Dynamic, tex:Dynamic, flipY:Bool, a:Int, b:Int, c:Int, uv:Dynamic):Void {
      ctx.clearRect(0, 0, TEX, TEX);
      if (tex != null && tex.image != null) {
        try ctx.drawImage(tex.image, 0, 0, TEX, TEX)
        catch (_:Dynamic) {
          ctx.fillStyle = '#333';
          ctx.fillRect(0, 0, TEX, TEX);
        }
      } else {
        ctx.fillStyle = '#333';
        ctx.fillRect(0, 0, TEX, TEX);
      }
      if (uv == null)
        return;
      var rx:Float = tex != null ? tex.repeat.x : 1.0;
      var ry:Float = tex != null ? tex.repeat.y : 1.0;
      var ox:Float = tex != null ? tex.offset.x : 0.0;
      var oy:Float = tex != null ? tex.offset.y : 0.0;
      // map a UV vert index to canvas pixel (apply repeat/offset, flip v when the texture is flipY)
      inline function px(i:Int):{x:Float, y:Float} {
        var u = uv.getX(i) * rx + ox;
        var v = uv.getY(i) * ry + oy;
        return { x: u * TEX, y: (flipY ? 1 - v : v) * TEX };
      }
      var p = [px(a), px(b), px(c)];
      // filled tint + bright outline
      ctx.beginPath();
      ctx.moveTo(p[0].x, p[0].y);
      ctx.lineTo(p[1].x, p[1].y);
      ctx.lineTo(p[2].x, p[2].y);
      ctx.closePath();
      ctx.fillStyle = 'rgba(255,51,85,0.35)';
      ctx.fill();
      ctx.lineWidth = 2;
      ctx.strokeStyle = '#ffee44';
      ctx.stroke();
      // vertex dots so a sliver triangle is still findable
      ctx.fillStyle = '#ffee44';
      for (q in p) {
        ctx.beginPath();
        ctx.arc(q.x, q.y, 3, 0, Math.PI * 2);
        ctx.fill();
      }
    }

// is a mesh actually shown? the raycaster ignores visibility, so a hidden object (e.g. the lamp
// cones toggled off with debug 5) still reports hits — walk the parent chain and reject if any
// ancestor is invisible
    function isShown(o:Object3D):Bool {
      var cur:Object3D = o;
      while (cur != null) {
        if (!cur.visible)
          return false;
        cur = cur.parent;
      }
      return true;
    }

// read a texture's pixels back to the CPU once (cached by uuid). null if there's no image or the
// canvas is tainted. drawn top-down at native res, so row 0 = image top (same as the panes)
    function sampleTex(tex:Dynamic):Dynamic {
      if (tex == null || tex.image == null)
        return null;
      var key:String = tex.uuid;
      if (sampCache.exists(key))
        return sampCache.get(key);
      var img:Dynamic = tex.image;
      var w:Int = img.width, h:Int = img.height;
      var s:Dynamic = null;
      sampCanvas.width = w;
      sampCanvas.height = h;
      try {
        sampCtx.drawImage(img, 0, 0, w, h);
        var id = sampCtx.getImageData(0, 0, w, h);
        s = { data: id.data, w: w, h: h };
      }
      catch (_:Dynamic)
        s = null; // cross-origin taint — can't read back
      sampCache.set(key, s);
      return s;
    }

// nearest-texel luminance (0..1) at texture coords (repeat/offset already applied). wraps into the
// tile and flips v to match the texture's flipY — same vertical convention as the texture panes
    function lumAt(samp:Dynamic, u:Float, v:Float, flipY:Bool):Float {
      var sw:Int = samp.w, sh:Int = samp.h;
      var uu = u - Math.floor(u);
      var vv = v - Math.floor(v);
      if (flipY)
        vv = 1 - vv;
      var px = Std.int(uu * sw);
      var py = Std.int(vv * sh);
      if (px < 0) px = 0;
      if (px >= sw) px = sw - 1;
      if (py < 0) py = 0;
      if (py >= sh) py = sh - 1;
      var i = (py * sw + px) * 4;
      var d:Dynamic = samp.data;
      return (0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2]) / 255;
    }

// classify EVERY triangle of a mesh by whether its emissive-map footprint carries a lit texel, and
// paint an over-everything overlay: emitting faces red, the rest faint blue — so you can literally see
// which tris self-glow (the lens SHOULD; a stray sliver on the post SHOULD NOT). toggled with G.
// per triangle we sample the 3 corners + 3 edge midpoints + centroid so a bright strip that only
// clips the face (not a vertex) is still caught
    function emissiveFaces(obj:Object3D, instanceId:Int):Void {
      clearGlow();
      var m0:Dynamic = obj.material;
      var mat:Dynamic = Std.isOfType(m0, Array) ? m0[0] : m0;
      var emap:Dynamic = mat != null ? mat.emissiveMap : null;
      var samp = sampleTex(emap);
      // emissive tint luminance: multiplies the map, and is the whole signal when there's no map
      var ec:Dynamic = mat != null ? mat.emissive : null;
      var ecLum:Float = ec != null ? (0.2126 * ec.r + 0.7152 * ec.g + 0.0722 * ec.b) : 1.0;
      var flipY:Bool = emap != null && emap.flipY == false ? false : true;
      var rx:Float = emap != null ? emap.repeat.x : 1.0;
      var ry:Float = emap != null ? emap.repeat.y : 1.0;
      var ox:Float = emap != null ? emap.offset.x : 0.0;
      var oy:Float = emap != null ? emap.offset.y : 0.0;
      var g:Dynamic = (cast obj).geometry;
      var pos:Dynamic = g.attributes.position;
      var uv:Dynamic = g.attributes.uv;
      var idx:Dynamic = g.index;
      var tris:Int = idx != null ? Std.int(idx.count / 3) : Std.int(pos.count / 3);
      // world matrix incl. the picked instance's transform
      var mw = obj.matrixWorld;
      if ((cast obj).isInstancedMesh && instanceId >= 0) {
        var im = new Matrix4();
        (cast obj).getMatrixAt(instanceId, im);
        mw = new Matrix4().multiplyMatrices(obj.matrixWorld, im);
      }
      var THR = 0.06; // any texel brighter than this counts as "emits"
      var emit:Array<Float> = [];
      var dark:Array<Float> = [];
      var nEmit = 0;
      // local index -> world-space vertex
      inline function wv(i:Int):Vector3 {
        var v = new Vector3(pos.getX(i), pos.getY(i), pos.getZ(i));
        v.applyMatrix4(mw);
        return v;
      }
      for (t in 0...tris) {
        var i0 = idx != null ? Std.int(idx.getX(t * 3)) : t * 3;
        var i1 = idx != null ? Std.int(idx.getX(t * 3 + 1)) : t * 3 + 1;
        var i2 = idx != null ? Std.int(idx.getX(t * 3 + 2)) : t * 3 + 2;
        var lit = false;
        if (samp != null) {
          var u0 = uv.getX(i0), v0 = uv.getY(i0);
          var u1 = uv.getX(i1), v1 = uv.getY(i1);
          var u2 = uv.getX(i2), v2 = uv.getY(i2);
          var su = [u0, u1, u2, (u0 + u1) / 2, (u1 + u2) / 2, (u2 + u0) / 2, (u0 + u1 + u2) / 3];
          var sv = [v0, v1, v2, (v0 + v1) / 2, (v1 + v2) / 2, (v2 + v0) / 2, (v0 + v1 + v2) / 3];
          for (k in 0...su.length)
            if (lumAt(samp, su[k] * rx + ox, sv[k] * ry + oy, flipY) * ecLum > THR) {
              lit = true;
              break;
            }
        }
        else
          lit = ecLum > THR; // uniform emissive (material emissive color, no map)
        var dst = lit ? emit : dark;
        for (v in [wv(i0), wv(i1), wv(i2)]) {
          dst.push(v.x);
          dst.push(v.y);
          dst.push(v.z);
        }
        if (lit)
          nEmit++;
      }
      // one flat-color mesh per class, drawn over everything (under the single-face hl at 1000)
      inline function faceMesh(arr:Array<Float>, color:Int, op:Float):Mesh {
        var geo = new BufferGeometry();
        geo.setAttribute('position', new Float32BufferAttribute(arr, 3));
        var mm = new Mesh(geo, new MeshBasicMaterial(
          { color: color, transparent: true, opacity: op, depthTest: false, side: THREE.DoubleSide }));
        mm.renderOrder = 999;
        return mm;
      }
      glowHl = new Group();
      if (dark.length > 0)
        glowHl.add(faceMesh(dark, 0x2266ff, 0.14));
      if (emit.length > 0)
        glowHl.add(faceMesh(emit, 0xff2244, 0.6));
      getScene().add(glowHl);
      // tally in the caption strip
      cap.textContent = 'emissive faces: ' + nEmit + ' / ' + tris + ' emit (red) · rest dark (blue)\n' +
        (samp == null ? '(no emissive map — uniform emit ' + round3(ecLum) + ')' : 'sampled map ' + samp.w + 'x' + samp.h);
      box.style.display = 'block';
    }

// raycast the cursor, take the nearest triangle hit, and light it up in both views
    function pick(ev:js.html.MouseEvent):Void {
      var r = dom.getBoundingClientRect();
      ndc.x = ((ev.clientX - r.left) / r.width) * 2 - 1;
      ndc.y = -((ev.clientY - r.top) / r.height) * 2 + 1;
      ray.setFromCamera(ndc, camera);
      for (h in ray.intersectObjects(getScene().children, true)) {
        var face:Dynamic = h.face;
        var obj = h.object;
        if (face == null || (cast obj).geometry == null || (cast obj).geometry.attributes.uv == null)
          continue;
        // skip hidden meshes (debug light/cone toggles) — the raycaster hits them regardless
        if (!isShown(obj))
          continue;
        // skip our own highlight fill so re-clicking picks the surface under it
        if (hl != null && (cast obj).parent == hl)
          continue;
        var a:Int = face.a, b:Int = face.b, c:Int = face.c;
        // instanced hit → the clicked instance id (else -1 for a plain mesh)
        var iid:Dynamic = (cast h).instanceId;
        var instanceId:Int = iid == null ? -1 : iid;
        lastObj = obj; // remember for the G emissive-face overlay
        lastInstanceId = instanceId;
        var m:Dynamic = obj.material;
        var mat:Dynamic = Std.isOfType(m, Array) ? m[face.materialIndex] : m;
        clear();
        highlight(obj, instanceId, a, b, c);
        var g:Dynamic = (cast obj).geometry;
        // paint both panes over the same UVs; hide the emissive pane when the material has none.
        // one shared flipY (from whichever map exists) so an absent base map can't mirror the
        // emissive pane against it — maps + emissive of a material share a vertical convention
        var bmap:Dynamic = mat != null ? mat.map : null;
        var emap:Dynamic = mat != null ? mat.emissiveMap : null;
        var refTex:Dynamic = bmap != null ? bmap : emap;
        var flipY:Bool = refTex != null && refTex.flipY == false ? false : true;
        paintTex(basePane.x, bmap, flipY, a, b, c, g.attributes.uv);
        paintTex(emisPane.x, emap, flipY, a, b, c, g.attributes.uv);
        emisPane.c.style.display = emap != null ? 'block' : 'none';
        emisPane.lbl.style.display = emap != null ? 'block' : 'none';
        // caption: mesh + face (+ instance) + base/emissive texture facts + the 3 raw UVs
        var tex:Dynamic = mat != null ? mat.map : null;
        inline function dimOf(t:Dynamic, none:String)
          return t != null && t.image != null ? (t.image.width + 'x' + t.image.height) : none;
        var flip = tex != null ? (tex.flipY == false ? 'flipY=0' : 'flipY=1') : '';
        inline function uvs(i:Int) return round3(g.attributes.uv.getX(i)) + ',' + round3(g.attributes.uv.getY(i));
        cap.textContent =
          'mesh: ' + (obj.name != '' ? obj.name : '(unnamed)') + '   face #' + h.faceIndex +
          (instanceId >= 0 ? '   inst#' + instanceId : '') + '\n' +
          'base: ' + dimOf(tex, 'no map') + ' ' + flip + '\n' +
          'emis: ' + dimOf(emap, 'none') + '\n' +
          'uv a ' + uvs(a) + '\n' +
          'uv b ' + uvs(b) + '\n' +
          'uv c ' + uvs(c);
        box.style.display = 'block';
        return;
      }
      clear();
    }

    var downX = 0.0, downY = 0.0;
    dom.addEventListener('mousedown', function(e:js.html.MouseEvent) {
      downX = e.clientX;
      downY = e.clientY;
    });
    dom.addEventListener('mouseup', function(e:js.html.MouseEvent) {
      if (!active() || e.button != 0)
        return;
      if (Math.sqrt(Math.pow(e.clientX - downX, 2) + Math.pow(e.clientY - downY, 2)) > 4)
        return;
      pick(e);
    });

    Tools.listen(function() {
      if (!active()) {
        clear();
        clearGlow();
      }
    });
    Browser.window.addEventListener('keydown', function(e:js.html.KeyboardEvent) {
      if (!Tools.enabled)
        return; // only in street-debug mode
      if (e.code == 'KeyP' && !e.ctrlKey && !e.metaKey && !e.altKey)
        Tools.setMode(active() ? 'none' : 'poly');
      // G: in poly mode, toggle the emissive-face overlay for the last picked mesh
      else if (e.code == 'KeyG' && active()) {
        if (glowHl != null)
          clearGlow();
        else if (lastObj != null)
          emissiveFaces(lastObj, lastInstanceId);
      }
    });
  }

// round to 3 decimals for the UV caption
  static inline function round3(x:Float):Float
    return Math.round(x * 1000) / 1000;
}
