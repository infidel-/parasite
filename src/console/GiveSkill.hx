// console give skill command
package console;

import const.SkillsConst;

class GiveSkill extends GiveBase
{
// gives skill/knowledge points: give skill [name] [amount]
  public function run(args: String)
    {
      var entries = buildEntries();
      if (args == '')
        {
          log('Usage: give skill [skill] [amount]');
          log('Skills: ' + listEntryNames(entries));
          return;
        }
      var partsRaw = args.split(' ');
      var parts = [];
      for (part in partsRaw)
        if (part != '')
          parts.push(part);
      if (parts.length < 2)
        {
          log('Usage: give skill [skill] [amount]');
          return;
        }
      var amountStr = parts[parts.length - 1];
      var queryParts = [];
      for (i in 0...parts.length - 1)
        queryParts.push(parts[i]);
      var query = queryParts.join(' ');
      if (query == '')
        {
          log('Usage: give skill [skill] [amount]');
          return;
        }
      var parsed = Std.parseInt(amountStr);
      if (parsed == null)
        {
          log('Invalid amount: ' + amountStr + '.');
          return;
        }
      var match = selectMatch('skill', query, entries);
      if (match == null)
        return;
      var amount: Int = parsed;
      game.player.skills.addID(match.value, amount);
      log('Skill/knowledge added: ' + match.name + ' (' + amount + ').');
    }

// builds skill entries for selection
  public function buildEntries(): Array<ConsoleAddEntry<_Skill>>
    {
      var list = [];
      for (info in SkillsConst.skills)
        {
          var name = info.name.toLowerCase();
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
