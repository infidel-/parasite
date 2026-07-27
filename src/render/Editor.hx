package render;

import three.Three;
import js.Browser;
import haxe.Json;

// in-browser texture-UV editor. Click a polygon to select its CLASS (white face
// outline + HUD); mouse wheel scrolls the class's additional UV offset on every
// polygon of that kind at once. Edits persist to localStorage (survive reload);
// Ctrl+C copies an `update info: <json>` prompt to merge back into PolyMeta.
//   wheel = V, alt+wheel = U, shift = 1/10 step, ctrl = ×10, base step = 1/res
class Editor {
  static inline var LS_KEY = 'polyedit';
  static inline var EPS = 1e-9;

  public static function attach(getScene:Void->Scene, camera:PerspectiveCamera, dom:Dynamic):Void {
    inline function fileOff(cls:String):{u:Float, v:Float} {
      var o = PolyMeta.OVERRIDES.get(cls);
      return { u: o != null ? o.offset.u : 0.0, v: o != null ? o.offset.v : 0.0 };
    }

    var storage = Browser.window.localStorage;
    var ls = new Map<String, {u:Float, v:Float}>();
    try {
      var raw = storage.getItem(LS_KEY);
      if (raw != null) {
        var o = Json.parse(raw);
        for (f in Reflect.fields(o)) {
          var e = Reflect.field(o, f);
          ls.set(f, { u: e.u != null ? e.u : 0.0, v: e.v != null ? e.v : 0.0 });
        }
      }
    } catch (_:Dynamic) {}
    for (cls in ls.keys()) { // drop edits already merged into PolyMeta
      var f = fileOff(cls);
      var e = ls.get(cls);
      if (Math.abs(e.u - f.u) < EPS && Math.abs(e.v - f.v) < EPS) ls.remove(cls);
    }
    inline function lsCount():Int { var n = 0; for (k in ls.keys()) n++; return n; }
    inline function saveLs():Void {
      var o = {};
      for (cls in ls.keys()) Reflect.setField(o, cls, { u: ls.get(cls).u, v: ls.get(cls).v });
      try storage.setItem(LS_KEY, Json.stringify(o)) catch (_:Dynamic) {}
    }
    saveLs();

    // current TOTAL additional offset per class = file value, overridden by live edits
    var cur = new Map<String, {u:Float, v:Float}>();
    for (cls in PolyMeta.OVERRIDES.keys()) cur.set(cls, fileOff(cls));
    for (cls in ls.keys()) cur.set(cls, { u: ls.get(cls).u, v: ls.get(cls).v });
    for (cls in cur.keys()) Poly.applyClassOffset(cls, cur.get(cls).u, cur.get(cls).v);

    var panel = Browser.document.getElementById('poly');
    var dirtyEl = Browser.document.getElementById('poly-dirty');
    var indEl = Browser.document.getElementById('editind');
    var checkEl = Browser.document.getElementById('poly-check');

    var selCls:String = null;
    var outline:LineSegments = null;
    var ray = new Raycaster();
    var ndc = new Vector2();

    inline function editMode() return Tools.mode == 'edit';
    inline function refreshDirty():Void dirtyEl.style.display = lsCount() > 0 ? 'inline' : 'none';
    inline function refreshInd():Void {
      indEl.textContent = editMode() ? 'EDIT' : '';
      indEl.style.display = editMode() ? 'inline' : 'none';
    }
    inline function round5(x:Float):Float return Math.round(x * 100000) / 100000;

    function showHud():Void {
      if (selCls == null) { panel.style.display = 'none'; return; }
      var info = Poly.info.get(selCls);
      var e = cur.exists(selCls) ? cur.get(selCls) : { u: 0.0, v: 0.0 };
      var texName = info != null && info.tex != null ? info.tex.split('/').pop() : '';
      var res = info != null ? info.res : 512;
      var name = info != null ? info.name : selCls;
      var data = Json.stringify({ offset: { u: round5(e.u), v: round5(e.v) } });
      panel.style.display = 'block';
      panel.innerHTML =
        '<div class="pn">' + name + '</div>' +
        '<div>tex: ' + texName + ' (' + res + ')</div>' +
        '<div>data: ' + data + '</div>' +
        '<div class="ph">cls ' + selCls + ' · wheel V · alt U · shift /10 · ctrl ×10 · Ctrl+C · R reset</div>';
    }

    function clearOutline():Void {
      if (outline == null) return;
      getScene().remove(outline);
      outline.geometry.dispose();
      outline = null;
    }

    function setOutline(hit:Intersection):Void {
      clearOutline();
      var obj = hit != null ? hit.object : null;
      if (obj == null || obj.isInstancedMesh || obj.geometry == null) return;
      var geo:Dynamic = obj.geometry;
      var eg:EdgesGeometry;
      // per-face outline only when the mesh has a MATERIAL ARRAY (walls: one cls per face, so
      // the hit face = the whole editable poly). single-material meshes (covers, doors) share
      // one cls across all faces → outline the WHOLE mesh, not the one box quad that was hit.
      var isArr:Bool = Std.isOfType(obj.material, Array);
      var mi = hit.face != null ? hit.face.materialIndex : 0;
      var grp:Dynamic = null;
      var groups:Array<Dynamic> = geo.groups;
      if (groups != null) for (g in groups) if (g.materialIndex == mi) { grp = g; break; }
      if (isArr && grp != null && geo.index != null) {
        var idx = geo.index, posa = geo.attributes.position;
        var arr:Array<Float> = [];
        var i:Int = grp.start;
        var end:Int = grp.start + grp.count;
        while (i < end) {
          var vi = idx.getX(i);
          arr.push(posa.getX(vi)); arr.push(posa.getY(vi)); arr.push(posa.getZ(vi));
          i++;
        }
        var fg = new BufferGeometry();
        fg.setAttribute('position', new Float32BufferAttribute(arr, 3));
        eg = new EdgesGeometry(fg, 1);
        fg.dispose();
      } else {
        eg = new EdgesGeometry(geo, 1);
      }
      outline = new LineSegments(eg, new LineBasicMaterial({ color: 0xffffff, depthTest: false }));
      outline.renderOrder = 999;
      outline.applyMatrix4(obj.matrixWorld);
      getScene().add(outline);
    }

    function pick(ev:js.html.MouseEvent):Void {
      var r = dom.getBoundingClientRect();
      ndc.x = ((ev.clientX - r.left) / r.width) * 2 - 1;
      ndc.y = -((ev.clientY - r.top) / r.height) * 2 + 1;
      ray.setFromCamera(ndc, camera);
      for (h in ray.intersectObjects(getScene().children, true)) {
        var m:Dynamic = h.object.material;
        var mat:Dynamic = Std.isOfType(m, Array) ? m[(h.face != null ? h.face.materialIndex : 0)] : m;
        var cls:String = (mat != null && mat.userData != null) ? mat.userData.cls : null;
        if (cls != null) { selCls = cls; setOutline(h); showHud(); return; }
      }
      selCls = null; clearOutline(); showHud();
    }

    var downX = 0.0, downY = 0.0;
    dom.addEventListener('mousedown', function(e:js.html.MouseEvent) { downX = e.clientX; downY = e.clientY; });
    dom.addEventListener('mouseup', function(e:js.html.MouseEvent) {
      if (!editMode() || e.button != 0) return;
      if (Math.sqrt(Math.pow(e.clientX - downX, 2) + Math.pow(e.clientY - downY, 2)) > 4) return;
      pick(e);
    });

    Browser.window.addEventListener('wheel', function(e:js.html.WheelEvent) {
      if (!editMode() || selCls == null) return;
      e.preventDefault();
      var info = Poly.info.get(selCls);
      var step = 1 / (info != null ? info.res : 512);
      if (e.shiftKey) step /= 10;
      if (e.ctrlKey) step *= 10;
      var dir = e.deltaY > 0 ? 1 : -1;
      var c = cur.exists(selCls) ? cur.get(selCls) : { u: 0.0, v: 0.0 };
      if (e.altKey) c.u += dir * step; else c.v += dir * step;
      cur.set(selCls, c);
      Poly.applyClassOffset(selCls, c.u, c.v);
      ls.set(selCls, { u: c.u, v: c.v });
      saveLs();
      refreshDirty();
      showHud();
    }, { passive: false });

    function copyAll():Void {
      var out = {};
      for (cls in ls.keys()) Reflect.setField(out, cls, { offset: { u: round5(ls.get(cls).u), v: round5(ls.get(cls).v) } });
      var text = 'update info: ' + Json.stringify(out);
      var flash = function() {
        checkEl.style.display = 'inline';
        Browser.window.setTimeout(function() checkEl.style.display = 'none', 1200);
      };
      var nav:Dynamic = Browser.navigator;
      if (nav.clipboard != null && nav.clipboard.writeText != null) nav.clipboard.writeText(text).then(flash, flash);
      else flash();
    }

    function resetAll():Void {
      ls = new Map();
      saveLs();
      for (cls in Poly.info.keys()) {
        var f = fileOff(cls);
        cur.set(cls, { u: f.u, v: f.v });
        Poly.applyClassOffset(cls, f.u, f.v);
      }
      refreshDirty();
      showHud();
    }

    Tools.listen(function() {
      refreshInd();
      if (!editMode()) { selCls = null; clearOutline(); showHud(); }
    });
    Browser.window.addEventListener('keydown', function(e:js.html.KeyboardEvent) {
      if (!Tools.enabled) return; // only in street-debug mode
      if (e.code == 'KeyE' && !e.ctrlKey && !e.metaKey && !e.altKey)
        Tools.setMode(editMode() ? 'select' : 'edit'); // exit edit → back to building-select (not dead 'none'), so clicking works again
      if (editMode() && (e.ctrlKey || e.metaKey) && e.code == 'KeyC') { e.preventDefault(); copyAll(); }
      if (editMode() && e.code == 'KeyR' && !e.ctrlKey && !e.metaKey && !e.altKey) resetAll();
    });

    refreshInd();
    refreshDirty();
  }
}
