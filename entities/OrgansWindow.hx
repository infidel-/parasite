// organs GUI window

package entities;

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

      for (imp in game.player.evolutionManager.getList())
        {
          // improvement not available yet or no organs
          if (imp.level == 0 || imp.info.organ == null)
            continue;

          var organ = imp.info.organ;

          // organ already completed
          if (game.player.host.organs.getActive(imp.info.id) != null)
            continue;

          list.add({
            id: 'set.' + imp.id,
            type: ACTION_ORGAN,
            name: organ.name + ' (' + organ.gp + 'gp)' +
            ' [' + organ.note + ']',
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
          buf.add(organ.info.name + ' ' + organ.level);
          if (organ.isActive)
            {
              if (organ.info.hasTimeout && organ.timeout > 0)
                buf.add(' (timeout: ' + organ.timeout + ')');
            }
          else buf.add(' (' + organ.gp + '/' + organ.info.gp + 'gp)');
          buf.add(' [' + organ.info.note + ']\n');
#if mydebug
//          var params = game.player.evolutionManager.getParams(organ.id);
          buf.add('DEBUG: ' + organ.params + '\n');
#end
          n++;
        }

      if (n == 0)
        buf.add('  --- empty ---\n');

      buf.add('\nGrowing body feature: ');
      buf.add(game.player.host.organs.getGrowInfo());

      return buf.toString();
    }
}
