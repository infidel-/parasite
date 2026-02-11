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
  override public function action(actionID: String, action: _PlayerAction): Null<Bool>
    {
      return switch (actionID)
        {
          case 'use': imbibeAction(action.item);
          default: super.action(actionID, action);
        };
    }

// performs alcohol drinking behavior
  function imbibeAction(item: _Item): Bool
    {
      var host = game.player.host;
      if (host == null)
        return false;

      game.scene.sounds.play('item-' + item.id);
      host.emitSound({
        text: '*glug*',
        radius: 2,
        alertness: 2
      });
      host.log('takes a few bold swigs, and the bottle quickly comes to an end.');
      host.inventory.removeItem(item);

      // apply drunk effect stack and evaluate blackout threshold
      host.onEffect(new effects.Drunk(game, 10));
      var drunkEffect = host.effects.get(EFFECT_DRUNK);

      // trigger blackout when overindulged
      if (drunkEffect.points >= 30)
        {
          host.onEffect(new effects.Paralysis(game, 5));
          host.log('staggers, blacks out, and you lose the grip.');
          host.onDetach('drunk');
          game.playerArea.onDetach();
        }
      return true;
    }
}
