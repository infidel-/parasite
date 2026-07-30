// per-mod fx facade — named registry + RAF/canvas/overlay primitives.
// engine = plumbing (registration, dispatch, RAF scheduler, lazy overlay div);
// mods = actual effects (shake, flash, etc.) registered against the engine.
// cross-mod calls work via parasite.fx.play(id, params) — any mod can fire
// any registered fx by id
package mods;

import js.Browser;
import js.html.Element;

// fx implementation contract — registered via parasite.fx.register(id, impl)
typedef FxImpl =
{
  // called by parasite.fx.play(id, params); receives the dynamic params blob
  // the caller passed (schema is whatever the impl documents)
  play: Dynamic -> Void,
  // optional early-stop hook; called by parasite.fx.stop(id). use to cancel
  // in-flight tick channels, reset DOM state, etc.
  ?stop: Void -> Void,
};

class ModFx
{
  var modID: String;
  var prefix: String;

  // global registry shared across all per-mod facades — fx ids are unique
  // across mods by virtue of the mod-<modID>- prefix rule
  static var registry: Map<String, FxImpl> = new Map();
  // missing-id warnings emit once per id to avoid log spam on hot paths
  static var warned: Map<String, Bool> = new Map();
  // tick channel -> in-flight RAF handle; allows tick() to cancel the prior
  // tick on the same channel when re-played
  static var activeChannels: Map<String, Int> = new Map();
  // engine-owned reusable fullscreen overlay div (lazy)
  static var overlayEl: Element = null;

  function new(modID: String)
    {
      this.modID = modID;
      this.prefix = 'mod-' + modID + '-';
    }

// register an fx implementation under id. id must start with mod-<modID>-.
// duplicate id last-wins + warns. impl must have a play function
  public function register(id: String, impl: FxImpl): Void
    {
      if (id == null ||
          !StringTools.startsWith(id, prefix))
        {
          Browser.console.error('[mods] fx register rejected (' + modID +
            '): id "' + id + '" must start with "' + prefix + '"');
          return;
        }
      if (impl == null ||
          !Reflect.isFunction(impl.play))
        {
          Browser.console.error('[mods] fx register rejected (' + modID +
            '): impl.play missing for "' + id + '"');
          return;
        }
      if (registry.exists(id))
        Browser.console.warn('[mods] fx register: id "' + id +
          '" overwritten by ' + modID);
      registry.set(id, impl);
      Browser.console.log('[mods] register fx: ' + modID + '/' + id);
    }

// fire a registered fx by id. params is forwarded as-is to impl.play.
// missing id = warn once, no throw. impl exceptions caught + logged
  public function play(id: String, ?params: Dynamic): Void
    {
      var impl = registry.get(id);
      if (impl == null)
        {
          if (!warned.exists(id))
            {
              warned.set(id, true);
              Browser.console.warn('[mods] fx play: id "' + id +
                '" not registered');
            }
          return;
        }
      try { impl.play(params); }
      catch (e: Dynamic)
        {
          Browser.console.error('[mods] fx play threw (' + id + '): ' + e);
        }
    }

// call registered fx's optional stop() to interrupt early. no-op if the
// fx has no stop hook or is not registered
  public function stop(id: String): Void
    {
      var impl = registry.get(id);
      if (impl == null ||
          impl.stop == null)
        return;
      try { impl.stop(); }
      catch (e: Dynamic)
        {
          Browser.console.error('[mods] fx stop threw (' + id + '): ' + e);
        }
    }

// RAF-based per-frame scheduler. frameFn receives t in [0..1] each frame;
// onDone fires once with frameFn(1.0) called first.
// pass channelID = your fx id to make re-plays interrupt the prior tick on
// that channel (the engine cancels the in-flight RAF before starting a new
// one). without channelID, parallel ticks coexist.
// RAF pauses on tab blur and resumes on return — long fx survive a tab switch
  public function tick(durationMS: Int, frameFn: Float -> Void,
      ?onDone: Void -> Void, ?channelID: String): Void
    {
      // cancel in-flight tick on same channel
      if (channelID != null &&
          activeChannels.exists(channelID))
        {
          Browser.window.cancelAnimationFrame(activeChannels.get(channelID));
          activeChannels.remove(channelID);
        }
      var startTS = haxe.Timer.stamp();
      var loop: Float -> Void = null;
      loop = function(_: Float): Void
        {
          var elapsed = (haxe.Timer.stamp() - startTS) * 1000;
          if (elapsed >= durationMS)
            {
              if (channelID != null)
                activeChannels.remove(channelID);
              try { frameFn(1.0); } catch (e: Dynamic) {}
              if (onDone != null)
                try { onDone(); } catch (e: Dynamic) {}
              return;
            }
          try { frameFn(elapsed / durationMS); }
          catch (e: Dynamic) {}
          var h = Browser.window.requestAnimationFrame(loop);
          if (channelID != null)
            activeChannels.set(channelID, h);
        };
      var h = Browser.window.requestAnimationFrame(loop);
      if (channelID != null)
        activeChannels.set(channelID, h);
    }

// lazy-create and return the engine-owned fullscreen overlay div. mods set
// their own styles per play(); engine owns el lifecycle (one per session,
// reused across mods + ids). div is fixed-position, pointer-events: none,
// z-index 9999, initial opacity 0. last mod to write its styles wins —
// concurrent fullscreen flashes from different mods will stomp each other
  public function overlay(): Element
    {
      if (overlayEl == null)
        {
          overlayEl = Browser.document.createDivElement();
          overlayEl.style.cssText = 'position:fixed;left:0;top:0;right:0;bottom:0;'
            + 'pointer-events:none;opacity:0;z-index:9999;';
          Browser.document.body.appendChild(overlayEl);
        }
      return overlayEl;
    }

// get the game's 2D #canvas element (may be null pre-scene). note this is the 2D canvas
// SPECIFICALLY — in a 3D area it is completely covered by #view, so viewport-anchored fx
// (camera shake) want viewport() below instead
  public function canvas(): Element
    {
      return Browser.document.getElementById('canvas');
    }

// get the canvas the game is currently drawing into: the 3D view canvas while a 3D area is
// shown, else the 2D #canvas. fx that anchor on the rendered viewport (e.g. camera shake via
// CSS transform) must use this — #view fully covers #canvas, so transforming #canvas alone is
// invisible in a 3D area. render.View toggles that display, so this tracks its `running`
  public function viewport(): Element
    {
      var v = Browser.document.getElementById('view');
      if (v != null &&
          v.style.display != 'none')
        return v;
      return Browser.document.getElementById('canvas');
    }

// builds a per-mod fx facade; called by ModLoader per import
  public static function forMod(modID: String): ModFx
    {
      return new ModFx(modID);
    }
}
