// console mods command helper — list/enable/disable/errors for sideload + workshop mods
package console;

import game.Game;
import mods.ModRegistry;

class Mods
{
  public var console: Console;
  var game: Game;

// sets up mods command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// handles mods command routing: list (default) / enable / disable / errors
  public function run(arr: Array<String>): Bool
    {
      if (arr[0] != 'mods' && arr[0] != 'mo')
        return false;

      if (arr.length == 1)
        {
          printMods();
          return true;
        }
      var sub = arr[1];
      if (sub == 'list')
        printMods();
      else if (sub == 'errors' || sub == 'err')
        printModErrors();
      else if (sub == 'enable' || sub == 'disable')
        {
          if (arr.length < 3)
            {
              log('Usage: mods ' + sub + ' <id>');
              return true;
            }
          toggleMod(arr[2], sub == 'enable');
        }
      else
        log('Usage: mods [list|enable &lt;id&gt;|disable &lt;id&gt;|errors]');
      return true;
    }

// print mod status table (all discovered mods with enabled/disabled/failed)
  function printMods()
    {
      if (ModRegistry.all.length == 0)
        {
          log('No mods discovered.');
          return;
        }
      var disabled = new Map<String, Bool>();
      for (id in game.profile.object.disabledMods)
        disabled.set(id, true);
      var enabledSet = new Map<String, Bool>();
      for (info in ModRegistry.enabled)
        enabledSet.set(info.id, true);
      var buf = new StringBuf();
      buf.add('Mods (' + ModRegistry.all.length + '):<br/>');
      for (info in ModRegistry.all)
        {
          var status =
            if (ModRegistry.failed.exists(info.id)) 'failed';
            else if (disabled.exists(info.id)) 'disabled';
            else if (enabledSet.exists(info.id)) 'enabled';
            else 'inactive';
          buf.add('  ' + info.id + ' v' + info.version +
            ' [' + status + '] (' + info.source + ')<br/>');
        }
      log(buf.toString());
    }

// toggle mod in profile.disabledMods; takes effect on next renderer reload
  function toggleMod(id: String, enable: Bool)
    {
      if (ModRegistry.byID(id) == null)
        {
          log('Mod [' + id + '] not found.');
          return;
        }
      var list = game.profile.object.disabledMods;
      var idx = list.indexOf(id);
      if (enable)
        {
          if (idx < 0)
            {
              log('Mod [' + id + '] already enabled.');
              return;
            }
          list.splice(idx, 1);
        }
      else
        {
          if (idx >= 0)
            {
              log('Mod [' + id + '] already disabled.');
              return;
            }
          list.push(id);
        }
      game.profile.save();
      log('Mod [' + id + '] ' + (enable ? 'enabled' : 'disabled') +
        '. Reload (Ctrl-F5) to apply.');
    }

// print per-mod failure reasons recorded during scan/load/init
  function printModErrors()
    {
      if (Lambda.count(ModRegistry.failed) == 0)
        {
          log('No mod errors.');
          return;
        }
      var buf = new StringBuf();
      buf.add('Mod errors:<br/>');
      for (id in ModRegistry.failed.keys())
        buf.add('  ' + id + ': ' + ModRegistry.failed.get(id) + '<br/>');
      log(buf.toString());
    }

// log helper — delegates to owning console
  inline function log(s: String)
    {
      console.log(s);
    }
}
