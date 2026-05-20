// console give evolution command (learn improvement at level)
package console;

import const.EvolutionConst;
import const.EvolutionConst.ImprovInfo;

class GiveEvolution extends GiveBase
{
// learns an improvement: give evolution [name] [level]
  public function run(args: String)
    {
      var entries = buildEntries();
      if (args == '')
        {
          log('Usage: give evolution [name] [level]');
          log('Improvements: ' + listEntryNames(entries));
          return;
        }
      var partsRaw = args.split(' ');
      var parts = [];
      for (part in partsRaw)
        if (part != '')
          parts.push(part);
      if (parts.length == 0)
        {
          log('Usage: give evolution [name] [level]');
          return;
        }
      var level = -1;
      var tail = parts[parts.length - 1];
      var maybeLevel = Std.parseInt(tail);
      if (maybeLevel != null)
        {
          level = maybeLevel;
          parts.pop();
        }
      var query = parts.join(' ');
      if (query == '')
        {
          log('Usage: give evolution [name] [level]');
          return;
        }
      var match = selectMatch('improvement', query, entries);
      if (match == null)
        return;
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
          log('Improvement info not found.');
          return;
        }
      var targetLevel = level;
      if (targetLevel < 0 || targetLevel > info.maxLevel)
        targetLevel = info.maxLevel;
      game.player.evolutionManager.addImprov(match.value, targetLevel);
      log('Learned ' + info.name + ' ' + targetLevel);
    }

// builds improvement entries for selection
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
          if (info == null)
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
