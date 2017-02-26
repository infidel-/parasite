// skills GUI window

package entities;

import game.Game;
import const.*;

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
      buf.add('Parasite skills and knowledges\n===\n\n');
      var n = 0;
      for (skill in game.player.skills)
        {
          n++;
          buf.add((skill.info.isKnowledge ? 'Knowledge: ' : '') +
            skill.info.name);
          if (skill.info.isBool == null || !skill.info.isBool)
            buf.add(' ' + skill.level + '%\n');
          else buf.add('\n');
        }

      if (n == 0)
        buf.add('  --- empty ---\n');

#if mydebug
      buf.add('[DEBUG] Group priority: ' + Std.int(game.group.priority) +
        '\n');
      if (game.group.team != null)
        buf.add('[DEBUG] Team level: ' + game.group.team.level +
          ', size: ' + game.group.team.size +
          ', distance: ' + Std.int(game.group.team.distance) + '\n');
#end

      // host skills and attributes
      if (game.player.state == PLR_STATE_HOST)
        {
          buf.add('\nHost skills and knowledges\n===\n\n');
          var n = 0;
          for (skill in game.player.host.skills)
            {
              n++;
              buf.add(skill.info.name);
              if (skill.info.isBool == null || !skill.info.isBool)
                buf.add(' ' + skill.level + '%\n');
              else buf.add('\n');
            }

          if (n == 0)
            buf.add('  --- empty ---\n');

          // host attributes and traits
          if (game.player.host.isAttrsKnown)
            {
              buf.add('\nHost attributes\n===\n\n');
              buf.add('Strength ' + game.player.host.strength + '\n');
              buf.add('<font color=#777777>' +
                'Increases health and energy\n' +
                'Increases melee damage\n' +
                'Decreases grip efficiency\n' +
                'Decreases paralysis efficiency\n' +
                'Increases speed of removing slime\n' +
                '</font>\n');

              buf.add('Constitution ' + game.player.host.constitution + '\n');
              buf.add('<font color=#777777>' +
                'Increases health and energy\n' +
                '</font>\n');

              buf.add('Intellect ' + game.player.host.intellect + '\n');
              buf.add('<font color=#777777>' +
                'Increases skills and society knowledge learning efficiency\n' +
                '</font>\n');

              buf.add('Psyche ' + game.player.host.psyche + '\n');
              buf.add('<font color=#777777>' +
                'Increases energy needed to probe brain\n' +
                'Reduces the efficiency of reinforcing control\n' +
                '</font>\n');

              // traits
              buf.add('Host traits\n===\n\n');
              for (t in game.player.host.traits)
                {
                  var info = TraitsConst.getInfo(t);
                  buf.add(info.name + '\n');
                  buf.add('<font color=#777777>' + info.note + '</font>\n');
                }
            }
        }

      return buf.toString();
    }
}
