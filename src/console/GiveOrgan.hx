// console give organ command
package console;

import const.EvolutionConst;
import const.EvolutionConst.ImprovInfo;

class GiveOrgan extends GiveBase
{
// gives an organ improvement to the current host and completes it
  public function run(args: String)
    {
      var entries = buildEntries();
      if (args == '')
        {
          log('Organs: ' + listEntryNames(entries));
          return;
        }
      var match = selectMatch('organ', args, entries);
      if (match == null)
        return;
      if (game.player.state != PLR_STATE_HOST)
        {
          log('Not on host.');
          return;
        }
      var info: ImprovInfo = null;
      try {
        info = EvolutionConst.getInfo(match.value);
      }
      catch (e: Dynamic)
        {
          info = null;
        }
      if (info == null)
        {
          log('Improvement [' + match.name + '] not found.');
          return;
        }
      if (info.organ == null)
        {
          log('Improvement [' + match.name + '] has no organ.');
          return;
        }
      game.player.evolutionManager.addImprov(match.value, info.maxLevel);
      game.player.host.organs.action('set.' + Std.string(match.value));
      game.player.host.organs.debugCompleteCurrent();
      game.log('Organ added: ' + info.organ.name + '.');
    }

// builds organ entries for selection
  public function buildEntries(): Array<ConsoleAddEntry<_Improv>>
    {
      var list = [];
      for (improv in Type.allEnums(_Improv))
        {
          var info: ImprovInfo = null;
          try {
            info = EvolutionConst.getInfo(improv);
          }
          catch (e: Dynamic)
            {
              info = null;
            }
          if (info == null || info.organ == null)
            continue;
          var name = Std.string(improv).substr(4).toLowerCase();
          list.push({
            name: name,
            searchKey: normalizeKey(name),
            value: improv
          });
        }
      list.sort(function(a, b)
        {
          return compareStrings(a.name, b.name);
        });
      return list;
    }
}
