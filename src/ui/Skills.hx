// skills GUI window

package ui;

import game.Game;
import const.*;

class Skills extends Text
{
  public function new(g: Game)
    { super(g); }


// update text
  override function update()
    {
      var buf = new StringBuf();

      // parasite skills
      buf.add('Parasite skills and knowledges<br/>===<br/><br/>');
      var n = 0;
      for (skill in game.player.skills)
        {
          n++;
          buf.add((skill.info.isKnowledge ? 'Knowledge: ' : '') +
            skill.info.name);
          if (skill.info.isBool == null || !skill.info.isBool)
            buf.add(' ' + skill.level + '%<br/>');
          else buf.add('<br/>');
        }

      if (n == 0)
        buf.add('  --- empty ---<br/>');

      // get group/team info
      game.group.getInfo(buf);

      // host skills and attributes
      if (game.player.state == PLR_STATE_HOST)
        {
          buf.add('<br/>Host skills and knowledges<br/>===<br/><br/>');
          var n = 0;
          for (skill in game.player.host.skills)
            {
              // hidden animal attack skill
              if (skill.info.id == SKILL_ATTACK)
                continue;

              n++;
              buf.add(skill.info.name);
              if (skill.info.isBool == null || !skill.info.isBool)
                buf.add(' ' + skill.level + '%<br/>');
              else buf.add('<br/>');
            }

          if (n == 0)
            buf.add('  --- empty ---<br/>');

          // host attributes and traits
          if (game.player.host.isAttrsKnown)
            {
              buf.add('<br/>Host attributes<br/>===<br/><br/>');
              buf.add('Strength ' + game.player.host.strength + '<br/>');
              buf.add('<font color="#777777">' +
                'Increases health and energy<br/>' +
                'Increases melee damage<br/>' +
                'Decreases grip efficiency<br/>' +
                'Decreases paralysis efficiency<br/>' +
                'Increases speed of removing slime<br/>' +
                '</font><br/>');

              buf.add('Constitution ' + game.player.host.constitution + '<br/>');
              buf.add('<font color="#777777">' +
                'Increases health and energy<br/>' +
                '</font><br/>');

              buf.add('Intellect ' + game.player.host.intellect + '<br/>');
              buf.add('<font color="#777777">' +
                'Increases skills and society knowledge learning efficiency<br/>' +
                '</font><br/>');

              buf.add('Psyche ' + game.player.host.psyche + '<br/>');
              buf.add('<font color="#777777">' +
                'Increases energy needed to probe brain<br/>' +
                'Reduces the efficiency of reinforcing control<br/>' +
                '</font><br/>');

              // traits
              buf.add('Host traits<br/>===<br/><br/>');
              for (t in game.player.host.traits)
                {
                  var info = TraitsConst.getInfo(t);
                  buf.add(info.name + '<br/>');
                  buf.add('<font color="#777777">' + info.note + '</font><br/>');
                }
            }
        }

      setParams(buf.toString());
    }
}
