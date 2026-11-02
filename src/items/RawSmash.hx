// defines raw smash junk item
package items;

import l10n.Loc;

import Const;
import game.Game;
import game._Item;
import ItemInfo;

class RawSmash extends ItemInfo
{
// builds raw smash info
  public function new(game: Game)
    {
      super(game);
      id = 'rawSmash';
      name = N('raw smash');
      type = 'junk';
      unknown = N('jagged red crystal');
    }

// builds raw smash-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      actions.push({
        id: 'use.' + item.id,
        type: ACTION_INVENTORY,
        name: T('Inject {item}', { item: Loc.colored('inventory-item', item) }),
        nameClean: T('Inject'),
        energy: 0,
        item: item
      });
      return actions;
    }

// handles raw smash-specific inventory actions
  override public function action(actionID: String, action: _PlayerAction): Null<Bool>
    {
      return switch (actionID)
        {
          case 'use': injectAction(action);
          default: super.action(actionID, action);
        };
    }

// performs raw smash injection behavior
  function injectAction(action: _PlayerAction): Bool
    {
      var host = action.who;
      if (host == null ||
          action.item == null)
        return false;

      game.scene.sounds.play('item-' + action.item.id);
      host.emitSound({
        text: T('*WAIL*'),
        kind: 'bark',
        radius: 6,
        alertness: 12
      });
      host.log(T('{ai:The} stabs the jagged crystal into flesh to flood the blood with raw smash.', { ai: host }));
      host.inventory.removeItem(action.item);
      host.onEffect(new effects.Smash(game, 10 + Std.random(4)));
      return true;
    }
}
