// player goals GUI window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Goals extends UIWindow
{
  var text: DivElement;

  public function new (g: Game)
    {
      super(g, 'window-goals');
      window.style.borderImage = "url('./img/window-goals.png') 130 fill / 1 / 0 stretch";

      text = Browser.document.createDivElement();
      text.id = 'window-goals-text';
      window.appendChild(text);
    }


// update text
  override function update()
    {
      var buf = new StringBuf();

      buf.add('<fieldset id="window-goals-current"><legend>CURRENT GOALS</legend><div class=scroller>');
      for (g in game.goals.iteratorCurrent())
        {
          var info = game.goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add(Const.col('goal', info.name));
          if (info.isOptional)
            buf.add(' ' + Const.small(Const.col('gray', '[optional]')));
          buf.add('<br/>');
          buf.add(info.note + '<br/>');
          if (info.note2 != null)
            buf.add(info.note2 + '<br/>');
          buf.add('<br/>');
        }
      buf.add('</div>');
      buf.add('</fieldset>');

      buf.add('<br><fieldset id="window-goals-completed"><legend>COMPLETED GOALS</legend><div class=scroller style="color:var(--text-color-gray)">');
      var hasCompletedGoals = false;
      for (g in game.goals.iteratorCompleted())
        {
          var info = game.goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add('<b>' + info.name + '</b><br/>');
          buf.add(info.note + '<br/>');
          if (info.note2 != null)
            buf.add(info.note2 + '<br/>');
          buf.add('<br/>');
          hasCompletedGoals = true;
        }
      if (!hasCompletedGoals)
        buf.add('None so far.');
      buf.add('</div>');
      buf.add('</fieldset>');

      buf.add('<br><fieldset id="window-goals-failed"><legend>FAILED GOALS</legend><div class=scroller style="color:var(--text-color-red)">');
      var hasFailedGoals = false;
      for (g in game.goals.iteratorFailed())
        {
          var info = game.goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add(info.name + '<br/>');
          buf.add(info.note + '<br/>');
          if (info.note2 != null)
            buf.add(info.note2 + '<br/>');
          buf.add('<br/>');
          hasFailedGoals = true;
        }
      if (!hasFailedGoals)
        buf.add('<font style="color:var(--text-color-gray)">None so far.</font>');
      buf.add('</div>');
      buf.add('</fieldset>');

      setParams(buf.toString());
    }

  public override function setParams(obj: Dynamic)
    {
      text.innerHTML = obj;
    }
}

