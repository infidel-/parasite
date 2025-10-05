// base info for computer-like items
package items;

import Const;
import ItemInfo;
import _PlayerAction;
import game.Game;
import game._Item;

class Computer extends ItemInfo
{
// builds computer defaults
  public function new(game: Game)
    {
      super(game);
      type = 'computer';
    }

// builds computer-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      var itemName = item.getName();
      if (game.player.evolutionManager.getLevel(IMP_ENGRAM) >= 1 &&
          !game.player.vars.mapAbsorbed)
        actions.push({
          id: 'absorbMap.' + item.id,
          type: ACTION_INVENTORY,
          name: 'Absorb regional map',
          energy: 15,
          item: item
        });
      if (game.player.vars.searchEnabled)
        actions.push({
          id: 'search.' + item.id,
          type: ACTION_INVENTORY,
          name: 'Use ' + Const.col('inventory-item', itemName) + ' to search',
          energy: 10,
          item: item
        });
      return actions;
    }
}
