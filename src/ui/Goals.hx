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

      buf.add('Current goals\n====\n\n');
      for (g in game.goals.iteratorCurrent())
        {
          var info = game.goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add("<font color='#4788FF'>" + info.name + '</font>\n');
          buf.add(info.note + '\n');
          if (info.note2 != null)
            buf.add(info.note2 + '\n');
          buf.add('\n');
        }

      buf.add("\nCompleted goals\n====\n\n<font color='#777777'>");
      for (g in game.goals.iteratorCompleted())
        {
          var info = game.goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add(info.name + '\n');
          buf.add(info.note + '\n');
          if (info.note2 != null)
            buf.add(info.note2 + '\n');
          buf.add('\n');
        }
      buf.add('</font>');

      buf.add("\nFailed goals\n====\n\n<font color='#770000'>");
      for (g in game.goals.iteratorFailed())
        {
          var info = game.goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add(info.name + '\n');
          buf.add(info.note + '\n');
          if (info.note2 != null)
            buf.add(info.note2 + '\n');
          buf.add('\n');
        }
      buf.add('</font>');

      setParams(buf.toString());
    }
}

