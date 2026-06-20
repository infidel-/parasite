// hud event log block: newest row first, older rows decay via css
package ui.hud;

import js.Browser.document;
import js.html.DivElement;

import game.*;

class LogHud
{
  var game: Game;
  var log: DivElement;
  var lastLogKey: String = '';     // detects a genuinely new top log row

  public function new(g: Game, h: HUD)
    {
      game = g;
      log = document.createDivElement();
      log.className = 'hud-panel hud-text';
      log.id = 'hud-log';
      h.container.appendChild(log);
    }

// update event log display (newest row first, older rows decay via css)
  public function update()
    {
      var arr = [for (l in game.hudMessageList) l];
      // newest message sits at the tail of the list; detect a genuinely new top row
      var topKey = (arr.length > 0 ?
        arr[arr.length - 1].msg + '|' + arr[arr.length - 1].turn + '|' + arr[arr.length - 1].cnt : '');
      var isNewTop = (topKey != '' && topKey != lastLogKey);
      lastLogKey = topKey;

      var buf = new StringBuf();
      var i = arr.length - 1;
      var first = true;
      while (i >= 0)
        {
          var l = arr[i];
          var cls = 'hud-row';
          if (l.col == COLOR_ALERT)
            cls += ' highlight-text';
          if (first && isNewTop)
            cls += ' hud-row-new';
          var ts = (l.turn == null || l.turn == 0 ? '-' : '' + l.turn);
          buf.add('<div class="' + cls + '"><span class="ts">' + ts + '</span>');
          buf.add('<span class="msg" style="color:' + Const.TEXT_COLORS[l.col] + '">' + l.msg + '</span>');
          if (l.cnt > 1)
            buf.add(' <span class="xn">(x' + l.cnt + ')</span>');
          buf.add('</div>');
          first = false;
          i--;
        }
      log.innerHTML = buf.toString();
    }
}
