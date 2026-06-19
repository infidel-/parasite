// player goals GUI window

package ui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Goals extends UIWindow
{
  var body: DivElement;

  public function new (g: Game)
    {
      super(g, 'window-goals');

      // shared HUD chrome: scrim + reticle glyph, frame, corners, veins, "GOALS" watermark
      addHudChrome('GOALS', UISvg.reticle());

      var title = Browser.document.createDivElement();
      title.className = 'win-title';
      title.innerHTML = 'GOALS';
      window.appendChild(title);

      // sections live in a flex-column body so update() can rebuild them in place
      body = Browser.document.createDivElement();
      body.className = 'goals-body';
      window.appendChild(body);

      addWinClose();
    }

// update sections
  override function update()
    {
      var buf = new StringBuf();
      var i = 0;
      i = addSection(buf, 'cur', 'CURRENT GOALS', 3, game.goals.iteratorCurrent(), i);
      i = addSection(buf, 'done', 'COMPLETED GOALS', 4, game.goals.iteratorCompleted(), i);
      i = addSection(buf, 'fail', 'FAILED GOALS', 2, game.goals.iteratorFailed(), i);
      body.innerHTML = buf.toString();
    }

// build one goals section; returns the next cascade index (--i runs across sections)
  function addSection(buf: StringBuf, cls: String, title: String, flex: Int,
      iter: Iterator<_Goal>, startIdx: Int): Int
    {
      var entries = new StringBuf();
      var count = 0;
      var idx = startIdx;
      for (gg in iter)
        {
          var info = game.goals.getInfo(gg);
          if (info.isHidden == true)
            continue;
          entries.add("<div class='goals-gl' style='--i:");
          entries.add(idx);
          entries.add("'>");
          // current goals: colored bold name (+ [optional]); done/fail: plain bold name
          if (cls == 'cur')
            {
              entries.add("<span class='goals-gname' style='color:var(--text-color-goal)'>");
              entries.add(info.name);
              entries.add("</span>");
              if (info.isOptional == true)
                entries.add(" <span class='goals-opt'>[optional]</span>");
            }
          else
            {
              entries.add("<b>");
              entries.add(info.name);
              entries.add("</b>");
            }
          entries.add("<br/>");
          entries.add(info.note);
          if (info.noteFunc != null)
            entries.add("<br/>" + info.noteFunc(game));
          entries.add("</div>");
          count++;
          idx++;
        }

      buf.add("<div class='goals-sec ");
      buf.add(cls);
      buf.add("' style='flex:");
      buf.add(flex);
      buf.add("'><div class='goals-sectitle'>");
      buf.add(title);
      buf.add(" <span class='goals-cnt'>");
      buf.add(count);
      buf.add("</span></div><div class='hud-scroll'");
      if (cls == 'done')
        buf.add(" style='color:var(--text-color-gray)'");
      else if (cls == 'fail')
        buf.add(" style='color:var(--text-color-red)'");
      buf.add(">");
      if (count == 0)
        buf.add("<div class='goals-empty'>None so far</div>");
      else
        buf.add(entries.toString());
      buf.add("</div></div>");
      return idx;
    }

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }
}
