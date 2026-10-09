package render;

import three.Three;
import js.Browser;
import citygen.CityConfig;
import render.SoundSources.SoundSource;
import render.world.WorldCtx;

// sound mode (Shift+S, inside street-debug; plain S is the fly cam's): a thin green ring at each looping sound source's range, a
// small label over it (kind, base dB, the volume it is playing now) and a panel of every kind. click
// a label or a panel row to select its kind; the wheel moves that kind's base dB (1 dB a notch,
// Shift 0.1) in render.SoundSources.DB, and every kind changed this session goes to the clipboard as
// paste-ready lines. the levels follow the PLAYER, who walks on the arrows while the mode is up;
// the fly cam keeps WASD
class SoundDebug
{
  static var group:Group;
  static var builtFor:Array<SoundSource>;
  static var layer:js.html.DivElement;
  static var panel:js.html.DivElement;
  static var labels:Array<js.html.DivElement> = [];
  static var selected:String;
  static var changed:Map<String, Bool> = [];
  static var flashUntil = 0.0;
  static var _v = new Vector3();

  public static inline function active():Bool return Tools.mode == 'sound';

// install the key, click and wheel handlers once (render.Debug.attachTools)
  public static function attach(camera:PerspectiveCamera, dom:Dynamic):Void
    {
      Tools.legend('sound',
        'Shift+S  leave sound mode   arrows  walk the player (the levels follow them)\n' +
        'LMB  select a source label (or a row of the panel)\n' +
        'wheel  base dB of the selected kind +-1   Shift+wheel  +-0.1   (changes -> clipboard)');
      Browser.window.addEventListener('keydown', function(e:js.html.KeyboardEvent) {
        if (!Tools.enabled ||
            e.code != 'KeyS' ||
            !e.shiftKey ||
            e.ctrlKey ||
            e.metaKey ||
            e.altKey)
          return;
        Tools.setMode(active() ? 'none' : 'sound');
      });
      var downX = 0.0;
      var downY = 0.0;
      dom.addEventListener('mousedown', function(e:js.html.MouseEvent) {
        downX = e.clientX;
        downY = e.clientY;
      });
      // a click (under 4px of drag) selects the label nearest the cursor, within 30px
      dom.addEventListener('mouseup', function(e:js.html.MouseEvent) {
        if (e.button != 0 ||
            !active() ||
            Math.abs(e.clientX - downX) + Math.abs(e.clientY - downY) > 4)
          return;
        var best = 30.0;
        for (i in 0...labels.length)
          {
            var l = labels[i];
            if (l.style.display == 'none')
              continue;
            var r = l.getBoundingClientRect();
            var d = Math.abs(e.clientX - (r.left + r.width / 2)) + Math.abs(e.clientY - (r.top + r.height / 2));
            if (d < best)
              {
                best = d;
                selected = builtFor[i].key;
              }
          }
      });
      Browser.window.addEventListener('wheel', function(e:js.html.WheelEvent) {
        if (!active() ||
            selected == null)
          return;
        e.preventDefault();
        // Shift+wheel arrives as a horizontal scroll on Windows
        var d = (e.deltaY != 0 ? e.deltaY : e.deltaX);
        if (d == 0)
          return;
        var step = (e.shiftKey ? 0.1 : 1.0) * (d < 0 ? 1 : -1);
        var db = SoundSources.DB[selected];
        SoundSources.DB[selected] = Math.round(((db == null ? 0 : db) + step) * 10) / 10;
        changed[selected] = true;
        var keys = [for (k in changed.keys()) k];
        keys.sort(Reflect.compare);
        StreetPerf.copyText([for (k in keys) k + ' ' + fmt(SoundSources.DB[k]) + ' dB'].join('\n'));
        flashUntil = haxe.Timer.stamp() + 1.5;
      }, { passive: false });
    }

// one decimal, always signed: -8.0, +1.5
  static function fmt(v:Float):String
    {
      var r = Math.round(v * 10) / 10;
      var s = Std.string(Math.abs(r));
      if (s.indexOf('.') < 0)
        s += '.0';
      return (r < 0 ? '-' : '+') + s;
    }

// per frame from render.View: hide everything out of the mode, else (re)build the rings when the
// source list changed and re-project the labels
  public static function frame(scene:Scene, camera:PerspectiveCamera):Void
    {
      var on = active();
      if (layer == null)
        {
          if (!on)
            return;
          makeDom();
        }
      layer.style.display = (on ? 'block' : 'none');
      if (group != null)
        group.visible = on;
      if (!on)
        return;
      if (group == null ||
          group.parent != scene ||
          builtFor != SoundSources.sources)
        rebuild(scene);
      // labels: one per source, over its centre
      for (i in 0...builtFor.length)
        {
          var s = builtFor[i];
          var l = labels[i];
          _v.set(s.x, WorldCtx.floorYAt(s.x, s.z) + CityConfig.CELL * 0.6, s.z);
          _v.project(camera);
          if (_v.z > 1 ||
              Math.abs(_v.x) > 1 ||
              Math.abs(_v.y) > 1)
            {
              l.style.display = 'none';
              continue;
            }
          l.style.display = 'block';
          l.style.left = ((_v.x * 0.5 + 0.5) * Viewport.w) + 'px';
          l.style.top = ((-_v.y * 0.5 + 0.5) * Viewport.h) + 'px';
          l.textContent = line(s.key);
          l.style.color = (s.key == selected ? '#ff6' : '#7f7');
        }
      // the panel: every kind in the area, beds included, clickable
      var keys = SoundSources.beds.copy();
      for (s in builtFor)
        if (keys.indexOf(s.key) < 0)
          keys.push(s.key);
      keys.sort(Reflect.compare);
      var html = '';
      for (k in keys)
        html += '<div data-key="' + k + '" style="cursor:pointer;color:' +
          (k == selected ? '#ff6' : '#7f7') + '">' + line(k) + '</div>';
      if (haxe.Timer.stamp() < flashUntil)
        html += '<div style="color:#6f6">✓ copied</div>';
      if (panel.innerHTML != html)
        panel.innerHTML = html;
    }

// a kind's readout: short name, base dB, volume playing now
  static function line(key:String):String
    {
      var db = SoundSources.DB[key];
      var v = SoundSources.vol[key];
      return SoundSources.label(key) + ' ' + fmt(db == null ? 0 : db) + ' dB ' +
        Math.round(v == null ? 0 : v) + '%';
    }

// the label layer and the kind panel, inside #view-debug
  static function makeDom():Void
    {
      var root = Browser.document.getElementById('view-debug');
      layer = Browser.document.createDivElement();
      layer.style.cssText = 'position:fixed;inset:0;z-index:301;pointer-events:none;' +
        'font:10px monospace;text-shadow:0 0 2px #000,0 0 2px #000';
      panel = Browser.document.createDivElement();
      panel.style.cssText = 'position:absolute;top:26px;right:8px;background:#000a;padding:6px 8px;' +
        'font-size:11px;line-height:1.5;pointer-events:auto';
      panel.addEventListener('click', function(e:js.html.MouseEvent) {
        var t:js.html.Element = cast e.target;
        var k = t.getAttribute('data-key');
        if (k != null)
          selected = k;
      });
      layer.appendChild(panel);
      root.appendChild(layer);
    }

// rings and label divs for the current source list (an area build replaces the list)
  static function rebuild(scene:Scene):Void
    {
      if (group != null)
        {
          if (group.parent != null)
            group.parent.remove(group);
          group.traverse(function(o) {
            var m:Mesh = cast o;
            if (m.geometry != null)
              m.geometry.dispose();
          });
        }
      group = new Group();
      var mat = new MeshBasicMaterial({
        color: 0x33ff55,
        transparent: true,
        opacity: 0.8,
        side: THREE.DoubleSide,
        depthWrite: false,
      });
      builtFor = SoundSources.sources;
      for (s in builtFor)
        {
          var r = s.range * CityConfig.CELL;
          var ring = new Mesh(new RingGeometry(r - 0.06, r, 64), mat);
          ring.rotation.x = -Math.PI / 2;
          ring.position.set(s.x, WorldCtx.floorYAt(s.x, s.z) + 0.08, s.z);
          group.add(ring);
        }
      scene.add(group);
      for (l in labels)
        l.remove();
      labels = [];
      for (_ in builtFor)
        {
          var l = Browser.document.createDivElement();
          l.style.cssText = 'position:absolute;transform:translate(-50%,-50%);white-space:nowrap';
          layer.appendChild(l);
          labels.push(l);
        }
    }
}
