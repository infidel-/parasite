// player goals GUI window

package ui;

import game.Game;

class Goals extends Text
{
  public function new (g: Game)
    { super(g); }


// update text
  override function update()
    {
      var buf = new StringBuf();

      buf.add('Current goals<br/>====<br/><br/>');
      for (g in game.goals.iteratorCurrent())
        {
          var info = game.goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add("<font color='#4788FF'>" + info.name + '</font><br/>');
          buf.add(info.note + '<br/>');
          if (info.note2 != null)
            buf.add(info.note2 + '<br/>');
          buf.add('<br/>');
        }

      buf.add("<br/>Completed goals<br/>====<br/><br/><font color='#777777'>");
      for (g in game.goals.iteratorCompleted())
        {
          var info = game.goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add(info.name + '<br/>');
          buf.add(info.note + '<br/>');
          if (info.note2 != null)
            buf.add(info.note2 + '<br/>');
          buf.add('<br/>');
        }
      buf.add('</font>');

      buf.add("<br/>Failed goals<br/>====<br/><br/><font color='#770000'>");
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
        }
      buf.add('</font>');

      setParams(buf.toString());
    }
}

