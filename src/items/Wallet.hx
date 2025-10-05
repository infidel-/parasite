// defines wallet junk item
package items;

import Const;
import _PlayerAction;
import game.Game;
import game._Item;
import ItemInfo;

class Wallet extends ItemInfo
{
// builds wallet info
  public function new(game: Game)
    {
      super(game);
      id = 'wallet';
      name = 'wallet';
      type = 'junk';
      unknown = 'small leather object';
    }

// builds wallet-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      var itemName = item.getName();
      actions.push({
        id: 'use.' + item.id,
        type: ACTION_INVENTORY,
        name: 'Open ' + Const.col('inventory-item', itemName),
        energy: 3,
        isAgreeable: true,
        item: item
      });
      return actions;
    }

// handles wallet inventory actions
  override public function action(actionID: String, item: _Item): Null<Bool>
    {
      return switch (actionID)
        {
          case 'use': openWalletAction(item);
          default: super.action(actionID, item);
        };
    }

// performs wallet opening to convert it into cash
  function openWalletAction(item: _Item): Bool
    {
      var ai = game.player.host;
      var inventory = game.player.host.inventory;
      inventory.removeItem(item);
      var money = inventory.addID('money');
      ai.log('opens the wallet and pockets the ' +
        Const.col('inventory-item', money.getName()) + ' inside.');
      game.scene.sounds.play('item-money');
      return true;
    }
}
