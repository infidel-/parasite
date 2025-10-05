// defines narcotics junk item
package items;

import Const;
import _PlayerAction;
import game.Game;
import game._Item;
import ItemInfo;

class Narcotics extends ItemInfo
{
// builds narcotics info
  public function new(game: Game)
    {
      super(game);
      id = 'narcotics';
      name = 'white powder';
      type = 'junk';
      unknown = 'small plastic bag';
    }

// builds narcotics-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      var itemName = item.getName();
      actions.push({
        id: 'use.' + item.id,
        type: ACTION_INVENTORY,
        name: 'Snort ' + Const.col('inventory-item', itemName),
        energy: 0,
        item: item
      });
      return actions;
    }

// handles narcotics-specific inventory actions
  override public function action(actionID: String, item: _Item): Null<Bool>
    {
      return switch (actionID)
        {
          case 'use': snortAction(item);
          default: super.action(actionID, item);
        };
    }

// performs narcotics snorting behavior
  function snortAction(item: _Item): Bool
    {
      game.scene.sounds.play('item-' + item.id);
      game.player.host.emitSound({
        text: '*snort*',
        radius: 5,
        alertness: 5
      });
      game.player.host.log('inhales the powder with unsettling confidence.');
      game.player.host.inventory.removeItem(item);
      return true;
    }
}
