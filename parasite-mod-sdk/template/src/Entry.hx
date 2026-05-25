// hello-world mod entry — engine calls init() at boot with per-mod runtime
// the @:expose name below MUST match "exportGlobal" in manifest.json
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
