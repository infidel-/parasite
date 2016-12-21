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

      // add stop action
      if (game.player.evolutionManager.isActive)
        list.add({
          id: 'stop',
          type: ACTION_EVOLUTION,
          name: 'Stop evolution',
          energy: 0,
          });

      // add available improvements
      for (imp in game.player.evolutionManager)
        if (imp.level < 3)
          {
            var buf = new StringBuf();
            buf.add("<font color='#00ffff'>" + imp.info.name + "</font>");
            buf.add(' ');
            buf.add(imp.level + 1);
            buf.add(' (' + imp.ep + '/' +
              EvolutionConst.epCostImprovement[imp.level] + ' ep) (');
            var epLeft = EvolutionConst.epCostImprovement[imp.level] - imp.ep;
            buf.add(Math.round(epLeft / _Math.epPerTurn()));
            buf.add(" turns)\n");

            buf.add("<font color='#5ebee5'>" + imp.info.note + '</font>\n');
            var levelNote = imp.info.levelNotes[imp.level + 1];
            if (levelNote.indexOf('fluff') < 0 &&
                levelNote.indexOf('todo') < 0)
              buf.add("<font color='#4cd47b'>" + levelNote + '</font>\n');
            if (imp.info.noteFunc != null)
              buf.add("<font color='#13ff65'>" +
                imp.info.noteFunc(imp.info.levelParams[imp.level + 1]) + '</font>\n');

            list.add({
              id: 'set.' + imp.id,
              type: ACTION_EVOLUTION,
              name: buf.toString(),
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

            var buf = new StringBuf();
            buf.add("<font color='#00ffff'>" + p.info.name + "</font>");
            buf.add(' (');
            buf.add(p.ep + '/' +
              EvolutionConst.epCostPath[p.level] + ' ep) (');
            var epLeft = EvolutionConst.epCostPath[p.level] - p.ep;
            buf.add(Math.round(epLeft / _Math.epPerTurn()));
            buf.add(" turns)");

            list.add({
              id: 'setPath.' + p.id,
              type: ACTION_EVOLUTION,
              name: buf.toString(),
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
      var n = 0;
      for (imp in game.player.evolutionManager)
        {
          buf.add("<font color='#00ffff'>" + imp.info.name + "</font>");
          buf.add(' ');
          buf.add(imp.level);
          if (imp.level < 3)
            buf.add(' (' + imp.ep + '/' +
              EvolutionConst.epCostImprovement[imp.level] + ' ep)');
          buf.add("\n<font color='#5ebee5'>" + imp.info.note + '</font>\n');
          var levelNote = imp.info.levelNotes[imp.level];
          if (levelNote.indexOf('fluff') < 0 &&
              levelNote.indexOf('todo') < 0)
            buf.add("<font color='#4cd47b'>" + levelNote + '</font>\n');
          if (imp.info.noteFunc != null)
            buf.add("<font color='#13ff65'>" +
              imp.info.noteFunc(imp.info.levelParams[imp.level]) + '</font>\n');
          buf.add('\n');
          n++;
        }

      if (n == 0)
        buf.add('  --- empty ---\n');

      if (game.location == LOCATION_AREA && game.area.isHabitat)
        buf.add('You are in a microhabitat.\n');
      buf.add('Evolving costs additional ' + _Math.evolutionEnergyPerTurn() +
        ' energy per turn.\n' +
        'You will receive ' + _Math.epPerTurn() + ' ep per turn.\n' +
        'Your host will survive for ' +
          Std.int(game.player.host.energy / _Math.evolutionEnergyPerTurn()) +
        ' turns while evolving (not counting other spending).\n');

      buf.add('\nCurrent evolution direction: ');
      buf.add(game.player.evolutionManager.getEvolutionDirectionInfo());

      return buf.toString();
    }
}
