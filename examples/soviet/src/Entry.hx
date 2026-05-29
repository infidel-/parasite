// soviet — pure-CSS UI overhaul mod; mod.css does all the work, init only logs
package;

import mods.ModRuntime;

import js.Browser.console;

@:expose("soviet_Entry")
class Entry
{
  public static function main() {}

// boot hook — engine loads mod.css automatically; this just confirms init ran
  public static function init(parasite: ModRuntime)
    {
      console.log('[soviet] Soviet CRT UI applied (mod.css)');
    }
}
