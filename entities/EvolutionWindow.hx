// evolution GUI window

package entities;

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

      for (imp in game.player.evolutionManager.getList())
        if (imp.level < 3)
          list.add({
            id: 'set.' + imp.id,
            type: ACTION_EVOLUTION,
            name: imp.info.name + 
              ' (' + imp.info.levelNotes[imp.level + 1] + ')',
            energy: 0,
            });

      // add paths (full evolution only)
      if (game.player.evolutionManager.state > 1)
        for (p in game.player.evolutionManager.getPathList())
          {
            // do not add completed paths
            if (game.player.evolutionManager.isPathComplete(p.id))
              continue;
              
            list.add({
              id: 'setPath.' + p.id,
              type: ACTION_EVOLUTION,
              name: p.info.name + ' (' + p.ep + '/' +
                ConstEvolution.epCostPath[p.level] + ')',
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
      for (imp in game.player.evolutionManager.getList())
        {
          buf.add(imp.info.name);
          buf.add(' ');
          buf.add(imp.level);
          if (imp.level < 3)
            buf.add(' (' + imp.ep + '/' + 
              ConstEvolution.epCostImprovement[imp.level] + ')');
          buf.add(': ');
          buf.add(imp.info.note + '\n');
//          if (imp.level > 0)
          buf.add('  ' + imp.info.levelNotes[imp.level] + '\n');
        }

      buf.add('\nCurrent evolution direction: ');
      buf.add(game.player.evolutionManager.getEvolutionDirectionInfo());

      return buf.toString();
    }
}
