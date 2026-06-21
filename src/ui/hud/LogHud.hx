// hud event log block: newest row first, older rows decay via css
package ui.hud;

import js.Browser.document;
import js.html.DivElement;

import game.*;

class LogHud
{
  var game: Game;
  var log: DivElement;
  var lastSig: String = '';        // full row signature; unchanged => skip rebuild
  var lastTopMsg: String = '';     // top row msg|turn (no count) => detects a new message
  var lastTopCnt: Int = 0;         // top row count => detects a repeat bump

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
      // signature of all displayed rows; if unchanged, skip the rebuild so an
      // in-flight arrival/pop animation on the freshly-inserted top row survives
      var sig = new StringBuf();
      for (l in arr)
        {
          sig.add(l.msg); sig.add('|'); sig.add('' + l.turn); sig.add('|');
          sig.add('' + l.cnt); sig.add('|'); sig.add('' + l.col); sig.add('\n');
        }
      var sigStr = sig.toString();
      if (sigStr == lastSig)
        return;
      lastSig = sigStr;

      // newest message sits at the tail; a changed msg|turn is a new row (slides in),
      // same msg|turn with a higher count is a repeat (pops the [xN] counter instead)
      var newest = (arr.length > 0 ? arr[arr.length - 1] : null);
      var topMsg = (newest != null ? newest.msg + '|' + newest.turn : '');
      var topCnt = (newest != null ? newest.cnt : 0);
      var isNewTop = (topMsg != '' && topMsg != lastTopMsg);
      var isRepeatTop = (!isNewTop && topCnt > lastTopCnt);
      lastTopMsg = topMsg;
      lastTopCnt = topCnt;

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
            buf.add(' <span class="xn' + (first && isRepeatTop ? ' pop' : '') + '">(x' + l.cnt + ')</span>');
          buf.add('</div>');
          first = false;
          i--;
        }
      log.innerHTML = buf.toString();

      // typewriter: reveal the newest row's text char-by-char on arrival.
      // skipped for messages carrying markup (slicing raw html breaks tags)
      if (isNewTop
          && newest != null
          && newest.msg.indexOf('<') < 0)
        {
          var topRow: js.html.Element = cast log.firstElementChild;
          var msgEl = (topRow != null ? topRow.querySelector('.msg') : null);
          if (msgEl != null)
            typewrite(msgEl, newest.msg, newest.col == COLOR_ALERT);
        }
    }

  static var GLYPHS = '#$%&@▒░╪◊'; // wrong-glyph flicker set

// type a message into the row's .msg element one char at a time; alert rows
// flicker a random glyph at the writing head before each char settles
  function typewrite(el: js.html.Element, text: String, isAlert: Bool)
    {
      var ti = 0;
      function step()
        {
          if (ti >= text.length)
            {
              el.textContent = text;
              return;
            }
          ti++;
          var t = text.substr(0, ti);
          if (isAlert
              && ti < text.length
              && Std.random(100) < 18)
            t = t.substr(0, t.length - 1) + GLYPHS.charAt(Std.random(GLYPHS.length));
          el.textContent = t;
          haxe.Timer.delay(step, 14);
        }
      step();
    }
}
