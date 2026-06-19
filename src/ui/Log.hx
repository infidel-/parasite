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

      // giant document glyph ghosted on the scrim, behind the frame
      bg.insertAdjacentHTML('afterbegin', '<div class="log-scrim">' + UISvg.doc() + '</div>');

      addCorners();

      // decorative layer (clipped to the rounded frame): corner veins + ghost watermark
      window.insertAdjacentHTML('afterbegin',
        '<div class="log-deco">' + UISvg.veins() + '</div>');

      // Cruiser title with hairline divider
      var title = Browser.document.createDivElement();
      title.className = 'win-title log-title';
      title.innerHTML = 'LOG';
      window.appendChild(title);

      // scrolling turn ledger
      logScroll = Browser.document.createDivElement();
      logScroll.className = 'log-scroll';
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
      // decode tail: the two newest message bodies resolve out of glyph noise,
      // each started ~when its own (top-down) cascade brings it on-screen
      var msgs = logScroll.querySelectorAll('.log-rl');
      var n = msgs.length;
      if (n > 0)
        decodeMsg(cast msgs.item(n - 1), n - 1, 0);
      if (n > 1)
        decodeMsg(cast msgs.item(n - 2), n - 2, 120);
    }

// decode one message body once its cascade has brought it on-screen.
// idx is the record's source index (= its --i); extra staggers the two.
// cascade delay mirrors the CSS: .12s + min(idx,40)*18ms
  function decodeMsg(el: js.html.Element, idx: Int, extra: Int)
    {
      var html = el.innerHTML;
      var txt = el.textContent;
      var casc = 120 + (idx < 40 ? idx : 40) * 18;
      haxe.Timer.delay(function() UIDecode.decodeTo(el, txt, html), casc + 120 + extra);
    }

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }
}
