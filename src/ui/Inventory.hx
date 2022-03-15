// inventory GUI window

package ui;

import game.Game;

class Inventory extends Actions
{
  public function new(g: Game)
    { super(g); }


// get action list
  /*
  override function getActions()
    {
      return game.player.host.inventory.getActions();
    }*/


// action
  override function onAction(action: _PlayerAction)
    {
      // do action
      game.player.host.inventory.action(action);

      // close window if it's still in inventory mode
      if (game.scene.state == UISTATE_INVENTORY)
        game.scene.closeWindow();
    }


// update window text
  override function getText()
    {
      var buf = new StringBuf();
      buf.add('Inventory<br/>===<br/><br/>');

      // draw a list of items
      var n = 0;
      for (item in game.player.host.inventory)
        {
          n++;
          var knowsItem = game.player.knowsItem(item.id);
          var name = (knowsItem ? item.name : item.info.unknown);
          buf.add(name + '<br/>');
        }

      if (n == 0)
        buf.add('  --- empty ---<br/>');

      return buf.toString();
    }
}
