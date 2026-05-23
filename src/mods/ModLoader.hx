// renderer-side mod loader
package mods;

import game.Game;
import js.Browser.console;

class ModLoader
{
  static var game: Game;

// sync boot phase: must run before any engine code that resolves an asset path
// (e.g. Images ctor in scene.init()). populates registry + settings + AssetPath
// so the later async load() phase only handles dynamic-imports + init() calls
  public static function preInit(g: Game)
    {
      game = g;
#if electron
      console.log('[mods] ModLoader.preInit: requesting list from main');
      // expose engine $hxClasses registry on window for mod externs to extend engine classes
      // (mod IIFE shadows local $hxClasses; needs a stable global ref before module-load extends evaluates)
      js.Syntax.code("window.parasiteHx = $hxClasses");
      var raw = HostBridge.modsList();
      ModRegistry.init(game, raw);
      ModSettings.init(game);
      ModSaveData.init(game);

      // populate AssetPath from each enabled mod's assets[] in toposorted order.
      // last writer wins resolve() lookups — matches load() init() order
      for (info in ModRegistry.enabled)
        {
          if (info.assets == null) continue;
          for (rel in info.assets)
            {
              AssetPath.register(info.id, rel);
              console.log('[mods] asset override: ' + rel + ' <- ' + info.id);
            }
        }

      // inject mod.css <link>s in load order, appended to <head> after the
      // engine's static stylesheets so later rules win on equal specificity.
      // later mods stomp earlier mods (cascade order = load order)
      for (info in ModRegistry.enabled)
        {
          if (!info.hasModCss) continue;
          var link = js.Browser.document.createLinkElement();
          link.rel = 'stylesheet';
          link.href = 'mod://' + info.id + '/mod.css';
          js.Browser.document.head.appendChild(link);
          console.log('[mods] mod.css loaded: ' + info.id);
        }
#end
    }

// async boot phase: dynamic-import each enabled mod entry, build per-mod parasite
// object, call init() in try/catch. preInit(g) MUST have already run
  public static function load(g: Game): js.lib.Promise<Dynamic>
    {
#if electron
      var enabled = ModRegistry.enabled;
      if (enabled.length == 0) {
        console.log('[mods] no enabled mods, skipping load phase');
        return js.lib.Promise.resolve(null);
      }

      // sequential load — keeps logs ordered, errors per-mod isolated
      console.log('[mods] loading ' + enabled.length + ' mod(s) sequentially');
      var chain: js.lib.Promise<Dynamic> = js.lib.Promise.resolve(null);
      for (info in enabled)
        {
          var captured = info;
          chain = chain.then(function(_) return loadOne(captured));
        }
      return chain.then(function(_) {
        console.log('[mods] all mod loads complete');
        // rebuild pedia DOM so mod-registered groups/articles appear
        // (Pedia ctor ran before mods registered; needs re-population)
        if (game.ui != null)
          game.ui.pedia.rebuild();
        return null;
      });
#else
      return js.lib.Promise.resolve(null);
#end
    }

// import one mod's entry module, build per-mod parasite object, call init() in try/catch
  static function loadOne(info: ModInfo): js.lib.Promise<Dynamic>
    {
      var url = 'mod://' + info.id + '/' + info.entry;
      console.log('[mods] load: ' + info.id + ' v' + info.version + ' <- ' + url);

      // build per-mod parasite object
      var parasite: ModRuntime = {
        modID: info.id,
        modVersion: info.version,
        modApiVersion: Const.MOD_API_VERSION,
        game: game,
        host: js.Syntax.code("window.host"),
        hxClasses: js.Syntax.code("$hxClasses"),
        version: Version.getVersion(),
        api: ModContentApi.forMod(info.id),
        settings: ModSettings.api(info.id),
        savedata: ModSaveData.api(info.id),
        events: ModEvents.forMod(info.id),
        fx: ModFx.forMod(info.id),
      };

      var promise: js.lib.Promise<Dynamic> =
        js.Syntax.code("import({0})", url);

      return promise
        .then(function(_) {
          try {
            // import() ran the entry for its side effect: Haxe @:expose put the
            // mod class on window[exportGlobal]. read it there and call init().
            // (Haxe emits a plain script, not an ESM with a named export, so the
            // module namespace is empty — the window global is the contract.)
            var mod: Dynamic = js.Syntax.code("window[{0}]", info.exportGlobal);
            if (mod != null &&
                Reflect.isFunction(mod.init)) {
              console.log('[mods] calling init() for ' + info.id);
              mod.init(parasite);
              console.log('[mods] init() returned for ' + info.id);
            }
            else
              fail(info, 'window.' + info.exportGlobal +
                ' has no init() — exportGlobal must match the @:expose("...") name');
            return null;
          }
          catch (e: Dynamic)
            {
              fail(info, 'init() threw: ' + e, e);
              return null;
            }
        })
        .catchError(function(e: Dynamic) {
          fail(info, 'import failed: ' + e, e);
          return null;
        });
    }

// mark mod failed in registry + emit error to devtools console + session log.
// pass the live error object as `err` so devtools rewrites its stack via the
// mod's source map (string-only stacks aren't rewritten by devtools)
  static function fail(info: ModInfo, msg: String, ?err: Dynamic)
    {
      ModRegistry.markFailed(info.id, msg);
      if (err != null)
        console.error('[mods] MOD ERROR [' + info.id + '] ' + msg, err);
      else
        console.error('[mods] MOD ERROR [' + info.id + '] ' + msg);
#if electron
      // session log is text-only, so flatten the stack into the message here
      var stack: Dynamic = (err != null ? err.stack : null);
      var full = msg + (stack != null ? '\n' + stack : '');
      try { HostBridge.logAppend('MOD ERROR [' + info.id + '] ' + full + '\n'); }
      catch (e: Dynamic) {}
#end
    }
}
