package render;

import three.Three;
import js.Browser;

// single-polygon probe (debug key P): click a mesh to select ONE triangle. highlights that face
// in the 3D view (filled + outlined, drawn over everything) and mirrors it onto a texture-view
// canvas in the upper-right — the clicked triangle drawn in UV space over its base-color map, so
// you can see exactly which texel region a poly samples. built to pinpoint model/UV/baking issues.
class PolyProbe {
  static inline var TEX = 320; // texture-view canvas edge, px

  public static function attach(getScene:Void->Scene, camera:PerspectiveCamera, dom:Dynamic):Void {
    var ray = new Raycaster();
    var ndc = new Vector2();
    var hl:Group = null; // current 3D highlight (fill mesh + edge lines), null when nothing selected

    // texture-view overlay (upper-right): canvas for the base map + a caption strip
    var box = Browser.document.createElement('div');
    box.style.cssText = 'position:fixed;top:8px;right:8px;z-index:320;display:none;pointer-events:none;font:11px monospace';
    var canvas:Dynamic = Browser.document.createElement('canvas');
    canvas.width = TEX;
    canvas.height = TEX;
    canvas.style.cssText = 'display:block;border:1px solid #6cf;background:#111;image-rendering:pixelated';
    var cap = Browser.document.createElement('div');
    cap.style.cssText = 'background:#000c;color:#cde;padding:4px 6px;white-space:pre;max-width:${TEX}px';
    box.appendChild(canvas);
    box.appendChild(cap);
    Browser.document.body.appendChild(box);
    var ctx:Dynamic = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false; // show raw texels, not a blurred interpolation

    inline function active() return Tools.mode == 'poly';

// drop the current 3D highlight + hide the texture view
    function clear():Void {
      if (hl != null) {
        getScene().remove(hl);
        hl = null;
      }
      box.style.display = 'none';
    }

// build the over-everything highlight for one triangle: translucent red fill + yellow edges,
// in world space (verts baked through the mesh's world matrix so it sits on the real surface)
    function highlight(obj:Object3D, a:Int, b:Int, c:Int):Void {
      var pos:Dynamic = (cast obj).geometry.attributes.position;
      var w:Array<Vector3> = [];
      for (vi in [a, b, c]) {
        var v = new Vector3(pos.getX(vi), pos.getY(vi), pos.getZ(vi));
        v.applyMatrix4(obj.matrixWorld);
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

// draw the clicked triangle onto the texture view: base map filling the canvas, then the face's
// 3 UVs outlined + dotted over it. flipY decides the v axis (glb maps are flipY=false, three's
// own textures flipY=true). repeat/offset applied; rotation ignored (models bake identity)
    function drawTex(mat:Dynamic, a:Int, b:Int, c:Int, uv:Dynamic):Void {
      ctx.clearRect(0, 0, TEX, TEX);
      var tex:Dynamic = mat != null ? mat.map : null;
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
      var flipY:Bool = tex != null && tex.flipY == false ? false : true;
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
        // skip our own highlight fill so re-clicking picks the surface under it
        if (hl != null && (cast obj).parent == hl)
          continue;
        var a:Int = face.a, b:Int = face.b, c:Int = face.c;
        var m:Dynamic = obj.material;
        var mat:Dynamic = Std.isOfType(m, Array) ? m[face.materialIndex] : m;
        clear();
        highlight(obj, a, b, c);
        var g:Dynamic = (cast obj).geometry;
        drawTex(mat, a, b, c, g.attributes.uv);
        // caption: mesh + material + face + texture facts + the 3 raw UVs
        var tex:Dynamic = mat != null ? mat.map : null;
        var img:Dynamic = tex != null ? tex.image : null;
        var dim = img != null ? (img.width + 'x' + img.height) : 'no map';
        var flip = tex != null ? (tex.flipY == false ? 'flipY=0' : 'flipY=1') : '';
        inline function uvs(i:Int) return round3(g.attributes.uv.getX(i)) + ',' + round3(g.attributes.uv.getY(i));
        cap.textContent =
          'mesh: ' + (obj.name != '' ? obj.name : '(unnamed)') + '   face #' + h.faceIndex + '\n' +
          'tex: ' + dim + ' ' + flip + '\n' +
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
      if (!active())
        clear();
    });
    Browser.window.addEventListener('keydown', function(e:js.html.KeyboardEvent) {
      if (!Tools.enabled)
        return; // only in street-debug mode
      if (e.code == 'KeyP' && !e.ctrlKey && !e.metaKey && !e.altKey)
        Tools.setMode(active() ? 'none' : 'poly');
    });
  }

// round to 3 decimals for the UV caption
  static inline function round3(x:Float):Float
    return Math.round(x * 1000) / 1000;
}
