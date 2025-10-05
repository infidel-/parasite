// base info for readable items
package items;

import Const;
import ItemInfo;
import _PlayerAction;
import game.Game;
import game._Item;

class Readable extends ItemInfo
{
// builds readable defaults
  public function new(game: Game)
    {
      super(game);
      type = 'readable';
    }

// builds readable-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      var itemName = item.getName();
      actions.push({
        id: 'read.' + item.id,
        type: ACTION_INVENTORY,
        name: 'Read ' + Const.col('inventory-item', itemName),
        energy: 10,
        isAgreeable: true,
        item: item
      });
      return actions;
    }
}
