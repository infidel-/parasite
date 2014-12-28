// skills GUI window

package entities;

class SkillsWindow extends TextWindow
{
  public function new(g: Game)
    {
      super(g);
    }


// update window text
  override function getText()
    {
      var buf = new StringBuf();

      // parasite skills
      buf.add('Skills and knowledges\n===\n\n');
      var n = 0;
      for (skill in game.player.skills)
        {
          n++;
          buf.add((skill.info.isKnowledge ? 'Knowledge: ' : '') +
            skill.info.name + ' ' + skill.level + '%\n');
        }

      if (n == 0)
        buf.add('  --- empty ---\n');

      // host skills
      if (game.player.state == PLR_STATE_HOST)
        {
          buf.add('\nHost skills\n===\n\n');
          var n = 0;
          for (skill in game.player.host.skills)
            {
              n++;
              buf.add(skill.info.name + ' ' + skill.level + '%\n');
            }

          if (n == 0)
            buf.add('  --- empty ---\n');
        }

      return buf.toString();
    }
}
