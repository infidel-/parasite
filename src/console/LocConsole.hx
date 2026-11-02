// console loc command — switch language, pseudo-localization, untranslated strings (debug only)
package console;

import l10n.Loc;
import game.Game;

class LocConsole
{
  public var console: Console;
  var game: Game;

// sets up loc command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// handles loc command routing: info (default) / missing / <code> / pseudo
  public function run(arr: Array<String>)
    {
      if (arr.length == 1)
        {
          log('Language: ' + Loc.lang() + ', available: ' + Loc.languages().join(', ') + '.<br/>' +
            'loc [code|pseudo|missing] - switch language (reloads), pseudo-localization, ' +
            'strings shown without a translation.');
          return;
        }
      var sub = arr[1];
      if (sub == 'missing')
        printMissing();
      else if (sub == 'pseudo' ||
          Loc.languages().indexOf(sub) >= 0)
        {
          game.config.set('lang', sub);
          game.config.save(false);
          Loc.reload();
        }
      else log('No lang file for [' + sub + ']. Available: ' + Loc.languages().join(', ') + ', pseudo.');
    }

// list the strings that reached Loc.tr without a translation this session
  function printMissing()
    {
      var list = Loc.missingList();
      if (list.length == 0)
        {
          log('No untranslated strings shown' + (Loc.lang() == 'en' ? ' (English is the source).' : '.'));
          return;
        }
      var buf = new StringBuf();
      buf.add(list.length + ' untranslated strings (also in the browser console):<br/>');
      for (i in 0...Std.int(Math.min(list.length, 40)))
        buf.add(StringTools.htmlEscape(list[i]) + '<br/>');
      log(buf.toString());
      js.Browser.console.log(list.join('\n'));
    }

// log helper — delegates to owning console
  inline function log(s: String)
    {
      console.log(s);
    }
}
