// organs GUI window

package entities;

import game.Game;

class OrgansWindow extends TextWindow
{
  public function new(g: Game)
    {
      super(g);
      actionName = 'body feature to grow';
    }


// get action list
  override function getActions()
    {
      var list = new List<_PlayerAction>();

      for (imp in game.player.evolutionManager)
        {
          // improvement not available yet or no organs
          if (imp.level == 0 || imp.info.organ == null)
            continue;

          var organInfo = imp.info.organ;

          // organ already completed 
          if (game.player.host.organs.getActive(imp.info.id) != null)
            continue;

          var organ = game.player.host.organs.get(imp.info.id);
          var currentGP = 0;
          if (organ != null)
            currentGP = organ.gp;

          var buf = new StringBuf();
          buf.add("<font color='#DDDD00'>" + organInfo.name + "</font>");
          buf.add(' ');
          buf.add(imp.level);
          buf.add(' (' + organInfo.gp + ' gp) (');
          var gpLeft = organInfo.gp - currentGP;
          buf.add(Math.ceil(gpLeft / game.player.vars.organGrowthPointsPerTurn));
          buf.add(" turns)\n");

          buf.add("\n<font color='#5ebee5'>" + organInfo.note + '</font>\n');
          buf.add("<font color='#4cd47b'>" +
            imp.info.levelNotes[imp.level] + '</font>\n');
          if (imp.info.noteFunc != null)
            buf.add("<font color='#13ff65'>" +
              imp.info.noteFunc(imp.info.levelParams[imp.level]) + '</font>\n');
          else buf.add('\n');

          list.add({
            id: 'set.' + imp.id,
            type: ACTION_ORGAN,
            name: buf.toString(),
//            organ.name + ' (' + organ.gp + 'gp)' +
//            ' [' + organ.note + ']',
            energy: 0,
            });
        }

      return list;
    }



// action
  override function onAction(action: _PlayerAction)
    {
      game.player.host.organs.action(action.id);
    }


// update window text
  override function getText()
    {
      var buf = new StringBuf();
      buf.add('Body features\n===\n\n');

      // draw a list of organs
      var n = 0;
      for (organ in game.player.host.organs)
        {
          if (organ.isActive)
            buf.add("<font color='#DDDD00'>" + organ.info.name + "</font>");
          else buf.add("<font color='#CCCCCC'>" + organ.info.name + "</font>");
          buf.add(' ');
          buf.add(organ.level);
          if (organ.isActive)
            {
              if (organ.info.hasTimeout && organ.timeout > 0)
                buf.add(' (timeout: ' + organ.timeout + ')');
            }
          else buf.add(' (' + organ.gp + '/' + organ.info.gp + ' gp)');
//          buf.add(' [' + organ.info.note + ']\n');
          var imp = game.player.evolutionManager.getImprov(organ.improvInfo.id);
          buf.add("\n<font color='#5ebee5'>" + organ.info.note + '</font>\n');
          buf.add("<font color='#4cd47b'>" +
            organ.improvInfo.levelNotes[imp.level] + '</font>\n');
          if (organ.improvInfo.noteFunc != null)
            buf.add("<font color='#13ff65'>" +
              organ.improvInfo.noteFunc(organ.improvInfo.levelParams[imp.level]) + '</font>\n');
          buf.add('\n');
#if mydebug
//          var params = game.player.evolutionManager.getParams(organ.id);
//          buf.add('DEBUG: ' + organ.params + '\n');
#end
          n++;
        }

      if (n == 0)
        buf.add('  --- empty ---\n\n');

      buf.add('Body feature growth costs additional ' +
        game.player.vars.organGrowthEnergyPerTurn +
        ' energy per turn.\n' +
        'You will receive ' + game.player.vars.organGrowthPointsPerTurn +
        ' gp per turn.\n' +
        'Your host will survive for ' +
          Std.int(game.player.host.energy /
            game.player.vars.organGrowthEnergyPerTurn) +
        ' turns while growing body features (not counting other spending).\n');

      buf.add('\nGrowing body feature: ');
      buf.add("<font color='#DDDD00'>" +
        game.player.host.organs.getGrowInfo() + "</font>");

      return buf.toString();
    }
}
