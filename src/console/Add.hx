// console add command helper
package console;

import const.EvolutionConst;
import const.EvolutionConst.ImprovInfo;
import const.ItemsConst;
import const.SkillsConst;
import game.Effect;
import game.Game;
import StringTools;
import Std;
import Type;

typedef ConsoleAddEntry<T> =
{
  name: String,
  searchKey: String,
  value: T,
  ?aliases: Array<String>,
}

class Add
{
  public var console: Console;
  var game: Game;

// sets up add command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// handles add command routing
  public function run(cmd: String): Bool
    {
      if (cmd.length < 2)
        return false;
      switch (cmd.charAt(1))
        {
          case 'e':
            addEffectCommand(cmd);
            return true;
          case 'i':
            addItemCommand(cmd);
            return true;
          case 'o':
            addOrganCommand(cmd);
            return true;
          case 's':
            addSkillCommand(cmd);
            return true;
          case 't':
            addTraitCommand(cmd);
            return true;
          default:
            return false;
        }
    }

// handles adding effects via console command
  function addEffectCommand(cmd: String)
    {
      var args = (cmd.length > 2 ? StringTools.trim(cmd.substr(2)) : '');
      var entries = buildEffectEntries();
      if (args == '')
        {
          log('Effects: ' + listEntryNames(entries));
          return;
        }
      var match = selectMatch('effect', args, entries);
      if (match == null)
        return;
      if (game.player.state != PLR_STATE_HOST)
        {
          log('Not on host.');
          return;
        }
      var effect: Effect = null;
      switch (match.value)
        {
          case EFFECT_PARALYSIS:
            effect = new effects.Paralysis(game, 10);
          case EFFECT_SLIME:
            effect = new effects.Slime(game, 10);
          case EFFECT_PANIC:
            effect = new effects.Panic(game, 10);
          case EFFECT_CANNOT_TEAR_AWAY:
            effect = new effects.CannotTearAway(game, 10);
          case EFFECT_CRYING:
            effect = new effects.Crying(game, 10);
          case EFFECT_BERSERK:
            effect = new effects.Berserk(game, 10);
          case EFFECT_WHITE_POWDER:
            effect = new effects.WhitePowder(game, 10);
          case EFFECT_WITHDRAWAL:
            effect = new effects.Withdrawal(game, 10);
          case EFFECT_DRUNK:
            effect = new effects.Drunk(game, 10);
        }
      if (effect == null)
        {
          log('Effect handler not implemented: ' + match.name + '.');
          return;
        }
      game.player.host.onEffect(effect);
      log('Added effect: ' + match.name + '.');
    }

// handles adding items via console command
  function addItemCommand(cmd: String)
    {
      var args = (cmd.length > 2 ? StringTools.trim(cmd.substr(2)) : '');
      if (ItemsConst.infos == null)
        ItemsConst.init(game);
      var entries = buildItemEntries();
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

// handles adding organs via console command
  function addOrganCommand(cmd: String)
    {
      var args = (cmd.length > 2 ? StringTools.trim(cmd.substr(2)) : '');
      var entries = buildOrganEntries();
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

// handles adding skills via console command
  function addSkillCommand(cmd: String)
    {
      var args = (cmd.length > 2 ? StringTools.trim(cmd.substr(2)) : '');
      var entries = buildSkillEntries();
      if (args == '')
        {
          log('Usage: as [skill] [amount]');
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
          log('Usage: as [skill] [amount]');
          return;
        }
      var amountStr = parts[parts.length - 1];
      var queryParts = [];
      for (i in 0...parts.length - 1)
        queryParts.push(parts[i]);
      var query = queryParts.join(' ');
      if (query == '')
        {
          log('Usage: as [skill] [amount]');
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

// handles adding traits via console command
  function addTraitCommand(args: String)
    {
      var arr = args.split(' ');
      if (game.player.state != PLR_STATE_HOST)
        {
          log('Not on host.');
          return;
        }

      var entries = [];
      for (trait in Type.allEnums(_AITraitType))
        {
          var enumName = Std.string(trait);
          var key = enumName.substr(6).toLowerCase();
          entries.push({
            id: trait,
            key: key,
            enumName: enumName
          });
        }
      entries.sort(function(a, b)
        {
          if (a.key < b.key) return -1;
          if (a.key > b.key) return 1;
          return 0;
        });

      if (arr.length < 2 || arr[1] == '')
        {
          var names = [];
          for (entry in entries)
            names.push(entry.key);
          log('Traits: ' + names.join(', '));
          return;
        }

      var query = arr[1].toLowerCase();
      var match = null;
      for (entry in entries)
        if (entry.key == query)
          {
            match = entry;
            break;
          }

      if (match == null)
        {
          var matches = [];
          for (entry in entries)
            if (StringTools.startsWith(entry.key, query))
              matches.push(entry);
          if (matches.length == 1)
            match = matches[0];
          else if (matches.length > 1)
            {
              var options = new Array<String>();
              for (entry in matches)
                options.push(entry.key);
              log('Ambiguous trait id, matches: ' + options.join(', '));
              return;
            }
        }

      if (match == null)
        {
          log('No trait matches id: ' + query);
          return;
        }

      game.player.host.addTrait(match.id);
      // kludge: if it's a cultist, we need to update cult member record
      if (game.player.host.isPlayerCultist())
        game.cults[0].updateData(game.player.host);

      log('Added trait: ' + match.enumName);
    }

// builds effect entries for selection
  public function buildEffectEntries(): Array<ConsoleAddEntry<_AIEffectType>>
    {
      var list = [];
      for (effect in Type.allEnums(_AIEffectType))
        {
          var name = Std.string(effect).substr(7).toLowerCase();
          list.push({
            name: name,
            searchKey: normalizeKey(name),
            value: effect
          });
        }
      list.sort(function(a, b)
        {
          return compareStrings(a.name, b.name);
        });
      return list;
    }

// builds item entries for selection
  public function buildItemEntries(): Array<ConsoleAddEntry<String>>
    {
      var list = [];
      for (info in ItemsConst.infos)
        {
          var name = info.id;
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

// builds organ entries for selection
  public function buildOrganEntries(): Array<ConsoleAddEntry<_Improv>>
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

// builds skill entries for selection
  public function buildSkillEntries(): Array<ConsoleAddEntry<_Skill>>
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

// builds improvement entries for selection
  public function buildImprovementEntries(): Array<ConsoleAddEntry<_Improv>>
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

// formats entry names for logging
  public function listEntryNames<T>(entries: Array<ConsoleAddEntry<T>>): String
    {
      var names = [];
      for (entry in entries)
        names.push(entry.name);
      names.sort(compareStrings);
      return names.join(', ');
    }

// selects matching entry for a query
  public function selectMatch<T>(label: String, query: String, entries: Array<ConsoleAddEntry<T>>): ConsoleAddEntry<T>
    {
      var normalizedQuery = normalizeKey(query);
      var exact = [];
      var partial = [];
      for (entry in entries)
        {
          var keys = [ entry.searchKey ];
          if (entry.aliases != null)
            for (alias in entry.aliases)
              keys.push(alias);
          var isExact = false;
          for (key in keys)
            if (key == normalizedQuery)
              {
                exact.push(entry);
                isExact = true;
                break;
              }
          if (isExact)
            continue;
          if (normalizedQuery == '')
            continue;
          for (key in keys)
            if (key.indexOf(normalizedQuery) != -1)
              {
                partial.push(entry);
                break;
              }
        }
      var matches = exact.length > 0 ? exact : partial;
      if (matches.length == 0)
        {
          log('No ' + label + ' matched "' + query + '".');
          return null;
        }
      if (matches.length > 1)
        {
          var options = [];
          for (entry in matches)
            options.push(entry.name);
          options.sort(compareStrings);
          log('Ambiguous ' + label + ' match: ' + options.join(', '));
          return null;
        }
      return matches[0];
    }

// converts value to a normalized lookup key
  inline function normalizeKey(value: String): String
    {
      var s = StringTools.trim(value).toLowerCase();
      s = StringTools.replace(s, '_', '');
      s = StringTools.replace(s, '-', '');
      s = StringTools.replace(s, ' ', '');
      return s;
    }

// compares strings ignoring case
  inline function compareStrings(a: String, b: String): Int
    {
      var la = a.toLowerCase();
      var lb = b.toLowerCase();
      if (la < lb) return -1;
      if (la > lb) return 1;
      return 0;
    }

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}
