// debug GUI window

package entities;

class DebugWindow extends TextWindow
{
  public function new(g: Game)
    {
      super(g);
    }


// get action list
  override function getActions()
    {
      var list = new List<_PlayerAction>();
      var actions = null;
      if (game.location == Game.LOCATION_AREA)
        actions = game.area.debug.actions;
      else if (game.location == Game.LOCATION_REGION)
        actions = game.region.debug.actions;

      var n = 0;
      for (a in actions)
        list.add({
          id: 'debug' + (n++),
          type: ACTION_DEBUG,
          name: a.name,
          energy: 0,
          });

      return list;
    }


// action handler
  override function onAction(action: _PlayerAction)
    {
      var index = Std.parseInt(action.id.substr(5));

      if (game.location == Game.LOCATION_AREA)
        game.area.debug.action(index);
      else if (game.location == Game.LOCATION_REGION)
        game.region.debug.action(index);
    }


// update window text
  override function getText()
    {
      var buf = new StringBuf();
      buf.add('Debug\n===\n\n');

      if (game.location == Game.LOCATION_AREA)
        {
          buf.add('Area alertness: ' + game.area.getArea().alertness + '\n');
          buf.add('Area interest: ' + game.area.getArea().interest + '\n');
        }
      else
        {
          var area = game.region.currentArea;
          buf.add('Area alertness: ' + area.alertness + '\n');
          buf.add('Area interest: ' + area.interest + '\n');
        }

      return buf.toString();
    }
}
