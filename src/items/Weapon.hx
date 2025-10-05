// base info for weapon items
package items;

import Const;
import ItemInfo;
import _PlayerAction;
import game.Game;
import game._Item;

class Weapon extends ItemInfo
{
// builds weapon defaults
  public function new(game: Game)
    {
      super(game);
      type = 'weapon';
    }

// builds weapon-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      var itemName = item.getName();
      actions.push({
        id: 'active.' + item.id,
        type: ACTION_INVENTORY,
        name: 'Mark ' + Const.col('inventory-item', itemName) + ' as active',
        energy: 0,
        item: item
      });
      return actions;
    }

// handles weapon-specific inventory actions
  override public function action(actionID: String, item: _Item): Null<Bool>
    {
      return switch (actionID)
        {
          case 'active': activeAction(item);
          default: super.action(actionID, item);
        };
    }

// marks this weapon as the active choice
  function activeAction(item: _Item): Bool
    {
      game.log('You will now attack with the ' + item.name + '.');
      game.player.host.inventory.weaponID = item.id;
      return true;
    }
}
