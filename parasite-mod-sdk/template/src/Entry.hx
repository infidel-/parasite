// hello-world mod entry — engine calls init() at boot with per-mod runtime
// rename @:expose to match EXPOSE_NAME in Makefile
package;

import mods.ModRuntime;

import js.Browser.console;

@:expose("yourmod_Entry")
class Entry
{
  public static function main() {}

// boot hook — receives per-mod parasite runtime
  public static function init(parasite: ModRuntime)
    {
      console.log('[yourmod] hello from ' + parasite.modID +
        ' v' + parasite.modVersion);
    }
}
