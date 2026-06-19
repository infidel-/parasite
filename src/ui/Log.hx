// player log GUI window

package ui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Log extends UIWindow
{
  var logScroll: DivElement;

  public function new (g: Game)
    {
      super(g, 'window-log');

      // shared HUD chrome: scrim + document glyph, frame, corners, veins, "LOG" watermark
      addHudChrome('LOG', UISvg.doc());

      // Cruiser title with hairline divider
      var title = Browser.document.createDivElement();
      title.className = 'win-title';
      title.innerHTML = 'LOG';
      window.appendChild(title);

      // scrolling turn ledger
      logScroll = Browser.document.createDivElement();
      logScroll.className = 'hud-scroll';
      logScroll.onmouseover = groupHover;
      logScroll.onmouseleave = function(e) clearGroup();
      window.appendChild(logScroll);

      addWinClose();
    }

// light every record sharing the hovered record's turn (turn-group binding)
  function groupHover(e: js.html.MouseEvent)
    {
      clearGroup();
      var rec = (cast e.target : js.html.Element).closest('.log-rec');
      if (rec == null)
        return;
      var t = rec.getAttribute('data-t');
      for (r in logScroll.querySelectorAll(".log-rec[data-t='" + t + "']"))
        (cast r : js.html.Element).classList.add('tg');
    }

// remove all turn-group highlights
  function clearGroup()
    {
      for (r in logScroll.querySelectorAll('.log-rec.tg'))
        (cast r : js.html.Element).classList.remove('tg');
    }

// update text
  override function update()
    {
      var buf = new StringBuf();
      var lastTurn = -1;
      var i = 0;
      for (l in game.messageList)
        {
          // turn cell shows only on the first record of a turn
          var showTurn = (l.turn != lastTurn);
          lastTurn = l.turn;
          buf.add("<div class='log-rec' data-t='");
          buf.add(l.turn);
          buf.add("' style='--i:");
          buf.add(i);
          buf.add("'><span class='log-tn'>");
          // old saves have no turn stamp (null); turn 0 is pre-first-turn — show "-"
          if (showTurn)
            buf.add((l.turn == null || l.turn == 0) ? '-' : '' + l.turn);
          buf.add("</span><div class='log-rl' style='color:");
          buf.add(Const.TEXT_COLORS[l.col]);
          buf.add("'>");
          buf.add(l.msg);
          if (l.cnt > 1)
            {
              buf.add(" <span class='log-rep'>(x");
              buf.add(l.cnt);
              buf.add(")</span>");
            }
          buf.add("</div></div>");
          i++;
        }
      logScroll.innerHTML = buf.toString();
      // mark newest record for the current-turn marker
      var recs = logScroll.querySelectorAll('.log-rec');
      if (recs.length > 0)
        (cast recs.item(recs.length - 1) : DivElement).classList.add('now');
      // opens scrolled to the end (game behavior)
      logScroll.scrollTop = logScroll.scrollHeight;
    }

  override function show(?skipAnimation: Bool = false)
    {
      super.show(skipAnimation);
      // scroll to the newest record here (not in update): update() runs while the
      // window is still display:none, so scrollHeight is 0 and the scroll is a no-op
      logScroll.scrollTop = logScroll.scrollHeight;

      var recs = logScroll.querySelectorAll('.log-rec');
      var n = recs.length;
      if (n == 0)
        return;
      // cascade only the on-screen window, top-down, with an adaptive stagger so the
      // whole visible cascade always finishes in ~0.3s — never a growing blank pause
      // no matter how long the log is. Rows scrolled above the fold appear at once.
      var avgRow = logScroll.scrollHeight / n;
      var k = Math.ceil(logScroll.clientHeight / avgRow) + 4;
      if (k > n)
        k = n;
      var firstVisible = n - k;
      var stagger = 0.30 / k;
      if (stagger > 0.018)
        stagger = 0.018;
      for (i in 0...n)
        {
          var rec: js.html.Element = cast recs.item(i);
          if (i >= firstVisible)
            {
              rec.classList.remove('instant');
              (untyped rec.style).animationDelay = (0.06 + (i - firstVisible) * stagger) + 's';
            }
          else rec.classList.add('instant');
        }

      // decode the two newest message bodies out of glyph noise, each started ~when
      // its row has risen in (delay = its cascade delay + the rise duration)
      decodeMsg(cast (cast recs.item(n - 1) : js.html.Element).querySelector('.log-rl'),
        Std.int((0.06 + (k - 1) * stagger) * 1000) + 120);
      if (n > 1)
        decodeMsg(cast (cast recs.item(n - 2) : js.html.Element).querySelector('.log-rl'),
          Std.int((0.06 + (k - 2) * stagger) * 1000) + 240);
    }

// decode one message body out of glyph noise after startMs (keeps colored markup)
  function decodeMsg(el: js.html.Element, startMs: Int)
    {
      var html = el.innerHTML;
      var txt = el.textContent;
      haxe.Timer.delay(function() UIDecode.decodeTo(el, txt, html), startMs);
    }

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }
}
