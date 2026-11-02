// defines wallet junk item
package items;

import l10n.Loc;

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
      name = N('wallet');
      type = 'junk';
      unknown = N('small leather object');
    }

// builds wallet-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      actions.push({
        id: 'use.' + item.id,
        type: ACTION_INVENTORY,
        name: T('Open {item}', { item: Loc.colored('inventory-item', item) }),
        nameClean: T('Open'),
        energy: 3,
        isAgreeable: true,
        item: item
      });
      return actions;
    }

// handles wallet inventory actions
  override public function action(actionID: String, action: _PlayerAction): Null<Bool>
    {
      return switch (actionID)
        {
          case 'use': openWalletAction(action.item);
          default: super.action(actionID, action);
        };
    }

// performs wallet opening to convert it into cash
  function openWalletAction(item: _Item): Bool
    {
      var ai = game.player.host;
      var inventory = game.player.host.inventory;
      inventory.removeItem(item);
      var money = inventory.addID('money');
      ai.log(T('{ai:The} opens the wallet and pockets {money:the} inside.', {
        ai: ai,
        money: Loc.colored('inventory-item', money),
      }));
      game.scene.sounds.play('item-money');
      return true;
    }
}
