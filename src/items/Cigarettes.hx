// defines cigarettes junk item
package items;

import Const;
import _PlayerAction;
import game.Game;
import game._Item;
import ItemInfo;

class Cigarettes extends ItemInfo
{
// builds cigarettes info
  public function new(game: Game)
    {
      super(game);
      id = 'cigarettes';
      name = 'pack of cigarettes';
      type = 'junk';
      unknown = 'small container';
    }

// builds cigarette-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      actions.push({
        id: 'use.' + item.id,
        type: ACTION_INVENTORY,
        name: 'Smoke a ' + Const.col('inventory-item', 'cigarette'),
        energy: 0,
        item: item
      });
      return actions;
    }

// handles cigarette-specific inventory actions
  override public function action(actionID: String, item: _Item): Null<Bool>
    {
      return switch (actionID)
        {
          case 'use': smokeAction(item);
          default: super.action(actionID, item);
        };
    }

// performs cigarette smoking behavior
  function smokeAction(item: _Item): Bool
    {
      game.scene.sounds.play('item-' + item.id);
      game.player.host.log('takes a slow drag and exhales a ribbon of smoke.');
      // game.player.host.inventory.removeItem(item);
      return true;
    }
}
