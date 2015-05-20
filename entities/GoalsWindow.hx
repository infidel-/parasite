// player goals GUI window

package entities;

import game.Game;

class GoalsWindow extends TextWindow
{
  public function new (g: Game)
    { super(g); }


  override function getText(): String
    {
      var buf = new StringBuf();

      buf.add('Current goals\n====\n\n');
      for (g in game.goals.iteratorCurrent()) 
        {
          var info = game.goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add(info.name + '\n');
          buf.add(info.note + '\n\n');
        }

      buf.add("\nCompleted goals\n====\n\n<font color='#777777'>");
      for (g in game.goals.iteratorCompleted()) 
        {
          var info = game.goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add(info.name + '\n');
          buf.add(info.note + '\n\n');
        }
      buf.add('</font>');

      buf.add("\nFailed goals\n====\n\n<font color='#770000'>");
      for (g in game.goals.iteratorFailed()) 
        {
          var info = game.goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add(info.name + '\n');
          buf.add(info.note + '\n\n');
        }
      buf.add('</font>');

      return buf.toString();
    }
}

