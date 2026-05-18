package mods;

// renderer-side mod loader
// dynamic-imports each enabled mod entry, builds per-mod parasite object,
// calls init() in try/catch
// see mod-design.md §5, §8.1, §8.2, §11

import game.Game;
import js.Browser.console;

class ModLoader
{
  static var game: Game;

// boot-time entry: request mod list from main, sequentially import + init each enabled mod
  public static function load(g: Game): js.lib.Promise<Dynamic>
    {
      game = g;
#if electron
      console.log('[mods] ModLoader.load: requesting list from main');
      var raw = HostBridge.modsList();
      ModRegistry.init(game, raw);

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
      };

      var promise: js.lib.Promise<Dynamic> =
        js.Syntax.code("import({0})", url);

      return promise
        .then(function(mod: Dynamic) {
          try {
            // call init() if exported
            if (mod != null &&
                Reflect.isFunction(mod.init)) {
              console.log('[mods] calling init() for ' + info.id);
              mod.init(parasite);
              console.log('[mods] init() returned for ' + info.id);
            }
            else
              console.warn('[mods] ' + info.id + ': no init() export, nothing to call');
            return null;
          }
          catch (e: Dynamic)
            {
              fail(info, 'init() threw: ' + e);
              return null;
            }
        })
        .catchError(function(e: Dynamic) {
          fail(info, 'import failed: ' + e);
          return null;
        });
    }

// mark mod failed in registry + emit error to devtools console + session log
  static function fail(info: ModInfo, msg: String)
    {
      ModRegistry.markFailed(info.id, msg);
      console.error('[mods] MOD ERROR [' + info.id + '] ' + msg);
#if electron
      try { HostBridge.logAppend('MOD ERROR [' + info.id + '] ' + msg + '\n'); }
      catch (e: Dynamic) {}
#end
    }
}
