// evolution GUI window

package entities;

import game.Game;
import const.EvolutionConst;

class EvolutionWindow extends TextWindow
{
  public function new(g: Game)
    {
      super(g);
      actionName = 'evolution direction';
    }


// get action list
  override function getActions()
    {
      var list = new List<_PlayerAction>();

      for (imp in game.player.evolutionManager)
        if (imp.level < 3)
          {
            var buf = new StringBuf();
            buf.add("<font color='#00ffff'>" + imp.info.name + "</font>");
            buf.add(' ');
            buf.add(imp.level + 1);
              buf.add(' (' + imp.ep + '/' + 
                EvolutionConst.epCostImprovement[imp.level] + ' ep)\n');
            buf.add("<font color='#5ebee5'>" + imp.info.note + '</font>\n');
            buf.add("<font color='#4cd47b'>" +
              imp.info.levelNotes[imp.level] + '</font>\n');
            if (imp.info.noteFunc != null)
              buf.add("<font color='#13ff65'>" +
                imp.info.noteFunc(imp.info.levelParams[imp.level]) + '</font>\n');

            list.add({
              id: 'set.' + imp.id,
              type: ACTION_EVOLUTION,
              name: buf.toString(),

  //            name: imp.info.name + 
  //              ' (' + imp.info.levelNotes[imp.level + 1] + ')',
              energy: 0,
              });
          }

      // add paths (full evolution only)
      if (game.player.evolutionManager.state > 1)
        for (p in game.player.evolutionManager.getPathList())
          {
            // special path is not available
            if (p.info.id == PATH_SPECIAL)
              continue;

            // do not add completed paths
            if (game.player.evolutionManager.isPathComplete(p.id))
              continue;
              
            list.add({
              id: 'setPath.' + p.id,
              type: ACTION_EVOLUTION,
              name: p.info.name + ' (' + p.ep + '/' +
                EvolutionConst.epCostPath[p.level] + ' ep)',
              energy: 0,
              });
          }

      return list;
    }


// action
  override function onAction(action: _PlayerAction)
    {
      game.player.evolutionManager.action(action.id);
    }


// update window text
  override function getText()
    {
      var buf = new StringBuf();
      buf.add('Controlled Evolution\n===\n\n');

      // form a list of improvs and actions
      buf.add('Improvements\n===\n');
      for (imp in game.player.evolutionManager)
        {
          buf.add("<font color='#00ffff'>" + imp.info.name + "</font>");
          buf.add(' ');
          buf.add(imp.level);
          if (imp.level < 3)
            buf.add(' (' + imp.ep + '/' + 
              EvolutionConst.epCostImprovement[imp.level] + ' ep)');
          buf.add("\n<font color='#5ebee5'>" + imp.info.note + '</font>\n');
          buf.add("<font color='#4cd47b'>" +
            imp.info.levelNotes[imp.level] + '</font>\n');
          if (imp.info.noteFunc != null)
            buf.add("<font color='#13ff65'>" +
              imp.info.noteFunc(imp.info.levelParams[imp.level]) + '</font>\n');
          buf.add('\n');
        }

      buf.add('\nCurrent evolution direction: ');
      buf.add("<font color='#00ffff'>" + 
        game.player.evolutionManager.getEvolutionDirectionInfo() + "</font>");

      return buf.toString();
    }
}
