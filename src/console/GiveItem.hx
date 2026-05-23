// console give item command
package console;

import const.ItemsConst;

class GiveItem extends GiveBase
{
// gives an item to the current host inventory
  public function run(args: String)
    {
      if (ItemsConst.infos == null)
        ItemsConst.init(game);
      var entries = buildEntries();
      if (args == '')
        {
          log('Items: ' + listEntryNames(entries));
          return;
        }
      var match = selectMatch('item', args, entries);
      if (match == null)
        return;
      if (game.player.state != PLR_STATE_HOST)
        {
          log('Not on host.');
          return;
        }
      try {
        var item = game.player.host.inventory.addID(match.value);
        if (item.name == 'keycard')
          item.lockID = 'corp-mission';
      }
      catch (e: Dynamic)
        {
          game.log(e + '');
          return;
        }
      game.log('Item added.');
    }

// builds item entries for selection. matches `give skill` convention:
// display by info.name (human label, e.g. "mobile phone"); keep info.id as
// alias so legacy `give item mobilePhone` typing still resolves.
  public function buildEntries(): Array<ConsoleAddEntry<String>>
    {
      if (ItemsConst.infos == null)
        ItemsConst.init(game);
      var list = [];
      for (info in ItemsConst.infos)
        {
          var name = info.name;
          list.push({
            name: name,
            searchKey: normalizeKey(name),
            value: info.id,
            aliases: [ normalizeKey(info.id) ],
          });
        }
      list.sort(function(a, b)
        {
          return compareStrings(a.name, b.name);
        });
      return list;
    }
}
