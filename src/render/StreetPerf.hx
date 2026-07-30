package render;

import three.Three;
import js.Browser;

// 3D-view perf instrumentation, split out of render.View so the view stays about rendering.
// owns the frame breakdown (submit/upd/idle), the real GPU timer, the on-screen HUD with its
// peak-hold, the renderer.info stat capture, and the debug keys 7 (shadow-sampling A/B),
// 8 (peak reset), 9 (draw-call breakdown dump). live under street-debug mode (`) or `perf street`
class StreetPerf {
  public static var lastCalls = 0; // draw calls last frame (HUD counter, when vidShowFps)
  public static var lastTris = 0;  // triangles drawn last frame (HUD counter, when vidShowFps)
  // GPU-resource counts (no byte API in WebGL) — a steady climb across area re-entries == a leak
  public static var lastGeo = 0;   // live geometries in the renderer's cache
  public static var lastTex = 0;   // live textures in the renderer's cache
  public static var lastProg = 0;  // compiled shader programs

  var renderer:WebGLRenderer;
  var getScene:Void->Scene;
  var debugOn = false;             // street-debug mode state, refreshed each frame by the caller
  var shadowsOff = false;          // Digit7: kill real shadow SAMPLING (shadowMap.enabled) for the perf A/B
  var perfDiv:js.html.Element = null; // lazily-built on-screen overlay
  var _lastProgs = 0;              // program count last frame; a jump == a (re)compile stall
  var _perfTick = 0;               // trace sampling counter — only every Nth frame prints
  // peak-hold: latch the WORST frame's full breakdown so a transient spike stays readable (reset: Digit8)
  var peakFrame = 0.0;
  var peakSubmit = 0.0;
  var peakUpd = 0.0;   // update-CPU at the peak frame
  var peakIdle = 0.0;  // vsync/compositor idle-wait at the peak frame
  var peakCalls = 0;
  var peakTris = 0;
  var peakShB = 0;     // shadow backlog at the peak frame
  var peakHeap = 0;    // js heap MB at the peak frame (compare to the live heap: a big gap hints a GC hit)
  var peakGpu = 0.0;   // real GPU ms at the peak frame
  var peakStamp = 0.0; // when the current peak was latched — rolls to the recent worst over a ~3s window
  // GPU timer (EXT_disjoint_timer_query_webgl2): the only honest signal once the cpu is just blocking on
  // the driver — submit/idle then only record WHERE it blocked, not the cost. results lag a few frames
  var glCtx:Dynamic = null;
  var timerExt:Dynamic = null;
  var gpuTried = false;
  var gpuPending:Array<Dynamic> = []; // queries awaiting readback, in submit order
  var gpuFree:Array<Dynamic> = [];    // reusable query objects
  var gpuQuery:Dynamic = null;        // the query opened by beginRender, closed by endRender
  var lastGpuMs = 0.0;

  public function new(renderer:WebGLRenderer, getScene:Void->Scene)
    {
      this.renderer = renderer;
      this.getScene = getScene;
    }

// is the instrumentation live? debug mode (`) or the `perf street` console toggle — the latter does
// NOT lock game input, so the HUD can be read while walking
  public inline function active():Bool
    return debugOn || render.Actors.DEBUG_PERF;

// handle a perf debug hotkey (only while street-debug mode is on); true if consumed
  public function onKey(code:String):Bool
    {
      var scene = getScene();
      if (scene == null)
        return false;
      switch (code)
        {
          // 7: A/B — kill real shadow SAMPLING, not just map generation. the main pass samples all 9 shadow
          // maps per fragment (PCF), which is the GPU fill cost; freezing the maps never touched it. toggling
          // shadowMap.enabled changes the program key, so force a rebuild (one compile stall, then true cost)
          case 'Digit7':
            shadowsOff = !shadowsOff;
            untyped renderer.shadowMap.enabled = !shadowsOff;
            scene.traverse(function(o)
              {
                var m:Dynamic = o.material;
                if (m == null)
                  return;
                var mats:Array<Dynamic> = Std.isOfType(m, Array) ? m : [m];
                for (mm in mats)
                  mm.needsUpdate = true;
              });
            trace('[shadows] sampling ' + (shadowsOff ? 'OFF' : 'ON'));
            return true;
          // 8: reset the peak-hold (clear the latched worst frame)
          case 'Digit8':
            peakFrame = 0;
            peakSubmit = 0;
            peakUpd = 0;
            peakIdle = 0;
            peakCalls = 0;
            peakTris = 0;
            return true;
          case 'Digit9':
            dumpScene(scene);
            return true;
          default:
            return false;
        }
    }

// one-shot draw-call breakdown — group every drawable three would actually reach by material, sorted
// desc. names what fills the ~490 draws, so batching effort goes where the draws really are
  function dumpScene(scene:Scene):Void
    {
      var byName = new Map<String,Int>();
      var total = 0;
      var drawables = 0;
      scene.traverse(function(o)
        {
          total++;
          var d:Dynamic = o;
          if (d.isMesh != true && d.isInstancedMesh != true)
            return;
          if (!reached(o))
            return;
          drawables++;
          var m:Dynamic = d.material;
          var key:String;
          if (m == null)
            key = 'no-material';
          else if (Std.isOfType(m, Array))
            {
              var arr:Array<Dynamic> = m;
              key = 'matArray[' + arr.length + '] ' + matCls(arr[0]);
            }
          else
            key = matCls(m);
          // bucket instance counts (exact counts fragment the report into noise)
          if (d.isInstancedMesh == true)
            key += ' INST' + (d.count <= 1 ? '=1' : (d.count <= 4 ? '=2-4' : (d.count <= 32 ? '=5-32' : '>32')));
          byName.set(key, (byName.exists(key) ? byName.get(key) : 0) + 1);
        });
      var rows = [for (k in byName.keys()) { name: k, n: byName.get(k) }];
      rows.sort(function(a, b) return b.n - a.n);
      var buf = new StringBuf();
      buf.add('[scene-dump] sceneObjects=' + total + ' visibleDrawables=' + drawables
        + ' geo=' + lastGeo + ' tex=' + lastTex + ' prog=' + lastProg);
      for (r in rows)
        buf.add('\n  ' + r.n + '  x  ' + r.name);
      var txt = buf.toString();
      trace(txt + '\n(copied to clipboard)');
      copyText(txt);
    }

// would three's projectObject descend to this object at all? it early-outs on the first invisible
// ANCESTOR, so an object's own .visible proves nothing on its own — the chunk cull hides whole parent
// groups and leaves every child visible=true. walk up to the root, the same test three applies down
  static function reached(o:Object3D):Bool
    {
      var n:Object3D = o;
      while (n != null)
        {
          if (!n.visible)
            return false;
          n = n.parent;
        }
      return true;
    }

// open a GPU timer query around the composer render (free when not profiling). only ONE TIME_ELAPSED
// query may be in flight, so this is strictly one begin/end per frame
  public function beginRender(debugOn:Bool):Void
    {
      this.debugOn = debugOn;
      if (!active())
        return;
      if (!gpuTried)
        {
          gpuTried = true;
          glCtx = untyped renderer.getContext();
          timerExt = glCtx.getExtension('EXT_disjoint_timer_query_webgl2');
        }
      if (timerExt == null)
        return;
      gpuQuery = gpuFree.length > 0 ? gpuFree.pop() : glCtx.createQuery();
      glCtx.beginQuery(timerExt.TIME_ELAPSED_EXT, gpuQuery);
    }

// close the in-flight query and drain any finished ones into lastGpuMs. a GPU_DISJOINT result means the
// driver descheduled mid-measure, so that sample is garbage and gets dropped rather than reported
  public function endRender():Void
    {
      if (gpuQuery == null)
        return;
      glCtx.endQuery(timerExt.TIME_ELAPSED_EXT);
      gpuPending.push(gpuQuery);
      gpuQuery = null;
      while (gpuPending.length > 0)
        {
          var head = gpuPending[0];
          if (!glCtx.getQueryParameter(head, untyped glCtx.QUERY_RESULT_AVAILABLE))
            break;
          gpuPending.shift();
          if (!glCtx.getParameter(timerExt.GPU_DISJOINT_EXT))
            lastGpuMs = glCtx.getQueryParameter(head, untyped glCtx.QUERY_RESULT) / 1e6;
          gpuFree.push(head);
        }
    }

// end of frame: capture the renderer stats (always — the HUD topbar reads them), then draw the perf
// overlay + print the sampled trace while profiling. submit = cpu cost to queue the composer render
// (headroom, NOT gpu frame time — GL is async), upd = all pre-render work, idle = the vsync leftover
  public function report(dtMs:Float, submit:Float, updateMs:Float):Void
    {
      lastCalls = renderer.info.render.calls; // scene + a few post-FX quads
      lastTris = renderer.info.render.triangles;
      // memory.* survives info.reset(), only the render counters reset — leak signal
      lastGeo = renderer.info.memory.geometries;
      lastTex = renderer.info.memory.textures;
      lastProg = (renderer.info.programs != null ? renderer.info.programs.length : 0);
      if (!active())
        {
          if (perfDiv != null)
            perfDiv.style.display = 'none';
          return;
        }
      var idleMs = dtMs - updateMs - submit; // leftover = vsync/compositor wait (external stall, NOT engine cpu)
      if (idleMs < 0)
        idleMs = 0;                          // clamp small measurement skew
      var fps = dtMs > 0.01 ? r2(1000 / dtMs) : 0;
      var mem:Dynamic = untyped js.Browser.window.performance.memory; // non-standard API — untyped
      var heapMB = mem != null ? Math.round(mem.usedJSHeapSize / 1048576) : 0;
      var shR = render.particles.LampLights.lastShadowRenders;
      var shB = render.particles.LampLights.lastShadowBacklog;
      hud(fps, dtMs, submit, updateMs, idleMs, heapMB, shR, shB);
      if (!render.Actors.DEBUG_PERF || _perfTick++ % 20 != 0)
        return;
      var compiled = lastProg - _lastProgs;
      // upd big -> engine update path; idle big w/ small submit+upd -> external stall, not our cpu
      trace('[street-render] frame=' + r2(dtMs) + 'ms(' + fps + 'fps) GPU=' + r2(lastGpuMs) +
        ' submit=' + r2(submit) + ' upd=' + r2(updateMs) + ' idle=' + r2(idleMs) +
        ' calls=' + lastCalls + ' tris=' + lastTris + ' programs=' + lastProg +
        ' shdw=' + shR + '/' + shB + ' heap=' + heapMB + 'M' +
        (compiled != 0 ? ' (COMPILE ' + (compiled > 0 ? '+' : '') + compiled + ')' : ''));
      _lastProgs = lastProg;
    }

// on-screen overlay: live fps/submit/draw/heap + a prominent SHADOWS(7) state. lazily builds one fixed
// div, then just rewrites its text each frame
  function hud(fps:Float, frameMs:Float, submit:Float, updateMs:Float, idleMs:Float, heapMB:Int, shR:Int, shB:Int):Void
    {
      if (perfDiv == null)
        {
          perfDiv = Browser.document.createElement('div');
          perfDiv.style.cssText = 'position:fixed;left:8px;top:8px;z-index:99999;padding:6px 9px;'
            + 'font:11px/1.45 monospace;color:#cfe;background:rgba(0,0,0,0.62);white-space:pre;'
            + 'pointer-events:none;border-radius:3px;';
          Browser.document.body.appendChild(perfDiv);
        }
      perfDiv.style.display = 'block';
      // latch the worst frame so a transient spike stays readable; roll to the recent worst over a ~3s
      // window (beat it -> re-latch and extend; window expires with no spike -> fall back to current)
      var now = haxe.Timer.stamp();
      if (frameMs >= peakFrame || now - peakStamp > 3.0)
        {
          peakFrame = frameMs;
          peakSubmit = submit;
          peakUpd = updateMs;
          peakIdle = idleMs;
          peakCalls = lastCalls;
          peakTris = lastTris;
          peakShB = shB;
          peakHeap = heapMB;
          peakGpu = lastGpuMs;
          peakStamp = now;
        }
      var shCol = shadowsOff ? '#ff8a5c' : '#8cff8c';
      var shTxt = shadowsOff ? 'OFF (sampling killed)' : 'ON';
      var fCol = frameMs > 20 ? '#ff8a5c' : '#cfe';
      // bold the dominant third of the peak: submit=render, upd=engine update, idle=external vsync/stall
      var pMax = Math.max(peakSubmit, Math.max(peakUpd, peakIdle));
      function b(v:Float):String return (v >= pMax ? '<b>' + r2(v) + '</b>' : '' + r2(v));
      perfDiv.innerHTML =
        'FPS ' + fps + '   <b style="color:' + fCol + '">frame ' + r2(frameMs) + 'ms</b> (budget 16.7)\n'
        + 'submit ' + r2(submit) + '  upd ' + r2(updateMs) + '  idle ' + r2(idleMs) + '\n'
        + '<b style="color:' + (lastGpuMs > 14 ? '#ff8a5c' : '#8cff8c') + '">GPU ' + r2(lastGpuMs) + 'ms</b> (real, budget 16.7)\n'
        + 'calls ' + lastCalls + '  tris ' + lastTris + '  prog ' + lastProg + '\n'
        + 'shdw ' + shR + '/' + shB + '   heap ' + heapMB + 'M\n'
        + '<span style="color:#ffd27f">PEAK~3s ' + r2(peakFrame) + 'ms  submit ' + b(peakSubmit)
        + '  upd ' + b(peakUpd) + '  idle ' + b(peakIdle) + '  GPU ' + r2(peakGpu) + '</span>\n'
        + 'SHADOWS(7): <b style="color:' + shCol + '">' + shTxt + '</b>';
    }

// a material's Poly.tag class (userData.cls) for the scene dump — the only meaningful label on these
// materials; falls back to name then type
  public static function matCls(m:Dynamic):String
    {
      if (m == null)
        return '?';
      if (m.userData != null && m.userData.cls != null)
        return m.userData.cls;
      if (m.name != null && m.name != '')
        return m.name;
      return m.type;
    }

// copy text to the OS clipboard (debug dumps). a keydown is a user gesture, so the async clipboard API
// is allowed; the sandboxed preload exposes no node clipboard, so fall back to textarea+execCommand
  static function copyText(s:String):Void
    {
      var nav:Dynamic = js.Browser.navigator;
      if (nav.clipboard != null)
        {
          nav.clipboard.writeText(s).then(null, function(_:Dynamic) copyFallback(s));
          return;
        }
      copyFallback(s);
    }

// legacy clipboard path: a throwaway offscreen textarea, selected and copied, then removed
  static function copyFallback(s:String):Void
    {
      var ta = js.Browser.document.createTextAreaElement();
      ta.value = s;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      js.Browser.document.body.appendChild(ta);
      ta.select();
      untyped js.Browser.document.execCommand('copy');
      js.Browser.document.body.removeChild(ta);
    }

// round a float to 2 decimals for perf logging
  public static inline function r2(v:Float):Float
    {
      return Std.int(v * 100) / 100;
    }
}
