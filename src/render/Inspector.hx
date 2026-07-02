package render;

import three.Three;
import js.Browser;
import citygen.CityConfig;
import citygen.CityModel.City;

// click a building (B mode, on at start; toggle with B) to dump the same area
// report the shape copy buttons produce — ASCII map + per-building metadata,
// centered on the clicked building — into #binfo + clipboard + console.
// click empty ground (no building hit) instead → same report centered on that
// spot, so you can point at a road/walkway/alley strip, not just a building
class Inspector {
  public static function attach(getScene:Void->Scene, camera:PerspectiveCamera, dom:Dynamic, getCity:Void->City, getSeed:Void->Int):Void {
    var out = Browser.document.getElementById('binfo');
    var ray = new Raycaster();
    var ndc = new Vector2();
    var downX = 0.0, downY = 0.0;

    inline function active() return Tools.mode == 'select';
    Tools.listen(function() {
      if (out != null) out.textContent = active() ? 'select buildings: ON (B)' : '';
    });
    Browser.window.addEventListener('keydown', function(e:js.html.KeyboardEvent) {
      if (!Tools.enabled) return; // only in street-debug mode
      if (e.code == 'KeyB' && !e.ctrlKey && !e.metaKey && !e.altKey)
        Tools.setMode(active() ? 'none' : 'select');
    });
    dom.addEventListener('mousedown', function(e:js.html.MouseEvent) {
      downX = e.clientX; downY = e.clientY;
    });
    dom.addEventListener('mouseup', function(e:js.html.MouseEvent) {
      if (e.button != 0 || !active()) return;
      if (Math.sqrt(Math.pow(e.clientX - downX, 2) + Math.pow(e.clientY - downY, 2)) > 4) return;
      var r = dom.getBoundingClientRect();
      ndc.x = ((e.clientX - r.left) / r.width) * 2 - 1;
      ndc.y = -((e.clientY - r.top) / r.height) * 2 + 1;
      ray.setFromCamera(ndc, camera);
      var hits = ray.intersectObjects(getScene().children, true);
      for (h in hits) {
        var ud:Dynamic = h.object.userData;
        if (ud != null && ud.b != null) { show(out, getCity(), getSeed(), ud.b); return; }
      }
      // no building under the cursor → report the ground spot we hit (point at a strip)
      if (hits.length > 0) {
        var p:Dynamic = (cast hits[0]).point;
        emit(out, '[block]', BDump.shape('block', getCity(), getSeed(), p.x, p.z, CityConfig.CELL * 6));
      }
    });
  }

  static function show(out:js.html.Element, city:City, seed:Int, b:Dynamic):Void {
    var cw = CityConfig.cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
    var r = (b.w > b.d ? b.w : b.d) * CityConfig.CELL / 2;
    emit(out, '[bldg]', BDump.shape('building', city, seed, cw.x, cw.z, r));
  }

  static function emit(out:js.html.Element, tag:String, s:String):Void {
    Browser.console.log(tag + '\n' + s);
    if (out != null) out.textContent = s;
    // clipboard rejects when the document is unfocused; skip then, and swallow any
    // residual rejection so it never surfaces as an unhandled promise error
    var nav:Dynamic = Browser.navigator;
    if (nav.clipboard != null &&
        nav.clipboard.writeText != null &&
        Browser.document.hasFocus())
      nav.clipboard.writeText(s).then(null, function(_) {});
  }
}
