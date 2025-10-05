// defines nutrients consumable item
package items;

import game.Game;
import game._Item;
import ItemInfo;
import Const;
import _PlayerAction;

class Nutrients extends ItemInfo
{
// builds nutrients info
  public function new(game: Game)
    {
      super(game);
      id = 'nutrients';
      name = 'nutrients';
      type = 'nutrients';
      unknown = 'uneven dark-red object';
      isKnown = true;
    }

// builds nutrient-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      var itemName = item.getName();
      actions.push({
        id: 'use.' + item.id,
        type: ACTION_INVENTORY,
        name: 'Consume ' + Const.col('inventory-item', itemName),
        energy: 0,
        item: item
      });
      return actions;
    }
}
