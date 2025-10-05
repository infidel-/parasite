// defines narcotics junk item
package items;

import Const;
import _PlayerAction;
import game.Game;
import game._Item;
import ItemInfo;

class Narcotics extends ItemInfo
{
// builds narcotics info
  public function new(game: Game)
    {
      super(game);
      id = 'narcotics';
      name = 'white powder';
      type = 'junk';
      unknown = 'small plastic bag';
    }

// builds narcotics-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      var itemName = item.getName();
      actions.push({
        id: 'use.' + item.id,
        type: ACTION_INVENTORY,
        name: 'Snort ' + Const.col('inventory-item', itemName),
        energy: 0,
        item: item
      });
      return actions;
    }

// handles narcotics-specific inventory actions
  override public function action(actionID: String, item: _Item): Null<Bool>
    {
      return switch (actionID)
        {
          case 'use': snortAction(item);
          default: super.action(actionID, item);
        };
    }

// performs narcotics snorting behavior
  function snortAction(item: _Item): Bool
    {
      var host = game.player.host;
      game.scene.sounds.play('item-' + item.id);
      host.emitSound({
        text: '*snort*',
        radius: 5,
        alertness: 5
      });
      host.log('inhales the powder with unsettling confidence.');
      host.inventory.removeItem(item);
      host.onEffect(new effects.WhitePowder(game, 10));

      var powder = host.effects.get(EFFECT_WHITE_POWDER);
      if (powder != null && powder.points > 30)
        {
          host.log('convulses as the powder overwhelms their body.');
          game.player.onHostDeath('Your host overdoses on the white powder and perishes.');
        }
      return true;
    }
}
