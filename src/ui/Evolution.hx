// evolution GUI window

package ui;

import game.Game;
import const.EvolutionConst;

class Evolution extends Actions
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
      var diff = game.player.evolutionManager.difficulty;
      for (imp in game.player.evolutionManager)
        {
          // limit max level
          var maxLevel = imp.info.maxLevel;
          if (imp.info.id == IMP_BRAIN_PROBE || diff == EASY)
            1;
          else if (diff == NORMAL && maxLevel > 2)
            maxLevel = 2;
          else if (diff == HARD && maxLevel > 1)
            maxLevel = 1;

          if (imp.level >= maxLevel)
            continue;

          var buf = new StringBuf();
          buf.add("<font color='#00ffff'>" + imp.info.name + "</font>");
          buf.add(' ');
          buf.add(imp.level + 1);
          buf.add(' (' + imp.ep + '/' +
            EvolutionConst.epCostImprovement[imp.level] + ' ep) (');
          var epLeft = EvolutionConst.epCostImprovement[imp.level] - imp.ep;
          buf.add(Math.round(epLeft / __Math.epPerTurn()));
          buf.add(" turns)<br/>");

          buf.add("<font color='#5ebee5'>" + imp.info.note + '</font><br/>');
          var levelNote = imp.info.levelNotes[imp.level + 1];
          if (levelNote.indexOf('fluff') < 0 &&
              levelNote.indexOf('todo') < 0)
            buf.add("<font color='#4cd47b'>" + levelNote + '</font><br/>');
          if (imp.info.noteFunc != null)
            buf.add("<font color='#13ff65'>" +
              imp.info.noteFunc(imp.info.levelParams[imp.level + 1]) + '</font><br/>');

          list.add({
            id: 'set.' + imp.id,
            type: ACTION_EVOLUTION,
            name: buf.toString(),
            energy: 0,
            });
        }

/*
  paths disabled
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
            buf.add(Math.round(epLeft / __Math.epPerTurn()));
            buf.add(" turns)");

            list.add({
              id: 'setPath.' + p.id,
              type: ACTION_EVOLUTION,
              name: buf.toString(),
              energy: 0,
              });
          }
*/

      return list;
    }


// action
  override function onAction(action: _PlayerAction)
    {
      game.player.evolutionManager.action(action);
    }


// update window text
  override function getText()
    {
      var buf = new StringBuf();
      buf.add('Controlled Evolution<br/>===<br/><br/>');

      // form a list of improvs and actions
      buf.add('Improvements<br/>===<br/>');
      var n = 0;
      for (imp in game.player.evolutionManager)
        {
          buf.add("<font color='#00ffff'>" + imp.info.name + "</font>");
          buf.add(' ');
          if (imp.info.maxLevel > 1)
            buf.add(imp.level);
          if (imp.level < imp.info.maxLevel)
            buf.add(' (' + imp.ep + '/' +
              EvolutionConst.epCostImprovement[imp.level] + ' ep)');
          buf.add("<br/><font color='#5ebee5'>" + imp.info.note + '</font><br/>');
          var levelNote = imp.info.levelNotes[imp.level];
          if (levelNote.indexOf('fluff') < 0 &&
              levelNote.indexOf('todo') < 0)
            buf.add("<font color='#4cd47b'>" + levelNote + '</font><br/>');
          if (imp.info.noteFunc != null)
            buf.add("<font color='#13ff65'>" +
              imp.info.noteFunc(imp.info.levelParams[imp.level]) + '</font><br/>');
          buf.add('<br/>');
          n++;
        }

      if (n == 0)
        buf.add('  --- empty ---<br/>');

      if (game.location == LOCATION_AREA && game.area.isHabitat)
        buf.add('You are in a microhabitat.<br/>');
      buf.add('Evolving costs additional ' + __Math.evolutionEnergyPerTurn() +
        ' energy per turn.<br/>' +
        'You will receive ' + __Math.epPerTurn() + ' ep per turn.<br/>' +
        'Your host will survive for ' +
          Std.int(game.player.host.energy / __Math.evolutionEnergyPerTurn()) +
        ' turns while evolving (not counting other spending).<br/>');

      buf.add('<br/>Current evolution direction: ');
      buf.add(game.player.evolutionManager.getEvolutionDirectionInfo());

      return buf.toString();
    }
}
