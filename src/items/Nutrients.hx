// defines nutrients consumable item
package items;

import l10n.Loc;

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
      name = N('nutrients');
      type = 'nutrients';
      unknown = N('uneven dark-red object');
      isKnown = true;
    }

// builds nutrient-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      actions.push({
        id: 'use.' + item.id,
        type: ACTION_INVENTORY,
        name: T('Consume {item}', { item: Loc.colored('inventory-item', item) }),
        nameClean: T('Consume'),
        energy: 0,
        item: item
      });
      return actions;
    }

// handles nutrient-specific inventory actions
  override public function action(actionID: String, action: _PlayerAction): Null<Bool>
    {
      return switch (actionID)
        {
          case 'use': useAction(action.item);
          default: super.action(actionID, action);
        };
    }

// performs nutrient consumption effects
  function useAction(item: _Item): Bool
    {
      game.log(T('Your host gnaws the delicious nutrients recovering health and energy.'));
      game.scene.sounds.play('item-nutrients');
      game.player.host.health += 10;
      game.player.host.energy += 50;
      return true;
    }
}
