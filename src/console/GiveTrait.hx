// console give trait command
package console;

import const.TraitsConst;

class GiveTrait extends GiveBase
{
// gives a trait to the current host
  public function run(args: String)
    {
      var entries = buildEntries();
      if (args == '')
        {
          log('Traits: ' + listEntryNames(entries));
          return;
        }
      if (game.player.state != PLR_STATE_HOST)
        {
          log('Not on host.');
          return;
        }
      var match = selectMatch('trait', args, entries);
      if (match == null)
        return;
      game.player.host.addTrait(match.value);
      // kludge: if it's a cultist, we need to update cult member record
      if (game.player.host.isPlayerCultist())
        game.cults[0].updateData(game.player.host);
      log('Added trait: ' + match.value);
    }

// builds trait entries for selection from the live trait registry
// (built-ins + any mod-registered entries appended via TraitsConst.addTrait)
  public function buildEntries(): Array<ConsoleAddEntry<String>>
    {
      var list = [];
      for (group in TraitsConst.traits)
        for (info in group)
          {
            var enumName: String = info.id;
            var name = StringTools.startsWith(enumName, 'TRAIT_') ?
              enumName.substr(6).toLowerCase() :
              enumName.toLowerCase();
            list.push({
              name: name,
              searchKey: normalizeKey(name),
              value: info.id
            });
          }
      list.sort(function(a, b)
        {
          return compareStrings(a.name, b.name);
        });
      return list;
    }
}
