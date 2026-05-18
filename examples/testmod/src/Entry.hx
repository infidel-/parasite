// testmod entry — verifies init() runs and ModContentApi.registerItem works
package;

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

      // build synthetic ItemInfo subclass via ES6 class extends (ItemInfo compiled with -D js-es=6)
      // untyped js.Syntax escape until SDK externs land (§14 step 11)
      var ItemInfo: Dynamic = Reflect.field(parasite.hxClasses, 'ItemInfo');
      var ctor: Dynamic = js.Syntax.code(
        "(function(SUPER){var f=class ModTestItem extends SUPER{constructor(g){super(g);this.id='modtest';this.type='misc';this.name='mod test trinket';this.unknown='odd trinket';}};f.__name__='testmod.ModTestItem';return f;})({0})",
        ItemInfo);
      parasite.api.registerItem(ctor);

      var ItemsConst: Dynamic = Reflect.field(parasite.hxClasses, 'const.ItemsConst');
      c.log('[testmod] modtest in infos? ' + ItemsConst.infos.exists('modtest'));
    }
}
