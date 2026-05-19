// testmod entry — verifies init() runs and ModContentApi.registerItem works via SDK externs
package;

import mods.ModRuntime;

// custom item class — extends engine ItemInfo via window.parasiteHx.ItemInfo (SDK extern)
class ModTestItem extends ItemInfo
{
  public function new(game: Dynamic)
    {
      super(game);
      id = 'mod-testmod-modtest';
      type = 'misc';
      name = 'mod test trinket';
      unknown = 'odd trinket';
    }
}

@:expose("testmod_Entry")
class Entry
{
  public static function main() {}

// boot hook — receives per-mod parasite runtime object (mod-design.md §8.2)
  public static function init(parasite: ModRuntime)
    {
      var c = js.Browser.console;
      c.log('[testmod] init() called');
      c.log('[testmod] parasite.modID = ' + parasite.modID);
      c.log('[testmod] parasite.modVersion = ' + parasite.modVersion);
      c.log('[testmod] parasite.modApiVersion = ' + parasite.modApiVersion);
      c.log('[testmod] parasite.version = ' + parasite.version);
      c.log('[testmod] parasite.game? ' + (parasite.game != null));
      c.log('[testmod] parasite.host? ' + (parasite.host != null));

      parasite.api.registerItem(ModTestItem);

      var ItemsConst: Dynamic = Reflect.field(parasite.hxClasses, 'const.ItemsConst');
      c.log('[testmod] mod-testmod-modtest in infos? ' +
        ItemsConst.infos.exists('mod-testmod-modtest'));

      // pedia registration smoke (§8.7.1 Phase A) — group + article ids
      // must both start with `mod-testmod-`; missing prefix = rejection
      parasite.api.registerPediaEntry({
        id: 'mod-testmod-group',
        name: 'Testmod',
        articles: [
          {
            id: 'mod-testmod-hello',
            name: 'Hello from testmod',
            text: 'this article was added at runtime by testmod via ' +
              'parasite.api.registerPediaEntry()',
          },
        ],
      });
      var PediaConst: Dynamic = Reflect.field(parasite.hxClasses,
        'const.PediaConst');
      c.log('[testmod] pedia group present? ' +
        (PediaConst.getGroup('mod-testmod-group') != null));
      c.log('[testmod] pedia article present? ' +
        (PediaConst.getArticle('mod-testmod-hello') != null));

      // prefix-rejection smoke — should log a reject, NOT register
      parasite.api.registerPediaEntry({
        id: 'badprefix-group',
        name: 'Bad',
        articles: [{ id: 'badprefix-art', name: 'x', text: 'x' }],
      });

      // settings smoke — boot counter; first launch = 1, subsequent = N+1
      var n = parasite.settings.getInt('boots');
      parasite.settings.set('boots', n + 1);
      c.log('[testmod] settings.boots was ' + n + ', now ' +
        parasite.settings.getInt('boots'));

      // asset override smoke (§8.6) — resolve() should return mod:// URLs for assets we shipped
      var AP: Dynamic = Reflect.field(parasite.hxClasses, 'mods.AssetPath');
      c.log('[testmod] resolve(img/mouse0.png) = ' + AP.resolve('img/mouse0.png'));
      c.log('[testmod] resolve(img/mouse1.png) = ' + AP.resolve('img/mouse1.png'));
      c.log('[testmod] resolve(sound/action-fail.mp3) = ' + AP.resolve('sound/action-fail.mp3'));
    }
}
