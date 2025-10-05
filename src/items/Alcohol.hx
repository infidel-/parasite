// defines alcohol junk item
package items;

import Const;
import _PlayerAction;
import game.Game;
import game._Item;
import ItemInfo;

class Alcohol extends ItemInfo
{
// builds alcohol info
  public function new(game: Game)
    {
      super(game);
      id = 'alcohol';
      name = 'bottle of alcohol';
      type = 'junk';
      unknown = 'glass container of liquid';
    }

// builds alcohol-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      var itemName = item.getName();
      actions.push({
        id: 'use.' + item.id,
        type: ACTION_INVENTORY,
        name: 'Imbibe ' + Const.col('inventory-item', itemName),
        energy: 2,
        item: item
      });
      return actions;
    }

// handles alcohol-specific inventory actions
  override public function action(actionID: String, item: _Item): Null<Bool>
    {
      return switch (actionID)
        {
          case 'use': imbibeAction(item);
          default: super.action(actionID, item);
        };
    }

// performs alcohol drinking behavior
  function imbibeAction(item: _Item): Bool
    {
      game.scene.sounds.play('item-' + item.id);
      game.player.host.emitSound({
        text: '*glug*',
        radius: 2,
        alertness: 2
      });
      game.player.host.log('takes a few bold swigs, and then the bottle suddenly comes to an end.');
      game.player.host.inventory.removeItem(item);
      return true;
    }
}
