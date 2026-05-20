// console give command shared base (matching + listing helpers)
package console;

import game.Game;
import StringTools;

class GiveBase
{
  public var console: Console;
  var game: Game;

// sets up give sub-command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
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
  function compareStrings(a: String, b: String): Int
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
