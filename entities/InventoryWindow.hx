// inventory GUI window

package entities;

import game.Game;

class InventoryWindow extends TextWindow
{

  public function new(g: Game)
    {
      super(g);
    }


// get action list
  override function getActions()
    {
      return game.player.host.inventory.getActions();
    }


// action
  override function onAction(action: _PlayerAction)
    {
      game.player.host.inventory.action(action); // do action
    }


// update window text
  override function getText()
    {
      var buf = new StringBuf();
      buf.add('Inventory\n===\n\n');

      // draw a list of items
      var n = 0;
      for (item in game.player.host.inventory)
        {
          n++;
          var knowsItem = game.player.knowsItem(item.id);
          var name = (knowsItem ? item.name : item.info.unknown);
          buf.add(name + '\n');
        }

      if (n == 0)
        buf.add('  --- empty ---\n');

      return buf.toString();
    }
}
