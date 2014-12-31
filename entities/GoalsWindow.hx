// player goals GUI window

package entities;

class GoalsWindow extends TextWindow
{
  public function new (g: Game)
    { super(g); }


  override function getText(): String
    {
      var buf = new StringBuf();

      buf.add('Current goals\n====\n\n');
      for (g in game.player.goals.iteratorCurrent()) 
        {
          var info = const.Goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add(info.name + '\n');
          buf.add(info.note + '\n\n');
        }

      buf.add("\nCompleted goals\n====\n\n<font color='#777777'>");
      for (g in game.player.goals.iteratorCompleted()) 
        {
          var info = const.Goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add(info.name + '\n');
          buf.add(info.note + '\n\n');
        }
      buf.add('</font>');

      return buf.toString();
    }
}

