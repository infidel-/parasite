package render;

import three.Three;
import js.Browser;
import citygen.CityModel.City;
import citygen.CityModel.PShape;
import game.Game;

// street-debug mode (backquote): the HUD overlay + tools — fly cam (F), poly UV editor (E),
// building inspector (B), shape cyclers, __dbg console helpers. Split out of render.View so
// the view keeps only the render loop; it forwards the toggle and per-frame hooks here.
// scene/city rebuild per area, so everything reads them through getters.
class Debug {
  public var on(default, null):Bool = false;
  public var freeCam(default, null):FreeCam;

  var game:Game;
  var canvas:Dynamic;
  var getCamera:Void->PerspectiveCamera;
  var getScene:Void->Scene;
  var getCity:Void->City;
  var getSeed:Void->Int;
  var el:js.html.Element;
  var toolsAttached = false;
  var cycRefresh:Array<Void->Void> = []; // per-cycler label/index resets, run on every rebuild
  var hudWasVisible = false; // game HUD state before debug hid it (restored on exit)

  // shape-cycler rows (debug HUD): label + copy button + locator list of the current city
  static var CYCLERS:Array<{ key:String, label:String, copy:Bool, spots:City->Array<PShape> }> = [
    { key: 'p', label: 'П-shaped', copy: true, spots: function(c) return c.pshapes },
    { key: 'turn', label: 'turns', copy: false, spots: function(c) return c.turnspots },
    { key: 'l', label: 'L-shaped', copy: true, spots: function(c) return c.lshapes },
    { key: 't', label: 'T-shaped', copy: true, spots: function(c) return c.tshapes },
    { key: 'plus', label: '+-shaped', copy: true, spots: function(c) return c.plusshapes },
    { key: 'shop', label: 'shop', copy: true, spots: function(c) return c.shopspots },
  ];

  public function new(game:Game, canvas:Dynamic, getCamera:Void->PerspectiveCamera,
      getScene:Void->Scene, getCity:Void->City, getSeed:Void->Int) {
    this.game = game;
    this.canvas = canvas;
    this.getCamera = getCamera;
    this.getScene = getScene;
    this.getCity = getCity;
    this.getSeed = getSeed;
    injectHud();
  }

// is the free cam currently owning the camera?
  public inline function flying():Bool return freeCam != null && freeCam.active;

// a new city was built (area change/restart): reset cycler indices + refresh counts
  public function onRebuild():Void {
    for (f in cycRefresh) f();
  }

// enter/leave street-debug mode (fly/editor/inspector + HUD)
  public function set(o:Bool):Void {
    on = o;
    if (o) attachTools();
    Tools.enabled = o;
    if (o && freeCam != null) freeCam.activate(); // auto-enter fly with debug (toggle off with F)
    // the game HUD makes way for the debug overlay; restored to its prior state on exit
    if (o) {
      hudWasVisible = game.ui.hud.isVisible();
      if (hudWasVisible) game.ui.hud.hide();
      // keep the topbar's perf readout (fps/dc/tri) up over the overlay, forced on
      game.ui.hud.topbar.setDebugStats(true);
    } else {
      if (freeCam != null) freeCam.deactivate();
      Tools.setMode('none');
      game.ui.hud.topbar.setDebugStats(false);
      if (hudWasVisible) game.ui.hud.show();
    }
    if (el != null) el.style.display = o ? 'block' : 'none';
  }

// inject the debug HUD elements the ported tools reference (hidden until debug on)
  function injectHud():Void {
    if (Browser.document.getElementById('view-debug') != null) {
      el = Browser.document.getElementById('view-debug');
      return;
    }
    var d = Browser.document.createElement('div');
    d.id = 'view-debug';
    d.style.display = 'none';
    // cycler rows markup (buttons wired lazily in attachTools)
    var cyc = '';
    for (c in CYCLERS)
      cyc += '<div style="margin-top:2px">' +
        '<span id="cyc-${c.key}-count">${c.label}</span>' +
        '<button id="cyc-${c.key}-prev">&lsaquo;</button>' +
        '<button id="cyc-${c.key}-next">&rsaquo;</button>' +
        (c.copy ? '<button id="cyc-${c.key}-copy">copy</button>' : '') +
        '</div>';
    // inline styling so it reads without the prototype's stylesheet
    d.innerHTML =
      '<style>#check.ok{color:#6f6}#check.bad{color:#f66}' +
      '#cyclers button{background:#222;color:#cde;border:1px solid #555;font:11px monospace;cursor:pointer;margin-left:2px}</style>' +
      '<div style="position:fixed;inset:0;z-index:300;pointer-events:none;font-family:monospace;color:#fff">' +
      '<div style="position:absolute;top:4px;left:8px;font-size:12px"><span id="mode"></span> <span id="editind"></span> <span id="check"></span></div>' +
      '<div id="cyclers" style="position:absolute;bottom:26px;right:8px;font-size:11px;text-align:right;pointer-events:auto">' + cyc + '</div>' +
      '<div id="binfo" style="position:absolute;top:26px;left:8px;white-space:pre;font-size:11px;color:#9f9;max-width:44vw"></div>' +
      '<div id="poly" style="position:absolute;top:26px;right:8px;background:#000c;padding:6px;font-size:12px;pointer-events:auto;display:none"></div>' +
      '<div id="polybar" style="position:absolute;bottom:6px;right:8px;font-size:12px">' +
      '<span id="poly-dirty" style="display:none;color:#fc6">CLASSES UPDATED — Ctrl+C to copy</span> ' +
      '<span id="poly-check" style="display:none;color:#6f6">✓ copied</span></div>' +
      // controls legend (bottom-left), shown whenever street-debug mode is on
      '<div id="help" style="position:absolute;bottom:6px;left:8px;font-size:11px;line-height:1.6;color:#cde;background:#000a;padding:6px 8px;white-space:pre;pointer-events:none">' +
      '`  toggle debug off     F  fly on/off\n' +
      'FLY: WASD move   Space/Q up·down   LMB-drag look   numpad rotate   Shift slow\n' +
      'B  inspect building / ground spot (report → clipboard)\n' +
      'P  probe polygon: click a face → highlight + texture/UV view (upper-right)   G  emissive-face map\n' +
      'E  UV editor   ·   in E-mode: wheel = offset, Ctrl+C copy, R reset\n' +
      '1  WYSIWYG lighting (bloom) toggle\n' +
      '2  ambient   3  hemisphere   4  moon   (fill)   5  lamp point lights\n' +
      '0  all lights on/off     6  kill emissive (self-glow)</div>' +
      '</div>';
    Browser.document.body.appendChild(d);
    el = d;
  }

// attach the debug tools once (camera is persistent; scene/city read via getters)
  function attachTools():Void {
    if (toolsAttached) return;
    freeCam = new FreeCam(getCamera(), canvas);
    Tools.freeCam = freeCam; // __check.goto resolves the fly-cam through this
    Editor.attach(getScene, getCamera(), canvas);
    Inspector.attach(getScene, getCamera(), canvas, getCity, getSeed);
    PolyProbe.attach(getScene, getCamera(), canvas);
    wireCyclers();
    attachDbg();
    toolsAttached = true;
  }

// debug: cycle the free cam through each located feature set (П/turns/L/T/+/shop).
// spots are read from the CURRENT city at click time (the scene rebuilds per area);
// the real player is teleported to the shape's front cell as a scale reference
  function wireCyclers():Void {
    for (c in CYCLERS) {
      var idx = -1;
      var cnt = Browser.document.getElementById('cyc-${c.key}-count');
      function label(n:Int) cnt.textContent = '${c.label}: ${idx + 1}/$n';
      function go(d:Int):Void {
        var spots = c.spots(getCity());
        if (spots.length == 0) {
          idx = -1;
          label(0);
          return;
        }
        idx = (idx + d + spots.length) % spots.length;
        var p = spots[idx];
        if (p.front != null) {
          // stand the player in front for scale (debug teleport, mirrors PlayerArea.loadPost)
          game.playerArea.x = p.front.col;
          game.playerArea.y = p.front.row;
          game.playerArea.entity.setPosition(p.front.col, p.front.row);
        }
        freeCam.focus(p.x, 8, p.z, p.r);
        label(spots.length);
      }
      Browser.document.getElementById('cyc-${c.key}-prev').addEventListener('click', function(_) go(-1));
      Browser.document.getElementById('cyc-${c.key}-next').addEventListener('click', function(_) go(1));
      if (c.copy)
        Browser.document.getElementById('cyc-${c.key}-copy').addEventListener('click', function(_) {
          var spots = c.spots(getCity());
          if (spots.length == 0) return;
          // stale index after an area rebuild: renormalize by stepping once
          if (idx < 0 ||
              idx >= spots.length) go(1);
          var p = spots[idx];
          Inspector.emit(Browser.document.getElementById('binfo'), '[${c.label}]',
            BDump.shape(c.label, getCity(), getSeed(), p.x, p.z, p.r));
        });
      function refresh() {
        idx = -1;
        label(c.spots(getCity()).length);
      }
      cycRefresh.push(refresh);
      refresh();
    }
  }

// console debug helpers (persistent) — replace ad-hoc scene-traversal / camera scripts.
//   __dbg.count('door-cover-')     -> {cls: n, ...}
//   __dbg.find('door-cover-stone') -> [{cls, type, tris, pos, size}]  (size = local w,h,d)
//   __dbg.cam('door-cover-stone')  -> frame free-cam head-on to first match (dist, up optional)
  function attachDbg():Void {
    inline function round2(x:Float):Float return Math.round(x * 100) / 100;
    var tmp = new Vector3();
    // all meshes whose material cls starts with prefix; walls carry a material ARRAY
    // (one cls per face), so return the matched cls alongside the mesh
    function dbgMeshes(prefix:Dynamic):Array<{ o:Dynamic, cls:String }> {
      var out = [];
      getScene().traverse(function(obj) {
        var m:Dynamic = obj.material;
        if (m == null) return;
        var mats:Array<Dynamic> = Std.isOfType(m, Array) ? m : [m];
        for (mm in mats) {
          var cls:String = mm.userData != null ? mm.userData.cls : null;
          if (cls != null &&
              (prefix == null || StringTools.startsWith(cls, prefix))) {
            out.push({ o: obj, cls: cls });
            break;
          }
        }
      });
      return out;
    }
    untyped js.Browser.window.__dbg = {
      find: function(prefix:Dynamic) {
        return dbgMeshes(prefix).map(function(e) {
          var o:Dynamic = e.o;
          var g:Dynamic = o.geometry;
          var tris = g.index != null ? Std.int(g.index.count / 3) : Std.int(g.attributes.position.count / 3);
          o.getWorldPosition(tmp);
          var pos = [round2(tmp.x), round2(tmp.y), round2(tmp.z)];
          g.computeBoundingBox();
          var bb = g.boundingBox;
          var size = [
            round2((bb.max.x - bb.min.x) * o.scale.x),
            round2((bb.max.y - bb.min.y) * o.scale.y),
            round2((bb.max.z - bb.min.z) * o.scale.z),
          ];
          return { cls: e.cls, type: g.type, tris: tris, pos: pos, size: size };
        });
      },
      count: function(prefix:Dynamic) {
        var c:Dynamic = {};
        for (e in dbgMeshes(prefix)) {
          var n = Reflect.field(c, e.cls);
          Reflect.setField(c, e.cls, (n == null ? 0 : n) + 1);
        }
        return c;
      },
      cam: function(cls:Dynamic, ?dist:Float, ?up:Float) {
        var list = dbgMeshes(cls);
        if (list.length == 0) return null;
        var o:Dynamic = list[0].o;
        o.getWorldPosition(tmp);
        var tx = tmp.x;
        var ty = tmp.y;
        var tz = tmp.z;
        o.getWorldDirection(tmp); // mesh local +z in world = outward for covers/walls
        var d = dist != null ? dist : 6.0;
        freeCam.lookFrom(tx + tmp.x * d, ty + (up != null ? up : 2.5), tz + tmp.z * d, tx, ty, tz);
        return { cls: list[0].cls, pos: [round2(tx), round2(ty), round2(tz)] };
      },
    };
  }
}
